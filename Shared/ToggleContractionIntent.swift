import AppIntents
import Foundation
import KickCore

/// Set by the app at launch, as `KickIntentBridge`: LiveActivityIntent.perform
/// runs in the app's process, so the handler is always present when it fires.
@MainActor
enum ContractionIntentBridge {
    static var toggle: (@MainActor (ContractionToggleAction) async -> Void)?
    /// `ContractionCoordinator.endEpisode()`, for `EndContractionTrackingIntent`.
    static var endTracking: (@MainActor () async -> Void)?
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

/// The contraction Live Activity's "Kết thúc" button, shown only while resting:
/// `ContractionCoordinator.endEpisode()` without opening the app, which keeps
/// every contraction and ends the activity.
///
/// The Lock Screen cannot ask "Kết thúc theo dõi?" as the timer screen does.
/// That is accepted: nothing is deleted, and ending no longer changes the 5-1-1
/// alert (its run, `ContractionStats.alertRun`, ignores the end mark), so a
/// mistaken tap only ends the activity; the next "Bắt đầu" in the app starts
/// a new tracking session.
struct EndContractionTrackingIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "intent.endContractionTracking.title"
    static let isDiscoverable = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        await ContractionIntentBridge.endTracking?()
        return .result()
    }
}
