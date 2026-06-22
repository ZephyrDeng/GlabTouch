import Foundation
import Security

@MainActor
@Observable
final class KeychainService {
    private let serviceName = "com.zephyrdeng.GlabTouch"

    func save(_ data: Data, for key: String) throws {
        try delete(for: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    func load(for key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.loadFailed(status)
        }
    }

    func delete(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    func saveString(_ value: String, for key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        try save(data, for: key)
    }

    func loadString(for key: String) throws -> String? {
        guard let data = try load(for: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func saveAccessToken(_ token: String, for instance: GitLabInstance) throws {
        try saveAccessToken(token, instanceID: instance.id)
    }

    func loadAccessToken(for instance: GitLabInstance) throws -> String? {
        try loadAccessToken(instanceID: instance.id)
    }

    func saveRefreshToken(_ refreshToken: String?, for instance: GitLabInstance) throws {
        try saveRefreshToken(refreshToken, instanceID: instance.id)
    }

    func loadRefreshToken(for instance: GitLabInstance) throws -> String? {
        try loadRefreshToken(instanceID: instance.id)
    }

    func saveTokenType(_ tokenType: String, for instance: GitLabInstance) throws {
        try saveTokenType(tokenType, instanceID: instance.id)
    }

    func loadTokenType(for instance: GitLabInstance) throws -> String? {
        try loadTokenType(instanceID: instance.id)
    }

    func deleteCredentials(for instance: GitLabInstance) throws {
        try delete(for: accessTokenKey(for: instance.id))
        try delete(for: refreshTokenKey(for: instance.id))
        try delete(for: tokenTypeKey(for: instance.id))
    }

    func saveAccessToken(_ token: String, instanceID: UUID) throws {
        try saveString(token, for: accessTokenKey(for: instanceID))
    }

    func loadAccessToken(instanceID: UUID) throws -> String? {
        try loadString(for: accessTokenKey(for: instanceID))
    }

    func saveRefreshToken(_ refreshToken: String?, instanceID: UUID) throws {
        let key = refreshTokenKey(for: instanceID)
        guard let refreshToken else {
            try delete(for: key)
            return
        }
        try saveString(refreshToken, for: key)
    }

    func loadRefreshToken(instanceID: UUID) throws -> String? {
        try loadString(for: refreshTokenKey(for: instanceID))
    }

    func saveTokenType(_ tokenType: String, instanceID: UUID) throws {
        try saveString(tokenType, for: tokenTypeKey(for: instanceID))
    }

    func loadTokenType(instanceID: UUID) throws -> String? {
        try loadString(for: tokenTypeKey(for: instanceID))
    }

    private func accessTokenKey(for instanceID: UUID) -> String {
        "token_\(instanceID.uuidString)"
    }

    private func refreshTokenKey(for instanceID: UUID) -> String {
        "refresh_token_\(instanceID.uuidString)"
    }

    private func tokenTypeKey(for instanceID: UUID) -> String {
        "token_type_\(instanceID.uuidString)"
    }
}

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status): "Keychain save failed: \(status)"
        case .loadFailed(let status): "Keychain load failed: \(status)"
        case .deleteFailed(let status): "Keychain delete failed: \(status)"
        case .encodingFailed: "Failed to encode value"
        }
    }
}
