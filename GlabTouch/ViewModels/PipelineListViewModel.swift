import Foundation

@MainActor
@Observable
final class PipelineListViewModel {
    enum PipelineTab: String, CaseIterable, Identifiable {
        case mrRelated
        case myTriggered

        var id: String { rawValue }

        var title: String {
            switch self {
            case .mrRelated: String(localized: "MR Related")
            case .myTriggered: String(localized: "My Triggered")
            }
        }
    }

    private(set) var mrRelatedPipelines: [Pipeline] = []
    private(set) var myTriggeredPipelines: [Pipeline] = []
    private(set) var isLoading = false
    private(set) var error: Error?
    var selectedTab: PipelineTab = .mrRelated

    var pipelines: [Pipeline] {
        switch selectedTab {
        case .mrRelated: mrRelatedPipelines
        case .myTriggered: myTriggeredPipelines
        }
    }

    func loadPipelines(client: GitLabAPIClient) async {
        isLoading = true
        error = nil

        do {
            let context = try await client.pipelineDashboardContext()
            mrRelatedPipelines = context.mrRelatedPipelines
            if let username = context.username {
                myTriggeredPipelines = try await client.myTriggeredPipelines(
                    username: username,
                    projects: context.reviewWorkspaceProjects
                )
            } else {
                myTriggeredPipelines = []
            }
        } catch {
            self.error = error
        }

        isLoading = false
    }
}
