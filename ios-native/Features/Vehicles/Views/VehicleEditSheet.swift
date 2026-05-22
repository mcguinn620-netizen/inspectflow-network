import SwiftUI

struct VehicleEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: VehicleEditViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("VIN", text: $viewModel.form.vin)
                        .font(.system(.body, design: .monospaced))
                    TextField("Nickname", text: $viewModel.form.nickname)
                }

                Section("Specs") {
                    TextField("Make", text: $viewModel.form.make)
                    TextField("Model", text: $viewModel.form.model)
                    TextField("Year", text: Binding(
                        get: { viewModel.form.year.map(String.init) ?? "" },
                        set: { viewModel.form.year = Int($0) }
                    ))
                }

                if viewModel.form.id != nil {
                    Section {
                        Button("Soft Delete", role: .destructive) {
                            Task { await viewModel.softDelete() }
                        }
                        if viewModel.form.isArchived {
                            Button("Restore") { Task { await viewModel.restore() } }
                        }
                    }
                }
            }
            .navigationTitle("Edit Vehicle")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.save()
                            dismiss()
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .task(id: viewModel.form.normalizedVIN) {
                await viewModel.fetchVINIntelIfNeeded()
            }
        }
    }
}
