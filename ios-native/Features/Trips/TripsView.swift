import SwiftUI

struct TripsView: View {
    @StateObject private var viewModel = TripsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.trips.isEmpty {
                    ProgressView("Loading trips")
                } else if let err = viewModel.errorMessage, viewModel.trips.isEmpty {
                    ContentUnavailableCompat(title: "Couldn't load", message: err)
                } else if viewModel.trips.isEmpty {
                    ContentUnavailableCompat(title: "No trips yet", message: "Start a trip from the dashboard.")
                } else {
                    List(viewModel.trips) { trip in
                        TripRow(trip: trip)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Trips")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { SyncStatusView() } }
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
        }
    }
}

private struct TripRow: View {
    let trip: Trip

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(trip.tripDate ?? "—").font(.headline)
                Text(trip.status.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f mi", trip.totalMiles ?? 0))
                    .font(.subheadline.monospacedDigit())
                if let started = trip.startedAt {
                    Text(started, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ContentUnavailableCompat: View {
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 8) {
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
