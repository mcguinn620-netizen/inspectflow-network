import SwiftUI
import EventKit

/// Apple-Calendar-style sidebar showing all EKCalendars grouped by source,
/// with per-calendar color dot, name, visibility toggle, plus quick filters
/// for app-specific categories and tags.
struct CalendarSidebarView: View {

    @ObservedObject var viewModel: ScheduleViewModel
    @ObservedObject var calendars: CalendarRepository
    @ObservedObject var filters: CalendarFilterModel

    init(
        viewModel: ScheduleViewModel,
        calendars: CalendarRepository = .shared,
        filters: CalendarFilterModel
    ) {
        self.viewModel = viewModel
        self.calendars = calendars
        self.filters = filters
    }

    var body: some View {
        List {
            sourcesSection
            categoriesSection
            tagsSection
            if filters.hasActiveFilters {
                Section {
                    Button("Clear Filters", role: .destructive) { filters.clearAll() }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Calendars")
    }

    // MARK: - Sources

    @ViewBuilder
    private var sourcesSection: some View {
        let grouped = Dictionary(grouping: calendars.calendars) { $0.source.title }
        ForEach(grouped.keys.sorted(), id: \.self) { sourceTitle in
            Section(sourceTitle) {
                ForEach(grouped[sourceTitle] ?? [], id: \.calendarIdentifier) { cal in
                    calendarRow(cal)
                }
            }
        }
    }

    private func calendarRow(_ cal: EKCalendar) -> some View {
        let visible = calendars.isVisible(cal)
        return Toggle(isOn: Binding(
            get: { visible },
            set: { newValue in
                calendars.setVisible(newValue, for: cal)
                Task { await viewModel.reloadEvents() }
            }
        )) {
            HStack(spacing: 10) {
                Circle()
                    .fill(calendars.color(for: cal))
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 1) {
                    Text(cal.title).font(.body)
                    if cal.isImmutable {
                        Text("Read only").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .toggleStyle(.switch)
        .accessibilityLabel("\(cal.title), \(visible ? "visible" : "hidden")")
    }

    // MARK: - Categories

    private var categoriesSection: some View {
        let allCategories = Set(viewModel.metadataByEventID.values.compactMap { $0.category })
            .sorted()
        return Section("Categories") {
            if allCategories.isEmpty {
                Text("No categories yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(allCategories, id: \.self) { category in
                    Button {
                        filters.toggleCategory(category)
                    } label: {
                        HStack {
                            Label(category, systemImage: "folder")
                            Spacer()
                            if filters.selectedCategories.contains(category) {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Tags

    private var tagsSection: some View {
        let allTags = Set(viewModel.metadataByEventID.values.flatMap { $0.tags }).sorted()
        return Section("Tags") {
            if allTags.isEmpty {
                Text("No tags yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(allTags, id: \.self) { tag in
                    Button {
                        filters.toggleTag(tag)
                    } label: {
                        HStack {
                            Label("#\(tag)", systemImage: "tag")
                            Spacer()
                            if filters.selectedTags.contains(tag) {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
