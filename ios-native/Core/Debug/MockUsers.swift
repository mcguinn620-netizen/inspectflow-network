import Foundation

/// Hardcoded test users mirroring `src/lib/authBypass.ts` MOCK_USERS on the
/// web. Same UUIDs, emails, names, and org IDs on both platforms so a mock
/// account behaves identically across web and native.
enum MockUsers {
    static let all: [DebugUser] = [
        DebugUser(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
            fullName: "Sam Superadmin",
            email: "super@test.local",
            organizationID: UUID(uuidString: "00000000-0000-4000-9000-000000000001")!,
            organizationName: "Platform HQ",
            role: "super_admin"
        ),
        DebugUser(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000002")!,
            fullName: "Nina Networkadmin",
            email: "network@test.local",
            organizationID: UUID(uuidString: "00000000-0000-4000-9000-000000000002")!,
            organizationName: "Regional Network",
            role: "network_admin"
        ),
        DebugUser(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000003")!,
            fullName: "Cam Companyadmin",
            email: "company@test.local",
            organizationID: UUID(uuidString: "00000000-0000-4000-9000-000000000003")!,
            organizationName: "Acme Inspections",
            role: "company_admin"
        ),
        DebugUser(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000004")!,
            fullName: "Riley Shopmanager",
            email: "shop@test.local",
            organizationID: UUID(uuidString: "00000000-0000-4000-9000-000000000004")!,
            organizationName: "Riley's Auto Body",
            role: "repair_shop_manager"
        ),
        DebugUser(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000005")!,
            fullName: "Ivy Inspector",
            email: "inspector@test.local",
            organizationID: UUID(uuidString: "00000000-0000-4000-9000-000000000005")!,
            organizationName: "Ivy's Workspace",
            role: "inspector"
        ),
        DebugUser(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000006")!,
            fullName: "Theo Technician",
            email: "tech@test.local",
            organizationID: UUID(uuidString: "00000000-0000-4000-9000-000000000006")!,
            organizationName: "Acme Inspections",
            role: "technician"
        ),
        DebugUser(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000007")!,
            fullName: "Cleo Client",
            email: "client@test.local",
            organizationID: UUID(uuidString: "00000000-0000-4000-9000-000000000007")!,
            organizationName: "Cleo (Client)",
            role: "client"
        ),
        DebugUser(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000008")!,
            fullName: "Fran Fleetmanager",
            email: "fleet@test.local",
            organizationID: UUID(uuidString: "00000000-0000-4000-9000-000000000008")!,
            organizationName: "BlueLine Fleet",
            role: "fleet_manager"
        ),
        DebugUser(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000009")!,
            fullName: "Max Mechanic",
            email: "mechanic@test.local",
            organizationID: UUID(uuidString: "00000000-0000-4000-9000-000000000009")!,
            organizationName: "Max's Garage",
            role: "mechanic"
        ),
        DebugUser(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000010")!,
            fullName: "Dana Dispatcher",
            email: "dispatch@test.local",
            organizationID: UUID(uuidString: "00000000-0000-4000-9000-000000000010")!,
            organizationName: "Acme Dispatch",
            role: "dispatcher"
        ),
    ]

    static func first(id: UUID) -> DebugUser? {
        all.first { $0.id == id }
    }
}
