import Foundation
import UserNotifications

@MainActor
@Observable
final class LocalPollingService {
    private enum DefaultsKey {
        static let isEnabled = "localPolling.isEnabled"
        static let intervalMinutes = "localPolling.intervalMinutes"
    }

    private let defaults: UserDefaults
    private var pollingTask: Task<Void, Never>?
    private var previousPipelines: [Pipeline] = []
    private var hasObservedPipelines = false

    private(set) var isEnabled: Bool
    private(set) var intervalMinutes: Int
    private(set) var isRefreshing = false
    private(set) var badgeCount = 0
    private(set) var lastRefreshDate: Date?
    private(set) var lastError: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isEnabled = defaults.bool(forKey: DefaultsKey.isEnabled)
        let savedInterval = defaults.integer(forKey: DefaultsKey.intervalMinutes)
        self.intervalMinutes = Self.clampedInterval(savedInterval == 0 ? 15 : savedInterval)
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        defaults.set(enabled, forKey: DefaultsKey.isEnabled)
        if !enabled {
            stop()
            previousPipelines = []
            hasObservedPipelines = false
            Task { await clearBadge() }
        }
    }

    func setIntervalMinutes(_ minutes: Int) {
        intervalMinutes = Self.clampedInterval(minutes)
        defaults.set(intervalMinutes, forKey: DefaultsKey.intervalMinutes)
    }

    func start(authService: AuthService) {
        stop()
        guard isEnabled else { return }

        pollingTask = Task { @MainActor [weak self, weak authService] in
            while !Task.isCancelled {
                guard let self, let authService else { return }
                await self.refreshBadge(authService: authService)

                let seconds = UInt64(self.intervalMinutes * 60)
                try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            }
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func refreshBadge(authService: AuthService) async {
        guard let instance = authService.currentInstance, let token = authService.accessToken else {
            lastError = String(localized: "Stored token was missing.")
            await clearBadge()
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let client = GitLabAPIClient(baseURL: instance.baseURL, token: token, authMethod: instance.authMethod)
            let pipelines = try await client.pipelineDashboard()
            let count = Pipeline.localBadgeCount(for: pipelines)
            badgeCount = count
            try await UNUserNotificationCenter.current().setBadgeCount(count)

            let events = hasObservedPipelines ? PipelineNotificationEvent.detect(previous: previousPipelines, current: pipelines) : []
            previousPipelines = pipelines
            hasObservedPipelines = true
            for event in events {
                try await scheduleNotification(for: event)
            }

            lastRefreshDate = Date()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func clearBadge() async {
        badgeCount = 0
        try? await UNUserNotificationCenter.current().setBadgeCount(0)
    }

    private func scheduleNotification(for event: PipelineNotificationEvent) async throws {
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.title = notificationTitle(for: event)
        content.body = notificationBody(for: event)
        content.userInfo = [
            "type": event.kind.payloadType,
            "pipeline_id": event.pipelineID,
            "status": event.status.rawValue
        ]

        let request = UNNotificationRequest(
            identifier: "pipeline-\(event.id)",
            content: content,
            trigger: nil
        )
        try await UNUserNotificationCenter.current().add(request)
    }

    private func notificationTitle(for event: PipelineNotificationEvent) -> String {
        switch event.kind {
        case .started: String(localized: "Pipeline Started")
        case .completed: String(localized: "Pipeline Completed")
        }
    }

    private func notificationBody(for event: PipelineNotificationEvent) -> String {
        let statusText = event.status.notificationText
        if let projectFullPath = event.projectFullPath {
            return "\(event.title) · \(projectFullPath) · \(statusText)"
        }
        return "\(event.title) · \(statusText)"
    }

    private static func clampedInterval(_ minutes: Int) -> Int {
        min(max(minutes, 1), 60)
    }
}

private extension PipelineNotificationEvent.Kind {
    var payloadType: String {
        switch self {
        case .started: NotificationPayload.EventType.pipelineStarted.rawValue
        case .completed: NotificationPayload.EventType.pipelineCompleted.rawValue
        }
    }
}

private extension Pipeline.Status {
    var notificationText: String {
        switch self {
        case .created: String(localized: "Created")
        case .waiting: String(localized: "Waiting")
        case .preparing: String(localized: "Preparing")
        case .pending: String(localized: "Pending")
        case .running: String(localized: "Running")
        case .success: String(localized: "Passed")
        case .failed: String(localized: "Failed")
        case .canceled: String(localized: "Canceled")
        case .skipped: String(localized: "Skipped")
        case .manual: String(localized: "Manual")
        case .scheduled: String(localized: "Scheduled")
        case .canceling: String(localized: "Canceling")
        case .waitingForCallback: String(localized: "Waiting")
        case .waitingForResource: String(localized: "Waiting")
        }
    }
}
