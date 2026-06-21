import SwiftUI

struct MergeRequestDetailView: View {
    @Environment(AuthService.self) private var authService
    @Environment(\.openURL) private var openURL

    @State private var mergeRequest: MergeRequest
    @State private var viewModel = MergeRequestDetailViewModel()

    init(mergeRequest: MergeRequest) {
        _mergeRequest = State(initialValue: mergeRequest)
    }

    var body: some View {
        List {
            Section("Overview") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(mergeRequest.title)
                        .font(.headline)

                    if let description = mergeRequest.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Label(mergeRequest.author.name, systemImage: "person")
                    Label("!\(mergeRequest.iid)", systemImage: "number")
                    Label("\(mergeRequest.sourceBranch) -> \(mergeRequest.targetBranch)", systemImage: "arrow.branch")
                }

                if mergeRequest.approved {
                    Label("Approved", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                }

                if let webURL = mergeRequest.webURL {
                    Button("Open in GitLab") {
                        openURL(webURL)
                    }
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
                                .foregroundStyle(.green)
                            Text("-\(stat.deletions)")
                                .foregroundStyle(.red)
                        }
                        .font(.subheadline)
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
                Section("Error") {
                    Text(error.localizedDescription)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Merge Request")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(mergeRequest.approved ? "Revoke" : "Approve") {
                    Task { await toggleApproval() }
                }
                .disabled(viewModel.isApproving)
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
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.displayPath)
                    .font(.subheadline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        if file.deletedFile { return .red }
        if file.newFile { return .green }
        return .secondary
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
            .padding(.vertical, 8)
        }
        .navigationTitle(file.displayPath)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DiffLineView: View {
    let line: DiffLine

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(prefix)
                .foregroundStyle(line.kind.foregroundStyle)
                .frame(width: 16, alignment: .center)

            Text(line.content.isEmpty ? " " : line.content)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(.caption, design: .monospaced))
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
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
        case .addition: .green
        case .deletion: .red
        case .hunk: .blue
        case .metadata: .secondary
        case .context: .primary
        }
    }

    var backgroundStyle: Color {
        switch self {
        case .addition: Color.green.opacity(0.12)
        case .deletion: Color.red.opacity(0.12)
        case .hunk: Color.blue.opacity(0.10)
        case .metadata: Color.secondary.opacity(0.08)
        case .context: Color.clear
        }
    }
}
