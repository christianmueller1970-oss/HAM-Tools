import Foundation
import AppKit
import CryptoKit
import SwiftUI

// Persistenter Disk-Cache für QRZ/HamQTH-Profilbilder. Eine Datei pro
// Bild-URL (Dateiname = SHA256(url)-Präfix 16 Hex), 30 Tage TTL. Bei
// expired/missing wird per HTTP geladen, geschrieben und das `NSImage`
// zurückgegeben. Bei jedem App-Start läuft beim ersten Cache-Zugriff
// einmalig ein Sweep, der Files älter als TTL wegräumt.
//
// Vorher (vor Cache): AsyncImage(url:) im QSOEntryPanel — frischer
// HTTP-Request bei jedem App-Start + Lookup-Spinner, jede Session
// fetcht alle Bilder neu.
@MainActor
final class QRZImageCache: ObservableObject {
    static let shared = QRZImageCache()

    private var cacheDir: URL
    private let ttl: TimeInterval = 30 * 24 * 3600  // 30 Tage
    private var didSweep = false

    private init() {
        // Fallback-Pfad. Wird via configure(dataRoot:) gleich nach App-Start
        // auf den echten Datenwurzel-Pfad gesetzt (s. HAMRechnerApp.init).
        let docs = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Documents")
        cacheDir = docs.appendingPathComponent("HAM-Tools/Cache/qrz-images",
                                                isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir,
                                                  withIntermediateDirectories: true)
    }

    /// Setzt das Cache-Verzeichnis auf <dataRoot>/Cache/qrz-images/.
    /// Wird einmal beim App-Start gerufen.
    func configure(dataRoot: AppDataRoot) {
        cacheDir = dataRoot.cacheDir.appendingPathComponent("qrz-images",
                                                             isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir,
                                                  withIntermediateDirectories: true)
    }

    /// Liefert das Bild für `url`. Bei Cache-Hit Disk-Read; sonst HTTP-
    /// Fetch + Cache-Schreiben. Returns nil bei Netzwerk- oder Decode-
    /// Fehlern (kein negativer Cache, der nächste Versuch lädt neu).
    func image(from url: URL) async -> NSImage? {
        if !didSweep {
            didSweep = true
            let dir = cacheDir
            let lifetime = ttl
            Task.detached(priority: .background) {
                Self.sweepExpired(in: dir, ttl: lifetime)
            }
        }
        let file = fileURL(for: url)
        if let img = readIfFresh(file) { return img }
        return await fetchAndStore(url: url, file: file)
    }

    private func fileURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let hex = digest.prefix(16).map { String(format: "%02x", $0) }.joined()
        return cacheDir.appendingPathComponent("\(hex).bin")
    }

    private func readIfFresh(_ file: URL) -> NSImage? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: file.path),
              let attrs = try? fm.attributesOfItem(atPath: file.path),
              let mod = attrs[.modificationDate] as? Date,
              Date().timeIntervalSince(mod) < ttl,
              let data = try? Data(contentsOf: file),
              let img = NSImage(data: data)
        else { return nil }
        return img
    }

    private func fetchAndStore(url: URL, file: URL) async -> NSImage? {
        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard let http = resp as? HTTPURLResponse,
                  http.statusCode == 200,
                  let img = NSImage(data: data)
            else { return nil }
            try? data.write(to: file)
            return img
        } catch {
            return nil
        }
    }

    // Sweep läuft auf einem Background-Task, daher nonisolated und ohne
    // Zugriff auf instance state außer dem URL-Snapshot.
    nonisolated private static func sweepExpired(in dir: URL, ttl: TimeInterval) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles])
        else { return }
        let now = Date()
        for f in files {
            guard let attrs = try? fm.attributesOfItem(atPath: f.path),
                  let mod = attrs[.modificationDate] as? Date
            else { continue }
            if now.timeIntervalSince(mod) > ttl {
                try? fm.removeItem(at: f)
            }
        }
    }
}

// Drop-in-Replacement für `AsyncImage`, das gegen den persistenten Cache
// arbeitet. Lebenszyklus: bei View-Erscheinen oder URL-Wechsel wird der
// Cache angefragt; bis das Image da ist, läuft der Lade-Indikator;
// bei Fehler kommt das Person-Fallback-Icon.
struct CachedQRZImage: View {
    let url: URL
    let theme: AppTheme

    @State private var image: NSImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            Rectangle().fill(theme.bgCard2)
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
            } else if failed {
                Image(systemName: "person.crop.square")
                    .font(.title)
                    .foregroundStyle(theme.textDim)
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .task(id: url.absoluteString) {
            failed = false
            image = nil
            let result = await QRZImageCache.shared.image(from: url)
            if Task.isCancelled { return }
            if let result {
                self.image = result
            } else {
                self.failed = true
            }
        }
    }
}
