import Foundation
import Security

struct StoredBankSession: Codable {
    let sessionID: String
    let accountUID: String
}

/// Persists the Enable Banking session_id per linked account in the Keychain
/// (keyed by accountUID), so the app can re-fetch balances/transactions on
/// relaunch without repeating the PSD2 authorization flow. Non-sensitive
/// account metadata (bank name, IBAN, cached balance) lives in SwiftData
/// (see Sources/Persistence/Models.swift), not here.
final class BankSessionStore {
    private let service = "com.adrianjm.finanzas.bank"

    func save(sessionID: String, accountUID: String) {
        delete(accountUID: accountUID)
        guard let data = try? JSONEncoder().encode(
            StoredBankSession(sessionID: sessionID, accountUID: accountUID)
        ) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountUID,
            kSecValueData as String: data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    func load(accountUID: String) -> StoredBankSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountUID,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(StoredBankSession.self, from: data)
    }

    func loadAll() -> [StoredBankSession] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let items = result as? [Data] else { return [] }
        return items.compactMap { try? JSONDecoder().decode(StoredBankSession.self, from: $0) }
    }

    func delete(accountUID: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountUID
        ]
        SecItemDelete(query as CFDictionary)
    }
}
