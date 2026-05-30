import SwiftUI

struct InspectorDashboardHomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AINTheme.Spacing.lg) {
                    ActiveTripBanner(activeTrip: viewModel.activeTrip) {
                        Task { await pauseTrip() }
                    }
                    NextStopCard(
                        activeTrip: viewModel.activeTrip,
                        nextTripStop: viewModel.nextTripStop,
                        nextJob: viewModel.nextJob,
                        onNavigate: openNextStop,
                        onCompleteStop: { Task { await completeStop() } }
                    )
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
        Task {
            if viewModel.activeTrip != nil {
                await viewModel.resumeActiveTrip(orgId: appState.activeOrganizationID, userId: SupabaseService.shared.currentUserID)
            } else {
                await viewModel.startTodayTrip(orgId: appState.activeOrganizationID, userId: SupabaseService.shared.currentUserID)
            }
        }
    }

    private func pauseTrip() async {
        await viewModel.pauseActiveTrip(orgId: appState.activeOrganizationID, userId: SupabaseService.shared.currentUserID)
    }

    private func completeStop() async {
        await viewModel.completeActiveStop(orgId: appState.activeOrganizationID, userId: SupabaseService.shared.currentUserID)
    }

    private func openNextStop() {
        if let stop = viewModel.nextTripStop {
            MapsLookupService.shared.open(stop: stop)
        } else if let job = viewModel.nextJob {
            MapsLookupService.shared.open(job: job)
        }
    }
}
