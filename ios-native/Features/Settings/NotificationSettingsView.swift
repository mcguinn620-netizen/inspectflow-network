import SwiftUI

struct NotificationSettingsView: View {
    @AppStorage("notifications.jobs") private var jobs = true
    @AppStorage("notifications.dispatch") private var dispatch = true
    @AppStorage("notifications.tripReminders") private var tripReminders = true

    var body: some View {
        Form {
            Section("Push notifications") {
                Toggle("New job assignments", isOn: $jobs)
                Toggle("Dispatch updates", isOn: $dispatch)
                Toggle("Trip reminders", isOn: $tripReminders)
            }
            Section {
                Text("Toggles are stored on this device. Server-side per-event preferences sync on next sign-in.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Notifications")
    }
}
