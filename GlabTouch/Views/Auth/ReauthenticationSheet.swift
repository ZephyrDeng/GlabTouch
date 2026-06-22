import SwiftUI

struct ReauthenticationSheet: View {
    @Environment(AuthService.self) private var authService
    @Environment(\.dismiss) private var dismiss

    @State private var token = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("OAuth") {
                    Button {
                        Task { await reauthenticateWithOAuth() }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Re-authenticate")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isOAuthDisabled)
                }

                Section("Personal Access Token") {
                    SecureField("Personal Access Token", text: $token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button {
                        Task { await reenterToken() }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Re-enter Token")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isTokenDisabled)
                }

                if let errorMessage {
                    ErrorSection(message: errorMessage)
                }
            }
            .navigationTitle("Authentication Required")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        authService.clearNeedsReauthentication()
                        dismiss()
                    }
                }
            }
        }
    }

    private var isOAuthDisabled: Bool {
        isLoading || authService.currentInstance?.oauthClientID == nil || authService.currentInstance?.oauthRedirectURI == nil
    }

    private var isTokenDisabled: Bool {
        isLoading || authService.currentInstance == nil || token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func reauthenticateWithOAuth() async {
        guard let instance = authService.currentInstance,
              let clientID = instance.oauthClientID,
              let redirectURI = instance.oauthRedirectURI
        else {
            errorMessage = "OAuth configuration was missing."
            return
        }

        await authenticate {
            try await authService.loginWithOAuth(instance: instance, clientID: clientID, redirectURI: redirectURI)
        }
    }

    private func reenterToken() async {
        guard let instance = authService.currentInstance else {
            errorMessage = "GitLab instance was missing."
            return
        }

        await authenticate {
            try await authService.loginWithPAT(
                instance: instance,
                token: token.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    private func authenticate(_ operation: () async throws -> Void) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            try await operation()
            authService.clearNeedsReauthentication()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ReauthenticationSheet()
        .environment(AuthService())
}
