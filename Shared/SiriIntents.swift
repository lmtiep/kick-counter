import AppIntents
import Foundation
import KickCore

/// Set by the app at launch, like `KickIntentBridge`. These are `LiveActivityIntent`s so the system
/// runs them in the app's process (also from Siri, Shortcuts, the Action Button and Controls), where the
/// bridge is present. Without it (the extension process) the result asks her to open the app.
@MainActor
enum SiriIntentBridge {
    static var run: (@MainActor (SiriCommand) async -> SiriResult)?
}

/// "Ghi cử động thai": one kick, like the Live Activity "+" button; starts a session if none runs.
struct RecordKickIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "intent.siri.recordKick.title"
    static let description = IntentDescription("intent.siri.recordKick.description")

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: await SiriDialog.perform(.recordKick))
    }
}

/// "Bấm cơn gò": starts timing a contraction, or ends the running one.
struct TimeContractionIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "intent.siri.timeContraction.title"
    static let description = IntentDescription("intent.siri.timeContraction.description")

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: await SiriDialog.perform(.timeContraction))
    }
}

/// "Kết thúc theo dõi cơn gò": ends the episode; every contraction is kept.
struct StopContractionTimingIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "intent.siri.stopContractions.title"
    static let description = IntentDescription("intent.siri.stopContractions.description")

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: await SiriDialog.perform(.stopContractions))
    }
}

private enum SiriDialog {
    @MainActor static func perform(_ command: SiriCommand) async -> IntentDialog {
        let result = await SiriIntentBridge.run?(command) ?? .failed
        return IntentDialog(stringLiteral: L10n.siriDialog(result))
    }
}
