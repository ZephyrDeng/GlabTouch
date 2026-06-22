import Foundation

struct MergeRequest: Identifiable, Hashable {
    let id: String
    let iid: Int
    let projectID: Int
    let title: String
    let description: String?
    let descriptionHtml: String?
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

    func withApproval(_ approved: Bool) -> MergeRequest {
        MergeRequest(
            id: id,
            iid: iid,
            projectID: projectID,
            title: title,
            description: description,
            descriptionHtml: descriptionHtml,
            author: author,
            sourceBranch: sourceBranch,
            targetBranch: targetBranch,
            state: state,
            approved: approved,
            reviewers: reviewers,
            diffStats: diffStats,
            headPipeline: headPipeline,
            webURL: webURL
        )
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
