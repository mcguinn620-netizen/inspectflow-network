import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        let todayLogs = store.mealLogs.filter { Calendar.current.isDateInToday($0.loggedAt) }
        let total = todayLogs.flatMap(\.items)
        List {
            Section("Totals") {
                Text("Calories: \(total.reduce(0) { $0 + ($1.calories ?? 0) })")
                Text("Protein: \(Int(total.reduce(0.0) { $0 + ($1.protein ?? 0) }))g")
                Text("Carbs: \(Int(total.reduce(0.0) { $0 + ($1.carbs ?? 0) }))g")
                Text("Fat: \(Int(total.reduce(0.0) { $0 + ($1.fat ?? 0) }))g")
            }
            Section("Tray") {
                if store.tray.isEmpty {
                    Text("Your tray is empty")
                } else {
                    ForEach(store.tray) { item in Text(item.name) }
                    Button("Log Tray as Lunch") { store.logTray(as: .lunch) }
                }
            }
        }
        .navigationTitle("Today")
    }
}
