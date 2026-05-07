#if canImport(CarPlay)
import CarPlay

final class CarPlayStopListTemplate {
    func make(stops: [CarPlayStop]) -> CPListTemplate {
        let items = stops.map { stop in
            CPListItem(text: stop.title, detailText: stop.subtitle)
        }
        let section = CPListSection(items: items)
        return CPListTemplate(title: "Stops", sections: [section])
    }
}
#endif
