import Foundation
import AuthenticationServices

@MainActor
@Observable
final class AuthService {
    private(set) var currentInstance: GitLabInstance?
    private(set) var isAuthenticated = false
    private let keychain = KeychainService()

    private var token: String?

    var accessToken: String? { token }

    func loginWithPAT(instance: GitLabInstance, token: String) async throws {
        var mutableInstance = instance
        mutableInstance.authMethod = .pat

        try keychain.saveString(token, for: tokenKey(for: mutableInstance))
        try saveInstance(mutableInstance)

        self.token = token
        self.currentInstance = mutableInstance
        self.isAuthenticated = true
    }

    func loginWithOAuth(instance: GitLabInstance) async throws {
        // OAuth 2.0 PKCE flow — requires ASWebAuthenticationSession
        // Will be implemented with actual OAuth endpoints
        var mutableInstance = instance
        mutableInstance.authMethod = .oauth
        try saveInstance(mutableInstance)
        self.currentInstance = mutableInstance
    }

    func logout() throws {
        guard let instance = currentInstance else { return }
        try keychain.delete(for: tokenKey(for: instance))
        token = nil
        currentInstance = nil
        isAuthenticated = false
    }

    func restoreSession() {
        guard let data = UserDefaults.standard.data(forKey: "currentInstance"),
              let instance = try? JSONDecoder().decode(GitLabInstance.self, from: data),
              let storedToken = try? keychain.loadString(for: tokenKey(for: instance))
        else { return }

        self.currentInstance = instance
        self.token = storedToken
        self.isAuthenticated = true
    }

    private func tokenKey(for instance: GitLabInstance) -> String {
        "token_\(instance.id.uuidString)"
    }

    private func saveInstance(_ instance: GitLabInstance) throws {
        let data = try JSONEncoder().encode(instance)
        UserDefaults.standard.set(data, forKey: "currentInstance")
    }
}

extension AuthService {
    var baseURL: URL? { currentInstance?.baseURL }
}
