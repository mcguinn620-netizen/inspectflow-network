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
}
