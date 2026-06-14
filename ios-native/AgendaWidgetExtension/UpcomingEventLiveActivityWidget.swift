import SwiftUI
import WidgetKit
#if canImport(ActivityKit)
import ActivityKit
#endif

#if canImport(ActivityKit)
@available(iOS 16.1, *)
struct UpcomingEventLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: UpcomingEventActivityAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
                .padding(12)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "calendar")
                        .imageScale(.large)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                        .font(.caption2.monospacedDigit())
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title).font(.headline).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let location = context.state.location, !location.isEmpty {
                        Label(location, systemImage: "mappin.and.ellipse")
                            .font(.caption)
                    }
                }
            } compactLeading: {
                Image(systemName: "calendar")
            } compactTrailing: {
                Text(context.state.startDate, style: .time)
                    .font(.caption2.monospacedDigit())
            } minimal: {
                Image(systemName: "calendar")
            }
        }
    }
}

@available(iOS 16.1, *)
private struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<UpcomingEventActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.title).font(.headline).lineLimit(1)
                Text(context.attributes.calendarTitle)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                if let location = context.state.location, !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(context.state.startDate, style: .time)
                    .font(.subheadline.monospacedDigit())
                Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}
#endif
