import SwiftUI

struct RootTabView: View {
    @EnvironmentObject var store: AppStore
    @State private var showSettings = false

    var body: some View {
        TabView {
            NavigationStack { DiningView() }
                .tabItem { Label("Dining", systemImage: "fork.knife") }

            NavigationStack { TodayView() }
                .tabItem { Label("Today", systemImage: "sun.max") }

            NavigationStack { WeekView() }
                .tabItem { Label("Week", systemImage: "calendar") }

            NavigationStack { FavoritesView() }
                .tabItem { Label("Favorites", systemImage: "heart") }
        }
        .tint(BSUColors.cardinalRed)
        .sheet(isPresented: $showSettings) { SettingsView() }
        .toolbarBackground(BSUColors.cardinalRed, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: { Image(systemName: "gearshape") }
            }
        }
    }
}
