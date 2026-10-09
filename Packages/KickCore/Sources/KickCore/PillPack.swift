import Foundation

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

/// Where a day falls in the pack: packs repeat every 28 days from `start`.
public struct PillPack: Equatable, Sendable {
    public static let length = 28

    public let type: PillPackType
    /// First day of the current pack, at start of day.
    public let start: Date
    private let calendar: Calendar

    public init(type: PillPackType, start: Date, calendar: Calendar) {
        self.type = type
        self.start = calendar.startOfDay(for: start)
        self.calendar = calendar
    }

    public var pillCount: Int { type.pillCount }

    /// 1…28, repeating every 28 days; nil before the first pack starts.
    public func dayInPack(on date: Date) -> Int? {
        let days = daysSinceStart(date)
        guard days >= 0 else { return nil }
        return days % Self.length + 1
    }

    /// False on days 22–28 of a `21+7` pack, and before the first pack.
    public func isPillDay(on date: Date) -> Bool {
        guard let day = dayInPack(on: date) else { return false }
        return day <= pillCount
    }

    /// n of `pillCount` on a pill day, otherwise nil.
    public func pillNumber(on date: Date) -> Int? {
        guard isPillDay(on: date) else { return nil }
        return dayInPack(on: date)
    }

    /// The first day of the next pack after the day of `date` (the first pack
    /// itself while it has not started).
    public func nextPackStart(after date: Date) -> Date {
        let days = daysSinceStart(date)
        let packs = days < 0 ? 0 : days / Self.length + 1
        return calendar.date(byAdding: .day, value: packs * Self.length, to: start) ?? start
    }

    /// The first `count` pill days from the day of `from` (that day included,
    /// whatever its time), each at `hour`:`minute`. Break days are skipped.
    public func upcomingReminderDates(from: Date, count: Int, hour: Int, minute: Int) -> [Date] {
        var dates: [Date] = []
        var day = max(calendar.startOfDay(for: from), start)
        // A 21+7 pack has at least 21 pill days in any 28: this bound is never reached.
        var remaining = count * 2 + Self.length
        while dates.count < count, remaining > 0 {
            remaining -= 1
            if isPillDay(on: day), let fire = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) {
                dates.append(fire)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return dates
    }

    private func daysSinceStart(_ date: Date) -> Int {
        calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: date)).day ?? 0
    }
}

/// The reminder's settings in `AppGroup.defaults` (phase 17 spec §3.1).
public struct PillReminderSettings: Equatable, Sendable {
    public static let defaultHour = 21
    public static let defaultMinute = 0

    public var enabled: Bool
    public var packType: PillPackType
    /// First day of the current pack; nil until she picks it.
    public var packStart: Date?
    public var hour: Int
    public var minute: Int

    public init(
        enabled: Bool = false,
        packType: PillPackType = .withBreak,
        packStart: Date? = nil,
        hour: Int = PillReminderSettings.defaultHour,
        minute: Int = PillReminderSettings.defaultMinute
    ) {
        self.enabled = enabled
        self.packType = packType
        self.packStart = packStart
        self.hour = hour
        self.minute = minute
    }

    public static func load(from defaults: UserDefaults) -> PillReminderSettings {
        let start = defaults.double(forKey: SettingsKey.pillPackStart)
        let hour = defaults.object(forKey: SettingsKey.pillReminderHour) as? Int
        let minute = defaults.object(forKey: SettingsKey.pillReminderMinute) as? Int
        return PillReminderSettings(
            enabled: defaults.bool(forKey: SettingsKey.pillReminderEnabled),
            packType: defaults.string(forKey: SettingsKey.pillPackType).flatMap(PillPackType.init(rawValue:)) ?? .withBreak,
            packStart: start > 0 ? Date(timeIntervalSince1970: start) : nil,
            hour: hour.flatMap { (0...23).contains($0) ? $0 : nil } ?? defaultHour,
            minute: minute.flatMap { (0...59).contains($0) ? $0 : nil } ?? defaultMinute
        )
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(enabled, forKey: SettingsKey.pillReminderEnabled)
        defaults.set(packType.rawValue, forKey: SettingsKey.pillPackType)
        if let packStart {
            defaults.set(packStart.timeIntervalSince1970, forKey: SettingsKey.pillPackStart)
        } else {
            defaults.removeObject(forKey: SettingsKey.pillPackStart)
        }
        defaults.set(hour, forKey: SettingsKey.pillReminderHour)
        defaults.set(minute, forKey: SettingsKey.pillReminderMinute)
    }

    /// The current pack, once a start day is set.
    public func pack(calendar: Calendar) -> PillPack? {
        packStart.map { PillPack(type: packType, start: $0, calendar: calendar) }
    }
}

/// One pill marked as taken (value snapshot of the SwiftData `PillDose`).
public struct PillDoseRecord: Equatable, Sendable, Identifiable {
    public let id: UUID
    /// Start of the calendar day the pill belongs to.
    public var day: Date
    public var takenAt: Date

    public init(id: UUID = UUID(), day: Date, takenAt: Date) {
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
    /// Marks the pill of the day of `day` as taken at `time`. A day already
    /// marked keeps its first time. Throws `.futureDate` for a day after `time`.
    func markTaken(on day: Date, at time: Date) throws
    /// No-op when that day is not marked.
    func unmark(on day: Date) throws
}

/// Validation shared by `PillDoseStore` and the test fake.
public enum PillDoseRules {
    /// The dose for the day of `day`, taken at `takenAt`.
    public static func dose(on day: Date, takenAt: Date, calendar: Calendar) throws -> PillDoseRecord {
        let start = calendar.startOfDay(for: day)
        guard start <= calendar.startOfDay(for: takenAt) else { throw PillDoseError.futureDate }
        return PillDoseRecord(day: start, takenAt: takenAt)
    }
}
