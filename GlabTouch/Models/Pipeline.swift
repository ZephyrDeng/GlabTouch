import Foundation

struct Pipeline: Identifiable, Hashable {
    let id: String
    let status: Status
    let ref: String?
    let sha: String?
    let stages: [Stage]

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
