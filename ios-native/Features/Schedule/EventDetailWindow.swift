import SwiftUI
import EventKit

/// Standalone window scene that hosts a single event in its own
/// `EventInspectorView`. Opened via `openWindow(value: EventIdentity)` from
/// the main schedule pane. Works on iPadOS (Stage Manager / Split View) and
/// macOS; on iPhone the system collapses it back into the main window.
@available(iOS 16.0, *)
struct EventDetailWindow: View {

    let identity: EventIdentity

    @StateObject private var viewModel = ScheduleViewModel()
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            EventInspectorView(viewModel: viewModel)
                .navigationTitle(windowTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Close") { dismiss() }
                    }
                }
        }
        .task {
            await viewModel.bootstrap(orgId: appState.activeOrganizationID)
            await selectEvent()
        }
    }

    private var windowTitle: String {
        viewModel.selectedEvent?.title ?? "Event"
    }

    @MainActor
    private func selectEvent() async {
        if let event = EventRepository.shared.event(matching: identity) {
            viewModel.selectedEventID = event.eventIdentifier
            viewModel.selectedJobID = nil
            if let start = event.startDate as Date? {
                viewModel.selectedDate = start
                await viewModel.reloadEvents()
            }
        }
    }
}

