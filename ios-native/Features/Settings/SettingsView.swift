import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            List {
                if case let .signedIn(profile) = appState.authState {
                    Section("Account") {
                        LabeledContent("Name", value: profile.fullName ?? "—")
                        LabeledContent("Email", value: profile.email ?? "—")
                    }
                }
                Section("App") {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Brand", value: AINBrand.displayName)
                }
                Section {
                    Button("Sign Out", role: .destructive) {
                        Task { await appState.signOut() }
                    }
                }
            }
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { SyncStatusView() } }
            .navigationTitle("Settings")
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
