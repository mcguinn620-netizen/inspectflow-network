import SwiftUI
import EventKit

/// Month grid with compact Apple Calendar style cells and 42-day paging
/// structure. Keeps drag/drop support while making the visual treatment much
/// closer to the native Calendar app.
struct ScheduleMonthMatrix: View {

    @Binding var selectedDate: Date
    let events: [EKEvent]
    let jobs: [Job]
    var coordinator: EventDropCoordinator? = nil
    var onSelectDay: (Date) -> Void = { _ in }

    @State private var dropHighlightedDay: Date?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)

    private var calendar: Calendar { Calendar.current }

    var body: some View {
        VStack(spacing: 0) {
            weekdayHeader
            Divider()
            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(monthDays(), id: \.self) { day in
                    dayCell(day)
                }
            }
            .padding(.top, 1)
            .background(Color(.systemGroupedBackground))
        }
        .background(Color(.systemGroupedBackground))
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(calendar.shortStandaloneWeekdaySymbols.indices, id: \.self) { idx in
                Text(calendar.shortStandaloneWeekdaySymbols[idx])
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
        }
        .background(.thinMaterial)
        .overlay(Divider(), alignment: .bottom)
    }

    private func dayCell(_ day: Date) -> some View {
        let inMonth = calendar.isDate(day, equalTo: selectedDate, toGranularity: .month)
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(day)

        let dayItems = timelineItems(for: day)
        let highlighted = dropHighlightedDay.map { calendar.isDate($0, inSameDayAs: day) } ?? false

        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                dayNumber(day, isSelected: isSelected, isToday: isToday)
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 3) {
                ForEach(dayItems.prefix(3), id: \.identifier) { item in
                    monthItemChip(item)
                }

                if dayItems.count > 3 {
                    Text("+\(dayItems.count - 3) more")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: NativeCalendarMetrics.monthCellMinimumHeight, alignment: .topLeading)
        .padding(NativeCalendarMetrics.monthCellPadding)
        .background(
            highlighted
                ? Color.accentColor.opacity(0.16)
                : Color(.systemBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedDate = day
            onSelectDay(day)
        }
        .opacity(inMonth ? 1.0 : 0.55)
        .modifier(MonthCellDropModifier(day: day, coordinator: coordinator, highlight: $dropHighlightedDay))
    }

    @ViewBuilder
    private func dayNumber(_ day: Date, isSelected: Bool, isToday: Bool) -> some View {
        let textColor: Color = isToday ? .white : (calendar.isDate(day, equalTo: selectedDate, toGranularity: .month) ? .primary : .secondary)

        Text(day, format: .dateTime.day())
            .font(.system(size: 13, weight: isToday ? .semibold : .regular))
            .frame(width: 26, height: 26)
            .background {
                if isToday {
                    Circle().fill(.red)
                } else if isSelected {
                    Circle().fill(Color.accentColor.opacity(0.16))
                }
            }
            .foregroundStyle(textColor)
    }

    @ViewBuilder
    private func monthItemChip(_ item: MonthTimelineItem) -> some View {
        let chip = HStack(spacing: 4) {
            Circle()
                .fill(item.color)
                .frame(width: 4, height: 4)

            Text(item.title)
                .font(.system(size: 9, weight: .medium))
                .lineLimit(1)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Capsule(style: .continuous)
                .fill(item.color.opacity(0.16))
        )

        switch item.payload {
        case .event(let event):
            chip.onDrag {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                return EventDragPayload(event: event).itemProvider()
            }
        case .job:
            chip
        }
    }

    private func monthDays() -> [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedDate) else { return [] }
        let weekday = calendar.component(.weekday, from: monthInterval.start)
        let leading = weekday - calendar.firstWeekday
        let normalizedLeading = (leading + 7) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -normalizedLeading, to: monthInterval.start) else { return [] }
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
    }

    private func timelineItems(for day: Date) -> [MonthTimelineItem] {
        let dayEvents = events.filter { calendar.isDate($0.startDate, inSameDayAs: day) }
            .sorted { $0.startDate < $1.startDate }
            .map { event in
                MonthTimelineItem(
                    identifier: "event-\(event.calendarItemIdentifier)",
                    sortDate: event.startDate,
                    title: event.title?.isEmpty == false ? (event.title ?? "Untitled") : "Untitled",
                    color: Color(cgColor: event.calendar?.cgColor ?? UIColor.systemBlue.cgColor),
                    payload: .event(event)
                )
            }

        let dayJobs = jobs.compactMap { job -> MonthTimelineItem? in
            guard let scheduledAt = job.scheduledAt, calendar.isDate(scheduledAt, inSameDayAs: day) else { return nil }
            return MonthTimelineItem(
                identifier: "job-\(job.id.uuidString)",
                sortDate: scheduledAt,
                title: job.title,
                color: .orange,
                payload: .job(job)
            )
        }

        return (dayEvents + dayJobs).sorted {
            let lhs = $0.sortDate ?? .distantFuture
            let rhs = $1.sortDate ?? .distantFuture
            if lhs == rhs { return $0.title < $1.title }
            return lhs < rhs
        }
    }
}

private struct MonthTimelineItem: Identifiable {
    enum Payload {
        case event(EKEvent)
        case job(Job)
    }

    let identifier: String
    let sortDate: Date?
    let title: String
    let color: Color
    let payload: Payload

    var id: String { identifier }
}

private struct MonthCellDropModifier: ViewModifier {
    let day: Date
    let coordinator: EventDropCoordinator?
    @Binding var highlight: Date?

    func body(content: Content) -> some View {
        if let coordinator {
            content.onDrop(
                of: [EventDragPayload.utType],
                delegate: MonthDayDropDelegate(day: day, coordinator: coordinator, highlightedDay: $highlight)
            )
        } else {
            content
        }
    }
}
