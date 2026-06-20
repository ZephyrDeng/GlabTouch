import SwiftUI

struct MainTabView: View {
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
    }
}

#Preview {
    MainTabView()
        .environment(AuthService())
}
