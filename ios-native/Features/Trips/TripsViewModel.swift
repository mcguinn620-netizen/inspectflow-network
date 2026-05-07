import Foundation

@MainActor
final class TripsViewModel: ObservableObject {
    @Published var trips: [Trip] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        guard let uid = SupabaseService.shared.currentUserID else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            trips = try await SupabaseService.shared.fetchTrips(userId: uid)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
