import SwiftUI

struct EarningsSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var mileageRate: String = ""
    @State private var defaultJobFee: String = ""
    @State private var estimatedTaxRate: String = ""
    @State private var stateCode: String = ""
    @State private var filingStatus: String = "single"
    @State private var isLoading = false
    @State private var statusMessage: String?

    private let filingOptions = ["single", "married_jointly", "married_separately", "head_of_household"]

    var body: some View {
        Form {
            Section("Mileage & fees") {
                TextField("Mileage rate ($/mi)", text: $mileageRate)
                    .keyboardType(.decimalPad)
                TextField("Default job fee ($)", text: $defaultJobFee)
                    .keyboardType(.decimalPad)
            }
            Section("Tax estimates") {
                TextField("Estimated tax rate (0–1)", text: $estimatedTaxRate)
                    .keyboardType(.decimalPad)
                TextField("State (e.g. CA)", text: $stateCode)
                    .textInputAutocapitalization(.characters)
                Picker("Filing status", selection: $filingStatus) {
                    ForEach(filingOptions, id: \.self) { Text($0.replacingOccurrences(of: "_", with: " ").capitalized).tag($0) }
                }
            }
            Section {
                Button("Save") { Task { await save() } }
            }
        }
        .navigationTitle("Earnings & Tax")
        .task { await load() }
        .overlay(alignment: .bottom) {
            if let msg = statusMessage {
                Text(msg).font(.footnote)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 16)
            }
        }
    }

    private func load() async {
        guard case let .signedIn(profile) = appState.authState else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            if let s = try await SupabaseService.shared.fetchEarningsSettings(userId: profile.id) {
                mileageRate = s.mileageRate.map { String($0) } ?? ""
                defaultJobFee = s.defaultJobFee.map { String($0) } ?? ""
                estimatedTaxRate = s.estimatedTaxRate.map { String($0) } ?? ""
                stateCode = s.stateCode ?? ""
                filingStatus = s.filingStatus ?? "single"
            }
        } catch {
            statusMessage = AINFriendlyError.message(for: error)
        }
    }

    private func save() async {
        guard case let .signedIn(profile) = appState.authState else { return }
        do {
            try await SupabaseService.shared.updateEarningsSettings(
                userId: profile.id,
                mileageRate: Double(mileageRate),
                defaultJobFee: Double(defaultJobFee),
                estimatedTaxRate: Double(estimatedTaxRate),
                stateCode: stateCode.isEmpty ? nil : stateCode,
                filingStatus: filingStatus
            )
            statusMessage = "Saved."
        } catch {
            statusMessage = AINFriendlyError.message(for: error)
        }
    }
}
