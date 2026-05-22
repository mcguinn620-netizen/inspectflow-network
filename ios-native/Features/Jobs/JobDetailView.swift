import SwiftUI

struct JobDetailView: View {
    let job: Job

    @State private var showEditSheet = false

    var body: some View {
        List {
            Section("Customer") {
                LabeledContent("Name", value: job.customerName ?? "Unassigned")
            }

            Section("Vehicle") {
                LabeledContent("Job", value: job.title)
            }

            Section("Schedule") {
                LabeledContent("Status", value: job.status.capitalized)
                if let scheduledAt = job.scheduledAt {
                    LabeledContent("Scheduled", value: scheduledAt.formatted(date: .abbreviated, time: .shortened))
                } else {
                    LabeledContent("Scheduled", value: "Not scheduled")
                }
            }

            Section("Location") {
                if let location = job.location {
                    Text(location)
                    OpenInMapsButton(address: location)
                } else {
                    Text("No location set")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Quick Actions") {
                Button("Start Inspection") {}
                Button("Navigate") {}
                Button("Call") {}
                Button("Mark Complete") {}
            }
        }
        .navigationTitle("Job Details")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            JobEditSheet(job: job)
        }
    }
}
