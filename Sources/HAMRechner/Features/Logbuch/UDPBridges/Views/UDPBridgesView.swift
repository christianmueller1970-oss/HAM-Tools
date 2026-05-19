import SwiftUI

// Settings-Tab für alle UDP-Logger-Bridges (WSJT-X / JTDX / JS8Call / MSHV /
// N1MM). Liste mit Add/Remove, pro Eintrag Toggle + Port + Protocol-Picker
// + Status-Pille. Ersetzt das alte single-instance `WsjtxBridgeView`.
struct UDPBridgesView: View {
    @EnvironmentObject var settings: UDPBridgesSettings
    @EnvironmentObject var service:  UDPBridgesService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("UDP-Bridges") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Externe Logger können geloggte QSOs (und N1MM zusätzlich Spots) per UDP an HAM-Tools senden. Jeder Eintrag entspricht einem Listener auf einem Port mit einem Protokoll-Adapter. Mehrere Bridges können parallel laufen, solange die Ports unterschiedlich sind.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Divider()
                        ForEach(settings.bridges) { bridge in
                            bridgeRow(bridge)
                            if bridge.id != settings.bridges.last?.id {
                                Divider().opacity(0.5)
                            }
                        }
                        Divider()
                        HStack {
                            Button {
                                addBridge(protocol: .wsjtxCompatible)
                            } label: {
                                Label("WSJT-X-Bridge hinzufügen", systemImage: "plus.circle")
                            }
                            Button {
                                addBridge(protocol: .n1mmContestUDP)
                            } label: {
                                Label("N1MM-Bridge hinzufügen", systemImage: "plus.circle")
                            }
                        }
                    }
                    .padding(10)
                }

                GroupBox("Konfigurations-Hinweise") {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("WSJT-X / JTDX / JS8Call / MSHV", systemImage: "waveform")
                            .font(.subheadline.bold())
                        Text("In WSJT-X: «Datei → Einstellungen → Berichten» — UDP-Server 127.0.0.1, Port wie oben gesetzt, «QSO-Mitteilungen weiterleiten» an. JS8Call hat denselben Dialog. MSHV findet die Option unter «UDP-Broadcast-Settings» mit Logged-QSO-Broadcast.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Divider()
                        Label("N1MM Logger+", systemImage: "stopwatch")
                            .font(.subheadline.bold())
                        Text("In N1MM: «Config → Configure Ports → Broadcast Data» — «Contacts» und «Spots» ankreuzen, IP `127.0.0.1:12060`. HAM-Tools liest ContactInfo-Pakete (QSOs ins aktive Log) und Spot-Pakete (in den DX-Cluster-Stream).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Wichtig: laufen WSJT-X und MSHV gleichzeitig, müssen sie verschiedene UDP-Ports haben — sonst gehen Datagramme verloren.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding(.top, 4)
                    }
                    .padding(10)
                }
            }
            .padding()
        }
    }

    // MARK: - Bridge-Zeile

    @ViewBuilder
    private func bridgeRow(_ bridge: UDPBridge) -> some View {
        let rt = service.runtime[bridge.id]
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Toggle("", isOn: enableBinding(for: bridge))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                TextField("Name", text: nameBinding(for: bridge))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)
                Picker("", selection: protocolBinding(for: bridge)) {
                    ForEach(UDPBridgeProtocol.allCases) { proto in
                        Text(proto.shortName).tag(proto)
                    }
                }
                .labelsHidden()
                .frame(width: 160)
                TextField("Port", text: portBinding(for: bridge))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .font(.system(.body, design: .monospaced))
                Spacer()
                statusPill(for: bridge, rt: rt)
                Button(role: .destructive) {
                    settings.remove(bridge.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Bridge entfernen")
            }
            HStack(spacing: 6) {
                Text(bridge.bridgeProtocol.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let rt {
                    Text("·").foregroundStyle(.secondary)
                    Text("\(rt.datagramCount) Datagramme")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let v = rt.version {
                        Text("· v\(v)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let err = rt.lastError {
                        Text("· Fehler: \(err)")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func statusPill(for bridge: UDPBridge,
                             rt: UDPBridgesService.BridgeRuntimeState?) -> some View {
        let (color, text) = statusColorAndText(bridge: bridge, rt: rt)
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(0.12))
        )
    }

    private func statusColorAndText(bridge: UDPBridge,
                                     rt: UDPBridgesService.BridgeRuntimeState?) -> (Color, String) {
        guard bridge.enabled else { return (.secondary, "aus") }
        guard let rt else { return (.yellow, "startet …") }
        switch rt.state {
        case .stopped:              return (.secondary, "gestoppt")
        case .listening:            return (.yellow, "lauschend")
        case .linked:               return (.green, "aktiv")
        case .failed:               return (.red, "Fehler")
        }
    }

    // MARK: - Bindings (jeder Edit ruft settings.update(...) auf)

    private func enableBinding(for bridge: UDPBridge) -> Binding<Bool> {
        Binding(
            get: { bridge.enabled },
            set: { newValue in
                var copy = bridge
                copy.enabled = newValue
                settings.update(copy)
            }
        )
    }

    private func nameBinding(for bridge: UDPBridge) -> Binding<String> {
        Binding(
            get: { bridge.name },
            set: { newValue in
                var copy = bridge
                copy.name = newValue
                settings.update(copy)
            }
        )
    }

    private func portBinding(for bridge: UDPBridge) -> Binding<String> {
        Binding(
            get: { String(bridge.port) },
            set: { newValue in
                guard let v = UInt16(newValue.trimmingCharacters(in: .whitespaces)),
                      v >= 1024 else { return }
                var copy = bridge
                copy.port = v
                settings.update(copy)
            }
        )
    }

    private func protocolBinding(for bridge: UDPBridge) -> Binding<UDPBridgeProtocol> {
        Binding(
            get: { bridge.bridgeProtocol },
            set: { newValue in
                var copy = bridge
                copy.bridgeProtocol = newValue
                // Port intelligent nachziehen, wenn der noch dem alten Default
                // entsprach.
                if copy.port == bridge.bridgeProtocol.defaultPort {
                    copy.port = newValue.defaultPort
                }
                settings.update(copy)
            }
        )
    }

    private func addBridge(protocol proto: UDPBridgeProtocol) {
        let name = proto == .wsjtxCompatible ? "Neue WSJT-X-Bridge" : "Neue N1MM-Bridge"
        settings.add(UDPBridge(
            name: name,
            port: proto.defaultPort,
            enabled: false,
            bridgeProtocol: proto
        ))
    }
}
