import SwiftUI
import EventKit

/// Native single-day timeline grid that replaces the CalendarKit day view.
///
/// Renders an hour rail on the left and positions `EKEvent` blocks (and any
/// unsynced `Job`s) on a single column. Pure SwiftUI, iOS 16 compatible.
struct ScheduleDayGrid: View {

    let date: Date
    let events: [EKEvent]
    let jobs: [Job]
    var coordinator: EventDropCoordinator? = nil
    var onSelectEvent: (EKEvent) -> Void = { _ in }
    var onSelectJob: (Job) -> Void = { _ in }

    @State private var dropHighlight: Date?


    private let startHour = 6
    private let endHour = 19
    private let hourHeight: CGFloat = 72
    private let railWidth: CGFloat = 72
    private let snapMinutes = 15

    private var hours: [Int] { Array(startHour..<endHour) }

    var body: some View {
        ScrollView {
            ZStack(alignment: .topLeading) {
                hourRail
                dropTargetColumn
                dropHighlightOverlay
                nowLine
                blocksOverlay
            }
            .frame(height: CGFloat(hours.count) * hourHeight)
        }
    }

    @ViewBuilder
    private var dropTargetColumn: some View {
        if let coordinator {
            GeometryReader { geo in
                let width = max(0, geo.size.width - railWidth - 8)
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .frame(width: width, height: CGFloat(hours.count) * hourHeight)
                    .offset(x: railWidth + 4)
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

    @ViewBuilder
    private var dropHighlightOverlay: some View {
        if let hl = dropHighlight, Calendar.current.isDate(hl, inSameDayAs: date) {
            GeometryReader { geo in
                let width = max(0, geo.size.width - railWidth - 8)
                let comps = Calendar.current.dateComponents([.hour, .minute], from: hl)
                let mins = (comps.hour ?? 0) * 60 + (comps.minute ?? 0) - startHour * 60
                let y = CGFloat(max(0, mins)) / 60.0 * hourHeight
                Rectangle()
                    .fill(Color.accentColor.opacity(0.18))
                    .frame(width: width, height: CGFloat(snapMinutes) / 60 * hourHeight)
                    .offset(x: railWidth + 4, y: y)
            }
        }
    }


    private var hourRail: some View {
        VStack(spacing: 0) {
            ForEach(hours, id: \.self) { hour in
                HStack(spacing: 0) {
                    Text(hourLabel(hour))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: railWidth, alignment: .trailing)
                        .padding(.trailing, 6)
                        .offset(y: -6)
                    VStack(spacing: 0) {
                        Divider()
                        Spacer(minLength: 0)
                    }
                }
                .frame(height: hourHeight, alignment: .top)
            }
        }
    }

    private var nowLine: some View {
        GeometryReader { geo in
            if Calendar.current.isDateInToday(date) {
                let comps = Calendar.current.dateComponents([.hour, .minute], from: Date())
                let minutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
                let startMinutes = startHour * 60
                if minutes >= startMinutes && minutes <= endHour * 60 {
                    let y = CGFloat(minutes - startMinutes) / 60.0 * hourHeight
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: max(0, geo.size.width - railWidth), height: 1.5)
                        .offset(x: railWidth, y: y)
                }
            }
        }
    }

    private var blocksOverlay: some View {
        GeometryReader { geo in
            let columnWidth = max(0, geo.size.width - railWidth - 8)
            ZStack(alignment: .topLeading) {
                ForEach(eventBlocks(), id: \.id) { block in
                    eventBlockView(block)
                        .frame(width: columnWidth, height: max(28, block.height))
                        .offset(x: railWidth + 4, y: block.y)
                }
                ForEach(unsyncedJobBlocks(), id: \.id) { block in
                    jobBlockView(block)
                        .frame(width: columnWidth, height: max(28, block.height))
                        .offset(x: railWidth + 4, y: block.y)
                }
            }
        }
    }

    // MARK: - Block views

    @ViewBuilder
    private func eventBlockView(_ block: EventBlock) -> some View {
        Button { onSelectEvent(block.event) } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(block.event.title ?? "Untitled")
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                Text(block.event.startDate, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(cgColor: block.event.calendar?.cgColor ?? UIColor.systemBlue.cgColor)
                        .opacity(0.22))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(cgColor: block.event.calendar?.cgColor ?? UIColor.systemBlue.cgColor)
                        .opacity(0.7), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .opacity((block.event.calendar?.allowsContentModifications ?? true) ? 1.0 : 0.7)
        .onDrag {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return EventDragPayload(event: block.event).itemProvider()
        }
    }


    @ViewBuilder
    private func jobBlockView(_ block: JobBlock) -> some View {
        Button { onSelectJob(block.job) } label: {
            VStack(alignment: .leading, spacing: 2) {
                Label(block.job.title, systemImage: "wrench.and.screwdriver")
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
                    .fill(Color.orange.opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.orange.opacity(0.7), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Block layout

    private struct EventBlock: Identifiable {
        let id: String
        let event: EKEvent
        let y: CGFloat
        let height: CGFloat
    }

    private struct JobBlock: Identifiable {
        let id: UUID
        let job: Job
        let y: CGFloat
        let height: CGFloat
    }

    private func eventBlocks() -> [EventBlock] {
        let cal = Calendar.current
        return events.compactMap { event in
            guard let id = event.eventIdentifier,
                  cal.isDate(event.startDate, inSameDayAs: date) else { return nil }
            let (y, h) = position(start: event.startDate, end: event.endDate)
            return EventBlock(id: id, event: event, y: y, height: h)
        }
    }

    private func unsyncedJobBlocks() -> [JobBlock] {
        let cal = Calendar.current
        return jobs.compactMap { job in
            guard let start = job.scheduledAt,
                  cal.isDate(start, inSameDayAs: date) else { return nil }
            let (y, h) = position(start: start, end: start.addingTimeInterval(3600))
            return JobBlock(id: job.id, job: job, y: y, height: h)
        }
    }

    private func position(start: Date, end: Date) -> (CGFloat, CGFloat) {
        let cal = Calendar.current
        let s = cal.dateComponents([.hour, .minute], from: start)
        let startMin = (s.hour ?? 0) * 60 + (s.minute ?? 0)
        let duration = max(30, Int(end.timeIntervalSince(start) / 60))
        let originMin = startHour * 60
        let clamped = max(originMin, min(startMin, endHour * 60 - 30))
        let y = CGFloat(clamped - originMin) / 60.0 * hourHeight
        let h = CGFloat(duration) / 60.0 * hourHeight
        return (y, h)
    }

    private func hourLabel(_ hour: Int) -> String {
        var comps = DateComponents()
        comps.hour = hour
        let f = DateFormatter()
        f.dateFormat = "h a"
        return Calendar.current.date(from: comps).map { f.string(from: $0) } ?? "\(hour)"
    }
}
