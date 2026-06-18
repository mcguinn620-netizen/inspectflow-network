import Foundation
import EventKit
import Combine

/// Native EventKit bridge for the Schedule screen.
///
/// Handles permissions for both iOS 16 and iOS 17+, fetching events,
/// upserting a `Job` as an `EKEvent`, and broadcasting external calendar
/// changes via an `AsyncStream`.
@MainActor
final class EventKitService: ObservableObject {
    
    static let shared = EventKitService()
    
    let store = EKEventStore()
    
    @Published private(set) var authorizationStatus: EKAuthorizationStatus =
    EKEventStore.authorizationStatus(for: .event)
    
    var hasAccess: Bool {
        authorizationStatus == .authorized
    }
    
    private var changeContinuations: [UUID: AsyncStream<Void>.Continuation] = [:]
    private var observerToken: NSObjectProtocol?
    
    private init() {
        observerToken = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            self?.broadcastChange()
        }
    }
    
    deinit {
        if let observerToken { NotificationCenter.default.removeObserver(observerToken) }
    }
    
    // MARK: - Authorization
    
    func requestAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            store.requestAccess(to: .event) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.authorizationStatus =
                    EKEventStore.authorizationStatus(for: .event)
                    
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    // MARK: - Fetch
    
    func events(
        in interval: DateInterval,
        calendars: [EKCalendar]? = nil
    ) -> [EKEvent] {
        guard hasAccess else { return [] }
        let predicate = store.predicateForEvents(
            withStart: interval.start,
            end: interval.end,
            calendars: calendars
        )
        return store.events(matching: predicate)
    }
    
    // MARK: - Dedicated calendar
    
    func inspectFlowCalendar() -> EKCalendar? {
        if let existing = store.calendars(for: .event)
            .first(where: { $0.title == "InspectFlow Jobs" }) {
            return existing
        }
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = "InspectFlow Jobs"
        calendar.source = store.defaultCalendarForNewEvents?.source ?? store.sources.first
        do {
            try store.saveCalendar(calendar, commit: true)
            return calendar
        } catch {
            return nil
        }
    }
    
    // MARK: - Job mirroring
    
    @discardableResult
    func upsert(job: Job, existingEventID: String? = nil) async throws -> String? {
        guard hasAccess else { return nil }
        guard let start = job.scheduledAt else { return nil }
        
        let event: EKEvent
        if let existingEventID, let found = store.event(withIdentifier: existingEventID) {
            event = found
        } else {
            event = EKEvent(eventStore: store)
        }
        
        event.calendar = inspectFlowCalendar()
        event.title = job.title
        event.startDate = start
        event.endDate = Calendar.current.date(byAdding: .minute, value: 60, to: start)
        ?? start.addingTimeInterval(3600)
        event.location = job.location
        event.notes = """
        Customer: \(job.customerName ?? "")
        Status: \(job.status)
        JobID: \(job.id.uuidString)
        """
        
        try store.save(event, span: .thisEvent, commit: true)
        return event.eventIdentifier
    }
    
    func delete(eventIdentifier: String) async throws {
        guard hasAccess, let event = store.event(withIdentifier: eventIdentifier) else { return }
        try store.remove(event, span: .thisEvent, commit: true)
    }
    
    // MARK: - Change stream
    
    /// Yields `()` each time the EKEventStore broadcasts a change.
    func changes() -> AsyncStream<Void> {
        let id = UUID()
        return AsyncStream { continuation in
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                
                Task { @MainActor [weak self] in
                    self?.changeContinuations[id] = nil
                }
            }
        }
    }
    
    private func broadcastChange() {
        for (_, continuation) in changeContinuations {
            continuation.yield()
        }
    }
}
