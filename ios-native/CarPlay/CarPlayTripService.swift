import Foundation
import AVFoundation

/// Drives the CarPlay live-trip experience using the same TripTrackingController
/// the phone app uses. CarPlay never owns trip state.
@MainActor
final class CarPlayTripService {
    static let shared = CarPlayTripService()

    private let synthesizer = AVSpeechSynthesizer()

    func activeSnapshot() -> TripTrackingController.Snapshot? {
        TripTrackingController.shared.snapshot
    }

    func startTrip(orgId: UUID, userId: UUID) {
        // CarPlay can resume an existing trip but won't create one — phone is the controller.
        TripTrackingController.shared.restoreIfNeeded()
    }

    func todaysStops() -> [CarPlayStop] {
        // Driven by `trip_stops` for the active trip. Empty when no trip is live.
        []
    }

    func markArrived(stopID: UUID) {
        speak("You have arrived")
        let payload = (try? JSONSerialization.data(withJSONObject: [
            "status": "arrived",
            "arrived_at": ISO8601DateFormatter().string(from: Date()),
        ])) ?? Data()
        Outbox.shared.enqueueRaw(
            table: "trip_stops",
            op: .update,
            payload: payload,
            matchColumn: "id",
            matchValue: stopID.uuidString
        )
    }

    func skip(stopID: UUID) {
        let payload = (try? JSONSerialization.data(withJSONObject: ["status": "skipped"])) ?? Data()
        Outbox.shared.enqueueRaw(
            table: "trip_stops",
            op: .update,
            payload: payload,
            matchColumn: "id",
            matchValue: stopID.uuidString
        )
    }

    func announceNext(_ stop: CarPlayStop) {
        speak("Next stop: \(stop.title)")
    }

    private func speak(_ phrase: String) {
        let utterance = AVSpeechUtterance(string: phrase)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }
}
