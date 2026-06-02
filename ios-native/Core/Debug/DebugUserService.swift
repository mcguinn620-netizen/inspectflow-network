import Foundation

#if DEBUG
/// DEV-only service that lists all known (user × organization) memberships
/// so an engineer can impersonate any user without a password.
enum DebugUserService {
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

    static func fetchDebugUsers() async throws -> [DebugUser] {
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

    static func fetchOne(id: UUID) async throws -> DebugUser? {
        let all = try await fetchDebugUsers()
        return all.first(where: { $0.id == id })
    }
}
#endif
