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
    @State private var selectedDate = Date()
    @State private var selectedJobID: UUID?
    @State private var dispatchTargetJob: Job?
    @State private var bannerMessage: String?
    @State private var rescheduleMode: Bool = false
    @AppStorage("schedule.viewMode") private var viewMode: String = "day"


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
                    Text("Day").tag("day")
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
                } else if viewMode == "day" {
                    CalendarKitDayView(
                        date: selectedDate,
                        jobs: viewModel.jobs,
                        conflicts: conflicts,
                        canReschedule: rescheduleMode && isDispatcher,
                        onSelect: { job in selectedJobID = job.id },
                        onLongPress: { job in if isDispatcher { dispatchTargetJob = job } },
                        onReschedule: { job, newStart in
                            Task { await viewModel.reschedule(job: job, scheduledAt: newStart, orgId: appState.activeOrganizationID) }
                        }
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    ScheduleExportMenu(jobs: viewModel.jobs) { msg in bannerMessage = msg }
                }
                if isDispatcher && viewMode == "day" {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Toggle(isOn: $rescheduleMode) {
                            Image(systemName: rescheduleMode ? "lock.open" : "lock")
                        }
                        .toggleStyle(.button)
                        .accessibilityLabel("Reschedule mode")
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Today") {
                        selectedWeekStart = Date.startOfWeek(for: Date())
                        selectedDate = Date()
                    }
                }
                if viewMode == "day" {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 12) {
                            Button {
                                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                            } label: { Image(systemName: "chevron.left") }
                            Text(selectedDate, format: .dateTime.weekday(.abbreviated).month().day())
                                .font(.subheadline.weight(.semibold))
                            Button {
                                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                            } label: { Image(systemName: "chevron.right") }
                        }
                    }
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
import SwiftUI

/// Apple Calendar-style week view. Hour rail on the left, 7 day columns,
/// jobs positioned as blocks by their `scheduledAt` time.
///
/// Compatible with iOS 16 — no `TimelineView`, no `ContentUnavailableView`.
struct ScheduleWeekCalendarView: View {
    let weekStart: Date
    let jobs: [Job]
    var onSelect: (Job) -> Void = { _ in }
    var onLongPress: (Job) -> Void = { _ in }

    private let startHour = 6      // 6 AM
    private let endHour = 22       // 10 PM
    private let hourHeight: CGFloat = 56
    private let railWidth: CGFloat = 44

    private var hours: [Int] { Array(startHour..<endHour) }

