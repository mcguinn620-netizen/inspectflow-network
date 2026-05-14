import Foundation

/// Helper to attach typed realtime listeners to feature view-models.
/// Each subscription is bound to a topic and torn down on `cancel()`.
@MainActor
public final class RealtimeSubscription {
    private let channel: RealtimeChannel
    private var cancelled = false

    init(channel: RealtimeChannel) { self.channel = channel }

    public func cancel() {
        cancelled = true
        // Connector currently has no per-channel unsubscribe; no-op to keep symmetry.
    }
}

@MainActor
public enum RealtimeSubscriptions {
    public static func inspectionRequests(orgId: UUID, onChange: @escaping ([String: Any]) -> Void) async -> RealtimeSubscription {
        let client = SupabaseClientProvider.shared
        let topic = "ain:inspections:\(orgId.uuidString)"
        let ch = client.realtime.channel(topic)
        ch.onPostgresChange(event: .all, table: "inspection_requests", handler: onChange)
        try? await ch.subscribe()
        return RealtimeSubscription(channel: ch)
    }

    public static func jobs(orgId: UUID, onChange: @escaping ([String: Any]) -> Void) async -> RealtimeSubscription {
        let client = SupabaseClientProvider.shared
        let topic = "ain:jobs:\(orgId.uuidString)"
        let ch = client.realtime.channel(topic)
        ch.onPostgresChange(event: .all, table: "jobs", handler: onChange)
        try? await ch.subscribe()
        return RealtimeSubscription(channel: ch)
    }

    public static func trips(userId: UUID, onChange: @escaping ([String: Any]) -> Void) async -> RealtimeSubscription {
        let client = SupabaseClientProvider.shared
        let topic = "ain:trips:\(userId.uuidString)"
        let ch = client.realtime.channel(topic)
        ch.onPostgresChange(event: .all, table: "trips", handler: onChange)
        try? await ch.subscribe()
        return RealtimeSubscription(channel: ch)
    }
}
