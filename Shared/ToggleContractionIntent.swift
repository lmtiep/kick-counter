import AppIntents
import Foundation
import KickCore

/// Set by the app at launch, as `KickIntentBridge`: LiveActivityIntent.perform
/// runs in the app's process, so the handler is always present when it fires.
@MainActor
enum ContractionIntentBridge {
    static var toggle: (@MainActor (ContractionToggleAction) async -> Void)?
}

/// What the Lock Screen's button showed when it was tapped.
enum ContractionIntentAction: String, AppEnum {
    case start
    case stop

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "intent.toggleContraction.action"
    static let caseDisplayRepresentations: [ContractionIntentAction: DisplayRepresentation] = [
        .start: "la.contraction.start",
        .stop: "la.contraction.stop",
    ]

    var toggleAction: ContractionToggleAction {
        switch self {
        case .start: .start
        case .stop: .stop
        }
    }
}

/// The contraction Live Activity's Start/Stop button (phase 20 spec §4.4):
/// `ContractionCoordinator.toggle(_:)` without opening the app. The button
/// passes the action it shows, so a tap on an out-of-date Lock Screen (a
/// "Bắt đầu" while one already runs) does nothing instead of the opposite.
struct ToggleContractionIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "intent.toggleContraction.title"
    static let isDiscoverable = false

    @Parameter(title: "intent.toggleContraction.action")
    var action: ContractionIntentAction

    init() {}

    init(action: ContractionIntentAction) {
        self.action = action
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        await ContractionIntentBridge.toggle?(action.toggleAction)
        return .result()
    }
}
