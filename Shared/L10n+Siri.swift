import Foundation
import KickCore

/// Siri, Shortcuts and Control Center strings (1.1). Dialogs are generic: no numbers, no medical wording.
extension L10n {
    static func siriDialog(_ result: SiriResult) -> String {
        switch result {
        case .kicksStarted: t("intent.siri.dialog.kicksStarted")
        case .kicksAlreadyRunning: t("intent.siri.dialog.kicksAlreadyRunning")
        case .contractionStarted: t("intent.siri.dialog.contractionStarted")
        case .contractionStopped: t("intent.siri.dialog.contractionStopped")
        case .contractionDiscarded: t("intent.siri.dialog.contractionDiscarded")
        case .trackingEnded: t("intent.siri.dialog.trackingEnded")
        case .nothingToEnd: t("intent.siri.dialog.nothingToEnd")
        case .needsPregnancyMode: t("intent.siri.dialog.needsPregnancy")
        case .failed: t("intent.siri.dialog.failed")
        }
    }

    static var controlKicksLabel: String { t("control.kicks.label") }
    static var controlContractionLabel: String { t("control.contraction.label") }
}
