import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public final class AuthClient {
    private let config: InspectFlowConfig
    private let session: SessionStore
    private let urlSession: URLSession

    init(config: InspectFlowConfig, session: SessionStore, urlSession: URLSession = .shared) {
        self.config = config
        self.session = session
        self.urlSession = urlSession
    }

    public var currentSession: InspectFlowSession? { session.current() }
    public var currentUser: InspectFlowUser? { session.current()?.user }

    public func signUp(email: String, password: String, metadata: [String: Any]? = nil) async throws -> InspectFlowSession {
        var body: [String: Any] = ["email": email, "password": password]
        if let metadata { body["data"] = metadata }
        return try await post("/signup", body: body, query: nil)
    }

    public func signIn(email: String, password: String) async throws -> InspectFlowSession {
        try await post("/token",
                       body: ["email": email, "password": password],
                       query: [URLQueryItem(name: "grant_type", value: "password")])
    }

    public func signInWithOTP(phone: String) async throws {
        _ = try await postRaw("/otp", body: ["phone": phone], query: nil)
    }

    public func verifyOTP(phone: String, token: String) async throws -> InspectFlowSession {
        try await post("/verify",
                       body: ["phone": phone, "token": token, "type": "sms"],
                       query: nil)
    }

    public func refresh() async throws -> InspectFlowSession {
        guard let s = session.current() else { throw InspectFlowError.notAuthenticated }
        do {
            let refreshed = try await post("/token",
                                           body: ["refresh_token": s.refreshToken],
                                           query: [URLQueryItem(name: "grant_type", value: "refresh_token")])
            debugAuthLog("[AUTH] Session refreshed")
            return refreshed
        } catch {
            debugAuthLog("[AUTH] Refresh failed")
            throw error
        }
    }

    public func signOut() async throws {
        guard session.current() != nil else { return }
        let token = try? await validAccessToken()
        var req = URLRequest(url: config.authURL.appendingPathComponent("logout"))
        req.httpMethod = "POST"
        req.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token ?? config.anonKey)", forHTTPHeaderField: "Authorization")
        _ = try? await urlSession.data(for: req)
        try session.set(nil)
    }

    /// Returns a valid access token, refreshing if expired.
    public func validAccessToken() async throws -> String {
        guard let s = session.current() else { throw InspectFlowError.notAuthenticated }
        if s.expiresAt.timeIntervalSinceNow > 60 { return s.accessToken }
        return try await refresh().accessToken
    }

    /// Restores and validates the persisted session without signing the user out on refresh failure.
    @discardableResult
    public func restoreAndValidateSession() async throws -> InspectFlowSession {
        guard session.current() != nil else { throw InspectFlowError.notAuthenticated }
        debugAuthLog("[AUTH] Session restored")
        _ = try await validAccessToken()
        guard let current = session.current() else { throw InspectFlowError.notAuthenticated }
        return current
    }

    public func bearerTokenForAuthenticatedRequest() async throws -> String? {
        guard session.current() != nil else { return nil }
        return try await validAccessToken()
    }

    public func refreshAccessTokenForRetry() async throws -> String {
        try await refresh().accessToken
    }

    public func shouldRetryAfterRefreshing(status: Int, body: String) -> Bool {
        status == 401 && (body.contains("PGRST303") || body.localizedCaseInsensitiveContains("JWT expired"))
    }

    public func logRetryingAfterJWTRefresh() {
        debugAuthLog("[AUTH] Retrying request after JWT refresh")
    }

    // MARK: - Private

    private func debugAuthLog(_ message: String) {
        #if DEBUG
        print(message)
        #endif
    }

    @discardableResult
    private func post(_ path: String, body: [String: Any], query: [URLQueryItem]?) async throws -> InspectFlowSession {
        let data = try await postRaw(path, body: body, query: query)
        let decoded = try JSONDecoder().decode(InspectFlowSession.self, from: data)
        try session.set(decoded)
        return decoded
    }

    private func postRaw(_ path: String, body: [String: Any], query: [URLQueryItem]?) async throws -> Data {
        var comps = URLComponents(url: config.authURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if let query { comps.queryItems = query }
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await urlSession.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw InspectFlowError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw InspectFlowError.http(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }
}
