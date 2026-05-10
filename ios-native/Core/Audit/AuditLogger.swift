import Foundation

/// Writes audit_log rows for every CUD action. Goes through the Outbox so it survives offline.
@MainActor
enum AuditLogger {
    static func log(action: String, entityType: String, entityId: UUID, changes: [String: Any]? = nil) {
        let userId = SupabaseService.shared.currentUserID?.uuidString
        var row: [String: Any] = [
            "action": action,
            "entity_type": entityType,
            "entity_id": entityId.uuidString,
        ]
        if let userId { row["user_id"] = userId }
        if let changes {
            row["changes"] = changes
        }
        let payload = (try? JSONSerialization.data(withJSONObject: row)) ?? Data("{}".utf8)
        Outbox.shared.enqueueRaw(table: "audit_log", op: .insert, payload: payload)
    }
}
