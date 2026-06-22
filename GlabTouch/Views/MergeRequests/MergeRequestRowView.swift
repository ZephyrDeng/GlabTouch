import SwiftUI

struct MergeRequestRowView: View {
    let mergeRequest: MergeRequest

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(mergeRequest.title)
                .font(AppFont.title)
                .lineLimit(2)

            HStack(spacing: Spacing.md) {
                Label(mergeRequest.author.name, systemImage: "person")
                Label("!\(mergeRequest.iid)", systemImage: "number")
            }
            .font(AppFont.metadata)
            .foregroundStyle(TextColor.secondary)

            HStack(spacing: Spacing.sm) {
                Label(mergeRequest.sourceBranch, systemImage: "arrow.branch")
                Image(systemName: "arrow.right")
                Text(mergeRequest.targetBranch)
            }
            .font(AppFont.tertiary)
            .foregroundStyle(TextColor.tertiary)

            HStack {
                if mergeRequest.approved {
                    Label("Approved", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(TextColor.approved)
                        .font(AppFont.metadata)
                }

                if let pipeline = mergeRequest.headPipeline {
                    PipelineStatusBadge(status: pipeline.status)
                }
            }
        }
        .padding(.vertical, Spacing.xs)
    }
}
