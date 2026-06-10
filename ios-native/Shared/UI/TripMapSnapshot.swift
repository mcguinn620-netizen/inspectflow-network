import MapKit
import SwiftUI

/// Renders a trip's route as a static map snapshot with red Start/End pins.
/// Uses `MKMapSnapshotter` so the view is lightweight and prints cleanly into the
/// mileage detail screen without a live `MKMapView` underneath.
struct TripMapSnapshot: View {
    let points: [TripLocationPoint]
    var height: CGFloat = 280

    @State private var snapshot: UIImage?
    @State private var renderedSize: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let snapshot {
                    Image(uiImage: snapshot)
                        .resizable()
                        .scaledToFill()
                } else if points.isEmpty {
                    placeholder(text: "No GPS points recorded for this trip.")
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            .frame(width: geo.size.width, height: height)
            .clipped()
            .task(id: TaskKey(width: geo.size.width, count: points.count)) {
                await render(width: geo.size.width)
            }
        }
        .frame(height: height)
        .accessibilityLabel("Trip route map")
    }

    private struct TaskKey: Equatable {
        let width: CGFloat
        let count: Int
    }

    private func placeholder(text: String) -> some View {
        Text(text)
            .font(AINTheme.Font.caption())
            .foregroundStyle(AINTheme.Color.textSecondary)
            .multilineTextAlignment(.center)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AINTheme.Color.surfaceMuted)
    }

    @MainActor
    private func render(width: CGFloat) async {
        guard !points.isEmpty, width > 0 else { return }
        let coords = points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        guard let region = Self.region(for: coords) else { return }

        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = CGSize(width: width, height: height)
        options.scale = UIScreen.main.scale
        options.mapType = .standard

        let snapshotter = MKMapSnapshotter(options: options)
        do {
            let snap = try await snapshotter.start()
            snapshot = Self.annotate(snap, coords: coords)
        } catch {
            // Surface as the placeholder; surfacing a thrown error inline would be noisier than it's worth here.
            snapshot = nil
        }
    }

    private static func region(for coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        guard let first = coords.first else { return nil }
        var minLat = first.latitude, maxLat = first.latitude
        var minLng = first.longitude, maxLng = first.longitude
        for c in coords {
            minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
            minLng = min(minLng, c.longitude); maxLng = max(maxLng, c.longitude)
        }
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.005, (maxLat - minLat) * 1.4),
            longitudeDelta: max(0.005, (maxLng - minLng) * 1.4)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    private static func annotate(_ snapshot: MKMapSnapshotter.Snapshot, coords: [CLLocationCoordinate2D]) -> UIImage {
        let image = snapshot.image
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { ctx in
            image.draw(at: .zero)

            // Polyline.
            let path = UIBezierPath()
            for (i, c) in coords.enumerated() {
                let p = snapshot.point(for: c)
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            UIColor.black.setStroke()
            path.lineWidth = 3
            path.lineJoinStyle = .round
            path.stroke()

            // Start + End pins.
            if let start = coords.first { drawPin(at: snapshot.point(for: start), label: "Start", in: ctx.cgContext) }
            if coords.count > 1, let end = coords.last { drawPin(at: snapshot.point(for: end), label: "End", in: ctx.cgContext) }
        }
    }

    private static func drawPin(at point: CGPoint, label: String, in ctx: CGContext) {
        let radius: CGFloat = 14
        let rect = CGRect(x: point.x - radius, y: point.y - radius * 2, width: radius * 2, height: radius * 2)
        ctx.setFillColor(UIColor.systemRed.cgColor)
        ctx.fillEllipse(in: rect)
        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineWidth(2)
        ctx.strokeEllipse(in: rect)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: UIColor.black,
        ]
        let str = NSAttributedString(string: label, attributes: attrs)
        let size = str.size()
        let textRect = CGRect(x: point.x - size.width / 2, y: point.y + 2, width: size.width, height: size.height)
        str.draw(in: textRect)
    }
}
