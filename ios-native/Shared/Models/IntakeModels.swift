import Foundation

// MARK: - Intake

struct IntakeItem: Codable, Identifiable, Equatable {
    let id: UUID
    let organizationID: UUID
    let channel: String           // gmail|outlook|telegram|web_link|manual
    let sourceAddress: String?
    let subject: String?
    let rawText: String?
    let parsedData: IntakeParsedData?
    let confidence: Double?
    let status: String            // new|parsing|needs_review|auto_created|converted|dismissed|error
    let inspectionRequestID: UUID?
    let error: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case channel
        case sourceAddress = "source_address"
        case subject
        case rawText = "raw_text"
        case parsedData = "parsed_data"
        case confidence
        case status
        case inspectionRequestID = "inspection_request_id"
        case error
        case createdAt = "created_at"
    }
}

struct IntakeParsedData: Codable, Equatable {
    var clientName: String?
    var companyName: String?
    var vin: String?
    var vehicleYear: String?
    var vehicleMake: String?
    var vehicleModel: String?
    var mileage: String?
    var inspectionLocation: String?
    var requestedDate: String?
    var inspectionType: String?
    var templateName: String?
    var priority: String?
    var vinValid: Bool?
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case clientName = "client_name"
        case companyName = "company_name"
        case vin
        case vehicleYear = "vehicle_year"
        case vehicleMake = "vehicle_make"
        case vehicleModel = "vehicle_model"
        case mileage
        case inspectionLocation = "inspection_location"
        case requestedDate = "requested_date"
        case inspectionType = "inspection_type"
        case templateName = "template_name"
        case priority
        case vinValid = "vin_valid"
        case notes
    }
}
