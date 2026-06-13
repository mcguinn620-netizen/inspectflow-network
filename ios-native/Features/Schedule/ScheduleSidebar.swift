import SwiftUI
import EventKit

/// Sidebar pane for the adaptive Schedule split layout.
///
/// Lists system calendars with toggles (filters which events appear) and
/// shows quick category/tag filters sourced from app metadata.
struct ScheduleSidebar: View {

    @ObservedObject var viewModel: ScheduleViewModel
    @ObservedObject var eventKit: EventKitService = .shared

    var body: some View {
        List {
            Section("System Calendars") {
                ForEach(eventKit.store.calendars(for: .event), id: \.calendarIdentifier) { cal in
                    calendarRow(cal)
                }
            }

            Section("Categories") {
                let categories = Set(viewModel.metadataByEventID.values.compactMap { $0.category })
                    .sorted()
                if categories.isEmpty {
                    Text("No categories yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(categories, id: \.self) { cat in
                        Label(cat, systemImage: "tag")
                    }
                }
            }

            Section("Tags") {
                let tags = Set(viewModel.metadataByEventID.values.flatMap { $0.tags }).sorted()
                if tags.isEmpty {
                    Text("No tags yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(tags, id: \.self) { tag in
                        Label("#\(tag)", systemImage: "number")
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Filters")
    }

    private func calendarRow(_ cal: EKCalendar) -> some View {
        let isOn = viewModel.visibleCalendarIDs.isEmpty
            || viewModel.visibleCalendarIDs.contains(cal.calendarIdentifier)
        return Toggle(isOn: Binding(
            get: { isOn },
            set: { newValue in
                if viewModel.visibleCalendarIDs.isEmpty {
                    // Seed from current list if user starts filtering.
                    viewModel.visibleCalendarIDs = Set(
                        eventKit.store.calendars(for: .event).map(\.calendarIdentifier)
                    )
                }
                if newValue {
                    viewModel.visibleCalendarIDs.insert(cal.calendarIdentifier)
                } else {
                    viewModel.visibleCalendarIDs.remove(cal.calendarIdentifier)
                }
                Task { await viewModel.reloadEvents() }
            }
        )) {
            HStack {
                Circle()
                    .fill(Color(cgColor: cal.cgColor))
                    .frame(width: 10, height: 10)
                Text(cal.title)
            }
        }
    }
}
