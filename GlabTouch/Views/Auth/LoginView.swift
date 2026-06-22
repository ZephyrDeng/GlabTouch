import SwiftUI

struct LoginView: View {
    @Environment(AuthService.self) private var authService
    @State private var instanceURL = ""
    @State private var token = ""
    @State private var instanceName = "My GitLab"
    @State private var authMethod: GitLabInstance.AuthMethod = .pat
    @State private var oauthClientID = ""
    @State private var oauthRedirectURI = "glabtouch://oauth/callback"
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("GitLab Instance") {
                    TextField("Instance Name", text: $instanceName)
                    TextField("Base URL", text: $instanceURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Authentication") {
                    Picker("Method", selection: $authMethod) {
                        Text("Personal Access Token").tag(GitLabInstance.AuthMethod.pat)
                        Text("OAuth 2.0").tag(GitLabInstance.AuthMethod.oauth)
                    }
                    .pickerStyle(.segmented)

                    if authMethod == .pat {
                        SecureField("Personal Access Token", text: $token)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        TextField("OAuth Client ID", text: $oauthClientID)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("Redirect URI", text: $oauthRedirectURI)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                if let errorMessage {
                    ErrorSection(message: errorMessage)
                }

                Section {
                    Button {
                        Task { await login() }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            if authMethod == .pat {
                                Text("Sign In")
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Sign in with OAuth")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint(Text("Signs in to the GitLab instance"))
                    .disabled(isSignInDisabled)
                }
            }
            .navigationTitle("GlabTouch")
        }
    }

    private var isSignInDisabled: Bool {
        if isLoading || normalizedInstanceURL == nil {
            return true
        }

        switch authMethod {
        case .pat:
            return token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .oauth:
            return oauthClientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || normalizedRedirectURI == nil
        }
    }

    private func login() async {
        guard let url = normalizedInstanceURL else {
            errorMessage = "Enter a valid GitLab URL, for example https://gitlab.com"
            return
        }

        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        let instance = GitLabInstance(name: instanceDisplayName(for: url), baseURL: url, authMethod: authMethod)
        do {
            switch authMethod {
            case .pat:
                try await authService.loginWithPAT(
                    instance: instance,
                    token: token.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            case .oauth:
                guard let redirectURI = normalizedRedirectURI else {
                    throw OAuthError.invalidRedirectURI
                }
                try await authService.loginWithOAuth(
                    instance: instance,
                    clientID: oauthClientID.trimmingCharacters(in: .whitespacesAndNewlines),
                    redirectURI: redirectURI
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var normalizedInstanceURL: URL? {
        GitLabBaseURLNormalizer.normalize(instanceURL)
    }

    private var normalizedRedirectURI: URL? {
        let trimmed = oauthRedirectURI.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme != nil else { return nil }
        return url
    }

    private func instanceDisplayName(for url: URL) -> String {
        let trimmedName = instanceName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            return trimmedName
        }
        return url.host ?? "GitLab"
    }
}

#Preview {
    LoginView()
        .environment(AuthService())
}
