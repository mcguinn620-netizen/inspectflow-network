import Foundation

/// FIFO mutation outbox persisted to disk so writes survive app relaunch and offline periods.
/// Replaces the older in-memory `MutationQueue`.
public struct OutboxEntry: Codable, Identifiable, Equatable {
    public enum Op: String, Codable { case insert, update, upsert, delete }

    public let id: UUID
    public let table: String
    public let op: Op
    public let payload: Data           // JSON-encoded row(s)
    public let matchColumn: String?    // for update/delete (e.g. "id")
    public let matchValue: String?
    public var attemptCount: Int
    public var lastError: String?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        table: String,
        op: Op,
        payload: Data,
        matchColumn: String? = nil,
        matchValue: String? = nil,
        attemptCount: Int = 0,
        lastError: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.table = table
        self.op = op
        self.payload = payload
        self.matchColumn = matchColumn
        self.matchValue = matchValue
        self.attemptCount = attemptCount
        self.lastError = lastError
        self.createdAt = createdAt
    }
}

@MainActor
public final class Outbox: ObservableObject {
    public static let shared = Outbox()

    @Published public private(set) var pending: [OutboxEntry] = []

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("ain-outbox.json")
    }()

    private init() {
        load()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        pending = (try? decoder.decode([OutboxEntry].self, from: data)) ?? []
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = (try? encoder.encode(pending)) ?? Data()
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Enqueue helpers

    @discardableResult
    public func enqueueInsert<T: Encodable>(table: String, row: T) -> OutboxEntry {
        let payload = (try? JSONEncoder.api.encode(row)) ?? Data("{}".utf8)
        let entry = OutboxEntry(table: table, op: .insert, payload: payload)
        pending.append(entry); persist()
        return entry
    }

    @discardableResult
    public func enqueueUpdate<T: Encodable>(table: String, row: T, matchColumn: String, matchValue: String) -> OutboxEntry {
        let payload = (try? JSONEncoder.api.encode(row)) ?? Data("{}".utf8)
        let entry = OutboxEntry(
            table: table, op: .update, payload: payload,
            matchColumn: matchColumn, matchValue: matchValue
        )
        pending.append(entry); persist()
        return entry
    }

    @discardableResult
    public func enqueueRaw(table: String, op: OutboxEntry.Op, payload: Data,
                           matchColumn: String? = nil, matchValue: String? = nil) -> OutboxEntry {
        let entry = OutboxEntry(table: table, op: op, payload: payload,
                                matchColumn: matchColumn, matchValue: matchValue)
        pending.append(entry); persist()
        return entry
    }

    // MARK: - Drain

    func remove(id: UUID) {
        pending.removeAll { $0.id == id }
        persist()
    }

    func mutate(id: UUID, transform: (inout OutboxEntry) -> Void) {
        guard let idx = pending.firstIndex(where: { $0.id == id }) else { return }
        var entry = pending[idx]
        transform(&entry)
        pending[idx] = entry
        persist()
    }

    public func nextDrainable() -> OutboxEntry? { pending.first }
}

extension JSONEncoder {
    static var api: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }
}
