import KickCore

/// The optional check-in notification (1.1 item 4, spec §4.5): one pending
/// request, `care-checkin`, at 10:00 on the next check-in day. Its text is
/// neutral and never names the pregnancy, the loss or the birth.
@MainActor
enum CareCheckInNotifications {
    static var text: NotificationText {
        NotificationText(title: L10n.appName, body: L10n.careNotificationBody)
    }

    /// Schedules or cancels it from the stored choices. Prompts only when
    /// `mayPrompt` (she just turned "Gửi thông báo nhẹ nhàng" on). Returns false
    /// when she wants it but notifications are not allowed.
    @discardableResult
    static func sync(mayPrompt: Bool = false) async -> Bool {
        guard !AppEnvironment.isUITesting else { return true }
        let defaults = AppGroup.defaults
        return await NotificationScheduler(center: SystemNotificationCenter()).syncCareCheckIn(
            end: PregnancyEndState.load(from: defaults),
            state: CareCheckInState.load(from: defaults),
            now: AppClock.now(),
            text: text,
            calendar: .current,
            mayPrompt: mayPrompt
        )
    }
}
