import Foundation
import UniformTypeIdentifiers
import SwiftUI
import EventKit

/// Drag payload exchanged between calendar surfaces during a reschedule
/// gesture. Encoded as a plain UTF-8 string on the pasteboard so the same
/// `NSItemProvider` works on iOS 16 (no `Transferable`) and iOS 17+.
///
/// Wire format: `"v1|<externalID>|<eventIdentifier>|<originalStartEpoch>"`.
/// Any field may be empty (encoded as the empty string).
public struct EventDragPayload: Hashable, Sendable {

    public static let utType: UTType = .utf8PlainText
    public static let pasteboardType: String = UTType.utf8PlainText.identifier

    public var identity: EventIdentity
    public var originalStart: Date

    public init(identity: EventIdentity, originalStart: Date) {
        self.identity = identity
        self.originalStart = originalStart
    }

    public init(event: EKEvent) {
        self.identity = EventIdentity(event: event)
        self.originalStart = event.startDate
    }

    public func encoded() -> String {
        let ext = identity.externalID ?? ""
        let evt = identity.eventIdentifier ?? ""
        let ts = String(originalStart.timeIntervalSince1970)
        return "v1|\(ext)|\(evt)|\(ts)"
    }

    public static func decode(_ raw: String) -> EventDragPayload? {
        let parts = raw.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 4, parts[0] == "v1" else { return nil }
        let identity = EventIdentity(
            eventIdentifier: parts[2].isEmpty ? nil : parts[2],
            externalID: parts[1].isEmpty ? nil : parts[1]
        )
        guard identity.isValid, let ts = TimeInterval(parts[3]) else { return nil }
        return EventDragPayload(
            identity: identity,
            originalStart: Date(timeIntervalSince1970: ts)
        )
    }

    public func itemProvider() -> NSItemProvider {
        NSItemProvider(object: encoded() as NSString)
    }
}

