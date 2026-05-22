import Foundation

@MainActor
final class VehicleDetailViewModel: ObservableObject {
    @Published var vehicle: Vehicle?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(vehicle: Vehicle) {
        self.vehicle = vehicle
        self.errorMessage = nil
    }

    func applyRealtimeUpdate(_ updated: Vehicle) {
        guard updated.id == vehicle?.id else { return }
        vehicle = updated
    }
}
