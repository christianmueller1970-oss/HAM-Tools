import Foundation
import SwiftUI

/// Bridge zwischen den Native-Antennen-Rechnern und der AntennenSimulator-View.
/// Eine Rechner-View ruft `openInSim(model:)` auf, packt damit ein NEC2-Drahtmodell
/// in einen URL-Param und triggert die Navigation zum Antennen-Simulator-Tab.
///
/// Spiegelt das Web-Verhalten (openInSim.js) — gleiche URL-Encoding-Konvention
/// (URL-safe Base64-JSON), damit `?model=<param>` von der Web-App identisch
/// dekodiert wird.
final class AntennaSimBridge: ObservableObject {
    /// Aktueller Modell-Param (Base64-JSON, URL-safe). Nil = Sim öffnet seine Default-URL.
    @Published var pendingModelParam: String? = nil
    /// Flag: Antennen-Rechner-View bittet um Navigation zum Sim-Tab.
    /// ContentView lauscht und setzt selectedCalculator = .antennenSim.
    @Published var navigationRequest: UUID? = nil

    static let shared = AntennaSimBridge()
    private init() {}

    /// Wird von Antennen-Rechner-Views aufgerufen mit dem fertigen
    /// NEC2-Modell-Dictionary (gleiches Schema wie cfg im Web).
    func openInSim(model: [String: Any]) {
        guard let json = try? JSONSerialization.data(withJSONObject: model, options: []),
              let raw = String(data: json, encoding: .utf8) else {
            return
        }
        // URL-safe Base64 (analog zu encodeModel() in openInSim.js)
        let b64 = Data(raw.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        pendingModelParam = b64
        navigationRequest = UUID()      // unique trigger
    }

    /// Wird vom Sim aufgerufen, sobald der Param "konsumiert" wurde, damit
    /// das nächste Aufrufen nicht den alten Wert wiederverwendet.
    func consumeParam() -> String? {
        let p = pendingModelParam
        pendingModelParam = nil
        return p
    }
}
