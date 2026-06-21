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

        do {
            pipelines = try await client.pipelineDashboard()
        } catch {
            self.error = error
        }

        isLoading = false
    }
}
