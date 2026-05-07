import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum RealtimeEvent: String {
    case insert = "INSERT"
    case update = "UPDATE"
    case delete = "DELETE"
    case all = "*"
}

/// Minimal Realtime client. For complex use cases, swap in `Realtime` from supabase-swift.
public final class RealtimeClient {
    private let config: InspectFlowConfig
    private let session: SessionStore
    private var task: URLSessionWebSocketTask?
    private var channels: [String: RealtimeChannel] = [:]

    init(config: InspectFlowConfig, session: SessionStore) {
        self.config = config
        self.session = session
    }

    public func channel(_ topic: String) -> RealtimeChannel {
        if let existing = channels[topic] { return existing }
        let ch = RealtimeChannel(topic: topic, client: self)
        channels[topic] = ch
        return ch
    }

    func connectIfNeeded() async throws -> URLSessionWebSocketTask {
        if let task, task.state == .running { return task }
        let task = URLSession.shared.webSocketTask(with: config.realtimeURL)
        task.resume()
        self.task = task
        Task { await self.receiveLoop(task: task) }
        return task
    }

    func send(_ payload: [String: Any]) async throws {
        let task = try await connectIfNeeded()
        let data = try JSONSerialization.data(withJSONObject: payload)
        let str = String(data: data, encoding: .utf8) ?? "{}"
        try await task.send(.string(str))
    }

    private func receiveLoop(task: URLSessionWebSocketTask) async {
        while task.state == .running {
            do {
                let msg = try await task.receive()
                if case .string(let s) = msg,
                   let data = s.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let topic = obj["topic"] as? String,
                   let channel = channels[topic.replacingOccurrences(of: "realtime:", with: "")] {
                    channel.handle(payload: obj)
                }
            } catch { return }
        }
    }
}

public final class RealtimeChannel {
    public typealias Handler = ([String: Any]) -> Void

    let topic: String
    private weak var client: RealtimeClient?
    private var handlers: [(RealtimeEvent, String, Handler)] = []

    init(topic: String, client: RealtimeClient) {
        self.topic = topic
        self.client = client
    }

    public func onPostgresChange(event: RealtimeEvent, table: String, handler: @escaping Handler) {
        handlers.append((event, table, handler))
    }

    public func subscribe() async throws {
        try await client?.send([
            "topic": "realtime:\(topic)",
            "event": "phx_join",
            "payload": ["config": ["postgres_changes": handlers.map { ["event": $0.0.rawValue, "schema": "public", "table": $0.1] }]],
            "ref": UUID().uuidString
        ])
    }

    func handle(payload: [String: Any]) {
        guard let data = payload["payload"] as? [String: Any],
              let eventStr = data["type"] as? String,
              let table = (data["table"] as? String) else { return }
        for (event, t, handler) in handlers where (event == .all || event.rawValue == eventStr) && t == table {
            handler(data)
        }
    }
}
