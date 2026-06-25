import SwiftUI
import EventKit

/// Native 7-day week view with a full 24-hour timeline and overlap lanes
/// matching the same layout engine used by the day view.
struct ScheduleWeekGrid: View {
    
    let weekStart: Date
    let events: [EKEvent]
    let jobs: [Job]
    var coordinator: EventDropCoordinator
    var onSelectEvent: (EKEvent) -> Void = { _ in }
    var onSelectJob: (Job) -> Void = { _ in }
    
    private let startHour = NativeCalendarMetrics.startHour
    private let endHour = NativeCalendarMetrics.endHour
    private let hourHeight: CGFloat = 68
    private let railWidth: CGFloat = 56
    private let snapMinutes = 15
    
    @State private var dropHighlight: Date?
    
    private var hours: [Int] { Array(startHour..<endHour) }
    
    private var days: [Date] {
        let cal = Calendar.current
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
    }
    
    private var timelineHeight: CGFloat {
        CGFloat(endHour - startHour) * hourHeight
    }
    
    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                header
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
    
    private var header: some View {
        HStack(spacing: 0) {
            Spacer()
                .frame(width: railWidth)
            
            ForEach(days, id: \.self) { day in
                VStack(spacing: 3) {
                    Text(day, format: .dateTime.weekday(.abbreviated))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    Text(day, format: .dateTime.day())
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 30, height: 30)
                        .background {
                            if Calendar.current.isDateInToday(day) {
                                Circle().fill(.red)
                            }
                        }
                        .foregroundStyle(
                            Calendar.current.isDateInToday(day) ? .white : .primary
                        )
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .background(.thinMaterial)
        .overlay(Divider(), alignment: .bottom)
    }
    
    @ViewBuilder
    private func timeline(width: CGFloat) -> some View {
        let contentWidth = max(0, width - railWidth)
        let columnWidth = contentWidth / 7.0
        
        HStack(spacing: 0) {
            hourRail
                .frame(width: railWidth, height: timelineHeight, alignment: .top)
            
            ZStack(alignment: .topLeading) {
                ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                    dayColumn(
                        day: day,
                        index: index,
                        columnWidth: columnWidth
                    )
                }
            }
            .frame(width: contentWidth, height: timelineHeight, alignment: .topLeading)
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
    func dayColumn(day: Date, index: Int, columnWidth: CGFloat) -> some View {
        let columnXOffset = CGFloat(index) * columnWidth
        let dayEvents = eventsFor(day: day)
        let dayJobs = jobsFor(day: day)
        
        let placements = NativeCalendarLayoutEngine.placements(
            for: day,
            events: dayEvents,
            jobs: dayJobs,
            startHour: startHour,
            endHour: endHour,
            hourHeight: hourHeight
        )
        
        ZStack(alignment: .topLeading) {
            ForEach(placements) { placement in
                timelineCard(placement)
                    .frame(
                        width: laneWidth(for: placement, width: columnWidth),
                        height: placement.height,
                        alignment: .topLeading
                    )
                    // Position the card using the column offset + its calculated internal lane offset
                    .offset(
                        x: columnXOffset + xOffset(for: placement, width: columnWidth),
                        y: placement.y
                    )
            }
            
            if let y = nowLineY(for: day) {
                NativeNowIndicator()
                    .frame(width: columnWidth)
                    .offset(x: columnXOffset, y: y)
            }
        }
        .frame(width: columnWidth, height: timelineHeight, alignment: .topLeading)
        .contentShape(Rectangle())
        .onDrop(
            of: [EventDragPayload.utType],
            delegate: TimeColumnDropDelegate(
                date: day,
                startHour: startHour,
                endHour: endHour,
                hourHeight: hourHeight,
                snapMinutes: snapMinutes,
                coordinator: coordinator,
                highlight: $dropHighlight
            )
        )
        .overlay(
            Rectangle()
                .fill(.secondary.opacity(0.06))
                .frame(width: 0.5)
                .offset(x: columnWidth - 0.25),
            alignment: .topLeading
        )
    }
        
        private func dayGrid(columnWidth: CGFloat) -> some View {
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
            .frame(width: columnWidth, height: timelineHeight, alignment: .topLeading)
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
                VStack(alignment: .leading, spacing: 2) {
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
        
        private func jobsFor(day: Date) -> [Job] {
            let cal = Calendar.current
            return jobs.filter { job in
                guard let start = job.scheduledAt else { return false }
                return cal.isDate(start, inSameDayAs: day)
            }
            .sorted {
                ($0.scheduledAt ?? .distantPast) < ($1.scheduledAt ?? .distantPast)
            }
        }
        
        private func eventsFor(day: Date) -> [EKEvent] {
            let cal = Calendar.current
            return events
                .filter { cal.isDate($0.startDate, inSameDayAs: day) }
                .sorted { $0.startDate < $1.startDate }
        }
        
        private func laneWidth(for placement: NativeCalendarTimelinePlacement, width: CGFloat) -> CGFloat {
            let columns = max(1, placement.totalColumns)
            let gap = NativeCalendarMetrics.laneGap
            let gaps = CGFloat(max(0, columns - 1)) * gap
            return max(42, (width - gaps) / CGFloat(columns))
        }
        
        private func xOffset(for placement: NativeCalendarTimelinePlacement, width: CGFloat) -> CGFloat {
            let lane = laneWidth(for: placement, width: width)
            return CGFloat(placement.column) * (lane + NativeCalendarMetrics.laneGap)
        }
        
        private func nowLineY(for day: Date) -> CGFloat? {
            guard Calendar.current.isDateInToday(day) else { return nil }
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
            let date = cal.date(bySettingHour: hour, minute: 0, second: 0, of: weekStart) ?? weekStart
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

