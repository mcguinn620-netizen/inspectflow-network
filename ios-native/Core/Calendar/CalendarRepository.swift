import Foundation
import EventKit
import SwiftUI
import Combine

/// Repository for calendar accounts, sources, colors, and per-calendar
/// visibility. Mirrors Apple Calendar's sidebar model.
///
/// Visibility is persisted via `UserDefaults` (keyed by `calendarIdentifier`)
/// so the user's choices survive relaunches without needing a separate store.
@MainActor
public final class CalendarRepository: ObservableObject {

    public static let shared = CalendarRepository()

    private let service: EventKitService
    private let defaults: UserDefaults
    private let visibilityKey = "schedule.calendar.visibility.v1"

    @Published public private(set) var calendars: [EKCalendar] = []
    @Published public private(set) var sources: [EKSource] = []
    @Published public private(set) var hiddenCalendarIDs: Set<String> = []

    private var changeTask: Task<Void, Never>?

    internal init(
        service: EventKitService = .shared,
        defaults: UserDefaults = .standard
    ) {
        self.service = service
        self.defaults = defaults
        self.hiddenCalendarIDs = Self.readHidden(defaults: defaults, key: visibilityKey)
        reload()

        changeTask = Task { [weak self] in
            guard let self else { return }
            for await _ in self.service.changes() {
                self.reload()
            }
        }
    }

    deinit { changeTask?.cancel() }

    public func reload() {
        guard service.hasAccess else {
            calendars = []
            sources = []
            return
        }
        calendars = service.store.calendars(for: .event)
            .sorted { lhs, rhs in
                if lhs.source.title == rhs.source.title { return lhs.title < rhs.title }
                return lhs.source.title < rhs.source.title
            }
        sources = service.store.sources
    }

    // MARK: - Visibility

    public func isVisible(_ calendar: EKCalendar) -> Bool {
        !hiddenCalendarIDs.contains(calendar.calendarIdentifier)
    }

    public func setVisible(_ visible: Bool, for calendar: EKCalendar) {
        if visible {
            hiddenCalendarIDs.remove(calendar.calendarIdentifier)
        } else {
            hiddenCalendarIDs.insert(calendar.calendarIdentifier)
        }
        persistHidden()
    }

    public func visibleCalendars() -> [EKCalendar] {
        calendars.filter { isVisible($0) }
    }

    // MARK: - Color

    public func color(for calendar: EKCalendar) -> Color {
        #if canImport(UIKit)
        return Color(uiColor: UIColor(cgColor: calendar.cgColor))
        #elseif canImport(AppKit)
        return Color(nsColor: NSColor(cgColor: calendar.cgColor) ?? .systemBlue)
        #else
        return .accentColor
        #endif
    }

    // MARK: - Mutations

    public func saveCalendar(_ calendar: EKCalendar) throws {
        try service.store.saveCalendar(calendar, commit: true)
        reload()
    }

    public func removeCalendar(_ calendar: EKCalendar) throws {
        try service.store.removeCalendar(calendar, commit: true)
        reload()
    }

    // MARK: - Persistence helpers

    private func persistHidden() {
        let array = Array(hiddenCalendarIDs)
        defaults.set(array, forKey: visibilityKey)
    }

    private static func readHidden(defaults: UserDefaults, key: String) -> Set<String> {
        let array = defaults.array(forKey: key) as? [String] ?? []
        return Set(array)
    }
}
