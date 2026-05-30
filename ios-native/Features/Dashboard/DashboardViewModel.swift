import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var todayJobCount = 0
    @Published var activeTrip: Trip?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(orgId: UUID?, userId: UUID?) async {
        guard let userId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let trips = try await SupabaseService.shared.fetchTrips(userId: userId, limit: 5)
            activeTrip = trips.first { ["active", "paused", "planned", "draft"].contains($0.status) }
            if let orgId {
                let jobs = try await SupabaseService.shared.fetchJobs(orgId: orgId, limit: 50)
                let cal = Calendar.current
                todayJobCount = jobs.filter {
                    guard let d = $0.scheduledAt else { return false }
                    return cal.isDateInToday(d)
                }.count
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startTodayTrip(orgId: UUID?, userId: UUID?) async {
        guard let orgId, let userId else { return }
        do {
            let trip = try await SupabaseService.shared.createTrip(
                orgId: orgId,
                userId: userId,
                title: "Inspector route \(Date().formatted(date: .abbreviated, time: .omitted))"
            )
            TripTrackingController.shared.start(tripId: trip.id, organizationId: orgId, userId: userId)
            AuditLogger.log(action: "create", entityType: "trip", entityId: trip.id)
            await load(orgId: orgId, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func pauseActiveTrip(orgId: UUID?, userId: UUID?) async {
        guard let tripId = activeTrip?.id else { return }
        TripTrackingController.shared.pause()
        do {
            try await SupabaseService.shared.updateTripStatus(
                tripId: tripId,
                status: "paused",
                extras: ["paused_at": ISO8601DateFormatter().string(from: Date())]
            )
            AuditLogger.log(action: "update", entityType: "trip", entityId: tripId, changes: ["status": "paused"])
            await load(orgId: orgId, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resumeActiveTrip(orgId: UUID?, userId: UUID?) async {
        guard let tripId = activeTrip?.id else { return }
        TripTrackingController.shared.resume()
        do {
            try await SupabaseService.shared.updateTripStatus(tripId: tripId, status: "active")
            AuditLogger.log(action: "update", entityType: "trip", entityId: tripId, changes: ["status": "active"])
            await load(orgId: orgId, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func completeActiveStop(orgId: UUID?, userId: UUID?) async {
        guard let tripId = activeTrip?.id else { return }
        do {
            try await SupabaseService.shared.updateTripStatus(
                tripId: tripId,
                status: "completed",
                extras: ["completed_at": ISO8601DateFormatter().string(from: Date())]
            )
            TripTrackingController.shared.stop()
            AuditLogger.log(action: "update", entityType: "trip", entityId: tripId, changes: ["status": "completed"])
            await load(orgId: orgId, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

}
