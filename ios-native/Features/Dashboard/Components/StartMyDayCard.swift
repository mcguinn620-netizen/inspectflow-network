import SwiftUI

struct StartMyDayCard: View {
    let hasJobsToday: Bool
    let todayJobCount: Int
    let activeTrip: Trip?
    let onStartTodayTrip: () -> Void

    var body: some View {
        AINCard {
            VStack(alignment: .leading, spacing: AINTheme.Spacing.md) {
                AINSectionHeader(title: "Start my day", subtitle: subtitle)
                if let activeTrip {
                    Text(activeTrip.status == "paused" ? "Resume trip when ready." : "Trip already active.")
                        .font(AINTheme.Font.caption())
                        .foregroundColor(AINTheme.Color.textSecondary)
                    AINSecondaryButton("Resume trip", systemImage: "play.fill", action: onStartTodayTrip)
                } else if hasJobsToday {
                    Text("You have \(todayJobCount) jobs today.")
                        .font(AINTheme.Font.caption())
                        .foregroundColor(AINTheme.Color.textSecondary)
                    AINPrimaryButton("Start my day", systemImage: "sun.max.fill", action: onStartTodayTrip)
                } else {
                    Text("No jobs yet. Open schedule to plan your route.")
                        .font(AINTheme.Font.caption())
                        .foregroundColor(AINTheme.Color.textSecondary)
                    NavigationLink("Open schedule", destination: ScheduleView())
                }
            }
        }
    }

    private var subtitle: String {
        hasJobsToday ? "Plan, start, and complete your stops." : "Set up your day before the first stop."
    }
}
