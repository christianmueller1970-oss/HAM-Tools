import Foundation
import Combine

// Credentials für die Callbook-Services. Schreibt direkt in UserDefaults
// via Combine-Sink — robuster als didSet (der bei SecureField-Bindings
// auf macOS gelegentlich nicht zuverlässig feuert).
final class CallbookSettings: ObservableObject {
    static let usernameKey   = "callbook.qrz.username"
    static let passwordKey   = "callbook.qrz.password"
    static let autoLookupKey = "callbook.autoLookupOnTab"

    @Published var qrzUsername: String
    @Published var qrzPassword: String
    @Published var autoLookupOnTab: Bool

    private var cancellables = Set<AnyCancellable>()

    init() {
        self.qrzUsername     = UserDefaults.standard.string(forKey: Self.usernameKey)   ?? ""
        self.qrzPassword     = UserDefaults.standard.string(forKey: Self.passwordKey)   ?? ""
        self.autoLookupOnTab = (UserDefaults.standard.object(forKey: Self.autoLookupKey) as? Bool) ?? true

        // Combine-basierte Persistenz — feuert zuverlässig bei jeder
        // Änderung (auch bei SecureField, wo didSet manchmal zickt).
        $qrzUsername
            .dropFirst()
            .sink { UserDefaults.standard.set($0, forKey: Self.usernameKey) }
            .store(in: &cancellables)
        $qrzPassword
            .dropFirst()
            .sink { UserDefaults.standard.set($0, forKey: Self.passwordKey) }
            .store(in: &cancellables)
        $autoLookupOnTab
            .dropFirst()
            .sink { UserDefaults.standard.set($0, forKey: Self.autoLookupKey) }
            .store(in: &cancellables)
    }

    // Computed — wird bei jedem View-Re-Render aus den @Published-Werten
    // neu berechnet. Kein Caching → kein Stale-State.
    var qrzIsConfigured: Bool {
        !qrzUsername.trimmingCharacters(in: .whitespaces).isEmpty
            && !qrzPassword.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
