import SwiftUI
import WidgetKit

@main
struct KickCounterWidgetsBundle: WidgetBundle {
    var body: some Widget {
        LunaWidget()
        KickLiveActivityWidget()
        ContractionLiveActivityWidget()
        if #available(iOS 18, *) {
            KickCountControl()
            ContractionControl()
        }
    }
}
