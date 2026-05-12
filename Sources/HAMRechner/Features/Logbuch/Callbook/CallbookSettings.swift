import Foundation
import Combine

// Credentials für die Callbook-Services. Schreibt direkt in UserDefaults
// via Combine-Sink — robuster als didSet (der bei SecureField-Bindings
// auf macOS gelegentlich nicht zuverlässig feuert).
final class CallbookSettings: ObservableObject {
    // QRZ
    static let qrzUsernameKey  = "callbook.qrz.username"
    static let qrzPasswordKey  = "callbook.qrz.password"
    // HamQTH
    static let hamqthUsernameKey = "callbook.hamqth.username"
    static let hamqthPasswordKey = "callbook.hamqth.password"
    // Verhalten
    static let autoLookupKey       = "callbook.autoLookupOnTab"
    static let primaryServiceKey   = "callbook.primaryService"

    @Published var qrzUsername: String
    @Published var qrzPassword: String
    @Published var hamqthUsername: String
    @Published var hamqthPassword: String
    @Published var autoLookupOnTab: Bool
    // Primärer Dienst — der zweite ist Fallback.
    @Published var primaryService: ServiceID

    enum ServiceID: String, Codable, CaseIterable, Identifiable {
        case qrz    = "QRZ"
        case hamqth = "HamQTH"
        var id: String { rawValue }
    }

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Migration: einmalig aus den Legacy-UserDefaults-Domains in die
        // Shared-Suite übernehmen. Beseitigt das wiederkehrende »Credentials
        // sind wieder weg«-Problem zwischen SPM-Builds und Xcode-Builds.
        // Siehe Shared/SharedDefaults.swift.
        UserDefaults.migrateLegacyStringToShared(key: Self.qrzUsernameKey)
        UserDefaults.migrateLegacyStringToShared(key: Self.qrzPasswordKey)
        UserDefaults.migrateLegacyStringToShared(key: Self.hamqthUsernameKey)
        UserDefaults.migrateLegacyStringToShared(key: Self.hamqthPasswordKey)
        UserDefaults.migrateLegacyBoolToShared(key: Self.autoLookupKey)
        UserDefaults.migrateLegacyStringToShared(key: Self.primaryServiceKey)

        let store = UserDefaults.appShared
        self.qrzUsername     = store.string(forKey: Self.qrzUsernameKey)    ?? ""
        self.qrzPassword     = store.string(forKey: Self.qrzPasswordKey)    ?? ""
        self.hamqthUsername  = store.string(forKey: Self.hamqthUsernameKey) ?? ""
        self.hamqthPassword  = store.string(forKey: Self.hamqthPasswordKey) ?? ""
        self.autoLookupOnTab = (store.object(forKey: Self.autoLookupKey) as? Bool) ?? true
        let primaryRaw       = store.string(forKey: Self.primaryServiceKey) ?? "QRZ"
        self.primaryService  = ServiceID(rawValue: primaryRaw) ?? .qrz

        // Combine-basierte Persistenz — feuert zuverlässig bei jeder Änderung
        $qrzUsername    .dropFirst().sink { store.set($0, forKey: Self.qrzUsernameKey)    }.store(in: &cancellables)
        $qrzPassword    .dropFirst().sink { store.set($0, forKey: Self.qrzPasswordKey)    }.store(in: &cancellables)
        $hamqthUsername .dropFirst().sink { store.set($0, forKey: Self.hamqthUsernameKey) }.store(in: &cancellables)
        $hamqthPassword .dropFirst().sink { store.set($0, forKey: Self.hamqthPasswordKey) }.store(in: &cancellables)
        $autoLookupOnTab.dropFirst().sink { store.set($0, forKey: Self.autoLookupKey)     }.store(in: &cancellables)
        $primaryService .dropFirst().sink { store.set($0.rawValue, forKey: Self.primaryServiceKey) }.store(in: &cancellables)
    }

    var qrzIsConfigured: Bool {
        !qrzUsername.trimmingCharacters(in: .whitespaces).isEmpty
            && !qrzPassword.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var hamqthIsConfigured: Bool {
        !hamqthUsername.trimmingCharacters(in: .whitespaces).isEmpty
            && !hamqthPassword.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var anyConfigured: Bool { qrzIsConfigured || hamqthIsConfigured }
}
