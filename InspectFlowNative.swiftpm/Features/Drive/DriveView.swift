import SwiftUI

struct DriveView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Drive") {
                    Text("Placeholder for native Drive feature.")
                }
            }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { SyncStatusView() } }
            .navigationTitle("Drive")
        }
    }
}
