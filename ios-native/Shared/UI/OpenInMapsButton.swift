import MapKit
import SwiftUI
import UIKit

struct OpenInMapsButton: View {
    let address: String

    var body: some View {
        Button("Open in Maps") {
            let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            guard let url = URL(string: "http://maps.apple.com/?q=\(encoded)") else { return }
            UIApplication.shared.open(url)
        }
    }
}
