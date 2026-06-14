import Foundation
import EventKit

/// Recurrence helpers for the Schedule editor. Encapsulates EKRecurrenceRule
/// construction so views never have to deal with raw EventKit types.
public enum RecurrenceFrequency: String, CaseIterable, Identifiable, Codable, Sendable {
    case none, daily, weekly, monthly, yearly
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .none:    return "Does not repeat"
        case .daily:   return "Daily"
        case .weekly:  return "Weekly"
        case .monthly: return "Monthly"
        case .yearly:  return "Yearly"
        }
    }

    fileprivate var ekFrequency: EKRecurrenceFrequency? {
        switch self {
        case .none:    return nil
        case .daily:   return .daily
        case .weekly:  return .weekly
        case .monthly: return .monthly
        case .yearly:  return .yearly
        }
    }
}

public enum RecurrenceEnd: Equatable, Sendable {
    case never
    case on(Date)
    case after(occurrences: Int)
}

public struct RecurrenceSpec: Equatable, Sendable {
    public var frequency: RecurrenceFrequency
    public var interval: Int
    public var end: RecurrenceEnd

    public init(
        frequency: RecurrenceFrequency = .none,
        interval: Int = 1,
        end: RecurrenceEnd = .never
    ) {
        self.frequency = frequency
        self.interval = max(1, interval)
        self.end = end
    }

    public static let none = RecurrenceSpec()
}

@MainActor
extension EventKitService {

    /// Returns a recurrence spec derived from the event's first recurrence rule,
    /// or `.none` when the event is non-repeating.
    public func recurrenceSpec(for event: EKEvent) -> RecurrenceSpec {
        guard let rule = event.recurrenceRules?.first else { return .none }
        let frequency: RecurrenceFrequency
        switch rule.frequency {
        case .daily:   frequency = .daily
        case .weekly:  frequency = .weekly
        case .monthly: frequency = .monthly
        case .yearly:  frequency = .yearly
        @unknown default: frequency = .none
        }
        let end: RecurrenceEnd
        if let ekEnd = rule.recurrenceEnd {
            if let date = ekEnd.endDate {
                end = .on(date)
            } else if ekEnd.occurrenceCount > 0 {
                end = .after(occurrences: ekEnd.occurrenceCount)
            } else {
                end = .never
            }
        } else {
            end = .never
        }
        return RecurrenceSpec(frequency: frequency, interval: rule.interval, end: end)
    }

    /// Applies `spec` to `event` and persists. Pass `.none` frequency to clear
    /// existing recurrence rules.
    public func applyRecurrence(_ spec: RecurrenceSpec, to event: EKEvent) throws {
        // Clear any prior rules first.
        if let existing = event.recurrenceRules {
            for rule in existing { event.removeRecurrenceRule(rule) }
        }
        guard let ekFreq = spec.frequency.ekFrequency else {
            try store.save(event, span: .futureEvents, commit: true)
            return
        }
        let ekEnd: EKRecurrenceEnd?
        switch spec.end {
        case .never:
            ekEnd = nil
        case .on(let date):
            ekEnd = EKRecurrenceEnd(end: date)
        case .after(let count):
            ekEnd = EKRecurrenceEnd(occurrenceCount: max(1, count))
        }
        let rule = EKRecurrenceRule(
            recurrenceWith: ekFreq,
            interval: max(1, spec.interval),
            end: ekEnd
        )
        event.addRecurrenceRule(rule)
        try store.save(event, span: .futureEvents, commit: true)
    }
}
