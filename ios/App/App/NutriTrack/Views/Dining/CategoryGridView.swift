import SwiftUI
struct CategoryGridView: View { @EnvironmentObject var store:AppStore; let station:Station; var body: some View { List(store.categories.filter{$0.stationID==station.id}){ c in NavigationLink(c.name){ FoodItemGridView(station:station,category:c) } }.navigationTitle(station.name) }}
