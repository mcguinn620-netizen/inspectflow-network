import Foundation

#if DEBUG
/// DEV-only impersonation record. Compiled out of release builds.
struct DebugUser: Identifiable, Codable, Hashable {
    let id: UUID
    let fullName: String?
    let email: String?
    let organizationID: UUID
    let organizationName: String?
    let role: String

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case email
        case organizationID = "organization_id"
        case organizationName = "organization_name"
        case role
    }
}

enum DebugRoleGroup: String {
    case admin, manager, dispatcher, inspector, client

    static func from(_ role: String) -> DebugRoleGroup {
        switch role {
        case "super_admin", "network_admin", "company_admin": return .admin
        case "repair_shop_manager", "fleet_manager": return .manager
        case "dispatcher": return .dispatcher
        case "client": return .client
        default: return .inspector
        }
    }
}
#endif
