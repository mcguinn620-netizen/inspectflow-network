import UIKit
import Foundation
import MapKit

@MainActor
final class MapsLookupService {
    static let shared = MapsLookupService()

    private init() {}

    func open(job: Job) {
        open(query: job.location ?? job.title, fallbackTitle: job.title)
    }

    func open(stop: TripStop) {
        if let latitude = stop.latitude, let longitude = stop.longitude {
            let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
            let item = MKMapItem(placemark: placemark)
            item.name = stop.label ?? stop.address
            item.openInMaps(launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving,
            ])
            return
        }

        guard let address = stop.address, !address.isEmpty else { return }
        open(query: address, fallbackTitle: stop.label)
    }

    func open(address: String, title: String? = nil) {
        open(query: address, fallbackTitle: title)
    }

    private func open(query: String, fallbackTitle: String?) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query

        Task {
            let search = MKLocalSearch(request: request)

            if let response = try? await search.start(),
               let item = response.mapItems.first {
                item.openInMaps(launchOptions: [
                    MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving,
                ])
                return
            }

            let fallbackQuery = [fallbackTitle, query]
                .compactMap { $0 }
                .joined(separator: " ")
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let fallbackURL = URL(string: "http://maps.apple.com/?q=\(fallbackQuery)") {
                await UIApplication.shared.open(fallbackURL)
            }
        }
    }
}
