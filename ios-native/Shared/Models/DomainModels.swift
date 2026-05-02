import Foundation

struct UserProfile: Codable, Identifiable {
    let id: UUID
    let fullName: String
    let email: String
}

struct UserRole: Codable, Identifiable { let id: UUID; let role: String }
struct Inspector: Codable, Identifiable { let id: UUID; let profileID: UUID }
struct Job: Codable, Identifiable { let id: UUID; let title: String; let scheduledAt: Date }
struct Trip: Codable, Identifiable { let id: UUID; let jobID: UUID; let status: String }
struct TripStop: Codable, Identifiable { let id: UUID; let tripID: UUID; let name: String; let sequence: Int }
struct TripLocationPoint: Codable, Identifiable { let id: UUID; let tripID: UUID; let latitude: Double; let longitude: Double }
struct Vehicle: Codable, Identifiable { let id: UUID; let plate: String; let nickname: String }
struct InspectionRequest: Codable, Identifiable { let id: UUID; let jobID: UUID; let status: String }
struct InspectionTemplate: Codable, Identifiable { let id: UUID; let name: String }
struct DispatchAssignment: Codable, Identifiable { let id: UUID; let inspectorID: UUID; let jobID: UUID }
struct Organization: Codable, Identifiable { let id: UUID; let name: String }
struct OrganizationUser: Codable, Identifiable { let id: UUID; let organizationID: UUID; let userID: UUID }
