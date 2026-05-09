import SwiftUI

struct SendSpotSheet: View {
    @Environment(\.dismiss) private var dismiss
    let callsign: String
    let onSend: (Double, String, String) -> Void

    @State private var dxCall    = ""
    @State private var frequency = ""
    @State private var mode      = "FT8"
    @State private var comment   = ""

    private let modes = ["FT8","FT4","CW","SSB","RTTY","PSK31","JS8","WSPR","DIGI"]
    private let quickBands: [(label: String, freq: Double)] = [
        ("160m", 1840.0), ("80m", 3573.0), ("40m", 7074.0),
        ("20m", 14074.0), ("15m", 21074.0), ("10m", 28074.0)
    ]

    private var preview: String {
        guard !dxCall.isEmpty, !frequency.isEmpty else { return "" }
        let c = "\(mode) \(comment)".trimmingCharacters(in: .whitespaces)
        return "DX \(frequency) \(dxCall.uppercased()) \(c)".prefix(60).description
    }

    private var isValid: Bool {
        !dxCall.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(frequency.replacingOccurrences(of: ",", with: ".")) != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "dot.radiowaves.right")
                    .foregroundStyle(.white)
                Text("DX-Spot senden")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.blue)

            // Form
            Form {
                Section("DX-Station") {
                    HStack {
                        Text("Rufzeichen")
                            .frame(width: 110, alignment: .trailing)
                            .foregroundStyle(.secondary)
                        TextField("z.B. VK2AB", text: $dxCall)
                            .font(.system(.body, design: .monospaced))
                            .textCase(.uppercase)
                    }
                    HStack {
                        Text("Frequenz (kHz)")
                            .frame(width: 110, alignment: .trailing)
                            .foregroundStyle(.secondary)
                        TextField("z.B. 14074.0", text: $frequency)
                            .font(.system(.body, design: .monospaced))
                    }
                    HStack(alignment: .center) {
                        Text("Band")
                            .frame(width: 110, alignment: .trailing)
                            .foregroundStyle(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(quickBands, id: \.label) { b in
                                    Button(b.label) {
                                        frequency = String(b.freq)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .tint(.blue)
                                }
                            }
                        }
                    }
                }

                Section("Betriebsart & Kommentar") {
                    HStack {
                        Text("Mode")
                            .frame(width: 110, alignment: .trailing)
                            .foregroundStyle(.secondary)
                        Picker("", selection: $mode) {
                            ForEach(modes, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 100)
                    }
                    HStack {
                        Text("Kommentar")
                            .frame(width: 110, alignment: .trailing)
                            .foregroundStyle(.secondary)
                        TextField("Optional", text: $comment)
                    }
                }

                Section("Vorschau") {
                    HStack {
                        Image(systemName: "terminal")
                            .foregroundStyle(.secondary)
                        Text(preview.isEmpty ? "—" : preview)
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(preview.isEmpty ? .secondary : .primary)
                    }
                    Text("Gesendet als: \(callsign)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            // Buttons
            HStack {
                Button("Abbrechen") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Senden") { send() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.bar)
        }
        .frame(width: 480, height: 420)
    }

    private func send() {
        let call = dxCall.trimmingCharacters(in: .whitespaces).uppercased()
        let freqStr = frequency.replacingOccurrences(of: ",", with: ".")
        guard let freq = Double(freqStr) else { return }
        let fullComment = "\(mode) \(comment)".trimmingCharacters(in: .whitespaces)
        onSend(freq, call, fullComment)
        dismiss()
    }
}
