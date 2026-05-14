import Foundation

/// Mirrors `src/lib/tripTracking.ts` filters and persistence behavior.
@MainActor
public final class TripTrackingController: ObservableObject {
    public enum Status: String, Codable { case idle, live, paused }

    public struct Snapshot: Codable, Equatable {
        public var tripId: UUID
        public var organizationId: UUID
        public var userId: UUID
        public var status: Status
        public var totalMiles: Double
        public var lastPointAt: Date?
    }

    public static let shared = TripTrackingController()

    @Published public private(set) var snapshot: Snapshot?

    // Filter constants matching the web implementation.
    private let minAccuracyMeters: Double = 75
    private let minMovementMeters: Double = 10
    private let maxMph: Double = 110
    private let maxGapSeconds: Double = 60 * 12
    private let flushBatchSize: Int = 8
    private let flushIntervalSec: Double = 6

    private var pointBuffer: [[String: Any]] = []
    private var lastWritten: LocationSample?
    private var flushTask: Task<Void, Never>?

    private let snapshotURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("ain-trip-snapshot.json")
    }()

    private init() {
        loadSnapshot()
    }

    // MARK: - Persistence

    private func loadSnapshot() {
        guard let data = try? Data(contentsOf: snapshotURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        snapshot = try? decoder.decode(Snapshot.self, from: data)
    }

    private func persistSnapshot() {
        guard let snapshot else {
            try? FileManager.default.removeItem(at: snapshotURL)
            return
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(snapshot) {
            try? data.write(to: snapshotURL, options: .atomic)
        }
    }

    // MARK: - Public API

    public func start(tripId: UUID, organizationId: UUID, userId: UUID, totalMiles: Double = 0) {
        snapshot = Snapshot(
            tripId: tripId,
            organizationId: organizationId,
            userId: userId,
            status: .live,
            totalMiles: totalMiles,
            lastPointAt: nil
        )
        persistSnapshot()
        LocationTracker.shared.start { [weak self] sample in
            Task { @MainActor in self?.handle(sample: sample) }
        }
    }

    public func pause() {
        guard var snap = snapshot else { return }
        snap.status = .paused
        snapshot = snap
        persistSnapshot()
        LocationTracker.shared.stop()
        flush()
    }

    public func resume() {
        guard var snap = snapshot else { return }
        snap.status = .live
        snapshot = snap
        persistSnapshot()
        LocationTracker.shared.start { [weak self] sample in
            Task { @MainActor in self?.handle(sample: sample) }
        }
    }

    public func stop() {
        LocationTracker.shared.stop()
        flush()
        snapshot = nil
        lastWritten = nil
        pointBuffer.removeAll()
        persistSnapshot()
    }

    public func restoreIfNeeded() {
        guard let snap = snapshot, snap.status == .live else { return }
        LocationTracker.shared.start { [weak self] sample in
            Task { @MainActor in self?.handle(sample: sample) }
        }
    }

    // MARK: - Filters & geometry

    private func haversineMiles(_ a: (Double, Double), _ b: (Double, Double)) -> Double {
        let toRad = { (n: Double) in n * .pi / 180 }
        let R = 3958.7613
        let dLat = toRad(b.0 - a.0)
        let dLon = toRad(b.1 - a.1)
        let lat1 = toRad(a.0); let lat2 = toRad(b.0)
        let h = sin(dLat/2)*sin(dLat/2) + cos(lat1)*cos(lat2)*sin(dLon/2)*sin(dLon/2)
        return 2 * R * asin(sqrt(h))
    }

    private func meters(_ a: LocationSample, _ b: LocationSample) -> Double {
        haversineMiles((a.latitude, a.longitude), (b.latitude, b.longitude)) * 1609.344
    }

    private func shouldRecord(_ s: LocationSample) -> Bool {
        if let acc = s.accuracy, acc > minAccuracyMeters { return false }
        guard let last = lastWritten else { return true }
        let dt = abs(s.timestamp.timeIntervalSince(last.timestamp))
        if dt < 1.5 && meters(last, s) < 3 { return false }
        let dtH = max(s.timestamp.timeIntervalSince(last.timestamp) / 3600, 0.0001)
        let miles = haversineMiles((last.latitude, last.longitude), (s.latitude, s.longitude))
        if dt <= maxGapSeconds && (miles / dtH) > maxMph { return false }
        return meters(last, s) >= minMovementMeters
    }

    // MARK: - Update handler

    private func handle(sample: LocationSample) {
        guard var snap = snapshot, snap.status == .live else { return }
        guard shouldRecord(sample) else { return }

        let distanceMiles: Double = {
            guard let last = lastWritten else { return 0 }
            return haversineMiles((last.latitude, last.longitude), (sample.latitude, sample.longitude))
        }()

        snap.totalMiles += distanceMiles
        snap.lastPointAt = sample.timestamp
        snapshot = snap
        persistSnapshot()

        let row: [String: Any] = [
            "trip_id": snap.tripId.uuidString,
            "organization_id": snap.organizationId.uuidString,
            "user_id": snap.userId.uuidString,
            "latitude": sample.latitude,
            "longitude": sample.longitude,
            "accuracy": sample.accuracy as Any,
            "speed": sample.speed as Any,
            "heading": sample.heading as Any,
            "distance_from_previous_miles": distanceMiles,
            "recorded_at": ISO8601DateFormatter().string(from: sample.timestamp),
        ]
        pointBuffer.append(row)
        lastWritten = sample

        // Update trips.total_miles via outbox so it persists offline.
        let updatePayload = (try? JSONSerialization.data(withJSONObject: ["total_miles": snap.totalMiles])) ?? Data()
        Outbox.shared.enqueueRaw(
            table: "trips",
            op: .update,
            payload: updatePayload,
            matchColumn: "id",
            matchValue: snap.tripId.uuidString
        )

        if pointBuffer.count >= flushBatchSize {
            flush()
        } else {
            scheduleFlush()
        }
    }

    private func scheduleFlush() {
        flushTask?.cancel()
        flushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((self?.flushIntervalSec ?? 6) * 1_000_000_000))
            await MainActor.run { self?.flush() }
        }
    }

    private func flush() {
        guard !pointBuffer.isEmpty else { return }
        let chunk = pointBuffer
        pointBuffer.removeAll()
        let data = (try? JSONSerialization.data(withJSONObject: chunk)) ?? Data()
        Outbox.shared.enqueueRaw(table: "trip_location_points", op: .insert, payload: data)
    }
}
