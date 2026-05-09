import SwiftUI

struct SendSpotSheet: View {
    let callsign: String
    let onDismiss: () -> Void
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

            ScrollView {
                VStack(spacing: 12) {
                    section("DX-Station") {
                        row("Rufzeichen") {
                            NativeTextField(text: $dxCall, placeholder: "z.B. VK2AB")
                                .frame(height: 22)
                        }
                        row("Frequenz (kHz)") {
                            NativeTextField(text: $frequency, placeholder: "z.B. 14074.0")
                                .frame(height: 22)
                        }
                        row("Band") {
                            HStack(spacing: 6) {
                                ForEach(quickBands, id: \.label) { b in
                                    Button(b.label) { frequency = String(b.freq) }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .tint(.blue)
                                }
                            }
                        }
                    }

                    section("Betriebsart & Kommentar") {
                        row("Mode") {
                            Picker("", selection: $mode) {
                                ForEach(modes, id: \.self) { Text($0).tag($0) }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 100)
                        }
                        row("Kommentar") {
                            NativeTextField(
                                text: $comment,
                                placeholder: "Optional",
                                font: .systemFont(ofSize: NSFont.systemFontSize)
                            )
                            .frame(height: 22)
                        }
                    }

                    section("Vorschau") {
                        HStack {
                            Image(systemName: "terminal")
                                .foregroundStyle(.secondary)
                            Text(preview.isEmpty ? "—" : preview)
                                .font(.system(.callout, design: .monospaced))
                                .foregroundStyle(preview.isEmpty ? .secondary : .primary)
                            Spacer()
                        }
                        Text("Gesendet als: \(callsign)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
            }

            // Buttons
            HStack {
                Button("Abbrechen") { onDismiss() }
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

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            VStack(spacing: 6) {
                content()
            }
            .padding(10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func row(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        HStack {
            Text(label)
                .frame(width: 110, alignment: .trailing)
                .foregroundStyle(.secondary)
            content()
            Spacer(minLength: 0)
        }
    }

    private func send() {
        let call = dxCall.trimmingCharacters(in: .whitespaces).uppercased()
        let freqStr = frequency.replacingOccurrences(of: ",", with: ".")
        guard let freq = Double(freqStr) else { return }
        let fullComment = "\(mode) \(comment)".trimmingCharacters(in: .whitespaces)
        onSend(freq, call, fullComment)
        onDismiss()
    }
}
