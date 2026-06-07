import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public final class StorageClient {
    private let config: InspectFlowConfig
    private let auth: AuthClient
    private let urlSession: URLSession

    init(config: InspectFlowConfig, auth: AuthClient, urlSession: URLSession = .shared) {
        self.config = config
        self.auth = auth
        self.urlSession = urlSession
    }

    public func upload(bucket: String, path: String, data: Data, contentType: String = "application/octet-stream", upsert: Bool = false) async throws {
        let url = config.storageURL.appendingPathComponent("object/\(bucket)/\(path)")
        let token = try await auth.bearerTokenForAuthenticatedRequest()
        let result = try await sendRequest(url: url, method: "POST", contentType: contentType, accessToken: token, body: data) { req in
            if upsert { req.setValue("true", forHTTPHeaderField: "x-upsert") }
        }
        guard auth.shouldRetryAfterRefreshing(status: result.http.statusCode, body: result.body) else {
            guard (200..<300).contains(result.http.statusCode) else {
                throw InspectFlowError.http(status: result.http.statusCode, body: result.body)
            }
            return
        }

        let refreshedToken = try await auth.refreshAccessTokenForRetry()
        auth.logRetryingAfterJWTRefresh()
        let retry = try await sendRequest(url: url, method: "POST", contentType: contentType, accessToken: refreshedToken, body: data) { req in
            if upsert { req.setValue("true", forHTTPHeaderField: "x-upsert") }
        }
        guard (200..<300).contains(retry.http.statusCode) else {
            throw InspectFlowError.http(status: retry.http.statusCode, body: retry.body)
        }
    }

    public func createSignedURL(bucket: String, path: String, expiresIn seconds: Int = 3600) async throws -> URL {
        let url = config.storageURL.appendingPathComponent("object/sign/\(bucket)/\(path)")
        let body = try JSONSerialization.data(withJSONObject: ["expiresIn": seconds])
        let token = try await auth.bearerTokenForAuthenticatedRequest()
        let result = try await sendRequest(url: url, method: "POST", contentType: "application/json", accessToken: token, body: body)
        let data: Data
        if auth.shouldRetryAfterRefreshing(status: result.http.statusCode, body: result.body) {
            let refreshedToken = try await auth.refreshAccessTokenForRetry()
            auth.logRetryingAfterJWTRefresh()
            let retry = try await sendRequest(url: url, method: "POST", contentType: "application/json", accessToken: refreshedToken, body: body)
            guard (200..<300).contains(retry.http.statusCode) else {
                throw InspectFlowError.http(status: retry.http.statusCode, body: retry.body)
            }
            data = retry.data
        } else {
            guard (200..<300).contains(result.http.statusCode) else {
                throw InspectFlowError.http(status: result.http.statusCode, body: result.body)
            }
            data = result.data
        }

        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let signed = obj?["signedURL"] as? String,
              let url = URL(string: signed, relativeTo: config.storageURL) else {
            throw InspectFlowError.invalidResponse
        }
        return url.absoluteURL
    }

    public func download(bucket: String, path: String) async throws -> Data {
        let url = config.storageURL.appendingPathComponent("object/\(bucket)/\(path)")
        let token = try await auth.bearerTokenForAuthenticatedRequest()
        let result = try await sendRequest(url: url, method: "GET", accessToken: token)
        guard auth.shouldRetryAfterRefreshing(status: result.http.statusCode, body: result.body) else {
            guard (200..<300).contains(result.http.statusCode) else {
                throw InspectFlowError.http(status: result.http.statusCode, body: result.body)
            }
            return result.data
        }

        let refreshedToken = try await auth.refreshAccessTokenForRetry()
        auth.logRetryingAfterJWTRefresh()
        let retry = try await sendRequest(url: url, method: "GET", accessToken: refreshedToken)
        guard (200..<300).contains(retry.http.statusCode) else {
            throw InspectFlowError.http(status: retry.http.statusCode, body: retry.body)
        }
        return retry.data
    }

    private func sendRequest(
        url: URL,
        method: String,
        contentType: String? = nil,
        accessToken: String?,
        body: Data? = nil,
        configure: ((inout URLRequest) -> Void)? = nil
    ) async throws -> (data: Data, http: HTTPURLResponse, body: String) {
        var req = URLRequest(url: url)
        req.httpMethod = method
        if let contentType { req.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        req.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(accessToken ?? config.anonKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = body
        configure?(&req)

        let (data, resp) = try await urlSession.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw InspectFlowError.invalidResponse }
        return (data, http, String(data: data, encoding: .utf8) ?? "")
    }
}
