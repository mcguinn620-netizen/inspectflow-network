import SwiftUI

struct InspectionsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = InspectionsViewModel()
    @State private var showCreate = false

    private var filtered: [InspectionRequest] { viewModel.requests }


    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Scope", selection: $scope) {
                    Text("All in org").tag("all")
                    Text("Assigned to me").tag("mine")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Group {
                    if filtered.isEmpty {
                        VStack(spacing: 16) {
                            ContentUnavailableCompat(
                                title: "No inspection requests",
                                message: viewModel.errorMessage ?? "Incoming inspection requests will appear here."
                            )
                            Button {
                                showCreate = true
                            } label: {
                                Label("New inspection request", systemImage: "plus")
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        List(filtered) { r in
                            NavigationLink(value: r) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(r.status.replacingOccurrences(of: "_", with: " ").capitalized)
                                            .font(.headline)
                                        if let d = r.scheduledAt ?? r.createdAt {
                                            Text(d, style: .date)
                                                .font(.caption).foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Inspections")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { SyncStatusView() }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showCreate = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("New inspection request")
                }
            }
            .navigationDestination(for: InspectionRequest.self) { req in
                if let orgId = appState.activeOrganizationID {
                    InspectionDetailView(request: req, orgId: orgId)
                }
            }
            .sheet(isPresented: $showCreate, onDismiss: {
                Task { await viewModel.load(orgId: appState.activeOrganizationID) }
            }) {
                if let orgId = appState.activeOrganizationID {
                    InspectionRequestCreateSheet(orgId: orgId)
                } else {
                    Text("No organization selected").padding()
                }
            }
            .refreshable { await viewModel.load(orgId: appState.activeOrganizationID) }
            .task { await viewModel.load(orgId: appState.activeOrganizationID) }
        }
    }
}

private struct InspectionRequestCreateSheet: View {
    let orgId: UUID
    @Environment(\.dismiss) private var dismiss

    @State private var clientName = ""
    @State private var vin = ""
    @State private var year = ""
    @State private var make = ""
    @State private var model = ""
    @State private var location = ""
    @State private var requestedDate = Date()
    @State private var template = "Standard Inspection"
    @State private var priority = "medium"
    @State private var isSaving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Client") {
                    TextField("Client name", text: $clientName)
                }
                Section("Vehicle") {
                    TextField("VIN", text: $vin)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                    HStack {
                        TextField("Year", text: $year).keyboardType(.numberPad)
                        TextField("Make", text: $make)
                        TextField("Model", text: $model)
                    }
                }
                Section("Inspection") {
                    TextField("Location", text: $location)
                    DatePicker("Requested date", selection: $requestedDate, displayedComponents: .date)
                    TextField("Template", text: $template)
                    Picker("Priority", selection: $priority) {
                        Text("Low").tag("low")
                        Text("Medium").tag("medium")
                        Text("High").tag("high")
                    }
                }
            }
            .navigationTitle("New Inspection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving { ProgressView() }
                    else { Button("Create") { Task { await create() } } }
                }
            }
            .alert("Error", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK") { error = nil }
            } message: { Text(error ?? "") }
        }
    }

    private func create() async {
        isSaving = true; defer { isSaving = false }
        do {
            _ = try await SupabaseService.shared.createInspectionRequest(
                orgId: orgId,
                clientName: clientName.isEmpty ? nil : clientName,
                vin: vin.isEmpty ? nil : vin.uppercased(),
                vehicleYear: year.isEmpty ? nil : year,
                vehicleMake: make.isEmpty ? nil : make,
                vehicleModel: model.isEmpty ? nil : model,
                inspectionLocation: location.isEmpty ? nil : location,
                requestedDate: requestedDate,
                templateName: template.isEmpty ? "Standard Inspection" : template,
                priority: priority
            )
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
