import SwiftUI

struct VehiclesView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Vehicles") {
                    Text("Placeholder for native Vehicles feature.")
                }
            }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { SyncStatusView() } }
            .navigationTitle("Vehicles")
        }
    }
}
