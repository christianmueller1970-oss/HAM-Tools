import Foundation
import UserNotifications

final class WatchListStore: ObservableObject {
    @Published var entries: [String] = [] {
        didSet { saveCalls() }
    }
    @Published var dxccEntries: [String] = [] {
        didSet { saveDXCC() }
    }
    @Published var notificationsEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "watchNotificationsEnabled")
            if notificationsEnabled { Self.requestPermission() }
        }
    }

    init() {
        loadCalls()
        loadDXCC()
        notificationsEnabled = UserDefaults.standard.bool(forKey: "watchNotificationsEnabled")
    }

    // MARK: - Match (Call/Präfix)

    /// Gibt true zurück wenn der DX-Call mit einem Eintrag beginnt oder exakt übereinstimmt.
    func matches(_ call: String) -> Bool {
        guard !entries.isEmpty else { return false }
        let upper = call.uppercased()
        return entries.contains { upper == $0 || upper.hasPrefix($0) }
    }

    // MARK: - Match (DXCC)

    /// Gibt true zurück wenn das Land in der DXCC-Watchliste steht.
    func matchesDXCC(_ country: String) -> Bool {
        guard !dxccEntries.isEmpty else { return false }
        return dxccEntries.contains(country)
    }

    /// Übergreifender Match (Call ODER DXCC) — nutzt der ViewModel.
    func matches(spot: DXSpot) -> AlertReason? {
        if matches(spot.dxCall)         { return .call }
        if matchesDXCC(spot.country)    { return .dxcc(spot.country) }
        return nil
    }

    enum AlertReason {
        case call
        case dxcc(String)
    }

    // MARK: - CRUD Calls

    func add(_ entry: String) {
        let cleaned = entry.trimmingCharacters(in: .whitespaces).uppercased()
        guard !cleaned.isEmpty, !entries.contains(cleaned) else { return }
        entries.append(cleaned)
    }

    func remove(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
    }

    // MARK: - CRUD DXCC

    func addDXCC(_ country: String) {
        let cleaned = country.trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty, !dxccEntries.contains(cleaned) else { return }
        dxccEntries.append(cleaned)
    }

    func removeDXCC(at offsets: IndexSet) {
        dxccEntries.remove(atOffsets: offsets)
    }

    // MARK: - Notifications

    static func requestPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func sendNotification(for spot: DXSpot, reason: AlertReason = .call) {
        guard notificationsEnabled else { return }
        let content        = UNMutableNotificationContent()
        switch reason {
        case .call:
            content.title  = "DX Alert: \(spot.dxCall)"
        case .dxcc(let country):
            content.title  = "DXCC Alert: \(country) (\(spot.dxCall))"
        }
        content.body       = "\(spot.displayFreq) kHz  ·  \(spot.mode)  ·  \(spot.country)"
        content.sound      = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString,
                                        content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    // MARK: - Persistence

    private func saveCalls() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: "watchListEntries")
        }
    }
    private func loadCalls() {
        if let data    = UserDefaults.standard.data(forKey: "watchListEntries"),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            entries = decoded
        }
    }
    private func saveDXCC() {
        if let data = try? JSONEncoder().encode(dxccEntries) {
            UserDefaults.standard.set(data, forKey: "watchListDXCCEntries")
        }
    }
    private func loadDXCC() {
        if let data    = UserDefaults.standard.data(forKey: "watchListDXCCEntries"),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            dxccEntries = decoded
        }
    }
}

// MARK: - Most-Wanted DXCC-Auswahl für den Watch-Picker
//
// Subset von DXCC_DATA: nur seltene Entitäten (Bouvet, Crozet, Heard, Pratas usw.)
// und kleine/abgelegene Inselgebiete. Häufige Länder (Switzerland, Germany, USA …)
// stehen bewusst NICHT in dieser Liste — die kann man ggf. über die Call-/Präfix-
// Watch-Liste abdecken (Eintrag „HB9", „DL" usw.).

let MOST_WANTED_DXCC: [String] = [
    "Agalega/St.Brandon", "Amsterdam & St.Paul",
    "Austral Is.", "Baker/Howland",
    "Bouvet Is.", "Brit. Virgin Is.",
    "Chatham Is.", "Christmas Is.",
    "Cocos (Keeling)", "Crozet Is.",
    "Easter Is.", "Falkland Is.",
    "Fernando Noronha", "Glorioso Is.",
    "Heard Is.", "Johnston Atoll",
    "Juan de Nova", "Juan Fernandez",
    "Kerguelen", "Kermadec Is.",
    "Kure Atoll", "Lord Howe",
    "Macquarie Is.", "Marquesas Is.",
    "Marshall Is.", "Mellish Reef",
    "Midway", "Montserrat",
    "New Caledonia", "Norfolk Is.",
    "North Korea", "NZ Subantarctic",
    "Ogasawara", "Palau",
    "Palmyra/Jarvis", "Pitcairn Is.",
    "Pratas Is.", "Prince Edward",
    "Rodrigues Is.", "Sable Is.",
    "Samoa", "San Felix",
    "Scarborough Reef", "Spratly Is.",
    "St. Helena", "St. Paul Is.",
    "St. Peter & Paul", "Swains Is.",
    "Tokelau", "Trindade",
    "Tristan da Cunha", "Tromelin",
    "Turks & Caicos", "Tuvalu",
    "Vatican City", "Wake Is.",
    "Wallis & Futuna",
].sorted()
