import Foundation
import Combine

// Orchestrator für CAT-Anbindung. Holt sich die aktive Konfiguration aus
// CATSettings, startet rigctld, verbindet TCP, pollt Frequenz/Mode und
// spiegelt sie in RadioState. Phase 5a: nur Read.
@MainActor
final class CATController: ObservableObject {
    enum Status: Equatable {
        case disconnected
        case starting
        case connected
        case errored(String)
    }

    @Published private(set) var status: Status = .disconnected
    @Published private(set) var lastError: String?
    @Published private(set) var lastPolledHz: Int64 = 0
    @Published private(set) var lastPolledMode: String = ""

    private let process = RigctldProcess()
    private let client = RigctldClient()
    private var pollTask: Task<Void, Never>?

    private let radioState: RadioState
    private let settings: CATSettings

    private let tcpPort = 4532

    // Lock-Flag um den RigctldClient. Der Client hat keine interne
    // Parallelität — Poll-Loop und Write-API (setFrequency, setMode …)
    // dürfen nie gleichzeitig auf den TCP-Socket schreiben, sonst
    // entsteht Buffer-Salat → Parse-Error → unbeabsichtigtes Disconnect.
    // Wir sind im @MainActor, also ist das Bool-Flip thread-safe.
    private var clientBusy = false

    init(radioState: RadioState, settings: CATSettings) {
        self.radioState = radioState
        self.settings = settings
    }

    deinit {
        pollTask?.cancel()
        client.disconnect()
        process.stop()
    }

    // MARK: - Lifecycle

    func toggle() async {
        if case .connected = status {
            stop()
        } else if case .starting = status {
            stop()
        } else {
            await start()
        }
    }

    func start() async {
        // Falls vorheriger Lauf nicht sauber gestoppt wurde (z.B. User klickt
        // Start zweimal ohne Stop dazwischen, oder Config gewechselt): vorhandenen
        // Prozess + Client abräumen, sonst hängt ein Orphan-rigctld auf Port 4532.
        stopInternal()

        guard let cfg = settings.activeConfig else {
            setError(CATError.noProfileSelected)
            return
        }
        guard let profile = TRXProfileLoader.shared.profile(forID: cfg.profileID) else {
            setError(CATError.noProfileSelected)
            return
        }

        if profile.needsSerialPort {
            guard let p = cfg.serialPort, !p.isEmpty else {
                setError(CATError.noPortSelected)
                return
            }
            _ = p
        }

        status = .starting
        lastError = nil

        do {
            try process.start(profile: profile, config: cfg, tcpPort: tcpPort)
        } catch {
            setError(error)
            return
        }

        let maxAttempts = 30
        var lastConnectError: Error?
        var firstHz: Int64?

        for attempt in 1...maxAttempts {
            if !process.isRunning {
                setError(CATError.rigctldExitedUnexpectedly(
                    code: -1,
                    stderr: process.lastStderr.isEmpty ? "(kein stderr)" : process.lastStderr))
                return
            }

            try? await Task.sleep(nanoseconds: 150_000_000)

            client.connect(host: "127.0.0.1", port: tcpPort)
            do {
                firstHz = try await client.getFrequencyHz()
                break
            } catch {
                lastConnectError = error
                client.disconnect()
                if attempt == maxAttempts {
                    let stderrSnippet = process.lastStderr.isEmpty
                        ? ""
                        : " · rigctld stderr: " + process.lastStderr.prefix(200)
                    let combinedMsg =
                        ((error as? CATError)?.errorDescription ?? error.localizedDescription)
                        + stderrSnippet
                    setError(CATError.protocolError(message: combinedMsg))
                    stopInternal()
                    return
                }
            }
        }

        if let hz = firstHz {
            lastPolledHz = hz
        } else if let err = lastConnectError {
            setError(err)
            stopInternal()
            return
        }

        status = .connected
        radioState.catConnected = true
        radioState.source = .cat
        startPollLoop()
    }

    func stop() {
        stopInternal()
        if case .errored = status {
            // Errored-Zustand erhalten
        } else {
            status = .disconnected
        }
    }

    private func stopInternal() {
        pollTask?.cancel()
        pollTask = nil
        client.disconnect()
        process.stop()
        radioState.catConnected = false
    }

    func restart() async {
        stop()
        await start()
    }

    // MARK: - Poll Loop

