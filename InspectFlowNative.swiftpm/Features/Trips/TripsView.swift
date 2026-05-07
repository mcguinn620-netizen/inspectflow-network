import SwiftUI

struct TripsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Trips") {
                    Text("Placeholder for native Trips feature.")
                }
            }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { SyncStatusView() } }
            .navigationTitle("Trips")
        }
    }
}
