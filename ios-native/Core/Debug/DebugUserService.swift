import Foundation

/// Lists (user × organization) memberships for the test-user / impersonation
/// picker. When `AuthBypass.isEnabled` is true, returns the hardcoded
/// `MockUsers.all` list with no network calls. Otherwise (real-auth mode),
/// falls back to querying Supabase — kept behind `#if DEBUG` so release
/// builds without bypass can't browse real accounts.
enum DebugUserService {
    static func fetchDebugUsers() async throws -> [DebugUser] {
        if AuthBypass.isEnabled {
            return MockUsers.all.sorted { lhs, rhs in
                (lhs.fullName ?? "").localizedCaseInsensitiveCompare(rhs.fullName ?? "") == .orderedAscending
            }
        }
        #if DEBUG
        return try await fetchFromSupabase()
        #else
        return []
        #endif
    }

    static func fetchOne(id: UUID) async throws -> DebugUser? {
        if AuthBypass.isEnabled {
            return MockUsers.first(id: id)
        }
        #if DEBUG
        let all = try await fetchFromSupabase()
        return all.first(where: { $0.id == id })
        #else
        return nil
        #endif
    }

    #if DEBUG
    private struct Row: Decodable {
        let userID: UUID
        let role: String
        let organizationID: UUID
        let profiles: ProfileRow?
        let organizations: OrgRow?

        struct ProfileRow: Decodable { let full_name: String? }
        struct OrgRow: Decodable { let name: String? }

        enum CodingKeys: String, CodingKey {
            case userID = "user_id"
            case role
            case organizationID = "organization_id"
            case profiles
            case organizations
        }
    }

    private static func fetchFromSupabase() async throws -> [DebugUser] {
        let client = SupabaseClientProvider.shared
        let rows: [Row] = try await client.db.from("organization_users")
            .select("user_id, role, organization_id, profiles!inner(full_name), organizations(name)")
            .limit(500)
            .execute()

        let users: [DebugUser] = rows.map { row in
            DebugUser(
                id: row.userID,
                fullName: row.profiles?.full_name,
                email: nil,
                organizationID: row.organizationID,
                organizationName: row.organizations?.name,
                role: row.role
            )
        }
        return users.sorted { lhs, rhs in
            (lhs.fullName ?? "").localizedCaseInsensitiveCompare(rhs.fullName ?? "") == .orderedAscending
        }
    }
    #endif
}
