import SwiftUI

/// Edit screen for an existing trip — mirrors the "Recorded Mileage / Edit" layout:
/// Drive Time (read-only derived), Job Category picker, Start time, End time.
/// Writes back via `SupabaseService.updateTrip` and reports the updated record
/// back to the caller via `onSave`.
struct MileageEditView: View {
    private static let categories = ["Other", "Commute", "Client Visit", "Errand", "Maintenance"]

    let trip: Trip
    let onSave: (Trip) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var jobCategory: String
    @State private var startedAt: Date
    @State private var completedAt: Date
    @State private var note: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(trip: Trip, onSave: @escaping (Trip) -> Void) {
        self.trip = trip
        self.onSave = onSave
        _jobCategory = State(initialValue: trip.jobCategory ?? "Other")
        _startedAt = State(initialValue: trip.startedAt ?? Date())
        _completedAt = State(initialValue: trip.completedAt ?? Date())
        _note = State(initialValue: trip.note ?? "")
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Drive Time", value: driveTimeText)
            }
            Section("Job Category") {
                Picker("Job Category", selection: $jobCategory) {
                    ForEach(Self.categories, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
            }
            Section("Start time") {
                DatePicker("Start time", selection: $startedAt)
                    .labelsHidden()
            }
            Section("End time") {
                DatePicker("End time", selection: $completedAt)
                    .labelsHidden()
            }
            Section("Note") {
                TextField("Add a note (optional)", text: $note, axis: .vertical)
                    .lineLimit(3...6)
            }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(AINTheme.Color.fail)
            }
        }
        .navigationTitle("Edit Mileage")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isSaving ? "Saving…" : "Save") { Task { await save() } }
                    .disabled(isSaving)
            }
        }
    }

    private var driveTimeText: String {
        let secs = max(0, Int(completedAt.timeIntervalSince(startedAt)))
        return "\(secs / 60)m \(secs % 60)s"
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let iso = ISO8601DateFormatter()
        var fields: [String: Any] = [
            "job_category": jobCategory,
            "started_at": iso.string(from: startedAt),
            "completed_at": iso.string(from: completedAt),
        ]
        fields["note"] = note.isEmpty ? NSNull() : note
        do {
            _ = try await SupabaseService.shared.updateTrip(tripId: trip.id, fields: fields)
            AuditLogger.log(action: "update", entityType: "trip", entityId: trip.id,
                            changes: ["job_category": jobCategory])
            let updated = Trip(
                id: trip.id, userID: trip.userID, organizationID: trip.organizationID,
                tripDate: trip.tripDate, status: trip.status, totalMiles: trip.totalMiles,
                startedAt: startedAt, pausedAt: trip.pausedAt, completedAt: completedAt,
                createdAt: trip.createdAt, note: note.isEmpty ? nil : note, jobCategory: jobCategory
            )
            onSave(updated)
            dismiss()
        } catch {
            errorMessage = AINFriendlyError.message(for: error)
        }
    }
}
