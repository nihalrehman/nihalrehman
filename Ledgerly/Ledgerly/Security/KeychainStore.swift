import Foundation
import Security

enum KeychainError: Error, LocalizedError {
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error"
            return "Keychain error \(status): \(message)"
        }
    }
}

/// Minimal wrapper around the iOS Keychain for small secrets.
///
/// Items are stored with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`:
/// they can only be read while the device is unlocked, are never synced
/// to iCloud Keychain and are never migrated to another device via backups.
enum KeychainStore {
    static let service = "com.ledgerly.app.secure"

    private static func baseQuery(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    /// Returns the stored data, or nil if no item exists.
    /// Throws for any other failure (e.g. device locked) so callers never
    /// mistake a transient error for a missing item.
    static func read(_ account: String) throws -> Data? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            return item as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    static func save(_ data: Data, account: String) throws {
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        var status = SecItemUpdate(baseQuery(account) as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = baseQuery(account)
            addQuery.merge(attributes) { _, new in new }
            addQuery[kSecAttrSynchronizable as String] = kCFBooleanFalse
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    static func delete(_ account: String) {
        SecItemDelete(baseQuery(account) as CFDictionary)
    }
}
