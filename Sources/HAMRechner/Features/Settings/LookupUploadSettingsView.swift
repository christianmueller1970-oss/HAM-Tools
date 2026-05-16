import SwiftUI

// Konsolidierter Settings-Tab "Lookup & Upload" — vereint die existierenden
// Callbook-Settings (QRZ XML + HamQTH funktional) mit Platzhaltern für
// alle weiteren Lookup-/Upload-Services (LoTW, eQSL, Club Log, HRDLOG,
// QRZCQ, HamCall) und die Award-Programme (POTA/SOTA/WWFF/BOTA — Konfig
// hier, Upload aber manuell aus dem jeweiligen Programm-Log).
//
// Aufbau:
//   • Top: globale Optionen (Primary/Secondary Callbook, Auto-Suggest-
//     Toggles, Master-Real-Time-Upload)
//   • Sub-Picker zur Service-Wahl
//   • Detail-Bereich pro Service mit einheitlichem Layout
struct LookupUploadSettingsView: View {
    @EnvironmentObject var callbook: CallbookSettings
    @EnvironmentObject var upload:   UploadServicesSettings

    @State private var selectedService: ServiceTab = .qrzXml

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            globalOptions
            Divider()
            servicePicker
            Divider()
            ScrollView {
                serviceDetail
                    .padding(16)
            }
        }
    }

    // MARK: - Globale Optionen (oben)

    private var globalOptions: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 16) {
                Picker("Primary Callbook", selection: $callbook.primaryService) {
                    ForEach(CallbookSettings.ServiceID.allCases) { id in
                        Text(id.rawValue).tag(id)
                    }
                }
                .frame(maxWidth: 220)

                // Secondary (Fallback): aktuell nicht im Model — UI vorbereitet,
                // Implementation folgt mit der echten Multi-Service-Lookup-Engine
                Picker("Secondary (Fallback)", selection: .constant("Keiner")) {
                    Text("Keiner").tag("Keiner")
                    Text("QRZ").tag("QRZ")
                    Text("HamQTH").tag("HamQTH")
                }
                .frame(maxWidth: 220)
                .disabled(true)
                .help("Fallback-Callbook bei Cache-Miss — folgt mit Multi-Service-Lookup-Engine")
            }

            // Auto-Suggest-Felder
            DisclosureGroup("Auto-Suggest aus Callbook (welche Felder befüllen)") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()),
                                    GridItem(.flexible())],
                          alignment: .leading, spacing: 6) {
                    Toggle("Name",       isOn: $upload.suggestName)
                    Toggle("QTH",        isOn: $upload.suggestQTH)
                    Toggle("Locator",    isOn: $upload.suggestLocator)
                    Toggle("Country",    isOn: $upload.suggestCountry)
                    Toggle("DXCC",       isOn: $upload.suggestDXCC)
                    Toggle("CQ-Zone",    isOn: $upload.suggestCQZone)
                    Toggle("ITU-Zone",   isOn: $upload.suggestITUZone)
                    Toggle("IOTA",       isOn: $upload.suggestIOTA)
                    Toggle("State",      isOn: $upload.suggestState)
                    Toggle("County",     isOn: $upload.suggestCounty)
                }
                .toggleStyle(.checkbox)
                .font(.callout)
                .padding(.top, 4)
            }
            .font(.subheadline)

            HStack(spacing: 12) {
                Toggle("Auto-Lookup beim TAB-Verlassen des Call-Felds",
                       isOn: $callbook.autoLookupOnTab)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                Spacer()
                Toggle("Real-Time-Upload (Master)",
                       isOn: $upload.realTimeUploadMasterEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .help("Aktiviert globalen Real-Time-Upload für Logbuch-Dienste — pro Service unten zusätzlich einzeln steuerbar")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Sub-Picker

    private var servicePicker: some View {
        Picker("Service", selection: $selectedService) {
            ForEach(ServiceTab.allCases, id: \.self) { tab in
                Text(tab.label).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Detail je Service

    @ViewBuilder
    private var serviceDetail: some View {
        switch selectedService {
        case .qrzXml:    qrzXmlPanel
        case .hamQTH:    hamQTHPanel
        case .qrzCQ:     placeholder(name: "QRZCQ",     web: "https://www.qrzcq.com")
        case .hamCall:   placeholder(name: "HamCall",   web: "https://hamcall.net")
        case .lotw:      placeholder(name: "LoTW (ARRL)",  web: "https://lotw.arrl.org",   showRT: true)
        case .eqsl:      placeholder(name: "eQSL.cc",      web: "https://www.eqsl.cc",     showRT: true)
        case .clublog:   placeholder(name: "Club Log",     web: "https://clublog.org",     showRT: true)
        case .hrdlog:    placeholder(name: "HRDLOG.net",   web: "https://www.hrdlog.net",  showRT: true)
        case .pota:      potaPanel
        case .sota:      programmePlaceholder(name: "SOTA (sotadata.org.uk)",
                                              web: "https://www.sotadata.org.uk")
        case .wwff:      programmePlaceholder(name: "WWFF (wwff.cc)",
                                              web: "https://wwff.cc")
        case .bota:      programmePlaceholder(name: "BOTA (bunkersontheair.com)",
                                              web: "https://bunkersontheair.com")
        }
    }

    // MARK: - QRZ XML (funktional)

    private var qrzXmlPanel: some View {
        servicePanel(name: "QRZ XML", web: "https://www.qrz.com") {
            VStack(alignment: .leading, spacing: 8) {
                credentialField(label: "Username", text: $callbook.qrzUsername)
                credentialField(label: "Password", text: $callbook.qrzPassword,
                                secure: true)
                statusLine(configured: callbook.qrzIsConfigured)
            }
        }
    }

    private var hamQTHPanel: some View {
        servicePanel(name: "HamQTH", web: "https://www.hamqth.com") {
            VStack(alignment: .leading, spacing: 8) {
                credentialField(label: "Username", text: $callbook.hamqthUsername)
                credentialField(label: "Password", text: $callbook.hamqthPassword,
                                secure: true)
                statusLine(configured: callbook.hamqthIsConfigured)
            }
        }
    }

    // POTA-Login: pota.app vergibt keinen Long-Lived-API-Key, sondern
    // arbeitet mit AWS Cognito (1h-Token). Wir speichern Username +
    // Passwort lokal (Passwort im macOS-Keychain) und holen das ID-Token
    // pro Upload-Session frisch.
    private var potaPanel: some View {
        servicePanel(name: "POTA (pota.app)", web: "https://pota.app") {
            VStack(alignment: .leading, spacing: 8) {
                credentialField(label: "Username", text: $upload.potaUsername)
                credentialField(label: "Passwort", text: $upload.potaPassword,
                                secure: true)
                Text("Dein pota.app-Account-Passwort. Wird ausschließlich lokal im macOS-Keychain gespeichert und nur beim manuellen Upload an Cognito gesendet, um ein Session-Token zu erhalten.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                statusLine(configured:
                    !upload.potaUsername.trimmingCharacters(in: .whitespaces).isEmpty &&
                    !upload.potaPassword.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    // MARK: - Platzhalter für Logbuch-Upload-Services

    private func placeholder(name: String, web: String, showRT: Bool = false) -> some View {
        servicePanel(name: name, web: web) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Credentials und Upload-Konfiguration folgen mit der Implementation der Service-API.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if showRT {
                    Text("Geplant: Auto-Upload nach QSO-Log + QSL-Mark + Confirmations-Sync.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                comingSoonBadge
            }
        }
    }

    // MARK: - Award-Programme (kein Real-Time-Upload)

    private func programmePlaceholder(name: String, web: String) -> some View {
        servicePanel(name: name, web: web) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Award-Programm-Konfiguration.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("Upload erfolgt **nicht automatisch** — du lädst aus dem jeweiligen Programm-Log (POTA/SOTA/WWFF/BOTA) manuell hoch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                comingSoonBadge
            }
        }
    }

    // MARK: - Bausteine

    private func servicePanel<Content: View>(
        name: String,
        web:  String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(name)
                    .font(.title3.bold())
                Spacer()
                if let url = URL(string: web) {
                    Link(destination: url) {
                        Label("Web-Seite", systemImage: "arrow.up.right.square")
                            .font(.caption)
                    }
                }
            }
            Divider()
            content()
        }
        .padding(14)
        .background(Color.gray.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func credentialField(label: String,
                                 text: Binding<String>,
                                 secure: Bool = false) -> some View {
        HStack {
            Text(label)
                .frame(width: 90, alignment: .trailing)
                .foregroundStyle(.secondary)
            if secure {
                SecureField("", text: text)
                    .textFieldStyle(.roundedBorder)
            } else {
                TextField("", text: text)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
            }
        }
    }

    private func statusLine(configured: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(configured ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            Text(configured ? "Konfiguriert" : "Nicht konfiguriert")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    private var comingSoonBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "hourglass")
            Text("Implementation folgt")
        }
        .font(.caption.bold())
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Color.orange.opacity(0.18))
        .foregroundStyle(.orange)
        .clipShape(Capsule())
    }

    // MARK: - Service-Tabs

    enum ServiceTab: String, CaseIterable, Hashable {
        case qrzXml, hamQTH, qrzCQ, hamCall
        case lotw, eqsl, clublog, hrdlog
        case pota, sota, wwff, bota

        var label: String {
            switch self {
            case .qrzXml:  return "QRZ"
            case .hamQTH:  return "HamQTH"
            case .qrzCQ:   return "QRZCQ"
            case .hamCall: return "HamCall"
            case .lotw:    return "LoTW"
            case .eqsl:    return "eQSL"
            case .clublog: return "Club Log"
            case .hrdlog:  return "HRDLOG"
            case .pota:    return "POTA"
            case .sota:    return "SOTA"
            case .wwff:    return "WWFF"
            case .bota:    return "BOTA"
            }
        }
    }
}
