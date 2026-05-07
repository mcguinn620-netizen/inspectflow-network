import SwiftUI

@main
struct AutoInspectorNetworkApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif
    @StateObject private var appState = AppState()
    @StateObject private var syncEngine = SyncEngine()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(syncEngine)
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                .task { await appState.bootstrap() }
                .tint(AINBrand.accent)
        }
    }
}
