import SwiftUI

private let stageDisclosureAnimation = Animation.timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.22)

struct PipelineDetailView: View {
    @Environment(AuthService.self) private var authService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    let pipeline: Pipeline
    @State private var viewModel = PipelineDetailViewModel()
    @State private var expandedStageIDs: Set<String> = []

    var body: some View {
        List {
            Section("Overview") {
                PipelineRowView(pipeline: pipeline, showsJobs: false)

                if let webURL = pipeline.webURL {
                    Button("Open in GitLab") {
                        openURL(webURL)
                    }
                }
            }

            if let projectID = pipeline.projectID, let pipelineID = pipeline.pipelineID {
                Section("Pipeline Actions") {
                    Button("Retry Pipeline") {
                        Task { await retryPipeline(projectID: projectID, pipelineID: pipelineID) }
                    }
                    .disabled(viewModel.isMutating)

                    Button("Cancel Pipeline", role: .destructive) {
                        Task { await cancelPipeline(projectID: projectID, pipelineID: pipelineID) }
                    }
                    .disabled(viewModel.isMutating)
                }

                Section("Jobs") {
                    if viewModel.isLoadingJobs {
                        ProgressView()
                    } else if viewModel.jobs.isEmpty {
                        ContentUnavailableView(
                            "No Jobs",
                            systemImage: "hammer",
                            description: Text("Pipeline jobs will appear here.")
                        )
                    } else {
                        ForEach(stageGroups) { group in
                            PipelineStageDisclosureRow(
                                group: group,
                                isExpanded: expandedStageIDs.contains(group.id),
                                reduceMotion: reduceMotion,
                                projectID: projectID,
                                isMutating: viewModel.isMutating,
                                toggle: { toggleStage(group) },
                                performAction: performAction
                            )
                        }
                    }
                }
            } else {
                Section("Pipeline Actions") {
                    ContentUnavailableView(
                        "Interaction Unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text("This pipeline is missing REST identifiers.")
                    )
                }
            }

            if let error = viewModel.error {
                Section("Error") {
                    Text(error.localizedDescription)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Pipeline")
        .refreshable {
            await loadJobs()
        }
        .safeAreaPadding(.bottom, 12)
        .task {
            await loadJobs()
        }
    }

    private var stageGroups: [PipelineStageGroup] {
        PipelineStageGroup.groups(for: viewModel.jobs)
    }

    private func loadJobs() async {
        guard let projectID = pipeline.projectID,
              let pipelineID = pipeline.pipelineID,
              let client
        else { return }
        await viewModel.loadJobs(projectID: projectID, pipelineID: pipelineID, client: client)
    }

    private func retryPipeline(projectID: Int, pipelineID: Int) async {
        guard let client else { return }
        if await viewModel.retryPipeline(projectID: projectID, pipelineID: pipelineID, client: client) {
            await loadJobs()
        }
    }

    private func cancelPipeline(projectID: Int, pipelineID: Int) async {
        guard let client else { return }
        if await viewModel.cancelPipeline(projectID: projectID, pipelineID: pipelineID, client: client) {
            await loadJobs()
        }
    }

    private func performAction(_ action: PipelineJobAction, job: PipelineJob, projectID: Int) {
        Task {
            guard let client else { return }
            if await viewModel.perform(action, projectID: projectID, jobID: job.id, client: client) {
                await loadJobs()
            }
        }
    }

    private func toggleStage(_ group: PipelineStageGroup) {
        withAnimation(reduceMotion ? nil : stageDisclosureAnimation) {
            if expandedStageIDs.contains(group.id) {
                expandedStageIDs.remove(group.id)
            } else {
                expandedStageIDs.insert(group.id)
            }
        }
    }

    private var client: GitLabAPIClient? {
        guard let instance = authService.currentInstance,
              let token = authService.accessToken else { return nil }
        return GitLabAPIClient(baseURL: instance.baseURL, token: token, authMethod: instance.authMethod)
    }
}

private struct PipelineStageDisclosureRow: View {
    let group: PipelineStageGroup
    let isExpanded: Bool
    let reduceMotion: Bool
    let projectID: Int
    let isMutating: Bool
    let toggle: () -> Void
    let performAction: (PipelineJobAction, PipelineJob, Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: toggle) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.stage)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Label {
                            Text(group.jobs.count, format: .number)
                        } icon: {
                            Image(systemName: "hammer")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    PipelineStatusBadge(status: group.status)
                        .frame(minWidth: 64, alignment: .trailing)

                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                        .frame(width: 24, height: 24)
                }
                .contentShape(Rectangle())
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .accessibilityValue(Text(isExpanded ? "Expanded" : "Collapsed"))

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(group.jobs) { job in
                        PipelineJobRowView(
                            job: job,
                            projectID: projectID,
                            isMutating: isMutating,
                            performAction: performAction
                        )

                        if job.id != group.jobs.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.top, 6)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(reduceMotion ? nil : stageDisclosureAnimation, value: isExpanded)
    }
}

private struct PipelineJobRowView: View {
    let job: PipelineJob
    let projectID: Int
    let isMutating: Bool
    let performAction: (PipelineJobAction, PipelineJob, Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.name)
                        .font(.subheadline)
                    HStack(spacing: 8) {
                        if let durationText = job.durationText {
                            Label(durationText, systemImage: "timer")
                        }
                        if job.allowFailure == true {
                            Label("Allowed to Fail", systemImage: "shield")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()
                PipelineStatusBadge(status: job.status)
            }

            HStack {
                NavigationLink {
                    PipelineJobTraceView(projectID: projectID, job: job)
                } label: {
                    Label("Trace", systemImage: "terminal")
                }

                Spacer()

                ForEach(PipelineJobAction.availableActions(for: job), id: \.self) { action in
                    Button(role: action.role) {
                        performAction(action, job, projectID)
                    } label: {
                        Label(action.title, systemImage: action.iconName)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isMutating)
                }
            }
            .font(.caption)
        }
        .padding(.vertical, 6)
    }
}

