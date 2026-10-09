import Foundation
@preconcurrency import UserNotifications

/// One pending pill notification (phase 17 spec §4.2).
public struct PillReminderRequest: Equatable, Sendable {
    public enum Kind: Sendable {
        /// At the chosen time.
        case reminder
        /// Two hours later, only while the day is not marked.
        case followUp
    }

    public let identifier: String
    public let kind: Kind
    /// Start of the pill's day (a follow-up after midnight keeps its day).
    public let day: Date
    public let fireDate: Date
    public let pillNumber: Int
    public let pillCount: Int

    public init(identifier: String, kind: Kind, day: Date, fireDate: Date, pillNumber: Int, pillCount: Int) {
        self.identifier = identifier
        self.kind = kind
        self.day = day
        self.fireDate = fireDate
        self.pillNumber = pillNumber
        self.pillCount = pillCount
    }
}

/// Which pill notifications should be pending: a reminder and a follow-up for
/// each of the next 14 pill days, never on a break day or a marked day.
public enum PillReminderPlan {
    public static let identifierPrefix = "pill-"
    public static let followUpSuffix = "-followup"
    public static let pillDaysAhead = 14
    public static let followUpDelayHours = 2
    /// Two per pill day: under iOS's 64 pending requests with the other reminders.
    public static let maxRequests = pillDaysAhead * 2
    public static let categoryIdentifier = "PILL_REMINDER"
    public static let takenActionIdentifier = "PILL_TAKEN"
    /// `userInfo` key: the pill's day, `timeIntervalSince1970`.
    public static let dayUserInfoKey = "pillDay"

    /// "pill-YYYYMMDD" for the local day of `day`.
    public static func identifier(for day: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        return identifierPrefix + String(format: "%04d%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    public static func followUpIdentifier(for day: Date, calendar: Calendar) -> String {
        identifier(for: day, calendar: calendar) + followUpSuffix
    }

    /// The day a pill identifier belongs to; nil for any other identifier.
    public static func day(fromIdentifier identifier: String, calendar: Calendar) -> Date? {
        guard identifier.hasPrefix(identifierPrefix) else { return nil }
        var digits = identifier.dropFirst(identifierPrefix.count)
        if digits.hasSuffix(followUpSuffix) { digits = digits.dropLast(followUpSuffix.count) }
        guard digits.count == 8, let value = Int(digits) else { return nil }
        return calendar.date(from: DateComponents(year: value / 10000, month: value / 100 % 100, day: value % 100))
    }

    /// The 14 pill days from today that still have something ahead of `now`;
    /// marked days get nothing.
    public static func requests(
        pack: PillPack,
        hour: Int,
        minute: Int,
        now: Date,
        takenDays: Set<Date>,
        calendar: Calendar
    ) -> [PillReminderRequest] {
        let candidates = pack.upcomingReminderDates(from: now, count: pillDaysAhead + 1, hour: hour, minute: minute)
        let days = candidates.compactMap { fire -> (day: Date, fire: Date, followUp: Date)? in
            guard let followUp = calendar.date(byAdding: .hour, value: followUpDelayHours, to: fire), followUp > now else {
                return nil
            }
            return (calendar.startOfDay(for: fire), fire, followUp)
        }.prefix(pillDaysAhead)

        var requests: [PillReminderRequest] = []
        for (day, fire, followUp) in days where !takenDays.contains(day) {
            guard let number = pack.pillNumber(on: day) else { continue }
            if fire > now {
                requests.append(PillReminderRequest(
                    identifier: identifier(for: day, calendar: calendar), kind: .reminder,
                    day: day, fireDate: fire, pillNumber: number, pillCount: pack.pillCount
                ))
            }
            requests.append(PillReminderRequest(
                identifier: followUpIdentifier(for: day, calendar: calendar), kind: .followUp,
                day: day, fireDate: followUp, pillNumber: number, pillCount: pack.pillCount
            ))
        }
        return requests
    }
}

/// The two notification texts, given the pill number and the pack's pill count.
public struct PillReminderTexts: Sendable {
    public let reminder: @Sendable (_ number: Int, _ count: Int) -> NotificationText
    public let followUp: @Sendable (_ number: Int, _ count: Int) -> NotificationText

    public init(
        reminder: @escaping @Sendable (Int, Int) -> NotificationText,
        followUp: @escaping @Sendable (Int, Int) -> NotificationText
    ) {
        self.reminder = reminder
        self.followUp = followUp
    }
}

/// Pill reminders. Only `PillCoordinator` calls these.
extension NotificationScheduler {
    /// Replaces every pending pill request with `requests`.
    public func schedulePillReminders(
        _ requests: [PillReminderRequest],
        texts: PillReminderTexts,
        calendar: Calendar = .current
    ) async throws {
        await cancelPillReminders()
        for request in requests {
            let text = switch request.kind {
            case .reminder: texts.reminder(request.pillNumber, request.pillCount)
            case .followUp: texts.followUp(request.pillNumber, request.pillCount)
            }
            let content = text.makeContent()
            content.categoryIdentifier = PillReminderPlan.categoryIdentifier
            content.threadIdentifier = PillReminderPlan.categoryIdentifier
            content.userInfo = [PillReminderPlan.dayUserInfoKey: request.day.timeIntervalSince1970]
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: request.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try await center.add(UNNotificationRequest(identifier: request.identifier, content: content, trigger: trigger))
        }
    }

    public func cancelPillReminders() async {
        let ids = await center.pendingRequestIDs().filter { $0.hasPrefix(PillReminderPlan.identifierPrefix) }
        guard !ids.isEmpty else { return }
        center.removePending(ids: ids)
    }
}
