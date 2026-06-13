import Foundation
import EventKit
import Combine

/// Single source of truth for the native Schedule screen.
///
/// Combines Supabase `Job`s, the system calendar's `EKEvent`s, and per-event
/// app metadata (SwiftData on iOS 17+, Core Data on iOS 16).
@MainActor
final class ScheduleViewModel: ObservableObject {

    enum DisplayMode: String, CaseIterable, Identifiable {
        case day, week, month, list
        var id: String { rawValue }
        var title: String {
            switch self {
            case .day: "Day"
            case .week: "Week"
            case .month: "Month"
            case .list: "List"
            }
        }
    }

    @Published var jobs: [Job] = []
    @Published var events: [EKEvent] = []
    @Published var metadataByEventID: [String: EventMetadata] = [:]
    @Published var selectedDate: Date = Date()
    @Published var selectedEventID: String?
    @Published var selectedJobID: UUID?
    @Published var visibleCalendarIDs: Set<String> = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let jobsVM = JobsViewModel()
    private let calendar = EventKitService.shared
    private let metadata = ScheduleMetadataStoreFactory.make()

    private var changeTask: Task<Void, Never>?

    init() {
        changeTask = Task { [weak self] in
            guard let self else { return }
            for await _ in self.calendar.changes() {
                await self.reloadEvents()
            }
        }
    }

    deinit { changeTask?.cancel() }

    // MARK: - Load

    func bootstrap(orgId: UUID?) async {
        _ = await calendar.requestAccess()
        await load(orgId: orgId)
    }

    func load(orgId: UUID?) async {
        isLoading = true
        defer { isLoading = false }

        async let jobsLoad: Void = jobsVM.loadForWeek(
            Date.startOfScheduleWeek(for: selectedDate),
            orgId: orgId
        )
        async let metaLoad = (try? metadata.allMetadata()) ?? []

        await jobsLoad
        let metaList = await metaLoad

        jobs = jobsVM.jobs
        metadataByEventID = Dictionary(uniqueKeysWithValues: metaList.map { ($0.eventID, $0) })
        await reloadEvents()
    }

    func reloadEvents() async {
        guard calendar.hasAccess else { return }
        let cal = Calendar.current
        let monthInterval = cal.dateInterval(of: .month, for: selectedDate) ?? DateInterval(
            start: selectedDate.addingTimeInterval(-86400 * 14),
            duration: 86400 * 30
        )
        // Pad a week on each side so week-view edges always have data.
        let padded = DateInterval(
            start: monthInterval.start.addingTimeInterval(-86400 * 7),
            end: monthInterval.end.addingTimeInterval(86400 * 7)
        )
        let cals = visibleCalendarIDs.isEmpty
            ? nil
            : calendar.store.calendars(for: .event).filter { visibleCalendarIDs.contains($0.calendarIdentifier) }
        events = calendar.events(in: padded, calendars: cals)
    }

    // MARK: - Selection helpers

    var selectedEvent: EKEvent? {
        guard let id = selectedEventID else { return nil }
        return events.first(where: { $0.eventIdentifier == id })
            ?? calendar.store.event(withIdentifier: id)
    }

    var selectedJob: Job? {
        guard let id = selectedJobID else { return nil }
        return jobs.first(where: { $0.id == id })
    }

    // MARK: - Writes

    func upsertMetadata(_ m: EventMetadata) async {
        var updated = m
        updated.updatedAt = Date()
        do {
            try await metadata.upsert(updated)
            metadataByEventID[updated.eventID] = updated
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func mirror(job: Job) async {
        do {
            let existing = metadataByEventID.values.first(where: { $0.jobID == job.id })?.eventID
            if let newID = try await calendar.upsert(job: job, existingEventID: existing) {
                var meta = metadataByEventID[newID]
                    ?? EventMetadata(eventID: newID, jobID: job.id)
                meta.jobID = job.id
                await upsertMetadata(meta)
            }
            await reloadEvents()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteEvent(_ event: EKEvent) async {
        guard let id = event.eventIdentifier else { return }
        do {
            try await calendar.delete(eventIdentifier: id)
            try? await metadata.delete(eventID: id)
            metadataByEventID[id] = nil
            await reloadEvents()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

extension Date {
    static func startOfScheduleWeek(for date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: comps) ?? date
    }
}
