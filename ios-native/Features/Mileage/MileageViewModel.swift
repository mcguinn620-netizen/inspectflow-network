import Foundation

/// Backs `MileageView`. Reuses the trip-tracking flows from the legacy
/// `TripsViewModel` so the active-trip banner keeps working unchanged.
@MainActor
final class MileageViewModel: ObservableObject {
    @Published var trips: [Trip] = []
    @Published var perMileRate: Double = MileageDeduction.currentIRSRate
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var realtime: RealtimeSubscription?

    func load() async {
        guard let uid = SupabaseService.shared.currentUserID else { return }

        if let cached: [Trip] = CoreDataCache.shared.load([Trip].self, for: CacheKeys.trips(uid)) {
            trips = cached
        }

        isLoading = true
        defer { isLoading = false }
        do {
            async let freshTrips = SupabaseService.shared.fetchTrips(userId: uid, limit: 200)
            async let rate = SupabaseService.shared.fetchPerMileRate(userId: uid)
            trips = try await freshTrips
            perMileRate = try await rate
            CoreDataCache.shared.save(trips, for: CacheKeys.trips(uid))
            errorMessage = nil
            await ensureRealtime(userId: uid)
        } catch {
            errorMessage = AINFriendlyError.message(for: error)
        }
    }

    private func ensureRealtime(userId: UUID) async {
        guard realtime == nil else { return }
        realtime = await RealtimeSubscriptions.trips(userId: userId) { [weak self] _ in
            Task { @MainActor in await self?.load() }
        }
    }

    // MARK: - Write flow (mirrors TripsViewModel)

    func startTrip(orgId: UUID) async {
        guard let uid = SupabaseService.shared.currentUserID else { return }
        do {
            let trip = try await SupabaseService.shared.createTrip(
                orgId: orgId, userId: uid,
                title: "Trip \(Date().formatted(date: .abbreviated, time: .shortened))"
            )
            TripTrackingController.shared.start(tripId: trip.id, organizationId: orgId, userId: uid)
            AuditLogger.log(action: "create", entityType: "trip", entityId: trip.id)
            await load()
        } catch {
            errorMessage = AINFriendlyError.message(for: error)
        }
    }

    func pauseTrip() async {
        guard let snap = TripTrackingController.shared.snapshot else { return }
        TripTrackingController.shared.pause()
        do {
            try await SupabaseService.shared.updateTripStatus(
                tripId: snap.tripId, status: "paused",
                extras: ["paused_at": ISO8601DateFormatter().string(from: Date())]
            )
        } catch { errorMessage = AINFriendlyError.message(for: error) }
    }

    func resumeTrip() async {
        guard let snap = TripTrackingController.shared.snapshot else { return }
        TripTrackingController.shared.resume()
        do {
            try await SupabaseService.shared.updateTripStatus(tripId: snap.tripId, status: "active")
        } catch { errorMessage = AINFriendlyError.message(for: error) }
    }

    func completeTrip() async {
        guard let snap = TripTrackingController.shared.snapshot else { return }
        let tripId = snap.tripId
        let totalMiles = snap.totalMiles
        TripTrackingController.shared.stop()
        do {
            try await SupabaseService.shared.updateTripStatus(
                tripId: tripId, status: "completed",
                extras: [
                    "completed_at": ISO8601DateFormatter().string(from: Date()),
                    "total_miles": totalMiles,
                ]
            )
            await load()
        } catch { errorMessage = AINFriendlyError.message(for: error) }
    }
}
