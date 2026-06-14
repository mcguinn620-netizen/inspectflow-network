import Foundation
import EventKit

/// Result of a unified Schedule search hit, fronted by an EKEvent and
/// optionally enriched with the app's metadata record.
public struct ScheduleSearchHit: Identifiable, Hashable {
    public let event: EKEvent
    public let metadata: EventMetadata?
    public let score: Double

    public var id: String {
        event.eventIdentifier ?? event.calendarItemExternalIdentifier ?? UUID().uuidString
    }

    public static func == (lhs: ScheduleSearchHit, rhs: ScheduleSearchHit) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Search across EKEvents and app metadata. Matches title, location, notes,
/// category, tags, and rich notes. Results are ranked by a simple heuristic
/// (title hits weighted highest, then metadata, then notes/location).
@MainActor
public final class ScheduleSearchService {

    private let repository: EventRepository

    public init(repository: EventRepository = .shared) {
        self.repository = repository
    }

    public func search(
        query rawQuery: String,
        in interval: DateInterval,
        metadataByEventID: [String: EventMetadata]
    ) -> [ScheduleSearchHit] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return [] }

        let events = repository.events(in: interval, visibleOnly: true)
        var hits: [ScheduleSearchHit] = []
        hits.reserveCapacity(events.count)

        for event in events {
            let metadata = event.eventIdentifier.flatMap { metadataByEventID[$0] }
            let score = relevance(of: event, metadata: metadata, query: query)
            if score > 0 {
                hits.append(ScheduleSearchHit(event: event, metadata: metadata, score: score))
            }
        }
        return hits.sorted { lhs, rhs in
            if lhs.score == rhs.score { return lhs.event.startDate > rhs.event.startDate }
            return lhs.score > rhs.score
        }
    }

    // MARK: - Ranking

    private func relevance(of event: EKEvent, metadata: EventMetadata?, query: String) -> Double {
        var score: Double = 0
        if let title = event.title?.lowercased(), title.contains(query) {
            score += title.hasPrefix(query) ? 5 : 3
        }
        if let location = event.location?.lowercased(), location.contains(query) {
            score += 2
        }
        if let notes = event.notes?.lowercased(), notes.contains(query) {
            score += 1
        }
        if let metadata {
            if let category = metadata.category?.lowercased(), category.contains(query) {
                score += 2.5
            }
            if metadata.tags.contains(where: { $0.lowercased().contains(query) }) {
                score += 2
            }
            if metadata.richNotes.lowercased().contains(query) {
                score += 1
            }
            if metadata.checklist.contains(where: { $0.title.lowercased().contains(query) }) {
                score += 1
            }
        }
        return score
    }
}
