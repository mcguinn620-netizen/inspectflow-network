import SwiftUI

struct AccountSettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            if case let .signedIn(profile) = appState.authState {
                Section("Email") {
                    LabeledContent("Address", value: profile.email ?? "—")
                    Text("Email changes must be requested from a desktop browser for security.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Password") {
                    Text("To change your password, tap Forgot Password on the sign-in screen and follow the email link.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Account ID") {
                    Text(profile.id.uuidString).font(.system(.footnote, design: .monospaced))
                }
            }
        }
        .navigationTitle("Account")
    }
}
