import SwiftUI
import WebKit

// MARK: - Antennen-Simulator (NEC2 via WASM)
//
// Native-Integration via WKWebView auf die Web-Version.
// Vorteil: keine doppelte Implementation, keine WASM-in-Swift-Komplikation.
// Web-App läuft komplett im Browser, kein Backend, keine Datenleitung nötig.

struct AntennenSimulatorView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isLoading: Bool = true
    @State private var loadError: String? = nil

    // ?embedded=1 aktiviert in der Web-App den schlanken Modus ohne eigene Sidebar
    private let simulatorURL = URL(string: "https://toolbox.funkwelt.net/?embedded=1#/antennensim")!
    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        ZStack {
            theme.bgApp.ignoresSafeArea()

            WKWebViewWrapper(url: simulatorURL,
                             isLoading: $isLoading,
                             loadError: $loadError)
                .opacity(loadError == nil ? 1 : 0)

            if isLoading {
                VStack(spacing: 14) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Antennen-Simulator wird geladen…")
                        .font(.callout)
                        .foregroundStyle(theme.textSecondary)
                    Text("(NEC2-Engine ~270 KB, lädt einmal beim ersten Aufruf)")
                        .font(.caption)
                        .foregroundStyle(theme.textDim)
                }
            }

            if let err = loadError {
                VStack(spacing: 14) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 44))
                        .foregroundStyle(theme.accentRed)
                    Text("Antennen-Simulator nicht erreichbar")
                        .font(.title3.bold())
                        .foregroundStyle(theme.textPrimary)
                    Text(err)
                        .font(.callout)
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                    Text("Online-Verbindung prüfen — der Antennen-Simulator wird live von toolbox.funkwelt.net geladen.")
                        .font(.caption)
                        .foregroundStyle(theme.textDim)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                    Button("Erneut versuchen") {
                        loadError = nil
                        isLoading = true
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
                }
                .padding(40)
            }
        }
        .navigationTitle("Antennen-Simulator")
    }
}

// MARK: - WKWebView SwiftUI Bridge

private struct WKWebViewWrapper: NSViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var loadError: String?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Worker + WASM laufen problemlos im WKWebView
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Wenn loadError zurückgesetzt wurde, neu laden
        if loadError == nil && nsView.url?.absoluteString != url.absoluteString && !isLoading {
            // nichts — Erstladen reicht
        }
        if loadError == nil && isLoading && nsView.isLoading == false && nsView.url == nil {
            nsView.load(URLRequest(url: url))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WKWebViewWrapper
        init(_ parent: WKWebViewWrapper) { self.parent = parent }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.loadError = nil
            }
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.loadError = error.localizedDescription
            }
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.loadError = error.localizedDescription
            }
        }
    }
}
