import SwiftUI

struct LoginView: View {
    @Environment(AuthService.self) private var authService
    @State private var instanceURL = ""
    @State private var token = ""
    @State private var instanceName = "My GitLab"
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
                    SecureField("Personal Access Token", text: $token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                Section {
                    Button {
                        Task { await login() }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Sign In")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(instanceURL.isEmpty || token.isEmpty || isLoading)
                }
            }
            .navigationTitle("GlabTouch")
        }
    }

    private func login() async {
        guard let url = URL(string: instanceURL) else {
            errorMessage = "Invalid URL"
            return
        }

        isLoading = true
        defer { isLoading = false }

        let instance = GitLabInstance(name: instanceName, baseURL: url, authMethod: .pat)
        do {
            try await authService.loginWithPAT(instance: instance, token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    LoginView()
        .environment(AuthService())
}
