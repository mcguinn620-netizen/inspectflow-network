import SwiftUI
struct NutritionDetailView: View { let item:FoodItem; var body: some View { VStack(alignment:.leading){ Text("Calories: \(item.calories ?? 0)"); Text("Protein: \(Int(item.protein ?? 0))g  Carbs: \(Int(item.carbs ?? 0))g  Fat: \(Int(item.fat ?? 0))g") } }}
