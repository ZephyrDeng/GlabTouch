import Foundation

enum TokenRefreshResult: Equatable, Sendable {
    case refreshed(String)
    case needsReauth
}

actor TokenRefresher {
    typealias OAuthRefresh = @Sendable (_ refreshToken: String, _ instanceURL: URL) async throws -> OAuthTokenResponse
    typealias TokenPersistence = @Sendable (_ instanceID: UUID, _ response: OAuthTokenResponse, _ fallbackRefreshToken: String) async throws -> Void

    private var refreshTask: Task<TokenRefreshResult, Never>?
    private var instanceIDsByURL: [URL: UUID] = [:]
    private var refreshedTokens: [String: String] = [:]
    private let persistTokens: TokenPersistence

    init(persistTokens: @escaping TokenPersistence = TokenRefresher.keychainPersistence) {
        self.persistTokens = persistTokens
    }

    func register(instanceID: UUID, instanceURL: URL) {
        instanceIDsByURL[instanceURL] = instanceID
    }

    func refreshIfNeeded(
        instanceURL: URL,
        currentToken: String,
        refreshToken: String?,
        tokenType: String,
        oauthRefresh: @escaping OAuthRefresh
    ) async -> TokenRefreshResult {
        guard tokenType == GitLabInstance.AuthMethod.oauth.rawValue,
              let refreshToken
        else {
            return .needsReauth
        }

        if let refreshedToken = refreshedTokens[currentToken] {
            return .refreshed(refreshedToken)
        }

        if let refreshTask {
            return await refreshTask.value
        }

        guard let instanceID = instanceIDsByURL[instanceURL] else {
            return .needsReauth
        }

        let persistTokens = persistTokens
        let task = Task<TokenRefreshResult, Never> {
            do {
                let response = try await oauthRefresh(refreshToken, instanceURL)
                try await persistTokens(instanceID, response, refreshToken)
                return .refreshed(response.accessToken)
            } catch {
                return .needsReauth
            }
        }

        refreshTask = task
        let result = await task.value
        refreshTask = nil

        if case .refreshed(let newToken) = result {
            refreshedTokens[currentToken] = newToken
        }

        return result
    }

    private static let keychainPersistence: TokenPersistence = { instanceID, response, fallbackRefreshToken in
        try await MainActor.run {
            let keychain = KeychainService()
            try keychain.saveAccessToken(response.accessToken, instanceID: instanceID)
            try keychain.saveRefreshToken(response.refreshToken ?? fallbackRefreshToken, instanceID: instanceID)
            try keychain.saveTokenType(GitLabInstance.AuthMethod.oauth.rawValue, instanceID: instanceID)
        }
    }
}
