import Foundation
import Network
import InspectFlowConnector

@MainActor
final class SyncEngine: ObservableObject {
    enum State: String { case idle, syncing, offline, failed }

    @Published var state: State = .idle
    @Published var lastSyncedAt: Date?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "ain.sync.network.monitor")
    private var isOnline = true
    private var draining = false

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                self.isOnline = path.status == .satisfied
                if self.isOnline {
                    if self.state == .offline { self.state = .idle }
                    await self.drainOutbox()
                } else {
                    self.state = .offline
                }
            }
        }
        monitor.start(queue: queue)
    }

    /// Manually trigger a drain (called after enqueue, on app foreground, on BGAppRefreshTask).
    func runSync() async {
        guard isOnline else { state = .offline; return }
        await drainOutbox()
    }

    // MARK: - Drain

    private func drainOutbox() async {
        guard !draining else { return }
        draining = true
        defer { draining = false }

        let client = SupabaseClientProvider.shared
        state = .syncing

        var hadFailure = false

        while let entry = Outbox.shared.nextDrainable() {
            do {
                try await execute(entry: entry, client: client)
                Outbox.shared.remove(id: entry.id)
            } catch {
                hadFailure = true
                Outbox.shared.mutate(id: entry.id) { e in
                    e.attemptCount += 1
                    e.lastError = String(describing: error)
                }
                // Backoff: stop draining when an entry fails; rely on next trigger.
                let backoff = min(60, Int(pow(2.0, Double(entry.attemptCount + 1))))
                try? await Task.sleep(nanoseconds: UInt64(backoff) * 1_000_000_000)
                break
            }
        }

        lastSyncedAt = Date()
        state = hadFailure ? .failed : .idle
    }

    private func execute(entry: OutboxEntry, client: InspectFlowClient) async throws {
        // Decode JSON payload back into a generic dictionary or array of dictionaries.
        let json = try JSONSerialization.jsonObject(with: entry.payload, options: [])
        let table = client.db.from(entry.table)

        switch entry.op {
        case .insert:
            if let arr = json as? [[String: Any]] {
                _ = try await table.insert(arr).execute()
            } else if let dict = json as? [String: Any] {
                _ = try await table.insert(dict).execute()
            }
        case .upsert:
            if let arr = json as? [[String: Any]] {
                _ = try await table.upsert(arr).execute()
            } else if let dict = json as? [String: Any] {
                _ = try await table.upsert([dict]).execute()
            }
        case .update:
            guard let dict = json as? [String: Any],
                  let col = entry.matchColumn,
                  let val = entry.matchValue else { return }
            _ = try await table.update(dict).eq(col, val).execute()
        case .delete:
            guard let col = entry.matchColumn, let val = entry.matchValue else { return }
            _ = try await table.delete().eq(col, val).execute()
        }
    }
}
