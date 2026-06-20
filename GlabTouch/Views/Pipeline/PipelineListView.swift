import SwiftUI

struct PipelineListView: View {
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
                    PipelineRowView(pipeline: pipeline)
                }
            }
            .navigationTitle("Pipelines")
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
        }
    }
}

struct PipelineRowView: View {
    let pipeline: Pipeline

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                PipelineStatusBadge(status: pipeline.status)
                if let ref = pipeline.ref {
                    Text(ref)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if !pipeline.stages.isEmpty {
                HStack(spacing: 4) {
                    ForEach(pipeline.stages) { stage in
                        PipelineStatusBadge(status: stage.status)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PipelineListView()
}
