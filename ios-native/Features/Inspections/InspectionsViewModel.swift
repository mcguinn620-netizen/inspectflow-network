import Foundation

@MainActor
final class InspectionsViewModel: ObservableObject {
    @Published var requests: [InspectionRequest] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(orgId: UUID?) async {
        guard let orgId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            requests = try await SupabaseService.shared.fetchInspectionRequests(orgId: orgId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
