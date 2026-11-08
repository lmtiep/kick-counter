import Foundation
import KickCore

/// Siri, Shortcuts and Control Center strings (1.1). Dialogs are generic: no numbers, no medical wording.
extension L10n {
    static func siriDialog(_ result: SiriResult) -> String {
        switch result {
        case .kickRecorded: t("intent.shortcut.dialog.kickRecorded")
        case .contractionStarted: t("intent.shortcut.dialog.contractionStarted")
        case .contractionStopped: t("intent.shortcut.dialog.contractionStopped")
        case .contractionDiscarded: t("intent.shortcut.dialog.contractionDiscarded")
        case .trackingEnded: t("intent.shortcut.dialog.trackingEnded")
        case .nothingToEnd: t("intent.shortcut.dialog.nothingToEnd")
        case .needsPregnancyMode: t("intent.shortcut.dialog.needsPregnancy")
        case .trackingCycle: t("intent.shortcut.dialog.trackingCycle")
        case .failed: t("intent.shortcut.dialog.failed")
        }
    }

    static var controlKicksLabel: String { t("control.kicks.label") }
    static var controlContractionLabel: String { t("control.contraction.label") }
}
