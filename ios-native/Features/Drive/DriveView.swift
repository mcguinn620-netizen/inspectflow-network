import Combine
import CoreLocation
import SwiftUI

@MainActor
final class DriveViewModel: ObservableObject {
    @Published var trip: Trip?
    @Published var stops: [TripStop] = []
    @Published var locationPoints: [TripLocationPoint] = []
    @Published var nextStopData: NextStopData?
    @Published var currentSample: LocationSample?
    @Published var isLoading = false
    @Published var isMutating = false
    @Published var errorMessage: String?

    private var locationCancellable: AnyCancellable?

    init(locationTracker: LocationTracker = LocationTracker.shared) {
        currentSample = locationTracker.latestSample
        locationCancellable = locationTracker.$latestSample
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sample in self?.currentSample = sample }
    }

    var completedStopCount: Int { stops.filter { ["completed", "skipped"].contains($0.status ?? "pending") }.count }
    var progressText: String { stops.isEmpty ? "No stops" : "\(completedStopCount) of \(stops.count) stops" }
    var progressFraction: Double { stops.isEmpty ? 0 : Double(completedStopCount) / Double(stops.count) }
    var isTripPaused: Bool { trip?.status == "paused" }
    var isTripActive: Bool { trip?.status == "active" }
    var canArrive: Bool { nextStopData?.stop.status == nil || nextStopData?.stop.status == "pending" }
    var canComplete: Bool { ["pending", "arrived"].contains(nextStopData?.stop.status ?? "") }
    var canSkip: Bool { nextStopData?.stop.status == "pending" || nextStopData?.stop.status == nil }

    var distanceText: String {
        guard let milesToNextStop else { return "Distance unavailable" }
        return String(format: "%.1f mi away", milesToNextStop)
    }

    var etaText: String {
        guard let miles = milesToNextStop else { return "ETA unavailable" }
        let mph = max((currentSample?.speed ?? 0) * 2.236936, 30)
        let minutes = max(Int((miles / mph) * 60), 1)
        return "~\(minutes) min"
    }

    private var milesToNextStop: Double? {
        guard let sample = currentSample, let coordinate = nextStopData?.coordinate else { return nil }
        let from = CLLocation(latitude: sample.latitude, longitude: sample.longitude)
        let to = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return from.distance(from: to) / 1609.344
    }

    func load(userId: UUID?) async {
        guard let userId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let currentTrip = try await SupabaseService.shared.fetchLatestCurrentTrip(userId: userId)
            trip = currentTrip
            if let tripId = currentTrip?.id {
                async let stopRows = SupabaseService.shared.fetchTripStops(tripId: tripId)
                async let pointRows = SupabaseService.shared.fetchTripLocationPoints(tripId: tripId)
                stops = try await stopRows
                locationPoints = try await pointRows
            } else {
                stops = []
                locationPoints = []
            }
            nextStopData = NextStopData.resolve(trip: currentTrip, stops: stops)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openMaps() {
        guard let stop = nextStopData?.stop else { return }
        MapsLookupService.shared.open(stop: stop)
    }

    func arrive(userId: UUID?) async { await setStop(status: "arrived", startJob: true, completeJob: false, userId: userId) }
    func complete(userId: UUID?) async { await setStop(status: "completed", startJob: false, completeJob: true, userId: userId) }
    func skip(userId: UUID?) async { await setStop(status: "skipped", startJob: false, completeJob: false, userId: userId) }

    func pause(userId: UUID?) async { await setTrip(status: "paused", userId: userId) }
    func resume(orgId: UUID?, userId: UUID?) async {
        if let trip, let userId, let organizationId = trip.organizationID ?? orgId {
            if TripTrackingController.shared.snapshot?.tripId == trip.id {
                TripTrackingController.shared.resume()
            } else {
                TripTrackingController.shared.start(
                    tripId: trip.id,
                    organizationId: organizationId,
                    userId: userId,
                    totalMiles: trip.totalMiles ?? 0
                )
            }
        }
        await setTrip(status: "active", userId: userId)
    }
    func endTrip(userId: UUID?) async { await setTrip(status: "completed", userId: userId) }

    private func setStop(status: String, startJob: Bool, completeJob: Bool, userId: UUID?) async {
        guard let stop = nextStopData?.stop else { return }
        isMutating = true
        defer { isMutating = false }
        do {
            _ = try await SupabaseService.shared.setStopStatus(stop, status: status, startJob: startJob, completeJob: completeJob)
            AuditLogger.log(action: "update", entityType: "trip_stop", entityId: stop.id, changes: ["status": status])
            await load(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func setTrip(status: String, userId: UUID?) async {
        guard let trip else { return }
        isMutating = true
        defer { isMutating = false }
        do {
            _ = try await SupabaseService.shared.setTripStatus(trip, status: status)
            AuditLogger.log(action: "update", entityType: "trip", entityId: trip.id, changes: ["status": status])
            await load(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct DriveView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("inspector.voice_cues_enabled") private var voiceCuesEnabled = true
    @StateObject private var viewModel = DriveViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AINTheme.Spacing.lg) {
                    tripStatusCard
                    nextStopCard
                    actionCard
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(AINTheme.Font.caption())
                            .foregroundColor(AINTheme.Color.fail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(AINTheme.Spacing.lg)
            }
            .background(AINTheme.Color.background.ignoresSafeArea())
            .navigationTitle("Drive")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { SyncStatusView() } }
            .refreshable { await reload() }
            .task { await reload() }
        }
    }

    private var tripStatusCard: some View {
        AINCard {
            VStack(alignment: .leading, spacing: AINTheme.Spacing.md) {
                HStack {
                    AINSectionHeader(title: "Current trip", subtitle: viewModel.progressText)
                    Spacer()
                    if let status = viewModel.trip?.status { AINStatusPill.forStatus(status) }
                }
                ProgressView(value: viewModel.progressFraction)
                    .tint(AINTheme.Color.accent)
                HStack(spacing: AINTheme.Spacing.md) {
                    metric("Distance", viewModel.distanceText, "point.topleft.down.curvedto.point.bottomright.up")
                    metric("ETA", viewModel.etaText, "clock.fill")
                }
                Toggle("Voice cues", isOn: $voiceCuesEnabled)
                    .font(AINTheme.Font.body())
            }
        }
    }

    private var nextStopCard: some View {
        AINCard {
            VStack(alignment: .leading, spacing: AINTheme.Spacing.md) {
                AINSectionHeader(title: "Next stop", subtitle: "Shared with Dashboard")
                if let next = viewModel.nextStopData {
                    Text(next.title)
                        .font(AINTheme.Font.title(22))
                        .foregroundColor(AINTheme.Color.textPrimary)
                    if let subtitle = next.subtitle {
                        Text(subtitle)
                            .font(AINTheme.Font.body())
                            .foregroundColor(AINTheme.Color.textSecondary)
                    }
                    AINSecondaryButton("Open Maps", systemImage: "map.fill") { viewModel.openMaps() }
                } else if viewModel.trip == nil {
                    Text("No active, paused, planned, or draft trip is assigned to you.")
                        .font(AINTheme.Font.caption())
                        .foregroundColor(AINTheme.Color.textSecondary)
                } else {
                    Text("All stops are completed or skipped.")
                        .font(AINTheme.Font.caption())
                        .foregroundColor(AINTheme.Color.textSecondary)
                }
            }
        }
    }

    private var actionCard: some View {
        AINCard {
            VStack(spacing: AINTheme.Spacing.md) {
                HStack(spacing: AINTheme.Spacing.md) {
                    AINSecondaryButton("Arrived", systemImage: "mappin.and.ellipse") { Task { await viewModel.arrive(userId: currentUserID) } }
                        .disabled(!viewModel.canArrive || viewModel.isMutating)
                    AINPrimaryButton("Complete", systemImage: "checkmark.circle.fill", isLoading: viewModel.isMutating, isDisabled: !viewModel.canComplete) {
                        Task { await viewModel.complete(userId: currentUserID) }
                    }
                }
                AINSecondaryButton("Skip stop", systemImage: "forward.fill") { Task { await viewModel.skip(userId: currentUserID) } }
                    .disabled(!viewModel.canSkip || viewModel.isMutating)
                HStack(spacing: AINTheme.Spacing.md) {
                    if viewModel.isTripPaused {
                        AINSecondaryButton("Resume trip", systemImage: "play.fill") { Task { await viewModel.resume(orgId: appState.activeOrganizationID, userId: currentUserID) } }
                    } else {
                        AINSecondaryButton("Pause trip", systemImage: "pause.fill") { Task { await viewModel.pause(userId: currentUserID) } }
                            .disabled(!viewModel.isTripActive)
                    }
                    AINSecondaryButton("End trip", systemImage: "stop.fill") { Task { await viewModel.endTrip(userId: currentUserID) } }
                        .disabled(viewModel.trip == nil || viewModel.isMutating)
                }
            }
        }
    }

    private func metric(_ label: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: AINTheme.Spacing.xs) {
            Label(label, systemImage: icon)
                .font(AINTheme.Font.caption(12))
                .foregroundColor(AINTheme.Color.textSecondary)
            Text(value)
                .font(AINTheme.Font.bodyEmphasized())
                .foregroundColor(AINTheme.Color.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AINTheme.Spacing.md)
        .background(AINTheme.Color.surfaceMuted, in: RoundedRectangle(cornerRadius: AINTheme.Radius.md, style: .continuous))
    }

    private var currentUserID: UUID? { SupabaseService.shared.currentUserID }

    private func reload() async {
        await viewModel.load(userId: currentUserID)
    }
}
