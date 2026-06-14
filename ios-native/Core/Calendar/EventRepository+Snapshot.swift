import Foundation
import EventKit
#if canImport(UIKit)
import UIKit
#endif

/// Publishes the next-N upcoming events to the App Group snapshot store
/// consumed by `AgendaWidgetExtension`.
@MainActor
public extension EventRepository {

    /// Number of items the widget snapshot keeps. Small enough to fit the
    /// large widget without bloating App Group storage.
    static let widgetSnapshotLimit = 12

    /// Builds a snapshot from `events` and writes it to the App Group store.
    /// Designed to be called at the end of `ScheduleViewModel.reloadEvents()`.
    func publishWidgetSnapshot(events: [EKEvent], now: Date = Date()) {
        let horizon = now.addingTimeInterval(60 * 60 * 24 * 2) // next 48h
        let relevant = events
            .filter { $0.endDate >= now.addingTimeInterval(-60 * 60 * 12) && $0.startDate <= horizon }
            .sorted { $0.startDate < $1.startDate }
            .prefix(Self.widgetSnapshotLimit)

        let items = relevant.map { event -> SharedAgendaStore.Item in
            SharedAgendaStore.Item(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: event.title ?? "Untitled",
                startDate: event.startDate,
                endDate: event.endDate,
                location: event.location,
                calendarTitle: event.calendar?.title,
                colorARGB: Self.argb(from: event.calendar?.cgColor),
                isAllDay: event.isAllDay,
                isOverdue: event.endDate < now
            )
        }
        SharedAgendaStore.save(SharedAgendaStore.Snapshot(generatedAt: now, items: Array(items)))
    }

    private static func argb(from cgColor: CGColor?) -> UInt32 {
        guard let cgColor, let components = cgColor.components else { return 0xFF3B82F6 }
        let r: CGFloat
        let g: CGFloat
        let b: CGFloat
        let a: CGFloat = components.count >= 4 ? components[3] : 1.0
        if components.count >= 3 {
            r = components[0]; g = components[1]; b = components[2]
        } else {
            // Grayscale color space — broadcast the single channel.
            r = components[0]; g = components[0]; b = components[0]
        }
        func clamp(_ v: CGFloat) -> UInt32 { UInt32(max(0, min(255, Int(v * 255)))) }
        return (clamp(a) << 24) | (clamp(r) << 16) | (clamp(g) << 8) | clamp(b)
    }
}
