import UIKit
import BackgroundTasks

final class AppDelegate: NSObject, UIApplicationDelegate {
    static let backgroundRefreshIdentifier = "com.autoinspectornetwork.refresh"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Ask for push permission and register on every cold start.
        Task { @MainActor in PushRegistrar.registerIfNeeded(application: application) }

        // Background refresh: drain outbox + restore active trip hourly.
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: AppDelegate.backgroundRefreshIdentifier,
            using: nil
        ) { task in
            Self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }
        Self.scheduleBackgroundRefresh()

        // Restore live trip if app was killed mid-trip.
        Task { @MainActor in TripTrackingController.shared.restoreIfNeeded() }
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in await PushRegistrar.handle(deviceToken: deviceToken) }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Silent — surfaced through Settings UI in a future build.
    }

    // MARK: - Background tasks

    static func scheduleBackgroundRefresh() {
        let req = BGAppRefreshTaskRequest(identifier: backgroundRefreshIdentifier)
        req.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        try? BGTaskScheduler.shared.submit(req)
    }

    static func handleBackgroundRefresh(task: BGAppRefreshTask) {
        scheduleBackgroundRefresh()
        let work = Task { @MainActor in
            // Drain pending mutations first; trip tracker stays alive across launches.
            await SyncEngineHolder.shared.runSync()
            TripTrackingController.shared.restoreIfNeeded()
        }
        task.expirationHandler = { work.cancel() }
        Task {
            _ = await work.value
            task.setTaskCompleted(success: true)
        }
    }
}

/// Holder so the AppDelegate (non-SwiftUI) can reach the shared SyncEngine instance.
@MainActor
final class SyncEngineHolder {
    static let shared = SyncEngineHolder()
    let engine = SyncEngine()
    func runSync() async { await engine.runSync() }
}
