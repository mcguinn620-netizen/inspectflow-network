import SwiftUI

struct FoodItemGridView: View {
    @EnvironmentObject var store: AppStore
    let station: Station
    let category: MenuCategory

    var body: some View {
        let filtered = store.items(for: station, category: category)
        ScrollView {
            if filtered.isEmpty {
                EmptyStateView(message: "No food items in this category")
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filtered) { item in FoodCardView(item: item) }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle(category.name)
    }
}
