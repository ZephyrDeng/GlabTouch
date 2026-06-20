import Foundation

@MainActor
@Observable
final class PipelineListViewModel {
    private(set) var pipelines: [Pipeline] = []
    private(set) var isLoading = false
    private(set) var error: Error?

    func loadPipelines(client: GitLabAPIClient) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        // GraphQL pipeline query
    }
}
