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
        case createdByMe = "Created by Me"
        case reviewRequested = "Review"

        var id: String { rawValue }
    }

    func loadMergeRequests(client: GitLabAPIClient) async {
        isLoading = true
        error = nil

        do {
            let fieldName = GraphQLQueries.filterFieldName(for: selectedFilter)
            let query = GraphQLQueries.mergeRequests(filter: fieldName)
            let response: CurrentUserResponse = try await client.graphQL(query)
            mergeRequests = response.currentUser.mergeRequests.map { $0.toMergeRequest() }
        } catch {
            self.error = error
        }

        isLoading = false
    }
}
