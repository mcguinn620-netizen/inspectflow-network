import SwiftUI

struct NextStopCard: View {
    let activeTrip: Trip?

    var body: some View {
        AINCard {
            VStack(alignment: .leading, spacing: AINTheme.Spacing.md) {
                AINSectionHeader(title: "Next stop", subtitle: "Inspector route progress")
                if activeTrip == nil {
                    Text("No active trip. Start my day to see upcoming stops.")
                        .font(AINTheme.Font.caption())
                        .foregroundColor(AINTheme.Color.textSecondary)
                } else {
                    HStack {
                        AINSecondaryButton("Navigate", systemImage: "location.fill") {}
                        AINSecondaryButton("Complete stop", systemImage: "checkmark.circle.fill") {}
                    }
                }
            }
        }
    }
}
