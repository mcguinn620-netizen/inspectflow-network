import Foundation

struct ScrapeLog: Codable, Identifiable, Hashable {
    let id: UUID
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
    }
}
