import SwiftUI

struct ActiveTripBanner: View {
    let activeTrip: Trip?

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
                    AINSecondaryButton("Pause", systemImage: "pause.fill") {}
                    NavigationLink("Open trips", destination: TripsView())
                }
            }
        }
    }
}
