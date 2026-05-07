import SwiftUI

struct JobsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = JobsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.jobs.isEmpty {
                    ProgressView()
                } else if viewModel.jobs.isEmpty {
                    ContentUnavailableCompat(
                        title: "No jobs",
                        message: viewModel.errorMessage ?? "Jobs assigned to your organization will appear here."
                    )
                } else {
                    List(viewModel.jobs) { job in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(job.title).font(.headline)
                            HStack(spacing: 8) {
                                Text(job.status.capitalized)
                                    .font(.caption).foregroundColor(.secondary)
                                if let when = job.scheduledAt {
                                    Text(when, style: .date).font(.caption).foregroundColor(.secondary)
                                }
                            }
                            if let loc = job.location {
                                Text(loc).font(.caption2).foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Jobs")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { SyncStatusView() } }
            .refreshable { await viewModel.load(orgId: appState.activeOrganizationID) }
            .task { await viewModel.load(orgId: appState.activeOrganizationID) }
        }
    }
}
