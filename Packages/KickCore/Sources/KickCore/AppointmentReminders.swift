import Foundation
@preconcurrency import UserNotifications

/// Day-before reminders for appointments. Only `AppointmentCoordinator` calls these.
extension NotificationScheduler {
    public static let appointmentReminderPrefix = "appointment-"
    public static let appointmentReminderHour = 9
    /// At most this many appointment reminders are pending at once (the soonest),
    /// so with the cycle, kick and pill reminders the total stays under iOS's 64.
    public nonisolated static let maxAppointmentReminders = 20

    public static func appointmentReminderID(for id: UUID) -> String {
        "\(appointmentReminderPrefix)\(id.uuidString)"
    }

    /// 9:00 on the day before `date`.
    public static func appointmentReminderFireDate(for date: Date, calendar: Calendar = .current) -> Date? {
        guard let dayBefore = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: date)) else { return nil }
        return calendar.date(bySettingHour: appointmentReminderHour, minute: 0, second: 0, of: dayBefore)
    }

    /// Schedules (or replaces) the reminder for an appointment at 9:00 the day
    /// before. Returns false — after removing any stale reminder — when that
    /// time is not in the future.
    @discardableResult
    public func scheduleAppointmentReminder(
        id: UUID,
        date: Date,
        title: String,
        now: Date,
        text: NotificationText,
        calendar: Calendar = .current
    ) async throws -> Bool {
        let identifier = Self.appointmentReminderID(for: id)
        center.removePending(ids: [identifier])
        guard let fireDate = Self.appointmentReminderFireDate(for: date, calendar: calendar), fireDate > now else {
            return false
        }
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let content = text.makeContent()
        content.subtitle = title
        try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        return true
    }

    public func cancelAppointmentReminder(id: UUID) {
        center.removePending(ids: [Self.appointmentReminderID(for: id)])
    }

    /// Appointment ids that currently have a pending reminder.
    public func pendingAppointmentReminderIDs() async -> Set<UUID> {
        let prefix = Self.appointmentReminderPrefix
        return Set(await center.pendingRequestIDs().compactMap { identifier -> UUID? in
            guard identifier.hasPrefix(prefix) else { return nil }
            return UUID(uuidString: String(identifier.dropFirst(prefix.count)))
        })
    }
}
