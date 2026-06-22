import SwiftUI

struct SettingsView: View {
    @Environment(AuthService.self) private var authService
    @Environment(NotificationService.self) private var notificationService
    @Environment(LocalPollingService.self) private var localPollingService

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

                Section("Saved Instances") {
                    ForEach(authService.savedInstances) { instance in
                        Button {
                            try? authService.switchInstance(instance)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    Text(instance.name)
                                    Text(instance.baseURL.absoluteString)
                                        .font(AppFont.metadata)
                                        .foregroundStyle(TextColor.secondary)
                                }
                                Spacer()
                                if authService.currentInstance?.id == instance.id {
                                    Label("Active", systemImage: "checkmark.circle.fill")
                                        .labelStyle(.iconOnly)
                                        .foregroundStyle(TextColor.approved)
                                }
                            }
                        }
                    }
                    .onDelete(perform: forgetInstances)
                }

                Section("Notifications") {
                    LabeledContent(
                        "Authorization",
                        value: notificationService.isAuthorized ? String(localized: "Allowed") : String(localized: "Authorization Pending")
                    )
                    if let deviceToken = notificationService.deviceToken {
                        LabeledContent("APNs Token", value: String(deviceToken.prefix(12)) + "...")
                    }
                    if let registrationError = notificationService.registrationError {
                        Text(registrationError)
                            .foregroundStyle(TextColor.error)
                    }
                    Button("Enable Push Notifications") {
                        Task {
                            try? await notificationService.requestAuthorization()
                        }
                    }
                }

                Section("Local Polling") {
                    Toggle("Enabled", isOn: pollingEnabledBinding)

                    Stepper(value: pollingIntervalBinding, in: 1...60) {
                        LabeledContent("Interval", value: formattedPollingInterval)
                    }

                    LabeledContent("Badge Count", value: "\(localPollingService.badgeCount)")
                    LabeledContent("Last Refresh", value: lastRefreshText)

                    if let lastError = localPollingService.lastError {
                        Text(lastError)
                            .foregroundStyle(TextColor.error)
                    }

                    Button {
                        Task {
                            await localPollingService.refreshBadge(authService: authService)
                        }
                    } label: {
                        if localPollingService.isRefreshing {
                            ProgressView()
                        } else {
                            Text("Refresh Badge Now")
                        }
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
            .task {
                notificationService.refreshRegistrationState()
            }
        }
    }

    private var pollingEnabledBinding: Binding<Bool> {
        Binding(
            get: { localPollingService.isEnabled },
            set: { localPollingService.setEnabled($0) }
        )
    }

    private var pollingIntervalBinding: Binding<Int> {
        Binding(
            get: { localPollingService.intervalMinutes },
            set: { localPollingService.setIntervalMinutes($0) }
        )
    }

    private var formattedPollingInterval: String {
        String(format: String(localized: "%d min"), localPollingService.intervalMinutes)
    }

    private var lastRefreshText: String {
        guard let lastRefreshDate = localPollingService.lastRefreshDate else {
            return String(localized: "Never")
        }
        return lastRefreshDate.formatted(date: .omitted, time: .shortened)
    }

    private func forgetInstances(at offsets: IndexSet) {
        let instances = offsets.map { authService.savedInstances[$0] }
        for instance in instances {
            try? authService.forgetInstance(instance)
        }
    }
}

#Preview {
    SettingsView()
        .environment(AuthService())
        .environment(NotificationService())
        .environment(LocalPollingService())
}
