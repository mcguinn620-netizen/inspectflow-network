import SwiftUI

struct FoodCardView: View {
    @EnvironmentObject var store: AppStore
    let item: FoodItem
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.name).font(.headline)
                Spacer()
                Button { store.toggleFavorite(item) } label: {
                    Image(systemName: store.favorites.contains(item.id) ? "heart.fill" : "heart")
                        .foregroundColor(BSUColors.cardinalRed)
                }
                Button { store.addToTray(item) } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
            if let servingSize = item.servingSize { Text(servingSize).font(.subheadline).foregroundStyle(.secondary) }
            HStack(spacing: 12) {
                Text("\(item.calories ?? 0) cal")
                Text("P \(Int(item.protein ?? 0))")
                Text("C \(Int(item.carbs ?? 0))")
                Text("F \(Int(item.fat ?? 0))")
            }
            .font(.caption)
            if expanded { NutritionDetailView(item: item) }
            Button(expanded ? "Hide details" : "Show details") { expanded.toggle() }
                .font(.caption)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.separator).opacity(0.2)))
        .padding(.horizontal)
    }
}
