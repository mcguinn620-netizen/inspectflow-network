import SwiftUI
struct RootTabView: View { var body: some View { TabView { DiningView().tabItem{Label("Dining",systemImage:"fork.knife")}; TodayView().tabItem{Label("Today",systemImage:"sun.max")}; WeekView().tabItem{Label("Week",systemImage:"calendar")}; FavoritesView().tabItem{Label("Favorites",systemImage:"heart")}}.tint(BSUColors.cardinalRed) }}
