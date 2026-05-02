import Foundation
struct FoodSnapshot: Codable, Identifiable, Hashable { let id: UUID; let name: String; let servingSize: String?; let allergens: [String]; let dietaryFlags: [String]; let calories: Int?; let protein: Double?; let carbs: Double?; let fat: Double?; let nutrients: [String: Double]
init(from item: FoodItem){id=item.id;name=item.name;servingSize=item.servingSize;allergens=item.allergens;dietaryFlags=item.dietaryFlags;calories=item.calories;protein=item.protein;carbs=item.carbs;fat=item.fat;nutrients=item.nutrients}}
