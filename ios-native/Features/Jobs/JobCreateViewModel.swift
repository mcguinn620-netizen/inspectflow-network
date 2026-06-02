import Foundation

@MainActor
final class JobCreateViewModel: ObservableObject {

    @Published var title = ""
    @Published var customerName = ""
    @Published var location = ""
    @Published var scheduledAt = Date()

    @Published var isSaving = false
    @Published var errorMessage: String?

    func save(
        orgId: UUID
    ) async -> Bool {

        isSaving = true
        defer { isSaving = false }

        do {

            let job =
                try await SupabaseService.shared.createJob(
                    orgId: orgId,
                    title: title,
                    customerName: customerName,
                    location: location,
                    scheduledAt: scheduledAt
                )

            _ = await CalendarSyncService.shared.sync(
                job: job
            )

            return true

        } catch {

            errorMessage =
                error.localizedDescription

            return false
        }
    }
}