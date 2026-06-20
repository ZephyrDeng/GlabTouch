import Foundation

@MainActor
@Observable
final class GitLabAPIClient {
    private let session = URLSession.shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private var baseURL: URL
    private var token: String

    init(baseURL: URL, token: String) {
        self.baseURL = baseURL
        self.token = token
    }

    func updateCredentials(baseURL: URL, token: String) {
        self.baseURL = baseURL
        self.token = token
    }

    // MARK: - GraphQL

    func graphQL<T: Decodable>(_ query: String, variables: [String: Any]? = nil) async throws -> T {
        let url = baseURL.appendingPathComponent("api/graphql")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["query": query]
        if let variables { body["variables"] = variables }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
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

    func rest<T: Decodable>(_ method: String, path: String, body: Encodable? = nil) async throws -> T {
        let url = baseURL.appendingPathComponent("api/v4").appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "PRIVATE-TOKEN")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try decoder.decode(T.self, from: data)
    }

    func restVoid(_ method: String, path: String) async throws {
        let url = baseURL.appendingPathComponent("api/v4").appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "PRIVATE-TOKEN")

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    // MARK: - Helpers

    private func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw GitLabAPIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw GitLabAPIError.httpError(http.statusCode)
        }
    }
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

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Invalid response from server"
        case .httpError(let code): "HTTP error \(code)"
        case .graphQLErrors(let msgs): msgs.joined(separator: "; ")
        case .emptyResponse: "Empty response from server"
        }
    }
}
