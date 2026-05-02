import SwiftUI

struct WeekView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        List {
            ForEach(0..<5, id: \.self) { offset in
                let start = Calendar.current.date(byAdding: .weekOfYear, value: -offset, to: Date()) ?? Date()
                let week = store.mealLogs.filter { Calendar.current.isDate($0.loggedAt, equalTo: start, toGranularity: .weekOfYear) }
                Section("Week of \(start.formatted(date: .abbreviated, time: .omitted))") {
                    Text("Meals logged: \(week.count)")
                    Text("Items: \(week.flatMap(\.items).count)")
                }
            }
        }
        .navigationTitle("Week")
    }
}
