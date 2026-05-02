import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        let favItems = store.items.filter { store.favorites.contains($0.id) }
        Group {
            if favItems.isEmpty {
                EmptyStateView(message: "No favorites yet")
            } else {
                List(favItems) { item in
                    FoodCardView(item: item)
                        .listRowInsets(EdgeInsets())
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Favorites")
    }
}
