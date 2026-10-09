import Foundation

/// A calendar date with no time and no time zone, stored as yyyymmdd. Pill
/// days are dates on the wall calendar: travelling to another time zone must
/// not move the pack or a marked pill by a day (phase 17 review).
public struct CalendarDay: Hashable, Comparable, Sendable {
    /// yyyymmdd, e.g. 20261001.
    public let key: Int

    /// Fixed reference for day arithmetic: whole days, no DST, no zone.
    private static let reference: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    public init(year: Int, month: Int, day: Int) {
        key = year * 10_000 + month * 100 + day
    }

    /// Nil for a key that is not a real date.
    public init?(key: Int) {
        let year = key / 10_000, month = key / 100 % 100, day = key % 100
        guard (1...9999).contains(year),
              let date = Self.reference.date(from: DateComponents(year: year, month: month, day: day)),
              Self.reference.dateComponents([.year, .month, .day], from: date)
                == DateComponents(year: year, month: month, day: day)
        else { return nil }
        self.key = key
    }

    /// The day `date` falls on in `calendar` (its time zone).
    public init(_ date: Date, calendar: Calendar) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 1, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    public var year: Int { key / 10_000 }
    public var month: Int { key / 100 % 100 }
    public var day: Int { key % 100 }

    /// Start of this day in `calendar`.
    public func date(in calendar: Calendar) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    public func adding(days: Int) -> CalendarDay {
        guard let date = referenceDate,
              let moved = Self.reference.date(byAdding: .day, value: days, to: date)
        else { return self }
        return CalendarDay(moved, calendar: Self.reference)
    }

    /// Whole days from `other` to this day.
    public func days(since other: CalendarDay) -> Int {
        guard let from = other.referenceDate, let to = referenceDate else { return 0 }
        return Self.reference.dateComponents([.day], from: from, to: to).day ?? 0
    }

    public static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool { lhs.key < rhs.key }

    private var referenceDate: Date? { date(in: Self.reference) }
}

/// The kind of pill pack (phase 17 spec §2).
public enum PillPackType: String, Sendable, CaseIterable {
    /// 21 pills, then 7 days without pills and without reminders.
    case withBreak = "21+7"
    /// A pill every day: 21 + 7 placebo, 24 + 4 and progestin-only packs.
    case continuous = "28"

    /// Pills with a reminder in one 28-day pack.
    public var pillCount: Int {
        switch self {
        case .withBreak: 21
        case .continuous: 28
        }
    }
}

/// Where a day falls in the pack: packs repeat every 28 days from `startDay`.
/// Day numbers come from calendar dates; `calendar` only turns instants into
/// dates (and back), in the zone the phone is in now.
public struct PillPack: Equatable, Sendable {
    public static let length = 28

    public let type: PillPackType
    /// First day of the first pack.
    public let startDay: CalendarDay
    private let calendar: Calendar

    public init(type: PillPackType, startDay: CalendarDay, calendar: Calendar) {
        self.type = type
        self.startDay = startDay
        self.calendar = calendar
    }

    /// The pack starting on the local day of `start`.
    public init(type: PillPackType, start: Date, calendar: Calendar) {
        self.init(type: type, startDay: CalendarDay(start, calendar: calendar), calendar: calendar)
    }

    public var pillCount: Int { type.pillCount }

    /// Start of the first day, in the current calendar.
    public var start: Date { startDay.date(in: calendar) ?? .distantPast }

    /// 1…28, repeating every 28 days; nil before the first pack starts.
    public func dayInPack(on day: CalendarDay) -> Int? {
        let days = day.days(since: startDay)
        guard days >= 0 else { return nil }
        return days % Self.length + 1
    }

    public func dayInPack(on date: Date) -> Int? { dayInPack(on: CalendarDay(date, calendar: calendar)) }

    /// False on days 22–28 of a `21+7` pack, and before the first pack.
    public func isPillDay(on day: CalendarDay) -> Bool {
        guard let number = dayInPack(on: day) else { return false }
        return number <= pillCount
    }

    public func isPillDay(on date: Date) -> Bool { isPillDay(on: CalendarDay(date, calendar: calendar)) }

    /// n of `pillCount` on a pill day, otherwise nil.
    public func pillNumber(on day: CalendarDay) -> Int? {
        isPillDay(on: day) ? dayInPack(on: day) : nil
    }

    public func pillNumber(on date: Date) -> Int? { pillNumber(on: CalendarDay(date, calendar: calendar)) }

    /// The first day of the next pack after `day` (the first pack itself
    /// while it has not started).
    public func nextPackStartDay(after day: CalendarDay) -> CalendarDay {
        let days = day.days(since: startDay)
        let packs = days < 0 ? 0 : days / Self.length + 1
        return startDay.adding(days: packs * Self.length)
    }

    /// Start of the next pack's first day after the local day of `date`.
    public func nextPackStart(after date: Date) -> Date {
        nextPackStartDay(after: CalendarDay(date, calendar: calendar)).date(in: calendar) ?? start
    }

