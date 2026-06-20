import SwiftUI

struct SettingsView: View {
    @Environment(AuthService.self) private var authService

    var body: some View {
        NavigationStack {
            List {
                if let instance = authService.currentInstance {
                    Section("Current Instance") {
                        LabeledContent("Name", value: instance.name)
                        LabeledContent("URL", value: instance.baseURL.absoluteString)
                        LabeledContent("Auth", value: instance.authMethod.rawValue.uppercased())
                    }
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        try? authService.logout()
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("License", value: "Apache 2.0")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
        .environment(AuthService())
}
