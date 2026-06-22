import SwiftUI

struct MergeRequestDetailView: View {
    @Environment(AuthService.self) private var authService
    @Environment(\.openURL) private var openURL

    @State private var mergeRequest: MergeRequest
    @State private var viewModel = MergeRequestDetailViewModel()
    @State private var webViewHeight: CGFloat = 0

    init(mergeRequest: MergeRequest) {
        _mergeRequest = State(initialValue: mergeRequest)
    }

    var body: some View {
        List {
            Section("Overview") {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(mergeRequest.title)
                        .font(AppFont.title)

                    if let descriptionHtml = mergeRequest.descriptionHtml?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !descriptionHtml.isEmpty
                    {
                        MarkdownWebView(
                            html: descriptionHtml,
                            baseURL: authService.baseURL,
                            authToken: authService.accessToken ?? "",
                            contentHeight: $webViewHeight
                        )
                        .frame(height: max(webViewHeight, 1))
                    } else if let description = mergeRequest.description, !description.isEmpty {
                        Text(description)
                            .font(AppFont.body)
                            .foregroundStyle(TextColor.secondary)
                    }

                    Label(mergeRequest.author.name, systemImage: "person")
                    Label("!\(mergeRequest.iid)", systemImage: "number")
                    Label("\(mergeRequest.sourceBranch) -> \(mergeRequest.targetBranch)", systemImage: "arrow.branch")
                }

                if mergeRequest.approved {
                    Label("Approved", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(TextColor.approved)
                }

                if let webURL = mergeRequest.webURL {
                    Link("Open in GitLab", destination: webURL)
                        .accessibilityHint(Text("Opens this merge request in the GitLab web interface"))
                }
            }

            if let pipeline = mergeRequest.headPipeline {
                Section("Pipeline") {
                    NavigationLink {
                        PipelineDetailView(pipeline: pipeline)
                    } label: {
                        PipelineRowView(pipeline: pipeline, showsJobs: true)
                    }
                }
            }

            if let diffStats = mergeRequest.diffStats, !diffStats.isEmpty {
                Section("Diff Summary") {
                    ForEach(diffStats, id: \.path) { stat in
                        HStack {
                            Text(stat.path)
                            Spacer()
                            Text("+\(stat.additions)")
                                .foregroundStyle(DiffColor.additionForeground)
                            Text("-\(stat.deletions)")
                                .foregroundStyle(DiffColor.deletionForeground)
                        }
                        .font(AppFont.body)
                    }
                }
            }

            Section("Changed Files") {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.diffFiles.isEmpty {
                    ContentUnavailableView(
                        "No Diff",
                        systemImage: "doc.text",
                        description: Text("No file changes were returned by GitLab.")
                    )
                } else {
                    ForEach(viewModel.diffFiles) { file in
                        NavigationLink {
                            DiffFileView(file: file)
                        } label: {
                            DiffFileRowView(file: file)
                        }
                    }
                }
            }

            if let error = viewModel.error {
                ErrorSection(message: error.localizedDescription)
            }
        }
        .navigationTitle("Merge Request")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if mergeRequest.approved {
                    Button("Revoke", role: .destructive) {
                        Task { await toggleApproval() }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityHint(Text("Removes your approval from this merge request"))
                    .disabled(viewModel.isApproving)
                } else {
                    Button("Approve") {
                        Task { await toggleApproval() }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint(Text("Approves this merge request"))
                    .disabled(viewModel.isApproving)
                }
            }
        }
        .refreshable {
            await loadChanges()
        }
        .task {
            await loadChanges()
        }
    }

    private func loadChanges() async {
        guard let client else { return }
        await viewModel.loadChanges(projectID: mergeRequest.projectID, mrIID: mergeRequest.iid, client: client)
    }

    private func toggleApproval() async {
        guard let client else { return }

        let succeeded: Bool
        if mergeRequest.approved {
            succeeded = await viewModel.revokeApproval(projectID: mergeRequest.projectID, mrIID: mergeRequest.iid, client: client)
        } else {
            succeeded = await viewModel.approve(projectID: mergeRequest.projectID, mrIID: mergeRequest.iid, client: client)
        }

        if succeeded {
            mergeRequest = mergeRequest.withApproval(!mergeRequest.approved)
        }
    }

    private var client: GitLabAPIClient? {
        guard let instance = authService.currentInstance,
              let token = authService.accessToken else { return nil }
        return GitLabAPIClient(baseURL: instance.baseURL, token: token, authMethod: instance.authMethod)
    }
}

struct DiffFileRowView: View {
    let file: DiffFile

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(file.displayPath)
                    .font(AppFont.body)
                Text(subtitle)
                    .font(AppFont.metadata)
                    .foregroundStyle(TextColor.secondary)
            }
        }
    }

    private var iconName: String {
        if file.deletedFile { return "trash" }
        if file.renamedFile { return "arrow.triangle.2.circlepath" }
        if file.newFile { return "doc.badge.plus" }
        return "doc.text"
    }

    private var iconColor: Color {
        if file.deletedFile { return DiffColor.deletionForeground }
        if file.newFile { return DiffColor.additionForeground }
        return TextColor.secondary
    }

    private var subtitle: String {
        if file.renamedFile { return String(localized: "Renamed") }
        if file.newFile { return String(localized: "New file") }
        if file.deletedFile { return String(localized: "Deleted") }
        return String(localized: "Modified")
    }
}

struct DiffFileView: View {
    let file: DiffFile

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(file.lines) { line in
                    DiffLineView(line: line)
                }
            }
            .padding(.vertical, Spacing.sm)
        }
        .navigationTitle(file.displayPath)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DiffLineView: View {
    let line: DiffLine

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Text(prefix)
                .foregroundStyle(line.kind.foregroundStyle)
                .frame(width: 16, alignment: .center)

            Text(line.content.isEmpty ? " " : line.content)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(AppFont.mono)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(line.kind.backgroundStyle)
    }

    private var prefix: String {
        switch line.kind {
        case .addition: "+"
        case .deletion: "-"
        case .hunk: "@"
        case .metadata: "\\"
        case .context: " "
        }
    }
}

private extension DiffLine.Kind {
    var foregroundStyle: Color {
        switch self {
        case .addition: DiffColor.additionForeground
        case .deletion: DiffColor.deletionForeground
        case .hunk: DiffColor.hunkForeground
        case .metadata: DiffColor.metadataForeground
        case .context: DiffColor.contextForeground
        }
    }

    var backgroundStyle: Color {
        switch self {
        case .addition: DiffColor.additionBackground
        case .deletion: DiffColor.deletionBackground
        case .hunk: DiffColor.hunkBackground
        case .metadata: DiffColor.metadataBackground
        case .context: DiffColor.contextBackground
        }
    }
}
