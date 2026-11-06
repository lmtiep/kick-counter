import Foundation
import KickCore

/// Siri, Shortcuts and Control Center strings (1.1). Dialogs are generic: no numbers, no medical wording.
extension L10n {
    static func siriDialog(_ result: SiriResult) -> String {
        switch result {
        case .kickRecorded: t("intent.siri.dialog.kickRecorded")
        case .contractionStarted: t("intent.siri.dialog.contractionStarted")
        case .contractionStopped: t("intent.siri.dialog.contractionStopped")
        case .contractionDiscarded: t("intent.siri.dialog.contractionDiscarded")
        case .trackingEnded: t("intent.siri.dialog.trackingEnded")
        case .nothingToEnd: t("intent.siri.dialog.nothingToEnd")
        case .needsPregnancyMode: t("intent.siri.dialog.needsPregnancy")
        case .trackingCycle: t("intent.siri.dialog.trackingCycle")
        case .failed: t("intent.siri.dialog.failed")
        }
    }

    static var controlKicksLabel: String { t("control.kicks.label") }
    static var controlContractionLabel: String { t("control.contraction.label") }
}
