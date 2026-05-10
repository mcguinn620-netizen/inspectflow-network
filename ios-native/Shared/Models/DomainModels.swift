import Foundation

// MARK: - Profile

struct UserProfile: Codable, Identifiable, Equatable {
    let id: UUID
    let fullName: String?
    let email: String?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case email
    }
}

// MARK: - Organization membership

struct OrganizationMembership: Codable, Identifiable, Equatable {
    let id: UUID
    let organizationID: UUID
    let userID: UUID
    let role: String
    let isDefault: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case userID = "user_id"
        case role
        case isDefault = "is_default"
    }
}

// MARK: - Trips

struct Trip: Codable, Identifiable, Equatable {
    let id: UUID
    let userID: UUID
    let organizationID: UUID?
    let tripDate: String?
    let status: String
    let totalMiles: Double?
    let startedAt: Date?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case organizationID = "organization_id"
        case tripDate = "trip_date"
        case status
        case totalMiles = "total_miles"
        case startedAt = "started_at"
        case createdAt = "created_at"
    }
}

// MARK: - Jobs

struct Job: Codable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let customerName: String?
    let location: String?
    let scheduledAt: Date?
    let status: String

    enum CodingKeys: String, CodingKey {
        case id, title, location, status
        case customerName = "customer_name"
        case scheduledAt = "scheduled_at"
    }
}

// MARK: - Vehicles

struct Vehicle: Codable, Identifiable, Equatable {
    let id: UUID
    let make: String?
    let model: String?
    let year: Int?
    let vin: String?
    let nickname: String?
}

// MARK: - Inspection requests

struct InspectionRequest: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let status: String
    let templateID: UUID?
    let createdAt: Date?
    let scheduledAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, status
        case templateID = "template_id"
        case createdAt = "created_at"
        case scheduledAt = "scheduled_at"
    }
}
