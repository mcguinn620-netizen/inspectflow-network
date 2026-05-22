import SwiftUI

struct InspectorDashboardHomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AINTheme.Spacing.lg) {
                    ActiveTripBanner(activeTrip: viewModel.activeTrip)
                    NextStopCard(activeTrip: viewModel.activeTrip)
                    StartMyDayCard(
                        hasJobsToday: viewModel.todayJobCount > 0,
                        todayJobCount: viewModel.todayJobCount,
                        activeTrip: viewModel.activeTrip,
                        onStartTodayTrip: startTrip
                    )
                }
                .padding(.horizontal, AINTheme.Spacing.lg)
                .padding(.vertical, AINTheme.Spacing.lg)
            }
            .background(AINTheme.Color.background.ignoresSafeArea())
            .navigationTitle("Dashboard")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { SyncStatusView() } }
            .refreshable { await reload() }
            .task { await reload() }
        }
    }

    private func reload() async {
        await viewModel.load(orgId: appState.activeOrganizationID, userId: SupabaseService.shared.currentUserID)
    }

    private func startTrip() {
        // Step 3.5 scaffold: trip start action wires to Trips in next iteration.
    }
}
