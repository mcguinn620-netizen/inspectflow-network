import SwiftUI

struct DiningView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        Group {
            if store.isLoading {
                LoadingStateView()
            } else if let error = store.errorMessage {
                ErrorStateView(message: error)
            } else if store.halls.isEmpty {
                EmptyStateView(message: "No dining halls available")
            } else {
                HallGridView()
            }
        }
        .navigationTitle("Dining")
        .toolbarBackground(BSUColors.cardinalRed, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}
