import Foundation
struct Station: Codable, Identifiable, Hashable { let id: UUID; let diningHallID: UUID; let name: String; let unitOID: Int?; enum CodingKeys:String,CodingKey{case id,name;case diningHallID="dining_hall_id";case unitOID="unit_oid"}}
