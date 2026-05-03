import Foundation

final class CarPlayTripService {
    func activeTrip() -> Trip? {
#if DEBUG
        return Trip(id: UUID(), jobID: UUID(), status: "in_progress")
#else
        return nil
#endif
    }

    func todaysStops() -> [CarPlayStop] {
#if DEBUG
        return [
            CarPlayStop(id: UUID(), title: "123 Market St", subtitle: "Pickup • 9:00 AM"),
            CarPlayStop(id: UUID(), title: "455 Howard St", subtitle: "Inspection • 10:15 AM"),
            CarPlayStop(id: UUID(), title: "1 Ferry Building", subtitle: "Drop-off • 11:30 AM")
        ]
#else
        return []
#endif
    }

    func markArrived(stopID: UUID) {}
    func skip(stopID: UUID) {}
}
