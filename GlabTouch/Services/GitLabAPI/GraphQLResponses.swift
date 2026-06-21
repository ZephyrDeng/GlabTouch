import Foundation

struct CurrentUserResponse: Decodable {
    let currentUser: CurrentUser
}

struct CurrentUser: Decodable {
    let assignedMergeRequests: MRConnection?
    let authoredMergeRequests: MRConnection?
    let reviewRequestedMergeRequests: MRConnection?

    var mergeRequests: [MRNode] {
        let connection = assignedMergeRequests ?? authoredMergeRequests ?? reviewRequestedMergeRequests
        return connection?.nodes ?? []
    }

    var allMergeRequests: [MRNode] {
        var seen = Set<String>()
        return [
            assignedMergeRequests?.nodes ?? [],
            authoredMergeRequests?.nodes ?? [],
            reviewRequestedMergeRequests?.nodes ?? []
        ]
        .flatMap { $0 }
        .filter { mergeRequest in
            seen.insert(mergeRequest.id).inserted
        }
    }
}

struct MRConnection: Decodable {
    let nodes: [MRNode]
}

struct MRNode: Decodable {
    let id: String
    let iid: String
    let title: String
    let description: String?
    let sourceBranch: String
    let targetBranch: String
    let state: String
    let approved: Bool
    let webUrl: String?
    let project: ProjectNode
    let author: UserNode
    let reviewers: UserConnection
    let diffStats: [DiffStatNode]?
    let headPipeline: PipelineNode?

    func toMergeRequest() -> MergeRequest {
        let webURL = webUrl.flatMap { URL(string: $0) }
        let mrIID = Int(iid) ?? 0

        return MergeRequest(
            id: id,
            iid: mrIID,
            projectID: extractProjectID(from: project.id),
            title: title,
            description: description,
            author: author.toUser(),
            sourceBranch: sourceBranch,
            targetBranch: targetBranch,
            state: MergeRequest.State(rawValue: state.lowercased()) ?? .opened,
            approved: approved,
            reviewers: reviewers.nodes.map { $0.toUser() },
            diffStats: diffStats?.map { DiffStat(path: $0.path, additions: $0.additions, deletions: $0.deletions) },
            headPipeline: headPipeline?.toPipeline(
                mergeRequestTitle: title,
                mergeRequestIID: mrIID,
                projectFullPath: project.fullPath,
                webURL: webURL
            ),
            webURL: webURL
        )
    }

    private func extractProjectID(from gid: String) -> Int {
        Int(gid.split(separator: "/").last ?? "0") ?? 0
    }
}

struct ProjectNode: Decodable {
    let id: String
    let fullPath: String
}

struct UserNode: Decodable {
    let id: String
    let username: String
    let name: String
    let avatarUrl: String?

    func toUser() -> User {
        User(
            id: id,
            username: username,
            name: name,
            avatarURL: avatarUrl.flatMap { URL(string: $0) }
        )
    }
}

struct UserConnection: Decodable {
    let nodes: [UserNode]
}

struct DiffStatNode: Decodable {
    let path: String
    let additions: Int
    let deletions: Int
}

struct PipelineNode: Decodable {
    let id: String
    let status: String
    let ref: String?
    let sha: String?
    let stages: StageConnection?

    func toPipeline(
        mergeRequestTitle: String? = nil,
        mergeRequestIID: Int? = nil,
        projectFullPath: String? = nil,
        webURL: URL? = nil
    ) -> Pipeline {
        Pipeline(
            id: id,
            status: Pipeline.Status(rawValue: status.lowercased()) ?? .created,
            ref: ref,
            sha: sha,
            stages: stages?.nodes.map { $0.toStage() } ?? [],
            mergeRequestTitle: mergeRequestTitle,
            mergeRequestIID: mergeRequestIID,
            projectFullPath: projectFullPath,
            webURL: webURL
        )
    }
}

struct StageConnection: Decodable {
    let nodes: [StageNode]
}

struct StageNode: Decodable {
    let id: String
    let name: String
    let status: String?
    let jobs: JobConnection?

    func toStage() -> Stage {
        Stage(
            id: id,
            name: name,
            status: Pipeline.Status(rawValue: (status ?? "created").lowercased()) ?? .created,
            jobs: jobs?.nodes.map { $0.toJob() } ?? []
        )
    }
}

struct JobConnection: Decodable {
    let nodes: [JobNode]
}

struct JobNode: Decodable {
    let id: String
    let name: String
    let status: String

    func toJob() -> Job {
        Job(
            id: id,
            name: name,
            status: Pipeline.Status(rawValue: status.lowercased()) ?? .created
        )
    }
}
