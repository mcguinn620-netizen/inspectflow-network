import Foundation
import CoreLocation

/// Single-source live location tracker. Mirrors web `tripTracking.ts` accuracy and
/// movement filters so iOS and web produce comparable trip_location_points rows.
public struct LocationSample: Equatable {
    public let latitude: Double
    public let longitude: Double
    public let accuracy: Double?
    public let speed: Double?
    public let heading: Double?
    public let timestamp: Date

    public init(latitude: Double, longitude: Double, accuracy: Double?, speed: Double?, heading: Double?, timestamp: Date) {
        self.latitude = latitude
        self.longitude = longitude
        self.accuracy = accuracy
        self.speed = speed
        self.heading = heading
        self.timestamp = timestamp
    }
}

public final class LocationTracker: NSObject, CLLocationManagerDelegate {
    public static let shared = LocationTracker()

    public typealias Update = (LocationSample) -> Void

    private let manager = CLLocationManager()
    private var onUpdate: Update?
    private(set) public var isTracking = false

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10 // meters
        manager.pausesLocationUpdatesAutomatically = false
        if #available(iOS 11.0, *) {
            manager.showsBackgroundLocationIndicator = true
        }
    }

    public func requestAuthorization() {
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse {
            manager.requestAlwaysAuthorization()
        }
    }

    public func start(onUpdate: @escaping Update) {
        self.onUpdate = onUpdate
        requestAuthorization()
        // Background updates require Always + UIBackgroundModes=location in Info.plist.
        if manager.authorizationStatus == .authorizedAlways {
            manager.allowsBackgroundLocationUpdates = true
        }
        manager.startUpdatingLocation()
        manager.startMonitoringSignificantLocationChanges()
        isTracking = true
    }

    public func stop() {
        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
        isTracking = false
        onUpdate = nil
    }

    // MARK: - CLLocationManagerDelegate

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for loc in locations {
            let sample = LocationSample(
                latitude: loc.coordinate.latitude,
                longitude: loc.coordinate.longitude,
                accuracy: loc.horizontalAccuracy >= 0 ? loc.horizontalAccuracy : nil,
                speed: loc.speed >= 0 ? loc.speed : nil,
                heading: loc.course >= 0 ? loc.course : nil,
                timestamp: loc.timestamp
            )
            onUpdate?(sample)
        }
    }

    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways {
            manager.allowsBackgroundLocationUpdates = true
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Transient errors are tolerated; tracker stays alive.
    }
}
