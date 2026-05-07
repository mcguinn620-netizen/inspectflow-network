import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section("Today") {
                    LabeledContent("Jobs", value: "\(viewModel.todayJobCount)")
                    if let trip = viewModel.activeTrip {
                        LabeledContent("Active trip", value: trip.status.capitalized)
                        LabeledContent("Miles", value: String(format: "%.1f", trip.totalMiles ?? 0))
                    } else {
                        Text("No active trip").foregroundColor(.secondary)
                    }
                }
                if let err = viewModel.errorMessage {
                    Section { Text(err).foregroundColor(AINBrand.fail).font(.footnote) }
                }
            }
            .navigationTitle("Dashboard")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { SyncStatusView() } }
            .refreshable { await reload() }
            .task { await reload() }
        }
    }

    private func reload() async {
        await viewModel.load(
            orgId: appState.activeOrganizationID,
            userId: SupabaseService.shared.currentUserID
        )
    }
}
