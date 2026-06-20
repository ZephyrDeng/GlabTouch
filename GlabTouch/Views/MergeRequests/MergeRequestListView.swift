import SwiftUI

struct MergeRequestListView: View {
    @State private var viewModel = MergeRequestListViewModel()

    var body: some View {
        NavigationStack {
            List {
                if viewModel.mergeRequests.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "No Merge Requests",
                        systemImage: "arrow.triangle.merge",
                        description: Text("Connect to a GitLab instance to see your merge requests.")
                    )
                }

                ForEach(viewModel.mergeRequests) { mr in
                    MergeRequestRowView(mergeRequest: mr)
                }
            }
            .navigationTitle("Merge Requests")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Picker("Filter", selection: $viewModel.selectedFilter) {
                        ForEach(MergeRequestListViewModel.MRFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
        }
    }
}

#Preview {
    MergeRequestListView()
}
