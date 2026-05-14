import SwiftUI

// Settings-Panel für die WSJT-X-UDP-Brücke. Wird als eigener Tab in den
// Haupt-Settings angezeigt. Toggle + Port; Status-Indicator; Last-QSO-Info;
// kurze Anleitung wie man WSJT-X konfiguriert.
struct WsjtxBridgeView: View {
    @EnvironmentObject var settings: WsjtxBridgeSettings
    @EnvironmentObject var bridge:   WsjtxBridgeService

    @State private var portString: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                GroupBox("Aktivierung") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("WSJT-X-Brücke aktiv", isOn: $settings.enabled)
                        HStack {
                            Text("UDP-Port")
                                .frame(width: 110, alignment: .leading)
                            TextField("2237", text: $portString)
                                .frame(width: 80)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit(commitPort)
                            Text("Standard: 2237 (WSJT-X-Default)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                }

                GroupBox("Status") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 10, height: 10)
                            Text(statusText)
                                .fontWeight(.semibold)
                        }
                        if let v = bridge.wsjtxVersion {
                            Text("WSJT-X Version: \(v)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let hb = bridge.lastHeartbeat {
                            Text("Letztes Lebenszeichen: \(timeAgo(hb))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let err = bridge.lastError {
                            Text("Fehler: \(err)")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(10)
                }

                GroupBox("QSO-Empfang") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Empfangene QSOs: \(bridge.qsosLoggedCount)")
                            .fontWeight(.medium)
                        if let q = bridge.lastQSO {
                            Text("Zuletzt: \(q.dxCall) · \(q.mode) · \(String(format: "%.4f", q.txFrequencyMHz)) MHz · \(timeAgo(q.dateTimeOff))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Noch kein QSO empfangen.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                }

                GroupBox("WSJT-X konfigurieren") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("In WSJT-X unter **Datei → Einstellungen → Berichten**:")
                            .font(.callout)
                        Label("UDP-Server: 127.0.0.1", systemImage: "1.circle")
                            .font(.caption)
                        Label("UDP-Server-Port: \(Int(settings.port))", systemImage: "2.circle")
                            .font(.caption)
                        Label("Option «QSO-Mitteilungen weiterleiten» aktivieren",
                              systemImage: "3.circle")
                            .font(.caption)
                        Text("HAM-Tools übernimmt jedes in WSJT-X geloggte QSO automatisch ins gerade aktive Log.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                    .padding(10)
                }
            }
            .padding()
        }
        .onAppear { portString = String(settings.port) }
        .onChange(of: settings.port) { _, new in portString = String(new) }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch bridge.connectionState {
        case .stopped:    return .secondary
        case .listening:  return .yellow
        case .linked:     return .green
        case .failed:     return .red
        }
    }

    private var statusText: String {
        switch bridge.connectionState {
        case .stopped:           return "Inaktiv"
        case .listening:         return "Lauschend auf Port \(Int(settings.port))"
        case .linked:            return "Mit WSJT-X verbunden"
        case .failed(let err):   return "Fehler: \(err)"
        }
    }

    private func commitPort() {
        guard let value = UInt16(portString.trimmingCharacters(in: .whitespaces)),
              value >= 1024 else {
            portString = String(settings.port)
            return
        }
        settings.port = value
    }

    private func timeAgo(_ date: Date) -> String {
        let s = Int(Date().timeIntervalSince(date))
        if s < 60       { return "vor \(s) s" }
        if s < 3600     { return "vor \(s / 60) min" }
        if s < 86400    { return "vor \(s / 3600) h" }
        return DateFormatter.localizedString(from: date,
                                             dateStyle: .short,
                                             timeStyle: .short)
    }
}
