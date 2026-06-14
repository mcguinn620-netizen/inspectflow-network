import Foundation
import EventKit
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

/// Parses a single natural-language line ("Lunch with Sam tomorrow at 1pm at
/// Joe's Diner for 90 min") into a draft `EKEvent`.
///
/// Implementation notes:
/// - Uses `NSDataDetector(.date)` for date/time + duration extraction (iOS 16+).
/// - Uses `NLTagger` with `.nameType` to harvest place/organization tokens for
///   the `location` field when an explicit "at <X>" / "in <X>" clause is absent.
/// - Title is whatever text remains after the date match and location clause
///   are stripped, trimmed of trailing connectives ("on", "at", "from", "for").
/// - All work is synchronous and cheap; expose `async` to keep call sites
///   future-proof and to allow off-main usage from a `Task`.
@available(iOS 16.0, *)
public struct NaturalLanguageSchedulingService: Sendable {

    public struct Draft: Sendable, Equatable {
        public var title: String
        public var start: Date
        public var end: Date
        public var location: String?
        public var notes: String?
    }

    public enum NLError: LocalizedError {
        case emptyInput
        case noDateFound
        public var errorDescription: String? {
            switch self {
            case .emptyInput:   return "Type something like \"Brake inspection tomorrow 2pm at Bay 3\"."
            case .noDateFound:  return "Couldn't find a date or time in that phrase."
            }
        }
    }

    private let defaultDuration: TimeInterval

    public init(defaultDuration: TimeInterval = 3600) {
        self.defaultDuration = defaultDuration
    }

    // MARK: - Public API

    public func parse(_ raw: String, referenceDate: Date = Date()) throws -> Draft {
        let input = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { throw NLError.emptyInput }

        let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let nsRange = NSRange(input.startIndex..<input.endIndex, in: input)
        let matches = detector.matches(in: input, options: [], range: nsRange)

        guard let dateMatch = matches.first, let start = dateMatch.date else {
            throw NLError.noDateFound
        }

        // Duration: prefer detector value, then "for N min/hr", else default.
        let detectedDuration = dateMatch.duration > 0 ? dateMatch.duration : nil
        let end = start.addingTimeInterval(
            detectedDuration ?? explicitDuration(in: input) ?? defaultDuration
        )

        // Remove date substring from working text before extracting location/title.
        var working = input
        if let r = Range(dateMatch.range, in: working) {
            working.removeSubrange(r)
        }

        let location = extractLocation(from: &working)
        stripDurationClause(in: &working)

        let title = cleanupTitle(working, fallback: input)

        return Draft(
            title: title,
            start: start,
            end: end,
            location: location,
            notes: nil
        )
    }

    /// Convenience that parses the input and persists the resulting event on
    /// the supplied calendar (defaults to the EventKit default for new events).
    @discardableResult
    public func createEvent(
        from raw: String,
        calendar: EKCalendar?,
        using repository: EventRepository,
        referenceDate: Date = Date()
    ) async throws -> EKEvent {
        let draft = try parse(raw, referenceDate: referenceDate)
        return try repository.createEvent(
            title: draft.title,
            in: calendar,
            start: draft.start,
            end: draft.end,
            location: draft.location,
            notes: draft.notes
        )
    }

    // MARK: - Helpers

    private func explicitDuration(in text: String) -> TimeInterval? {
        // Matches "for 90 min", "for 2 hours", "for 1h", "for 45m".
        let pattern = #"(?i)\bfor\s+(\d+(?:\.\d+)?)\s*(minute|minutes|min|mins|m|hour|hours|hr|hrs|h)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let m = regex.firstMatch(in: text, range: ns),
              m.numberOfRanges >= 3,
              let valueRange = Range(m.range(at: 1), in: text),
              let unitRange  = Range(m.range(at: 2), in: text),
              let value = Double(text[valueRange])
        else { return nil }
        let unit = text[unitRange].lowercased()
        let isHours = unit.hasPrefix("h")
        return isHours ? value * 3600 : value * 60
    }

    private func stripDurationClause(in text: inout String) {
        let pattern = #"(?i)\bfor\s+\d+(?:\.\d+)?\s*(?:minute|minutes|min|mins|m|hour|hours|hr|hrs|h)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let ns = NSRange(text.startIndex..<text.endIndex, in: text)
        text = regex.stringByReplacingMatches(in: text, range: ns, withTemplate: "")
    }

    private func extractLocation(from text: inout String) -> String? {
        // Explicit "at|in <Location>" clause anchored to end of string.
        let pattern = #"(?i)\b(?:at|in|@)\s+([A-Z0-9][^,.;]*?)\s*$"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let ns = NSRange(text.startIndex..<text.endIndex, in: text)
            if let m = regex.firstMatch(in: text, range: ns),
               m.numberOfRanges >= 2,
               let full = Range(m.range, in: text),
               let cap  = Range(m.range(at: 1), in: text) {
                let value = String(text[cap]).trimmingCharacters(in: .whitespacesAndNewlines)
                text.removeSubrange(full)
                if !value.isEmpty { return value }
            }
        }

        #if canImport(NaturalLanguage)
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        var found: String?
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .nameType,
            options: [.omitWhitespace, .omitPunctuation, .joinNames]
        ) { tag, range in
            if let tag, tag == .placeName || tag == .organizationName {
                found = String(text[range])
                return false
            }
            return true
        }
        return found
        #else
        return nil
        #endif
    }

    private func cleanupTitle(_ text: String, fallback: String) -> String {
        var trimmed = text
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Drop dangling connectives left over after date/location removal.
        let trailing = ["on", "at", "from", "for", "in", "by", "@", "-", "–"]
        var changed = true
        while changed {
            changed = false
            for token in trailing {
                if trimmed.lowercased().hasSuffix(" " + token) {
                    trimmed = String(trimmed.dropLast(token.count + 1))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    changed = true
                }
                if trimmed.lowercased().hasPrefix(token + " ") {
                    trimmed = String(trimmed.dropFirst(token.count + 1))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    changed = true
                }
            }
            // Collapse repeated whitespace introduced by removals.
            while trimmed.contains("  ") {
                trimmed = trimmed.replacingOccurrences(of: "  ", with: " ")
            }
        }

        if trimmed.isEmpty {
            return fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }
}
