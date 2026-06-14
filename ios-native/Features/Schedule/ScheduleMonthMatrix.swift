import SwiftUI
import EventKit

/// Comprehensive month matrix for iPad / Mac form factors.
///
/// Pure SwiftUI grid, iOS 16 compatible. Each cell shows up to three event
/// pills; tapping a day raises it as the selected date.
struct ScheduleMonthMatrix: View {

    @Binding var selectedDate: Date
    let events: [EKEvent]
    var coordinator: EventDropCoordinator? = nil
    var onSelectDay: (Date) -> Void = { _ in }

    @State private var dropHighlightedDay: Date?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)


    var body: some View {
        VStack(spacing: 0) {
            weekdayHeader
            Divider()
            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(monthDays(), id: \.self) { day in
                    dayCell(day)
                }
            }
            .background(Color.secondary.opacity(0.1))
        }
    }

    private var weekdayHeader: some View {
        let symbols = Calendar.current.shortWeekdaySymbols
        return HStack(spacing: 0) {
            ForEach(symbols, id: \.self) { sym in
                Text(sym)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let cal = Calendar.current
        let inMonth = cal.isDate(day, equalTo: selectedDate, toGranularity: .month)
        let isSelected = cal.isDate(day, inSameDayAs: selectedDate)
        let isToday = cal.isDateInToday(day)
        let dayEvents = events.filter { cal.isDate($0.startDate, inSameDayAs: day) }
            .sorted { $0.startDate < $1.startDate }

        return Button {
            selectedDate = day
            onSelectDay(day)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(day, format: .dateTime.day())
                    .font(.caption.weight(isToday ? .bold : .regular))
                    .foregroundStyle(inMonth ? Color.primary : Color.secondary)
                    .padding(4)
                    .background(
                        Circle()
                            .fill(isToday ? Color.accentColor.opacity(0.2) : .clear)
                    )
                ForEach(dayEvents.prefix(3), id: \.eventIdentifier) { ev in
                    Text(ev.title ?? "")
                        .font(.system(size: 9))
                        .lineLimit(1)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            Color(cgColor: ev.calendar?.cgColor ?? UIColor.systemBlue.cgColor)
                                .opacity(0.25)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .onDrag {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            return EventDragPayload(event: ev).itemProvider()
                        }
                }
                if dayEvents.count > 3 {
                    Text("+\(dayEvents.count - 3) more")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
            .padding(4)
            .background(
                (dropHighlightedDay.map { Calendar.current.isDate($0, inSameDayAs: day) } ?? false)
                    ? Color.accentColor.opacity(0.18)
                    : Color(.systemBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .modifier(MonthCellDropModifier(day: day, coordinator: coordinator, highlight: $dropHighlightedDay))
    }

    private func monthDays() -> [Date] {
        let cal = Calendar.current
        guard let monthInterval = cal.dateInterval(of: .month, for: selectedDate) else { return [] }
        let firstWeekday = cal.component(.weekday, from: monthInterval.start) - 1
        guard let gridStart = cal.date(byAdding: .day, value: -firstWeekday, to: monthInterval.start) else { return [] }
        return (0..<42).compactMap { cal.date(byAdding: .day, value: $0, to: gridStart) }
    }
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

