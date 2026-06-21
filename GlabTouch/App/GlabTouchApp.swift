import SwiftUI

@main
struct GlabTouchApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var authService = AuthService()
    @State private var notificationService = NotificationService()
    @State private var localPollingService = LocalPollingService()

    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isAuthenticated {
                    MainTabView()
                        .environment(authService)
                        .environment(notificationService)
                        .environment(localPollingService)
                } else {
                    LoginView()
                        .environment(authService)
                }
            }
            .task {
                authService.restoreSession()
            }
        }
        .onChange(of: authService.isAuthenticated) {}
    }
}
