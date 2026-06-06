import Foundation

/// Thin app-facing facade over `InspectFlowClient`.
final class SupabaseService {
    static let shared = SupabaseService()
    private init() {}

    private var client: InspectFlowClient { SupabaseClientProvider.shared }

    private struct MutationID: Decodable { let id: UUID }

    enum TripLifecycleError: LocalizedError {
        case missingCurrentUser
        case terminalTrip
        case invalidTripTransition
        case terminalStop
        case invalidStopTransition

        var errorDescription: String? {
            switch self {
            case .missingCurrentUser: return "No signed-in user is available."
            case .terminalTrip: return "This trip is already completed or canceled."
            case .invalidTripTransition: return "This trip cannot move to the requested status."
            case .terminalStop: return "This stop is already completed or skipped."
            case .invalidStopTransition: return "This stop cannot move to the requested status."
            }
        }
    }

    private let activeTripStatuses = ["active", "planned", "draft", "paused"]
    private let terminalTripStatuses = ["completed", "canceled"]
    private let terminalStopStatuses = ["completed", "skipped"]
    private let terminalJobStatuses = ["completed", "canceled"]

    // MARK: - Auth

    var currentUserID: UUID? { client.auth.currentUser?.id }
    var hasSession: Bool { client.auth.currentSession != nil }

    @discardableResult
    func signIn(email: String, password: String) async throws -> InspectFlowSession {
        try await client.auth.signIn(email: email, password: password)
    }

    @discardableResult
    func signUp(email: String, password: String, fullName: String) async throws -> InspectFlowSession {
        try await client.auth.signUp(
            email: email,
            password: password,
            metadata: ["full_name": fullName, "role": "inspector"]
        )
    }

    func signOut() async throws { try await client.auth.signOut() }

    // MARK: - Profile

    func fetchMyProfile(userId: UUID) async throws -> UserProfile {
        try await client.db.from("profiles")
            .select()
            .eq("id", userId.uuidString)
            .single()
            .execute()
    }

    func fetchDefaultOrganization(userId: UUID) async throws -> OrganizationMembership? {
        let memberships: [OrganizationMembership] = try await client.db.from("organization_users")
            .select()
            .eq("user_id", userId.uuidString)
            .order("is_default", ascending: false)
            .limit(1)
            .execute()
        return memberships.first
    }

    // MARK: - Trips

