import Foundation

/// Thin app-facing facade over `InspectFlowClient`.
final class SupabaseService {
    static let shared = SupabaseService()
    private init() {}

    private var client: InspectFlowClient { SupabaseClientProvider.shared }

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

    func updateTripStatus(tripId: UUID, status: String, extras: [String: Any] = [:]) async throws {
        var row: [String: Any] = ["status": status]
        for (k, v) in extras { row[k] = v }
        _ = try await client.db.from("trips")
            .update(row)
            .eq("id", tripId.uuidString)
            .execute()
    }
}
