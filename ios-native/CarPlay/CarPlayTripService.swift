import Foundation

final class CarPlayTripService {
    func activeTrip() -> Trip? { nil }
    func todaysStops() -> [CarPlayStop] { [] }
    func markArrived(stopID: UUID) {}
    func skip(stopID: UUID) {}
}
