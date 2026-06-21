import Foundation

struct Pipeline: Identifiable, Hashable {
    let id: String
    let status: Status
    let ref: String?
    let sha: String?
    let stages: [Stage]
    let mergeRequestTitle: String?
    let mergeRequestIID: Int?
    let projectFullPath: String?
    let webURL: URL?

    init(
        id: String,
        status: Status,
        ref: String? = nil,
        sha: String? = nil,
        stages: [Stage] = [],
        mergeRequestTitle: String? = nil,
        mergeRequestIID: Int? = nil,
        projectFullPath: String? = nil,
        webURL: URL? = nil
    ) {
        self.id = id
        self.status = status
        self.ref = ref
        self.sha = sha
        self.stages = stages
        self.mergeRequestTitle = mergeRequestTitle
        self.mergeRequestIID = mergeRequestIID
        self.projectFullPath = projectFullPath
        self.webURL = webURL
    }

    var shortSHA: String? {
        sha.map { String($0.prefix(8)) }
    }

    var countsTowardLocalBadge: Bool {
        switch status {
        case .created, .waiting, .preparing, .pending, .running, .failed, .manual, .scheduled:
            true
        case .success, .canceled, .skipped:
            false
        }
    }

    static func localBadgeCount(for pipelines: [Pipeline]) -> Int {
        pipelines.filter(\.countsTowardLocalBadge).count
    }

    enum Status: String, Codable {
        case created, waiting, preparing, pending
        case running, success, failed, canceled
        case skipped, manual, scheduled
    }
}

struct Stage: Identifiable, Hashable {
    let id: String
    let name: String
    let status: Pipeline.Status
    let jobs: [Job]
}

struct Job: Identifiable, Hashable {
    let id: String
    let name: String
    let status: Pipeline.Status
}
