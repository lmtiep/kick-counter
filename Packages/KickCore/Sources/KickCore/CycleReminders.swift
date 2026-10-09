import Foundation
@preconcurrency import UserNotifications

public enum CycleReminderKind: String, Sendable, CaseIterable {
    /// 2 days before the fertile window opens.
    case fertile
    /// 1 day before the next period is due.
    case period
    /// Once, when the period is 3 days late.
    case late

    public var identifier: String { "cycle-\(rawValue)" }
}

public struct CycleReminderTexts: Sendable {
    public let fertile: NotificationText
    public let period: NotificationText
    public let late: NotificationText
    /// "Bleed" wording for `.period` / `.late` on hormonal contraception, where
    /// the bleed is not a period (fact-check row 56). Nil: the period texts.
    public let bleed: NotificationText?
    public let bleedLate: NotificationText?

    public init(
        fertile: NotificationText,
        period: NotificationText,
        late: NotificationText,
        bleed: NotificationText? = nil,
        bleedLate: NotificationText? = nil
    ) {
        self.fertile = fertile
        self.period = period
        self.late = late
        self.bleed = bleed
        self.bleedLate = bleedLate
    }

    /// The texts to schedule for `label`: a withdrawal bleed swaps in the bleed texts.
    func forBleedLabel(_ label: CycleDisplayPolicy.BleedLabel) -> CycleReminderTexts {
        guard label == .withdrawalBleed else { return self }
        return CycleReminderTexts(fertile: fertile, period: bleed ?? period, late: bleedLate ?? late)
    }

    func text(for kind: CycleReminderKind) -> NotificationText {
        switch kind {
        case .fertile: fertile
        case .period: period
        case .late: late
        }
    }
}

/// Cycle reminders at 9:00. Only `CycleCoordinator` calls these.
extension NotificationScheduler {
    public static let cycleReminderHour = 9
    static let fertileReminderLeadDays = 2
    static let periodReminderLeadDays = 1

    /// When each reminder for `forecast` would fire (9:00 local), past or not.
    public static func cycleReminderFireDates(for forecast: CycleForecast, calendar: Calendar = .current) -> [CycleReminderKind: Date] {
        func nineOClock(_ days: Int, from date: Date) -> Date? {
            guard let day = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: date)) else { return nil }
            return calendar.date(bySettingHour: cycleReminderHour, minute: 0, second: 0, of: day)
        }
        var dates: [CycleReminderKind: Date] = [:]
        dates[.fertile] = nineOClock(-fertileReminderLeadDays, from: forecast.fertileWindow.lowerBound)
        dates[.period] = nineOClock(-periodReminderLeadDays, from: forecast.nextPeriodStart)
        dates[.late] = nineOClock(CyclePredictor.lateNoticeDays, from: forecast.nextPeriodStart)
        return dates
    }

    /// Replaces all three cycle reminders with those of `kinds` for `forecast`
    /// whose time is still ahead of `now` (the others stay cancelled). Returns
    /// the kinds that were scheduled.
    @discardableResult
    public func scheduleCycleReminders(
        for forecast: CycleForecast,
        now: Date,
        texts: CycleReminderTexts,
        kinds: Set<CycleReminderKind> = Set(CycleReminderKind.allCases),
        calendar: Calendar = .current
    ) async throws -> Set<CycleReminderKind> {
        cancelCycleReminders()
        let fireDates = Self.cycleReminderFireDates(for: forecast, calendar: calendar)
        var scheduled: Set<CycleReminderKind> = []
        for kind in CycleReminderKind.allCases where kinds.contains(kind) {
            guard let fireDate = fireDates[kind], fireDate > now else { continue }
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: kind.identifier, content: texts.text(for: kind).makeContent(), trigger: trigger
            )
            try await center.add(request)
            scheduled.insert(kind)
        }
        return scheduled
    }

    public func cancelCycleReminders() {
        center.removePending(ids: CycleReminderKind.allCases.map(\.identifier))
    }
}
