// CarPlay scene delegate stub.
// This file is intentionally not built by Lovable's web sandbox — it is
// committed for the local Xcode project that you create with
// `npx cap add ios`. Move it (or symlink) into
// `ios/App/App/CarPlay/` after running `cap add`.
//
// Apple requires:
//   1. CarPlay entitlement (apply via developer.apple.com)
//   2. Info.plist:
//      <key>UIApplicationSceneManifest</key>
//      <dict>
//        <key>UISceneConfigurations</key>
//        <dict>
//          <key>CPTemplateApplicationSceneSessionRoleApplication</key>
//          <array>
//            <dict>
//              <key>UISceneClassName</key>
//              <string>CPTemplateApplicationScene</string>
//              <key>UISceneDelegateClassName</key>
//              <string>$(PRODUCT_MODULE_NAME).CarPlaySceneDelegate</string>
//              <key>UISceneConfigurationName</key>
//              <string>CarPlay</string>
//            </dict>
//          </array>
//        </dict>
//      </dict>
//
// Data flow (see docs/native/CARPLAY_CONTRACT.md):
//   1. CarPlayDataSource.fetchTodayStops() → reads from Supabase using the
//      session token persisted by the JS layer in Capacitor Preferences
//      under key "supabase.auth.token".
//   2. Renders a CPListTemplate of today's stops.
//   3. Tapping a stop opens a CPMapTemplate with the next-stop pin and an
//      "Arrived" button that POSTs back to Supabase via CarPlayDataSource.
//
// All persistent state lives in Supabase — CarPlay is a thin projection.

#if canImport(CarPlay)
import CarPlay
import UIKit

@available(iOS 14.0, *)
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    var interfaceController: CPInterfaceController?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        showTodayStops()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
    }

    private func showTodayStops() {
        Task {
            let stops = (try? await CarPlayDataSource.shared.fetchTodayStops()) ?? []
            let items: [CPListItem] = stops.map { stop in
                let item = CPListItem(text: stop.label, detailText: stop.address)
                item.handler = { [weak self] _, completion in
                    self?.showMap(for: stop)
                    completion()
                }
                return item
            }
            let section = CPListSection(items: items, header: "Today", sectionIndexTitle: nil)
            let template = CPListTemplate(title: "Stops", sections: [section])
            await MainActor.run {
                self.interfaceController?.setRootTemplate(template, animated: true) { _, _ in }
            }
        }
    }

    private func showMap(for stop: CarPlayStop) {
        // Placeholder: a full CPMapTemplate setup requires a MapKit overlay.
        // Hand off to Apple Maps for turn-by-turn until you implement an
        // in-CarPlay map renderer.
        guard let url = URL(string: "https://maps.apple.com/?ll=\(stop.latitude),\(stop.longitude)") else { return }
        UIApplication.shared.open(url)
    }
}

struct CarPlayStop {
    let id: String
    let label: String
    let address: String
    let latitude: Double
    let longitude: Double
}

/// Stub data source. Replace with a real Supabase REST call using
/// URLSession and the JWT pulled from Capacitor Preferences.
final class CarPlayDataSource {
    static let shared = CarPlayDataSource()

    func fetchTodayStops() async throws -> [CarPlayStop] {
        // TODO: GET /rest/v1/trip_stops?status=eq.pending&order=sort_order
        //       with the user's bearer token and the project's anon key.
        return []
    }

    func markArrived(stopId: String) async throws {
        // TODO: POST /functions/v1/trip-arrive  { stopId }
    }
}
#endif
