import SwiftUI

/// Detail screen for a single recorded trip. Mirrors the "Recorded Mileage" screen
/// (deduction, total miles, drive time, job category, start/end times, route map,
/// delete button) and pushes `MileageEditView` from the nav "Edit" action.
struct MileageDetailView: View {
    let trip: Trip
    let ratePerMile: Double
    let onChanged: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var points: [TripLocationPoint] = []
    @State private var isLoading = false
    @State private var isDeleting = false
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?
    @State private var liveTrip: Trip

    init(trip: Trip, ratePerMile: Double, onChanged: @escaping () -> Void) {
        self.trip = trip
        self.ratePerMile = ratePerMile
        self.onChanged = onChanged
        _liveTrip = State(initialValue: trip)
    }

    private var deduction: Double {
        MileageDeduction.amount(forMiles: liveTrip.totalMiles ?? 0, ratePerMile: ratePerMile)
    }

    private var driveTime: String {
        guard let start = liveTrip.startedAt, let end = liveTrip.completedAt else { return "—" }
        let secs = Int(end.timeIntervalSince(start))
        let minutes = secs / 60
        let seconds = secs % 60
        return "\(minutes)m \(seconds)s"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                field("Deduction",
                      value: deduction.formatted(.currency(code: "USD").precision(.fractionLength(2))),
                      valueColor: AINTheme.Color.pass,
                      valueFont: .system(size: 32, weight: .bold))
                field("Total Miles", value: String(format: "%.2f mi", liveTrip.totalMiles ?? 0))
                field("Drive Time", value: driveTime)
                field("Job Category", value: liveTrip.jobCategory?.capitalized ?? "Other")
                if let start = liveTrip.startedAt {
                    field("Start time", value: start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                }
                if let end = liveTrip.completedAt {
                    field("End time", value: end.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                }

                TripMapSnapshot(points: points, height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                if let errorMessage {
                    Text(errorMessage).font(.caption).foregroundStyle(AINTheme.Color.fail)
                }

                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    Text(isDeleting ? "Deleting…" : "Delete")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .disabled(isDeleting)
                .background(AINTheme.Color.fail.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AINTheme.Color.fail, lineWidth: 1)
                )
            }
            .padding()
        }
        .background(AINTheme.Color.background.ignoresSafeArea())
        .navigationTitle("Recorded Mileage")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    MileageEditView(trip: liveTrip) { updated in
                        liveTrip = updated
                        onChanged()
                    }
                } label: { Text("Edit") }
            }
        }
        .task { await loadPoints() }
        .confirmationDialog("Delete this trip?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await deleteTrip() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func field(_ label: String,
                       value: String,
                       valueColor: Color = AINTheme.Color.textPrimary,
                       valueFont: Font = .title3.weight(.semibold)) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.subheadline).foregroundStyle(AINTheme.Color.textSecondary)
            Text(value).font(valueFont).foregroundStyle(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadPoints() async {
        isLoading = true
        defer { isLoading = false }
        do {
            points = try await SupabaseService.shared.fetchTripLocationPoints(tripId: liveTrip.id)
        } catch {
            errorMessage = AINFriendlyError.message(for: error)
        }
    }

    private func deleteTrip() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            _ = try await SupabaseService.shared.deleteTrip(tripId: liveTrip.id)
           await AuditLogger.log(action: "delete", entityType: "trip", entityId: liveTrip.id)
            onChanged()
            dismiss()
        } catch {
            errorMessage = AINFriendlyError.message(for: error)
        }
    }
}
