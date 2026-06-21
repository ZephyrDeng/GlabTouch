import Foundation

@MainActor
@Observable
final class MergeRequestDetailViewModel {
    private(set) var mergeRequest: MergeRequest?
    private(set) var diffFiles: [DiffFile] = []
    private(set) var isLoading = false
    private(set) var error: Error?
    private(set) var isApproving = false

    func loadDetail(id: String, client: GitLabAPIClient) async {
        isLoading = true
        error = nil

        // GraphQL detail query
        isLoading = false
    }

    func loadChanges(projectID: Int, mrIID: Int, client: GitLabAPIClient) async {
        isLoading = true
        error = nil

        do {
            diffFiles = try await client.mergeRequestChanges(projectID: projectID, mrIID: mrIID)
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func approve(projectID: Int, mrIID: Int, client: GitLabAPIClient) async -> Bool {
        isApproving = true
        defer { isApproving = false }

        do {
            try await client.restVoid("POST", path: "projects/\(projectID)/merge_requests/\(mrIID)/approve")
            return true
        } catch {
            self.error = error
            return false
        }
    }

    func revokeApproval(projectID: Int, mrIID: Int, client: GitLabAPIClient) async -> Bool {
        isApproving = true
        defer { isApproving = false }

        do {
            try await client.restVoid("POST", path: "projects/\(projectID)/merge_requests/\(mrIID)/unapprove")
            return true
        } catch {
            self.error = error
            return false
        }
    }
}
