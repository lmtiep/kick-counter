import Foundation
@preconcurrency import UserNotifications

/// How she feels today, on the check-in card (spec §4.5). Stored nowhere but
/// as the low streak: the answers never leave the phone.
public enum CareFeeling: String, CaseIterable, Sendable {
    case good, okay, tired, sad, heavy

    /// Two low answers in a row add the "share it with someone close" line.
    public var isLow: Bool { self == .sad || self == .heavy }
}

/// The check-in state in `AppGroup.defaults` (spec §4.6): never in a model or a
/// backup, cleared by "delete all data" and by a new pregnancy.
public struct CareCheckInState: Equatable, Sendable {
    /// Profile's "Hỏi thăm tôi". Missing means on.
    public var enabled: Bool = true
    /// Profile's "Gửi thông báo nhẹ nhàng". Missing means off.
    public var notify: Bool = false
    /// "Cảm ơn, mình ổn rồi": stopped for good.
    public var stopped: Bool = false
    /// When the last check-in was answered or skipped.
    public var lastShown: Date?
    public var lowStreak: Int = 0

    public init() {}

    public static let keys = [
        SettingsKey.careCheckInEnabled,
        SettingsKey.careCheckInNotify,
        SettingsKey.careCheckInLastShown,
        SettingsKey.careCheckInLowStreak,
        SettingsKey.careCheckInStopped,
    ]

    public static func load(from defaults: UserDefaults) -> CareCheckInState {
        var state = CareCheckInState()
        state.enabled = defaults.object(forKey: SettingsKey.careCheckInEnabled) as? Bool ?? true
        state.notify = defaults.bool(forKey: SettingsKey.careCheckInNotify)
        state.stopped = defaults.bool(forKey: SettingsKey.careCheckInStopped)
        state.lastShown = (defaults.object(forKey: SettingsKey.careCheckInLastShown) as? Double).map(Date.init(timeIntervalSince1970:))
        state.lowStreak = max(0, defaults.integer(forKey: SettingsKey.careCheckInLowStreak))
        return state
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(enabled, forKey: SettingsKey.careCheckInEnabled)
        defaults.set(notify, forKey: SettingsKey.careCheckInNotify)
        defaults.set(stopped, forKey: SettingsKey.careCheckInStopped)
        if let lastShown {
            defaults.set(lastShown.timeIntervalSince1970, forKey: SettingsKey.careCheckInLastShown)
        } else {
            defaults.removeObject(forKey: SettingsKey.careCheckInLastShown)
        }
        defaults.set(lowStreak, forKey: SettingsKey.careCheckInLowStreak)
    }

    public static func clear(_ defaults: UserDefaults) {
        for key in keys { defaults.removeObject(forKey: key) }
    }
}

/// When the check-in card shows (spec §4.5): from day 21 after the end, at most
/// once a week, until day 105 (about 12 weeks), then never again.
public enum CareCheckInPolicy {
    public static let firstDay = 21
    public static let spacingDays = 7
    public static let lastDay = firstDay + spacingDays * 12

    public static func isDue(end: PregnancyEndState?, state: CareCheckInState, now: Date, calendar: Calendar) -> Bool {
        guard let next = nextDate(end: end, state: state, now: now, calendar: calendar) else { return false }
        return next <= calendar.startOfDay(for: now)
    }

    /// The start of the next check-in day: today when one is due now, nil when
    /// they are over, stopped, switched off or no pregnancy has ended.
    public static func nextDate(end: PregnancyEndState?, state: CareCheckInState, now: Date, calendar: Calendar) -> Date? {
        guard let end, state.enabled, !state.stopped else { return nil }
        let endDay = calendar.startOfDay(for: end.endDate)
        let today = calendar.startOfDay(for: now)
        guard let first = calendar.date(byAdding: .day, value: firstDay, to: endDay),
              let last = calendar.date(byAdding: .day, value: lastDay, to: endDay)
        else { return nil }
        var next = first
        if let shown = state.lastShown,
           let weekLater = calendar.date(byAdding: .day, value: spacingDays, to: calendar.startOfDay(for: shown)) {
            next = max(next, weekLater)
        }
        next = max(next, today)
        return next <= last ? next : nil
    }

    /// Answering (or skipping, `nil`) the check-in: low answers in a row are
    /// counted, any other answer resets the count, a skip leaves it.
    public static func record(_ feeling: CareFeeling?, state: CareCheckInState, now: Date) -> CareCheckInState {
        var updated = state
        updated.lastShown = now
        if let feeling {
            updated.lowStreak = feeling.isLow ? state.lowStreak + 1 : 0
        }
        return updated
    }

    public static func showsShareLine(_ state: CareCheckInState) -> Bool {
        state.lowStreak >= 2
    }

    /// The same tip all day, the next one tomorrow.
    public static func tipIndex(now: Date, calendar: Calendar, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let epoch = Date(timeIntervalSince1970: 0)
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: epoch), to: calendar.startOfDay(for: now)).day ?? 0
        return ((days % count) + count) % count
    }
}

/// The optional check-in notification (spec §4.5): one pending request, its
/// text neutral, never naming the pregnancy, the loss or the birth.
extension NotificationScheduler {
    public static let careCheckInID = "care-checkin"
    public static let careCheckInHour = 10

    /// Replaces the pending check-in with one at 10:00 on `day`. Returns false
    /// (with nothing pending) when that time is not in the future.
    @discardableResult
    public func scheduleCareCheckIn(on day: Date, now: Date, text: NotificationText, calendar: Calendar = .current) async throws -> Bool {
        center.removePending(ids: [Self.careCheckInID])
        guard let fire = calendar.date(bySettingHour: Self.careCheckInHour, minute: 0, second: 0, of: day), fire > now else {
            return false
        }
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try await center.add(UNNotificationRequest(identifier: Self.careCheckInID, content: text.makeContent(), trigger: trigger))
        return true
    }

    public func cancelCareCheckIn() {
        center.removePending(ids: [Self.careCheckInID])
    }

    /// Brings the one check-in notification in line with her choices: scheduled at
    /// 10:00 on the next check-in day while "Gửi thông báo nhẹ nhàng" is on, the
    /// check-ins still run and notifications are allowed; cancelled otherwise.
    /// Prompts only when `mayPrompt` (she just turned the switch on). Returns false
    /// only when she wants it but notifications are not allowed.
    @discardableResult
    public func syncCareCheckIn(
        end: PregnancyEndState?,
        state: CareCheckInState,
        now: Date,
        text: NotificationText,
        calendar: Calendar = .current,
        mayPrompt: Bool
    ) async -> Bool {
        guard state.notify, let next = CareCheckInPolicy.nextDate(end: end, state: state, now: now, calendar: calendar) else {
            cancelCareCheckIn()
            return true
        }
        let authorized = mayPrompt ? await requestAuthorizationIfNeeded() : await isAuthorized()
        guard authorized else {
            cancelCareCheckIn()
            return false
        }
        do {
            try await scheduleCareCheckIn(on: next, now: now, text: text, calendar: calendar)
        } catch {
            cancelCareCheckIn()
        }
        return true
    }
}
