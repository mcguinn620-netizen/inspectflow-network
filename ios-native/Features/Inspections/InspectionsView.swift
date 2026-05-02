import SwiftUI

struct InspectionsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Inspections") {
                    Text("Placeholder for native Inspections feature.")
                }
            }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { SyncStatusView() } }
            .navigationTitle("Inspections")
        }
    }
}
