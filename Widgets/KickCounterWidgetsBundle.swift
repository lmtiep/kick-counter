import SwiftUI
import WidgetKit

@main
struct KickCounterWidgetsBundle: WidgetBundle {
    var body: some Widget {
        KickLiveActivityWidget()
        ContractionLiveActivityWidget()
    }
}
