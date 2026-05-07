import SwiftUI

struct InspectionsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = InspectionsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.requests.isEmpty {
                    ContentUnavailableCompat(
                        title: "No inspection requests",
                        message: viewModel.errorMessage ?? "Incoming inspection requests will appear here."
                    )
                } else {
                    List(viewModel.requests) { r in
                        HStack {
                            Text(r.status.capitalized).font(.headline)
                            Spacer()
                            if let d = r.scheduledAt ?? r.createdAt {
                                Text(d, style: .date).font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Inspections")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { SyncStatusView() } }
            .refreshable { await viewModel.load(orgId: appState.activeOrganizationID) }
            .task { await viewModel.load(orgId: appState.activeOrganizationID) }
        }
    }
}
