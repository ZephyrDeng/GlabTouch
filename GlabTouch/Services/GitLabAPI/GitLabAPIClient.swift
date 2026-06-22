import Foundation

@MainActor
@Observable
final class GitLabAPIClient {
    private static weak var authService: AuthService?
    private static let tokenRefresher = TokenRefresher()

    private let session = URLSession.shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = ISO8601DateFormatter.gitLabDate(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date: \(value)")
        }
        return d
    }()

    private var baseURL: URL
    private var token: String
    private var authMethod: GitLabInstance.AuthMethod

    init(baseURL: URL, token: String, authMethod: GitLabInstance.AuthMethod = .pat) {
        self.baseURL = baseURL
        self.token = token
        self.authMethod = authMethod
    }

    static func configure(authService: AuthService) {
        self.authService = authService
    }

    static func registerInstanceForTokenRefresh(_ instance: GitLabInstance) {
        Task {
            await tokenRefresher.register(instanceID: instance.id, instanceURL: instance.baseURL)
        }
    }

    func updateCredentials(baseURL: URL, token: String, authMethod: GitLabInstance.AuthMethod = .pat) {
        self.baseURL = baseURL
        self.token = token
        self.authMethod = authMethod
    }

    // MARK: - GraphQL

    func graphQL<T: Decodable>(_ query: String, variables: [String: Any]? = nil) async throws -> T {
        let url = baseURL.appendingPathComponent("api/graphql")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyAuthorization(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["query": query]
        if let variables { body["variables"] = variables }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data = try await data(for: request)
        let wrapper = try decoder.decode(GraphQLResponse<T>.self, from: data)

        if let errors = wrapper.errors, !errors.isEmpty {
            throw GitLabAPIError.graphQLErrors(errors.map(\.message))
        }
        guard let result = wrapper.data else {
            throw GitLabAPIError.emptyResponse
        }
        return result
    }

    // MARK: - REST

    func rest<T: Decodable>(_ method: String, path: String, queryItems: [URLQueryItem] = [], body: Encodable? = nil) async throws -> T {
        var request = URLRequest(url: restURL(path: path, queryItems: queryItems))
        request.httpMethod = method
        applyAuthorization(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let data = try await data(for: request)
        return try decoder.decode(T.self, from: data)
    }

    func restVoid(_ method: String, path: String) async throws {
        var request = URLRequest(url: restURL(path: path))
        request.httpMethod = method
        applyAuthorization(to: &request)

        _ = try await data(for: request)
    }

    func mergeRequestChanges(projectID: Int, mrIID: Int) async throws -> [DiffFile] {
        let response: MergeRequestChangesResponse = try await rest(
            "GET",
            path: "projects/\(projectID)/merge_requests/\(mrIID)/changes"
        )
        return response.changes
    }

    func pipelineDashboard() async throws -> [Pipeline] {
        let response: CurrentUserResponse = try await graphQL(GraphQLQueries.pipelineDashboard)
        return response.currentUser.allMergeRequests.compactMap { $0.toMergeRequest().headPipeline }
    }

    func pipelineJobs(projectID: Int, pipelineID: Int) async throws -> [PipelineJob] {
        try await rest(
            "GET",
            path: "projects/\(projectID)/pipelines/\(pipelineID)/jobs",
            queryItems: [
                URLQueryItem(name: "include_retried", value: "true"),
                URLQueryItem(name: "per_page", value: "100")
            ]
        )
    }

    func retryPipeline(projectID: Int, pipelineID: Int) async throws {
        try await restVoid("POST", path: "projects/\(projectID)/pipelines/\(pipelineID)/retry")
    }

    func cancelPipeline(projectID: Int, pipelineID: Int) async throws {
        try await restVoid("POST", path: "projects/\(projectID)/pipelines/\(pipelineID)/cancel")
    }

    func playJob(projectID: Int, jobID: Int) async throws -> PipelineJob {
        try await rest("POST", path: "projects/\(projectID)/jobs/\(jobID)/play")
    }

    func retryJob(projectID: Int, jobID: Int) async throws -> PipelineJob {
        try await rest("POST", path: "projects/\(projectID)/jobs/\(jobID)/retry")
    }

    func cancelJob(projectID: Int, jobID: Int) async throws -> PipelineJob {
        try await rest("POST", path: "projects/\(projectID)/jobs/\(jobID)/cancel")
    }

    func jobTrace(projectID: Int, jobID: Int) async throws -> String {
        var request = URLRequest(url: restURL(path: "projects/\(projectID)/jobs/\(jobID)/trace"))
        request.httpMethod = "GET"
        applyAuthorization(to: &request)

        let data = try await data(for: request)
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - Helpers

    private func restURL(path: String, queryItems: [URLQueryItem] = []) -> URL {
        let url = baseURL.appendingPathComponent("api/v4").appendingPathComponent(path)
        guard !queryItems.isEmpty,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return url }
        components.queryItems = queryItems
        return components.url ?? url
    }

    private func applyAuthorization(to request: inout URLRequest) {
        switch authMethod {
        case .pat:
            request.setValue(token, forHTTPHeaderField: "PRIVATE-TOKEN")
        case .oauth:
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func data(for request: URLRequest, allowsRefresh: Bool = true) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        if isAuthenticationRequired(response) {
            guard allowsRefresh, await refreshTokenAfterAuthenticationFailure() else {
                Self.authService?.markNeedsReauthentication()
                throw GitLabAPIError.authenticationRequired
            }

            var retryRequest = request
            applyAuthorization(to: &retryRequest)
            return try await self.data(for: retryRequest, allowsRefresh: false)
        }

        try validateResponse(response)
        return data
    }

    private func refreshTokenAfterAuthenticationFailure() async -> Bool {
        guard let authService = Self.authService,
              let instance = authService.currentInstance,
              let clientID = instance.oauthClientID
        else { return false }

        await Self.tokenRefresher.register(instanceID: instance.id, instanceURL: instance.baseURL)
        let result = await Self.tokenRefresher.refreshIfNeeded(
            instanceURL: instance.baseURL,
            currentToken: token,
            refreshToken: authService.refreshToken,
            tokenType: authService.tokenType
        ) { refreshToken, instanceURL in
            try await OAuthPKCE.refreshToken(refreshToken: refreshToken, instanceURL: instanceURL, clientID: clientID)
        }

        switch result {
        case .refreshed(let newToken):
            token = newToken
            try? authService.reloadCurrentCredentials()
            return true
        case .needsReauth:
            authService.markNeedsReauthentication()
            return false
        }
    }

    private func isAuthenticationRequired(_ response: URLResponse) -> Bool {
        guard let http = response as? HTTPURLResponse else { return false }
        return http.statusCode == 401
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw GitLabAPIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw GitLabAPIError.httpError(http.statusCode)
        }
    }
}

private extension ISO8601DateFormatter {
    static func gitLabDate(from value: String) -> Date? {
        gitLabFractionalFormatter.date(from: value) ?? gitLabFormatter.date(from: value)
    }

    private static var gitLabFormatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }

    private static var gitLabFractionalFormatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
}

struct MergeRequestChangesResponse: Decodable {
    let changes: [DiffFile]
}

struct GraphQLResponse<T: Decodable>: Decodable {
    let data: T?
    let errors: [GraphQLError]?
}

struct GraphQLError: Decodable {
    let message: String
}

enum GitLabAPIError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case graphQLErrors([String])
    case emptyResponse
    case authenticationRequired

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Invalid response from server"
        case .httpError(let code): "HTTP error \(code)"
        case .graphQLErrors(let msgs): msgs.joined(separator: "; ")
        case .emptyResponse: "Empty response from server"
        case .authenticationRequired: "Authentication required"
        }
    }
}
