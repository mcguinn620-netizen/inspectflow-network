import SwiftUI

struct VehicleDetailView: View {
    let vehicle: Vehicle

    var body: some View {
        List {
            Section("Identity") {
                Text(vehicle.vin ?? "Unknown VIN")
                    .font(.system(.body, design: .monospaced))
                if let nickname = vehicle.nickname, !nickname.isEmpty {
                    Text(nickname)
                }
            }

            Section("Specs") {
                LabeledContent("Make", value: vehicle.make ?? "—")
                LabeledContent("Model", value: vehicle.model ?? "—")
                LabeledContent("Year", value: vehicle.year.map(String.init) ?? "—")
            }
        }
        .navigationTitle("Vehicle")
    }
}
