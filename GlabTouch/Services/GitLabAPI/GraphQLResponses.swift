import Foundation

struct CurrentUserResponse: Decodable {
    let currentUser: CurrentUser
}

struct CurrentUser: Decodable {
    let username: String?
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

    var reviewWorkspaceProjects: [ReviewWorkspaceProject] {
        var seen = Set<Int>()
        return allMergeRequests
            .map { $0.project.toReviewWorkspaceProject() }
            .filter { project in
                seen.insert(project.projectID).inserted
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
    let descriptionHtml: String?
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
            projectID: project.numericID,
            title: title,
            description: description,
            descriptionHtml: descriptionHtml,
            author: author.toUser(),
            sourceBranch: sourceBranch,
            targetBranch: targetBranch,
            state: MergeRequest.State(rawValue: state.lowercased()) ?? .opened,
            approved: approved,
            reviewers: reviewers.nodes.map { $0.toUser() },
            diffStats: diffStats?.map { DiffStat(path: $0.path, additions: $0.additions, deletions: $0.deletions) },
            headPipeline: headPipeline?.toPipeline(
                projectID: project.numericID,
                mergeRequestTitle: title,
                mergeRequestIID: mrIID,
                projectFullPath: project.fullPath,
                webURL: webURL
            ),
            webURL: webURL
        )
    }

}

struct ProjectNode: Decodable {
    let id: String
    let fullPath: String

    var numericID: Int {
        Int(id.split(separator: "/").last ?? "0") ?? 0
    }

    func toReviewWorkspaceProject() -> ReviewWorkspaceProject {
        ReviewWorkspaceProject(projectID: numericID, fullPath: fullPath)
    }
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
        projectID: Int? = nil,
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
            pipelineID: extractNumericID(from: id),
            projectID: projectID,
            mergeRequestTitle: mergeRequestTitle,
            mergeRequestIID: mergeRequestIID,
            projectFullPath: projectFullPath,
            webURL: webURL
        )
    }

    private func extractNumericID(from gid: String) -> Int? {
        guard let value = gid.split(separator: "/").last else { return nil }
        return Int(value)
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
    let webUrl: String?

    func toJob() -> Job {
        Job(
            id: id,
            name: name,
            status: Pipeline.Status(rawValue: status.lowercased()) ?? .created,
            jobID: extractNumericID(from: id),
            webURL: webUrl.flatMap { URL(string: $0) }
        )
    }

    private func extractNumericID(from gid: String) -> Int? {
        guard let value = gid.split(separator: "/").last else { return nil }
        return Int(value)
    }
}

struct RESTPipelineNode: Decodable {
    let id: Int
    let status: Pipeline.Status
    let source: String?
    let ref: String?
    let sha: String?
    let updatedAt: Date?
    let webURL: URL?
    let user: RESTUserNode?

    func toMyTriggeredPipeline(project: ReviewWorkspaceProject) -> Pipeline {
        Pipeline(
            id: "\(project.projectID):\(id)",
            status: status,
            ref: ref,
            sha: sha,
            pipelineID: id,
            projectID: project.projectID,
            projectFullPath: project.fullPath,
            webURL: webURL,
            ownership: .myTriggered,
            updatedAt: updatedAt,
            triggeredBy: user?.toUser(),
            triggerSource: source
        )
    }

    enum CodingKeys: String, CodingKey {
        case id, status, source, ref, sha, user
        case updatedAt = "updated_at"
        case webURL = "web_url"
    }
}

struct RESTUserNode: Decodable {
    let id: Int
    let username: String
    let name: String
    let avatarURL: URL?

    func toUser() -> User {
        User(id: String(id), username: username, name: name, avatarURL: avatarURL)
    }

    enum CodingKeys: String, CodingKey {
        case id, username, name
        case avatarURL = "avatar_url"
    }
}
