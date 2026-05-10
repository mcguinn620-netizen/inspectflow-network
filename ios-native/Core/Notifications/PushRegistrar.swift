import Foundation
import UIKit
import UserNotifications

/// Registers for APNs and stores the device token in the `device_tokens` table.
@MainActor
public enum PushRegistrar {
    public static func registerIfNeeded(application: UIApplication) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }
    }

    public static func handle(deviceToken: Data) async {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        guard let userId = SupabaseService.shared.currentUserID?.uuidString else { return }
        let row: [String: Any] = [
            "user_id": userId,
            "token": token,
            "platform": "ios",
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "last_seen": ISO8601DateFormatter().string(from: Date()),
        ]
        let data = (try? JSONSerialization.data(withJSONObject: [row])) ?? Data()
        Outbox.shared.enqueueRaw(table: "device_tokens", op: .upsert, payload: data)
    }
}
