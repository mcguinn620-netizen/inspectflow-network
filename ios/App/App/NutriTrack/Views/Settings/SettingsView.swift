import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var calories = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Nutrition Goals") {
                    TextField("Calories", text: $calories)
                        .keyboardType(.numberPad)
                    Button("Save Goals") {
                        store.saveGoals(NutritionGoals(calories: Int(calories) ?? store.goals.calories, protein: store.goals.protein, carbs: store.goals.carbs, fat: store.goals.fat))
                    }
                }
                Section("Theme") { Text("Default: System") }
                Section("Data") {
                    Button("Manual Refresh") { Task { await store.refreshRemoteData() } }
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .onAppear { calories = String(store.goals.calories) }
        }
    }
}
