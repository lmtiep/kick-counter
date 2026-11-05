import Foundation

/// How the pregnancy ended (1.1 item 4). The two branches never share wording.
public enum PregnancyEndBranch: String, Sendable, Codable, CaseIterable {
    case birth
    case loss
}

/// The pregnancy-ended state kept in `AppGroup.defaults` (spec §4.2, §4.6): the
/// branch, the end day and the period she confirmed as the first after it. Its
/// presence turns on the prediction pause (`CyclePause`) and the check-ins
/// (`CareCheckInPolicy`). Belongs to this phone: never in a backup.
public struct PregnancyEndState: Equatable, Sendable {
    public var branch: PregnancyEndBranch
    /// Start of the local day the pregnancy ended.
    public var endDate: Date
    /// The period confirmed as the first after the end; nil = predictions paused.
    public var firstPeriodConfirmedID: UUID?

    public init(branch: PregnancyEndBranch, endDate: Date, firstPeriodConfirmedID: UUID? = nil, calendar: Calendar = .current) {
        self.branch = branch
        self.endDate = calendar.startOfDay(for: endDate)
        self.firstPeriodConfirmedID = firstPeriodConfirmedID
    }

    /// Every key the state owns, removed by `clear` and by "delete all data".
    public static let keys = [
        SettingsKey.pregnancyEndBranch,
        SettingsKey.pregnancyEndDate,
        SettingsKey.pregnancyEndFirstPeriodID,
        SettingsKey.pregnancyEndDeclinedPeriods,
    ]

    /// nil when no pregnancy has ended (or the stored values are unreadable).
    public static func load(from defaults: UserDefaults) -> PregnancyEndState? {
        guard let branch = defaults.string(forKey: SettingsKey.pregnancyEndBranch).flatMap(PregnancyEndBranch.init(rawValue:)),
              let interval = defaults.object(forKey: SettingsKey.pregnancyEndDate) as? Double
        else { return nil }
        var state = PregnancyEndState(branch: branch, endDate: Date(timeIntervalSince1970: interval))
        // Stored already at the start of a day; keep the exact instant.
        state.endDate = Date(timeIntervalSince1970: interval)
        state.firstPeriodConfirmedID = defaults.string(forKey: SettingsKey.pregnancyEndFirstPeriodID).flatMap(UUID.init(uuidString:))
        return state
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(branch.rawValue, forKey: SettingsKey.pregnancyEndBranch)
        defaults.set(endDate.timeIntervalSince1970, forKey: SettingsKey.pregnancyEndDate)
        if let firstPeriodConfirmedID {
            defaults.set(firstPeriodConfirmedID.uuidString, forKey: SettingsKey.pregnancyEndFirstPeriodID)
        } else {
            defaults.removeObject(forKey: SettingsKey.pregnancyEndFirstPeriodID)
        }
    }

    /// Removes the keys (no `@AppStorage` reads them), including the declined periods.
    public static func clear(_ defaults: UserDefaults) {
        for key in keys { defaults.removeObject(forKey: key) }
    }

    /// The periods she answered "not the first" for.
    public static func declinedPeriods(in defaults: UserDefaults) -> Set<UUID> {
        Set((defaults.stringArray(forKey: SettingsKey.pregnancyEndDeclinedPeriods) ?? []).compactMap(UUID.init(uuidString:)))
    }

    public static func saveDeclinedPeriods(_ ids: Set<UUID>, to defaults: UserDefaults) {
        defaults.set(ids.map(\.uuidString).sorted(), forKey: SettingsKey.pregnancyEndDeclinedPeriods)
    }
}

/// The days the pregnancy covered (spec §4.6), used to pick which weights,
/// appointments and day logs belong to it.
public enum PregnancyRange {
    /// From the LMP, else the due date − 280 days, else the earliest of
    /// `fallbackStarts` (kicks, contractions, appointments), through the whole
    /// end day. nil when there is no start at all. The start is never after the end day.
    public static func make(
        profile: PregnancyProfile,
        endDate: Date,
        fallbackStarts: [Date],
        calendar: Calendar
    ) -> ClosedRange<Date>? {
        let start: Date
        if let lmp = profile.lmpDate {
            start = lmp
        } else if let due = profile.dueDate {
            start = PregnancyDates.lmp(fromDueDate: due, calendar: calendar)
        } else if let earliest = fallbackStarts.min() {
            start = earliest
        } else {
            return nil
        }
        let endDay = calendar.startOfDay(for: endDate)
        let lower = min(calendar.startOfDay(for: start), endDay)
        let upper = CycleRules.nextDay(after: endDay, calendar: calendar).addingTimeInterval(-0.001)
        return lower...upper
    }
}
