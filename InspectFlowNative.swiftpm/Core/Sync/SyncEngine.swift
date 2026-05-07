import Foundation
import Network

@MainActor
final class SyncEngine: ObservableObject {
    enum State: String {
        case idle, syncing, offline, failed
    }

    @Published var state: State = .idle
    @Published var lastSyncedAt: Date?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "sync.network.monitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                if path.status == .satisfied {
                    await self.runSync()
                } else {
                    self.state = .offline
                }
            }
        }
        monitor.start(queue: queue)
    }

    func runSync() async {
        state = .syncing
        // TODO: pull latest tables, push mutation queue.
        try? await Task.sleep(nanoseconds: 250_000_000)
        lastSyncedAt = Date()
        state = .idle
    }
}
