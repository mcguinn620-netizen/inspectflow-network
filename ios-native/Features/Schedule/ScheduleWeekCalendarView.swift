import SwiftUI

/// Apple Calendar-style week view. Hour rail on the left, 7 day columns,
/// jobs positioned as blocks by their `scheduledAt` time.
///
/// Compatible with iOS 16 — no `TimelineView`, no `ContentUnavailableView`.
struct ScheduleWeekCalendarView: View {
    let weekStart: Date
    let jobs: [Job]
    var onSelect: (Job) -> Void = { _ in }
    var onLongPress: (Job) -> Void = { _ in }

    private let startHour = 6      // 6 AM
    private let endHour = 22       // 10 PM
    private let hourHeight: CGFloat = 56
    private let railWidth: CGFloat = 44

    private var hours: [Int] { Array(startHour..<endHour) }

    private var dayColumns: [Date] {
        let cal = Calendar.current
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                ZStack(alignment: .topLeading) {
                    grid
                    nowLineOverlay
                    blocksOverlay
                }
                .frame(height: CGFloat(hours.count) * hourHeight)
            }
        }
    }

    // MARK: - Header (day strip)

    private var header: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: railWidth)
            ForEach(dayColumns, id: \.self) { day in
                VStack(spacing: 2) {
                    Text(day, format: .dateTime.weekday(.abbreviated))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(day, format: .dateTime.day())
                        .font(.headline)
                        .foregroundStyle(isToday(day) ? Color.accentColor : Color.primary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle().fill(isToday(day) ? Color.accentColor.opacity(0.15) : .clear)
                        )
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Grid (hour rows + day columns)

    private var grid: some View {
        GeometryReader { geo in
            let dayWidth = max(0, (geo.size.width - railWidth) / 7)
            ZStack(alignment: .topLeading) {
                // Today column tint
                if let todayIndex = dayColumns.firstIndex(where: { isToday($0) }) {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.06))
                        .frame(width: dayWidth, height: CGFloat(hours.count) * hourHeight)
                        .offset(x: railWidth + CGFloat(todayIndex) * dayWidth, y: 0)
                }

                // Hour rows
                VStack(spacing: 0) {
                    ForEach(hours, id: \.self) { hour in
                        HStack(spacing: 0) {
                            Text(hourLabel(hour))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(width: railWidth, alignment: .trailing)
                                .padding(.trailing, 4)
                                .offset(y: -6)
                            VStack(spacing: 0) {
                                Divider()
                                Spacer(minLength: 0)
                            }
                        }
                        .frame(height: hourHeight, alignment: .top)
                    }
                }

                // Vertical day separators
                HStack(spacing: 0) {
                    Spacer().frame(width: railWidth)
                    ForEach(0..<7, id: \.self) { _ in
                        VStack { Spacer() }
                            .frame(width: dayWidth)
                            .overlay(
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.12))
                                    .frame(width: 0.5),
                                alignment: .leading
                            )
                    }
                }
            }
        }
    }

    // MARK: - "Now" line

    private var nowLineOverlay: some View {
        GeometryReader { geo in
            let dayWidth = max(0, (geo.size.width - railWidth) / 7)
            if let todayIndex = dayColumns.firstIndex(where: { isToday($0) }) {
                let now = Date()
                let cal = Calendar.current
                let comps = cal.dateComponents([.hour, .minute], from: now)
                let minutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
                let startMinutes = startHour * 60
                if minutes >= startMinutes && minutes <= endHour * 60 {
                    let y = CGFloat(minutes - startMinutes) / 60.0 * hourHeight
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: dayWidth, height: 1.5)
                        .offset(x: railWidth + CGFloat(todayIndex) * dayWidth, y: y)
                }
            }
        }
    }

    // MARK: - Job blocks

    private var blocksOverlay: some View {
        GeometryReader { geo in
            let dayWidth = max(0, (geo.size.width - railWidth) / 7)
            ZStack(alignment: .topLeading) {
                ForEach(positionedBlocks(dayWidth: dayWidth), id: \.id) { block in
                    blockView(for: block)
                        .frame(width: max(0, dayWidth - 4), height: max(28, block.height))
                        .offset(x: block.x + 2, y: block.y)
                }
            }
        }
    }

    private func blockView(for block: PositionedBlock) -> some View {
        Button {
            onSelect(block.job)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(block.job.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                if let at = block.job.scheduledAt {
                    Text(at, format: .dateTime.hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.accentColor.opacity(0.6), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onLongPressGesture { onLongPress(block.job) }
        .accessibilityLabel("\(block.job.title), \(block.job.status)")
    }

    // MARK: - Layout helpers

    private struct PositionedBlock {
        let id: UUID
        let job: Job
        let x: CGFloat
        let y: CGFloat
        let height: CGFloat
    }

    private func positionedBlocks(dayWidth: CGFloat) -> [PositionedBlock] {
        let cal = Calendar.current
        var out: [PositionedBlock] = []
        for job in jobs {
            guard let scheduled = job.scheduledAt else { continue }
            // Find which day column (timezone-safe)
            guard let columnIndex = dayColumns.firstIndex(where: {
                cal.isDate(scheduled, inSameDayAs: $0)
            }) else { continue }

            let comps = cal.dateComponents([.hour, .minute], from: scheduled)
            let minutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
            let startMinutes = startHour * 60
            let endMinutes = endHour * 60
            // Clamp to visible range so jobs scheduled at edges still render
            let visibleMinutes = max(startMinutes, min(minutes, endMinutes - 30))
            let y = CGFloat(visibleMinutes - startMinutes) / 60.0 * hourHeight
            let duration: CGFloat = 60 // default 60 min
            let height = duration / 60.0 * hourHeight
            let x = railWidth + CGFloat(columnIndex) * dayWidth
            out.append(PositionedBlock(id: job.id, job: job, x: x, y: y, height: height))
        }
        return out
    }

    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    private func hourLabel(_ hour: Int) -> String {
        var comps = DateComponents()
        comps.hour = hour
        let cal = Calendar.current
        if let date = cal.date(from: comps) {
            let f = DateFormatter()
            f.dateFormat = "h a"
            return f.string(from: date)
        }
        return "\(hour)"
    }
}
