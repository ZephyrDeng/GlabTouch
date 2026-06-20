import SwiftUI

struct MergeRequestRowView: View {
    let mergeRequest: MergeRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(mergeRequest.title)
                .font(.headline)
                .lineLimit(2)

            HStack(spacing: 12) {
                Label(mergeRequest.author.name, systemImage: "person")
                Label("!\(mergeRequest.iid)", systemImage: "number")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Label(mergeRequest.sourceBranch, systemImage: "arrow.branch")
                Image(systemName: "arrow.right")
                Text(mergeRequest.targetBranch)
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)

            HStack {
                if mergeRequest.approved {
                    Label("Approved", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }

                if let pipeline = mergeRequest.headPipeline {
                    PipelineStatusBadge(status: pipeline.status)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
