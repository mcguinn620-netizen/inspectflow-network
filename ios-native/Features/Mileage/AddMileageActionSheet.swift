import SwiftUI

/// Bottom sheet shown when the "+" FAB is tapped on the Mileage screen.
/// Mirrors the Stride-style list: Add Mileage / Add Income / Add Expense / Track Miles.
struct AddMileageActionSheet: View {
    enum Action {
        case addMileage
        case addIncome
        case addExpense
        case trackMiles
    }

    let onSelect: (Action) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            row(icon: "car.fill", title: "Add Mileage") { onSelect(.addMileage) }
            row(icon: "creditcard.fill", title: "Add Income") { onSelect(.addIncome) }
            row(icon: "doc.text.fill", title: "Add Expense") { onSelect(.addExpense) }
            row(icon: "steeringwheel", title: "Track Miles") { onSelect(.trackMiles) }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(width: 56, height: 56)
                    .background(Color.yellow, in: Circle())
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal)
        .padding(.top, 24)
        .background(AINTheme.Color.background)
    }

    private func row(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(AINTheme.Color.textPrimary)
                    .frame(width: 32)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AINTheme.Color.textPrimary)
                Spacer()
            }
            .padding()
            .background(AINTheme.Color.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
