import Foundation
import Security

// Minimaler Keychain-Wrapper für das POTA-Passwort. Service-Eintrag pro
// Account (= Username), keine ObjC-Bridge-Abhängigkeit, nur Security.framework
// direkt. Reicht für unsere zwei Operationen (read/write/delete einer
// einzigen Password-Zeile).
enum PotaKeychain {
    private static let service = "com.hb9hji.hamrechner.pota"

    static func setPassword(_ password: String, account: String) {
        let acc = account.trimmingCharacters(in: .whitespaces)
        guard !acc.isEmpty else { return }

        // Erst löschen, dann neu anlegen — vermeidet "duplicate item"-Fehler
        // und erspart das Aufdröseln zwischen SecItemAdd vs SecItemUpdate.
        delete(account: acc)

        guard let data = password.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: acc,
            kSecValueData as String:   data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        _ = SecItemAdd(query as CFDictionary, nil)
    }

    static func password(account: String) -> String? {
        let acc = account.trimmingCharacters(in: .whitespaces)
        guard !acc.isEmpty else { return nil }

        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: acc,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let s = String(data: data, encoding: .utf8) else { return nil }
        return s
    }

    static func delete(account: String) {
        let acc = account.trimmingCharacters(in: .whitespaces)
        guard !acc.isEmpty else { return }
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: acc,
        ]
        _ = SecItemDelete(query as CFDictionary)
    }
}
