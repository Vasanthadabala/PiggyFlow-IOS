import Foundation
import Security

/// Keychain-backed storage for values that must not sit in `UserDefaults`.
///
/// `UserDefaults` is a plist in the app container — readable from a backup and not
/// encrypted at rest beyond the device passcode. Credentials and identity tokens belong
/// here instead.
final class KeychainManager {

    static let shared = KeychainManager()

    /// Namespaces entries so they can't collide with other apps sharing a group.
    private let service: String

    init(service: String = Bundle.main.bundleIdentifier ?? "com.piggyflowlabs.PiggyFlow") {
        self.service = service
    }

    enum KeychainError: LocalizedError {
        case unexpectedStatus(OSStatus)

        var errorDescription: String? {
            switch self {
            case .unexpectedStatus(let status):
                let message = SecCopyErrorMessageString(status, nil) as String? ?? "status \(status)"
                return "Keychain error: \(message)"
            }
        }
    }

    // MARK: - Data

    func save(_ data: Data, for account: String) throws {
        // Delete-then-add keeps this an upsert; SecItemUpdate would fail on first write.
        try? delete(account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func read(_ account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    func delete(_ account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: - String convenience

    func saveString(_ value: String, for account: String) throws {
        guard let data = value.data(using: .utf8) else { return }
        try save(data, for: account)
    }

    func readString(_ account: String) -> String? {
        guard let data = read(account) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
