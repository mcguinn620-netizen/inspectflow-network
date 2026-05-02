import Foundation
struct NutritionMath { static func totals(for items:[FoodSnapshot])->(calories:Int,protein:Double,carbs:Double,fat:Double){ items.reduce((0,0,0,0)){a,i in (a.0+(i.calories ?? 0),a.1+(i.protein ?? 0),a.2+(i.carbs ?? 0),a.3+(i.fat ?? 0)) } } }
