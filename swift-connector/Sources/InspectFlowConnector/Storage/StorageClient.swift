import Foundation

public final class StorageClient {
    private let config: InspectFlowConfig
    private let session: SessionStore
    private let urlSession: URLSession

    init(config: InspectFlowConfig, session: SessionStore, urlSession: URLSession = .shared) {
        self.config = config
        self.session = session
        self.urlSession = urlSession
    }

    public func upload(bucket: String, path: String, data: Data, contentType: String = "application/octet-stream", upsert: Bool = false) async throws {
        let url = config.storageURL.appendingPathComponent("object/\(bucket)/\(path)")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        req.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        if let token = session.current()?.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if upsert { req.setValue("true", forHTTPHeaderField: "x-upsert") }
        req.httpBody = data

        let (respData, resp) = try await urlSession.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw InspectFlowError.http(status: status, body: String(data: respData, encoding: .utf8) ?? "")
        }
    }

    public func createSignedURL(bucket: String, path: String, expiresIn seconds: Int = 3600) async throws -> URL {
        let url = config.storageURL.appendingPathComponent("object/sign/\(bucket)/\(path)")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        if let token = session.current()?.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: ["expiresIn": seconds])
        let (data, _) = try await urlSession.data(for: req)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let signed = obj?["signedURL"] as? String,
              let url = URL(string: signed, relativeTo: config.storageURL) else {
            throw InspectFlowError.invalidResponse
        }
        return url.absoluteURL
    }

    public func download(bucket: String, path: String) async throws -> Data {
        let url = config.storageURL.appendingPathComponent("object/\(bucket)/\(path)")
        var req = URLRequest(url: url)
        req.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        if let token = session.current()?.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, resp) = try await urlSession.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw InspectFlowError.http(status: (resp as? HTTPURLResponse)?.statusCode ?? -1,
                                       body: String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }
}
