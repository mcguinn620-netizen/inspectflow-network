import Foundation
struct NutritionGoals: Codable, Hashable { var calories:Int; var protein:Double; var carbs:Double; var fat:Double; static let `default` = NutritionGoals(calories: 2200, protein: 150, carbs: 250, fat: 70)}
