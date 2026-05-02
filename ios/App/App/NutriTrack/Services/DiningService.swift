import Foundation

final class DiningService {
    private let api = SupabaseClient()

    func fetchHalls() async throws -> [DiningHall] {
        try await api.fetch("dining_halls", query: [URLQueryItem(name: "order", value: "name.asc")])
    }

    func fetchStations() async throws -> [Station] {
        try await api.fetch("stations", query: [URLQueryItem(name: "order", value: "name.asc")])
    }

    func fetchCategories() async throws -> [MenuCategory] {
        try await api.fetch("menu_categories", query: [URLQueryItem(name: "order", value: "name.asc")])
    }

    func fetchFoodItems() async throws -> [FoodItem] {
        try await api.fetch("food_items", query: [URLQueryItem(name: "order", value: "name.asc")])
    }

    func fetchLatestScrapeLog() async throws -> ScrapeLog? {
        try await api.fetch(
            "scrape_logs",
            query: [
                URLQueryItem(name: "order", value: "created_at.desc"),
                URLQueryItem(name: "limit", value: "1")
            ]
        ).first
    }
}
