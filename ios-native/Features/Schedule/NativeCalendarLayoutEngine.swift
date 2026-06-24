import SwiftUI
import Foundation
import UIKit
import EventKit

struct NativeCalendarTimelinePlacement: Identifiable {
    enum Kind {
        case event(EKEvent)
        case job(Job)
    }

    let id: String
    let kind: Kind
    let start: Date
    let end: Date
    let y: CGFloat
    let height: CGFloat
    let column: Int
    let totalColumns: Int

    var isReadOnly: Bool {
        switch kind {
        case .event(let event):
            return !(event.calendar?.allowsContentModifications ?? true)
        case .job:
            return false
        }
    }

    var baseColor: Color {
        switch kind {
        case .event(let event):
            return Color(cgColor: event.calendar?.cgColor ?? UIColor.systemBlue.cgColor)
        case .job:
            return .orange
        }
    }
}

enum NativeCalendarLayoutEngine {

    static func placements(
        for day: Date,
        events: [EKEvent],
        jobs: [Job] = [],
        startHour: Int = NativeCalendarMetrics.startHour,
        endHour: Int = NativeCalendarMetrics.endHour,
        hourHeight: CGFloat = NativeCalendarMetrics.hourHeight
    ) -> [NativeCalendarTimelinePlacement] {

        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)

        let raw: [RawItem] = events.compactMap { event in
            guard event.startDate < dayEnd, event.endDate > dayStart else { return nil }
            let start = max(event.startDate, dayStart)
            let end = min(event.endDate, dayEnd)
            return RawItem(
                id: event.calendarItemIdentifier,
                kind: .event(event),
                start: start,
                end: max(end, start.addingTimeInterval(60)),
                title: event.title ?? "Untitled"
            )
        } + jobs.compactMap { job in
            guard let startCandidate = job.scheduledAt else { return nil }
            guard cal.isDate(startCandidate, inSameDayAs: day) else { return nil }
            let start = max(startCandidate, dayStart)
            let end = min(start.addingTimeInterval(60 * 60), dayEnd)
            return RawItem(
                id: "job-\(job.id.uuidString)",
                kind: .job(job),
                start: start,
                end: max(end, start.addingTimeInterval(60)),
                title: job.title
            )
        }

        let sorted = raw.sorted {
            if $0.start == $1.start { return $0.end < $1.end }
            return $0.start < $1.start
        }

        guard !sorted.isEmpty else { return [] }

        var groups: [[RawItem]] = []
        var current: [RawItem] = []
        var currentGroupEnd: Date = .distantPast

        for item in sorted {
            if current.isEmpty {
                current = [item]
                currentGroupEnd = item.end
                continue
            }

            if item.start < currentGroupEnd {
                current.append(item)
                currentGroupEnd = max(currentGroupEnd, item.end)
            } else {
                groups.append(current)
                current = [item]
                currentGroupEnd = item.end
            }
        }

        if !current.isEmpty {
            groups.append(current)
        }

        var placements: [NativeCalendarTimelinePlacement] = []

        for group in groups {
            let totalColumns = max(1, maxConcurrentItems(in: group))
            let assignments = assignColumns(in: group)

            for assignment in assignments {
                let startMinutes = minutes(from: dayStart, to: assignment.item.start)
                let endMinutes = minutes(from: dayStart, to: assignment.item.end)
                let yMinutes = clamp(
                    startMinutes,
                    lower: startHour * 60,
                    upper: endHour * 60
                )
                let visibleEnd = clamp(
                    max(endMinutes, yMinutes + 15),
                    lower: yMinutes + 1,
                    upper: endHour * 60
                )
                let heightMinutes = max(15, visibleEnd - yMinutes)

                placements.append(
                    NativeCalendarTimelinePlacement(
                        id: assignment.item.id,
                        kind: assignment.item.kind,
                        start: assignment.item.start,
                        end: assignment.item.end,
                        y: CGFloat(yMinutes - startHour * 60) / 60.0 * hourHeight,
                        height: max(
                            NativeCalendarMetrics.eventMinimumHeight,
                            CGFloat(heightMinutes) / 60.0 * hourHeight
                        ),
                        column: assignment.column,
                        totalColumns: totalColumns
                    )
                )
            }
        }

        return placements.sorted {
            if $0.y == $1.y { return $0.column < $1.column }
            return $0.y < $1.y
        }
    }

    private struct RawItem {
        enum RawKind {
            case event(EKEvent)
            case job(Job)
        }

        let id: String
        let kind: RawKind
        let start: Date
        let end: Date
        let title: String

        var placementKind: NativeCalendarTimelinePlacement.Kind {
            switch kind {
            case .event(let event):
                return .event(event)
            case .job(let job):
                return .job(job)
            }
        }
    }

    private struct Assignment {
        let item: RawItem
        let column: Int
    }

    private static func assignColumns(in group: [RawItem]) -> [Assignment] {
        var activeEnds: [Date] = []
        var assignments: [Assignment] = []

        for item in group.sorted(by: itemSort) {
            var chosenColumn: Int?

            for index in activeEnds.indices {
                if activeEnds[index] <= item.start {
                    chosenColumn = index
                    activeEnds[index] = item.end
                    break
                }
            }

            if chosenColumn == nil {
                activeEnds.append(item.end)
                chosenColumn = activeEnds.count - 1
            }

            assignments.append(
                Assignment(
                    item: item,
                    column: chosenColumn ?? 0
                )
            )
        }

        return assignments
    }

    private static func maxConcurrentItems(in group: [RawItem]) -> Int {
        let points: [(date: Date, delta: Int)] = group.flatMap { item in
            [
                (item.start, 1),
                (item.end, -1)
            ]
        }
        .sorted {
            if $0.date == $1.date {
                return $0.delta < $1.delta
            }
            return $0.date < $1.date
        }

        var active = 0
        var maxActive = 0

        for point in points {
            active += point.delta
            maxActive = max(maxActive, active)
        }

        return max(1, maxActive)
    }

    private static func itemSort(_ lhs: RawItem, _ rhs: RawItem) -> Bool {
        if lhs.start == rhs.start { return lhs.end < rhs.end }
        return lhs.start < rhs.start
    }

    private static func minutes(from start: Date, to end: Date) -> Int {
        max(0, Int(end.timeIntervalSince(start) / 60.0))
    }

    private static func clamp(_ value: Int, lower: Int, upper: Int) -> Int {
        min(max(value, lower), upper)
    }
}
