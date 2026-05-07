import SwiftUI

struct ScheduleView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Schedule") {
                    Text("Placeholder for native Schedule feature.")
                }
            }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { SyncStatusView() } }
            .navigationTitle("Schedule")
        }
    }
}
