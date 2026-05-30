import SwiftUI

struct NextStopCard: View {
    let activeTrip: Trip?
    let nextStopData: NextStopData?
    let nextJob: Job?
    let onNavigate: () -> Void
    let onCompleteStop: () -> Void

    var body: some View {
        AINCard {
            VStack(alignment: .leading, spacing: AINTheme.Spacing.md) {
                AINSectionHeader(title: "Next stop", subtitle: "Inspector route progress")
                if activeTrip == nil {
                    Text("No active trip. Start my day to see upcoming stops.")
                        .font(AINTheme.Font.caption())
                        .foregroundColor(AINTheme.Color.textSecondary)
                } else if let title = stopTitle {
                    VStack(alignment: .leading, spacing: AINTheme.Spacing.xs) {
                        Text(title)
                            .font(AINTheme.Font.bodyEmphasized())
                            .foregroundColor(AINTheme.Color.textPrimary)
                        if let subtitle = stopSubtitle {
                            Text(subtitle)
                                .font(AINTheme.Font.caption())
                                .foregroundColor(AINTheme.Color.textSecondary)
                        }
                    }
                    HStack {
                        AINSecondaryButton("Navigate", systemImage: "location.fill", action: onNavigate)
                        AINSecondaryButton("Complete stop", systemImage: "checkmark.circle.fill", action: onCompleteStop)
                    }
                } else {
                    Text("No pending stops for this trip.")
                        .font(AINTheme.Font.caption())
                        .foregroundColor(AINTheme.Color.textSecondary)
                }
            }
        }
    }

    private var stopTitle: String? {
        nextStopData?.title ?? nextJob?.title
    }

    private var stopSubtitle: String? {
        nextStopData?.subtitle ?? nextJob?.location
    }
}
