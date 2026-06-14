import SwiftUI
import EventKit

/// Coordinator that turns a dropped `EventDragPayload` into a reschedule
/// action via `ScheduleViewModel`. All surfaces (day / week / month) share
/// this single sink so haptics, validation, and refresh stay consistent.
@MainActor
final class EventDropCoordinator {

    let viewModel: ScheduleViewModel

    init(viewModel: ScheduleViewModel) {
        self.viewModel = viewModel
    }

    func reschedule(payload: EventDragPayload, to newStart: Date) {
        Task { @MainActor in
            await viewModel.reschedule(identity: payload.identity, originalStart: payload.originalStart, to: newStart)
        }
    }
}

/// Decodes a `String` `NSItemProvider` into an `EventDragPayload`.
@MainActor
func loadEventDragPayload(
    from providers: [NSItemProvider],
    completion: @escaping (EventDragPayload?) -> Void
) {
    guard let provider = providers.first(where: {
        $0.hasItemConformingToTypeIdentifier(EventDragPayload.pasteboardType)
    }) else {
        completion(nil)
        return
    }
    _ = provider.loadObject(ofClass: NSString.self) { object, _ in
        let payload: EventDragPayload? = (object as? String).flatMap(EventDragPayload.decode)
        DispatchQueue.main.async { completion(payload) }
    }
}

// MARK: - Day & Week grid drop delegate

/// Drop delegate for a single time-axis column (a day in the day grid or one
/// of the 7 columns in the week grid). The column reports the y position of
/// the drop and the delegate converts that into a snapped `Date`.
struct TimeColumnDropDelegate: DropDelegate {

    let date: Date
    let startHour: Int
    let endHour: Int
    let hourHeight: CGFloat
    let snapMinutes: Int
    let coordinator: EventDropCoordinator
    @Binding var highlight: Date?

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [EventDragPayload.utType])
    }

    func dropEntered(info: DropInfo) {
        highlight = snappedDate(forY: info.location.y)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        highlight = snappedDate(forY: info.location.y)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        highlight = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        let target = snappedDate(forY: info.location.y)
        highlight = nil
        let providers = info.itemProviders(for: [EventDragPayload.utType])
        loadEventDragPayload(from: providers) { payload in
            guard let payload else { return }
            UISelectionFeedbackGenerator().selectionChanged()
            coordinator.reschedule(payload: payload, to: target)
        }
        return true
    }

    private func snappedDate(forY y: CGFloat) -> Date {
        let totalMinutes = max(0, Int((y / hourHeight) * 60))
        let maxMinutes = (endHour - startHour) * 60 - snapMinutes
        let clamped = min(max(0, totalMinutes), max(0, maxMinutes))
        let snapped = (clamped / snapMinutes) * snapMinutes
        let cal = Calendar.current
        let base = cal.date(bySettingHour: startHour, minute: 0, second: 0, of: date) ?? date
        return cal.date(byAdding: .minute, value: snapped, to: base) ?? base
    }
}

// MARK: - Month matrix drop delegate

/// Drops on a month cell snap to the same wall-clock time as the dragged
/// event, just on the new calendar day.
struct MonthDayDropDelegate: DropDelegate {

    let day: Date
    let coordinator: EventDropCoordinator
    @Binding var highlightedDay: Date?

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [EventDragPayload.utType])
    }

    func dropEntered(info: DropInfo) { highlightedDay = day }
    func dropExited(info: DropInfo) {
        if let h = highlightedDay, Calendar.current.isDate(h, inSameDayAs: day) {
            highlightedDay = nil
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        highlightedDay = nil
        let providers = info.itemProviders(for: [EventDragPayload.utType])
        loadEventDragPayload(from: providers) { payload in
            guard let payload else { return }
            let cal = Calendar.current
            let comps = cal.dateComponents([.hour, .minute], from: payload.originalStart)
            let target = cal.date(
                bySettingHour: comps.hour ?? 9,
                minute: comps.minute ?? 0,
                second: 0,
                of: day
            ) ?? day
            UISelectionFeedbackGenerator().selectionChanged()
            coordinator.reschedule(payload: payload, to: target)
        }
        return true
    }
}

