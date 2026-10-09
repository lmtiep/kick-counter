import KickCore
import OSLog
@preconcurrency import UserNotifications

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "pill")

/// The app's one `UNUserNotificationCenter` delegate (phase 17 spec §4.2). Nothing
/// else sets one (`PartnerAppDelegate` is a `UIApplicationDelegate` only), so it
/// does not compose with another: it handles the pill's "Đã uống" action and
/// leaves every other notification as before. `willPresent` is not implemented,
/// so notifications still do not show while the app is open, as before.
@MainActor
final class PillNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PillNotificationDelegate()

    private weak var pill: PillCoordinator?

    /// Called from `KickCounterApp.init`, before launch finishes, so an action
    /// that launches the app in the background is delivered here.
    func install(pill: PillCoordinator) {
        self.pill = pill
        guard !AppEnvironment.isUITesting else { return }
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        registerCategory()
    }

    /// The "Đã uống" action in the current language; called again when it changes.
    /// Merged into the registered categories rather than replacing them, so a
    /// category another part of the app (or a later phase) registers survives.
    func registerCategory() {
        let taken = UNNotificationAction(
            identifier: PillReminderPlan.takenActionIdentifier,
            title: L10n.pillActionTaken,
            options: []
        )
        let category = UNNotificationCategory(
            identifier: PillReminderPlan.categoryIdentifier,
            actions: [taken],
            intentIdentifiers: [],
            options: []
        )
        let center = UNUserNotificationCenter.current()
        Task {
            var categories = await center.notificationCategories()
            categories = categories.filter { $0.identifier != PillReminderPlan.categoryIdentifier }
            categories.insert(category)
            center.setNotificationCategories(categories)
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == PillReminderPlan.takenActionIdentifier else { return }
        let content = response.notification.request.content
        guard content.categoryIdentifier == PillReminderPlan.categoryIdentifier,
              let key = content.userInfo[PillReminderPlan.dayUserInfoKey] as? Int,
              let day = CalendarDay(key: key)
        else { return }
        await markTaken(on: day)
    }

    private func markTaken(on day: CalendarDay) async {
        guard let pill else {
            logger.error("A pill action arrived before the app was ready")
            return
        }
        // Reads the store first: the app may have just been launched for this.
        await pill.load()
        if let failure = await pill.markTaken(on: day) {
            logger.error("Marking the pill from a notification failed: \(String(describing: failure))")
        }
    }
}
