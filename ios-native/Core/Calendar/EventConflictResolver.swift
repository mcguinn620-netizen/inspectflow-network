import Foundation

/// Deterministic conflict resolution for `EventMetadata` records that may have
/// been edited concurrently on multiple devices or processes.
///
/// Strategy:
/// 1. Higher `version` always wins outright.
/// 2. When versions are equal, the record with the more recent `updatedAt`
///    wins; ties break in favor of the later `lastSyncedAt`, then on `eventID`
///    for full determinism.
/// 3. Scalar fields are taken from the winner. Collections (`tags`,
///    `checklist`, `attachments`) are field-level merged by `id`/value union
///    so concurrent appends on different devices don't lose data.
public enum EventConflictResolver {

    public static func merge(_ a: EventMetadata, _ b: EventMetadata) -> EventMetadata {
        let (winner, loser) = order(a, b)
        var merged = winner

        merged.tags = mergeUnique(winner.tags, loser.tags)
        merged.checklist = mergeChecklist(winner.checklist, loser.checklist)
        merged.attachments = mergeAttachments(winner.attachments, loser.attachments)

        // Preserve earliest creation timestamp.
        merged.createdAt = min(winner.createdAt, loser.createdAt)
        // Bump version to encode the merge.
        merged.version = max(winner.version, loser.version) + 1
        merged.updatedAt = Date()
        return merged
    }

    // MARK: - Ordering

    private static func order(
        _ a: EventMetadata,
        _ b: EventMetadata
    ) -> (winner: EventMetadata, loser: EventMetadata) {
        if a.version != b.version {
            return a.version > b.version ? (a, b) : (b, a)
        }
        if a.updatedAt != b.updatedAt {
            return a.updatedAt > b.updatedAt ? (a, b) : (b, a)
        }
        let aSync = a.lastSyncedAt ?? .distantPast
        let bSync = b.lastSyncedAt ?? .distantPast
        if aSync != bSync {
            return aSync > bSync ? (a, b) : (b, a)
        }
        return a.eventID >= b.eventID ? (a, b) : (b, a)
    }

    // MARK: - Collection merges

    private static func mergeUnique(_ lhs: [String], _ rhs: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for v in lhs + rhs where seen.insert(v).inserted {
            out.append(v)
        }
        return out
    }

    private static func mergeChecklist(
        _ lhs: [ScheduleChecklistItem],
        _ rhs: [ScheduleChecklistItem]
    ) -> [ScheduleChecklistItem] {
        var byID: [UUID: ScheduleChecklistItem] = [:]
        var order: [UUID] = []
        for item in lhs + rhs {
            if let existing = byID[item.id] {
                // "done" wins if either side marked complete.
                var merged = existing
                merged.done = existing.done || item.done
                // Prefer non-empty title.
                if merged.title.isEmpty { merged.title = item.title }
                byID[item.id] = merged
            } else {
                byID[item.id] = item
                order.append(item.id)
            }
        }
        return order.compactMap { byID[$0] }
    }

    private static func mergeAttachments(
        _ lhs: [EventAttachment],
        _ rhs: [EventAttachment]
    ) -> [EventAttachment] {
        var byID: [UUID: EventAttachment] = [:]
        var order: [UUID] = []
        for item in lhs + rhs where byID[item.id] == nil {
            byID[item.id] = item
            order.append(item.id)
        }
        return order.compactMap { byID[$0] }
    }
}
