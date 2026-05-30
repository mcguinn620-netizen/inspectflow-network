import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var todayJobCount = 0
    @Published var activeTrip: Trip?
    @Published var nextTripStop: TripStop?
    @Published var nextJob: Job?
    @Published var nextStopData: NextStopData?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let resumableStatuses = ["active", "paused", "planned", "draft"]
    private let incompleteJobStatuses = ["scheduled", "in_progress"]
    private let incompleteStopStatuses = ["pending", "arrived"]

    func load(orgId: UUID?, userId: UUID?) async {
        guard let userId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let trips = try await SupabaseService.shared.fetchTrips(userId: userId, limit: 5)
            let currentTrip = trips.first { resumableStatuses.contains($0.status) }
            activeTrip = currentTrip
            nextTripStop = nil
            nextJob = nil
            nextStopData = nil

            if let orgId {
                let jobs = try await SupabaseService.shared.fetchJobs(orgId: orgId, limit: 50)
                let cal = Calendar.current
                let todaysJobs = jobs.filter {
                    guard let d = $0.scheduledAt else { return false }
                    return cal.isDateInToday(d)
                }
                todayJobCount = todaysJobs.count
                nextJob = todaysJobs.first { incompleteJobStatuses.contains($0.status) }
            }

            if let tripId = currentTrip?.id {
                let stops = try await SupabaseService.shared.fetchTripStops(tripId: tripId)
                nextStopData = NextStopData.resolve(trip: currentTrip, stops: stops)
                nextTripStop = nextStopData?.stop
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startTodayTrip(orgId: UUID?, userId: UUID?) async {
        if activeTrip != nil {
            await resumeActiveTrip(orgId: orgId, userId: userId)
            return
        }

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
        guard let trip = activeTrip else { return }
        TripTrackingController.shared.pause()
        do {
            _ = try await SupabaseService.shared.setTripStatus(trip, status: "paused")
            AuditLogger.log(action: "update", entityType: "trip", entityId: trip.id, changes: ["status": "paused"])
            await load(orgId: orgId, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resumeActiveTrip(orgId: UUID?, userId: UUID?) async {
        guard let trip = activeTrip, let userId, let organizationId = trip.organizationID ?? orgId else { return }
        do {
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
            _ = try await SupabaseService.shared.setTripStatus(trip, status: "active")
            AuditLogger.log(action: "update", entityType: "trip", entityId: trip.id, changes: ["status": "active"])
            await load(orgId: orgId, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func completeActiveStop(orgId: UUID?, userId: UUID?) async {
        do {
            if let stop = nextTripStop {
                _ = try await SupabaseService.shared.setStopStatus(stop, status: "completed", completeJob: true)
                AuditLogger.log(action: "update", entityType: "trip_stop", entityId: stop.id, changes: ["status": "completed"])
            } else if let job = nextJob {
                try await SupabaseService.shared.updateJobStatus(jobId: job.id, status: "completed")
                AuditLogger.log(action: "update", entityType: "job", entityId: job.id, changes: ["status": "completed"])
            } else {
                return
            }
            await load(orgId: orgId, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
