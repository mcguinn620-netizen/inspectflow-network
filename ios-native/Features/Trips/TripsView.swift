import SwiftUI

struct TripsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = TripsViewModel()
    @StateObject private var tracker = TripTrackingController.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let snap = tracker.snapshot {
                    ActiveTripBar(snapshot: snap, viewModel: viewModel)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }

                Group {
                    if viewModel.isLoading && viewModel.trips.isEmpty {
                        ProgressView("Loading trips")
                    } else if let err = viewModel.errorMessage, viewModel.trips.isEmpty {
                        ContentUnavailableCompat(title: "Couldn't load", message: err)
                    } else if viewModel.trips.isEmpty {
                        ContentUnavailableCompat(title: "No trips yet", message: "Tap + to start a trip.")
                    } else {
                        List(viewModel.trips) { trip in
                            TripRow(trip: trip)
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("Trips")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { SyncStatusView() }
                ToolbarItem(placement: .topBarLeading) {
                    if tracker.snapshot == nil, let orgId = appState.activeOrganizationID {
                        Button {
                            Task { await viewModel.startTrip(orgId: orgId) }
                        } label: { Image(systemName: "plus.circle.fill") }
                    }
                }
            }
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
        }
    }
}

private struct ActiveTripBar: View {
    let snapshot: TripTrackingController.Snapshot
    @ObservedObject var viewModel: TripsViewModel

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Circle().fill(snapshot.status == .live ? .green : .orange)
                        .frame(width: 8, height: 8)
                    Text(snapshot.status == .live ? "Live trip" : "Paused")
                        .font(.caption.bold())
                }
                Text(String(format: "%.2f mi", snapshot.totalMiles))
                    .font(.title3.monospacedDigit())
            }
            Spacer()
            if snapshot.status == .live {
                Button("Pause") { Task { await viewModel.pauseTrip() } }
            } else {
                Button("Resume") { Task { await viewModel.resumeTrip() } }
            }
            Button("End") { Task { await viewModel.completeTrip() } }
                .buttonStyle(.borderedProminent)
                .tint(.red)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct TripRow: View {
    let trip: Trip
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(trip.tripDate ?? "—").font(.headline)
                Text(trip.status.capitalized)
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f mi", trip.totalMiles ?? 0))
                    .font(.subheadline.monospacedDigit())
                if let started = trip.startedAt {
                    Text(started, style: .time).font(.caption).foregroundColor(.secondary)
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
