import Foundation

struct QueuedMutation: Codable, Identifiable {
    let id: UUID
    let table: String
    let payload: [String: String]
    let createdAt: Date
}

final class MutationQueue {
    static let shared = MutationQueue()
    private(set) var pending: [QueuedMutation] = []

    func enqueue(_ mutation: QueuedMutation) {
        pending.append(mutation)
    }

    func drain() -> [QueuedMutation] {
        let copy = pending
        pending.removeAll()
        return copy
    }
}
