import SwiftUI

/// Toolbar menu that exports scheduled jobs to the user's iPhone Calendar
/// via EventKit. Strictly additive — denial of calendar access is handled
/// inline without blocking the rest of the Schedule UI.
struct ScheduleExportMenu: View {

    let jobs: [Job]
    var onMessage: (String) -> Void = { _ in }

    var body: some View {
        Menu {
            Button {
                Task { await exportAll() }
            } label: {
                Label("Export visible week", systemImage: "square.and.arrow.up")
            }

            Button(role: .destructive) {
                Task { await removeAll() }
            } label: {
                Label("Remove all synced events", systemImage: "calendar.badge.minus")
            }
        } label: {
            Image(systemName: "calendar.badge.plus")
                .accessibilityLabel("Calendar Sync")
        }
    }

    private func exportAll() async {
        let result = await CalendarSyncService.shared.syncMany(jobs)
        if result.succeeded == 0 && result.failed > 0 {
            onMessage("Calendar access denied or save failed. Enable Calendars in Settings to export jobs.")
        } else {
            onMessage("Exported \(result.succeeded) job\(result.succeeded == 1 ? "" : "s") to iPhone Calendar.")
        }
    }

    private func removeAll() async {
        let removed = await CalendarSyncService.shared.removeAll(jobIDs: jobs.map(\.id))
        onMessage("Removed \(removed) event\(removed == 1 ? "" : "s") from iPhone Calendar.")
    }
}
