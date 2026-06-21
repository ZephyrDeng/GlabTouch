import Foundation

struct Pipeline: Identifiable, Hashable {
    let id: String
    let status: Status
    let ref: String?
    let sha: String?
    let stages: [Stage]
    let pipelineID: Int?
    let projectID: Int?
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
        pipelineID: Int? = nil,
        projectID: Int? = nil,
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
        self.pipelineID = pipelineID
        self.projectID = projectID
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
        case .created, .waiting, .preparing, .pending, .running, .failed, .manual, .scheduled, .canceling, .waitingForCallback, .waitingForResource:
            true
        case .success, .canceled, .skipped:
            false
        }
    }

    var isActive: Bool {
        switch status {
        case .created, .waiting, .preparing, .pending, .running, .manual, .scheduled, .canceling, .waitingForCallback, .waitingForResource:
            true
        case .success, .failed, .canceled, .skipped:
            false
        }
    }

    var isTerminal: Bool {
        switch status {
        case .success, .failed, .canceled, .skipped:
            true
        case .created, .waiting, .preparing, .pending, .running, .manual, .scheduled, .canceling, .waitingForCallback, .waitingForResource:
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
        case canceling
        case waitingForCallback = "waiting_for_callback"
        case waitingForResource = "waiting_for_resource"
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
    let jobID: Int?
    let webURL: URL?

    init(id: String, name: String, status: Pipeline.Status, jobID: Int? = nil, webURL: URL? = nil) {
        self.id = id
        self.name = name
        self.status = status
        self.jobID = jobID
        self.webURL = webURL
    }
}

struct PipelineJob: Identifiable, Hashable, Decodable {
    let id: Int
    let name: String
    let stage: String
    let status: Pipeline.Status
    let ref: String?
    let allowFailure: Bool?
    let duration: Double?
    let queuedDuration: Double?
    let createdAt: Date?
    let startedAt: Date?
    let finishedAt: Date?
    let webURL: URL?

    init(
        id: Int,
        name: String,
        stage: String,
        status: Pipeline.Status,
        ref: String? = nil,
        allowFailure: Bool? = nil,
        duration: Double? = nil,
        queuedDuration: Double? = nil,
        createdAt: Date? = nil,
        startedAt: Date? = nil,
        finishedAt: Date? = nil,
        webURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.stage = stage
        self.status = status
        self.ref = ref
        self.allowFailure = allowFailure
        self.duration = duration
        self.queuedDuration = queuedDuration
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.webURL = webURL
    }

    enum CodingKeys: String, CodingKey {
        case id, name, stage, status, ref, duration
        case allowFailure = "allow_failure"
        case queuedDuration = "queued_duration"
        case createdAt = "created_at"
        case startedAt = "started_at"
        case finishedAt = "finished_at"
        case webURL = "web_url"
    }
}

enum PipelineJobAction: String, CaseIterable, Hashable {
    case play
    case retry
    case cancel

    static func availableActions(for job: PipelineJob) -> [PipelineJobAction] {
        switch job.status {
        case .manual:
            [.play]
        case .failed, .canceled:
            [.retry]
        case .created, .waiting, .preparing, .pending, .running, .scheduled, .canceling, .waitingForCallback, .waitingForResource:
            [.cancel]
        case .success, .skipped:
            []
        }
    }
}

struct PipelineNotificationEvent: Equatable, Identifiable {
    let kind: Kind
    let pipelineID: Int
    let title: String
    let status: Pipeline.Status
    let projectFullPath: String?

    var id: String { "\(kind.rawValue)-\(pipelineID)-\(status.rawValue)" }

    enum Kind: String, Equatable {
        case started
        case completed
    }

    static func detect(previous: [Pipeline], current: [Pipeline]) -> [PipelineNotificationEvent] {
        let previousByID = Dictionary(uniqueKeysWithValues: previous.compactMap { pipeline -> (Int, Pipeline)? in
            guard let pipelineID = pipeline.pipelineID else { return nil }
            return (pipelineID, pipeline)
        })

        return current.compactMap { pipeline in
            guard let pipelineID = pipeline.pipelineID,
                  let previousPipeline = previousByID[pipelineID],
                  previousPipeline.status != pipeline.status
            else { return nil }

            let title = pipeline.mergeRequestTitle ?? pipeline.ref ?? "#\(pipelineID)"
            if previousPipeline.status != .running && pipeline.status == .running {
                return PipelineNotificationEvent(
                    kind: .started,
                    pipelineID: pipelineID,
                    title: title,
                    status: pipeline.status,
                    projectFullPath: pipeline.projectFullPath
                )
            }
            if previousPipeline.isActive && pipeline.isTerminal {
                return PipelineNotificationEvent(
                    kind: .completed,
                    pipelineID: pipelineID,
                    title: title,
                    status: pipeline.status,
                    projectFullPath: pipeline.projectFullPath
                )
            }

            return nil
        }
    }
}
