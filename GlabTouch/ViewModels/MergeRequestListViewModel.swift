import Foundation

@MainActor
@Observable
final class MergeRequestListViewModel {
    private(set) var mergeRequests: [MergeRequest] = []
    private(set) var isLoading = false
    private(set) var error: Error?

    var selectedFilter: MRFilter = .assignedToMe

    enum MRFilter: String, CaseIterable, Identifiable {
        case assignedToMe = "Assigned"
        case createdByMe = "Created"
        case reviewRequested = "Review"

        var id: String { rawValue }
    }

    func loadMergeRequests(client: GitLabAPIClient) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        // GraphQL query will be implemented with real query strings
    }
}
