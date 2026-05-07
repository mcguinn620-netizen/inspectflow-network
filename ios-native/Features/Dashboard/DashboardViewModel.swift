import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var todayJobCount = 0
    @Published var activeTrip: Trip?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(orgId: UUID?, userId: UUID?) async {
        guard let userId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let trips = try await SupabaseService.shared.fetchTrips(userId: userId, limit: 5)
            activeTrip = trips.first { ["active", "paused", "planned", "draft"].contains($0.status) }
            if let orgId {
                let jobs = try await SupabaseService.shared.fetchJobs(orgId: orgId, limit: 50)
                let cal = Calendar.current
                todayJobCount = jobs.filter {
                    guard let d = $0.scheduledAt else { return false }
                    return cal.isDateInToday(d)
                }.count
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
