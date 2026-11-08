import AppIntents

/// Siri, Spotlight and Shortcuts phrases (1.1), no setup needed. Every phrase carries the app name, which
/// App Shortcuts require; the vi and en wording lives in `AppShortcuts.xcstrings`.
struct LunaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecordKickIntent(),
            phrases: [
                "Record a kick in \(.applicationName)",
                "Log a kick in \(.applicationName)",
            ],
            shortTitle: "intent.shortcut.recordKick.title",
            systemImageName: "hand.tap.fill"
        )
        AppShortcut(
            intent: TimeContractionIntent(),
            phrases: [
                "Time a contraction in \(.applicationName)",
                "Start a contraction in \(.applicationName)",
            ],
            shortTitle: "intent.shortcut.timeContraction.title",
            systemImageName: "timer"
        )
        AppShortcut(
            intent: StopContractionTimingIntent(),
            phrases: [
                "Stop timing contractions in \(.applicationName)",
                "End contraction tracking in \(.applicationName)",
            ],
            shortTitle: "intent.shortcut.stopContractions.title",
            systemImageName: "stop.circle"
        )
    }
}
