import AppIntents
import SwiftUI
import WidgetKit

/// Control Center, Lock Screen and Action Button controls (iOS 18+). On iOS 17 the app runs and these are
/// simply missing (`KickCounterWidgetsBundle` adds them behind `#available`). Each one runs an intent that
/// the app performs in its own process, with no unlock-to-open.
@available(iOS 18, *)
struct KickCountControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.lmtiep.kickcounter.control.kicks") {
            ControlWidgetButton(action: RecordKickIntent()) {
                Label(L10n.controlKicksLabel, systemImage: "hand.tap.fill")
            }
        }
        .displayName("control.kicks.name")
        .description("control.kicks.description")
    }
}

@available(iOS 18, *)
struct ContractionControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.lmtiep.kickcounter.control.contraction") {
            ControlWidgetButton(action: TimeContractionIntent()) {
                Label(L10n.controlContractionLabel, systemImage: "timer")
            }
        }
        .displayName("control.contraction.name")
        .description("control.contraction.description")
    }
}
