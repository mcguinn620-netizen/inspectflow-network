import SwiftUI

/// A reusable sort menu for list-view screens.
/// Persists the user's choice in `@AppStorage` under the supplied storage key.
///
/// Example:
/// ```swift
/// AINSortMenu(storageKey: "sort.jobs", options: JobsSortKey.allCases)
///     .onChange(of: sort) { _ in /* re-sort */ }
/// ```
struct AINSortOption: Hashable, Identifiable {
    let id: String          // stable key persisted across launches
    let label: String       // display label
    var systemImage: String? = nil
}

struct AINSortMenu: View {
    let storageKey: String
    let options: [AINSortOption]
    @Binding var selectedID: String
    @Binding var ascending: Bool

    var body: some View {
        Menu {
            Picker("Sort by", selection: $selectedID) {
                ForEach(options) { opt in
                    if let icon = opt.systemImage {
                        Label(opt.label, systemImage: icon).tag(opt.id)
                    } else {
                        Text(opt.label).tag(opt.id)
                    }
                }
            }
            Divider()
            Picker("Order", selection: $ascending) {
                Label("Ascending", systemImage: "arrow.up").tag(true)
                Label("Descending", systemImage: "arrow.down").tag(false)
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down.circle")
                .accessibilityLabel("Sort")
        }
    }
}

/// Convenience state holder for screens — exposes two `@AppStorage`-backed
/// bindings so the user's sort preference survives relaunches.
@MainActor
final class AINSortState: ObservableObject {
    @Published var selectedID: String
    @Published var ascending: Bool

    private let idKey: String
    private let ascKey: String

    init(storageKey: String, defaultID: String, defaultAscending: Bool = false) {
        self.idKey = "sort.\(storageKey).id"
        self.ascKey = "sort.\(storageKey).asc"
        self.selectedID = UserDefaults.standard.string(forKey: idKey) ?? defaultID
        if UserDefaults.standard.object(forKey: ascKey) != nil {
            self.ascending = UserDefaults.standard.bool(forKey: ascKey)
        } else {
            self.ascending = defaultAscending
        }
    }

    func persist() {
        UserDefaults.standard.set(selectedID, forKey: idKey)
        UserDefaults.standard.set(ascending, forKey: ascKey)
    }
}
