import Foundation
import Combine

// Credentials für die Callbook-Services. UserDefaults für jetzt — bei
// Bedarf später auf Keychain migrieren (braucht Codesigning-Setup).
@MainActor
final class CallbookSettings: ObservableObject {
    private let usernameKey = "callbook.qrz.username"
    private let passwordKey = "callbook.qrz.password"
    private let autoLookupKey = "callbook.autoLookupOnTab"

    @Published var qrzUsername: String {
        didSet {
            UserDefaults.standard.set(qrzUsername, forKey: usernameKey)
            recomputeIsConfigured()
        }
    }
    @Published var qrzPassword: String {
        didSet {
            UserDefaults.standard.set(qrzPassword, forKey: passwordKey)
            recomputeIsConfigured()
        }
    }
    @Published var autoLookupOnTab: Bool {
        didSet { UserDefaults.standard.set(autoLookupOnTab, forKey: autoLookupKey) }
    }

    // Als @Published statt computed — damit SwiftUI zuverlässig re-rendert
    // wenn Username/Passwort sich ändern.
    @Published private(set) var qrzIsConfigured: Bool = false

    init() {
        self.qrzUsername = UserDefaults.standard.string(forKey: usernameKey) ?? ""
        self.qrzPassword = UserDefaults.standard.string(forKey: passwordKey) ?? ""
        self.autoLookupOnTab = (UserDefaults.standard.object(forKey: autoLookupKey) as? Bool) ?? true
        recomputeIsConfigured()
    }

    private func recomputeIsConfigured() {
        qrzIsConfigured = !qrzUsername.trimmingCharacters(in: .whitespaces).isEmpty
            && !qrzPassword.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
