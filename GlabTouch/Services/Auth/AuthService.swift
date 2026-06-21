import Foundation
import AuthenticationServices
import UIKit

@MainActor
@Observable
final class AuthService {
    private(set) var currentInstance: GitLabInstance?
    private(set) var savedInstances: [GitLabInstance] = []
    private(set) var isAuthenticated = false
    private let keychain = KeychainService()

    private var token: String?
    private var oauthSession: ASWebAuthenticationSession?
    private let oauthPresentationProvider = WebAuthenticationPresentationContextProvider()

    var accessToken: String? { token }

    func loginWithPAT(instance: GitLabInstance, token: String) async throws {
        var mutableInstance = instance
        mutableInstance.authMethod = .pat

        try keychain.saveString(token, for: tokenKey(for: mutableInstance))
        try activateInstance(mutableInstance, token: token)

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

        let tokenResponse = try await exchangeAuthorizationCode(
            instance: mutableInstance,
            clientID: clientID,
            redirectURI: redirectURI,
            code: code,
            verifier: verifier
        )

        try keychain.saveString(tokenResponse.accessToken, for: tokenKey(for: mutableInstance))
        try activateInstance(mutableInstance, token: tokenResponse.accessToken)
    }

    func switchInstance(_ instance: GitLabInstance) throws {
        guard let storedToken = try keychain.loadString(for: tokenKey(for: instance)) else {
            throw AuthSessionError.missingStoredToken
        }

        try activateInstance(instance, token: storedToken)
    }

    func forgetInstance(_ instance: GitLabInstance) throws {
        try keychain.delete(for: tokenKey(for: instance))
        savedInstances = GitLabInstanceList.remove(instance, from: savedInstances)
        try saveInstances(savedInstances)

        if currentInstance?.id == instance.id {
            token = nil
            currentInstance = nil
            isAuthenticated = false
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
              let storedToken = try? keychain.loadString(for: tokenKey(for: instance))
        else { return }

        savedInstances = GitLabInstanceList.upsert(instance, in: savedInstances)
        try? saveInstances(savedInstances)

        self.currentInstance = instance
        self.token = storedToken
        self.isAuthenticated = true
    }

    private func tokenKey(for instance: GitLabInstance) -> String {
        "token_\(instance.id.uuidString)"
    }

    private func activateInstance(_ instance: GitLabInstance, token: String) throws {
        savedInstances = GitLabInstanceList.upsert(instance, in: savedInstances)
        try saveInstances(savedInstances)

        let data = try JSONEncoder().encode(instance)
        UserDefaults.standard.set(data, forKey: StorageKey.currentInstance)

        self.token = token
        self.currentInstance = instance
        self.isAuthenticated = true
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

    private func exchangeAuthorizationCode(
        instance: GitLabInstance,
        clientID: String,
        redirectURI: URL,
        code: String,
        verifier: String
    ) async throws -> OAuthTokenResponse {
        let tokenURL = instance.baseURL.appendingPathComponent("oauth/token")
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formURLEncodedData([
            "grant_type": "authorization_code",
            "client_id": clientID,
            "redirect_uri": redirectURI.absoluteString,
            "code": code,
            "code_verifier": verifier
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OAuthError.invalidTokenResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw OAuthError.tokenExchangeFailed(http.statusCode)
        }

        return try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
    }

    private func formURLEncodedData(_ values: [String: String]) -> Data {
        values
            .map { key, value in
                "\(key.urlFormEncoded)=\(value.urlFormEncoded)"
            }
            .sorted()
            .joined(separator: "&")
            .data(using: .utf8) ?? Data()
    }
}

private enum StorageKey {
    static let currentInstance = "currentInstance"
    static let savedInstances = "savedInstances"
}

extension AuthService {
    var baseURL: URL? { currentInstance?.baseURL }
}

private struct OAuthTokenResponse: Decodable {
    let accessToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }
}

enum OAuthError: LocalizedError {
    case authorizationCodeMissing
    case callbackMissing
    case invalidAuthorizationURL
    case invalidRedirectURI
    case invalidTokenResponse
    case randomGenerationFailed(OSStatus)
    case stateMismatch
    case tokenExchangeFailed(Int)

    var errorDescription: String? {
        switch self {
        case .authorizationCodeMissing: String(localized: "OAuth authorization code was missing.")
        case .callbackMissing: String(localized: "OAuth callback was missing.")
        case .invalidAuthorizationURL: String(localized: "OAuth authorization URL is invalid.")
        case .invalidRedirectURI: String(localized: "OAuth redirect URI is invalid.")
        case .invalidTokenResponse: String(localized: "OAuth token response is invalid.")
        case .randomGenerationFailed(let status): String(localized: "PKCE random generation failed: \(status)")
        case .stateMismatch: String(localized: "OAuth state mismatch.")
        case .tokenExchangeFailed(let statusCode): String(localized: "OAuth token exchange failed: HTTP \(statusCode)")
        }
    }
}

enum AuthSessionError: LocalizedError {
    case missingStoredToken

    var errorDescription: String? {
        switch self {
        case .missingStoredToken: String(localized: "Stored token was missing.")
        }
    }
}

private extension String {
    var urlFormEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlFormAllowed) ?? self
    }
}

private extension CharacterSet {
    static let urlFormAllowed: CharacterSet = {
        var set = CharacterSet.urlQueryAllowed
        set.remove(charactersIn: ":#[]@!$&'()*+,;=")
        return set
    }()
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
