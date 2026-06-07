import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public final class FunctionsClient {
    private let config: InspectFlowConfig
    private let auth: AuthClient
    private let urlSession: URLSession

    init(config: InspectFlowConfig, auth: AuthClient, urlSession: URLSession = .shared) {
        self.config = config
        self.auth = auth
        self.urlSession = urlSession
    }

    public func invoke<T: Decodable>(_ name: String, body: [String: Any]? = nil, decoding: T.Type = T.self) async throws -> T {
        let data = try await invokeRaw(name, body: body)
        let decoder = JSONDecoder.supabase()
        do { return try decoder.decode(T.self, from: data) }
        catch { throw InspectFlowError.decoding(error) }
    }

    public func invokeRaw(_ name: String, body: [String: Any]? = nil) async throws -> Data {
        let requestBody = try body.map { try JSONSerialization.data(withJSONObject: $0) }
        let token = try await auth.bearerTokenForAuthenticatedRequest()
        let result = try await sendRequest(name: name, body: requestBody, accessToken: token)
        guard auth.shouldRetryAfterRefreshing(status: result.http.statusCode, body: result.body) else {
            guard (200..<300).contains(result.http.statusCode) else {
                throw InspectFlowError.http(status: result.http.statusCode, body: result.body)
            }
            return result.data
        }

        let refreshedToken = try await auth.refreshAccessTokenForRetry()
        auth.logRetryingAfterJWTRefresh()
        let retry = try await sendRequest(name: name, body: requestBody, accessToken: refreshedToken)
        guard (200..<300).contains(retry.http.statusCode) else {
            throw InspectFlowError.http(status: retry.http.statusCode, body: retry.body)
        }
        return retry.data
    }

    private func sendRequest(name: String, body: Data?, accessToken: String?) async throws -> (data: Data, http: HTTPURLResponse, body: String) {
        var req = URLRequest(url: config.functionsURL.appendingPathComponent(name))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(accessToken ?? config.anonKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = body

        let (data, resp) = try await urlSession.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw InspectFlowError.invalidResponse }
        return (data, http, String(data: data, encoding: .utf8) ?? "")
    }
}
