import SwiftUI

struct StationGridView: View {
    @EnvironmentObject var store: AppStore
    let hall: DiningHall

    var body: some View {
        let filtered = store.stations(for: hall)
        Group {
            if filtered.isEmpty {
                EmptyStateView(message: "No stations for \(hall.name)")
            } else {
                List(filtered) { station in
                    NavigationLink(station.name) { CategoryGridView(station: station) }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(hall.name)
    }
}
