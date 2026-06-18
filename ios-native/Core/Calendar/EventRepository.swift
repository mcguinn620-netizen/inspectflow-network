import Foundation
import EventKit

/// Repository that owns all event reads/writes for the Schedule feature.
///
/// `ScheduleViewModel` talks only to this repository (and `CalendarRepository`),
/// never to `EventKitService` directly. The repository:
/// - Fetches events for a window using a visible-calendar filter.
/// - Creates/updates/deletes events with paired metadata side effects.
/// - Emits a debounced `AsyncStream` of change notifications fanned out from
///   `EKEventStoreChanged`, so observers can refresh once per burst.
@MainActor
public final class EventRepository: ObservableObject {
    
    public static let shared = EventRepository()
    
    private let service: EventKitService
    private let calendars: CalendarRepository
    private let metadata: ScheduleMetadataStore
    
    /// Debounce window for fan-out of EK change notifications.
    private let debounce: Duration
    
    private var continuations: [UUID: AsyncStream<Void>.Continuation] = [:]
    private var changeTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    
    // MARK: - Caches (Phase 6)
    
    private struct EventCacheKey: Hashable {
        let start: Date
        let end: Date
        let visibleOnly: Bool
    }
    private var eventCache: [EventCacheKey: [EKEvent]] = [:]
    private var metadataCache: [String: EventMetadata] = [:]
    private var metadataCacheLoaded = false
    
    internal init(
        service: EventKitService = .shared,
        calendars: CalendarRepository = .shared,
        metadata: ScheduleMetadataStore = ScheduleMetadataStoreFactory.make(),
        debounceMilliseconds: Int = 250
    ) {
        self.service = service
        self.calendars = calendars
        self.metadata = metadata
        self.debounce = .milliseconds(debounceMilliseconds)
        
        changeTask = Task { [weak self] in
            guard let self else { return }
            for await _ in self.service.changes() {
                self.invalidateCaches()
                self.scheduleDebouncedBroadcast()
            }
        }
    }
    
    /// Drops all in-memory caches. Called automatically on EK change events
    /// and exposed for explicit refresh from tests/UI.
    public func invalidateCaches() {
        eventCache.removeAll(keepingCapacity: true)
        metadataCache.removeAll(keepingCapacity: true)
        metadataCacheLoaded = false
    }
    
    deinit {
        changeTask?.cancel()
        debounceTask?.cancel()
    }
    
    // MARK: - Access
    
    public var hasAccess: Bool { service.hasAccess }
    
    public func requestAccess() async -> Bool {
        await service.requestAccess()
    }
    
    // MARK: - Fetch
    
    /// Loads events in `interval`. If `visibleOnly` is true, hidden calendars
    /// (per `CalendarRepository`) are excluded.
    public func events(in interval: DateInterval, visibleOnly: Bool = true) -> [EKEvent] {
        guard service.hasAccess else { return [] }
        let key = EventCacheKey(start: interval.start, end: interval.end, visibleOnly: visibleOnly)
        if let cached = eventCache[key] { return cached }
        let cals: [EKCalendar]? = visibleOnly ? calendars.visibleCalendars() : nil
        let loaded = service.events(in: interval, calendars: cals)
        eventCache[key] = loaded
        return loaded
    }
    
    public func event(matching identity: EventIdentity) -> EKEvent? {
        identity.resolve(in: service.store)
    }
    
    // MARK: - Metadata
    
    public func metadata(for event: EKEvent) async -> EventMetadata? {
        let identity = EventIdentity(event: event)
        if let eventID = identity.eventIdentifier, let cached = metadataCache[eventID] {
            return cached
        }
        if let externalID = identity.externalID,
           let found = try? await metadata.metadata(forExternalID: externalID) {
            if let id = identity.eventIdentifier { metadataCache[id] = found }
            return found
        }
        if let eventID = identity.eventIdentifier,
           let found = try? await metadata.metadata(for: eventID) {
            metadataCache[eventID] = found
            return found
        }
        return nil
    }
    
    public func allMetadata() async -> [EventMetadata] {
        if metadataCacheLoaded {
            return Array(metadataCache.values)
        }
        let list = (try? await metadata.allMetadata()) ?? []
        metadataCache = Dictionary(uniqueKeysWithValues: list.map { ($0.eventID, $0) })
        metadataCacheLoaded = true
        return list
    }
    
