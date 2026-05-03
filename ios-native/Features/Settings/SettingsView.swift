import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            List {
                Section("Profile") {
                    if case .signedIn(let profile) = appState.authState {
                        Text(profile.fullName ?? "-")
                        Text(profile.email ?? "-")
                    }
                }
                Section("Session") {
                    Button("Sign Out", role: .destructive) {
                        appState.signOut()
                    }
                }
            }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { SyncStatusView() } }
            .navigationTitle("Settings")
        }
    }
}
