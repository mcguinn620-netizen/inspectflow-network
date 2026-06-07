import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    init() {
        // Themed tab bar appearance.
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor(AINTheme.Color.surface)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().tintColor = UIColor(AINTheme.Color.accent)

        let nav = UINavigationBarAppearance()
        nav.configureWithDefaultBackground()
        nav.backgroundColor = UIColor(AINTheme.Color.background)
        nav.titleTextAttributes = [.foregroundColor: UIColor(AINTheme.Color.textPrimary)]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor(AINTheme.Color.textPrimary)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
    }

    var body: some View {
        VStack(spacing: 0) {
            #if DEBUG
            AINDebugBanner()
            #endif
            TabView {
                if appState.effectiveRole == "inspector" { // role-aware home tab
                    InspectorDashboardHomeView().tabItem { Label("Dashboard", systemImage: "house.fill") }
                } else {
                    DashboardView().tabItem { Label("Dashboard", systemImage: "house.fill") }
                }
                ScheduleView().tabItem { Label("Schedule", systemImage: "calendar") }
                JobsView().tabItem { Label("Jobs", systemImage: "briefcase.fill") }
                TripsView().tabItem { Label("Trips", systemImage: "map.fill") }
                MoreView().tabItem { Label("More", systemImage: "ellipsis.circle.fill") }
            }
            .tint(AINTheme.Color.accent)
        }
    }
}

struct MoreView: View {
    @EnvironmentObject private var appState: AppState
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Intake Inbox", destination: IntakeInboxView(appState: appState))
                NavigationLink("Drive", destination: DriveView())
                NavigationLink("Tax", destination: TaxView())
                NavigationLink("Vehicles", destination: VehiclesView())
                NavigationLink("Inspections", destination: InspectionsView())
                NavigationLink("Settings", destination: SettingsView())
            }
            .navigationTitle("More")
        }
    }
}
