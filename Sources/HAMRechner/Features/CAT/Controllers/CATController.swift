import Foundation
import Combine

// Orchestrator für CAT-Anbindung: startet rigctld, verbindet TCP, pollt
// Frequenz/Mode und spiegelt sie in RadioState. Phase 5a: nur Read.
// Reconnect-Logik / Watchdog kommt in Phase 5c.
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

    // Diagnostik für CATSettingsView
    @Published private(set) var lastPolledHz: Int64 = 0
    @Published private(set) var lastPolledMode: String = ""

    private let process = RigctldProcess()
    private let client = RigctldClient()
    private var pollTask: Task<Void, Never>?

    private let radioState: RadioState
    private let settings: CATSettings

    // localhost-Port für rigctld. Festwert reicht für MVP — falls künftig
    // mehrere Instanzen, hier dynamisch wählen.
    private let tcpPort = 4532

    init(radioState: RadioState, settings: CATSettings) {
        self.radioState = radioState
        self.settings = settings
    }

    deinit {
        // Bei App-Shutdown sauber abräumen.
        pollTask?.cancel()
        client.disconnect()
        process.stop()
    }

    // MARK: - Lifecycle

    func start() async {
        guard let profileID = settings.selectedProfileID,
              let profile = TRXProfileLoader.shared.profile(forID: profileID) else {
            setError(CATError.noProfileSelected)
            return
        }
        guard let port = settings.serialPort, !port.isEmpty else {
            setError(CATError.noPortSelected)
            return
        }

        status = .starting
        lastError = nil

        do {
            try process.start(profile: profile,
                              serialPort: port,
                              baudRate: settings.baudRate,
                              tcpPort: tcpPort)
        } catch {
            setError(error)
            return
        }

        // Warte 500 ms — rigctld braucht etwas, bis der TCP-Listener offen ist.
        // Bei zu früh: connect schlägt mit "Connection refused" fehl.
        try? await Task.sleep(nanoseconds: 500_000_000)

        if process.isRunning == false {
            setError(CATError.rigctldExitedUnexpectedly(code: -1,
                                                       stderr: process.lastStderr))
            return
        }

        client.connect(host: "127.0.0.1", port: tcpPort)

        // Erster Probe-Call: Frequenz lesen. Wenn das nicht klappt, ist
        // die Strecke kaputt (falsche Baudrate, falscher Port, USB-Kabel los…).
        do {
            let hz = try await client.getFrequencyHz()
            lastPolledHz = hz
        } catch {
            setError(error)
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
            // Errored-Zustand erhalten, damit User die Fehlermeldung sieht.
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
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    let hz = try await self.client.getFrequencyHz()
                    let mode = try await self.client.getMode()
                    self.applyPoll(hz: hz, hamlibMode: mode.mode)
                } catch {
                    self.setError(error)
                    self.stopInternal()
                    break
                }
                let interval = UInt64(self.settings.pollIntervalMillis) * 1_000_000
                try? await Task.sleep(nanoseconds: interval)
            }
        }
    }

    private func applyPoll(hz: Int64, hamlibMode: String) {
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

    // MARK: - Error-Hilfe

    private func setError(_ error: Error) {
        let msg = (error as? CATError)?.errorDescription ?? error.localizedDescription
        lastError = msg
        status = .errored(msg)
        radioState.catConnected = false
    }
}
