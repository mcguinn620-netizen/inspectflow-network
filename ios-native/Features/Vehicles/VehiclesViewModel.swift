import Foundation

@MainActor
final class VehiclesViewModel: ObservableObject {
    @Published var vehicles: [Vehicle] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(orgId: UUID?) async {
        guard let orgId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            vehicles = try await SupabaseService.shared.fetchVehicles(orgId: orgId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
