import Foundation
import AuthenticationServices
import UIKit

@MainActor
@Observable
final class AuthService {
    private(set) var currentInstance: GitLabInstance?
    private(set) var savedInstances: [GitLabInstance] = []
    private(set) var isAuthenticated = false
    private(set) var refreshToken: String?
    private(set) var tokenType = GitLabInstance.AuthMethod.pat.rawValue
    var needsReauthentication = false
    var needsRefreshTokenWarning = false

    private let keychain = KeychainService()

    private var token: String?
    private var oauthSession: ASWebAuthenticationSession?
    private let oauthPresentationProvider = WebAuthenticationPresentationContextProvider()

    var accessToken: String? { token }

    init() {
        GitLabAPIClient.configure(authService: self)
    }

    func loginWithPAT(instance: GitLabInstance, token: String) async throws {
        var mutableInstance = instance
        mutableInstance.authMethod = .pat

        try keychain.saveAccessToken(token, for: mutableInstance)
        try keychain.saveRefreshToken(nil, for: mutableInstance)
        try keychain.saveTokenType(GitLabInstance.AuthMethod.pat.rawValue, for: mutableInstance)
        try activateInstance(
            mutableInstance,
            token: token,
            refreshToken: nil,
            tokenType: GitLabInstance.AuthMethod.pat.rawValue
        )
        needsRefreshTokenWarning = false
    }

    func loginWithOAuth(instance: GitLabInstance, clientID: String, redirectURI: URL) async throws {
        var mutableInstance = instance
        mutableInstance.authMethod = .oauth
        mutableInstance.oauthClientID = clientID
        mutableInstance.oauthRedirectURI = redirectURI

        let verifier = try OAuthPKCE.codeVerifier()
        let challenge = OAuthPKCE.codeChallenge(for: verifier)
        let state = UUID().uuidString
        let callbackURL = try await requestAuthorizationCode(
            instance: mutableInstance,
            clientID: clientID,
            redirectURI: redirectURI,
            codeChallenge: challenge,
            state: state
        )
        let callbackComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
        let callbackState = callbackComponents?.queryItems?.first { $0.name == "state" }?.value
        guard callbackState == state else {
            throw OAuthError.stateMismatch
        }
        guard let code = callbackComponents?.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw OAuthError.authorizationCodeMissing
        }

        let tokenResponse = try await OAuthPKCE.exchangeAuthorizationCode(
            instanceURL: mutableInstance.baseURL,
            clientID: clientID,
            redirectURI: redirectURI,
            code: code,
            codeVerifier: verifier
        )

