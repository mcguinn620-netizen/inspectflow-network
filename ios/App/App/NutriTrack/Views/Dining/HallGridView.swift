import SwiftUI

struct HallGridView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        List(store.halls) { hall in
            NavigationLink(hall.name) {
                StationGridView(hall: hall)
            }
        }
        .listStyle(.insetGrouped)
    }
}
