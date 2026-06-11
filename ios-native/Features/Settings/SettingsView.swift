import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            List {
                if case let .signedIn(profile) = appState.authState {
                    Section {
                        NavigationLink(destination: ProfileView()) {
                            HStack(spacing: 12) {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.tint)
                                VStack(alignment: .leading) {
                                    Text(profile.fullName ?? "Your profile").font(.headline)
                                    Text(profile.email ?? "").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section("Account") {
                    NavigationLink("Account", destination: AccountSettingsView())
                    NavigationLink("Organization", destination: OrganizationSettingsView())
                }

                Section("Work") {
                    NavigationLink("Availability", destination: AvailabilitySettingsView())
                    NavigationLink("Earnings & Tax", destination: EarningsSettingsView())
                    NavigationLink("My Vehicles", destination: InspectorVehiclesView())
                }

                Section("Device") {
                    NavigationLink("Notifications", destination: NotificationSettingsView())
                    NavigationLink("Calendar Sync", destination: CalendarSyncSettingsView())
                }

                Section("About") {
                    NavigationLink("About", destination: AboutView())
                }

                #if DEBUG
                DeveloperToolsSection()
                #endif

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
}
