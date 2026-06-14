import SwiftUI
import EventKit

/// Native 7-day week grid with hour rail and per-column drop targets.
///
/// Drag any event block to reschedule it; the drop snaps to the nearest
/// 15-minute slot in the destination column. Read-only calendars refuse the
/// drop in `ScheduleViewModel.reschedule(...)`. Pure SwiftUI, iOS 16+.
struct ScheduleWeekGrid: View {

    let weekStart: Date
    let events: [EKEvent]
    let coordinator: EventDropCoordinator
    var onSelectEvent: (EKEvent) -> Void = { _ in }

    private let startHour = 6
    private let endHour = 22
    private let hourHeight: CGFloat = 56
    private let railWidth: CGFloat = 44
    private let snapMinutes = 15

    @State private var dropHighlight: Date?

    private var hours: [Int] { Array(startHour..<endHour) }

    private var days: [Date] {
        let cal = Calendar.current
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                GeometryReader { geo in
                    let columnWidth = max(0, (geo.size.width - railWidth) / 7)
                    ZStack(alignment: .topLeading) {
                        hourRail
                        ForEach(Array(days.enumerated()), id: \.element) { idx, day in
                            dayColumn(day: day, columnWidth: columnWidth, columnIndex: idx)
                        }
                        nowLine(width: geo.size.width - railWidth)
                    }
                }
                .frame(height: CGFloat(hours.count) * hourHeight)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: railWidth)
            ForEach(days, id: \.self) { day in
                VStack(spacing: 2) {
                    Text(day, format: .dateTime.weekday(.abbreviated))
                        .font(.caption2).foregroundStyle(.secondary)
                    Text(day, format: .dateTime.day())
                        .font(.headline)
                        .foregroundStyle(Calendar.current.isDateInToday(day) ? Color.accentColor : .primary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 6)
    }

    private var hourRail: some View {
        VStack(spacing: 0) {
            ForEach(hours, id: \.self) { hour in
                HStack(spacing: 0) {
                    Text(hourLabel(hour))
                        .font(.caption2).foregroundStyle(.secondary)
                        .frame(width: railWidth, alignment: .trailing)
                        .padding(.trailing, 4)
                        .offset(y: -6)
                    Spacer()
                }
                .frame(height: hourHeight, alignment: .top)
            }
        }
    }

    @ViewBuilder
    private func dayColumn(day: Date, columnWidth: CGFloat, columnIndex: Int) -> some View {
        let xOffset = railWidth + CGFloat(columnIndex) * columnWidth
        ZStack(alignment: .topLeading) {
            // Background grid lines
            VStack(spacing: 0) {
                ForEach(hours, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: hourHeight)
                        .overlay(Divider(), alignment: .top)
                }
            }
            .frame(width: columnWidth)
            // Drop highlight
            if let hl = dropHighlight, Calendar.current.isDate(hl, inSameDayAs: day) {
                let y = yOffset(for: hl)
                Rectangle()
                    .fill(Color.accentColor.opacity(0.18))
                    .frame(width: columnWidth, height: CGFloat(snapMinutes) / 60 * hourHeight)
                    .offset(y: y)
            }
            // Event blocks
            ForEach(eventsFor(day: day), id: \.eventIdentifier) { event in
                eventBlock(event: event, columnWidth: columnWidth)
            }
        }
        .frame(width: columnWidth, height: CGFloat(hours.count) * hourHeight, alignment: .topLeading)
        .offset(x: xOffset)
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
    }

    @ViewBuilder
    private func eventBlock(event: EKEvent, columnWidth: CGFloat) -> some View {
        let y = yOffset(for: event.startDate)
        let height = max(24, blockHeight(start: event.startDate, end: event.endDate))
        let color = Color(cgColor: event.calendar?.cgColor ?? UIColor.systemBlue.cgColor)
        let readOnly = !(event.calendar?.allowsContentModifications ?? true)
        Button { onSelectEvent(event) } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title ?? "Untitled")
                    .font(.caption2.weight(.semibold))
                    .lineLimit(2)
                Text(event.startDate, format: .dateTime.hour().minute())
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .frame(width: max(0, columnWidth - 4), height: height, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.22))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4).stroke(color.opacity(0.7), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .offset(x: 2, y: y)
        .opacity(readOnly ? 0.7 : 1.0)
        .onDrag {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return EventDragPayload(event: event).itemProvider()
        }
    }

    private func nowLine(width: CGFloat) -> some View {
        Group {
            if let todayIdx = days.firstIndex(where: { Calendar.current.isDateInToday($0) }) {
                let comps = Calendar.current.dateComponents([.hour, .minute], from: Date())
                let minutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
                let originMin = startHour * 60
                if minutes >= originMin && minutes <= endHour * 60 {
                    let y = CGFloat(minutes - originMin) / 60.0 * hourHeight
                    let columnWidth = max(0, width / 7)
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: columnWidth, height: 1.5)
                        .offset(x: railWidth + CGFloat(todayIdx) * columnWidth, y: y)
                }
            }
        }
    }

    // MARK: - Helpers

    private func eventsFor(day: Date) -> [EKEvent] {
        let cal = Calendar.current
        return events
            .filter { cal.isDate($0.startDate, inSameDayAs: day) }
            .sorted { $0.startDate < $1.startDate }
    }

    private func yOffset(for date: Date) -> CGFloat {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let minutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        let originMin = startHour * 60
        let clamped = max(originMin, min(minutes, endHour * 60 - snapMinutes))
        return CGFloat(clamped - originMin) / 60.0 * hourHeight
    }

    private func blockHeight(start: Date, end: Date) -> CGFloat {
        let minutes = max(Double(snapMinutes), end.timeIntervalSince(start) / 60)
        return CGFloat(minutes) / 60.0 * hourHeight
    }

    private func hourLabel(_ hour: Int) -> String {
        var comps = DateComponents()
        comps.hour = hour
        let f = DateFormatter()
        f.dateFormat = "h a"
        return Calendar.current.date(from: comps).map { f.string(from: $0) } ?? "\(hour)"
    }
}

