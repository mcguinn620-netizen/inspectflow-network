import SwiftUI

struct JobCreateView: View {

    let orgId: UUID

    @Environment(\.dismiss)
    private var dismiss

    @StateObject
    private var viewModel =
        JobCreateViewModel()

    var body: some View {

        NavigationStack {

            Form {

                Section("Job") {

                    TextField(
                        "Inspection Type",
                        text: $viewModel.title
                    )

                    TextField(
                        "Customer Name",
                        text: $viewModel.customerName
                    )
                }

                Section("Location") {

                    TextField(
                        "Address",
                        text: $viewModel.location
                    )
                }

                Section("Schedule") {

                    DatePicker(
                        "Appointment",
                        selection:
                            $viewModel.scheduledAt
                    )
                }
            }
            .navigationTitle("New Job")
            .toolbar {

                ToolbarItem(
                    placement:
                        .navigationBarLeading
                ) {

                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(
                    placement:
                        .navigationBarTrailing
                ) {

                    Button("Save") {

                        Task {

                            let success =
                                await viewModel.save(
                                    orgId: orgId
                                )

                            if success {
                                dismiss()
                            }
                        }
                    }
                    .disabled(
                        viewModel.title.isEmpty
                    )
                }
            }
        }
    }
}