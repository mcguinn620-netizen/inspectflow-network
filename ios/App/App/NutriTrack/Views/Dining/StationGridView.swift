import SwiftUI
struct StationGridView: View { @EnvironmentObject var store:AppStore; let hall:DiningHall; var body: some View { List(store.stations.filter{$0.diningHallID==hall.id}){ s in NavigationLink(s.name){ CategoryGridView(station:s) } }.navigationTitle(hall.name) }}
