import Foundation

/// Session shim for `AuthBypass` mock users.
///
/// Mock users have no Supabase JWT, so every RLS-protected PostgREST read
/// returns an empty set. When the bypass is on, `SupabaseService` routes reads
/// through this shim, which calls the service-role `mock-read` edge function
/// with the mock user's id. Real-auth mode never touches this type.
enum MockSession {

    struct Filter {
        let column: String
        let op: String
        let value: Any

        static func eq(_ column: String, _ value: Any) -> Filter { .init(column: column, op: "eq", value: value) }
        static func gte(_ column: String, _ value: Any) -> Filter { .init(column: column, op: "gte", value: value) }
        static func lt(_ column: String, _ value: Any) -> Filter { .init(column: column, op: "lt", value: value) }
        static func inList(_ column: String, _ values: [String]) -> Filter { .init(column: column, op: "in", value: values) }
        static func isNull(_ column: String) -> Filter { .init(column: column, op: "is", value: NSNull()) }
    }

    enum MockSessionError: LocalizedError {
        case noMockUser
        case server(String)

        var errorDescription: String? {
            switch self {
            case .noMockUser: return "No test user is selected."
            case .server(let m): return m
            }
        }
    }

    private static let payloadKey = "debugUserPayload"

    /// The mock user chosen in the test-user picker, if any.
    static var currentUser: DebugUser? {
        guard AuthBypass.isEnabled,
              let data = UserDefaults.standard.data(forKey: payloadKey) else { return nil }
        return try? JSONDecoder().decode(DebugUser.self, from: data)
    }

    static var isActive: Bool { AuthBypass.isEnabled && currentUser != nil }
    static var userID: UUID? { currentUser?.id }
    static var organizationID: UUID? { currentUser?.organizationID }

    /// Reads rows from an allowlisted table via the `mock-read` edge function.
    static func read<T: Decodable>(
        _ table: String,
        filters: [Filter] = [],
        order: String? = nil,
        ascending: Bool = true,
        limit: Int = 100
    ) async throws -> [T] {
        guard let user = currentUser else { throw MockSessionError.noMockUser }

        var payload: [String: Any] = [
            "mock_user_id": user.id.uuidString,
            "table": table,
            "limit": limit,
            "ascending": ascending,
            "filters": filters.map { f -> [String: Any] in
                ["column": f.column, "op": f.op, "value": f.value is NSNull ? NSNull() : f.value]
            }
        ]
        if let order { payload["order"] = order }

        var req = URLRequest(url: SupabaseConfig.baseURL
            .appendingPathComponent("functions/v1/mock-read"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw MockSessionError.server("Invalid response") }

        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard (200..<300).contains(http.statusCode) else {
            throw MockSessionError.server((object?["error"] as? String) ?? "mock-read failed (\(http.statusCode))")
        }
        let rows = object?["rows"] as? [Any] ?? []
        let rowData = try JSONSerialization.data(withJSONObject: rows)
        return try JSONDecoder.supabase().decode([T].self, from: rowData)
    }

    static func readOne<T: Decodable>(
        _ table: String,
        filters: [Filter] = [],
        order: String? = nil,
        ascending: Bool = true
    ) async throws -> T? {
        let rows: [T] = try await read(table, filters: filters, order: order, ascending: ascending, limit: 1)
        return rows.first
    }
}
