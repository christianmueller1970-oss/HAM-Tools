import Foundation
import IOKit.ps

/// Liest den macOS-Akkustatus alle 30 s aus der IOPowerSources-API und
/// publisht ihn für UI-Konsumenten. Bei Desktop-Macs ohne Akku bleibt der
/// Status auf `.noBattery` — die UI soll die Pille dann ganz ausblenden.
@MainActor
final class BatteryMonitor: ObservableObject {
    enum Status: Equatable {
        /// Kein interner Akku (Desktop, eGPU-Setup ohne Battery, …).
        case noBattery
        /// Akku-Betrieb. `remainingMin` ist nil solange macOS noch keine
        /// Schätzung hat (direkt nach Stecker-Ziehen).
        case onBattery(percent: Int, remainingMin: Int?)
        /// AC angeschlossen und Akku lädt aktiv.
        case charging(percent: Int)
        /// AC angeschlossen, Akku ist voll (oder hält den Stand).
        case acPower(percent: Int)
    }

    @Published private(set) var status: Status = .noBattery

    private var timer: Timer?

    init() {
        refresh()
        // 30 s reicht — Akku-Prozente kriechen langsam, und wir wollen
        // den Mac nicht für eine 1-Hz-Statusbar wachhalten.
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    deinit { timer?.invalidate() }

    func refresh() {
        guard let snap = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            status = .noBattery
            return
        }
        guard let list = IOPSCopyPowerSourcesList(snap)?.takeRetainedValue() as? [CFTypeRef] else {
            status = .noBattery
            return
        }
        for src in list {
            guard let descRef = IOPSGetPowerSourceDescription(snap, src)?.takeUnretainedValue(),
                  let dict = descRef as? [String: Any]
            else { continue }
            // Nur den internen Akku — externe USB-Power-Banks etc. ignorieren.
            let type = dict[kIOPSTypeKey as String] as? String
            guard type == kIOPSInternalBatteryType else { continue }

            let cur = dict[kIOPSCurrentCapacityKey as String] as? Int ?? 0
            let cap = dict[kIOPSMaxCapacityKey as String] as? Int ?? 100
            let pct = cap > 0 ? Int(round(Double(cur) / Double(cap) * 100)) : 0
            let powerState = dict[kIOPSPowerSourceStateKey as String] as? String
            let isCharging = dict[kIOPSIsChargingKey as String] as? Bool ?? false

            if powerState == kIOPSACPowerValue {
                status = isCharging ? .charging(percent: pct) : .acPower(percent: pct)
            } else {
                let ttx = dict[kIOPSTimeToEmptyKey as String] as? Int
                let remain: Int? = (ttx ?? -1) > 0 ? ttx : nil
                status = .onBattery(percent: pct, remainingMin: remain)
            }
            return
        }
        status = .noBattery
    }
}
