import Foundation

struct NotificationPayload: Codable {
    let type: EventType
    let instance: URL
    let project: ProjectRef
    let mergeRequest: MergeRequestRef?
    let actor: ActorRef
    let timestamp: Date

    enum EventType: String, Codable {
        case mrAssigned = "mr_assigned"
        case mrApproved = "mr_approved"
        case mrMerged = "mr_merged"
        case pipelineFailed = "pipeline_failed"
    }

    struct ProjectRef: Codable {
        let id: Int
        let name: String
    }

    struct MergeRequestRef: Codable {
        let iid: Int
        let title: String
    }

    struct ActorRef: Codable {
        let username: String
        let avatarURL: URL?

        enum CodingKeys: String, CodingKey {
            case username
            case avatarURL = "avatar_url"
        }
    }

    enum CodingKeys: String, CodingKey {
        case type, instance, project, actor, timestamp
        case mergeRequest = "merge_request"
    }
}
