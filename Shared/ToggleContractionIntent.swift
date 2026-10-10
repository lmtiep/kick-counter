import AppIntents
import Foundation

/// Set by the app at launch, as `KickIntentBridge`: LiveActivityIntent.perform
/// runs in the app's process, so the handler is always present when it fires.
@MainActor
enum ContractionIntentBridge {
    static var toggle: (@MainActor () async -> Void)?
}

/// The contraction Live Activity's Start/Stop button (phase 20 spec §4.4):
/// `ContractionCoordinator.toggle()` without opening the app.
struct ToggleContractionIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "intent.toggleContraction.title"
    static let isDiscoverable = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        await ContractionIntentBridge.toggle?()
        return .result()
    }
}
