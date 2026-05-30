import Foundation

@MainActor
final class JobsViewModel: ObservableObject {
    @Published var jobs: [Job] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(orgId: UUID?) async {
        guard let orgId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            jobs = try await SupabaseService.shared.fetchJobs(orgId: orgId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reschedule(job: Job, scheduledAt: Date, orgId: UUID?) async {
        do {
            try await SupabaseService.shared.updateJobSchedule(jobId: job.id, scheduledAt: scheduledAt)
            await load(orgId: orgId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func assign(job: Job, inspectorId: UUID, orgId: UUID?) async {
        do {
            try await SupabaseService.shared.assignJob(jobId: job.id, inspectorId: inspectorId)
            await load(orgId: orgId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markComplete(job: Job, orgId: UUID?) async {
        do {
            try await SupabaseService.shared.updateJobStatus(jobId: job.id, status: "completed")
            await load(orgId: orgId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

}
