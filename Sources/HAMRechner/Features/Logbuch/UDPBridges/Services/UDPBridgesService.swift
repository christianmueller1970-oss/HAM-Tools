import Foundation
import Combine

// Zentraler Manager für alle UDP-Bridges. Beobachtet `UDPBridgesSettings.bridges`
// und startet / stoppt / restartet pro Eintrag einen `UDPListener` mit dem
// passenden Adapter.
//
// Events fließen über zwei Callbacks raus:
//   • onQSOLogged: vom App-Root verdrahtet mit LogbookManager.addQSO(...)
//   • onSpot:      vom App-Root verdrahtet mit DXClusterViewModel.injectExternalSpot(_:)
//
// Pro Bridge wird ein `BridgeRuntime` gehalten — der State daraus speist die
// Status-Pillen im Settings-UI.
@MainActor
final class UDPBridgesService: ObservableObject {

    /// Pro Bridge-ID der aktuelle Runtime-Status (für UI-Anzeige).
    @Published private(set) var runtime: [UUID: BridgeRuntimeState] = [:]

    var onQSOLogged: ((UDPBridgeQSOPayload, UDPBridge) -> Void)?
    var onSpot:      ((UDPBridgeSpotPayload, UDPBridge) -> Void)?

    struct BridgeRuntimeState: Equatable {
        var state: UDPListener.State
        var datagramCount: Int
        var lastActivity: Date?
        var lastError: String?
        var version: String?
    }

    private var listeners: [UUID: UDPListener] = [:]
    private var settings: UDPBridgesSettings?
    private var settingsCancellable: AnyCancellable?
    private var watchdogTimer: Timer?

    /// Bindet den Service an die Settings-Quelle. Reagiert auf Änderungen
    /// (Toggle, Port-Edit, Add/Remove) und passt die laufenden Listener
    /// entsprechend an.
    func bind(to settings: UDPBridgesSettings) {
        self.settings = settings
        settingsCancellable = settings.$bridges
            .receive(on: RunLoop.main)
            .sink { [weak self] bridges in
                self?.reconcile(bridges: bridges)
            }
        reconcile(bridges: settings.bridges)
        startWatchdog()
    }

    func stopAll() {
        for l in listeners.values { l.stop() }
        listeners.removeAll()
        runtime.removeAll()
        watchdogTimer?.invalidate()
        watchdogTimer = nil
    }

    // MARK: - Reconcile

    private func reconcile(bridges: [UDPBridge]) {
        let desired = Dictionary(uniqueKeysWithValues:
            bridges.filter { $0.enabled }.map { ($0.id, $0) }
        )

        // Listener stoppen, die nicht mehr im Soll-Zustand sind
        // oder andere Ports / Disable-Status haben.
        for (id, listener) in listeners {
            guard let bridge = desired[id] else {
                listener.stop()
                listeners.removeValue(forKey: id)
                runtime.removeValue(forKey: id)
                continue
            }
            if listener.port != bridge.port {
                listener.stop()
                listeners.removeValue(forKey: id)
                runtime.removeValue(forKey: id)
            }
        }

        // Neue / wieder aktivierte Bridges starten.
        for (id, bridge) in desired where listeners[id] == nil {
            startListener(for: bridge)
        }

        // Runtime-States für disabled Bridges löschen (transparent in UI).
        let activeIDs = Set(desired.keys)
        for id in runtime.keys where !activeIDs.contains(id) {
            runtime.removeValue(forKey: id)
        }
    }

    private func startListener(for bridge: UDPBridge) {
        let listener = UDPListener(bridgeID: bridge.id, port: bridge.port)
        listener.onDatagram = { [weak self] data in
            self?.handle(datagram: data, bridge: bridge)
        }
        listener.onStateChange = { [weak self] state in
            self?.updateRuntime(for: bridge.id) { rt in
                rt.state = state
                if case .failed(let msg) = state { rt.lastError = msg }
            }
        }
        listeners[bridge.id] = listener
        runtime[bridge.id] = BridgeRuntimeState(
            state: .stopped, datagramCount: 0,
            lastActivity: nil, lastError: nil, version: nil
        )
        listener.start()
    }

    // MARK: - Event-Dispatch

    private func handle(datagram: Data, bridge: UDPBridge) {
        let event: UDPBridgeEvent?
        switch bridge.bridgeProtocol {
        case .wsjtxCompatible:
            event = WsjtxAdapter.decode(datagram)
        case .n1mmContestUDP:
            event = N1MMAdapter.decode(datagram)
        }
        guard let e = event else { return }

        // Runtime updaten (Counter + last-Activity läuft schon via Listener,
        // hier nur Heartbeat-Version + Quittierung).
        updateRuntime(for: bridge.id) { rt in
            rt.datagramCount += 1
            rt.lastActivity = Date()
            if case .heartbeat(let v) = e, let v = v { rt.version = v }
        }

        switch e {
        case .qsoLogged(let q):
            onQSOLogged?(q, bridge)
        case .spot(let s):
            onSpot?(s, bridge)
        case .heartbeat, .close:
            break
        }
    }

    private func updateRuntime(for id: UUID, mutate: (inout BridgeRuntimeState) -> Void) {
        var rt = runtime[id] ?? BridgeRuntimeState(
            state: .stopped, datagramCount: 0,
            lastActivity: nil, lastError: nil, version: nil
        )
        mutate(&rt)
        runtime[id] = rt
    }

    // MARK: - Watchdog

    /// 5-Sekunden-Watchdog kickt Listener-Status von .linked auf .listening
    /// zurück, wenn >30 s keine Daten kamen. Wichtig für die UI-Pille, sonst
    /// sieht der User „verbunden" obwohl der Logger schon zu ist.
    private func startWatchdog() {
        watchdogTimer?.invalidate()
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                for listener in self.listeners.values {
                    listener.tickWatchdog()
                }
            }
        }
    }
}
