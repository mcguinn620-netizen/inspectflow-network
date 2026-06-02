import SwiftUI

#if DEBUG
/// DEV-only "Developer Tools" section in Settings.
/// Compiled out of release builds.
struct DeveloperToolsSection: View {
    @EnvironmentObject private var appState: AppState
    @State private var showPicker = false

    var body: some View {
        Section {
            if let user = appState.selectedDebugUser {
                LabeledContent("Current User", value: user.fullName ?? user.id.uuidString)
                HStack {
                    Text("Current Role")
                    Spacer()
                    AINRoleBadge(role: user.role)
                }
                LabeledContent("Current Organization", value: user.organizationName ?? "—")

                Button {
                    showPicker = true
                } label: {
                    Label("Switch User", systemImage: "person.2.crop.square.stack")
                }

                Button(role: .destructive) {
                    appState.clearDebugUser()
                } label: {
                    Label("Clear User", systemImage: "xmark.circle")
                }

                Button(role: .destructive) {
                    appState.clearDebugUser()
                    showPicker = true
                } label: {
                    Label("Reset Debug Session", systemImage: "arrow.counterclockwise")
                }
            } else {
                Button {
                    showPicker = true
                } label: {
                    Label("Pick Debug User", systemImage: "person.crop.circle.badge.questionmark")
                }
            }
        } header: {
            Label("Developer Tools", systemImage: "hammer.fill")
        } footer: {
            Text("Development build only. These controls are stripped from production.")
        }
        .sheet(isPresented: $showPicker) {
            DebugUserPickerView()
                .environmentObject(appState)
        }
    }
}
#endif
