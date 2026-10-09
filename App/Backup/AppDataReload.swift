import ActivityKit
import KickCore
@preconcurrency import UserNotifications

/// What follows replacing the store and the owned preferences, by "Xoá toàn bộ
/// dữ liệu" (phase 12) or by restoring a backup (phase 15): every notification and
/// Live Activity of the old data stops, then the coordinators load the new data
/// and schedule their reminders again as usual.
@MainActor
enum AppDataReload {
    static func afterReplacingAllData(
        kicks: KickCoordinator,
        appointments: AppointmentCoordinator,
        cycle: CycleCoordinator,
        weight: WeightCoordinator
    ) async {
        // Forgets the old session and its completion card; stops the daily
        // reminder, the 2-hour alerts and every kick Live Activity.
        await kicks.resetAfterDataDeletion()
        if !AppEnvironment.isUITesting {
            let center = UNUserNotificationCenter.current()
            center.removeAllPendingNotificationRequests()
            center.removeAllDeliveredNotifications()
            for activity in Activity<KickActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        await kicks.load()
        await appointments.load()
        await cycle.load()
        await weight.load()
    }
}
