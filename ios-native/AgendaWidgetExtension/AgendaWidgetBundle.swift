import SwiftUI
import WidgetKit

@main
struct AgendaWidgetBundle: WidgetBundle {
    var body: some Widget {
        AgendaWidget()
        if #available(iOS 16.1, *) {
            UpcomingEventLiveActivityWidget()
        }
    }
}
