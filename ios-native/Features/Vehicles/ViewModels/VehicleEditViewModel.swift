import Foundation

@MainActor
final class VehicleEditViewModel: ObservableObject {
    @Published var form: VehicleFormState
    @Published var isSaving = false
    @Published var isLoadingVINIntel = false
    @Published var toastMessage: String?

    private let repository: VehicleRepository
    private let actorUserID: UUID

    init(form: VehicleFormState, repository: VehicleRepository = OutboxVehicleRepository(), actorUserID: UUID) {
        self.form = form
        self.repository = repository
        self.actorUserID = actorUserID
    }

    func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            let metadata = CommandMetadata(actorUserId: actorUserID, timestamp: Date(), correlationID: UUID())
            if let id = form.id {
                try await repository.enqueueUpdate(id: id, from: form, metadata: metadata)
            } else {
                try await repository.enqueueCreate(from: form, metadata: metadata)
            }
            toastMessage = "Vehicle queued for sync"
        } catch {
            toastMessage = "Failed to queue vehicle write"
        }
    }

    func fetchVINIntelIfNeeded() async {
        guard form.isVINLikelyValid else { return }
        isLoadingVINIntel = true
        defer { isLoadingVINIntel = false }
        do {
            let intel = try await repository.lookupVIN(form.normalizedVIN)
            form.applyVINIntel(intel)
        } catch {
            toastMessage = "VIN lookup unavailable"
        }
    }

    func softDelete() async {
        guard let id = form.id else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let metadata = CommandMetadata(actorUserId: actorUserID, timestamp: Date(), correlationID: UUID())
            try await repository.enqueueSoftDelete(id: id, metadata: metadata)
            form.isArchived = true
            toastMessage = "Vehicle moved to trash"
        } catch {
            toastMessage = "Failed to delete vehicle"
        }
    }

    func restore() async {
        guard let id = form.id else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let metadata = CommandMetadata(actorUserId: actorUserID, timestamp: Date(), correlationID: UUID())
            try await repository.enqueueRestore(id: id, metadata: metadata)
            form.isArchived = false
            toastMessage = "Vehicle restored"
        } catch {
            toastMessage = "Failed to restore vehicle"
        }
    }

    func applyScannedVIN(_ vin: String) {
        form.vin = vin.uppercased()
    }
}
