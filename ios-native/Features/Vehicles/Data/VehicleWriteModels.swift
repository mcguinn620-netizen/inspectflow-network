import Foundation

struct VINIntelResult: Equatable {
    let make: String?
    let model: String?
    let year: Int?
    let trim: String?
    let engine: String?
    let hasOpenRecall: Bool?
}

struct CommandMetadata {
    let actorUserId: UUID
    let timestamp: Date
    let correlationID: UUID
}

protocol VehicleRepository {
    func lookupVIN(_ vin: String) async throws -> VINIntelResult
    func enqueueCreate(from form: VehicleFormState, metadata: CommandMetadata) async throws
    func enqueueUpdate(id: UUID, from form: VehicleFormState, metadata: CommandMetadata) async throws
    func enqueueSoftDelete(id: UUID, metadata: CommandMetadata) async throws
    func enqueueRestore(id: UUID, metadata: CommandMetadata) async throws
}

@MainActor
final class OutboxVehicleRepository: VehicleRepository {
    func lookupVIN(_ vin: String) async throws -> VINIntelResult {
        // Step 3.2 scaffold: edge function integration can replace this fallback.
        _ = vin
        return VINIntelResult(make: nil, model: nil, year: nil, trim: nil, engine: nil, hasOpenRecall: nil)
    }

    func enqueueCreate(from form: VehicleFormState, metadata: CommandMetadata) async throws {
        let row = vehicleRow(form: form, metadata: metadata)
        Outbox.shared.enqueueInsert(table: "vehicles", row: row)
        AuditLogger.log(action: "create", entityType: "vehicle", entityId: row.id, changes: row.auditChanges)
    }

    func enqueueUpdate(id: UUID, from form: VehicleFormState, metadata: CommandMetadata) async throws {
        let row = vehicleRow(form: form, metadata: metadata, id: id)
        Outbox.shared.enqueueUpdate(table: "vehicles", row: row, matchColumn: "id", matchValue: id.uuidString)
        AuditLogger.log(action: "update", entityType: "vehicle", entityId: id, changes: row.auditChanges)
    }

    func enqueueSoftDelete(id: UUID, metadata: CommandMetadata) async throws {
        let row = ["deleted_at": ISO8601DateFormatter().string(from: metadata.timestamp)]
        Outbox.shared.enqueueUpdate(table: "vehicles", row: row, matchColumn: "id", matchValue: id.uuidString)
        AuditLogger.log(action: "soft_delete", entityType: "vehicle", entityId: id, changes: row)
    }

    func enqueueRestore(id: UUID, metadata: CommandMetadata) async throws {
        _ = metadata
        let row = ["deleted_at": NSNull()] as [String : Any]
        let payload = try JSONSerialization.data(withJSONObject: row)
        Outbox.shared.enqueueRaw(table: "vehicles", op: .update, payload: payload, matchColumn: "id", matchValue: id.uuidString)
        AuditLogger.log(action: "restore", entityType: "vehicle", entityId: id, changes: ["deleted_at": "null"])
    }

    private func vehicleRow(form: VehicleFormState, metadata: CommandMetadata, id: UUID = UUID()) -> VehicleWriteRow {
        VehicleWriteRow(
            id: id,
            vin: form.normalizedVIN,
            nickname: form.nickname,
            make: form.make,
            model: form.model,
            year: form.year,
            trim: form.trim,
            engine: form.engine,
            recallFlag: form.recallFlag,
            updatedAt: ISO8601DateFormatter().string(from: metadata.timestamp),
            updatedBy: metadata.actorUserId.uuidString
        )
    }
}

private struct VehicleWriteRow: Encodable {
    let id: UUID
    let vin: String
    let nickname: String
    let make: String
    let model: String
    let year: Int?
    let trim: String
    let engine: String
    let recallFlag: Bool
    let updatedAt: String
    let updatedBy: String

    enum CodingKeys: String, CodingKey {
        case id, vin, nickname, make, model, year, trim, engine
        case recallFlag = "recall_flag"
        case updatedAt = "updated_at"
        case updatedBy = "updated_by"
    }

    var auditChanges: [String: Any] {
        [
            "vin": vin,
            "nickname": nickname,
            "make": make,
            "model": model,
            "year": year as Any,
            "trim": trim,
            "engine": engine,
            "recall_flag": recallFlag,
            "updated_at": updatedAt,
            "updated_by": updatedBy,
        ]
    }
}
