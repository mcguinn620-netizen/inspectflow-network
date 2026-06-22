//
//  NativeCalendarLayoutEngine.swift
//  AutoInspectorNetwork
//
//  Created by Matt McGuinn on 6/22/26.
//

import Foundation
import EventKit

struct NativeCalendarEventLayout: Identifiable {

    let id: String

    let event: EKEvent

    let column: Int

    let totalColumns: Int
}

enum NativeCalendarLayoutEngine {

    static func layout(
        events: [EKEvent]
    ) -> [NativeCalendarEventLayout] {

        let sorted = events.sorted {
            $0.startDate < $1.startDate
        }

        var result: [NativeCalendarEventLayout] = []

        var active: [EKEvent] = []

        for event in sorted {

            active.removeAll {
                $0.endDate <= event.startDate
            }

            var usedColumns: Set<Int> = []

            for existing in active {

                if let layout = result.first(
                    where: {
                        $0.event.eventIdentifier ==
                        existing.eventIdentifier
                    }
                ) {
                    usedColumns.insert(layout.column)
                }
            }

            var column = 0

            while usedColumns.contains(column) {
                column += 1
            }

            active.append(event)

            result.append(
                NativeCalendarEventLayout(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    event: event,
                    column: column,
                    totalColumns: max(1, active.count)
                )
            )
        }

        return result
    }
}
