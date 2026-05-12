import Foundation
import Combine

// Zentrale Radio-State. Aktuell nur manuelle Frequenz-Eingabe; ab Phase 5
// (Hamlib-CAT) wird ein Subprocess die Werte live setzen und die UI
// reagiert genauso.
@MainActor
final class RadioState: ObservableObject {
    // Aktuelle TRX-Frequenz in MHz. Wird vom RadioControlPanel gepflegt
    // (manuell oder via CAT) und vom QSO-Eingabe-Panel + Send-Spot
    // gelesen. Auto-Band-Ableitung passiert beim Lesen via HamBand.
    @Published var frequencyMHz: Double = 14.200

    // Quelle der Frequenz — manual / CAT. Im Panel als Badge sichtbar.
    enum Source: String, Codable {
        case manual
        case cat
    }
    @Published var source: Source = .manual

    // Verbindungsstatus zur CAT-Schnittstelle. False = kein Radio aktiv.
    @Published var catConnected: Bool = false

    // Mode: vorerst nur als String, wird von QSO-Form gespiegelt.
    @Published var mode: String = "SSB"

    // Live-Werte aus dem Funkgerät (gepflegt von CATController bei aktivem CAT).
    @Published var signalStrengthRelDB: Int = -54  // dB relativ zu S9. S0 ≈ -54, S9 = 0, S9+30 = +30.
    @Published var activeVFO: String = "VFOA"      // "VFOA" / "VFOB" / "MEM"
    @Published var splitOn: Bool = false
    @Published var splitTxVfo: String = "VFOB"

    // Aktueller Hamlib-Mode (vor Mode-Mapping zu UI/ADIF). Wird vom
    // RadioControlPanel-Mode-Picker gelesen, damit USB/LSB/CW/PKTUSB etc.
    // unterschieden werden können (gegenüber dem "SSB"/"CW"/"DATA" in mode).
    @Published var hamlibMode: String = "USB"
    @Published var passbandHz: Int = 0

    // Persistierung der letzten Frequenz, damit Restart einen sinnvollen
    // Wert bringt statt 14.200 Default.
    private let lastFreqKey = "radio.lastFrequencyMHz"
    private var cancellable: AnyCancellable?

    init() {
        let stored = UserDefaults.standard.double(forKey: lastFreqKey)
        if stored > 0 { self.frequencyMHz = stored }

        cancellable = $frequencyMHz
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { UserDefaults.standard.set($0, forKey: "radio.lastFrequencyMHz") }
    }

    // Band-Ableitung aus aktueller Frequenz.
    var band: String {
        HamBand.from(frequencyMHz: frequencyMHz)?.rawValue ?? ""
    }
}