    func fetchTrips(userId: UUID, limit: Int = 50) async throws -> [Trip] {
        try await client.db.from("trips")
            .select()
            .eq("user_id", userId.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
    }

    func fetchLatestCurrentTrip(userId: UUID? = nil) async throws -> Trip? {
        let uid: UUID
        if let userId { uid = userId }
        else if let currentUserID { uid = currentUserID }
        else { throw TripLifecycleError.missingCurrentUser }

        let trips: [Trip] = try await client.db.from("trips")
            .select()
            .eq("user_id", uid.uuidString)
            .in("status", activeTripStatuses)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
        return trips.first
    }

    // MARK: - Jobs

    func fetchJobs(orgId: UUID, limit: Int = 50) async throws -> [Job] {
        try await client.db.from("jobs")
            .select()
            .eq("organization_id", orgId.uuidString)
            .isNull("deleted_at")
            .order("scheduled_at", ascending: true)
            .limit(limit)
            .execute()
    }
    
    func createJob(
    orgId: UUID,
    title: String,
    customerName: String?,
    location: String?,
    scheduledAt: Date?) async throws -> Job {

    struct Payload: Encodable {
        let organization_id: UUID
        let title: String
        let customer_name: String?
        let location: String?
        let scheduled_at: Date?
        let status: String
    }

    let payload = Payload(
        organization_id: orgId,
        title: title,
        customer_name: customerName,
        location: location,
        scheduled_at: scheduledAt,
        status: "scheduled"
    )

    let created: [Job] = try await client.db
        .from("jobs")
        .insert(payload)
        .select()
        .execute()

    guard let job = created.first else {
        throw NSError(
            domain: "InspectFlow",
            code: -1,
            userInfo: [
                NSLocalizedDescriptionKey:
                "Failed to create job"
            ]
        )
    }

    return job
    }


    // MARK: - Job mutations

    func updateJobSchedule(jobId: UUID, scheduledAt: Date) async throws {
        _ = try await client.db.from("jobs")
            .update(["scheduled_at": ISO8601DateFormatter().string(from: scheduledAt)])
            .eq("id", jobId.uuidString)
            .execute()
    }

    func updateJobStatus(jobId: UUID, status: String) async throws {
        _ = try await client.db.from("jobs")
            .update(["status": status])
            .eq("id", jobId.uuidString)
            .execute()
    }

    func assignJob(jobId: UUID, inspectorId: UUID) async throws {
        _ = try await client.db.from("jobs")
            .update(["assigned_inspector_id": inspectorId.uuidString])
            .eq("id", jobId.uuidString)
            .execute()
    }

    func fetchOrgInspectors(orgId: UUID) async throws -> [OrganizationMembership] {
        let rows: [OrganizationMembership] = try await client.db.from("organization_users")
            .select()
            .eq("organization_id", orgId.uuidString)
            .eq("role", "inspector")
            .limit(100)
            .execute()
        return rows
    }

    // MARK: - Vehicles

    func fetchVehicles(orgId: UUID, limit: Int = 100) async throws -> [Vehicle] {
        try await client.db.from("vehicles")
            .select()
            .eq("organization_id", orgId.uuidString)
            .limit(limit)
            .execute()
    }

    // MARK: - Inspection requests

    func fetchInspectionRequests(orgId: UUID, limit: Int = 50) async throws -> [InspectionRequest] {
        try await client.db.from("inspection_requests")
            .select()
            .eq("organization_id", orgId.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
    }

    // MARK: - Templates

    func fetchTemplate(templateId: UUID) async throws -> InspectionTemplate {
        try await client.db.from("inspection_templates")
            .select()
            .eq("id", templateId.uuidString)
            .single()
            .execute()
    }

    func fetchTemplateSections(templateId: UUID) async throws -> [TemplateSection] {
        try await client.db.from("template_sections")
            .select()
            .eq("template_id", templateId.uuidString)
            .order("sort_order", ascending: true)
            .execute()
    }

    func fetchTemplateItems(sectionIds: [UUID]) async throws -> [TemplateChecklistItem] {
        guard !sectionIds.isEmpty else { return [] }
        return try await client.db.from("template_checklist_items")
            .select()
            .in("section_id", sectionIds.map { $0.uuidString })
            .order("sort_order", ascending: true)
            .execute()
    }

    // MARK: - Inspection submission

    func submitInspectionScore(requestId: UUID, score: InspectionScoreResult) async throws {
        let row: [String: Any] = [
            "inspection_request_id": requestId.uuidString,
            "overall_score": score.overallScore,
            "vehicle_condition_rating": score.conditionRating,
            "section_scores": score.sectionScores,
        ]
        _ = try await client.db.from("inspection_scores").insert(row).execute()
        _ = try await client.db.from("inspection_requests")
            .update([
                "status": "awaiting_review",
                "overall_score": score.overallScore,
                "vehicle_condition_rating": score.conditionRating,
            ])
            .eq("id", requestId.uuidString)
            .execute()
    }

    // MARK: - Photo upload

    func uploadInspectionPhoto(orgId: UUID, requestId: UUID, data: Data) async throws -> String {
        let filename = "\(UUID().uuidString).jpg"
        let path = "\(orgId.uuidString)/\(requestId.uuidString)/\(filename)"
        try await client.storage.upload(
            bucket: "inspection-photos",
            path: path,
            data: data,
            contentType: "image/jpeg",
            upsert: false
        )
        return path
    }

    // MARK: - Trip mutations

    func createTrip(orgId: UUID, userId: UUID, title: String?) async throws -> Trip {
        var row: [String: Any] = [
            "organization_id": orgId.uuidString,
            "user_id": userId.uuidString,
            "status": "active",
            "started_at": ISO8601DateFormatter().string(from: Date()),
        ]
        if let title { row["title"] = title }
        let inserted: [Trip] = try await client.db.from("trips").insert(row).execute()
        guard let trip = inserted.first else { throw InspectFlowError.invalidResponse }
        return trip
    }

    @discardableResult
    func updateTripStatus(tripId: UUID, status: String, extras: [String: Any] = [:]) async throws -> Bool {
        var row: [String: Any] = ["status": status]
        for (k, v) in extras { row[k] = v }
        let changed: [MutationID] = try await client.db.from("trips")
            .update(row)
            .eq("id", tripId.uuidString)
            .notIn("status", terminalTripStatuses)
            .execute()
        return !changed.isEmpty
    }

    @discardableResult
    func setTripStatus(_ trip: Trip, status: String) async throws -> Bool {
        if terminalTripStatuses.contains(trip.status) { throw TripLifecycleError.terminalTrip }
        if status == "completed" && !["active", "paused", "draft", "planned"].contains(trip.status) {
            throw TripLifecycleError.invalidTripTransition
        }

        var updates: [String: Any] = ["status": status]
        let now = ISO8601DateFormatter().string(from: Date())
        if status == "active" && trip.startedAt == nil { updates["started_at"] = now }
        if status == "paused" { updates["paused_at"] = now }
        if status == "completed" { updates["completed_at"] = now }

        let changed = try await updateTripStatus(tripId: trip.id, status: status, extras: updates.filter { $0.key != "status" })
        if changed {
            if status == "paused" { await MainActor.run { TripTrackingController.shared.pause() } }
            if status == "completed" || status == "canceled" { await MainActor.run { TripTrackingController.shared.stop() } }
        }
        return changed
    }

    func fetchTripStops(tripId: UUID, limit: Int = 50) async throws -> [TripStop] {
        try await client.db.from("trip_stops")
            .select()
            .eq("trip_id", tripId.uuidString)
            .order("sort_order", ascending: true)
            .limit(limit)
            .execute()
    }

    func fetchTripLocationPoints(tripId: UUID, limit: Int = 500) async throws -> [TripLocationPoint] {
        try await client.db.from("trip_location_points")
            .select("id,trip_id,latitude,longitude,recorded_at")
            .eq("trip_id", tripId.uuidString)
            .order("recorded_at", ascending: true)
            .limit(limit)
            .execute()
    }

    @discardableResult
    func updateTripStopStatus(stopId: UUID, status: String, extras: [String: Any] = [:]) async throws -> Bool {
        var row: [String: Any] = ["status": status]
        for (k, v) in extras { row[k] = v }
        let changed: [MutationID] = try await client.db.from("trip_stops")
            .update(row)
            .eq("id", stopId.uuidString)
            .notIn("status", terminalStopStatuses)
            .execute()
        return !changed.isEmpty
    }

    @discardableResult
    func setStopStatus(_ stop: TripStop, status: String, startJob: Bool = false, completeJob: Bool = false) async throws -> Bool {
        let currentStatus = stop.status ?? "pending"
        if terminalStopStatuses.contains(currentStatus) { throw TripLifecycleError.terminalStop }
        if status == "arrived" && currentStatus != "pending" { throw TripLifecycleError.invalidStopTransition }
        if status == "completed" && !["pending", "arrived"].contains(currentStatus) { throw TripLifecycleError.invalidStopTransition }
        if status == "skipped" && currentStatus != "pending" { throw TripLifecycleError.invalidStopTransition }

        let now = ISO8601DateFormatter().string(from: Date())
        var updates: [String: Any] = [:]
        if status == "arrived" && stop.arrivedAt == nil { updates["arrived_at"] = now }
        if status == "completed" {
            if stop.completedAt == nil { updates["completed_at"] = now }
            if stop.departedAt == nil { updates["departed_at"] = now }
            if stop.arrivedAt == nil { updates["arrived_at"] = now }
        }
        if status == "skipped" && stop.departedAt == nil { updates["departed_at"] = now }

        let changed = try await updateTripStopStatus(stopId: stop.id, status: status, extras: updates)
        guard changed else { return false }

        if let jobID = stop.jobID {
            if startJob { _ = try await startJobById(jobID) }
            if completeJob { _ = try await completeJobById(jobID) }
        }
        return true
    }

    @discardableResult
    private func startJobById(_ id: UUID) async throws -> Bool {
        let changed: [MutationID] = try await client.db.from("jobs")
            .update(["status": "in_progress", "actual_start_time": ISO8601DateFormatter().string(from: Date())])
            .eq("id", id.uuidString)
            .eq("status", "scheduled")
            .isNull("actual_start_time")
            .execute()
        return !changed.isEmpty
    }

    @discardableResult
    private func completeJobById(_ id: UUID) async throws -> Bool {
        let changed: [MutationID] = try await client.db.from("jobs")
            .update(["status": "completed", "actual_end_time": ISO8601DateFormatter().string(from: Date())])
            .eq("id", id.uuidString)
            .notIn("status", terminalJobStatuses)
            .isNull("actual_end_time")
            .execute()
        return !changed.isEmpty
    }
}
