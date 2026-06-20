import Foundation
import UserNotifications

@MainActor
@Observable
final class NotificationService {
    private(set) var isAuthorized = false

    func requestAuthorization() async throws {
        let center = UNUserNotificationCenter.current()
        isAuthorized = try await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    func handlePayload(_ payload: NotificationPayload) {
        // Route notification to appropriate view based on payload type
    }
}
