import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Shared between the app process (which starts/updates the activity) and the
/// widget extension (which renders it on the Lock Screen / Dynamic Island).
///
/// Gated by ActivityKit availability so the file compiles on non-iOS targets
/// (Mac Catalyst falls back to the no-op stub).
#if canImport(ActivityKit)
@available(iOS 16.1, *)
public struct UpcomingEventActivityAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        public var title: String
        public var startDate: Date
        public var endDate: Date
        public var location: String?

        public init(title: String, startDate: Date, endDate: Date, location: String? = nil) {
            self.title = title
            self.startDate = startDate
            self.endDate = endDate
            self.location = location
        }
    }

    /// Eventually invariant — the EventKit identifier the activity tracks.
    public let eventID: String
    public let calendarTitle: String

    public init(eventID: String, calendarTitle: String) {
        self.eventID = eventID
        self.calendarTitle = calendarTitle
    }
}
#endif
