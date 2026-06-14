import Foundation
import EventKit

/// Dual-identifier handle for a calendar event.
///
/// `eventIdentifier` is the volatile, per-store id (changes when an event is
/// detached from a recurring series or moved to a different store).
/// `calendarItemExternalIdentifier` is the stable, cross-device identifier we
/// use to keep app metadata attached to the same logical event across syncs.
///
/// Always prefer `externalID` when persisting a link; fall back to
/// `eventIdentifier` only when the external id is unavailable.
public struct EventIdentity: Hashable, Codable, Sendable {

    public var eventIdentifier: String?
    public var externalID: String?

    public init(eventIdentifier: String? = nil, externalID: String? = nil) {
        self.eventIdentifier = eventIdentifier
        self.externalID = externalID
    }

    public init(event: EKEvent) {
        self.eventIdentifier = event.eventIdentifier
        self.externalID = event.calendarItemExternalIdentifier
    }

    /// Stable preference order: external id (cross-store) > event id.
    public var primaryKey: String {
        externalID ?? eventIdentifier ?? ""
    }

    public var isValid: Bool {
        !(externalID?.isEmpty ?? true) || !(eventIdentifier?.isEmpty ?? true)
    }

    public func resolve(in store: EKEventStore) -> EKEvent? {
        if let externalID,
           let item = store.calendarItems(withExternalIdentifier: externalID).first as? EKEvent {
            return item
        }
        if let eventIdentifier {
            return store.event(withIdentifier: eventIdentifier)
        }
        return nil
    }
}
