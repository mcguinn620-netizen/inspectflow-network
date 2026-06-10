import SwiftUI

struct AvailabilitySettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var rows: [AvailabilityRow] = []
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var statusMessage: String?

    private let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        List {
            if isLoading {
                Section { HStack { ProgressView(); Text("Loading…").foregroundStyle(.secondary) } }
            } else if let loadError {
                Section { Text(loadError).font(.footnote).foregroundStyle(.secondary) }
            } else if rows.isEmpty {
                Section { Text("No availability windows set yet. Manage on the web for now.").foregroundStyle(.secondary) }
            } else {
                ForEach($rows) { $row in
                    Section(dayLabel(row.dayOfWeek)) {
                        Toggle("Available", isOn: $row.isAvailable)
                        LabeledContent("Start", value: row.startTime)
                        LabeledContent("End", value: row.endTime)
                    }
                }
            }
        }
        .navigationTitle("Availability")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") { Task { await save() } }
                    .disabled(rows.isEmpty)
            }
        }
        .task { await load() }
        .overlay(alignment: .bottom) {
            if let msg = statusMessage {
                Text(msg).font(.footnote)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 16)
            }
        }
    }

    private func dayLabel(_ idx: Int) -> String {
        guard idx >= 0, idx < dayNames.count else { return "Day \(idx)" }
        return dayNames[idx]
    }

    private func load() async {
        guard case let .signedIn(profile) = appState.authState else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            rows = try await SupabaseService.shared.fetchAvailability(userId: profile.id)
        } catch {
            loadError = AINFriendlyError.message(for: error)
        }
    }

    private func save() async {
        do {
            try await SupabaseService.shared.upsertAvailability(rows)
            statusMessage = "Availability saved."
        } catch {
            statusMessage = AINFriendlyError.message(for: error)
        }
    }
}
