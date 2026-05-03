import Foundation

struct UserProfile: Codable, Identifiable {
    let id: UUID
    let fullName: String?
    let email: String?
    let role: String?
}

struct UserRole: Codable, Identifiable { let id: UUID; let userId: UUID; let role: String }
struct Inspector: Codable, Identifiable { let id: UUID; let userId: UUID?; let companyId: UUID? }
struct Job: Codable, Identifiable { let id: UUID; let customerName: String?; let location: String?; let status: String?; let scheduledDate: String? }
struct ScheduleItem: Codable, Identifiable { let id: UUID; let inspectionRequestId: UUID; let inspectorId: UUID?; let scheduledDate: String?; let scheduledTime: String?; let status: String? }
struct Trip: Codable, Identifiable { let id: UUID; let userId: UUID?; let status: String; let startedAt: String? }
struct TripStop: Codable, Identifiable { let id: UUID; let tripId: UUID; let jobId: UUID?; let stopLabel: String?; let status: String?; let sortOrder: Int?; let latitude: Double?; let longitude: Double?; let address: String? }
struct TripLocationPoint: Codable, Identifiable { let id: UUID; let tripId: UUID; let latitude: Double; let longitude: Double; let createdAt: String? }
struct Vehicle: Codable, Identifiable { let id: UUID; let make: String?; let model: String?; let year: Int?; let licensePlate: String?; let vin: String? }
struct InspectionRequest: Codable, Identifiable { let id: UUID; let status: String?; let inspectorId: UUID?; let scheduledDate: String? }
struct InspectionTemplate: Codable, Identifiable { let id: UUID; let name: String; let isActive: Bool? }
struct TaxMileageSummary: Codable, Identifiable { let id: UUID; let tripId: UUID; let totalMiles: Double?; let deductibleAmount: Double? }
