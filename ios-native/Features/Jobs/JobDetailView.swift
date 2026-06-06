import SwiftUI

struct JobDetailView: View {
    let job: Job
    let onMarkComplete: (Job) -> Void
    let onReschedule: (Job, Date) -> Void

    @State private var showEditSheet = false
    @State private var actionMessage: String?

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
                Button("Start Inspection") {
                    actionMessage =
                        "Open this job from Inspections to start the checklist."
                }

                Button("Navigate") {
                    MapsLookupService.shared.open(job: job)
                }

                Button("Add To Calendar") {
                    Task {
                        let success =
                            await CalendarSyncService.shared.sync(
                                job: job
                            )

                        actionMessage = success
                            ? "Added to Calendar"
                            : "Unable to add event"
                    }
                }

                Button("Call") {
                    actionMessage =
                        "Customer phone is not attached to this job yet."
                }

                Button("Mark Complete") {
                    onMarkComplete(job)
                }
            }
        }
        .navigationTitle("Job Details")
        .toolbar {
            ToolbarItemGroup(
                placement: .navigationBarTrailing
            ) {
                Button("Edit") {
                    showEditSheet = true
                }

                Button {
                    Task {
                        let success =
                            await CalendarSyncService.shared.sync(
                                job: job
                            )

                        actionMessage = success
                            ? "Added to Calendar"
                            : "Unable to add event"
                    }

                } label: {
                    Image(
                        systemName: "calendar.badge.plus"
                    )
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            JobEditSheet(job: job) { scheduledAt, _ in
                onReschedule(job, scheduledAt)
            }
        }
        .alert("Job action", isPresented: Binding(get: { actionMessage != nil }, set: { if !$0 { actionMessage = nil } })) {
            Button("OK") { actionMessage = nil }
        } message: {
            Text(actionMessage ?? "")
        }
    }
}
