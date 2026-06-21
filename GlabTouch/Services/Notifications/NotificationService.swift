import Foundation
import UserNotifications
import UIKit

@MainActor
@Observable
final class NotificationService {
    private(set) var isAuthorized = false
    private(set) var latestPayload: NotificationPayload?
    private(set) var deviceToken: String?
    private(set) var registrationError: String?

    func requestAuthorization() async throws {
        let center = UNUserNotificationCenter.current()
        isAuthorized = try await center.requestAuthorization(options: [.alert, .badge, .sound])
        if isAuthorized {
            UIApplication.shared.registerForRemoteNotifications()
        }
        refreshRegistrationState()
    }

    func handlePayload(_ payload: NotificationPayload) {
        latestPayload = payload
    }

    func refreshRegistrationState() {
        deviceToken = UserDefaults.standard.string(forKey: "apnsDeviceToken")
        registrationError = UserDefaults.standard.string(forKey: "apnsRegistrationError")
    }
}
