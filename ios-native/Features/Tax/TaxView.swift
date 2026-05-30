import SwiftUI

struct TaxView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Tax") {
                    Text("Mileage, reimbursements, and tax exports are available from trip records.")
                }
            }
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { SyncStatusView() } }
            .navigationTitle("Tax")
        }
    }
}
