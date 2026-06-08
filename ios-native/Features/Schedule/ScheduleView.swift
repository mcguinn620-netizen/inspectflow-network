import SwiftUI
import UniformTypeIdentifiers

// MARK: - Schedule conflict detection (ported from src/lib/scheduleConflicts.ts)

enum ScheduleConflict: Equatable {
    case blocked
    case outsideHours
    case overlap(otherJobId: UUID, otherTitle: String)
}

struct AvailabilitySlot {
    let startMinutes: Int
    let endMinutes: Int
    let isAvailable: Bool
}

enum ScheduleConflictDetector {
    static func detect(
        jobs: [Job],
        blockedDates: Set<String> = [],
        availability: [Int: [AvailabilitySlot]] = [:],
        defaultDurationMinutes: Int = 60
    ) -> [UUID: [ScheduleConflict]] {
        var out: [UUID: [ScheduleConflict]] = [:]
        let cal = Calendar.current

        struct Entry { let job: Job; let start: Date; let end: Date; let dayKey: String }
        var byDay: [String: [Entry]] = [:]

        for job in jobs {
            guard let start = job.scheduledAt else { continue }
            if job.status == "canceled" || job.status == "completed" { continue }
            let duration = TimeInterval(defaultDurationMinutes * 60)
            let end = start.addingTimeInterval(duration)
            let dayKey = Self.ymd(start)
            byDay[dayKey, default: []].append(Entry(job: job, start: start, end: end, dayKey: dayKey))

            if blockedDates.contains(dayKey) {
                out[job.id, default: []].append(.blocked)
            }

            let dow = cal.component(.weekday, from: start) - 1
            let slots = availability[dow] ?? []
            if !slots.isEmpty {
                let comps = cal.dateComponents([.hour, .minute], from: start)
                let startMin = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
                let endMin = startMin + defaultDurationMinutes
                let fits = slots.contains { $0.isAvailable && startMin >= $0.startMinutes && endMin <= $0.endMinutes }
                if !fits {
                    out[job.id, default: []].append(.outsideHours)
                }
            }
        }

        for var list in byDay.values {
            list.sort { $0.start < $1.start }
            for i in 0..<list.count {
                for k in (i + 1)..<list.count {
                    if list[k].start >= list[i].end { break }
                    out[list[i].job.id, default: []].append(.overlap(otherJobId: list[k].job.id, otherTitle: list[k].job.title))
                    out[list[k].job.id, default: []].append(.overlap(otherJobId: list[i].job.id, otherTitle: list[i].job.title))
                }
            }
        }
        return out
    }

    private static func ymd(_ d: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }
}

// MARK: - Schedule view

struct ScheduleView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = JobsViewModel()
    @State private var selectedWeekStart = Date.startOfWeek(for: Date())
    @State private var selectedJobID: UUID?
    @State private var dispatchTargetJob: Job?
    @State private var bannerMessage: String?
    @AppStorage("schedule.viewMode") private var viewMode: String = "week"

    private var dayColumns: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: selectedWeekStart) }
    }

    private var conflicts: [UUID: [ScheduleConflict]] {
        ScheduleConflictDetector.detect(jobs: viewModel.jobs)
    }

    private var hasConflicts: Bool { !conflicts.isEmpty }

    private var isDispatcher: Bool {
        let role = appState.effectiveRole
        return role == "dispatcher" || role == "admin" || role == "company_owner"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $viewMode) {
                    Text("Week").tag("week")
                    Text("List").tag("list")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                if viewModel.isLoading && viewModel.jobs.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.jobs.isEmpty {
                    ContentUnavailableCompat(
                        title: "No jobs this week",
                        message: viewModel.errorMessage ?? "Scheduled jobs appear here."
                    )
                } else if viewMode == "week" {
                    ScheduleWeekCalendarView(
                        weekStart: selectedWeekStart,
                        jobs: viewModel.jobs,
                        onSelect: { job in selectedJobID = job.id },
                        onLongPress: { job in
                            if isDispatcher { dispatchTargetJob = job }
                        }
                    )
                    .gesture(
                        DragGesture(minimumDistance: 30)
                            .onEnded { value in
                                if value.translation.width < -50 {
                                    selectedWeekStart = Calendar.current.date(byAdding: .day, value: 7, to: selectedWeekStart) ?? selectedWeekStart
                                } else if value.translation.width > 50 {
                                    selectedWeekStart = Calendar.current.date(byAdding: .day, value: -7, to: selectedWeekStart) ?? selectedWeekStart
                                }
                            }
                    )
                } else {
                    ScheduleListView(
                        weekStart: selectedWeekStart,
                        jobs: viewModel.jobs,
                        conflicts: conflicts,
                        onSelect: { selectedJobID = $0.id },
                        onAssign: { job in if isDispatcher { dispatchTargetJob = job } }
                    )
                }
            }
            .navigationTitle("Schedule")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { SyncStatusView() }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Today") { selectedWeekStart = Date.startOfWeek(for: Date()) }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if hasConflicts {
                    Text("Scheduling conflicts detected")
                        .font(.footnote)
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(.orange.opacity(0.2))
                        .accessibilityLabel("Scheduling conflicts detected")
                }
            }
            .sheet(item: $dispatchTargetJob) { job in
                DispatcherAssignSheet(job: job, orgId: appState.activeOrganizationID) { inspectorId in
                    Task { await viewModel.assign(job: job, inspectorId: inspectorId, orgId: appState.activeOrganizationID) }
                }
            }
            .alert("Schedule", isPresented: Binding(get: { bannerMessage != nil }, set: { if !$0 { bannerMessage = nil } })) {
                Button("OK") { bannerMessage = nil }
            } message: {
                Text(bannerMessage ?? "")
            }
            .refreshable { await viewModel.loadForWeek(selectedWeekStart, orgId: appState.activeOrganizationID) }
            .task(id: selectedWeekStart) { await viewModel.loadForWeek(selectedWeekStart, orgId: appState.activeOrganizationID) }
        }
    }
}

