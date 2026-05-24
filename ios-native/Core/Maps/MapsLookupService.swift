import UIKit
import Foundation
import MapKit

@MainActor
final class MapsLookupService {
    static let shared = MapsLookupService()

    private init() {}

    func open(job: Job) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = job.location ?? job.title

        Task {
            if let item = try? await MKLocalSearch(request: request).start().mapItems.first {
                item.name = job.title
                item.openInMaps()
                return
            }

            if let location = job.location?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let fallback = URL(string: "http://maps.apple.com/?q=\(location)") {
                UIApplication.shared.open(fallback)
            }
        }
    }
}
