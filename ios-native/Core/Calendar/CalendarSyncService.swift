import Foundation
import EventKit
import MapKit

@MainActor
final class CalendarSyncService {

    static let shared = CalendarSyncService()

    private let store = EKEventStore()

    private let mapKey = "schedule.calendar.event.map.v1"

    private init() {}

    // MARK: - Permissions

    func ensureAccess() async -> Bool {

        if #available(iOS 17.0, *) {
            do {
                return try await store.requestFullAccessToEvents()
            } catch {
                return false
            }
        } else {
            return await withCheckedContinuation { continuation in
                store.requestAccess(to: .event) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    // MARK: - Calendar

    private func inspectFlowCalendar() -> EKCalendar? {

        if let existing = store.calendars(for: .event)
            .first(where: { $0.title == "InspectFlow Jobs" }) {
            return existing
        }

        let calendar = EKCalendar(for: .event)

        calendar.title = "InspectFlow Jobs"

        calendar.source =
            store.defaultCalendarForNewEvents?.source ??
            store.sources.first

        do {
            try store.saveCalendar(
                calendar,
                commit: true
            )

            return calendar
        } catch {
            print("Calendar create failed:", error)
            return nil
        }
    }

    // MARK: - Sync

    func sync(job: Job) async -> Bool {

        guard await ensureAccess() else {
            return false
        }

        guard let startDate = job.scheduledAt else {
            return false
        }

        let eventID = eventIdentifier(for: job.id)

        let event: EKEvent

        if let eventID,
           let existing = store.event(withIdentifier: eventID) {

            event = existing

        } else {

            event = EKEvent(eventStore: store)
        }

        event.calendar = inspectFlowCalendar()

        event.title = job.title

        event.startDate = startDate

        event.endDate =
            Calendar.current.date(
                byAdding: .minute,
                value: 90,
                to: startDate
            ) ?? startDate.addingTimeInterval(5400)

        event.location = job.location

        event.notes = """
        Customer: \(job.customerName ?? "")
        Status: \(job.status)
        JobID: \(job.id.uuidString)
        """

        if let address = job.location {

            let location = EKStructuredLocation(
                title: address
            )

            event.structuredLocation = location

            event.travelTime = 1800
        }

        do {

            try store.save(
                event,
                span: .thisEvent,
                commit: true
            )

            saveEventID(
                event.eventIdentifier,
                for: job.id
            )

            return true

        } catch {

            print("Calendar sync failed:", error)

            return false
        }
    }

    // MARK: - Delete

    func remove(job: Job) async {

        guard await ensureAccess() else {
            return
        }

        guard let eventID = eventIdentifier(for: job.id),
              let event = store.event(
                withIdentifier: eventID
              ) else {
            return
        }

        do {

            try store.remove(
                event,
                span: .thisEvent,
                commit: true
            )

            removeEventID(for: job.id)

        } catch {

            print("Delete event failed:", error)
        }
    }

    // MARK: - Mapping

    private func mappings() -> [String: String] {

        UserDefaults.standard.dictionary(
            forKey: mapKey
        ) as? [String: String] ?? [:]
    }

    private func eventIdentifier(
        for jobID: UUID
    ) -> String? {

        mappings()[jobID.uuidString]
    }

    private func saveEventID(
        _ eventID: String?,
        for jobID: UUID
    ) {

        guard let eventID else { return }

        var map = mappings()

        map[jobID.uuidString] = eventID

        UserDefaults.standard.set(
            map,
            forKey: mapKey
        )
    }

    private func removeEventID(
        for jobID: UUID
    ) {

        var map = mappings()

        map.removeValue(
            forKey: jobID.uuidString
        )

        UserDefaults.standard.set(
            map,
            forKey: mapKey
        )
    }
}