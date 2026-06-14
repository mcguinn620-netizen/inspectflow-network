import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// App Group-backed snapshot consumed by `AgendaWidgetExtension`.
///
/// The app process writes the next-N upcoming items (today + overdue) every
/// time `ScheduleViewModel` reloads. The widget extension reads the snapshot
/// inside its `TimelineProvider`. State crosses the process boundary through
/// `UserDefaults(suiteName:)`, never `UserDefaults.standard`.
public enum SharedAgendaStore {

    public static let appGroupID = "group.com.inspectflow.shared"
    public static let snapshotKey = "schedule.widget.snapshot.v1"
    /// Stable kind matching `AgendaWidget.kind`. Used to scope WidgetCenter
    /// timeline reloads from the app process.
    public static let agendaWidgetKind = "AgendaWidget"

    public struct Snapshot: Codable, Equatable, Sendable {
        public var generatedAt: Date
        public var items: [Item]

        public init(generatedAt: Date = Date(), items: [Item]) {
            self.generatedAt = generatedAt
            self.items = items
        }
    }

    public struct Item: Codable, Equatable, Identifiable, Sendable {
        public var id: String
        public var title: String
        public var startDate: Date
        public var endDate: Date
        public var location: String?
        public var calendarTitle: String?
        /// ARGB packed color for the calendar dot. Stored as `UInt32` so the
        /// widget extension does not need to depend on UIKit/AppKit.
        public var colorARGB: UInt32
        public var isAllDay: Bool
        public var isOverdue: Bool

        public init(
            id: String,
            title: String,
            startDate: Date,
            endDate: Date,
            location: String?,
            calendarTitle: String?,
            colorARGB: UInt32,
            isAllDay: Bool,
            isOverdue: Bool
        ) {
            self.id = id
            self.title = title
            self.startDate = startDate
            self.endDate = endDate
            self.location = location
            self.calendarTitle = calendarTitle
            self.colorARGB = colorARGB
            self.isAllDay = isAllDay
            self.isOverdue = isOverdue
        }
    }

    // MARK: - I/O

    public static func defaults() -> UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    public static func load() -> Snapshot? {
        guard let data = defaults()?.data(forKey: snapshotKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Snapshot.self, from: data)
    }

    public static func save(_ snapshot: Snapshot) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        defaults()?.set(data, forKey: snapshotKey)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: agendaWidgetKind)
        #endif
    }
}
