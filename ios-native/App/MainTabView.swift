import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView().tabItem { Label("Dashboard", systemImage: "house") }
            ScheduleView().tabItem { Label("Schedule", systemImage: "calendar") }
            JobsView().tabItem { Label("Jobs", systemImage: "briefcase") }
            TripsView().tabItem { Label("Trips", systemImage: "map") }
            MoreView().tabItem { Label("More", systemImage: "ellipsis.circle") }
        }
    }
}

struct MoreView: View {
    var body: some View {
        NavigationStack {
            List {
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
