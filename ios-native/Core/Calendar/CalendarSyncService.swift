import EventKit
import Foundation

@MainActor
final class CalendarSyncService {
    static let shared = CalendarSyncService()

    private let store = EKEventStore()
    private let defaults = UserDefaults.standard
    private let eventMapKey = "schedule.calendar.event.map.v1"

    private init() {}

    func ensureAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            do {
                return try await store.requestFullAccessToEvents()
            } catch {
                return false
            }
        }

        return await withCheckedContinuation { continuation in
            store.requestAccess(to: .event) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    func sync(job: Job) async -> Bool {
        guard let start = job.scheduledAt else { return false }
        guard await ensureAccess() else { return false }

        let end = Calendar.current.date(byAdding: .hour, value: 1, to: start) ?? start.addingTimeInterval(3600)
        let notes = [
            "Job ID: \(job.id.uuidString)",
            "Status: \(job.status)",
            "Customer: \(job.customerName ?? \"\")"
        ].joined(separator: "\n")

        let event = existingEvent(for: job.id) ?? EKEvent(eventStore: store)
        event.calendar = store.defaultCalendarForNewEvents
        event.title = job.title
        event.startDate = start
        event.endDate = end
        event.location = job.location
        event.notes = notes

        do {
            try store.save(event, span: .thisEvent)
            save(eventIdentifier: event.eventIdentifier, for: job.id)
            return true
        } catch {
            return false
        }
    }

    private func existingEvent(for jobID: UUID) -> EKEvent? {
        guard let id = loadMap()[jobID.uuidString] else { return nil }
        return store.event(withIdentifier: id)
    }

    private func save(eventIdentifier: String, for jobID: UUID) {
        var map = loadMap()
        map[jobID.uuidString] = eventIdentifier
        defaults.set(map, forKey: eventMapKey)
    }

    private func loadMap() -> [String: String] {
        defaults.dictionary(forKey: eventMapKey) as? [String: String] ?? [:]
    }
}