    private func startPollLoop() {
        guard let cfg = settings.activeConfig else { return }
        let intervalMs = cfg.pollIntervalMillis
        pollTask = Task { [weak self] in
            guard let self else { return }
            // Periodische Felder die nicht jede Runde gelesen werden müssen,
            // werden über einen Counter ausgedünnt (signal/vfo/split).
            var tick = 0
            while !Task.isCancelled {
                // Lock um die GANZE Poll-Iteration: getFrequency, getMode,
                // getSignal, getVFO, getSplit — alle auf demselben TCP-Socket,
                // dürfen nicht von einer Write-Operation unterbrochen werden.
                await self.acquireClientLock()
                let pollResult: Result<(Int64, (mode: String, passbandHz: Int), Int, String?, (Bool, String)?), Error>
                do {
                    let hz = try await self.client.getFrequencyHz()
                    let mode = try await self.client.getMode()
                    let signal = (try? await self.client.getSignalStrengthRelDB()) ?? self.radioState.signalStrengthRelDB
                    var newVfo: String? = nil
                    var newSplit: (Bool, String)? = nil
                    if tick % 4 == 0 {
                        newVfo = try? await self.client.getVFO()
                        newSplit = try? await self.client.getSplit()
                    }
                    pollResult = .success((hz, mode, signal, newVfo, newSplit))
                } catch {
                    pollResult = .failure(error)
                }
                self.releaseClientLock()

                switch pollResult {
                case .success(let (hz, mode, signal, newVfo, newSplit)):
                    self.applyPoll(hz: hz,
                                   hamlibMode: mode.mode,
                                   passbandHz: mode.passbandHz,
                                   signalRelDB: signal,
                                   vfo: newVfo,
                                   split: newSplit)
                case .failure(let error):
                    self.setError(error)
                    self.stopInternal()
                    // break funktioniert hier nicht weil wir in switch sind;
                    // wir setzen ein Flag und brechen außerhalb ab.
                    return
                }
                tick += 1
                try? await Task.sleep(nanoseconds: UInt64(intervalMs) * 1_000_000)
            }
        }
    }

    private func applyPoll(hz: Int64,
                           hamlibMode: String,
                           passbandHz: Int,
                           signalRelDB: Int,
                           vfo: String?,
                           split: (Bool, String)?) {
        lastPolledHz = hz
        lastPolledMode = hamlibMode

        let mhz = Double(hz) / 1_000_000.0
        if abs(mhz - radioState.frequencyMHz) > 0.0000005 {
            radioState.frequencyMHz = mhz
        }
        let uiMode = Self.mapMode(hamlib: hamlibMode)
        if radioState.mode != uiMode {
            radioState.mode = uiMode
        }
        if radioState.hamlibMode != hamlibMode {
            radioState.hamlibMode = hamlibMode
        }
        if radioState.passbandHz != passbandHz {
            radioState.passbandHz = passbandHz
        }
        if radioState.signalStrengthRelDB != signalRelDB {
            radioState.signalStrengthRelDB = signalRelDB
        }
        if let v = vfo, radioState.activeVFO != v {
            radioState.activeVFO = v
        }
        if let s = split {
            if radioState.splitOn != s.0 { radioState.splitOn = s.0 }
            if radioState.splitTxVfo != s.1 { radioState.splitTxVfo = s.1 }
        }
    }

    // MARK: - Client-Lock (verhindert Race zwischen Poll-Loop und Write-API)

    /// Wartet bis der Client frei ist (5ms-Polling), markiert ihn dann als
    /// belegt. Aufrufer MUSS am Ende `releaseClientLock()` rufen — entweder
    /// direkt oder via `defer`.
    private func acquireClientLock() async {
        while clientBusy {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        clientBusy = true
    }

    private func releaseClientLock() {
        clientBusy = false
    }

    // MARK: - Write-API (Phase 5b)

    func setFrequencyMHz(_ mhz: Double) async {
        guard case .connected = status else { return }
        let hz = Int64((mhz * 1_000_000).rounded())
        await acquireClientLock()
        defer { releaseClientLock() }
        do { try await client.setFrequencyHz(hz) }
        catch { setError(error) }
    }

    func setHamlibMode(_ mode: String, passbandHz: Int = 0) async {
        guard case .connected = status else { return }
        await acquireClientLock()
        defer { releaseClientLock() }
        do { try await client.setMode(mode, passbandHz: passbandHz) }
        catch { setError(error) }
    }

    func setVFO(_ vfo: String) async {
        guard case .connected = status else { return }
        await acquireClientLock()
        defer { releaseClientLock() }
        do { try await client.setVFO(vfo) }
        catch { setError(error) }
    }

    func setSplit(on: Bool, txVfo: String = "VFOB") async {
        guard case .connected = status else { return }
        await acquireClientLock()
        defer { releaseClientLock() }
        do { try await client.setSplit(on: on, txVfo: txVfo) }
        catch { setError(error) }
    }

    // MARK: - Mode-Mapping (Hamlib → UI/ADIF-ish)

    static func mapMode(hamlib: String) -> String {
        switch hamlib.uppercased() {
        case "USB", "LSB":        return "SSB"
        case "CW", "CWR":         return "CW"
        case "AM":                return "AM"
        case "FM", "FMN":         return "FM"
        case "RTTY", "RTTYR":     return "RTTY"
        case "PKTUSB", "PKTLSB",
             "PKTFM", "PKTAM":    return "DATA"
        default:                  return hamlib
        }
    }

    private func setError(_ error: Error) {
        let msg = (error as? CATError)?.errorDescription ?? error.localizedDescription
        lastError = msg
        status = .errored(msg)
        radioState.catConnected = false
    }
}
