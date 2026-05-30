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
                        NavigationLink {
                            JobDetailView(
                                job: job,
                                onMarkComplete: { selectedJob in
                                    Task { await viewModel.markComplete(job: selectedJob, orgId: appState.activeOrganizationID) }
                                },
                                onReschedule: { selectedJob, scheduledAt in
                                    Task { await viewModel.reschedule(job: selectedJob, scheduledAt: scheduledAt, orgId: appState.activeOrganizationID) }
                                }
                            )
                        } label: {
                            JobRow(job: job)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Jobs")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { SyncStatusView() } }
            .refreshable { await viewModel.load(orgId: appState.activeOrganizationID) }
            .task { await viewModel.load(orgId: appState.activeOrganizationID) }
        }
    }
}

private struct JobRow: View {
    let job: Job

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(job.title)
                .font(.headline)
            HStack(spacing: 8) {
                Text(job.status.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let when = job.scheduledAt {
                    Text(when, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            if let loc = job.location {
                Text(loc)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
