import Foundation
enum MealCategory: String, Codable, CaseIterable, Identifiable { case breakfast,lunch,dinner,snacks; var id:String{rawValue}}
struct MealLog: Codable, Identifiable, Hashable { let id: UUID; let loggedAt: Date; let category: MealCategory; let items: [FoodSnapshot] }
