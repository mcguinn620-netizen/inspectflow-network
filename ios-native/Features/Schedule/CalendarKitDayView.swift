import SwiftUI
import EventKit

/// Compatibility shim that used to wrap CalendarKit's `DayViewController`.
///
/// CalendarKit has been removed; this struct now bridges to the native
/// `ScheduleDayGrid` so existing call sites in `ScheduleView` keep working.
struct CalendarKitDayView: View {

    let date: Date
    let jobs: [Job]
    let conflicts: [UUID: [ScheduleConflict]]
    let canReschedule: Bool
    var onSelect: (Job) -> Void = { _ in }
    var onLongPress: (Job) -> Void = { _ in }
    var onReschedule: (Job, Date) -> Void = { _, _ in }

    var body: some View {
        ScheduleDayGrid(
            date: date,
            events: [],
            jobs: jobs,
            onSelectEvent: { _ in },
            onSelectJob: { job in onSelect(job) }
        )
    }
}
