import Foundation

final class DatabaseQueryBuilder {
    private let table: String
    private let config: SupabaseConfig
    private let session: URLSession

    private var method = "GET"
    private var query: [URLQueryItem] = []
    private var body: Data?
    private var prefer: [String] = []
    private var singleRow = false

    init(table: String, config: SupabaseConfig, session: URLSession) {
        self.table = table
        self.config = config
        self.session = session
    }

    @discardableResult
    func select(_ columns: String = "*") -> Self {
        method = "GET"
        query.append(URLQueryItem(name: "select", value: columns))
        return self
    }

    @discardableResult
    func insert(_ values: [String: Any]) -> Self {
        insert([values])
    }

    @discardableResult
    func insert(_ values: [[String: Any]]) -> Self {
        method = "POST"
        body = try? JSONSerialization.data(withJSONObject: values)
        prefer.append("return=representation")
        return self
    }

    @discardableResult
    func update(_ values: [String: Any]) -> Self {
        method = "PATCH"
        body = try? JSONSerialization.data(withJSONObject: values)
        prefer.append("return=representation")
        return self
    }

    @discardableResult
    func delete() -> Self {
        method = "DELETE"
        prefer.append("return=representation")
        return self
    }

    @discardableResult
    func eq(_ column: String, _ value: Any) -> Self {
        query.append(URLQueryItem(name: column, value: "eq.\(value)"))
        return self
    }

    @discardableResult
    func order(_ column: String, ascending: Bool = true) -> Self {
        query.append(URLQueryItem(name: "order", value: "\(column).\(ascending ? "asc" : "desc")"))
        return self
    }

    @discardableResult
    func limit(_ count: Int) -> Self {
        query.append(URLQueryItem(name: "limit", value: "\(count)"))
        return self
    }

    @discardableResult
    func single() -> Self {
        singleRow = true
        prefer.append("return=representation")
        return self
    }

    func execute() async throws -> Data {
        let (data, _) = try await raw()
        return data
    }

    func execute<T: Decodable>() async throws -> [T] {
        let (data, _) = try await raw()
        return try JSONDecoder.supabase.decode([T].self, from: data)
    }

    private func raw() async throws -> (Data, HTTPURLResponse) {
        let endpoint = config.url.appending(path: "rest/v1").appendingPathComponent(table)
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        if !query.isEmpty {
            components?.queryItems = query
        }

        guard let url = components?.url else {
            throw SupabaseError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        let accessToken = (try? KeychainStore.shared.readSession()?.accessToken) ?? config.anonKey
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        if singleRow {
            request.setValue("application/vnd.pgrst.object+json", forHTTPHeaderField: "Accept")
        }
        if !prefer.isEmpty {
            request.setValue(prefer.joined(separator: ","), forHTTPHeaderField: "Prefer")
        }
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw SupabaseError.serverError(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        return (data, http)
    }
}

private extension JSONDecoder {
    static var supabase: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
