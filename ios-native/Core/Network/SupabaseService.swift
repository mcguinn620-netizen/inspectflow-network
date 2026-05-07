import Foundation
import InspectFlowConnector

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
}
