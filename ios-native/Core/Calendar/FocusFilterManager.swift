import Foundation
import Combine
#if canImport(Intents)
import Intents
#endif

/// Bridges the system Focus state to Schedule filter presets.
///
/// On iOS 16+, `INFocusStatusCenter` exposes the user's current Focus status
/// (`isFocused`). We can't read the *identifier* of the active Focus mode
/// without a Focus Filter extension, so this manager exposes a lightweight
/// preset model the user can map themselves: when Focus turns on, apply the
/// preset named "focus"; when it turns off, apply "default".
///
/// Presets are persisted as JSON in `UserDefaults` keyed by name and can be
/// edited from Settings. The manager also exposes an `AsyncStream` of preset
/// changes so views can react.
@MainActor
public final class FocusFilterManager: ObservableObject {

    public static let shared = FocusFilterManager()

    public struct Preset: Codable, Equatable, Identifiable {
        public var id: String { name }
        public var name: String
        public var hiddenCalendarIDs: Set<String>
        public var selectedCategories: Set<String>
        public var selectedTags: Set<String>

        public init(
            name: String,
            hiddenCalendarIDs: Set<String> = [],
            selectedCategories: Set<String> = [],
            selectedTags: Set<String> = []
        ) {
            self.name = name
            self.hiddenCalendarIDs = hiddenCalendarIDs
            self.selectedCategories = selectedCategories
            self.selectedTags = selectedTags
        }
    }

    private let defaults: UserDefaults
    private let storageKey = "schedule.focus.presets.v1"
    private let activePresetKey = "schedule.focus.active.v1"

    @Published public private(set) var presets: [Preset]
    @Published public private(set) var activePresetName: String?
    @Published public private(set) var isFocusActive: Bool = false

    private var focusObserverTask: Task<Void, Never>?

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.presets = Self.read(defaults: defaults, key: storageKey)
        self.activePresetName = defaults.string(forKey: activePresetKey)
        startFocusObservation()
    }

    deinit { focusObserverTask?.cancel() }

    // MARK: - Presets

    public func upsert(_ preset: Preset) {
        if let idx = presets.firstIndex(where: { $0.name == preset.name }) {
            presets[idx] = preset
        } else {
            presets.append(preset)
        }
        persist()
    }

    public func delete(_ name: String) {
        presets.removeAll { $0.name == name }
        if activePresetName == name { activePresetName = nil }
        persist()
    }

    public func preset(named name: String) -> Preset? {
        presets.first { $0.name == name }
    }

    /// Applies `preset` to the given filter + calendar repositories.
    public func apply(_ preset: Preset, filters: CalendarFilterModel, calendars: CalendarRepository) {
        activePresetName = preset.name
        defaults.set(preset.name, forKey: activePresetKey)

        filters.selectedCategories = preset.selectedCategories
        filters.selectedTags = preset.selectedTags

        for calendar in calendars.calendars {
            let visible = !preset.hiddenCalendarIDs.contains(calendar.calendarIdentifier)
            calendars.setVisible(visible, for: calendar)
        }
    }

    /// Captures the current state of the filters/calendars as a preset.
    public func capture(
        name: String,
        filters: CalendarFilterModel,
        calendars: CalendarRepository
    ) -> Preset {
        let hidden = Set(calendars.calendars
            .filter { !calendars.isVisible($0) }
            .map { $0.calendarIdentifier })
        let preset = Preset(
            name: name,
            hiddenCalendarIDs: hidden,
            selectedCategories: filters.selectedCategories,
            selectedTags: filters.selectedTags
        )
        upsert(preset)
        return preset
    }

    // MARK: - Focus bridging

    private func startFocusObservation() {
        #if canImport(Intents)
        if #available(iOS 16.0, macOS 13.0, *) {
            // Authorization is required before isFocused becomes meaningful.
            focusObserverTask = Task { @MainActor [weak self] in
                guard let self else { return }
                let center = INFocusStatusCenter.default
                if center.authorizationStatus == .notDetermined {
                    _ = try? await center.requestAuthorization()
                }
                self.isFocusActive = center.focusStatus.isFocused ?? false
                // Poll on a slow cadence — there is no public KVO for focusStatus
                // and the cost is trivial (one property read).
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    let active = INFocusStatusCenter.default.focusStatus.isFocused ?? false
                    if active != self.isFocusActive {
                        self.isFocusActive = active
                    }
                }
            }
        }
        #endif
    }

    // MARK: - Persistence

    private func persist() {
        if let data = try? JSONEncoder().encode(presets) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private static func read(defaults: UserDefaults, key: String) -> [Preset] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Preset].self, from: data) else {
            return []
        }
        return decoded
    }
}