        try keychain.saveAccessToken(tokenResponse.accessToken, for: mutableInstance)
        try keychain.saveRefreshToken(tokenResponse.refreshToken, for: mutableInstance)
        try keychain.saveTokenType(GitLabInstance.AuthMethod.oauth.rawValue, for: mutableInstance)
        try activateInstance(
            mutableInstance,
            token: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            tokenType: GitLabInstance.AuthMethod.oauth.rawValue
        )
        needsRefreshTokenWarning = tokenResponse.refreshToken == nil
    }

    func switchInstance(_ instance: GitLabInstance) throws {
        guard let storedToken = try keychain.loadAccessToken(for: instance) else {
            throw AuthSessionError.missingStoredToken
        }

        try activateInstance(
            instance,
            token: storedToken,
            refreshToken: try keychain.loadRefreshToken(for: instance),
            tokenType: try keychain.loadTokenType(for: instance) ?? instance.authMethod.rawValue
        )
    }

    func forgetInstance(_ instance: GitLabInstance) throws {
        try keychain.deleteCredentials(for: instance)
        savedInstances = GitLabInstanceList.remove(instance, from: savedInstances)
        try saveInstances(savedInstances)

        if currentInstance?.id == instance.id {
            token = nil
            refreshToken = nil
            tokenType = GitLabInstance.AuthMethod.pat.rawValue
            currentInstance = nil
            isAuthenticated = false
            needsReauthentication = false
            needsRefreshTokenWarning = false
            UserDefaults.standard.removeObject(forKey: StorageKey.currentInstance)
        }
    }

    func logout() throws {
        guard let instance = currentInstance else { return }
        try forgetInstance(instance)
    }

    func restoreSession() {
        savedInstances = loadSavedInstances()

        guard let data = UserDefaults.standard.data(forKey: "currentInstance"),
              let instance = try? JSONDecoder().decode(GitLabInstance.self, from: data),
              let storedToken = try? keychain.loadAccessToken(for: instance)
        else { return }

        savedInstances = GitLabInstanceList.upsert(instance, in: savedInstances)
        try? saveInstances(savedInstances)

        self.currentInstance = instance
        self.token = storedToken
        self.refreshToken = try? keychain.loadRefreshToken(for: instance)
        self.tokenType = (try? keychain.loadTokenType(for: instance)) ?? instance.authMethod.rawValue
        self.isAuthenticated = true
        self.needsReauthentication = false
        self.needsRefreshTokenWarning = instance.authMethod == .oauth && refreshToken == nil
        GitLabAPIClient.registerInstanceForTokenRefresh(instance)
    }

    func markNeedsReauthentication() {
        needsReauthentication = true
    }

    func clearNeedsReauthentication() {
        needsReauthentication = false
    }

    func reloadCurrentCredentials() throws {
        guard let instance = currentInstance else { return }
        guard let storedToken = try keychain.loadAccessToken(for: instance) else {
            throw AuthSessionError.missingStoredToken
        }

        token = storedToken
        refreshToken = try keychain.loadRefreshToken(for: instance)
        tokenType = try keychain.loadTokenType(for: instance) ?? instance.authMethod.rawValue
    }

    private func activateInstance(_ instance: GitLabInstance, token: String, refreshToken: String?, tokenType: String) throws {
        savedInstances = GitLabInstanceList.upsert(instance, in: savedInstances)
        try saveInstances(savedInstances)

        let data = try JSONEncoder().encode(instance)
        UserDefaults.standard.set(data, forKey: StorageKey.currentInstance)

        self.token = token
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.currentInstance = instance
        self.isAuthenticated = true
        self.needsReauthentication = false
        GitLabAPIClient.registerInstanceForTokenRefresh(instance)
    }

    private func saveInstances(_ instances: [GitLabInstance]) throws {
        let data = try JSONEncoder().encode(instances)
        UserDefaults.standard.set(data, forKey: StorageKey.savedInstances)
    }

    private func loadSavedInstances() -> [GitLabInstance] {
        guard let data = UserDefaults.standard.data(forKey: StorageKey.savedInstances),
              let instances = try? JSONDecoder().decode([GitLabInstance].self, from: data)
        else { return [] }
        return instances
    }

    private func requestAuthorizationCode(
        instance: GitLabInstance,
        clientID: String,
        redirectURI: URL,
        codeChallenge: String,
        state: String
    ) async throws -> URL {
        guard let callbackURLScheme = redirectURI.scheme else {
            throw OAuthError.invalidRedirectURI
        }

        var components = URLComponents(url: instance.baseURL.appendingPathComponent("oauth/authorize"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI.absoluteString),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "api read_user read_api"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state)
        ]
        guard let authorizationURL = components?.url else {
            throw OAuthError.invalidAuthorizationURL
        }

        do {
            let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
                let session = ASWebAuthenticationSession(url: authorizationURL, callbackURLScheme: callbackURLScheme) { callbackURL, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let callbackURL else {
                        continuation.resume(throwing: OAuthError.callbackMissing)
                        return
                    }
                    continuation.resume(returning: callbackURL)
                }
                session.presentationContextProvider = oauthPresentationProvider
                session.prefersEphemeralWebBrowserSession = true
                oauthSession = session
                session.start()
            }
            oauthSession = nil
            return callbackURL
        } catch {
            oauthSession = nil
            throw error
        }
    }

}

private enum StorageKey {
    static let currentInstance = "currentInstance"
    static let savedInstances = "savedInstances"
}

extension AuthService {
    var baseURL: URL? { currentInstance?.baseURL }
}

enum AuthSessionError: LocalizedError {
    case missingStoredToken

    var errorDescription: String? {
        switch self {
        case .missingStoredToken: String(localized: "Stored token was missing.")
        }
    }
}

@MainActor
private final class WebAuthenticationPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
