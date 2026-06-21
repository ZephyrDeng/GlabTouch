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

    private static func clampedInterval(_ minutes: Int) -> Int {
        min(max(minutes, 1), 60)
    }
}
