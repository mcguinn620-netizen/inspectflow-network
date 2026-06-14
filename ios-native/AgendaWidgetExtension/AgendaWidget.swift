import SwiftUI
import WidgetKit

struct AgendaEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedAgendaStore.Snapshot
}

struct AgendaProvider: TimelineProvider {
    func placeholder(in context: Context) -> AgendaEntry {
        AgendaEntry(date: Date(), snapshot: Self.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (AgendaEntry) -> Void) {
        let snap = SharedAgendaStore.load() ?? Self.sample
        completion(AgendaEntry(date: Date(), snapshot: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AgendaEntry>) -> Void) {
        let snap = SharedAgendaStore.load() ?? SharedAgendaStore.Snapshot(items: [])
        let now = Date()
        // Refresh hourly, plus an extra entry right after the next event starts
        // so the widget rolls forward without waiting for the app to publish.
        var entries: [AgendaEntry] = [AgendaEntry(date: now, snapshot: snap)]
        if let next = snap.items.first(where: { $0.startDate > now }) {
            entries.append(AgendaEntry(date: next.startDate.addingTimeInterval(1), snapshot: snap))
        }
        let refresh = now.addingTimeInterval(60 * 60)
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }

    static var sample: SharedAgendaStore.Snapshot {
        let now = Date()
        return SharedAgendaStore.Snapshot(items: [
            .init(id: "1", title: "Pre-purchase inspection",
                  startDate: now.addingTimeInterval(3600),
                  endDate: now.addingTimeInterval(5400),
                  location: "Hayward, CA",
                  calendarTitle: "InspectFlow",
                  colorARGB: 0xFF3B82F6,
                  isAllDay: false,
                  isOverdue: false)
        ])
    }
}

struct AgendaWidget: Widget {
    static let kind = SharedAgendaStore.agendaWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: AgendaProvider()) { entry in
            AgendaWidgetView(entry: entry)
        }
        .configurationDisplayName("Agenda")
        .description("Upcoming inspections and overdue items.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct AgendaWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AgendaEntry

    var body: some View {
        switch family {
        case .systemSmall: SmallAgendaView(entry: entry)
        case .systemLarge: LargeAgendaView(entry: entry)
        default: MediumAgendaView(entry: entry)
        }
    }
}

private struct SmallAgendaView: View {
    let entry: AgendaEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let next = entry.snapshot.items.first {
                Text("NEXT").font(.caption2).foregroundStyle(.secondary)
                Text(next.title).font(.headline).lineLimit(2)
                Text(next.startDate, style: .time).font(.subheadline).foregroundStyle(.secondary)
                if let location = next.location, !location.isEmpty {
                    Text(location).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            } else {
                Text("No upcoming").font(.headline)
                Text("You're all caught up.").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
    }
}

private struct MediumAgendaView: View {
    let entry: AgendaEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today").font(.caption).foregroundStyle(.secondary)
            ForEach(Array(entry.snapshot.items.prefix(3))) { item in
                AgendaRow(item: item)
            }
            if entry.snapshot.items.isEmpty {
                Text("No upcoming events").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
    }
}

private struct LargeAgendaView: View {
    let entry: AgendaEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Agenda").font(.caption).foregroundStyle(.secondary)
            ForEach(Array(entry.snapshot.items.prefix(7))) { item in
                AgendaRow(item: item)
            }
            if entry.snapshot.items.isEmpty {
                Text("No upcoming events").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
    }
}

private struct AgendaRow: View {
    let item: SharedAgendaStore.Item
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(argb: item.colorARGB))
                .frame(width: 3, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                HStack(spacing: 6) {
                    Text(item.startDate, style: .time).font(.caption).foregroundStyle(.secondary)
                    if item.isOverdue {
                        Text("Overdue").font(.caption2.weight(.semibold))
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Color.red.opacity(0.15), in: Capsule())
                            .foregroundStyle(.red)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

private extension Color {
    init(argb: UInt32) {
        let a = Double((argb >> 24) & 0xFF) / 255
        let r = Double((argb >> 16) & 0xFF) / 255
        let g = Double((argb >> 8) & 0xFF) / 255
        let b = Double(argb & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
