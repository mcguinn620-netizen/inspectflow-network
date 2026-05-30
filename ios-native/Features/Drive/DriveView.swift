import SwiftUI

struct DriveView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Drive") {
                    Text("Use Trips to start route tracking and capture drive activity.")
                }
            }
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { SyncStatusView() } }
            .navigationTitle("Drive")
        }
    }
}
