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

/// `JobEvent` round-trips a `Job` through CalendarKit's `EventDescriptor`
/// protocol so selections and drags can be mapped back to our domain model.
final class JobEvent: Event {
    let job: Job
    init(job: Job, conflicts: [ScheduleConflict]) {
        self.job = job
        super.init()
        let start = job.scheduledAt ?? Date()
        let end = Calendar.current.date(byAdding: .minute, value: 90, to: start) ?? start.addingTimeInterval(5400)
        dateInterval = DateInterval(start: start, end: end)
        isAllDay = false
        text = job.title + "\n" + (job.customerName ?? job.location ?? "")
        color = JobEvent.color(for: job.status)
        backgroundColor = color.withAlphaComponent(0.18)
        textColor = .label
        if !conflicts.isEmpty {
            lineBreakMode = .byTruncatingTail
            color = .systemRed
            backgroundColor = UIColor.systemRed.withAlphaComponent(0.18)
            text = "⚠︎ " + (text ?? "")
        }
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
            return JobEvent(job: job, conflicts: conflicts[job.id] ?? [])
        }
    }

    override func dayViewDidSelectEventView(_ eventView: EventView) {
        guard let job = (eventView.descriptor as? JobEvent)?.job else { return }
        bridge?.parent.onSelect(job)
    }

    override func dayViewDidLongPressEventView(_ eventView: EventView) {
        guard let job = (eventView.descriptor as? JobEvent)?.job else { return }
        bridge?.parent.onLongPress(job)
    }

    override func dayView(dayView: DayView, willMoveTo date: Date) {
        super.dayView(dayView: dayView, willMoveTo: date)
    }

    override func dayViewDidLongPressTimelineAtHour(_ hour: Int) { /* no-op */ }

    override func dayView(dayView: DayView, didUpdate event: EventDescriptor) {
        defer { endEventEditing() }
        guard canReschedule,
              let descriptor = event.editedEvent as? JobEvent ?? event as? JobEvent
        else { return }
        let newStart = (event.editedEvent?.dateInterval.start) ?? event.dateInterval.start
        bridge?.parent.onReschedule(descriptor.job, newStart)
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
