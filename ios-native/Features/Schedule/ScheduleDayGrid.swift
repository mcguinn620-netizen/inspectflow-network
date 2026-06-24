import SwiftUI
import EventKit

/// Native single-day timeline grid with an Apple Calendar-inspired layout.
/// Keeps the existing EventKit / Job integration while changing only the
/// rendering to a denser 24-hour timeline with overlap lanes.
struct ScheduleDayGrid: View {

    let date: Date
    let events: [EKEvent]
    let jobs: [Job]
    var coordinator: EventDropCoordinator? = nil
    var onSelectEvent: (EKEvent) -> Void = { _ in }
    var onSelectJob: (Job) -> Void = { _ in }

    @State private var dropHighlight: Date?

    private let startHour = NativeCalendarMetrics.startHour
    private let endHour = NativeCalendarMetrics.endHour
    private let hourHeight: CGFloat = NativeCalendarMetrics.hourHeight
    private let railWidth: CGFloat = NativeCalendarMetrics.railWidth
    private let snapMinutes = 15

    private var hours: [Int] { Array(startHour..<endHour) }

    private var timelineHeight: CGFloat {
        CGFloat(endHour - startHour) * hourHeight
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                dayHeader
                GeometryReader { geo in
                    let width = max(0, geo.size.width)
                    timeline(width: width)
                        .frame(height: timelineHeight)
                }
                .frame(height: timelineHeight)
            }
        }
        .background(NativeCalendarMetrics.sidebarBackground)
    }

    private var dayHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(date, format: .dateTime.weekday(.wide))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(date, format: .dateTime.month(.wide).day())
                    .font(.system(size: 34, weight: .bold, design: .default))
                    .foregroundStyle(.primary)

                if Calendar.current.isDateInToday(date) {
                    Text("Today")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.red.opacity(0.12)))
                        .foregroundStyle(.red)
                }
            }

            Text(date, format: .dateTime.year())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, NativeCalendarMetrics.dayHeaderPadding)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.thinMaterial)
        .overlay(Divider(), alignment: .bottom)
    }

    @ViewBuilder
    private func timeline(width: CGFloat) -> some View {
        let contentWidth = max(0, width - railWidth)
        let placements = NativeCalendarLayoutEngine.placements(
            for: date,
            events: events,
            jobs: jobs,
            startHour: startHour,
            endHour: endHour,
            hourHeight: hourHeight
        )

        HStack(spacing: 0) {
            hourRail
                .frame(width: railWidth, height: timelineHeight, alignment: .top)

            dayBody(width: contentWidth, placements: placements)
        }
        .frame(width: width, height: timelineHeight, alignment: .topLeading)
        .background(Color(.systemBackground))
    }

    private var hourRail: some View {
        VStack(spacing: 0) {
            ForEach(hours, id: \.self) { hour in
                HStack(spacing: 0) {
                    Text(hourLabel(hour))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: railWidth - 10, alignment: .trailing)
                        .padding(.trailing, 8)
                        .offset(y: -6)

                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(.secondary.opacity(NativeCalendarMetrics.majorLineOpacity))
                            .frame(height: 0.5)

                        Rectangle()
                            .fill(.secondary.opacity(NativeCalendarMetrics.minorLineOpacity))
                            .frame(height: 0.5)
                            .offset(y: hourHeight / 2)

                        Spacer(minLength: 0)
                    }
                }
                .frame(height: hourHeight, alignment: .top)
            }
        }
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private func dayBody(
        width: CGFloat,
        placements: [NativeCalendarTimelinePlacement]
    ) -> some View {
        let lineWidth = max(0, width)
        let laneGap = NativeCalendarMetrics.laneGap

        ZStack(alignment: .topLeading) {
            hourGrid(width: lineWidth)

            if let highlight = dropHighlight,
               Calendar.current.isDate(highlight, inSameDayAs: date) {
                let y = yOffset(for: highlight)
                Rectangle()
                    .fill(Color.accentColor.opacity(0.16))
                    .frame(width: lineWidth, height: CGFloat(snapMinutes) / 60.0 * hourHeight)
                    .offset(y: y)
            }

            ForEach(placements) { placement in
                timelineCard(placement)
                    .frame(
                        width: laneWidth(for: placement, width: lineWidth, gap: laneGap),
                        height: placement.height,
                        alignment: .topLeading
                    )
                    .offset(
                        x: xOffset(for: placement, width: lineWidth, gap: laneGap),
                        y: placement.y
                    )
            }

            if let y = nowLineY(), Calendar.current.isDateInToday(date) {
                NativeNowIndicator()
                    .frame(width: lineWidth)
                    .offset(y: y)
            }

            dropTarget(width: lineWidth)
        }
        .frame(width: width, height: timelineHeight, alignment: .topLeading)
        .contentShape(Rectangle())
    }

    private func dropTarget(width: CGFloat) -> some View {
        Group {
            if let coordinator {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: width, height: timelineHeight)
                    .contentShape(Rectangle())
                    .onDrop(
                        of: [EventDragPayload.utType],
                        delegate: TimeColumnDropDelegate(
                            date: date,
                            startHour: startHour,
                            endHour: endHour,
                            hourHeight: hourHeight,
                            snapMinutes: snapMinutes,
                            coordinator: coordinator,
                            highlight: $dropHighlight
                        )
                    )
            }
        }
    }

    private func hourGrid(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(hours, id: \.self) { _ in
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(.secondary.opacity(NativeCalendarMetrics.majorLineOpacity))
                        .frame(height: 0.5)

                    Rectangle()
                        .fill(.secondary.opacity(NativeCalendarMetrics.minorLineOpacity))
                        .frame(height: 0.5)
                        .offset(y: hourHeight / 2)

                    Spacer(minLength: 0)
                }
                .frame(height: hourHeight, alignment: .top)
            }
        }
        .frame(width: width, height: timelineHeight, alignment: .topLeading)
    }

    @ViewBuilder
    private func timelineCard(_ placement: NativeCalendarTimelinePlacement) -> some View {
        let content = Button {
            switch placement.kind {
            case .event(let event):
                onSelectEvent(event)
            case .job(let job):
                onSelectJob(job)
            }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Circle()
                        .fill(placement.baseColor)
                        .frame(width: 6, height: 6)

                    Text(cardTitle(for: placement))
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                }

                if let subtitle = cardSubtitle(for: placement) {
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: NativeCalendarMetrics.eventCornerRadius, style: .continuous)
                    .fill(placement.baseColor.opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: NativeCalendarMetrics.eventCornerRadius, style: .continuous)
                    .strokeBorder(placement.baseColor.opacity(0.28), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.03), radius: 1, x: 0, y: 0.5)
        }
        .buttonStyle(.plain)
        .opacity(placement.isReadOnly ? 0.78 : 1.0)

        switch placement.kind {
        case .event(let event):
            content.onDrag {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                return EventDragPayload(event: event).itemProvider()
            }
        case .job:
            content
        }
    }

    private func cardTitle(for placement: NativeCalendarTimelinePlacement) -> String {
        switch placement.kind {
        case .event(let event):
            return event.title?.isEmpty == false ? (event.title ?? "Untitled") : "Untitled"
        case .job(let job):
            return job.title
        }
    }

    private func cardSubtitle(for placement: NativeCalendarTimelinePlacement) -> String? {
        let formatter = Self.timeFormatter
        switch placement.kind {
        case .event(let event):
            return "\(formatter.string(from: event.startDate)) – \(formatter.string(from: event.endDate))"
        case .job(let job):
            guard let start = job.scheduledAt else { return nil }
            return formatter.string(from: start)
        }
    }

    private func laneWidth(
        for placement: NativeCalendarTimelinePlacement,
        width: CGFloat,
        gap: CGFloat
    ) -> CGFloat {
        let columns = max(1, placement.totalColumns)
        let gaps = CGFloat(max(0, columns - 1)) * gap
        return max(
            44,
            (width - gaps) / CGFloat(columns)
        )
    }

    private func xOffset(
        for placement: NativeCalendarTimelinePlacement,
        width: CGFloat,
        gap: CGFloat
    ) -> CGFloat {
        let lane = laneWidth(for: placement, width: width, gap: gap)
        return CGFloat(placement.column) * (lane + gap)
    }

    private func nowLineY() -> CGFloat? {
        guard Calendar.current.isDateInToday(date) else { return nil }
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: Date())
        let minutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        let origin = startHour * 60
        guard minutes >= origin && minutes <= endHour * 60 else { return nil }
        return CGFloat(minutes - origin) / 60.0 * hourHeight
    }

    private func yOffset(for date: Date) -> CGFloat {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: date)
        let minutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        let origin = startHour * 60
        let clamped = max(origin, min(minutes, endHour * 60))
        return CGFloat(clamped - origin) / 60.0 * hourHeight
    }

    private func hourLabel(_ hour: Int) -> String {
        let cal = Calendar.current
        guard let date = cal.date(bySettingHour: hour, minute: 0, second: 0, of: self.date) else {
            return "\(hour)"
        }
        return Self.hourFormatter.string(from: date)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "h a"
        return formatter
    }()
}
