import Foundation
import Security

struct StoredBankSession: Codable {
    let sessionID: String
    let accountUID: String
    let bankName: String
}

/// Persists the (non-secret) identifiers of the last authorized bank
/// connection in the Keychain, so the app can re-fetch the balance on
/// relaunch without repeating the PSD2 authorization flow.
final class BankSessionStore {
    private let service = "com.adrianjm.finanzas.enablebanking"
    private let account = "bank_session"

    func save(sessionID: String, accountUID: String, bankName: String) {
        clear()
        guard let data = try? JSONEncoder().encode(
            StoredBankSession(sessionID: sessionID, accountUID: accountUID, bankName: bankName)
        ) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    func load() -> StoredBankSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(StoredBankSession.self, from: data)
    }

    func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
