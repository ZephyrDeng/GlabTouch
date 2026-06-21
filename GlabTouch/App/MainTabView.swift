import SwiftUI

struct MainTabView: View {
    @Environment(AuthService.self) private var authService
    @Environment(LocalPollingService.self) private var localPollingService

    var body: some View {
        TabView {
            Tab("Merge Requests", systemImage: "arrow.triangle.merge") {
                MergeRequestListView()
            }

            Tab("Pipelines", systemImage: "circle.dashed") {
                PipelineListView()
            }

            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .task {
            localPollingService.start(authService: authService)
        }
        .onChange(of: authService.currentInstance?.id) {
            localPollingService.start(authService: authService)
        }
        .onChange(of: localPollingService.isEnabled) {
            localPollingService.start(authService: authService)
        }
        .onChange(of: localPollingService.intervalMinutes) {
            localPollingService.start(authService: authService)
        }
    }
}

#Preview {
    MainTabView()
        .environment(AuthService())
        .environment(LocalPollingService())
}
