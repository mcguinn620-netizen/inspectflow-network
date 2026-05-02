import SwiftUI

struct JobsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Jobs") {
                    Text("Placeholder for native Jobs feature.")
                }
            }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { SyncStatusView() } }
            .navigationTitle("Jobs")
        }
    }
}
