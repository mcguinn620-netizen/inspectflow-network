import Foundation
import SwiftUI
import Combine

/// Observable model for cross-cutting Schedule filters: per-calendar visibility
/// (delegated to `CalendarRepository`) plus category and tag filters persisted
/// across launches via `UserDefaults`.
///
/// Use a single instance owned by `ScheduleViewModel` so the sidebar, content
/// pane, and search service all reference the same source of truth.
@MainActor
public final class CalendarFilterModel: ObservableObject {

    private let defaults: UserDefaults
    private let categoryKey = "schedule.filter.categories.v1"
    private let tagKey = "schedule.filter.tags.v1"

    @Published public var selectedCategories: Set<String>
    @Published public var selectedTags: Set<String>
    @Published public var searchQuery: String = ""

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.selectedCategories = Set(defaults.stringArray(forKey: categoryKey) ?? [])
        self.selectedTags = Set(defaults.stringArray(forKey: tagKey) ?? [])
    }

    public var hasActiveFilters: Bool {
        !selectedCategories.isEmpty || !selectedTags.isEmpty || !searchQuery.isEmpty
    }

    public func toggleCategory(_ category: String) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
        persist()
    }

    public func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
        persist()
    }

    public func clearAll() {
        selectedCategories.removeAll()
        selectedTags.removeAll()
        searchQuery = ""
        persist()
    }

    public func matches(_ metadata: EventMetadata?) -> Bool {
        if !selectedCategories.isEmpty {
            guard let category = metadata?.category, selectedCategories.contains(category) else {
                return false
            }
        }
        if !selectedTags.isEmpty {
            let tags = Set(metadata?.tags ?? [])
            if tags.isDisjoint(with: selectedTags) { return false }
        }
        return true
    }

    private func persist() {
        defaults.set(Array(selectedCategories), forKey: categoryKey)
        defaults.set(Array(selectedTags), forKey: tagKey)
    }
}
