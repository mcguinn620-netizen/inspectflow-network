#if canImport(CarPlay)
import CarPlay
import MapKit

@MainActor
final class CarPlayNavigationCoordinator {
    private var interfaceController: CPInterfaceController?
    private let tripService = CarPlayTripService()

    func connect(interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        let template = CarPlayScheduleTemplate().make(stops: tripService.todaysStops())
        interfaceController.setRootTemplate(template, animated: false)
    }

    func openInMaps(stop: CarPlayStop) {
        let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude))
        MKMapItem(placemark: placemark).openInMaps()
    }
}
#endif
