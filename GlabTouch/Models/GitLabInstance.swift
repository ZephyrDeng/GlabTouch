import Foundation

struct GitLabInstance: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var baseURL: URL
    var authMethod: AuthMethod

    enum AuthMethod: String, Codable {
        case pat
        case oauth
    }

    init(id: UUID = UUID(), name: String, baseURL: URL, authMethod: AuthMethod = .pat) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.authMethod = authMethod
    }
}
