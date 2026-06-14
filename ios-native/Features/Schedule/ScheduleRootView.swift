import SwiftUI
import EventKit

/// Adaptive entry point for the native Schedule experience.
///
/// On regular-width devices (iPad / Mac Catalyst) it presents a three-pane
/// `NavigationSplitView`: sidebar → calendar grid → event inspector. On
/// compact widths (iPhone) it falls back to a stacked `NavigationStack`.
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
                    ScheduleContentPane(viewModel: viewModel)
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
        .task { await viewModel.bootstrap(orgId: appState.activeOrganizationID) }
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

// MARK: - Content pane (Day / Week / Month / List switcher)

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


    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: mode) {
                ForEach(ScheduleViewModel.DisplayMode.allCases) { m in
                    Text(m.title).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            dayNavigator

            Divider()

            if !viewModel.filters.searchQuery.isEmpty {
                searchResultsList
            } else {
                switch mode.wrappedValue {
                case .day:
                    ScheduleDayGrid(
                        date: viewModel.selectedDate,
                        events: viewModel.events,
                        jobs: viewModel.jobs.filter { unsynced($0) },
                        coordinator: dropCoordinator,
                        onSelectEvent: { ev in viewModel.selectedEventID = ev.eventIdentifier; viewModel.selectedJobID = nil },
                        onSelectJob: { job in viewModel.selectedJobID = job.id; viewModel.selectedEventID = nil }
                    )
                case .week:
                    weekView
                case .month:
                    ScheduleMonthMatrix(
                        selectedDate: $viewModel.selectedDate,
                        events: viewModel.events,
                        coordinator: dropCoordinator
                    )
                case .list:
                    eventList
                }

            }
        }
        .navigationTitle("Schedule")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Today") { viewModel.selectedDate = Date() }
            }
        }
        .searchable(
            text: Binding(
                get: { viewModel.filters.searchQuery },
                set: { viewModel.updateSearchQuery($0) }
            ),
            prompt: "Search events, tags, notes"
        )
        .refreshable { await viewModel.load(orgId: nil) }
        .onChange(of: viewModel.selectedDate) { _ in
            Task { await viewModel.reloadEvents() }
        }
    }

    private var searchResultsList: some View {
        List(viewModel.searchResults) { hit in
            Button {
                viewModel.selectedEventID = hit.event.eventIdentifier
                viewModel.selectedJobID = nil
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(hit.event.title ?? "Untitled").font(.subheadline)
                    HStack(spacing: 6) {
                        Text(hit.event.startDate, format: .dateTime.month().day().hour().minute())
                            .font(.caption).foregroundStyle(.secondary)
                        if let category = hit.metadata?.category {
                            Text("· \(category)").font(.caption).foregroundStyle(.secondary)
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


    private var dayNavigator: some View {
        HStack {
            Button { shift(by: -1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            Text(viewModel.selectedDate, format: .dateTime.weekday(.wide).month().day().year())
                .font(.subheadline.weight(.semibold))
            Spacer()
            Button { shift(by: 1) } label: { Image(systemName: "chevron.right") }
        }
        .padding(.horizontal)
        .padding(.bottom, 6)
    }

    private func shift(by days: Int) {
        viewModel.selectedDate = Calendar.current.date(
            byAdding: .day, value: days, to: viewModel.selectedDate
        ) ?? viewModel.selectedDate
    }

    private func unsynced(_ job: Job) -> Bool {
        !viewModel.metadataByEventID.values.contains(where: { $0.jobID == job.id })
    }

    // MARK: Week (reuses existing ScheduleWeekCalendarView)

    private var weekView: some View {
        let weekStart = Date.startOfScheduleWeek(for: viewModel.selectedDate)
        return ScheduleWeekGrid(
            weekStart: weekStart,
            events: viewModel.events,
            coordinator: dropCoordinator,
            onSelectEvent: { ev in
                viewModel.selectedEventID = ev.eventIdentifier
                viewModel.selectedJobID = nil
            }
        )
    }


    // MARK: List

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
                                    Text(ev.title ?? "Untitled").font(.subheadline)
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
