import Foundation

struct MergeRequest: Identifiable, Hashable {
    let id: String
    let iid: Int
    let projectID: Int
    let title: String
    let description: String?
    let author: User
    let sourceBranch: String
    let targetBranch: String
    let state: State
    let approved: Bool
    let reviewers: [User]
    let diffStats: [DiffStat]?
    let headPipeline: Pipeline?
    let webURL: URL?

    enum State: String, Codable {
        case opened, closed, merged, locked
    }
}

struct User: Identifiable, Hashable, Codable {
    let id: String
    let username: String
    let name: String
    let avatarURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, username, name
        case avatarURL = "avatarUrl"
    }
}

struct DiffStat: Hashable {
    let path: String
    let additions: Int
    let deletions: Int
}
