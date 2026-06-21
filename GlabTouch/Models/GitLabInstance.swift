import Foundation

struct GitLabInstance: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var baseURL: URL
    var authMethod: AuthMethod
    var oauthClientID: String?
    var oauthRedirectURI: URL?

    enum AuthMethod: String, Codable {
        case pat
        case oauth
    }

    init(
        id: UUID = UUID(),
        name: String,
        baseURL: URL,
        authMethod: AuthMethod = .pat,
        oauthClientID: String? = nil,
        oauthRedirectURI: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.authMethod = authMethod
        self.oauthClientID = oauthClientID
        self.oauthRedirectURI = oauthRedirectURI
    }
}

enum GitLabInstanceList {
    static func upsert(_ instance: GitLabInstance, in instances: [GitLabInstance]) -> [GitLabInstance] {
        var result = instances
        if let index = result.firstIndex(where: { $0.id == instance.id }) {
            result[index] = instance
        } else {
            result.append(instance)
        }
        return result
    }

    static func remove(_ instance: GitLabInstance, from instances: [GitLabInstance]) -> [GitLabInstance] {
        instances.filter { $0.id != instance.id }
    }
}
