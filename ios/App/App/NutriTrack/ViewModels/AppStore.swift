import Foundation
import SwiftUI
@MainActor final class AppStore: ObservableObject { @Published var halls:[DiningHall]=[]; @Published var stations:[Station]=[]; @Published var categories:[MenuCategory]=[]; @Published var items:[FoodItem]=[]; @Published var tray:[FoodSnapshot]=[]; @Published var favorites:Set<UUID>=[]; @Published var mealLogs:[MealLog]=[]; @Published var goals=NutritionGoals.default; @Published var isLoading=false; @Published var errorMessage:String?; @Published var lastScrape:Date?; private let service=DiningService(); private let local=LocalStore()
func bootstrap() async { tray=local.load([FoodSnapshot].self,key:"tray") ?? []; favorites=local.load(Set<UUID>.self,key:"favorites") ?? []; mealLogs=local.load([MealLog].self,key:"mealLogs") ?? []; goals=local.load(NutritionGoals.self,key:"goals") ?? .default; await refreshRemoteData() }
func refreshRemoteData() async { isLoading=true; defer{isLoading=false}; do { async let h=service.fetchHalls(); async let s=service.fetchStations(); async let c=service.fetchCategories(); async let f=service.fetchFoodItems(); halls=try await h; stations=try await s; categories=try await c; items=try await f; lastScrape=try await service.fetchLatestScrapeLog()?.createdAt; errorMessage=nil } catch { errorMessage=error.localizedDescription }}
func addToTray(_ item:FoodItem){ tray.append(FoodSnapshot(from:item)); local.save(tray,key:"tray") }
func toggleFavorite(_ item:FoodItem){ if favorites.contains(item.id){favorites.remove(item.id)} else {favorites.insert(item.id)}; local.save(favorites,key:"favorites") }
}