    /// When the reminder for `day` fires: `hour`:`minute` on that local day.
    public func reminderDate(on day: CalendarDay, hour: Int, minute: Int) -> Date? {
        guard let start = day.date(in: calendar) else { return nil }
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: start)
    }

    /// The first `count` pill days from the day of `from` (that day included,
    /// whatever its time), each at `hour`:`minute`. Break days are skipped.
    public func upcomingReminderDates(from: Date, count: Int, hour: Int, minute: Int) -> [Date] {
        upcomingPillDays(from: CalendarDay(from, calendar: calendar), count: count)
            .compactMap { reminderDate(on: $0, hour: hour, minute: minute) }
    }

    /// The first `count` pill days from `first` (included).
    public func upcomingPillDays(from first: CalendarDay, count: Int) -> [CalendarDay] {
        var days: [CalendarDay] = []
        var day = max(first, startDay)
        // A 21+7 pack has at least 21 pill days in any 28: this bound is never reached.
        var remaining = count * 2 + Self.length
        while days.count < count, remaining > 0 {
            remaining -= 1
            if isPillDay(on: day) { days.append(day) }
            day = day.adding(days: 1)
        }
        return days
    }
}

/// The reminder's settings in `AppGroup.defaults` (phase 17 spec §3.1).
public struct PillReminderSettings: Equatable, Sendable {
    public static let defaultHour = 21
    public static let defaultMinute = 0

    public var enabled: Bool
    public var packType: PillPackType
    /// First day of the current pack; nil until she picks it.
    public var packStartDay: CalendarDay?
    public var hour: Int
    public var minute: Int

    public init(
        enabled: Bool = false,
        packType: PillPackType = .withBreak,
        packStartDay: CalendarDay? = nil,
        hour: Int = PillReminderSettings.defaultHour,
        minute: Int = PillReminderSettings.defaultMinute
    ) {
        self.enabled = enabled
        self.packType = packType
        self.packStartDay = packStartDay
        self.hour = hour
        self.minute = minute
    }

    /// `pillPackStart` is a yyyymmdd day; earlier builds of this branch stored
    /// an instant (seconds since 1970), read as its day in `calendar`.
    public static func load(from defaults: UserDefaults, calendar: Calendar = .autoupdatingCurrent) -> PillReminderSettings {
        let hour = defaults.object(forKey: SettingsKey.pillReminderHour) as? Int
        let minute = defaults.object(forKey: SettingsKey.pillReminderMinute) as? Int
        return PillReminderSettings(
            enabled: defaults.bool(forKey: SettingsKey.pillReminderEnabled),
            packType: defaults.string(forKey: SettingsKey.pillPackType).flatMap(PillPackType.init(rawValue:)) ?? .withBreak,
            packStartDay: startDay(defaults.object(forKey: SettingsKey.pillPackStart), calendar: calendar),
            hour: hour.flatMap { (0...23).contains($0) ? $0 : nil } ?? defaultHour,
            minute: minute.flatMap { (0...59).contains($0) ? $0 : nil } ?? defaultMinute
        )
    }

    private static func startDay(_ stored: Any?, calendar: Calendar) -> CalendarDay? {
        guard let number = stored as? NSNumber else { return nil }
        let value = number.doubleValue
        guard value > 0 else { return nil }
        if value >= 100_000_000 {
            return CalendarDay(Date(timeIntervalSince1970: value), calendar: calendar)
        }
        return CalendarDay(key: number.intValue)
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(enabled, forKey: SettingsKey.pillReminderEnabled)
        defaults.set(packType.rawValue, forKey: SettingsKey.pillPackType)
        if let packStartDay {
            defaults.set(packStartDay.key, forKey: SettingsKey.pillPackStart)
        } else {
            defaults.removeObject(forKey: SettingsKey.pillPackStart)
        }
        defaults.set(hour, forKey: SettingsKey.pillReminderHour)
        defaults.set(minute, forKey: SettingsKey.pillReminderMinute)
    }

    /// The current pack, once a start day is set.
    public func pack(calendar: Calendar) -> PillPack? {
        packStartDay.map { PillPack(type: packType, startDay: $0, calendar: calendar) }
    }
}

/// One pill marked as taken (value snapshot of the SwiftData `PillDose`).
public struct PillDoseRecord: Equatable, Sendable, Identifiable {
    public let id: UUID
    /// The calendar day the pill belongs to.
    public var day: CalendarDay
    public var takenAt: Date

    public init(id: UUID = UUID(), day: CalendarDay, takenAt: Date) {
        self.id = id
        self.day = day
        self.takenAt = takenAt
    }
}

public enum PillDoseError: Error, Equatable, Sendable {
    case futureDate
}

/// Storage for the marked pills: at most one per day.
@MainActor
public protocol PillDoseRepository: AnyObject {
    /// Every dose, oldest first, one per day.
    func doses() throws -> [PillDoseRecord]
    /// Marks the pill of `day` as taken at `time`. A day already marked keeps
    /// its first time. Throws `.futureDate` for a day after the day of `time`.
    func markTaken(on day: CalendarDay, at time: Date) throws
    /// No-op when that day is not marked.
    func unmark(on day: CalendarDay) throws
}

/// Validation shared by `PillDoseStore` and the test fake.
public enum PillDoseRules {
    /// The dose for `day`, taken at `takenAt` (whose local day is in `calendar`).
    public static func dose(on day: CalendarDay, takenAt: Date, calendar: Calendar) throws -> PillDoseRecord {
        guard day <= CalendarDay(takenAt, calendar: calendar) else { throw PillDoseError.futureDate }
        return PillDoseRecord(day: day, takenAt: takenAt)
    }
}
