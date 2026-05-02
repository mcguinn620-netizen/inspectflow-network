import Foundation
struct MenuCategory: Codable, Identifiable, Hashable { let id: UUID; let stationID: UUID; let name: String; enum CodingKeys:String,CodingKey{case id,name;case stationID="station_id"}}
