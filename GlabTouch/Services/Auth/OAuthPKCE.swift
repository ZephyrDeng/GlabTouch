import CryptoKit
import Foundation
import Security

enum OAuthPKCE {
    static func codeVerifier() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw OAuthError.randomGenerationFailed(status)
        }
        return Data(bytes).base64URLEncodedString()
    }

    static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }

    static func exchangeAuthorizationCode(
        instanceURL: URL,
        clientID: String,
        redirectURI: URL,
        code: String,
        codeVerifier: String
    ) async throws -> OAuthTokenResponse {
        try await requestToken(
            instanceURL: instanceURL,
            body: [
                "grant_type": "authorization_code",
                "client_id": clientID,
                "redirect_uri": redirectURI.absoluteString,
                "code": code,
                "code_verifier": codeVerifier
            ]
        )
    }

    static func refreshToken(refreshToken: String, instanceURL: URL, clientID: String) async throws -> OAuthTokenResponse {
        try await requestToken(
            instanceURL: instanceURL,
            body: [
                "grant_type": "refresh_token",
                "client_id": clientID,
                "refresh_token": refreshToken
            ]
        )
    }

    private static func requestToken(instanceURL: URL, body: [String: String]) async throws -> OAuthTokenResponse {
        let tokenURL = instanceURL.appendingPathComponent("oauth/token")
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formURLEncodedData(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OAuthError.invalidTokenResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw OAuthError.tokenExchangeFailed(http.statusCode)
        }

        return try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
    }

    private static func formURLEncodedData(_ values: [String: String]) -> Data {
        values
            .map { key, value in
                "\(key.urlFormEncoded)=\(value.urlFormEncoded)"
            }
            .sorted()
            .joined(separator: "&")
            .data(using: .utf8) ?? Data()
    }
}

struct OAuthTokenResponse: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
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

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
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
