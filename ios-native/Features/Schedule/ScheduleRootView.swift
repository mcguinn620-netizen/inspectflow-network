import SwiftUI
import EventKit

/// Adaptive entry point for the native Schedule experience.
///
/// Regular width uses a calendar-style three column split view.
/// Compact width uses a stacked navigation flow.
struct ScheduleRootView: View {

    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ScheduleViewModel()
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        Group {
            if sizeClass == .regular {
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    CalendarSidebarView(viewModel: viewModel, filters: viewModel.filters)
                } content: {
                    NavigationStack {
                        ScheduleContentPane(viewModel: viewModel)
                    }
                } detail: {
                    NavigationStack {
                        EventInspectorView(viewModel: viewModel)
                    }
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                NavigationStack {
                    ScheduleContentPane(viewModel: viewModel)
                        .navigationDestination(isPresented: detailBinding) {
                            EventInspectorView(viewModel: viewModel)
                        }
                }
            }
        }
        .task {
            await viewModel.bootstrap(orgId: appState.activeOrganizationID)
        }
        .alert("Schedule", isPresented: errorBinding) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var detailBinding: Binding<Bool> {
        Binding(
            get: { viewModel.selectedEventID != nil || viewModel.selectedJobID != nil },
            set: { open in
                if !open {
                    viewModel.selectedEventID = nil
                    viewModel.selectedJobID = nil
                }
            }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

// MARK: - Content pane

struct ScheduleContentPane: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @AppStorage("schedule.viewMode.v2") private var rawMode: String = ScheduleViewModel.DisplayMode.day.rawValue

    private var dropCoordinator: EventDropCoordinator {
        EventDropCoordinator(viewModel: viewModel)
    }

    private var mode: Binding<ScheduleViewModel.DisplayMode> {
        Binding(
            get: { ScheduleViewModel.DisplayMode(rawValue: rawMode) ?? .day },
            set: { rawMode = $0.rawValue }
        )
    }

    private var unsyncedJobs: [Job] {
        viewModel.jobs.filter { job in
            !viewModel.metadataByEventID.values.contains(where: { $0.jobID == job.id })
        }
    }

    private var screenTitle: String {
        let cal = Calendar.current
        switch mode.wrappedValue {
        case .day:
            return viewModel.selectedDate.formatted(.dateTime.weekday(.wide).month().day())
        case .week:
            let weekStart = Date.startOfScheduleWeek(for: viewModel.selectedDate)
            let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
            return "\(weekStart.formatted(.dateTime.month().day())) – \(weekEnd.formatted(.dateTime.month().day()))"
        case .month:
            return viewModel.selectedDate.formatted(.dateTime.month(.wide).year())
        case .list:
            return "Schedule"
        }
    }

    var body: some View {
        Group {
            if !viewModel.filters.searchQuery.isEmpty {
                searchResultsList
            } else {
                switch mode.wrappedValue {
                case .day:
                    ScheduleDayGrid(
                        date: viewModel.selectedDate,
                        events: viewModel.events,
                        jobs: unsyncedJobs,
                        coordinator: dropCoordinator,
                        onSelectEvent: { ev in
                            viewModel.selectedEventID = ev.eventIdentifier
                            viewModel.selectedJobID = nil
                        },
                        onSelectJob: { job in
                            viewModel.selectedJobID = job.id
                            viewModel.selectedEventID = nil
                        }
                    )
                case .week:
                    weekView
                case .month:
                    ScheduleMonthMatrix(
                        selectedDate: $viewModel.selectedDate,
                        events: viewModel.events,
                        jobs: unsyncedJobs,
                        coordinator: dropCoordinator,
                        onSelectDay: { day in
                            viewModel.selectedDate = day
                        }
                    )
                case .list:
                    eventList
                }
            }
        }
        .navigationTitle(screenTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color(.systemBackground), for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarLeading) {
                Button {
                    goToday()
                } label: {
                    Text("Today")
                        .fontWeight(.semibold)
                }
            }

            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    shift(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Previous")

                Button {
                    shift(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .accessibilityLabel("Next")

                Menu {
                    ForEach(ScheduleViewModel.DisplayMode.allCases) { displayMode in
                        Button {
                            rawMode = displayMode.rawValue
                        } label: {
                            Label(displayMode.title, systemImage: icon(for: displayMode))
                        }
                    }
                } label: {
                    Label(mode.wrappedValue.title, systemImage: icon(for: mode.wrappedValue))
                }

                QuickAddEventField(viewModel: viewModel)
            }
        }
        .searchable(
            text: Binding(
                get: { viewModel.filters.searchQuery },
                set: { viewModel.updateSearchQuery($0) }
            ),
            prompt: "Search events, tags, notes"
        )
        .refreshable {
            await viewModel.load(orgId: nil)
        }
        .onChange(of: viewModel.selectedDate) { _ in
            Task { await viewModel.reloadEvents() }
        }
    }

    private func goToday() {
        viewModel.selectedDate = Date()
    }

    private func shift(by step: Int) {
        let cal = Calendar.current
        switch mode.wrappedValue {
        case .day, .list:
            viewModel.selectedDate = cal.date(byAdding: .day, value: step, to: viewModel.selectedDate) ?? viewModel.selectedDate
        case .week:
            viewModel.selectedDate = cal.date(byAdding: .day, value: step * 7, to: viewModel.selectedDate) ?? viewModel.selectedDate
        case .month:
            viewModel.selectedDate = cal.date(byAdding: .month, value: step, to: viewModel.selectedDate) ?? viewModel.selectedDate
        }
    }

    private func icon(for mode: ScheduleViewModel.DisplayMode) -> String {
        switch mode {
        case .day:
            return "calendar.day.timeline.leading"
        case .week:
            return "calendar"
        case .month:
            return "square.grid.3x3"
        case .list:
            return "list.bullet"
        }
    }

    private var searchResultsList: some View {
        List(viewModel.searchResults) { hit in
            Button {
                viewModel.selectedEventID = hit.event.eventIdentifier
                viewModel.selectedJobID = nil
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(hit.event.title ?? "Untitled")
                        .font(.subheadline)
                    HStack(spacing: 6) {
                        Text(hit.event.startDate, format: .dateTime.month().day().hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let category = hit.metadata?.category {
                            Text("· \(category)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .overlay {
            if viewModel.searchResults.isEmpty {
                ContentUnavailableCompat(
                    title: "No matches",
                    message: "Try a different search term."
                )
            }
        }
    }

    private var weekView: some View {
        let weekStart = Date.startOfScheduleWeek(for: viewModel.selectedDate)
        return ScheduleWeekGrid(
            weekStart: weekStart,
            events: viewModel.events,
            jobs: unsyncedJobs,
            coordinator: dropCoordinator,
            onSelectEvent: { ev in
                viewModel.selectedEventID = ev.eventIdentifier
                viewModel.selectedJobID = nil
            },
            onSelectJob: { job in
                viewModel.selectedJobID = job.id
                viewModel.selectedEventID = nil
            }
        )
    }

    private var eventList: some View {
        List {
            ForEach(eventsByDay(), id: \.0) { day, items in
                Section(day.formatted(.dateTime.weekday(.wide).month().day())) {
                    ForEach(items, id: \.eventIdentifier) { ev in
                        Button {
                            viewModel.selectedEventID = ev.eventIdentifier
                            viewModel.selectedJobID = nil
                        } label: {
                            HStack {
                                Circle()
                                    .fill(Color(cgColor: ev.calendar?.cgColor ?? UIColor.systemBlue.cgColor))
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading) {
                                    Text(ev.title ?? "Untitled")
                                        .font(.subheadline)
                                    Text(ev.startDate, format: .dateTime.hour().minute())
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func eventsByDay() -> [(Date, [EKEvent])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: viewModel.events) { ev in
            cal.startOfDay(for: ev.startDate)
        }
        return grouped.keys.sorted().map { ($0, grouped[$0]!.sorted { $0.startDate < $1.startDate }) }
    }
}
