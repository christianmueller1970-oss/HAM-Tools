import Foundation
import UserNotifications

final class WatchListStore: ObservableObject {
    @Published var entries: [String] = [] {
        didSet { save() }
    }
    @Published var notificationsEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "watchNotificationsEnabled")
            if notificationsEnabled { Self.requestPermission() }
        }
    }

    init() {
        load()
        notificationsEnabled = UserDefaults.standard.bool(forKey: "watchNotificationsEnabled")
    }

    // MARK: - Match

    /// Gibt true zurück wenn der DX-Call mit einem Eintrag beginnt oder exakt übereinstimmt.
    func matches(_ call: String) -> Bool {
        guard !entries.isEmpty else { return false }
        let upper = call.uppercased()
        return entries.contains { upper == $0 || upper.hasPrefix($0) }
    }

    // MARK: - CRUD

    func add(_ entry: String) {
        let cleaned = entry.trimmingCharacters(in: .whitespaces).uppercased()
        guard !cleaned.isEmpty, !entries.contains(cleaned) else { return }
        entries.append(cleaned)
    }

    func remove(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
    }

    // MARK: - Notifications

    static func requestPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func sendNotification(for spot: DXSpot) {
        guard notificationsEnabled else { return }
        let content        = UNMutableNotificationContent()
        content.title      = "DX Alert: \(spot.dxCall)"
        content.body       = "\(spot.displayFreq) kHz  ·  \(spot.mode)  ·  \(spot.country)"
        content.sound      = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString,
                                        content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: "watchListEntries")
        }
    }

    private func load() {
        if let data    = UserDefaults.standard.data(forKey: "watchListEntries"),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            entries = decoded
        }
    }
}
