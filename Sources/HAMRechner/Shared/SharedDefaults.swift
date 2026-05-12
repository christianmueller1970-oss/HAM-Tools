import Foundation

extension UserDefaults {
    /// Stabile, build-übergreifende UserDefaults-Domain. Hintergrund:
    /// `UserDefaults.standard` hängt am Bundle-Identifier; Swift-Package-Builds
    /// (kein Bundle) fallen auf den Executable-Namen zurück, Xcode-Release-Builds
    /// nutzen ihren Bundle-Identifier, ein installiertes DMG noch einen anderen.
    /// Dadurch "vergessen" wir Credentials/Settings sobald man zwischen Build-
    /// Varianten wechselt. Diese Suite zentralisiert das.
    static let appShared: UserDefaults =
        UserDefaults(suiteName: "com.hb9hji.hamrechner.shared") ?? .standard

    /// Einmalige Migration für einen einzelnen Key: liest aus den Legacy-
    /// Domains (UserDefaults.standard + bekannte Bundle-IDs) und schreibt in
    /// `appShared`, falls dort noch nichts steht. Idempotent.
    static func migrateLegacyStringToShared(key: String) {
        guard appShared.string(forKey: key) == nil else { return }
        let legacy: [UserDefaults] = [
            .standard,
            UserDefaults(suiteName: "com.hb9hji.hamrechner.dev") ?? .standard,
            UserDefaults(suiteName: "com.hb9hji.hamrechner")     ?? .standard,
            UserDefaults(suiteName: "HAMRechner")                ?? .standard,
        ]
        if let v = legacy.compactMap({ $0.string(forKey: key) }).first {
            appShared.set(v, forKey: key)
        }
    }

    /// Same for Bool — falls in appShared kein Wert steht, schaue in den
    /// Legacy-Domains nach.
    static func migrateLegacyBoolToShared(key: String) {
        guard appShared.object(forKey: key) == nil else { return }
        let legacy: [UserDefaults] = [
            .standard,
            UserDefaults(suiteName: "com.hb9hji.hamrechner.dev") ?? .standard,
            UserDefaults(suiteName: "com.hb9hji.hamrechner")     ?? .standard,
            UserDefaults(suiteName: "HAMRechner")                ?? .standard,
        ]
        if let v = legacy.compactMap({ $0.object(forKey: key) as? Bool }).first {
            appShared.set(v, forKey: key)
        }
    }
}
