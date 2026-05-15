import SwiftUI

struct VehiclesView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = VehiclesViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.vehicles.isEmpty {
                    ContentUnavailableCompat(
                        title: "No vehicles",
                        message: viewModel.errorMessage ?? "Vehicles in your fleet appear here."
                    )
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
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { SyncStatusView() } }
            .refreshable { await viewModel.load(orgId: appState.activeOrganizationID) }
            .task { await viewModel.load(orgId: appState.activeOrganizationID) }
        }
    }
}
