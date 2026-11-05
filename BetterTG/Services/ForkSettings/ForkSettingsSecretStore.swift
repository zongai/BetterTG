// ForkSettingsSecretStore.swift
// Sync passphrase for API-key encryption, stored in iCloud Keychain (Apple ID).

import Foundation
import Security

/// Reads/writes the encryption passphrase used for sealing API keys in Saved Messages.
/// Uses `kSecAttrSynchronizable` so the secret follows the user's Apple ID via iCloud Keychain.
enum ForkSettingsSecretStore {
    private static let service = "com.zongai.BetterTG.forkSettings"
    private static let account = "apiKeysPassphrase"

    /// Whether a passphrase is already available from (iCloud) Keychain.
    static var hasPassphrase: Bool {
        (try? loadPassphrase())?.isEmpty == false
    }

    static func loadPassphrase() throws -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data,
              let text = String(data: data, encoding: .utf8), !text.isEmpty
        else {
            throw StoreError.unexpectedStatus(status)
        }
        return text
    }

    /// Saves passphrase to the Keychain and marks it synchronizable (iCloud Keychain).
    static func savePassphrase(_ passphrase: String) throws {
        let trimmed = passphrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw StoreError.emptyPassphrase }
        let data = Data(trimmed.utf8)

        // Remove any existing item (sync + non-sync) first.
        try? deletePassphrase()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: true,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData as String: data,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw StoreError.unexpectedStatus(status) }
    }

    /// Generates a random passphrase, stores it in iCloud Keychain, returns it.
    @discardableResult
    static func ensurePassphrase() throws -> String {
        if let existing = try loadPassphrase(), !existing.isEmpty {
            return existing
        }
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else { throw StoreError.unexpectedStatus(status) }
        let generated = Data(bytes).base64EncodedString()
        try savePassphrase(generated)
        return generated
    }

    static func deletePassphrase() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw StoreError.unexpectedStatus(status)
        }
    }

    enum StoreError: LocalizedError {
        case emptyPassphrase
        case unexpectedStatus(OSStatus)

        var errorDescription: String? {
            switch self {
            case .emptyPassphrase: return "口令不能为空"
            case .unexpectedStatus(let s): return "钥匙串错误 (\(s))"
            }
        }
    }
}
