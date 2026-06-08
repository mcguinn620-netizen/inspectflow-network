import SwiftUI

struct VehiclesView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = VehiclesViewModel()
    @State private var showCreate = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.vehicles.isEmpty {
                    VStack(spacing: 16) {
                        ContentUnavailableCompat(
                            title: "No vehicles",
                            message: viewModel.errorMessage ?? "Vehicles in your fleet appear here."
                        )
                        Button {
                            showCreate = true
                        } label: {
                            Label("Add vehicle", systemImage: "plus")
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List(viewModel.vehicles) { v in
                        VStack(alignment: .leading) {
                            Text([v.year.map(String.init), v.make, v.model].compactMap { $0 }.joined(separator: " "))
                                .font(.headline)
                            if let vin = v.vin {
                                Text(vin).font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Vehicles")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { SyncStatusView() }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add vehicle")
                }
            }
            .sheet(isPresented: $showCreate, onDismiss: {
                Task { await viewModel.load(orgId: appState.activeOrganizationID) }
            }) {
                if let uid = SupabaseService.shared.currentUserID {
                    VehicleEditSheet(
                        viewModel: VehicleEditViewModel(
                            form: .empty,
                            actorUserID: uid
                        )
                    )
                } else {
                    Text("Sign in required").padding()
                }
            }
            .refreshable { await viewModel.load(orgId: appState.activeOrganizationID) }
            .task { await viewModel.load(orgId: appState.activeOrganizationID) }
        }
    }
}