struct PipelineJobTraceView: View {
    @Environment(AuthService.self) private var authService

    let projectID: Int
    let job: PipelineJob
    @State private var viewModel = PipelineDetailViewModel()

    var body: some View {
        ScrollView {
            if viewModel.isLoadingTrace {
                ProgressView()
                    .padding()
            } else if let error = viewModel.error {
                ContentUnavailableView(
                    "Error",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
                .padding()
            } else if viewModel.trace.isEmpty {
                ContentUnavailableView(
                    "No Trace",
                    systemImage: "terminal",
                    description: Text("No job trace was returned by GitLab.")
                )
                .padding()
            } else {
                Text(viewModel.trace)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .navigationTitle(job.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadTrace()
        }
        .refreshable {
            await loadTrace()
        }
        .safeAreaPadding(.bottom, 12)
    }

    private func loadTrace() async {
        guard let client else { return }
        await viewModel.loadTrace(projectID: projectID, jobID: job.id, client: client)
    }

    private var client: GitLabAPIClient? {
        guard let instance = authService.currentInstance,
              let token = authService.accessToken else { return nil }
        return GitLabAPIClient(baseURL: instance.baseURL, token: token, authMethod: instance.authMethod)
    }
}

private extension PipelineJob {
    var durationText: String? {
        guard let duration else { return nil }
        return Duration.seconds(duration).formatted(.time(pattern: .minuteSecond))
    }
}

private extension PipelineJobAction {
    var title: String {
        switch self {
        case .play: String(localized: "Play")
        case .retry: String(localized: "Retry")
        case .cancel: String(localized: "Cancel")
        }
    }

    var iconName: String {
        switch self {
        case .play: "play.fill"
        case .retry: "arrow.clockwise"
        case .cancel: "xmark.circle"
        }
    }

    var role: ButtonRole? {
        switch self {
        case .cancel: .destructive
        case .play, .retry: nil
        }
    }
}

#Preview {
    NavigationStack {
        PipelineDetailView(
            pipeline: Pipeline(
                id: "gid://gitlab/Ci::Pipeline/1",
                status: .running,
                ref: "main",
                sha: "abcdef1234567890",
                pipelineID: 1,
                projectID: 1,
                mergeRequestTitle: "Preview pipeline",
                mergeRequestIID: 42,
                projectFullPath: "group/project"
            )
        )
    }
    .environment(AuthService())
}
