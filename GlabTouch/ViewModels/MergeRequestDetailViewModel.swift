import Foundation

@MainActor
@Observable
final class MergeRequestDetailViewModel {
    private(set) var mergeRequest: MergeRequest?
    private(set) var isLoading = false
    private(set) var error: Error?
    private(set) var isApproving = false

    func loadDetail(id: String, client: GitLabAPIClient) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        // GraphQL detail query
    }

    func approve(projectID: Int, mrIID: Int, client: GitLabAPIClient) async {
        isApproving = true
        defer { isApproving = false }

        do {
            try await client.restVoid("POST", path: "projects/\(projectID)/merge_requests/\(mrIID)/approve")
        } catch {
            self.error = error
        }
    }

    func revokeApproval(projectID: Int, mrIID: Int, client: GitLabAPIClient) async {
        isApproving = true
        defer { isApproving = false }

        do {
            try await client.restVoid("POST", path: "projects/\(projectID)/merge_requests/\(mrIID)/unapprove")
        } catch {
            self.error = error
        }
    }
}
