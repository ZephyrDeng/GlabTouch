import SwiftUI

struct MergeRequestListView: View {
    @Environment(AuthService.self) private var authService
    @State private var viewModel = MergeRequestListViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Filter", selection: $viewModel.selectedFilter) {
                    ForEach(MergeRequestListViewModel.MRFilter.allCases) { filter in
                        Text(LocalizedStringKey(filter.rawValue)).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                List {
                    if viewModel.mergeRequests.isEmpty && !viewModel.isLoading {
                        ContentUnavailableView(
                            "No Merge Requests",
                            systemImage: "arrow.triangle.merge",
                            description: Text("No merge requests found for this filter.")
                        )
                    }

                    ForEach(viewModel.mergeRequests) { mr in
                        NavigationLink {
                            MergeRequestDetailView(mergeRequest: mr)
                        } label: {
                            MergeRequestRowView(mergeRequest: mr)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Merge Requests")
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .refreshable {
                await loadData()
            }
            .task {
                await loadData()
            }
            .onChange(of: viewModel.selectedFilter) {
                Task { await loadData() }
            }
        }
    }

    private func loadData() async {
        guard let instance = authService.currentInstance,
              let token = authService.accessToken else { return }
        let client = GitLabAPIClient(baseURL: instance.baseURL, token: token, authMethod: instance.authMethod)
        await viewModel.loadMergeRequests(client: client)
    }
}

#Preview {
    MergeRequestListView()
        .environment(AuthService())
}
