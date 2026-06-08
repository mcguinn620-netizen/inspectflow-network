import SwiftUI

@MainActor
final class IntakeReviewViewModel: ObservableObject {
    @Published var data: IntakeParsedData
    @Published var isSaving = false
    @Published var error: String?

    let item: IntakeItem
    private let service = SupabaseService.shared

    init(item: IntakeItem) {
        self.item = item
        self.data = item.parsedData ?? IntakeParsedData()
    }

    func convert() async -> UUID? {
        isSaving = true; defer { isSaving = false }
        do {
            return try await service.convertIntakeItem(item: item, edited: data)
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    func convertAndAssignToMe(inspectorId: UUID) async -> Bool {
        guard let requestId = await convert() else { return false }
        isSaving = true; defer { isSaving = false }
        do {
            try await service.claimInspectionRequest(requestId: requestId, inspectorId: inspectorId)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func dismiss() async {
        do { try await service.updateIntakeItemStatus(itemId: item.id, status: "dismissed") }
        catch { self.error = error.localizedDescription }
    }
}

struct IntakeReviewView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm: IntakeReviewViewModel
    let onClose: () -> Void
    @Environment(\.dismiss) private var dismissEnv

    init(item: IntakeItem, onClose: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: IntakeReviewViewModel(item: item))
        self.onClose = onClose
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Source") {
                    LabeledContent("Channel", value: vm.item.channel)
                    if let addr = vm.item.sourceAddress { LabeledContent("From", value: addr) }
                    if let subj = vm.item.subject { LabeledContent("Subject", value: subj) }
                    if let c = vm.item.confidence {
                        LabeledContent("Confidence", value: "\(Int(c * 100))%")
                    }
                }

                Section("Customer") {
                    TextField("Client name", text: bind($vm.data.clientName))
                    TextField("Company", text: bind($vm.data.companyName))
                }

                Section("Vehicle") {
                    TextField("VIN", text: bind($vm.data.vin))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                    HStack {
                        TextField("Year", text: bind($vm.data.vehicleYear))
                        TextField("Make", text: bind($vm.data.vehicleMake))
                        TextField("Model", text: bind($vm.data.vehicleModel))
                    }
                    TextField("Mileage", text: bind($vm.data.mileage))
                        .keyboardType(.numberPad)
                }

                Section("Inspection") {
                    TextField("Location", text: bind($vm.data.inspectionLocation))
                    TextField("Requested date", text: bind($vm.data.requestedDate))
                    TextField("Type", text: bind($vm.data.inspectionType))
                    TextField("Template", text: bind($vm.data.templateName))
                    Picker("Priority", selection: Binding(
                        get: { vm.data.priority ?? "medium" },
                        set: { vm.data.priority = $0 }
                    )) {
                        Text("Low").tag("low")
                        Text("Medium").tag("medium")
                        Text("High").tag("high")
                    }
                }

                Section {
                    Button {
                        guard let uid = SupabaseService.shared.currentUserID else { return }
                        Task {
                            if await vm.convertAndAssignToMe(inspectorId: uid) { onClose() }
                        }
                    } label: {
                        Label("Convert & assign to me", systemImage: "person.fill.checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(vm.isSaving || SupabaseService.shared.currentUserID == nil)
                } footer: {
                    Text("Creates the inspection request and assigns it to you in one step.")
                        .font(.caption)
                }

                if let notes = vm.data.notes, !notes.isEmpty {
                    Section("Notes") {
                        TextEditor(text: bind($vm.data.notes))
                            .frame(minHeight: 80)
                    }
                }

                if let raw = vm.item.rawText, !raw.isEmpty {
                    Section("Original text") {
                        Text(raw).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onClose() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if vm.isSaving { ProgressView() }
                    else {
                        Button("Convert") {
                            Task {
                                if await vm.convert() != nil { onClose() }
                            }
                        }
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button(role: .destructive) {
                        Task { await vm.dismiss(); onClose() }
                    } label: { Text("Dismiss") }
                }
            }
            .alert("Error", isPresented: Binding(
                get: { vm.error != nil },
                set: { if !$0 { vm.error = nil } }
            )) { Button("OK") { vm.error = nil } } message: { Text(vm.error ?? "") }
        }
    }

    private func bind(_ source: Binding<String?>) -> Binding<String> {
        Binding(get: { source.wrappedValue ?? "" }, set: { source.wrappedValue = $0.isEmpty ? nil : $0 })
    }
}
