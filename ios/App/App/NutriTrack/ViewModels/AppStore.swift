import Foundation
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published var halls: [DiningHall] = []
    @Published var stations: [Station] = []
    @Published var categories: [MenuCategory] = []
    @Published var items: [FoodItem] = []

    @Published var tray: [FoodSnapshot] = []
    @Published var favorites: Set<UUID> = []
    @Published var mealLogs: [MealLog] = []
    @Published var goals = NutritionGoals.default

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastScrape: Date?

    private let service = DiningService()
    private let local = LocalStore()

    func bootstrap() async {
        tray = local.load([FoodSnapshot].self, key: "tray") ?? []
        favorites = local.load(Set<UUID>.self, key: "favorites") ?? []
        mealLogs = local.load([MealLog].self, key: "mealLogs") ?? []
        goals = local.load(NutritionGoals.self, key: "goals") ?? .default
        await refreshRemoteData()
    }

    func refreshRemoteData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let hallsTask = service.fetchHalls()
            async let stationsTask = service.fetchStations()
            async let categoriesTask = service.fetchCategories()
            async let itemsTask = service.fetchFoodItems()

            halls = try await hallsTask
            stations = try await stationsTask
            categories = try await categoriesTask
            items = try await itemsTask
            lastScrape = try await service.fetchLatestScrapeLog()?.createdAt
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stations(for hall: DiningHall) -> [Station] { stations.filter { $0.diningHallID == hall.id } }
    func categories(for station: Station) -> [MenuCategory] { categories.filter { $0.stationID == station.id } }
    func items(for station: Station, category: MenuCategory) -> [FoodItem] {
        items.filter { $0.stationID == station.id && $0.categoryID == category.id }
    }

    func addToTray(_ item: FoodItem) {
        tray.append(FoodSnapshot(from: item))
        local.save(tray, key: "tray")
    }

    func removeFromTray(_ id: UUID) {
        tray.removeAll { $0.id == id }
        local.save(tray, key: "tray")
    }

    func logTray(as category: MealCategory) {
        guard !tray.isEmpty else { return }
        mealLogs.insert(MealLog(id: UUID(), loggedAt: Date(), category: category, items: tray), at: 0)
        tray.removeAll()
        local.save(mealLogs, key: "mealLogs")
        local.save(tray, key: "tray")
    }

    func toggleFavorite(_ item: FoodItem) {
        if favorites.contains(item.id) { favorites.remove(item.id) } else { favorites.insert(item.id) }
        local.save(favorites, key: "favorites")
    }

    func saveGoals(_ newGoals: NutritionGoals) {
        goals = newGoals
        local.save(goals, key: "goals")
    }
}
