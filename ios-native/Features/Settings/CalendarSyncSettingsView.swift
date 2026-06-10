import SwiftUI

struct CalendarSyncSettingsView: View {
    @State private var statusMessage: String?

    var body: some View {
        Form {
            Section("iPhone Calendar") {
                Text("Auto Inspector can write scheduled jobs to an \"InspectFlow Jobs\" calendar on your iPhone so they appear in Apple Calendar and on your watch.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Request calendar access") {
                    Task {
                        let granted = await CalendarSyncService.shared.ensureAccess()
                        statusMessage = granted ? "Calendar access granted." : "Calendar access denied. Enable in Settings → Privacy → Calendars."
                    }
                }
            }
            Section("Bulk actions") {
                Text("Use the Calendar Sync menu in the Schedule toolbar to export the visible week or remove all synced events.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Calendar Sync")
        .alert("Calendar", isPresented: Binding(get: { statusMessage != nil }, set: { if !$0 { statusMessage = nil } })) {
            Button("OK") { statusMessage = nil }
        } message: { Text(statusMessage ?? "") }
    }
}
