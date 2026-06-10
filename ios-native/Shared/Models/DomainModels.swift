import Foundation

// MARK: - Profile

struct UserProfile: Codable, Identifiable, Equatable {
    let id: UUID
    let fullName: String?
    let email: String?
    let avatarUrl: String?
    let phone: String?

    init(id: UUID, fullName: String?, email: String?, avatarUrl: String? = nil, phone: String? = nil) {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.avatarUrl = avatarUrl
        self.phone = phone
    }

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case email
        case avatarUrl = "avatar_url"
        case phone
    }
}

// MARK: - Availability + Earnings settings

struct AvailabilityRow: Codable, Identifiable, Equatable {
    let id: UUID
    let inspectorID: UUID
    let dayOfWeek: Int
    let startTime: String
    let endTime: String
    let isAvailable: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case inspectorID = "inspector_id"
        case dayOfWeek = "day_of_week"
        case startTime = "start_time"
        case endTime = "end_time"
        case isAvailable = "is_available"
    }
}

struct EarningsSettings: Codable, Equatable {
    let id: UUID?
    let userID: UUID?
    let organizationID: UUID?
    let mileageRate: Double?
    let defaultJobFee: Double?
    let estimatedTaxRate: Double?
    let stateCode: String?
    let filingStatus: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case organizationID = "organization_id"
        case mileageRate = "mileage_rate"
        case defaultJobFee = "default_job_fee"
        case estimatedTaxRate = "estimated_tax_rate"
        case stateCode = "state_code"
        case filingStatus = "filing_status"
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
    let pausedAt: Date?
    let completedAt: Date?
    let createdAt: Date?
    let note: String?
    let jobCategory: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case organizationID = "organization_id"
        case tripDate = "trip_date"
        case status
        case totalMiles = "total_miles"
        case startedAt = "started_at"
        case pausedAt = "paused_at"
        case completedAt = "completed_at"
        case createdAt = "created_at"
        case note
        case jobCategory = "job_category"
    }
}

struct TripStop: Codable, Identifiable, Equatable {
    let id: UUID
    let tripID: UUID
    let jobID: UUID?
    let sortOrder: Int
    let label: String?
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let status: String?
    let arrivedAt: Date?
    let completedAt: Date?
    let departedAt: Date?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case tripID = "trip_id"
        case jobID = "job_id"
        case sortOrder = "sort_order"
        case label, address, latitude, longitude, status
        case arrivedAt = "arrived_at"
        case completedAt = "completed_at"
        case departedAt = "departed_at"
        case createdAt = "created_at"
    }
}


struct TripLocationPoint: Codable, Identifiable, Equatable {
    let id: UUID
    let tripID: UUID
    let latitude: Double
    let longitude: Double
    let recordedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case tripID = "trip_id"
        case latitude
        case longitude
        case recordedAt = "recorded_at"
    }
}

struct NextStopData: Equatable {
    let trip: Trip
    let stop: TripStop

    var title: String { stop.label ?? "Stop \(stop.sortOrder + 1)" }
    var subtitle: String? { stop.address }
    var coordinate: (latitude: Double, longitude: Double)? {
        guard let latitude = stop.latitude, let longitude = stop.longitude else { return nil }
        return (latitude, longitude)
    }

    static func resolve(trip: Trip?, stops: [TripStop]) -> NextStopData? {
        guard let trip else { return nil }
        let incompleteStatuses = ["pending", "arrived"]
        guard let stop = stops.first(where: { incompleteStatuses.contains($0.status ?? "pending") }) else { return nil }
        return NextStopData(trip: trip, stop: stop)
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
