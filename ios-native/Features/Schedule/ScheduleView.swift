import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = JobsViewModel()
    @State private var selectedWeekStart = Date.startOfWeek(for: Date())
    @State private var selectedJobID: UUID?
    @State private var draggingJobID: UUID?
    @State private var dispatchTargetJob: Job?
    @State private var bannerMessage: String?

    private var dayColumns: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: selectedWeekStart) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.jobs.isEmpty {
                    ProgressView()
                } else if viewModel.jobs.isEmpty {
                    ContentUnavailableCompat(
                        title: "No jobs this week",
                        message: viewModel.errorMessage ?? "Scheduled jobs appear in this week grid."
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                            ForEach(dayColumns, id: \.self) { day in
                                DayHeader(day: day)
                            }

                            ForEach(dayColumns, id: \.self) { day in
                                dayCell(for: day)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
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
                DispatcherAssignSheet(job: job) { inspectorId in
                    Task { await viewModel.assign(job: job, inspectorId: inspectorId, orgId: appState.activeOrganizationID) }
                }
            }
            .alert("Schedule", isPresented: Binding(get: { bannerMessage != nil }, set: { if !$0 { bannerMessage = nil } })) {
                Button("OK") { bannerMessage = nil }
            } message: {
                Text(bannerMessage ?? "")
            }
            .refreshable { await viewModel.load(orgId: appState.activeOrganizationID) }
            .task { await viewModel.load(orgId: appState.activeOrganizationID) }
        }
    }

    private var hasConflicts: Bool {
        let grouped = Dictionary(grouping: viewModel.jobs.compactMap { job -> (Date, UUID)? in
            guard let date = job.scheduledAt else { return nil }
            return (Calendar.current.startOfDay(for: date), job.id)
        }, by: { $0.0 })
        return grouped.values.contains { $0.count > 8 }
    }

    @ViewBuilder
    private func dayCell(for day: Date) -> some View {
        let jobs = viewModel.jobs.filter { job in
            guard let scheduled = job.scheduledAt else { return false }
            return Calendar.current.isDate(scheduled, inSameDayAs: day)
        }

        VStack(alignment: .leading, spacing: 6) {
            ForEach(jobs) { job in
                ScheduleJobPill(job: job, isDragging: draggingJobID == job.id)
                    .onTapGesture { selectedJobID = job.id }
                    .onLongPressGesture { draggingJobID = job.id }
                    .contextMenu {
                        Button("Sync to device calendar") {
                            Task {
                                let synced = await CalendarSyncService.shared.sync(job: job)
                                bannerMessage = synced ? "Synced to Calendar" : "Unable to sync with Calendar"
                            }
                        }
                        Button("Open with Apple Maps") {
                            MapsLookupService.shared.open(job: job)
                        }
                    }
            }
            Spacer(minLength: 36)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(selectedJobID != nil ? Color.accentColor.opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .contextMenu {
            if isDispatcher {
                Button("Assign to inspector") {
                    if let first = jobs.first { dispatchTargetJob = first }
                }
            }
            if draggingJobID != nil {
                Button("Move first job here") {
                    Task { await moveDraggedJob(to: day) }
                }
            }
        }
    }

    private var isDispatcher: Bool {
        guard case .signedIn = appState.authState else { return false }
        return true
    }

    private func moveDraggedJob(to day: Date) async {
        guard let draggedJobID = draggingJobID else { return }
        self.draggingJobID = nil
        guard let index = viewModel.jobs.firstIndex(where: { $0.id == draggedJobID }) else { return }
        let source = viewModel.jobs[index]
        let mergedDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: day)
        if let mergedDate {
            await viewModel.reschedule(job: source, scheduledAt: mergedDate, orgId: appState.activeOrganizationID)
        }
    }
}

private struct DayHeader: View {
    let day: Date

    var body: some View {
        VStack(spacing: 2) {
            Text(day, format: .dateTime.weekday(.abbreviated))
                .font(.caption)
                .foregroundColor(.secondary)
            Text(day, format: .dateTime.day())
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ScheduleJobPill: View {
    let job: Job
    let isDragging: Bool

    var body: some View {
        HStack {
            Text(job.title)
                .font(.caption)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(job.status)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(6)
        .background(Capsule().fill(isDragging ? Color.accentColor.opacity(0.25) : Color.blue.opacity(0.12)))
        .accessibilityLabel("\(job.title), status \(job.status)")
    }
}

private struct DispatcherAssignSheet: View {
    let job: Job
    let onAssign: (UUID) -> Void
    @State private var inspectorIDText = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Dispatch") {
                    Text("Assign \(job.title) by entering an inspector UUID from the dispatcher roster.")
                    TextField("Inspector UUID", text: $inspectorIDText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Assign inspector") {
                        guard let inspectorId = UUID(uuidString: inspectorIDText.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
                        onAssign(inspectorId)
                    }
                }
            }
            .navigationTitle("Assign Inspector")
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
