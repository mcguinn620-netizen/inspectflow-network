import SwiftUI

struct JobEditSheet: View {
    let job: Job
    var onSave: ((Date, String) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var scheduledAt = Date()
    @State private var assignee = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Reschedule", selection: $scheduledAt)
                TextField("Reassign to", text: $assignee)
                    .textInputAutocapitalization(.words)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
            .navigationTitle("Edit Job")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave?(scheduledAt, assignee.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let currentDate = job.scheduledAt {
                    scheduledAt = currentDate
                }
            }
        }
    }
}
