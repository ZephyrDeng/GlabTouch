import SwiftUI

@main
struct GlabTouchApp: App {
    @State private var authService = AuthService()

    var body: some Scene {
        WindowGroup {
            if authService.isAuthenticated {
                MainTabView()
                    .environment(authService)
            } else {
                LoginView()
                    .environment(authService)
            }
        }
    }
}
