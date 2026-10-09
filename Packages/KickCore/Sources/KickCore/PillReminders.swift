import Foundation
@preconcurrency import UserNotifications

/// One pending pill notification (phase 17 spec §4.2).
public struct PillReminderRequest: Equatable, Sendable {
    public enum Kind: Sendable {
        /// At the chosen time.
        case reminder
        /// Two hours later, only while the day is not marked.
        case followUp
        /// After the last scheduled day: "open the app to keep the reminders going".
        case renew
    }

    public let identifier: String
    public let kind: Kind
    /// The pill's calendar day (a follow-up after midnight keeps its day).
    public let day: CalendarDay
    public let fireDate: Date
    public let pillNumber: Int
    public let pillCount: Int

    public init(identifier: String, kind: Kind, day: CalendarDay, fireDate: Date, pillNumber: Int, pillCount: Int) {
        self.identifier = identifier
        self.kind = kind
        self.day = day
        self.fireDate = fireDate
        self.pillNumber = pillNumber
        self.pillCount = pillCount
    }
}

/// Which pill notifications should be pending: a reminder and a follow-up for
/// each of the next 14 pill days, never on a break day or a marked day, then
/// one renewal notice so the reminders never stop without a word.
public enum PillReminderPlan {
    public static let identifierPrefix = "pill-"
    public static let followUpSuffix = "-followup"
    public static let renewIdentifier = "pill-renew"
    public static let pillDaysAhead = 14
    public static let followUpDelayHours = 2
    /// Two per pill day and the renewal notice: under iOS's 64 pending requests
    /// with the other reminders (`maxAppointmentReminders`).
    public static let maxRequests = pillDaysAhead * 2 + 1
    public static let categoryIdentifier = "PILL_REMINDER"
    public static let takenActionIdentifier = "PILL_TAKEN"
    /// `userInfo` key: the pill's day, `CalendarDay.key` (yyyymmdd).
    public static let dayUserInfoKey = "pillDay"

    /// "pill-YYYYMMDD".
    public static func identifier(for day: CalendarDay) -> String {
        identifierPrefix + String(format: "%08d", day.key)
    }

    public static func followUpIdentifier(for day: CalendarDay) -> String {
        identifier(for: day) + followUpSuffix
    }

    /// "pill-YYYYMMDD" for the local day of `day`.
    public static func identifier(for day: Date, calendar: Calendar) -> String {
        identifier(for: CalendarDay(day, calendar: calendar))
    }

    public static func followUpIdentifier(for day: Date, calendar: Calendar) -> String {
        followUpIdentifier(for: CalendarDay(day, calendar: calendar))
    }

    /// The day a pill identifier belongs to; nil for any other identifier.
    public static func day(fromIdentifier identifier: String) -> CalendarDay? {
        guard identifier.hasPrefix(identifierPrefix) else { return nil }
        var digits = identifier.dropFirst(identifierPrefix.count)
        if digits.hasSuffix(followUpSuffix) { digits = digits.dropLast(followUpSuffix.count) }
        guard digits.count == 8, let value = Int(digits) else { return nil }
        return CalendarDay(key: value)
    }

    /// When the follow-up for `day` fires (2 hours after its reminder).
    public static func followUpDate(for day: CalendarDay, pack: PillPack, hour: Int, minute: Int, calendar: Calendar) -> Date? {
        pack.reminderDate(on: day, hour: hour, minute: minute)
            .flatMap { calendar.date(byAdding: .hour, value: followUpDelayHours, to: $0) }
    }

    /// The 14 pill days from today that still have something ahead of `now`
    /// (marked days get nothing), then the renewal notice at the reminder time
    /// of the next pill day.
    public static func requests(
        pack: PillPack,
        hour: Int,
        minute: Int,
        now: Date,
        takenDays: Set<CalendarDay>,
        calendar: Calendar
    ) -> [PillReminderRequest] {
        let candidates = pack.upcomingPillDays(from: CalendarDay(now, calendar: calendar), count: pillDaysAhead + 2)
        var window: [(day: CalendarDay, fire: Date, followUp: Date)] = []
        var next: (day: CalendarDay, fire: Date)?
        for day in candidates {
            guard let fire = pack.reminderDate(on: day, hour: hour, minute: minute),
                  let followUp = calendar.date(byAdding: .hour, value: followUpDelayHours, to: fire),
                  followUp > now
            else { continue }
            if window.count < pillDaysAhead {
                window.append((day, fire, followUp))
            } else {
                next = (day, fire)
                break
            }
        }

        var requests: [PillReminderRequest] = []
        for (day, fire, followUp) in window where !takenDays.contains(day) {
            guard let number = pack.pillNumber(on: day) else { continue }
            if fire > now {
                requests.append(PillReminderRequest(
                    identifier: identifier(for: day), kind: .reminder,
                    day: day, fireDate: fire, pillNumber: number, pillCount: pack.pillCount
                ))
            }
            requests.append(PillReminderRequest(
                identifier: followUpIdentifier(for: day), kind: .followUp,
                day: day, fireDate: followUp, pillNumber: number, pillCount: pack.pillCount
            ))
        }
        if let next, let number = pack.pillNumber(on: next.day) {
            requests.append(PillReminderRequest(
                identifier: renewIdentifier, kind: .renew,
                day: next.day, fireDate: next.fire, pillNumber: number, pillCount: pack.pillCount
            ))
        }
        return requests
    }
}

/// The notification texts: the reminder and follow-up given the pill number
/// and the pack's pill count, and the renewal notice.
public struct PillReminderTexts: Sendable {
    public let reminder: @Sendable (_ number: Int, _ count: Int) -> NotificationText
    public let followUp: @Sendable (_ number: Int, _ count: Int) -> NotificationText
    public let renew: NotificationText

    public init(
        reminder: @escaping @Sendable (Int, Int) -> NotificationText,
        followUp: @escaping @Sendable (Int, Int) -> NotificationText,
        renew: NotificationText
    ) {
        self.reminder = reminder
        self.followUp = followUp
        self.renew = renew
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
            case .renew: texts.renew
            }
            let content = text.makeContent()
            content.threadIdentifier = PillReminderPlan.categoryIdentifier
            // The renewal notice has no pill to mark: no "Đã uống" action.
            if request.kind != .renew {
                content.categoryIdentifier = PillReminderPlan.categoryIdentifier
                content.userInfo = [PillReminderPlan.dayUserInfoKey: request.day.key]
            }
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: request.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try await center.add(UNNotificationRequest(identifier: request.identifier, content: content, trigger: trigger))
        }
    }

    /// Clears that day's reminder and follow-up from Notification Center once marked.
    public func removeDeliveredPillReminders(for day: CalendarDay) {
        center.removeDelivered(ids: [PillReminderPlan.identifier(for: day), PillReminderPlan.followUpIdentifier(for: day)])
    }

    public func cancelPillReminders() async {
        let ids = await center.pendingRequestIDs().filter { $0.hasPrefix(PillReminderPlan.identifierPrefix) }
        guard !ids.isEmpty else { return }
        center.removePending(ids: ids)
    }
}
