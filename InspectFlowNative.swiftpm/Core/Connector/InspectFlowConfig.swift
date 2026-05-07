import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct InspectFlowConfig {
    public let url: URL
    public let anonKey: String
    public let keychainService: String
    public let keychainAccount: String

    public init(
        url: URL,
        anonKey: String,
        keychainService: String = "com.inspectflow.connector",
        keychainAccount: String = "session"
    ) {
        self.url = url
        self.anonKey = anonKey
        self.keychainService = keychainService
        self.keychainAccount = keychainAccount
    }

    var restURL: URL { url.appendingPathComponent("rest/v1") }
    var authURL: URL { url.appendingPathComponent("auth/v1") }
    var functionsURL: URL { url.appendingPathComponent("functions/v1") }
    var storageURL: URL { url.appendingPathComponent("storage/v1") }
    var realtimeURL: URL {
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        comps.scheme = (comps.scheme == "https") ? "wss" : "ws"
        comps.path = "/realtime/v1/websocket"
        comps.queryItems = [URLQueryItem(name: "apikey", value: anonKey), URLQueryItem(name: "vsn", value: "1.0.0")]
        return comps.url!
    }
}
