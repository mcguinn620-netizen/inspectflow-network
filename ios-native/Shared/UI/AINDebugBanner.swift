import SwiftUI

#if DEBUG
/// Slim amber banner shown across the app in DEBUG builds when impersonating.
struct AINDebugBanner: View {
    @EnvironmentObject private var appState: AppState
    @State private var showPicker = false

    var body: some View {
        if let user = appState.selectedDebugUser {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("DEBUG USER MODE")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.5)
                Text("— \(user.fullName ?? user.id.uuidString) (\(roleLabel(user.role)))")
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                Button {
                    showPicker = true
                } label: {
                    Text("Switch")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.18), in: Capsule())
                }
                .buttonStyle(.plain)
                Button {
                    appState.clearDebugUser()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .padding(6)
                        .background(Color.black.opacity(0.18), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .foregroundColor(Color(red: 0.25, green: 0.16, blue: 0.02))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AINTheme.Color.warn)
            .sheet(isPresented: $showPicker) {
                DebugUserPickerView()
                    .environmentObject(appState)
            }
        }
    }

    private func roleLabel(_ role: String) -> String {
        role.split(separator: "_").map { $0.capitalized }.joined(separator: " ")
    }
}
#endif
