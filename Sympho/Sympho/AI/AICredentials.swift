import Foundation
import Security

nonisolated protocol AICredentialStore: Sendable {
    func apiKey(for providerID: String) async throws -> String?
    func saveAPIKey(_ apiKey: String, for providerID: String) async throws
    func deleteAPIKey(for providerID: String) async throws
}

nonisolated enum AICredentialError: LocalizedError, Sendable {
    case keychain(OSStatus)
    case invalidValue

    var errorDescription: String? {
        switch self {
        case .keychain(let status):
            return "Keychain operation failed (\(status))."
        case .invalidValue:
            return "The credential could not be read from Keychain."
        }
    }
}

actor KeychainAICredentialStore: AICredentialStore {
    private let service = "com.sympho.ai.credentials"

    func apiKey(for providerID: String) async throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: providerID,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw AICredentialError.keychain(status) }
        guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
            throw AICredentialError.invalidValue
        }
        return value
    }

    func saveAPIKey(_ apiKey: String, for providerID: String) async throws {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty, let data = cleanKey.data(using: .utf8) else {
            throw AICredentialError.invalidValue
        }

        try await deleteAPIKey(for: providerID)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: providerID,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw AICredentialError.keychain(status) }
    }

    func deleteAPIKey(for providerID: String) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: providerID
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AICredentialError.keychain(status)
        }
    }
}
