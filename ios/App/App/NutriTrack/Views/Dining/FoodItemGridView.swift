import SwiftUI
struct FoodItemGridView: View { @EnvironmentObject var store:AppStore; let station:Station; let category:MenuCategory; var body: some View { ScrollView { ForEach(store.items.filter{$0.stationID==station.id && $0.categoryID==category.id}) { FoodCardView(item:$0) } }.navigationTitle(category.name) }}
