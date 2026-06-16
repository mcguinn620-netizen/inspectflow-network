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

/// Minimal Supabase Realtime (Phoenix v2) client.
///
/// Sends the join with `access_token` in the payload so RLS-protected
/// `postgres_changes` actually deliver rows, and keeps the socket alive
/// with a `phx_heartbeat` every 25 s. On socket failure the heartbeat is
/// torn down and the next `send(_:)` reconnects.
public final class RealtimeClient {
    private let config: InspectFlowConfig
    private let session: SessionStore
    private var task: URLSessionWebSocketTask?
    private var heartbeat: Task<Void, Never>?
    private var channels: [String: RealtimeChannel] = [:]
    private let lock = NSLock()

    init(config: InspectFlowConfig, session: SessionStore) {
        self.config = config
        self.session = session
    }

    public func channel(_ topic: String) -> RealtimeChannel {
        lock.lock(); defer { lock.unlock() }
        if let existing = channels[topic] { return existing }
        let ch = RealtimeChannel(topic: topic, client: self)
        channels[topic] = ch
        return ch
    }

    func currentAccessToken() -> String? {
        session.current()?.accessToken
    }

    func connectIfNeeded() async throws -> URLSessionWebSocketTask {
        if let task, task.state == .running { return task }
        let task = URLSession.shared.webSocketTask(with: config.realtimeURL)
        task.resume()
        self.task = task
        startHeartbeat(task: task)
        Task { await self.receiveLoop(task: task) }
        return task
    }

    private func startHeartbeat(task: URLSessionWebSocketTask) {
        heartbeat?.cancel()
        heartbeat = Task { [weak self] in
            while !Task.isCancelled, task.state == .running {
                try? await Task.sleep(nanoseconds: 25_000_000_000)
                guard !Task.isCancelled, task.state == .running else { return }
                let payload: [String: Any] = [
                    "topic": "phoenix",
                    "event": "phx_heartbeat",
                    "payload": [:] as [String: Any],
                    "ref": UUID().uuidString
                ]
                if let data = try? JSONSerialization.data(withJSONObject: payload),
                   let str = String(data: data, encoding: .utf8) {
                    try? await task.send(.string(str))
                }
                _ = self // keep self alive
            }
        }
    }

    private func tearDownSocket() {
        heartbeat?.cancel()
        heartbeat = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    func send(_ payload: [String: Any]) async throws {
        let task = try await connectIfNeeded()
        let data = try JSONSerialization.data(withJSONObject: payload)
        let str = String(data: data, encoding: .utf8) ?? "{}"
        do {
            try await task.send(.string(str))
        } catch {
            tearDownSocket()
            throw error
        }
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
            } catch {
                tearDownSocket()
                return
            }
        }
        tearDownSocket()
    }

    /// Push a fresh access token to every joined channel after a refresh.
    public func updateAccessToken(_ token: String) async {
        let topics: [String]
        lock.lock()
        topics = Array(channels.keys)
        lock.unlock()
        for topic in topics {
            try? await send([
                "topic": "realtime:\(topic)",
                "event": "access_token",
                "payload": ["access_token": token],
                "ref": UUID().uuidString
            ])
        }
    }
}

public final class RealtimeChannel {
    public typealias Handler = ([String: Any]) -> Void

    let topic: String
    private weak var client: RealtimeClient?
    private var handlers: [(RealtimeEvent, String, Handler)] = []
    private var joined = false

    init(topic: String, client: RealtimeClient) {
        self.topic = topic
        self.client = client
    }

    public func onPostgresChange(event: RealtimeEvent, table: String, handler: @escaping Handler) {
        if joined {
            // Handlers registered after subscribe() were silently dropped before; log so it's visible.
            #if DEBUG
            print("[RealtimeChannel] onPostgresChange called after subscribe() on topic \(topic); rejoin required.")
            #endif
        }
        handlers.append((event, table, handler))
    }

    public func subscribe() async throws {
        guard let client else { return }
        let token = client.currentAccessToken()
        var payload: [String: Any] = [
            "config": [
                "postgres_changes": handlers.map {
                    ["event": $0.0.rawValue, "schema": "public", "table": $0.1]
                },
                "broadcast": ["ack": false, "self": false],
                "presence": ["key": ""]
            ]
        ]
        if let token { payload["access_token"] = token }

        try await client.send([
            "topic": "realtime:\(topic)",
            "event": "phx_join",
            "payload": payload,
            "ref": UUID().uuidString
        ])
        joined = true
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
