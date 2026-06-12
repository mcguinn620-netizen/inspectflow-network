#if canImport(CalendarKit)
import SwiftUI
import UIKit
import CalendarKit

/// SwiftUI bridge wrapping CalendarKit's `DayViewController` to render `Job`
/// objects as draggable events for the Schedule screen.
struct CalendarKitDayView: UIViewControllerRepresentable {

    let date: Date
    let jobs: [Job]
    let conflicts: [UUID: [ScheduleConflict]]
    let canReschedule: Bool
    var onSelect: (Job) -> Void = { _ in }
    var onLongPress: (Job) -> Void = { _ in }
    var onReschedule: (Job, Date) -> Void = { _, _ in }

    func makeUIViewController(context: Context) -> ScheduleDayViewController {
        let controller = ScheduleDayViewController()
        controller.bridge = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: ScheduleDayViewController, context: Context) {
        context.coordinator.parent = self
        controller.bridge = context.coordinator
        controller.jobs = jobs
        controller.conflicts = conflicts
        controller.canReschedule = canReschedule
        controller.move(to: date)
        controller.reloadData()
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator {
        var parent: CalendarKitDayView
        init(parent: CalendarKitDayView) { self.parent = parent }
    }
}

/// Factory that builds a CalendarKit `Event` from a `Job` and attaches the
/// originating job via `userInfo` so callbacks can recover it.
enum JobEventFactory {
    static func make(job: Job, conflicts: [ScheduleConflict]) -> Event {
        let event = Event()
        let start = job.scheduledAt ?? Date()
        let end = Calendar.current.date(byAdding: .minute, value: 90, to: start) ?? start.addingTimeInterval(5400)
        event.dateInterval = DateInterval(start: start, end: end)
        event.isAllDay = false
        var text = job.title + "\n" + (job.customerName ?? job.location ?? "")
        event.color = color(for: job.status)
        event.backgroundColor = event.color.withAlphaComponent(0.18)
        event.textColor = .label
        if !conflicts.isEmpty {
            event.lineBreakMode = .byTruncatingTail
            event.color = .systemRed
            event.backgroundColor = UIColor.systemRed.withAlphaComponent(0.18)
            text = "⚠︎ " + text
        }
        event.text = text
        event.userInfo = job
        return event
    }

    private static func color(for status: String) -> UIColor {
        switch status {
        case "completed": return .systemGreen
        case "in_progress": return .systemBlue
        case "canceled": return .systemGray
        case "scheduled": return .systemIndigo
        default: return .systemTeal
        }
    }
}

/// CalendarKit subclass that surfaces drag/select callbacks to SwiftUI.
final class ScheduleDayViewController: DayViewController {

    weak var bridge: CalendarKitDayView.Coordinator?
    var jobs: [Job] = []
    var conflicts: [UUID: [ScheduleConflict]] = [:]
    var canReschedule: Bool = false

    override func eventsForDate(_ date: Date) -> [EventDescriptor] {
        let cal = Calendar.current
        return jobs.compactMap { job in
            guard let start = job.scheduledAt, cal.isDate(start, inSameDayAs: date) else { return nil }
            return JobEventFactory.make(job: job, conflicts: conflicts[job.id] ?? [])
        }
    }

    private func job(from descriptor: EventDescriptor?) -> Job? {
        (descriptor as? Event)?.userInfo as? Job
    }

    override func dayViewDidSelectEventView(_ eventView: EventView) {
        guard let job = job(from: eventView.descriptor) else { return }
        bridge?.parent.onSelect(job)
    }

    override func dayViewDidLongPressEventView(_ eventView: EventView) {
        guard let job = job(from: eventView.descriptor) else { return }
        bridge?.parent.onLongPress(job)
    }

    override func dayView(dayView: DayView, willMoveTo date: Date) {
        super.dayView(dayView: dayView, willMoveTo: date)
    }

    override func dayView(dayView: DayView, didUpdate event: EventDescriptor) {
        defer { endEventEditing() }
        guard canReschedule,
              let job = job(from: event.editedEvent) ?? job(from: event)
        else { return }
        let newStart = (event.editedEvent?.dateInterval.start) ?? event.dateInterval.start
        bridge?.parent.onReschedule(job, newStart)
    }

}
#else
import SwiftUI

/// Fallback rendered when CalendarKit isn't linked (e.g., Swift Playgrounds or
/// a build configuration that omits the SPM dependency).
struct CalendarKitDayView: View {
    let date: Date
    let jobs: [Job]
    let conflicts: [UUID: [ScheduleConflict]]
    let canReschedule: Bool
    var onSelect: (Job) -> Void = { _ in }
    var onLongPress: (Job) -> Void = { _ in }
    var onReschedule: (Job, Date) -> Void = { _, _ in }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("CalendarKit is unavailable in this build.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif
