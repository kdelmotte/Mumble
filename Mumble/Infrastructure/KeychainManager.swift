import Foundation
import Security

// MARK: - Keychain Errors

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case updateFailed(OSStatus)
    case unexpectedData
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save item to Keychain (OSStatus \(status)): \(SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error")"
        case .deleteFailed(let status):
            return "Failed to delete item from Keychain (OSStatus \(status)): \(SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error")"
        case .updateFailed(let status):
            return "Failed to update item in Keychain (OSStatus \(status)): \(SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error")"
        case .unexpectedData:
            return "Unexpected data format retrieved from Keychain"
        case .encodingFailed:
            return "Failed to encode the API key as UTF-8 data"
        }
    }
}

// MARK: - KeychainManager

final class KeychainManager {

    static let shared = KeychainManager()

    private let service = "com.mumble.apikey"
    private let account = "api-key"

    private init() {}

    // MARK: - Public API

    /// Saves an API key to the Keychain. If a key already exists it will be updated.
    func saveAPIKey(_ key: String) throws {
        guard let data = key.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        // Attempt to update an existing item first.
        let query = baseQuery()
        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)

        if updateStatus == errSecSuccess {
            return
        }

        if updateStatus != errSecItemNotFound {
            throw KeychainError.updateFailed(updateStatus)
        }

        // No existing item – add a new one.
        var addQuery = baseQuery()
        addQuery[kSecValueData as String] = data

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError.saveFailed(addStatus)
        }
    }

    /// Retrieves the stored API key from the Keychain, or `nil` if none exists.
    func getAPIKey() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    /// Deletes the stored API key from the Keychain.
    func deleteAPIKey() throws {
        let query = baseQuery()
        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    // MARK: - Private Helpers

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
