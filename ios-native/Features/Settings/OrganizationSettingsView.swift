import SwiftUI

struct OrganizationSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var memberships: [OrganizationMembership] = []
    @State private var isLoading = false
    @State private var loadError: String?

    var body: some View {
        List {
            Section("Active organization") {
                if let orgId = appState.activeOrganizationID {
                    LabeledContent("Org ID", value: orgId.uuidString.prefix(8) + "…")
                    LabeledContent("Role", value: appState.effectiveRole.capitalized)
                } else {
                    Text("No active organization.").foregroundStyle(.secondary)
                }
            }

            Section("Your memberships") {
                if isLoading {
                    HStack { ProgressView(); Text("Loading…").foregroundStyle(.secondary) }
                } else if let loadError {
                    Text(loadError).font(.footnote).foregroundStyle(.secondary)
                } else if memberships.isEmpty {
                    Text("You don't belong to any organizations yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(memberships) { m in
                        Button {
                            appState.activeOrganizationID = m.organizationID
                            appState.effectiveRole = m.role
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(m.organizationID.uuidString.prefix(8) + "…")
                                        .font(.subheadline)
                                    Text(m.role).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if m.organizationID == appState.activeOrganizationID {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Organization")
        .task { await load() }
    }

    private func load() async {
        guard case let .signedIn(profile) = appState.authState else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            memberships = try await SupabaseService.shared.listMyMemberships(userId: profile.id)
        } catch {
            loadError = AINFriendlyError.message(for: error)
        }
    }
}
