import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Settings") {
                    Text("Placeholder for native Settings feature.")
                }
            }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { SyncStatusView() } }
            .navigationTitle("Settings")
        }
    }
}
