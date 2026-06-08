import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public final class AuthClient {
    private let config: InspectFlowConfig
    private let session: SessionStore
    private let urlSession: URLSession

    /// Single in-flight refresh task — coalesces concurrent refresh attempts so
    /// the (single-use) refresh token is not burned by parallel tab loads.
    private let refreshLock = NSLock()
    private var inflightRefresh: Task<InspectFlowSession, Error>?

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

    /// Refresh the access token. Coalesces concurrent callers so the refresh
    /// token is only spent once. On hard refresh failure (`invalid_grant`,
    /// `refresh_token_not_found`, 4xx auth error), the session is cleared and
    /// `.notAuthenticated` is thrown so the UI can route to sign-in.
    public func refresh() async throws -> InspectFlowSession {
        refreshLock.lock()
        if let task = inflightRefresh {
            refreshLock.unlock()
            return try await task.value
        }
        let task = Task<InspectFlowSession, Error> { [weak self] in
            guard let self else { throw InspectFlowError.notAuthenticated }
            defer {
                self.refreshLock.lock()
                self.inflightRefresh = nil
                self.refreshLock.unlock()
            }
            guard let s = self.session.current() else { throw InspectFlowError.notAuthenticated }
            do {
                let refreshed = try await self.post("/token",
                                                    body: ["refresh_token": s.refreshToken],
                                                    query: [URLQueryItem(name: "grant_type", value: "refresh_token")])
                self.debugAuthLog("[AUTH] Session refreshed")
                return refreshed
            } catch let InspectFlowError.http(status, body) {
                self.debugAuthLog("[AUTH] Refresh failed status=\(status) body=\(body.prefix(180))")
                let bodyLower = body.lowercased()
                let hardFailure = (400...401).contains(status)
                    || bodyLower.contains("invalid_grant")
                    || bodyLower.contains("refresh_token_not_found")
                    || bodyLower.contains("refresh token")
                if hardFailure {
                    try? self.session.set(nil)
                    throw InspectFlowError.notAuthenticated
                }
                throw InspectFlowError.http(status: status, body: body)
            } catch {
                self.debugAuthLog("[AUTH] Refresh failed: \(error)")
                throw error
            }
        }
        inflightRefresh = task
        refreshLock.unlock()
        return try await task.value
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

    /// Returns a valid access token, refreshing if it expires within the skew
    /// window (120s) or has already expired.
    public func validAccessToken() async throws -> String {
        guard let s = session.current() else { throw InspectFlowError.notAuthenticated }
        if s.expiresAt.timeIntervalSinceNow > 120 { return s.accessToken }
        return try await refresh().accessToken
    }

    /// Restores and validates the persisted session. On hard-refresh failure the
    /// underlying session is cleared by `refresh()` and `.notAuthenticated` bubbles up.
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