    /// Upserts metadata with deterministic conflict resolution against any
    /// existing record for the same logical event.
    @discardableResult
    public func upsertMetadata(_ incoming: EventMetadata) async throws -> EventMetadata {
        var next = incoming
        next.updatedAt = Date()
        
        let existing: EventMetadata?
        if let externalID = incoming.externalID, !externalID.isEmpty {
            existing = try await metadata.metadata(forExternalID: externalID)
        } else {
            existing = try await metadata.metadata(for: incoming.eventID)
        }
        
        let resolved = existing.map { EventConflictResolver.merge($0, next) } ?? next
        try await metadata.upsert(resolved)
        metadataCache[resolved.eventID] = resolved
        return resolved
    }
    
    // MARK: - Event mutations
    
    @discardableResult
    public func createEvent(
        title: String,
        in calendar: EKCalendar?,
        start: Date,
        end: Date,
        location: String? = nil,
        notes: String? = nil
    ) throws -> EKEvent {
        let event = EKEvent(eventStore: service.store)
        event.calendar = calendar ?? service.store.defaultCalendarForNewEvents
        event.title = title
        event.startDate = start
        event.endDate = end
        event.location = location
        event.notes = notes
        try service.store.save(event, span: .thisEvent, commit: true)
        eventCache.removeAll(keepingCapacity: true)
        return event
    }
    
    public func updateEvent(
        _ event: EKEvent,
        span: EKSpan = .thisEvent
    ) throws {
        try service.store.save(event, span: span, commit: true)
        eventCache.removeAll(keepingCapacity: true)
    }
    
    public func deleteEvent(_ event: EKEvent, span: EKSpan = .thisEvent) async throws {
        try service.store.remove(event, span: span, commit: true)
        if let id = event.eventIdentifier {
            try? await metadata.delete(eventID: id)
            metadataCache[id] = nil
        }
        eventCache.removeAll(keepingCapacity: true)
    }
    
    /// Reschedules `event` to `newStart`, preserving its duration. Bumps
    /// metadata `updatedAt`/`version` for conflict resolution.
    public func reschedule(_ event: EKEvent, to newStart: Date, span: EKSpan = .thisEvent) async throws {
        guard event.calendar?.allowsContentModifications ?? false else {
            throw NSError(
                domain: "EventRepository",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "This calendar is read-only."]
            )
        }
        let duration = max(60, event.endDate.timeIntervalSince(event.startDate))
        event.startDate = newStart
        event.endDate = newStart.addingTimeInterval(duration)
        try service.store.save(event, span: span, commit: true)
        
        if var meta = await metadata(for: event) {
            meta.version &+= 1
            meta.updatedAt = Date()
            meta.lastSyncedAt = Date()
            _ = try? await upsertMetadata(meta)
        }
    }
    
    // MARK: - Job mirroring
    
    /// Mirrors a `Job` into the system calendar and ties it to a metadata row.
    @discardableResult
    func mirror(job: Job, existingMetadataByJobID: [UUID: EventMetadata]) async throws -> EKEvent? {
        let existingEventID = existingMetadataByJobID[job.id]?.eventID
        guard let newID = try await service.upsert(job: job, existingEventID: existingEventID) else {
            return nil
        }
        let event = service.store.event(withIdentifier: newID)
        var meta = existingMetadataByJobID[job.id] ?? EventMetadata(eventID: newID, jobID: job.id)
        meta.eventID = newID
        meta.externalID = event?.calendarItemExternalIdentifier ?? meta.externalID
        meta.jobID = job.id
        meta.lastSyncedAt = Date()
        _ = try await upsertMetadata(meta)
        return event
    }
    
    // MARK: - Change stream
    
    /// Yields `()` after each debounced burst of EventKit changes.
    public func changes() -> AsyncStream<Void> {
        let id = UUID()
        return AsyncStream { continuation in
            self.continuations[id] = continuation
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.continuations[id] = nil
                }
            }
        }
    }
    
    private func scheduleDebouncedBroadcast() {
        debounceTask?.cancel()
        debounceTask = Task { [debounce, weak self] in
            try? await Task.sleep(for: debounce)
            guard let self, !Task.isCancelled else { return }
            for (_, continuation) in self.continuations {
                continuation.yield()
            }
        }
    }
    
}
