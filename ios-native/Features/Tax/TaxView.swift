import SwiftUI

struct TaxView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Tax") {
                    Text("Placeholder for native Tax feature.")
                }
            }
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { SyncStatusView() } }
            .navigationTitle("Tax")
        }
    }
}
