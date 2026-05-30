import SwiftUI

struct ActiveTripBanner: View {
    let activeTrip: Trip?
    let onPauseTrip: () -> Void

    var body: some View {
        if let activeTrip {
            AINCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Active trip")
                            .font(AINTheme.Font.caption())
                            .foregroundColor(AINTheme.Color.textSecondary)
                        Text(activeTrip.status.capitalized)
                            .font(AINTheme.Font.bodyEmphasized())
                            .foregroundColor(AINTheme.Color.textPrimary)
                    }
                    Spacer()
                    AINSecondaryButton("Pause", systemImage: "pause.fill", action: onPauseTrip)
                    NavigationLink("Open trips", destination: TripsView())
                }
            }
        }
    }
}
