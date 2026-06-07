import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import InspectFlowConnector
import XCTest

final class AuthRefreshTests: XCTestCase {
    private static let userID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testExpiredSessionRefreshesBeforeDatabaseRequest() async throws {
        let harness = try makeHarness(session: expiredSession(accessToken: "expired-token", refreshToken: "refresh-token"))

        MockURLProtocol.handler = { request in
            if request.url?.path == "/auth/v1/token" {
                XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), harness.config.anonKey)
                return Self.jsonResponse(
                    status: 200,
                    url: request.url!,
                    body: Self.sessionJSON(accessToken: "fresh-token", refreshToken: "refresh-token")
                )
            }

            XCTAssertEqual(request.url?.path, "/rest/v1/inspection_requests")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fresh-token")
            return Self.jsonResponse(status: 200, url: request.url!, body: "[]")
        }

        let rows: [EmptyRow] = try await harness.rest.from("inspection_requests")
            .select()
            .execute()

        XCTAssertTrue(rows.isEmpty)
        XCTAssertEqual(MockURLProtocol.requestPaths, ["/auth/v1/token", "/rest/v1/inspection_requests"])
    }

    func testJwtExpired401RefreshesAndRetriesAuthenticatedRequestOnce() async throws {
        let harness = try makeHarness(session: validSession(accessToken: "stale-token", refreshToken: "refresh-token"))
        var restAttempts = 0

        MockURLProtocol.handler = { request in
            if request.url?.path == "/auth/v1/token" {
                return Self.jsonResponse(
                    status: 200,
                    url: request.url!,
                    body: Self.sessionJSON(accessToken: "retry-token", refreshToken: "refresh-token")
                )
            }

            XCTAssertEqual(request.url?.path, "/rest/v1/jobs")
            restAttempts += 1
            if restAttempts == 1 {
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer stale-token")
                return Self.jsonResponse(
                    status: 401,
                    url: request.url!,
                    body: #"{"code":"PGRST303","message":"JWT expired"}"#
                )
            }

            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer retry-token")
            return Self.jsonResponse(status: 200, url: request.url!, body: "[]")
        }

        let rows: [EmptyRow] = try await harness.rest.from("jobs")
            .select()
            .execute()

        XCTAssertTrue(rows.isEmpty)
        XCTAssertEqual(restAttempts, 2)
        XCTAssertEqual(MockURLProtocol.requestPaths, ["/rest/v1/jobs", "/auth/v1/token", "/rest/v1/jobs"])
    }

    private func makeHarness(session: InspectFlowSession) throws -> (config: InspectFlowConfig, rest: RestClient) {
        let config = InspectFlowConfig(
            url: URL(string: "https://example.supabase.co")!,
            anonKey: "anon-key",
            keychainService: "AuthRefreshTests.\(UUID().uuidString)",
            keychainAccount: "session"
        )
        let store = SessionStore(config: config)
        try store.set(session)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let urlSession = URLSession(configuration: configuration)
        let auth = AuthClient(config: config, session: store, urlSession: urlSession)
        return (config, RestClient(config: config, auth: auth, urlSession: urlSession))
    }

    private func expiredSession(accessToken: String, refreshToken: String) -> InspectFlowSession {
        InspectFlowSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: Date().addingTimeInterval(-60),
            user: InspectFlowUser(id: Self.userID, email: "inspector@example.com", phone: nil)
        )
    }

    private func validSession(accessToken: String, refreshToken: String) -> InspectFlowSession {
        InspectFlowSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: Date().addingTimeInterval(3600),
            user: InspectFlowUser(id: Self.userID, email: "inspector@example.com", phone: nil)
        )
    }

    private static func sessionJSON(accessToken: String, refreshToken: String) -> String {
        """
        {
          "access_token": "\(accessToken)",
          "refresh_token": "\(refreshToken)",
          "expires_at": \(Int(Date().addingTimeInterval(3600).timeIntervalSince1970)),
          "user": {
            "id": "\(userID.uuidString)",
            "email": "inspector@example.com",
            "phone": null
          }
        }
        """
    }

    private static func jsonResponse(status: Int, url: URL, body: String) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (response, Data(body.utf8))
    }
}

private struct EmptyRow: Decodable {}

private final class MockURLProtocol: URLProtocol {
    typealias Handler = (URLRequest) throws -> (HTTPURLResponse, Data)

    static var handler: Handler?

    private static let lock = NSLock()
    private static var paths: [String] = []

    static var requestPaths: [String] {
        lock.lock(); defer { lock.unlock() }
        return paths
    }

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        handler = nil
        paths = []
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.paths.append(request.url?.path ?? "")
        let handler = Self.handler
        Self.lock.unlock()

        guard let handler else {
            client?.urlProtocol(self, didFailWithError: InspectFlowError.invalidResponse)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
