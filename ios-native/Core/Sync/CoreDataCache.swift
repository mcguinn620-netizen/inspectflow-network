import Foundation

/// Lightweight on-disk JSON cache for read-from-cache-then-refresh.
/// Keeps tier 2 dependency-free (no extra Core Data entities required).
@MainActor
final class CoreDataCache {
    static let shared = CoreDataCache()

    private let dir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let d = base.appendingPathComponent("ain-cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    private func url(for key: String) -> URL { dir.appendingPathComponent("\(key).json") }

    func save<T: Encodable>(_ value: T, for key: String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(value) {
            try? data.write(to: url(for: key), options: .atomic)
        }
    }

    func load<T: Decodable>(_ type: T.Type, for key: String) -> T? {
        guard let data = try? Data(contentsOf: url(for: key)) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }

    func clear(_ key: String) {
        try? FileManager.default.removeItem(at: url(for: key))
    }
}

enum CacheKeys {
    static func jobs(_ orgId: UUID) -> String { "jobs-\(orgId.uuidString)" }
    static func trips(_ userId: UUID) -> String { "trips-\(userId.uuidString)" }
    static func vehicles(_ orgId: UUID) -> String { "vehicles-\(orgId.uuidString)" }
    static func inspectionRequests(_ orgId: UUID) -> String { "inspections-\(orgId.uuidString)" }
}