    private var dayColumns: [Date] {
        let cal = Calendar.current
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                ZStack(alignment: .topLeading) {
                    grid
                    nowLineOverlay
                    blocksOverlay
                }
                .frame(height: CGFloat(hours.count) * hourHeight)
            }
        }
    }

    // MARK: - Header (day strip)

    private var header: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: railWidth)
            ForEach(dayColumns, id: \.self) { day in
                VStack(spacing: 2) {
                    Text(day, format: .dateTime.weekday(.abbreviated))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(day, format: .dateTime.day())
                        .font(.headline)
                        .foregroundStyle(isToday(day) ? Color.accentColor : Color.primary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle().fill(isToday(day) ? Color.accentColor.opacity(0.15) : .clear)
                        )
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Grid (hour rows + day columns)

    private var grid: some View {
        GeometryReader { geo in
            let dayWidth = max(0, (geo.size.width - railWidth) / 7)
            ZStack(alignment: .topLeading) {
                // Today column tint
                if let todayIndex = dayColumns.firstIndex(where: { isToday($0) }) {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.06))
                        .frame(width: dayWidth, height: CGFloat(hours.count) * hourHeight)
                        .offset(x: railWidth + CGFloat(todayIndex) * dayWidth, y: 0)
                }

                // Hour rows
                VStack(spacing: 0) {
                    ForEach(hours, id: \.self) { hour in
                        HStack(spacing: 0) {
                            Text(hourLabel(hour))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(width: railWidth, alignment: .trailing)
                                .padding(.trailing, 4)
                                .offset(y: -6)
                            VStack(spacing: 0) {
                                Divider()
                                Spacer(minLength: 0)
                            }
                        }
                        .frame(height: hourHeight, alignment: .top)
                    }
                }

                // Vertical day separators
                HStack(spacing: 0) {
                    Spacer().frame(width: railWidth)
                    ForEach(0..<7, id: \.self) { _ in
                        VStack { Spacer() }
                            .frame(width: dayWidth)
                            .overlay(
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.12))
                                    .frame(width: 0.5),
                                alignment: .leading
                            )
                    }
                }
            }
        }
    }

    // MARK: - "Now" line

    private var nowLineOverlay: some View {
        GeometryReader { geo in
            let dayWidth = max(0, (geo.size.width - railWidth) / 7)
            if let todayIndex = dayColumns.firstIndex(where: { isToday($0) }) {
                let now = Date()
                let cal = Calendar.current
                let comps = cal.dateComponents([.hour, .minute], from: now)
                let minutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
                let startMinutes = startHour * 60
                if minutes >= startMinutes && minutes <= endHour * 60 {
                    let y = CGFloat(minutes - startMinutes) / 60.0 * hourHeight
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: dayWidth, height: 1.5)
                        .offset(x: railWidth + CGFloat(todayIndex) * dayWidth, y: y)
                }
            }
        }
    }

    // MARK: - Job blocks

    private var blocksOverlay: some View {
        GeometryReader { geo in
            let dayWidth = max(0, (geo.size.width - railWidth) / 7)
            ZStack(alignment: .topLeading) {
                ForEach(positionedBlocks(dayWidth: dayWidth), id: \.id) { block in
                    blockView(for: block)
                        .frame(width: max(0, dayWidth - 4), height: max(28, block.height))
                        .offset(x: block.x + 2, y: block.y)
                }
            }
        }
    }

    private func blockView(for block: PositionedBlock) -> some View {
        Button {
            onSelect(block.job)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(block.job.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                if let at = block.job.scheduledAt {
                    Text(at, format: .dateTime.hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.accentColor.opacity(0.6), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onLongPressGesture { onLongPress(block.job) }
        .accessibilityLabel("\(block.job.title), \(block.job.status)")
    }

    // MARK: - Layout helpers

    private struct PositionedBlock {
        let id: UUID
        let job: Job
        let x: CGFloat
        let y: CGFloat
        let height: CGFloat
    }

    private func positionedBlocks(dayWidth: CGFloat) -> [PositionedBlock] {
        let cal = Calendar.current
        var out: [PositionedBlock] = []
        for job in jobs {
            guard let scheduled = job.scheduledAt else { continue }
            // Find which day column (timezone-safe)
            guard let columnIndex = dayColumns.firstIndex(where: {
                cal.isDate(scheduled, inSameDayAs: $0)
            }) else { continue }

            let comps = cal.dateComponents([.hour, .minute], from: scheduled)
            let minutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
            let startMinutes = startHour * 60
            let endMinutes = endHour * 60
            // Clamp to visible range so jobs scheduled at edges still render
            let visibleMinutes = max(startMinutes, min(minutes, endMinutes - 30))
            let y = CGFloat(visibleMinutes - startMinutes) / 60.0 * hourHeight
            let duration: CGFloat = 60 // default 60 min
            let height = duration / 60.0 * hourHeight
            let x = railWidth + CGFloat(columnIndex) * dayWidth
            out.append(PositionedBlock(id: job.id, job: job, x: x, y: y, height: height))
        }
        return out
    }

    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    private func hourLabel(_ hour: Int) -> String {
        var comps = DateComponents()
        comps.hour = hour
        let cal = Calendar.current
        if let date = cal.date(from: comps) {
            let f = DateFormatter()
            f.dateFormat = "h a"
            return f.string(from: date)
        }
        return "\(hour)"
    }
}
