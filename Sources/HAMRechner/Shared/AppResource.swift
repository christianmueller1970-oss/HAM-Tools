import Foundation

/// Robuster Resource-Lookup, der `Bundle.module` umgeht.
///
/// `Bundle.module` ist eine SwiftPM-synthesized `static let`-Property mit
/// `fatalError` als Fallback. Auf macOS 26.5 liefert `Bundle.init(url:)`
/// für die in `Bundle.module` versuchten Kandidaten nil — die Folge ist
/// `EXC_BREAKPOINT` (assertionFailure) **beim ersten Resource-Zugriff
/// nach App-Start**, also direkt in `HAMRechnerApp.init()` über die
/// SQLite-Initializer der Outdoor-Services (BOTARefService etc.).
///
/// Wir suchen das SwiftPM-Resource-Bundle deshalb selber — toleranter
/// gegenüber Bundle-Format-Schwankungen (flat vs. regular) und ohne
/// Crash-Fallback. Wirkt für alle Bundle.module-Konsumenten in der App:
/// BOTARefService (bota-refs.csv), TRXProfile (trx-profiles.json),
/// BandplanModel (bandplan.json), ContestService (contests.json),
/// RechnerBeschreibung (*.md).
enum AppResource {
    private static let bundleName = "HAMRechner_HAMRechner"

    static func url(forResource name: String, withExtension ext: String) -> URL? {
        let fm = FileManager.default

        // Mögliche Kandidaten für das Resource-Bundle, in Reihenfolge der
        // Wahrscheinlichkeit:
        //   1) App-Bundle/Contents/Resources/HAMRechner_HAMRechner.bundle (Production-DMG)
        //   2) /.bundleURL/HAMRechner_HAMRechner.bundle (Dev-Build, neben Binary)
        //   3) Bundle.main.resourceURL direkt (falls Resources im Hauptbundle landen)
        let candidates: [URL] = [
            Bundle.main.resourceURL?.appendingPathComponent(bundleName).appendingPathExtension("bundle"),
            Bundle.main.bundleURL.appendingPathComponent(bundleName).appendingPathExtension("bundle"),
            Bundle.main.resourceURL,
            Bundle.main.bundleURL,
        ].compactMap { $0 }

        for url in candidates {
            // (a) Regulärer Bundle-Loader — funktioniert wenn Contents/Info.plist
            //     korrekt ist und macOS das Bundle akzeptiert.
            if let bundle = Bundle(url: url),
               let r = bundle.url(forResource: name, withExtension: ext) {
                return r
            }
            // (b) Flat-Layout: Resource direkt im Bundle-Folder.
            let flat = url.appendingPathComponent(name).appendingPathExtension(ext)
            if fm.fileExists(atPath: flat.path) {
                return flat
            }
            // (c) Regular-Layout, aber Bundle(url:) hat versagt — direkt nach
            //     Contents/Resources/<name>.<ext> greifen.
            let nested = url.appendingPathComponent("Contents/Resources")
                            .appendingPathComponent(name)
                            .appendingPathExtension(ext)
            if fm.fileExists(atPath: nested.path) {
                return nested
            }
        }
        return nil
    }
}