private struct ScheduleListView: View {
    let weekStart: Date
    let jobs: [Job]
    let conflicts: [UUID: [ScheduleConflict]]
    let onSelect: (Job) -> Void
    let onAssign: (Job) -> Void

    private var dayColumns: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: weekStart) }
    }

    var body: some View {
        List {
            ForEach(dayColumns, id: \.self) { day in
                let dayJobs = jobs.filter { job in
                    guard let s = job.scheduledAt else { return false }
                    return Calendar.current.isDate(s, inSameDayAs: day)
                }
                Section(header: Text(day, format: .dateTime.weekday(.wide).month().day())) {
                    if dayJobs.isEmpty {
                        Text("No jobs").font(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(dayJobs) { job in
                            Button { onSelect(job) } label: {
                                ScheduleJobPill(job: job, conflicts: conflicts[job.id] ?? [])
                            }
                            .swipeActions {
                                Button { onAssign(job) } label: { Label("Assign", systemImage: "person.badge.plus") }
                                    .tint(.blue)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

private struct ScheduleJobPill: View {
    let job: Job
    let conflicts: [ScheduleConflict]

    var body: some View {
        HStack {
            if !conflicts.isEmpty {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
            Text(job.title)
                .font(.caption)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(job.status)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(6)
        .background(Capsule().fill(conflicts.isEmpty ? Color.blue.opacity(0.12) : Color.orange.opacity(0.2)))
        .accessibilityLabel("\(job.title), status \(job.status)\(conflicts.isEmpty ? "" : ", has scheduling conflict")")
    }
}

private struct DispatcherAssignSheet: View {
    let job: Job
    let orgId: UUID?
    let onAssign: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var inspectors: [OrganizationMembership] = []
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var inspectorIDText = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Recommended inspectors") {
                    if isLoading {
                        HStack { ProgressView(); Text("Loading inspectors…").foregroundColor(.secondary) }
                    } else if let loadError {
                        Text(loadError).font(.footnote).foregroundColor(.secondary)
                    } else if inspectors.isEmpty {
                        Text("No inspectors found in this organization.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(inspectors) { membership in
                            Button {
                                onAssign(membership.userID)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(membership.userID.uuidString.prefix(8) + "…")
                                            .font(.subheadline)
                                        Text(membership.role)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                Section("Manual override") {
                    Text("Assign \(job.title) by entering an inspector UUID.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    TextField("Inspector UUID", text: $inspectorIDText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Assign inspector") {
                        guard let inspectorId = UUID(uuidString: inspectorIDText.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
                        onAssign(inspectorId)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Assign Inspector")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await loadInspectors() }
        }
    }

    private func loadInspectors() async {
        guard let orgId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            inspectors = try await SupabaseService.shared.fetchOrgInspectors(orgId: orgId)
        } catch {
            loadError = error.localizedDescription
        }
    }
}

private extension Date {
    static func startOfWeek(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }
}
