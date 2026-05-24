import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public final class FunctionsClient {
    private let config: InspectFlowConfig
    private let session: SessionStore
    private let urlSession: URLSession

    init(config: InspectFlowConfig, session: SessionStore, urlSession: URLSession = .shared) {
        self.config = config
        self.session = session
        self.urlSession = urlSession
    }

    public func invoke<T: Decodable>(_ name: String, body: [String: Any]? = nil, decoding: T.Type = T.self) async throws -> T {
        let data = try await invokeRaw(name, body: body)
        let decoder = JSONDecoder.supabase()
        do { return try decoder.decode(T.self, from: data) }
        catch { throw InspectFlowError.decoding(error) }
    }

    public func invokeRaw(_ name: String, body: [String: Any]? = nil) async throws -> Data {
        var req = URLRequest(url: config.functionsURL.appendingPathComponent(name))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        if let token = session.current()?.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            req.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        }
        if let body { req.httpBody = try JSONSerialization.data(withJSONObject: body) }

        let (data, resp) = try await urlSession.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw InspectFlowError.http(status: (resp as? HTTPURLResponse)?.statusCode ?? -1,
                                       body: String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }
}
