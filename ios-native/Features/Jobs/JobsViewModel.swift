import Foundation
import InspectFlowConnector

@MainActor
final class JobsViewModel: ObservableObject {
    @Published var jobs: [Job] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var realtime: RealtimeSubscription?

    func load(orgId: UUID?) async {
        guard let orgId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            jobs = try await SupabaseService.shared.fetchJobs(orgId: orgId)
            errorMessage = nil
            await ensureRealtime(orgId: orgId)
        } catch {
            errorMessage = AINFriendlyError.message(for: error)
        }
    }

    /// Scoped load for the Schedule week grid: pulls jobs in `[weekStart, weekStart+7d)`.
    func loadForWeek(_ weekStart: Date, orgId: UUID?) async {
        guard let orgId else { return }
        let end = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        isLoading = true
        defer { isLoading = false }
        do {
            jobs = try await SupabaseService.shared.fetchJobs(orgId: orgId, from: weekStart, to: end)
            errorMessage = nil
            await ensureRealtime(orgId: orgId)
        } catch {
            errorMessage = AINFriendlyError.message(for: error)
        }
    }

    private func ensureRealtime(orgId: UUID) async {
        guard realtime == nil else { return }
        realtime = await RealtimeSubscriptions.jobs(orgId: orgId) { [weak self] _ in
            Task { @MainActor in await self?.load(orgId: orgId) }
        }
    }

    func reschedule(job: Job, scheduledAt: Date, orgId: UUID?) async {
        do {
            try await SupabaseService.shared.updateJobSchedule(jobId: job.id, scheduledAt: scheduledAt)
            let updatedJob = Job(
                id: job.id,
                title: job.title,
                customerName: job.customerName,
                location: job.location,
                scheduledAt: scheduledAt,
                status: job.status
            )
            _ = await CalendarSyncService.shared.sync(job: updatedJob)
            await load(orgId: orgId)
        } catch {
            errorMessage = AINFriendlyError.message(for: error)
        }
    }

    func assign(job: Job, inspectorId: UUID, orgId: UUID?) async {
        do {
            try await SupabaseService.shared.assignJob(jobId: job.id, inspectorId: inspectorId)
            _ = await CalendarSyncService.shared.sync(job: job)
            await load(orgId: orgId)
        } catch {
            errorMessage = AINFriendlyError.message(for: error)
        }
    }

    func markComplete(job: Job, orgId: UUID?) async {
        do {
            try await SupabaseService.shared.updateJobStatus(jobId: job.id, status: "completed")
            let completedJob = Job(
                id: job.id,
                title: job.title,
                customerName: job.customerName,
                location: job.location,
                scheduledAt: job.scheduledAt,
                status: "completed"
            )
            _ = await CalendarSyncService.shared.sync(job: completedJob)
            await load(orgId: orgId)
        } catch {
            errorMessage = AINFriendlyError.message(for: error)
        }
    }
}
