import SwiftUI
import EventKit

/// Sheet for editing the recurrence rule of an `EKEvent`. Supports daily,
/// weekly, monthly, and yearly recurrence with a custom interval and an
/// end-policy of never, on a date, or after N occurrences.
struct RecurrenceEditorView: View {

    let initial: RecurrenceSpec
    let onSave: (RecurrenceSpec) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var frequency: RecurrenceFrequency
    @State private var interval: Int
    @State private var endMode: EndMode
    @State private var endDate: Date
    @State private var occurrences: Int

    private enum EndMode: String, CaseIterable, Identifiable {
        case never, on, after
        var id: String { rawValue }
        var title: String {
            switch self {
            case .never: return "Never"
            case .on:    return "On Date"
            case .after: return "After"
            }
        }
    }

    init(initial: RecurrenceSpec, onSave: @escaping (RecurrenceSpec) -> Void) {
        self.initial = initial
        self.onSave = onSave
        _frequency = State(initialValue: initial.frequency)
        _interval = State(initialValue: max(1, initial.interval))
        switch initial.end {
        case .never:
            _endMode = State(initialValue: .never)
            _endDate = State(initialValue: Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date())
            _occurrences = State(initialValue: 10)
        case .on(let date):
            _endMode = State(initialValue: .on)
            _endDate = State(initialValue: date)
            _occurrences = State(initialValue: 10)
        case .after(let count):
            _endMode = State(initialValue: .after)
            _endDate = State(initialValue: Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date())
            _occurrences = State(initialValue: max(1, count))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Repeat") {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(RecurrenceFrequency.allCases) { freq in
                            Text(freq.title).tag(freq)
                        }
                    }
                }
                if frequency != .none {
                    Section("Every") {
                        Stepper(value: $interval, in: 1...365) {
                            Text("\(interval) \(unitLabel)")
                        }
                    }
                    Section("Ends") {
                        Picker("Ends", selection: $endMode) {
                            ForEach(EndMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        switch endMode {
                        case .never:
                            EmptyView()
                        case .on:
                            DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                        case .after:
                            Stepper(value: $occurrences, in: 1...999) {
                                Text("\(occurrences) occurrences")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Recurrence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(currentSpec)
                        dismiss()
                    }
                }
            }
        }
    }

    private var unitLabel: String {
        switch frequency {
        case .none:    return ""
        case .daily:   return interval == 1 ? "day" : "days"
        case .weekly:  return interval == 1 ? "week" : "weeks"
        case .monthly: return interval == 1 ? "month" : "months"
        case .yearly:  return interval == 1 ? "year" : "years"
        }
    }

    private var currentSpec: RecurrenceSpec {
        let end: RecurrenceEnd
        switch endMode {
        case .never: end = .never
        case .on:    end = .on(endDate)
        case .after: end = .after(occurrences: occurrences)
        }
        return RecurrenceSpec(frequency: frequency, interval: interval, end: end)
    }
}

#if compiler(>=5.9)
@available(iOS 17.0, macOS 14.0, *)
#Preview {
    RecurrenceEditorView(initial: .none) { _ in }
}
#endif
