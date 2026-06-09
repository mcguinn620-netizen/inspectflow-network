import Foundation

public final class QueryBuilder {
    private let table: String
    private let config: InspectFlowConfig
    private let auth: AuthClient
    private let urlSession: URLSession

    private var method: String = "GET"
    private var isMutating: Bool = false
    private var query: [URLQueryItem] = []
    private var body: Data?
    private var prefer: [String] = []

    init(table: String, config: InspectFlowConfig, auth: AuthClient, session: URLSession) {
        self.table = table
        self.config = config
        self.auth = auth
        self.urlSession = session
    }

    // MARK: - Selection

    @discardableResult public func select(_ columns: String = "*") -> Self {
        // Only flip to GET when no mutation has been chained. PostgREST accepts
        // ?select=... on POST/PATCH/DELETE to shape the returned representation,
        // so we must preserve the mutation method here.
        if !isMutating { method = "GET" }
        query.append(URLQueryItem(name: "select", value: columns))
        return self
    }

    // MARK: - Mutations

    @discardableResult public func insert(_ values: [String: Any]) -> Self { insert([values]) }
    @discardableResult public func insert(_ values: [[String: Any]]) -> Self {
        method = "POST"
        isMutating = true
        body = try? JSONSerialization.data(withJSONObject: values)
        if !prefer.contains("return=representation") { prefer.append("return=representation") }
        return self
    }

    @discardableResult public func update(_ values: [String: Any]) -> Self {
        method = "PATCH"
        isMutating = true
        body = try? JSONSerialization.data(withJSONObject: values)
        if !prefer.contains("return=representation") { prefer.append("return=representation") }
        return self
    }

    @discardableResult public func delete() -> Self {
        method = "DELETE"
        isMutating = true
        if !prefer.contains("return=representation") { prefer.append("return=representation") }
        return self
    }

    @discardableResult public func upsert(_ values: [[String: Any]], onConflict: String? = nil) -> Self {
        method = "POST"
        isMutating = true
        body = try? JSONSerialization.data(withJSONObject: values)
        if !prefer.contains("resolution=merge-duplicates") { prefer.append("resolution=merge-duplicates") }
        if !prefer.contains("return=representation") { prefer.append("return=representation") }
        if let onConflict { query.append(URLQueryItem(name: "on_conflict", value: onConflict)) }
        return self
    }

    // MARK: - Filters

    @discardableResult public func eq(_ column: String, _ value: Any) -> Self { filter(column, "eq", value) }
    @discardableResult public func neq(_ column: String, _ value: Any) -> Self { filter(column, "neq", value) }
    @discardableResult public func gt(_ column: String, _ value: Any) -> Self { filter(column, "gt", value) }
    @discardableResult public func gte(_ column: String, _ value: Any) -> Self { filter(column, "gte", value) }
    @discardableResult public func lt(_ column: String, _ value: Any) -> Self { filter(column, "lt", value) }
    @discardableResult public func lte(_ column: String, _ value: Any) -> Self { filter(column, "lte", value) }
    @discardableResult public func like(_ column: String, _ pattern: String) -> Self { filter(column, "like", pattern) }
    @discardableResult public func ilike(_ column: String, _ pattern: String) -> Self { filter(column, "ilike", pattern) }
    @discardableResult public func isNull(_ column: String) -> Self { filter(column, "is", "null") }
    @discardableResult public func `in`(_ column: String, _ values: [Any]) -> Self {
        let joined = values.map { "\($0)" }.joined(separator: ",")
        query.append(URLQueryItem(name: column, value: "in.(\(joined))"))
        return self
    }

    @discardableResult public func notIn(_ column: String, _ values: [Any]) -> Self {
        let joined = values.map { "\($0)" }.joined(separator: ",")
        query.append(URLQueryItem(name: column, value: "not.in.(\(joined))"))
        return self
    }

    @discardableResult public func rpc(_ params: [String: Any] = [:]) -> Self {
        method = "POST"
        isMutating = true
        body = try? JSONSerialization.data(withJSONObject: params)
        return self
    }

    private func filter(_ column: String, _ op: String, _ value: Any) -> Self {
        query.append(URLQueryItem(name: column, value: "\(op).\(value)"))
        return self
    }

    // MARK: - Ordering / paging

    @discardableResult public func order(_ column: String, ascending: Bool = true) -> Self {
        query.append(URLQueryItem(name: "order", value: "\(column).\(ascending ? "asc" : "desc")"))
        return self
    }

    @discardableResult public func limit(_ n: Int) -> Self {
        query.append(URLQueryItem(name: "limit", value: "\(n)")); return self
    }

    @discardableResult public func range(from: Int, to: Int) -> Self {
        prefer.append("count=exact")
        query.append(URLQueryItem(name: "offset", value: "\(from)"))
        query.append(URLQueryItem(name: "limit", value: "\(to - from + 1)"))
        return self
    }

    @discardableResult public func single() -> Self {
        prefer.append("return=representation"); _singleRow = true; return self
    }
    private var _singleRow = false

    // MARK: - Execution

    @discardableResult
    public func execute() async throws -> Data {
        let (data, _) = try await raw()
        return data
    }

    public func execute<T: Decodable>(decoding: T.Type = T.self) async throws -> T {
        let (data, _) = try await raw()
        let decoder = JSONDecoder.supabase()
        do { return try decoder.decode(T.self, from: data) }
        catch { throw InspectFlowError.decoding(error) }
    }

    private func raw() async throws -> (Data, HTTPURLResponse) {
        var comps = URLComponents(url: config.restURL.appendingPathComponent(table), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { comps.queryItems = query }
        var req = URLRequest(url: comps.url!)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        if let token = auth.currentSession?.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            req.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        }
        if _singleRow { req.setValue("application/vnd.pgrst.object+json", forHTTPHeaderField: "Accept") }
        if !prefer.isEmpty { req.setValue(prefer.joined(separator: ","), forHTTPHeaderField: "Prefer") }
        req.httpBody = body

        let (data, resp) = try await urlSession.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw InspectFlowError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw InspectFlowError.http(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        return (data, http)
    }
}
