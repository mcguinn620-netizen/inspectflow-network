import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif
#if canImport(EventKit)
import EventKit
#endif

/// Starts, updates, and ends the upcoming-event Live Activity.
///
/// Availability gates keep iOS 16.0 a clean compile target — Live Activities
/// require iOS 16.1, Dynamic Island content surfaces require iOS 16.2.
@MainActor
public final class LiveActivityController {

    public static let shared = LiveActivityController()

    private init() {}

    /// Starts a Live Activity for `event` if one is not already running for
    /// the same event id, or updates the existing one in place.
    @discardableResult
    public func startOrUpdate(for event: EKEvent) async -> Bool {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return false }
        guard let eventID = event.eventIdentifier else { return false }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }

        let attributes = UpcomingEventActivityAttributes(
            eventID: eventID,
            calendarTitle: event.calendar?.title ?? ""
        )
        let state = UpcomingEventActivityAttributes.ContentState(
            title: event.title ?? "",
            startDate: event.startDate,
            endDate: event.endDate,
            location: event.location
        )

        if let existing = Activity<UpcomingEventActivityAttributes>.activities
            .first(where: { $0.attributes.eventID == eventID }) {
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: state, staleDate: event.endDate)
                await existing.update(content)
            } else {
                await existing.update(using: state)
            }
            return true
        }

        do {
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: state, staleDate: event.endDate)
                _ = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
            } else {
                _ = try Activity.request(
                    attributes: attributes,
                    contentState: state,
                    pushType: nil
                )
            }
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }

    public func end(eventID: String) async {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }
        for activity in Activity<UpcomingEventActivityAttributes>.activities
            where activity.attributes.eventID == eventID {
            if #available(iOS 16.2, *) {
                await activity.end(nil, dismissalPolicy: .immediate)
            } else {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
        #endif
    }

    public func endAll() async {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }
        for activity in Activity<UpcomingEventActivityAttributes>.activities {
            if #available(iOS 16.2, *) {
                await activity.end(nil, dismissalPolicy: .immediate)
            } else {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
        #endif
    }
}
