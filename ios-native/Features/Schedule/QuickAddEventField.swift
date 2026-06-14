import SwiftUI
import EventKit

/// Compact toolbar popover that parses a natural-language phrase into a draft
/// `EKEvent`, persists it on the InspectFlow calendar, and selects it so the
/// inspector opens for further edits.
///
/// Example phrases:
/// - "Brake inspection tomorrow 2pm at Bay 3 for 45 min"
/// - "Call Sam Friday 10am"
/// - "Pickup at 1234 Main St Monday 8:30am for 30 min"
@available(iOS 16.0, *)
struct QuickAddEventField: View {

    @ObservedObject var viewModel: ScheduleViewModel
    @State private var text: String = ""
    @State private var isPresented: Bool = false
    @State private var preview: NaturalLanguageSchedulingService.Draft?
    @State private var parseError: String?
    @FocusState private var focused: Bool

    private let service = NaturalLanguageSchedulingService()

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "wand.and.stars")
                .accessibilityLabel("Quick add event")
        }
        .popover(isPresented: $isPresented) {
            popoverContent
                .frame(minWidth: 320, idealWidth: 360, maxWidth: 420)
                .padding(16)
        }
        .onChange(of: isPresented) { showing in
            if showing {
                focused = true
            } else {
                text = ""
                preview = nil
                parseError = nil
            }
        }
    }

    private var popoverContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Add")
                .font(.headline)
            Text("Type a phrase like \"Brake inspection tomorrow 2pm for 45 min at Bay 3\".")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("New event…", text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)
                .focused($focused)
                .submitLabel(.go)
                .onSubmit(create)
                .onChange(of: text) { _ in refreshPreview() }

            if let preview {
                previewCard(preview)
            } else if let parseError {
                Label(parseError, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                Button("Add", action: create)
                    .buttonStyle(.borderedProminent)
                    .disabled(preview == nil)
            }
        }
    }

    private func previewCard(_ draft: NaturalLanguageSchedulingService.Draft) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(draft.title)
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                Text(draft.start, format: .dateTime.weekday(.abbreviated).month().day().hour().minute())
                Text("–")
                Text(draft.end, format: .dateTime.hour().minute())
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let loc = draft.location, !loc.isEmpty {
                Label(loc, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private func refreshPreview() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            preview = nil
            parseError = nil
            return
        }
        do {
            preview = try service.parse(trimmed)
            parseError = nil
        } catch {
            preview = nil
            parseError = error.localizedDescription
        }
    }

    private func create() {
        guard let draft = preview else { return }
        let calendar = EventKitService.shared.inspectFlowCalendar()
        Task { @MainActor in
            do {
                let event = try EventRepository.shared.createEvent(
                    title: draft.title,
                    in: calendar,
                    start: draft.start,
                    end: draft.end,
                    location: draft.location,
                    notes: draft.notes
                )
                viewModel.selectedDate = draft.start
                viewModel.selectedJobID = nil
                viewModel.selectedEventID = event.eventIdentifier
                await viewModel.reloadEvents()
                isPresented = false
            } catch {
                parseError = error.localizedDescription
            }
        }
    }
}
