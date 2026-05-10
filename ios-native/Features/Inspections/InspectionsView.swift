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
                        NavigationLink(value: r) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(r.status.replacingOccurrences(of: "_", with: " ").capitalized)
                                        .font(.headline)
                                    if let d = r.scheduledAt ?? r.createdAt {
                                        Text(d, style: .date)
                                            .font(.caption).foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Inspections")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { SyncStatusView() } }
            .navigationDestination(for: InspectionRequest.self) { req in
                if let orgId = appState.activeOrganizationID {
                    InspectionDetailView(request: req, orgId: orgId)
                }
            }
            .refreshable { await viewModel.load(orgId: appState.activeOrganizationID) }
            .task { await viewModel.load(orgId: appState.activeOrganizationID) }
        }
    }
}
