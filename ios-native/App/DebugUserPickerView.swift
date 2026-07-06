import SwiftUI

/// Test-user picker. Under `AuthBypass.isEnabled` this is the app's entry
/// screen: pick any of the 10 hardcoded mock users to enter the app with
/// that role, no password. In real-auth mode (DEBUG only) it falls back to
/// browsing real Supabase memberships for impersonation.
struct DebugUserPickerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var users: [DebugUser] = []
    @State private var query: String = ""
    @State private var loading = true
    @State private var errorMessage: String?

    private var filtered: [DebugUser] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return users }
        return users.filter { u in
            (u.fullName ?? "").lowercased().contains(q) ||
            (u.email ?? "").lowercased().contains(q) ||
            (u.organizationName ?? "").lowercased().contains(q) ||
            u.role.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                banner

                if loading {
                    Spacer()
                    ProgressView("Loading users…")
                    Spacer()
                } else if let errorMessage {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(AINTheme.Color.fail)
                        Text("Failed to load users")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(AINTheme.Color.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Retry") { Task { await load() } }
                            .buttonStyle(.borderedProminent)
                    }
                    Spacer()
                } else {
                    List(filtered) { user in
                        Button {
                            select(user)
                        } label: {
                            row(user)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .listStyle(.plain)
                    .searchable(text: $query, prompt: "Search name, email, organization, or role")
                }
            }
            .navigationTitle("Debug User Picker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if appState.selectedDebugUser != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
            }
            .task { await load() }
        }
    }

    private var banner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AINTheme.Color.warn)
            VStack(alignment: .leading, spacing: 2) {
                Text("Development Only")
                    .font(.subheadline).fontWeight(.semibold)
                Text("Pick a user to impersonate. No password required. Production builds never show this screen.")
                    .font(.caption)
                    .foregroundColor(AINTheme.Color.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(AINTheme.Color.warn.opacity(0.12))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(AINTheme.Color.warn.opacity(0.35)),
            alignment: .bottom
        )
    }

    private func row(_ user: DebugUser) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AINTheme.Color.surfaceMuted)
                Text(initials(user.fullName))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AINTheme.Color.textPrimary)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(user.fullName ?? "(no name)")
                    .font(.body).fontWeight(.semibold)
                    .foregroundColor(AINTheme.Color.textPrimary)
                if let email = user.email, !email.isEmpty {
                    Text(email)
                        .font(.caption)
                        .foregroundColor(AINTheme.Color.textSecondary)
                }
                Text(user.organizationName ?? "(no org)")
                    .font(.caption)
                    .foregroundColor(AINTheme.Color.textTertiary)
            }

            Spacer()

            AINRoleBadge(role: user.role)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func initials(_ name: String?) -> String {
        guard let name, !name.isEmpty else { return "?" }
        let parts = name.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    private func select(_ user: DebugUser) {
        appState.debugSignIn(as: user)
        dismiss()
    }

    private func load() async {
        loading = true
        errorMessage = nil
        do {
            users = try await DebugUserService.fetchDebugUsers()
        } catch {
            errorMessage = error.localizedDescription
        }
        loading = false
    }
}

