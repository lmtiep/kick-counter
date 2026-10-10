import KickCore

/// Notification texts in the current app language. Read again whenever the
/// language changes, so pending reminders are rescheduled in it (spec §2.2).
enum ReminderTexts {
    static var overdue: NotificationText {
        NotificationText(title: L10n.overdueTitle, body: L10n.overdueBody)
    }

    static var daily: NotificationText {
        NotificationText(title: L10n.reminderTitle, body: L10n.reminderBody)
    }

    /// The contraction alert's one-time notification (phase 20): the alert
    /// card's text under a short title.
    static func contractionAlert(_ alert: ContractionAlert) -> NotificationText? {
        switch alert {
        case .none: nil
        case .fiveOneOne:
            NotificationText(title: L10n.contractionNotificationFiveOneOneTitle, body: L10n.contractionAlertFiveOneOne)
        case .pretermRegular:
            NotificationText(title: L10n.contractionNotificationPretermTitle, body: L10n.contractionAlertPreterm)
        }
    }

    static var appointment: NotificationText {
        NotificationText(title: L10n.appointmentsReminderTitle, body: L10n.appointmentsReminderBody)
    }

    static var cycle: CycleReminderTexts {
        CycleReminderTexts(
            fertile: NotificationText(title: L10n.cycleReminderFertileTitle, body: L10n.cycleReminderFertileBody),
            period: NotificationText(title: L10n.cycleReminderPeriodTitle, body: L10n.cycleReminderPeriodBody),
            late: NotificationText(title: L10n.cycleReminderLateTitle, body: L10n.cycleReminderLateBody),
            bleed: NotificationText(title: L10n.cycleReminderBleedTitle, body: L10n.cycleReminderBleedBody),
            bleedLate: NotificationText(title: L10n.cycleReminderBleedLateTitle, body: L10n.cycleReminderBleedLateBody)
        )
    }

    static var pill: PillReminderTexts {
        let reminderTitle = L10n.pillNotificationTitle
        let followUpTitle = L10n.pillNotificationFollowUpTitle
        // Bodies are formatted when scheduled, in the language of that moment.
        return PillReminderTexts(
            reminder: { number, count in
                NotificationText(title: reminderTitle, body: L10n.pillNotificationBody(number, count))
            },
            followUp: { number, count in
                NotificationText(title: followUpTitle, body: L10n.pillNotificationFollowUpBody(number, count))
            },
            renew: NotificationText(title: reminderTitle, body: L10n.pillNotificationRenewBody)
        )
    }
}
