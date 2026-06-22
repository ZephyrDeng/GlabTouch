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
                        let isActive = authService.currentInstance?.id == instance.id
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
                                if isActive {
                                    Label("Active", systemImage: "checkmark.circle.fill")
                                        .labelStyle(.iconOnly)
                                        .foregroundStyle(TextColor.approved)
                                } else {
                                    Image(systemName: "arrow.right.circle")
                                        .foregroundStyle(TextColor.secondary)
                                }
                            }
                        }
                        .accessibilityLabel(Text("Switch to \(instance.name)"))
                        .accessibilityHint(isActive ? Text("This is the active instance") : Text("Switches to this GitLab instance"))
                        .disabled(isActive)
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
                        ErrorText(message: registrationError)
                    }
                    Button("Enable Push Notifications") {
                        Task {
                            try? await notificationService.requestAuthorization()
                        }
                    }
                    .accessibilityHint(Text("Requests permission to send push notifications"))
                }

                Section("Local Polling") {
                    Toggle("Enabled", isOn: pollingEnabledBinding)

                    Stepper(value: pollingIntervalBinding, in: 1...60) {
                        LabeledContent("Interval", value: formattedPollingInterval)
                    }

                    LabeledContent("Badge Count", value: "\(localPollingService.badgeCount)")
                    LabeledContent("Last Refresh", value: lastRefreshText)

                    if let lastError = localPollingService.lastError {
                        ErrorText(message: lastError)
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
                    .accessibilityHint(Text("Checks for new merge requests and updates the badge count"))
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        try? authService.logout()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityHint(Text("Signs out of the current GitLab instance"))
                }

                Section("About") {
                    LabeledContent("Version", value: "1.1.0")
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
