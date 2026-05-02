import SwiftUI

struct CategoryGridView: View {
    @EnvironmentObject var store: AppStore
    let station: Station

    var body: some View {
        let filtered = store.categories(for: station)
        Group {
            if filtered.isEmpty {
                EmptyStateView(message: "No categories in \(station.name)")
            } else {
                List(filtered) { category in
                    NavigationLink(category.name) {
                        FoodItemGridView(station: station, category: category)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(station.name)
    }
}
