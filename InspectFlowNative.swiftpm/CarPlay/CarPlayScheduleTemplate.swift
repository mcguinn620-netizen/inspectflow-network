import CarPlay

final class CarPlayScheduleTemplate {
    func make(stops: [CarPlayStop]) -> CPListTemplate {
        CarPlayStopListTemplate().make(stops: stops)
    }
}
