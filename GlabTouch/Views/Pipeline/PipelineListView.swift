import SwiftUI

struct PipelineListView: View {
    @Environment(AuthService.self) private var authService
    @State private var viewModel = PipelineListViewModel()

    var body: some View {
        NavigationStack {
            List {
                if viewModel.pipelines.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "No Pipelines",
                        systemImage: "circle.dashed",
                        description: Text("Pipeline status will appear here.")
                    )
                }

                ForEach(viewModel.pipelines) { pipeline in
                    NavigationLink {
                        PipelineDetailView(pipeline: pipeline)
                    } label: {
                        PipelineRowView(pipeline: pipeline, showsJobs: false)
                    }
                }

                if let error = viewModel.error {
                    Section("Error") {
                        Text(error.localizedDescription)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Pipelines")
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .refreshable {
                await loadData()
            }
            .task {
                await loadData()
            }
        }
    }

    private func loadData() async {
        guard let instance = authService.currentInstance,
              let token = authService.accessToken else { return }
        let client = GitLabAPIClient(baseURL: instance.baseURL, token: token, authMethod: instance.authMethod)
        await viewModel.loadPipelines(client: client)
    }
}

struct PipelineRowView: View {
    let pipeline: Pipeline
    var showsJobs = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                PipelineStatusBadge(status: pipeline.status)
                Spacer()
                if let shortSHA = pipeline.shortSHA {
                    Text(shortSHA)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            if let title = pipeline.mergeRequestTitle {
                Text(title)
                    .font(.subheadline)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                if let ref = pipeline.ref {
                    Label(ref, systemImage: "arrow.branch")
                }
                if let iid = pipeline.mergeRequestIID {
                    Label("!\(iid)", systemImage: "number")
                }
                if let projectFullPath = pipeline.projectFullPath {
                    Text(projectFullPath)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !pipeline.stages.isEmpty {
                if showsJobs {
                    ForEach(pipeline.stages) { stage in
                        DisclosureGroup {
                            ForEach(stage.jobs) { job in
                                HStack {
                                    Text(job.name)
                                    Spacer()
                                    PipelineStatusBadge(status: job.status)
                                }
                                .font(.caption)
                            }
                        } label: {
                            HStack {
                                Text(stage.name)
                                Spacer()
                                PipelineStatusBadge(status: stage.status)
                            }
                        }
                    }
                } else {
                    HStack(spacing: 4) {
                        ForEach(pipeline.stages) { stage in
                            PipelineStatusBadge(status: stage.status)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PipelineListView()
        .environment(AuthService())
}
