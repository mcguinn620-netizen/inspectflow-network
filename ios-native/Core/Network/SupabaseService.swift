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

    /// Under `AuthBypass`, the selected mock user stands in for the Supabase user.
    var currentUserID: UUID? { MockSession.userID ?? client.auth.currentUser?.id }
    var hasSession: Bool { MockSession.isActive || client.auth.currentSession != nil }


    @discardableResult
    func restoreAndValidateSession() async throws -> InspectFlowSession {
        try await client.auth.restoreAndValidateSession()
    }

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
        if MockSession.isActive {
            guard let row: UserProfile = try await MockSession.readOne("profiles") else {
                throw MockSession.MockSessionError.server("Profile not found for test user")
            }
            return row
        }
        return try await client.db.from("profiles")
            .select()
            .eq("id", userId.uuidString)
            .single()
            .execute()
    }

    func fetchDefaultOrganization(userId: UUID) async throws -> OrganizationMembership? {
        if MockSession.isActive, let orgId = MockSession.organizationID {
            return try await MockSession.readOne("organization_users",
                filters: [.eq("organization_id", orgId.uuidString)],
                order: "is_default", ascending: false)
        }
        let memberships: [OrganizationMembership] = try await client.db.from("organization_users")
            .select()
            .eq("user_id", userId.uuidString)
            .order("is_default", ascending: false)
            .limit(1)
            .execute()
        return memberships.first
    }

    // MARK: - Inspector Vehicles

    func fetchInspectorVehicles(userId: UUID) async throws -> [InspectorVehicle] {
        if MockSession.isActive {
            return try await MockSession.read("inspector_vehicles",
                filters: [.eq("is_archived", false)],
                order: "is_default", ascending: false)
        }
        return try await client.db.from("inspector_vehicles")
            .select()
            .eq("user_id", userId.uuidString)
            .eq("is_archived", false)
            .order("is_default", ascending: false)
            .execute()
    }

    func archiveInspectorVehicle(id: UUID) async throws {
        _ = try await client.db.from("inspector_vehicles")
            .update(["is_archived": true])
            .eq("id", id.uuidString)
            .execute()
    }

    func clearDefaultInspectorVehicle(userId: UUID) async throws {
        _ = try await client.db.from("inspector_vehicles")
            .update(["is_default": false])
            .eq("user_id", userId.uuidString)
            .execute()
    }

    func setDefaultInspectorVehicle(id: UUID) async throws {
        _ = try await client.db.from("inspector_vehicles")
            .update(["is_default": true])
            .eq("id", id.uuidString)
            .execute()
    }

    func createInspectorVehicle(
        userId: UUID,
        nickname: String,
        year: Int?,
        make: String,
        model: String,
        plate: String
    ) async throws {
        var payload: [String: Any] = [
            "user_id": userId.uuidString,
            "nickname": nickname,
            "make": make,
            "model": model,
            "license_plate": plate,
            "is_default": false,
            "is_archived": false
        ]
        if let year { payload["year"] = year }
        _ = try await client.db.from("inspector_vehicles")
            .insert(payload)
            .execute()
    }

    // MARK: - Trips


    func fetchTrips(userId: UUID, limit: Int = 50) async throws -> [Trip] {
        if MockSession.isActive {
            return try await MockSession.read("trips", order: "created_at", ascending: false, limit: limit)
        }
        return try await client.db.from("trips")
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

        if MockSession.isActive {
            let rows: [Trip] = try await MockSession.read("trips",
                filters: [.inList("status", activeTripStatuses)],
                order: "created_at", ascending: false, limit: 1)
            return rows.first
        }
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
        if MockSession.isActive {
            return try await MockSession.read("jobs",
                filters: [.eq("organization_id", orgId.uuidString), .isNull("deleted_at")],
                order: "scheduled_at", ascending: true, limit: limit)
        }
        return try await client.db.from("jobs")
            .select()
            .eq("organization_id", orgId.uuidString)
            .isNull("deleted_at")
            .order("scheduled_at", ascending: true)
            .limit(limit)
            .execute()
    }

    /// Fetches jobs scheduled within `[from, to)` for the org. Used by the
    /// Schedule week grid so all jobs in view come back, not just the first 50.
    func fetchJobs(orgId: UUID, from: Date, to: Date, limit: Int = 200) async throws -> [Job] {
        let iso = ISO8601DateFormatter()
        if MockSession.isActive {
            return try await MockSession.read("jobs",
                filters: [
                    .eq("organization_id", orgId.uuidString),
                    .isNull("deleted_at"),
                    .gte("scheduled_at", iso.string(from: from)),
                    .lt("scheduled_at", iso.string(from: to))
                ],
                order: "scheduled_at", ascending: true, limit: limit)
        }
        return try await client.db.from("jobs")
            .select()
            .eq("organization_id", orgId.uuidString)
            .isNull("deleted_at")
            .gte("scheduled_at", iso.string(from: from))
            .lt("scheduled_at", iso.string(from: to))
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

    var payload: [String: Any] = [
        "organization_id": orgId.uuidString,
        "title": title,
        "status": "scheduled"
    ]
    if let customerName { payload["customer_name"] = customerName }
    if let location { payload["location"] = location }
    if let scheduledAt { payload["scheduled_at"] = ISO8601DateFormatter().string(from: scheduledAt) }

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
        if MockSession.isActive {
            return try await MockSession.read("organization_users",
                filters: [.eq("organization_id", orgId.uuidString), .eq("role", "inspector")],
                limit: 100)
        }
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
        if MockSession.isActive {
            return try await MockSession.read("inspection_requests",
                filters: [.eq("organization_id", orgId.uuidString)],
                order: "created_at", ascending: false, limit: limit)
        }
        return try await client.db.from("inspection_requests")
            .select()
            .eq("organization_id", orgId.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
    }

    // MARK: - Intake

    func fetchIntakeItems(orgId: UUID, status: String? = nil, limit: Int = 100) async throws -> [IntakeItem] {
        if MockSession.isActive {
            var mockFilters: [MockSession.Filter] = [.eq("organization_id", orgId.uuidString)]
            if let status { mockFilters.append(.eq("status", status)) }
            return try await MockSession.read("intake_items",
                filters: mockFilters, order: "created_at", ascending: false, limit: limit)
        }
        var q = client.db.from("intake_items")
            .select()
            .eq("organization_id", orgId.uuidString)
        if let status { q = q.eq("status", status) }
        return try await q
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
    }

    func updateIntakeItemStatus(itemId: UUID, status: String) async throws {
        _ = try await client.db.from("intake_items")
            .update(["status": status])
            .eq("id", itemId.uuidString)
            .execute()
    }

    func convertIntakeItem(item: IntakeItem, edited: IntakeParsedData) async throws -> UUID {
        var payload: [String: Any] = [
            "organization_id": item.organizationID.uuidString,
            "status": "request_received",
            "template_name": edited.templateName ?? "Standard Inspection",
            "priority": edited.priority ?? "medium",
        ]
        if let v = edited.clientName { payload["client_name"] = v }
        if let v = edited.companyName { payload["company_name"] = v }
        if let v = edited.vin { payload["vin"] = v }
        if let v = edited.vehicleYear { payload["vehicle_year"] = v }
        if let v = edited.vehicleMake { payload["vehicle_make"] = v }
        if let v = edited.vehicleModel { payload["vehicle_model"] = v }
        if let v = edited.mileage { payload["mileage"] = v }
        if let v = edited.inspectionLocation { payload["inspection_location"] = v }
        if let v = edited.requestedDate { payload["requested_date"] = v }
        if let v = edited.inspectionType { payload["inspection_type"] = v }
        if let v = edited.notes { payload["notes"] = v }

        // POST + Prefer: return=representation returns the inserted row.
        // (After QueryBuilder fix, .select() no longer flips this to GET.)
        let created: [InspectionRequest] = try await client.db
            .from("inspection_requests")
            .insert(payload)
            .select()
            .execute()
        guard let req = created.first else {
            throw NSError(domain: "InspectFlow", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create inspection request"])
        }
        _ = try await client.db.from("intake_items")
            .update([
                "status": "converted",
                "inspection_request_id": req.id.uuidString,
            ])
            .eq("id", item.id.uuidString)
            .execute()
        return req.id
    }

    /// Claim an inspection request for the given inspector. Sets
    /// `assigned_inspector_id` and moves the request into `assigned`.
    func claimInspectionRequest(requestId: UUID, inspectorId: UUID) async throws {
        _ = try await client.db.from("inspection_requests")
            .update([
                "assigned_inspector_id": inspectorId.uuidString,
                "status": "assigned",
            ])
            .eq("id", requestId.uuidString)
            .execute()
    }

    /// Create an inspection request manually (used by the Inspections tab "+" action).
    func createInspectionRequest(
        orgId: UUID,
        clientName: String?,
        vin: String?,
        vehicleYear: String?,
        vehicleMake: String?,
        vehicleModel: String?,
        inspectionLocation: String?,
        requestedDate: Date?,
        templateName: String = "Standard Inspection",
        priority: String = "medium"
    ) async throws -> InspectionRequest {
        var payload: [String: Any] = [
            "organization_id": orgId.uuidString,
            "status": "request_received",
            "template_name": templateName,
            "priority": priority,
        ]
        if let v = clientName { payload["client_name"] = v }
        if let v = vin { payload["vin"] = v }
        if let v = vehicleYear { payload["vehicle_year"] = v }
        if let v = vehicleMake { payload["vehicle_make"] = v }
        if let v = vehicleModel { payload["vehicle_model"] = v }
        if let v = inspectionLocation { payload["inspection_location"] = v }
        if let d = requestedDate {
            let f = DateFormatter()
            f.calendar = Calendar(identifier: .gregorian)
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = .current
            f.dateFormat = "yyyy-MM-dd"
            payload["requested_date"] = f.string(from: d)
        }
        let created: [InspectionRequest] = try await client.db
            .from("inspection_requests")
            .insert(payload)
            .select()
            .execute()
        guard let row = created.first else {
            throw NSError(domain: "InspectFlow", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create inspection request"])
        }
        return row
    }


    func ingestUrl(url: String) async throws {
        _ = try await client.functions.invokeRaw("intake-fetch-url", body: ["url": url])
    }

    /// Uploads a PDF to the `intake-files` bucket, then invokes `intake-parse-pdf`
    /// which extracts text and creates an intake_item.
    func ingestPdf(orgId: UUID, fileName: String, data: Data) async throws {
        let safeName = fileName.replacingOccurrences(of: "/", with: "_")
        let path = "\(orgId.uuidString)/\(Int(Date().timeIntervalSince1970))-\(safeName)"
        try await client.storage.upload(
            bucket: "intake-files",
            path: path,
            data: data,
            contentType: "application/pdf",
            upsert: false
        )
        _ = try await client.functions.invokeRaw("intake-parse-pdf", body: [
            "storage_path": path,
            "organization_id": orgId.uuidString,
            "channel": "manual_pdf",
            "subject": fileName,
        ])
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
        if MockSession.isActive {
            return try await MockSession.read("trip_stops",
                filters: [.eq("trip_id", tripId.uuidString)],
                order: "sort_order", ascending: true, limit: limit)
        }
        return try await client.db.from("trip_stops")
            .select()
            .eq("trip_id", tripId.uuidString)
            .order("sort_order", ascending: true)
            .limit(limit)
            .execute()
    }

    func fetchTripLocationPoints(tripId: UUID, limit: Int = 500) async throws -> [TripLocationPoint] {
        if MockSession.isActive, let orgId = MockSession.organizationID {
            return try await MockSession.read("trip_location_points",
                filters: [.eq("organization_id", orgId.uuidString), .eq("trip_id", tripId.uuidString)],
                order: "recorded_at", ascending: true, limit: limit)
        }
        return try await client.db.from("trip_location_points")
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

    // MARK: - Mileage feature (Trip edits + earnings rate)

    /// Patch arbitrary fields on a trip (note, job_category, started_at, completed_at, total_miles).
    @discardableResult
    func updateTrip(tripId: UUID, fields: [String: Any]) async throws -> Bool {
        guard !fields.isEmpty else { return false }
        let changed: [MutationID] = try await client.db.from("trips")
            .update(fields)
            .eq("id", tripId.uuidString)
            .execute()
        return !changed.isEmpty
    }

    /// Hard-delete a trip row (used by the "Delete" button on the mileage detail screen).
    @discardableResult
    func deleteTrip(tripId: UUID) async throws -> Bool {
        let changed: [MutationID] = try await client.db.from("trips")
            .delete()
            .eq("id", tripId.uuidString)
            .execute()
        return !changed.isEmpty
    }

    /// Returns the configured `$/mi` rate for the given user from `earnings_settings`,
    /// falling back to the current IRS standard mileage rate when unset.
    func fetchPerMileRate(userId: UUID) async throws -> Double {
        struct Row: Decodable { let mileage_rate: Double? }
        let rows: [Row] = try await client.db.from("earnings_settings")
            .select("mileage_rate")
            .eq("user_id", userId.uuidString)
            .limit(1)
            .execute()
        return rows.first?.mileage_rate ?? MileageDeduction.currentIRSRate
    }

    // MARK: - Profile / Settings helpers (Section 3)

    func updateProfile(userId: UUID, fullName: String?, phone: String?, avatarUrl: String?) async throws {
        var fields: [String: String] = [:]
        if let fullName { fields["full_name"] = fullName }
        if let phone { fields["phone"] = phone }
        if let avatarUrl { fields["avatar_url"] = avatarUrl }
        guard !fields.isEmpty else { return }
        _ = try await client.db.from("profiles")
            .update(fields)
            .eq("id", userId.uuidString)
            .execute()
    }

    func uploadAvatar(userId: UUID, data: Data, contentType: String = "image/jpeg") async throws -> String {
        let path = "\(userId.uuidString)/avatar-\(Int(Date().timeIntervalSince1970)).jpg"
        try await client.storage.upload(bucket: "avatars", path: path, data: data, contentType: contentType, upsert: true)
        return path
    }

    func avatarSignedURL(path: String) async throws -> URL {
        try await client.storage.createSignedURL(bucket: "avatars", path: path, expiresIn: 3600)
    }

    func fetchAvailability(userId: UUID) async throws -> [AvailabilityRow] {
        try await client.db.from("availability_schedules")
            .select()
            .eq("inspector_id", userId.uuidString)
            .order("day_of_week", ascending: true)
            .execute()
    }

    func upsertAvailability(_ rows: [AvailabilityRow]) async throws {
        for row in rows {
            let fields: [String: String] = [
                "id": row.id.uuidString,
                "inspector_id": row.inspectorID.uuidString,
                "day_of_week": String(row.dayOfWeek),
                "start_time": row.startTime,
                "end_time": row.endTime,
                "is_available": row.isAvailable ? "true" : "false"
            ]
            _ = try await client.db.from("availability_schedules")
                .update(fields)
                .eq("id", row.id.uuidString)
                .execute()
        }
    }

    func fetchEarningsSettings(userId: UUID) async throws -> EarningsSettings? {
        let rows: [EarningsSettings] = try await client.db.from("earnings_settings")
            .select()
            .eq("user_id", userId.uuidString)
            .limit(1)
            .execute()
        return rows.first
    }

    func updateEarningsSettings(userId: UUID, mileageRate: Double?, defaultJobFee: Double?, estimatedTaxRate: Double?, stateCode: String?, filingStatus: String?) async throws {
        var fields: [String: String] = [:]
        if let mileageRate { fields["mileage_rate"] = String(mileageRate) }
        if let defaultJobFee { fields["default_job_fee"] = String(defaultJobFee) }
        if let estimatedTaxRate { fields["estimated_tax_rate"] = String(estimatedTaxRate) }
        if let stateCode { fields["state_code"] = stateCode }
        if let filingStatus { fields["filing_status"] = filingStatus }
        guard !fields.isEmpty else { return }
        _ = try await client.db.from("earnings_settings")
            .update(fields)
            .eq("user_id", userId.uuidString)
            .execute()
    }

    func listMyMemberships(userId: UUID) async throws -> [OrganizationMembership] {
        try await client.db.from("organization_users")
            .select()
            .eq("user_id", userId.uuidString)
            .execute()
    }
}

