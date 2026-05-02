import SwiftUI

@main
struct NutriTrackApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .task {
                    await store.bootstrap()
                }
        }
    }
}
