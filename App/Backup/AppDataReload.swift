import ActivityKit
import KickCore
@preconcurrency import UserNotifications

/// What surrounds replacing the store and the owned preferences, by "Xoá toàn bộ
/// dữ liệu" (phase 12) or by restoring a backup (phase 15): every notification and
/// Live Activity of the old data stops, then the coordinators load the new data
/// and schedule their reminders again as usual.
@MainActor
enum AppDataReload {
    /// Forgets the shown session and its completion card; stops the daily
    /// reminder, the 2-hour alerts, every notification and every kick Live
    /// Activity. A restore calls it before replacing the store, so a "+1" from
    /// the Lock Screen cannot land in the restored data.
    static func stopEverything(kicks: KickCoordinator, contractions: ContractionCoordinator) async {
        await kicks.resetAfterDataDeletion()
        // Forgets the timer and ends its Live Activity (phase 20).
        await contractions.resetAfterDataDeletion()
        guard !AppEnvironment.isUITesting else { return }
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        for activity in Activity<KickActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        for activity in Activity<ContractionActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// Loads every coordinator from the store and the preferences as they are now
    /// (which schedules their reminders), and the stored daily kick reminder.
    static func reload(
        kicks: KickCoordinator,
        appointments: AppointmentCoordinator,
        cycle: CycleCoordinator,
        weight: WeightCoordinator,
        pill: PillCoordinator,
        contractions: ContractionCoordinator
    ) async {
        await kicks.load()
        await appointments.load()
        await cycle.load()
        await weight.load()
        await pill.load()
        await contractions.load()
        // Never prompting, and never in partner mode (as RootView after a language change).
        let reminder = DailyKickReminder.stored
        if reminder.enabled, AppMode.load(from: AppGroup.defaults) != .partner, await kicks.notificationsAuthorized() {
            _ = await DailyKickReminder.apply(reminder, with: kicks)
        }
    }

    static func afterReplacingAllData(
        kicks: KickCoordinator,
        appointments: AppointmentCoordinator,
        cycle: CycleCoordinator,
        weight: WeightCoordinator,
        pill: PillCoordinator,
        contractions: ContractionCoordinator
    ) async {
        await stopEverything(kicks: kicks, contractions: contractions)
        await reload(
            kicks: kicks, appointments: appointments, cycle: cycle, weight: weight, pill: pill, contractions: contractions
        )
    }
}
