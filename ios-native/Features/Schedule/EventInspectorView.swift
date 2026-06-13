import SwiftUI
import EventKit
import EventKitUI

/// Trailing inspector pane for the selected calendar event or job.
///
/// Shows core EKEvent fields, presents the system editor sheet, and edits
/// app-specific metadata (category, tags, checklist, rich notes).
struct EventInspectorView: View {

    @ObservedObject var viewModel: ScheduleViewModel
    @State private var presentingEditor = false
    @State private var localMetadata: EventMetadata?
    @State private var newTag: String = ""
    @State private var newChecklistTitle: String = ""

    var body: some View {
        Group {
            if let event = viewModel.selectedEvent {
                eventForm(event)
            } else if let job = viewModel.selectedJob {
                jobForm(job)
            } else {
                ContentUnavailableCompat(
                    title: "Nothing selected",
                    message: "Pick an event or job from the schedule."
                )
            }
        }
        .navigationTitle("Inspector")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Event form

    private func eventForm(_ event: EKEvent) -> some View {
        Form {
            Section {
                Text(event.title ?? "Untitled").font(.headline)
                Label {
                    Text(event.startDate, format: .dateTime.month().day().hour().minute())
                } icon: { Image(systemName: "clock") }
                if let location = event.location, !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                }
                if let cal = event.calendar {
                    Label(cal.title, systemImage: "calendar")
                        .foregroundStyle(Color(cgColor: cal.cgColor))
                }
            }

            Section("Notes") {
                Text(event.notes ?? "")
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            metadataSection(eventID: event.eventIdentifier ?? "")

            Section {
                Button {
                    presentingEditor = true
                } label: {
                    Label("Edit in Calendar", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    Task { await viewModel.deleteEvent(event) }
                } label: {
                    Label("Delete Event", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $presentingEditor) {
            EventEditSheet(event: event, store: viewModel.eventStore) {
                Task { await viewModel.reloadEvents() }
            }
        }
        .task(id: event.eventIdentifier) {
            await loadMetadata(for: event.eventIdentifier ?? "")
        }
    }

    // MARK: - Job form (unsynced)

    private func jobForm(_ job: Job) -> some View {
        Form {
            Section {
                Text(job.title).font(.headline)
                if let at = job.scheduledAt {
                    Label {
                        Text(at, format: .dateTime.month().day().hour().minute())
                    } icon: { Image(systemName: "clock") }
                }
                if let loc = job.location {
                    Label(loc, systemImage: "mappin.and.ellipse")
                }
                if let cust = job.customerName {
                    Label(cust, systemImage: "person")
                }
                Label(job.status.capitalized, systemImage: "circle.fill")
            }

            Section {
                Button {
                    Task { await viewModel.mirror(job: job) }
                } label: {
                    Label("Sync to Apple Calendar", systemImage: "calendar.badge.plus")
                }
            }
        }
    }

    // MARK: - Metadata editor

    @ViewBuilder
    private func metadataSection(eventID: String) -> some View {
        if let meta = localMetadata {
            Section("Category") {
                TextField("Category", text: Binding(
                    get: { meta.category ?? "" },
                    set: { update { $0.category = $1.isEmpty ? nil : $1 } ($0) }
                ))
            }
            Section("Tags") {
                ForEach(meta.tags, id: \.self) { tag in
                    HStack {
                        Label(tag, systemImage: "tag")
                        Spacer()
                        Button {
                            update { $0.tags.removeAll(where: { $0 == tag }) }
                        } label: { Image(systemName: "minus.circle.fill").foregroundStyle(.red) }
                            .buttonStyle(.plain)
                    }
                }
                HStack {
                    TextField("New tag", text: $newTag)
                    Button("Add") {
                        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        update { $0.tags.append(trimmed) }
                        newTag = ""
                    }
                }
            }
            Section("Checklist") {
                ForEach(meta.checklist) { item in
                    Toggle(isOn: Binding(
                        get: { item.done },
                        set: { newVal in
                            update {
                                if let idx = $0.checklist.firstIndex(where: { $0.id == item.id }) {
                                    $0.checklist[idx].done = newVal
                                }
                            }
                        }
                    )) { Text(item.title) }
                }
                HStack {
                    TextField("New item", text: $newChecklistTitle)
                    Button("Add") {
                        let trimmed = newChecklistTitle.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        update { $0.checklist.append(ScheduleChecklistItem(title: trimmed)) }
                        newChecklistTitle = ""
                    }
                }
            }
            Section("Rich Notes") {
                TextEditor(text: Binding(
                    get: { meta.richNotes },
                    set: { newVal in update { $0.richNotes = newVal } }
                ))
                .frame(minHeight: 100)
            }
        } else {
            Section { ProgressView() }
        }
    }

    private func loadMetadata(for eventID: String) async {
        guard !eventID.isEmpty else { localMetadata = nil; return }
        if let existing = viewModel.metadataByEventID[eventID] {
            localMetadata = existing
        } else {
            localMetadata = EventMetadata(eventID: eventID)
        }
    }

    private func update(_ mutate: (inout EventMetadata) -> Void) {
        guard var meta = localMetadata else { return }
        mutate(&meta)
        localMetadata = meta
        Task { await viewModel.upsertMetadata(meta) }
    }

    // Curried helper for the TextField category binding above.
    private func update(_ mutate: @escaping (inout EventMetadata, String) -> Void) -> (String) -> Void {
        { newValue in
            guard var meta = localMetadata else { return }
            mutate(&meta, newValue)
            localMetadata = meta
            Task { await viewModel.upsertMetadata(meta) }
        }
    }
}

// MARK: - System editor wrapper

private struct EventEditSheet: UIViewControllerRepresentable {
    let event: EKEvent
    let store: EKEventStore
    let onDone: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let vc = EKEventEditViewController()
        vc.event = event
        vc.eventStore = store
        vc.editViewDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: EKEventEditViewController, context: Context) {}

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onDone: () -> Void
        init(onDone: @escaping () -> Void) { self.onDone = onDone }
        func eventEditViewController(_ controller: EKEventEditViewController,
                                     didCompleteWith action: EKEventEditViewAction) {
            controller.dismiss(animated: true) { [onDone] in onDone() }
        }
    }
}

// Expose the EKEventStore on the view model without leaking the whole service.
private extension ScheduleViewModel {
    var eventStore: EKEventStore { EventKitService.shared.store }
}
