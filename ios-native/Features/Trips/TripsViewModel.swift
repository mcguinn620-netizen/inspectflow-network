import Foundation
import InspectFlowConnector

@MainActor
final class TripsViewModel: ObservableObject {
    @Published var trips: [Trip] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var activeTripID: UUID?

    private var realtime: RealtimeSubscription?

    func load() async {
        guard let uid = SupabaseService.shared.currentUserID else { return }

        // Hydrate from cache first.
        if let cached: [Trip] = CoreDataCache.shared.load([Trip].self, for: CacheKeys.trips(uid)) {
            trips = cached
        }

        isLoading = true
        defer { isLoading = false }
        do {
            let fresh = try await SupabaseService.shared.fetchTrips(userId: uid)
            trips = fresh
            CoreDataCache.shared.save(fresh, for: CacheKeys.trips(uid))
            errorMessage = nil
            activeTripID = TripTrackingController.shared.snapshot?.tripId
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

    // MARK: - Write flow

    func startTrip(orgId: UUID) async {
        guard let uid = SupabaseService.shared.currentUserID else { return }
        do {
            let trip = try await SupabaseService.shared.createTrip(
                orgId: orgId, userId: uid, title: "Trip \(Date().formatted(date: .abbreviated, time: .shortened))"
            )
            TripTrackingController.shared.start(
                tripId: trip.id, organizationId: orgId, userId: uid
            )
            AuditLogger.log(action: "create", entityType: "trip", entityId: trip.id)
            activeTripID = trip.id
            await load()
        } catch {
            errorMessage = error.localizedDescription
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
            AuditLogger.log(action: "update", entityType: "trip", entityId: snap.tripId,
                            changes: ["status": "paused"])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resumeTrip() async {
        guard let snap = TripTrackingController.shared.snapshot else { return }
        TripTrackingController.shared.resume()
        do {
            try await SupabaseService.shared.updateTripStatus(tripId: snap.tripId, status: "active")
            AuditLogger.log(action: "update", entityType: "trip", entityId: snap.tripId,
                            changes: ["status": "active"])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func completeTrip() async {
        guard let snap = TripTrackingController.shared.snapshot else { return }
        let tripId = snap.tripId
        let totalMiles = snap.totalMiles
        TripTrackingController.shared.stop()
        activeTripID = nil
        do {
            try await SupabaseService.shared.updateTripStatus(
                tripId: tripId, status: "completed",
                extras: [
                    "completed_at": ISO8601DateFormatter().string(from: Date()),
                    "total_miles": totalMiles,
                ]
            )
            AuditLogger.log(action: "update", entityType: "trip", entityId: tripId,
                            changes: ["status": "completed", "total_miles": totalMiles])
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
