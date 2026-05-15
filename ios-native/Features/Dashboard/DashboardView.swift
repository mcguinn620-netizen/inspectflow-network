import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = DashboardViewModel()
    @State private var toast: AINToast?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AINTheme.Spacing.lg) {
                    headerCard
                    todayCard
                    activeTripCard
                    quickActions
                    if let err = viewModel.errorMessage {
                        AINErrorState(message: err) {
                            Task { await reload() }
                        }
                        .padding(.top, AINTheme.Spacing.md)
                    }
                }
                .padding(.horizontal, AINTheme.Spacing.lg)
                .padding(.vertical, AINTheme.Spacing.lg)
            }
            .background(AINTheme.Color.background.ignoresSafeArea())
            .navigationTitle("Dashboard")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { SyncStatusView() } }
            .refreshable { await reload() }
            .task { await reload() }
            .ainToast($toast)
        }
    }

    // MARK: - Sections

    private var headerCard: some View {
        AINCard {
            VStack(alignment: .leading, spacing: AINTheme.Spacing.sm) {
                Text(greeting)
                    .font(AINTheme.Font.caption(13))
                    .foregroundColor(AINTheme.Color.textSecondary)
                Text(AINBrand.tagline)
                    .font(AINTheme.Font.title(20))
                    .foregroundColor(AINTheme.Color.textPrimary)
            }
        }
    }

    private var todayCard: some View {
        AINCard {
            VStack(alignment: .leading, spacing: AINTheme.Spacing.md) {
                AINSectionHeader(
                    title: "Today",
                    subtitle: Date().formatted(date: .complete, time: .omitted)
                )
                if viewModel.isLoading {
                    HStack(spacing: AINTheme.Spacing.md) {
                        AINSkeleton(height: 56).frame(maxWidth: .infinity)
                        AINSkeleton(height: 56).frame(maxWidth: .infinity)
                    }
                } else {
                    HStack(spacing: AINTheme.Spacing.md) {
                        statTile(label: "Jobs today", value: "\(viewModel.todayJobCount)", icon: "briefcase.fill", tone: .info)
                        statTile(
                            label: "Trip status",
                            value: viewModel.activeTrip?.status.capitalized ?? "Idle",
                            icon: "map.fill",
                            tone: viewModel.activeTrip == nil ? .neutral : .pass
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var activeTripCard: some View {
        if let trip = viewModel.activeTrip {
            AINCard {
                VStack(alignment: .leading, spacing: AINTheme.Spacing.md) {
                    AINSectionHeader(
                        title: "Active trip",
                        trailing: AnyView(AINStatusPill.forStatus(trip.status))
                    )
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Miles").font(AINTheme.Font.caption()).foregroundColor(AINTheme.Color.textSecondary)
                            Text(String(format: "%.1f", trip.totalMiles ?? 0))
                                .font(AINTheme.Font.display(28))
                                .foregroundColor(AINTheme.Color.textPrimary)
                        }
                        Spacer()
                        if let started = trip.startedAt {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Started").font(AINTheme.Font.caption()).foregroundColor(AINTheme.Color.textSecondary)
                                Text(started, style: .time)
                                    .font(AINTheme.Font.bodyEmphasized())
                                    .foregroundColor(AINTheme.Color.textPrimary)
                            }
                        }
                    }
                }
            }
        }
    }

    private var quickActions: some View {
        AINCard {
            VStack(alignment: .leading, spacing: AINTheme.Spacing.md) {
                AINSectionHeader(title: "Quick actions")
                HStack(spacing: AINTheme.Spacing.md) {
                    AINSecondaryButton("New trip", systemImage: "plus.circle.fill") {
                        toast = AINToast(message: "Trip creation coming next step", tone: .info)
                    }
                    AINSecondaryButton("Refresh", systemImage: "arrow.clockwise") {
                        Task { await reload() }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func statTile(label: String, value: String, icon: String, tone: AINStatusTone) -> some View {
        VStack(alignment: .leading, spacing: AINTheme.Spacing.xs) {
            HStack(spacing: AINTheme.Spacing.xs) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold)).foregroundColor(tone.fg)
                Text(label).font(AINTheme.Font.caption(12)).foregroundColor(AINTheme.Color.textSecondary)
            }
            Text(value)
                .font(AINTheme.Font.title(22))
                .foregroundColor(AINTheme.Color.textPrimary)
        }
        .padding(AINTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tone.bg.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: AINTheme.Radius.md, style: .continuous))
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default:      return "Hello"
        }
    }

    private func reload() async {
        await viewModel.load(
            orgId: appState.activeOrganizationID,
            userId: SupabaseService.shared.currentUserID
        )
    }
}
