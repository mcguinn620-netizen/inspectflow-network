import Foundation
struct DiningHall: Codable, Identifiable, Hashable { let id: UUID; let name: String; let unitOID: Int?; enum CodingKeys:String,CodingKey{case id,name;case unitOID="unit_oid"}}
