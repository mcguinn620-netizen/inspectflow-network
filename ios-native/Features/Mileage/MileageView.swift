import SwiftUI

/// Unified Mileage screen — replaces the prior `TripsView` + standalone `DriveView` link.
/// Top: YTD deduction + miles, deductions/income segmented control, active-trip banner.
/// Bottom: list of trips with `$amount` left, `Mileage (x.xx mi) — day` right.
/// FAB-style "+" opens `AddMileageActionSheet`.
struct MileageView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = MileageViewModel()
    @StateObject private var tracker = TripTrackingController.shared

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var segment: Segment = .deductions
    @State private var isAddSheetPresented = false

    enum Segment: String, CaseIterable, Identifiable {
        case deductions = "Deductions"
        case income = "Income"
        var id: Self { self }
    }

    private var yearChoices: [Int] {
        let now = Calendar.current.component(.year, from: Date())
        return Array((now - 4)...now).reversed()
    }

    private var tripsForYear: [Trip] {
        viewModel.trips.filter { trip in
            guard let date = trip.completedAt ?? trip.startedAt ?? trip.createdAt else { return false }
            return Calendar.current.component(.year, from: date) == selectedYear
        }
    }

    private var ytdDeduction: Double {
        MileageDeduction.total(forTrips: tripsForYear, ratePerMile: viewModel.perMileRate)
    }

    private var ytdMiles: Double { MileageDeduction.totalMiles(tripsForYear) }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                content

                AddMileageFAB { isAddSheetPresented = true }
                    .padding(.bottom, 16)
            }
            .background(AINTheme.Color.background.ignoresSafeArea())
            .navigationTitle("Mileage")
            .toolbar {
                ToolbarItem(placement: .principal) { yearMenu }
                ToolbarItem(placement: .navigationBarTrailing) { SyncStatusView() }
            }
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
            .sheet(isPresented: $isAddSheetPresented) {
                AddMileageActionSheet { action in
                    isAddSheetPresented = false
                    handle(action)
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Subviews

    private var yearMenu: some View {
        Menu {
            ForEach(yearChoices, id: \.self) { y in
                Button("\(String(y)) Deductions") { selectedYear = y }
            }
        } label: {
            HStack(spacing: 4) {
                Text("\(String(selectedYear)) Deductions").font(.headline)
                Image(systemName: "chevron.down").font(.caption2)
            }
            .foregroundStyle(AINTheme.Color.textPrimary)
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: AINTheme.Spacing.md) {
                statsHeader
                Picker("", selection: $segment) {
                    ForEach(Segment.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if let snap = tracker.snapshot {
                    MileageActiveTripBanner(snapshot: snap, viewModel: viewModel)
                        .padding(.horizontal)
                }

                tripList
                Color.clear.frame(height: 80) // spacer for FAB
            }
            .padding(.top, AINTheme.Spacing.md)
        }
    }

    private var statsHeader: some View {
        HStack(alignment: .top, spacing: AINTheme.Spacing.lg) {
            statCell(value: ytdDeduction.formatted(.currency(code: "USD").precision(.fractionLength(2))),
                     caption: "\(String(selectedYear)) Deductions")
            statCell(value: String(format: "%.2f mi", ytdMiles),
                     caption: "\(String(selectedYear)) Mileage")
        }
        .padding(.horizontal)
    }

    private func statCell(value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.system(size: 28, weight: .bold)).foregroundStyle(AINTheme.Color.textPrimary)
            Text(caption).font(.caption).foregroundStyle(AINTheme.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var tripList: some View {
        if segment == .income {
            ContentUnavailableCompat(title: "Income view coming soon",
                                      message: "Income entries will sync from your earnings settings.")
                .padding(.top, 40)
        } else if viewModel.isLoading && tripsForYear.isEmpty {
            ProgressView("Loading mileage").padding(.top, 40)
        } else if tripsForYear.isEmpty {
            ContentUnavailableCompat(title: "No mileage yet",
                                      message: "Tap + to track or add miles.")
                .padding(.top, 40)
        } else {
            VStack(spacing: 0) {
                ForEach(tripsForYear) { trip in
                    NavigationLink(value: trip.id) { MileageRow(trip: trip, ratePerMile: viewModel.perMileRate) }
                        .buttonStyle(.plain)
                    Divider().padding(.leading)
                }
            }
            .background(AINTheme.Color.surface)
            .navigationDestination(for: UUID.self) { id in
                if let trip = viewModel.trips.first(where: { $0.id == id }) {
                    MileageDetailView(trip: trip, ratePerMile: viewModel.perMileRate) {
                        Task { await viewModel.load() }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func handle(_ action: AddMileageActionSheet.Action) {
        switch action {
        case .trackMiles:
            if let orgId = appState.activeOrganizationID {
                Task { await viewModel.startTrip(orgId: orgId) }
            }
        case .addMileage, .addIncome, .addExpense:
            // Manual entry sheets land in a follow-up; surface a friendly stub for now.
            viewModel.errorMessage = "Manual entry coming soon."
        }
    }
}

// MARK: - Row

private struct MileageRow: View {
    let trip: Trip
    let ratePerMile: Double

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(MileageDeduction.amount(forMiles: trip.totalMiles ?? 0, ratePerMile: ratePerMile)
                    .formatted(.currency(code: "USD").precision(.fractionLength(2))))
                .font(.title3.bold())
                .frame(width: 96, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "Mileage  (%.2f mi)", trip.totalMiles ?? 0))
                    .font(.subheadline.weight(.semibold))
                if let date = trip.completedAt ?? trip.startedAt ?? trip.createdAt {
                    Text(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .font(.caption).foregroundStyle(AINTheme.Color.textSecondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Active trip banner

private struct MileageActiveTripBanner: View {
    let snapshot: TripTrackingController.Snapshot
    @ObservedObject var viewModel: MileageViewModel

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(snapshot.status == .live ? .green : .orange).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.status == .live ? "Live trip" : "Paused").font(.caption.bold())
                Text(String(format: "%.2f mi", snapshot.totalMiles)).font(.title3.monospacedDigit())
            }
            Spacer()
            if snapshot.status == .live {
                Button("Pause") { Task { await viewModel.pauseTrip() } }
            } else {
                Button("Resume") { Task { await viewModel.resumeTrip() } }
            }
            Button("End") { Task { await viewModel.completeTrip() } }
                .buttonStyle(.borderedProminent).tint(.red)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - FAB

private struct AddMileageFAB: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.black)
                .frame(width: 60, height: 60)
                .background(Color.yellow, in: Circle())
                .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        }
        .accessibilityLabel("Add mileage, income, expense, or track miles")
    }
}
