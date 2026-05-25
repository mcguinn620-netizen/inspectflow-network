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
            let search = MKLocalSearch(request: request)
            
            // Perform the search
            if let response = try? await search.start(),
               let item = response.mapItems.first {
                
                // Use openInMaps with launch options if you need custom behavior
                item.openInMaps(launchOptions: [
                    MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                ])
                return
            }

            // Fallback: Use URL encoding to open maps with a custom query
            // This is where you can pass the job title as the query
            let query = (job.title + " " + (job.location ?? "")).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let fallbackURL = URL(string: "http://maps.apple.com/?q=\(query)") {
                await UIApplication.shared.open(fallbackURL)
            }
        }
    }
}
