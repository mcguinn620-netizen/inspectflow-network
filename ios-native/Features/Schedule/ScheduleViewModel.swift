import Foundation
import EventKit
import Combine

/// Single source of truth for the native Schedule screen.
///
/// Refactored (Phase 1) to depend only on `EventRepository` and
/// `CalendarRepository`. All EventKit I/O and metadata persistence now goes
/// through the repositories; this view model coordinates view state.
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
    @Published var searchResults: [ScheduleSearchHit] = []

    let filters: CalendarFilterModel
    private let searchService: ScheduleSearchService
    private let jobsVM = JobsViewModel()
    private let events_repo: EventRepository
    private let calendarsRepo: CalendarRepository

    private var changeTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?

    init(
        events: EventRepository = .shared,
        calendars: CalendarRepository = .shared,
        filters: CalendarFilterModel = CalendarFilterModel(),
        searchService: ScheduleSearchService? = nil
    ) {
        self.events_repo = events
        self.calendarsRepo = calendars
        self.filters = filters
        self.searchService = searchService ?? ScheduleSearchService(repository: events)

        changeTask = Task { [weak self] in
            guard let self else { return }
            for await _ in self.events_repo.changes() {
                await self.reloadEvents()
            }
        }
    }

    deinit {
        changeTask?.cancel()
        searchTask?.cancel()
    }


    // MARK: - Load

    func bootstrap(orgId: UUID?) async {
        _ = await events_repo.requestAccess()
        calendarsRepo.reload()
        await load(orgId: orgId)
    }

    func load(orgId: UUID?) async {
        isLoading = true
        defer { isLoading = false }

        async let jobsLoad: Void = jobsVM.loadForWeek(
            Date.startOfScheduleWeek(for: selectedDate),
            orgId: orgId
        )
        async let metaLoad = events_repo.allMetadata()

        await jobsLoad
        let metaList = await metaLoad

        jobs = jobsVM.jobs
        metadataByEventID = Dictionary(uniqueKeysWithValues: metaList.map { ($0.eventID, $0) })
        await reloadEvents()
    }

    func reloadEvents() async {
        guard events_repo.hasAccess else { return }
        let cal = Calendar.current
        let monthInterval = cal.dateInterval(of: .month, for: selectedDate) ?? DateInterval(
            start: selectedDate.addingTimeInterval(-86400 * 14),
            duration: 86400 * 30
        )
        let padded = DateInterval(
            start: monthInterval.start.addingTimeInterval(-86400 * 7),
            end: monthInterval.end.addingTimeInterval(86400 * 7)
        )
        let all = events_repo.events(in: padded, visibleOnly: true)
        if filters.selectedCategories.isEmpty && filters.selectedTags.isEmpty {
            events = all
        } else {
            events = all.filter { ev in
                let meta = ev.eventIdentifier.flatMap { metadataByEventID[$0] }
                return filters.matches(meta)
            }
        }
        await refreshSearchResults()
    }

    // MARK: - Search

    func updateSearchQuery(_ query: String) {
        filters.searchQuery = query
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard let self, !Task.isCancelled else { return }
            await self.refreshSearchResults()
        }
    }

    private func refreshSearchResults() async {
        let query = filters.searchQuery
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        let cal = Calendar.current
        let interval = cal.dateInterval(of: .month, for: selectedDate) ?? DateInterval(
            start: selectedDate.addingTimeInterval(-86400 * 30),
            duration: 86400 * 60
        )
        let padded = DateInterval(
            start: interval.start.addingTimeInterval(-86400 * 30),
            end: interval.end.addingTimeInterval(86400 * 60)
        )
        searchResults = searchService.search(
            query: query,
            in: padded,
            metadataByEventID: metadataByEventID
        )
    }

    // MARK: - Recurrence

    func applyRecurrence(_ spec: RecurrenceSpec, to event: EKEvent) async {
        do {
            try EventKitService.shared.applyRecurrence(spec, to: event)
            await reloadEvents()
        } catch {
            errorMessage = error.localizedDescription
        }
    }


    // MARK: - Selection helpers

    var selectedEvent: EKEvent? {
        guard let id = selectedEventID else { return nil }
        return events.first(where: { $0.eventIdentifier == id })
            ?? events_repo.event(matching: EventIdentity(eventIdentifier: id))
    }

    var selectedJob: Job? {
        guard let id = selectedJobID else { return nil }
        return jobs.first(where: { $0.id == id })
    }

    // MARK: - Writes

    func upsertMetadata(_ m: EventMetadata) async {
        do {
            let saved = try await events_repo.upsertMetadata(m)
            metadataByEventID[saved.eventID] = saved
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func mirror(job: Job) async {
        do {
            let byJob = Dictionary(
                metadataByEventID.values.compactMap { meta -> (UUID, EventMetadata)? in
                    guard let id = meta.jobID else { return nil }
                    return (id, meta)
                },
                uniquingKeysWith: { a, _ in a }
            )
            _ = try await events_repo.mirror(job: job, existingMetadataByJobID: byJob)
            await reloadEvents()
            let metaList = await events_repo.allMetadata()
            metadataByEventID = Dictionary(uniqueKeysWithValues: metaList.map { ($0.eventID, $0) })
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteEvent(_ event: EKEvent) async {
        do {
            try await events_repo.deleteEvent(event)
            if let id = event.eventIdentifier {
                metadataByEventID[id] = nil
            }
            await reloadEvents()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Reschedule entry point shared by all calendar drop surfaces.
    func reschedule(identity: EventIdentity, originalStart: Date, to newStart: Date) async {
        guard let event = events_repo.event(matching: identity) else {
            errorMessage = "The dragged event could not be found."
            return
        }
        let cal = Calendar.current
        if cal.compare(event.startDate, to: originalStart, toGranularity: .minute) != .orderedSame {
            // Event moved while the drag was in flight — refresh and abort.
            await reloadEvents()
            return
        }
        do {
            try await events_repo.reschedule(event, to: newStart)
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
