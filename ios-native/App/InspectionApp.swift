import SwiftUI

@main
struct InspectionApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var syncEngine = SyncEngine()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(syncEngine)
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                .task { await appState.bootstrap() }
        }
    }
}
