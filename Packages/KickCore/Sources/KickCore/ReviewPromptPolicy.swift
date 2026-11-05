import Foundation

/// A positive moment that may earn the App Store rating request.
public enum ReviewMoment: Equatable, Sendable {
    /// A kick-count session reached its target.
    case kickSessionCompleted
    /// A period start was just logged; `totalPeriods` counts it.
    case periodStarted(totalPeriods: Int)
    /// A weight entry was just saved.
    case weightSaved
}

/// What the screen knows that must keep the request away.
public struct ReviewPromptContext: Equatable, Sendable {
    public var isOnboarding: Bool
    /// A contraction is running, or one was timed within `ReviewPromptPolicy.contractionQuietPeriod`.
    public var recentContractionUse: Bool
    /// An alert card is up: the kick 2-hour overdue card or the 5-1-1 / preterm contraction card.
    public var alertShowing: Bool

    public init(isOnboarding: Bool = false, recentContractionUse: Bool = false, alertShowing: Bool = false) {
        self.isOnboarding = isOnboarding
        self.recentContractionUse = recentContractionUse
        self.alertShowing = alertShowing
    }
}

/// What the phone remembers about the rating prompt. Only dates and version names.
public struct ReviewPromptState: Equatable, Sendable {
    public var firstUseAt: Date?
    /// Distinct days the app was opened, `yyyymmdd`.
    public var useDays: Set<Int>
    public var askedAt: [Date]
    public var askedVersions: [String]

    public init(firstUseAt: Date? = nil, useDays: Set<Int> = [], askedAt: [Date] = [], askedVersions: [String] = []) {
        self.firstUseAt = firstUseAt
        self.useDays = useDays
        self.askedAt = askedAt
        self.askedVersions = askedVersions
    }
}

/// When the app may ask for an App Store rating. Pure decision logic: the screen
/// calls `shouldAsk`, makes the request (`requestReview`) and only then `recordingAsk`.
public enum ReviewPromptPolicy {
    /// Distinct days of use needed before the first request.
    public static let minimumUseDays = 3
    /// Whole days between two requests.
    public static let minimumDaysBetweenRequests = 120
    /// Requests allowed in any 365-day window.
    public static let maximumRequestsPerYear = 3
    public static let yearDays = 365
    /// Whole days since first use before a weight entry counts as a good moment.
    public static let weightMinimumDaysOfUse = 7
    /// The third logged period start is the first that counts.
    public static let minimumPeriodStarts = 3
    /// After timing a contraction the request stays away this long.
    public static let contractionQuietPeriod: TimeInterval = 24 * 60 * 60
    /// Days of use kept: only the count up to `minimumUseDays` matters.
    static let keptUseDays = 10

    public static func shouldAsk(
        moment: ReviewMoment,
        context: ReviewPromptContext,
        state: ReviewPromptState,
        appVersion: String,
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard !context.isOnboarding, !context.recentContractionUse, !context.alertShowing else { return false }
        guard momentQualifies(moment, state: state, now: now, calendar: calendar) else { return false }
        guard state.useDays.count >= minimumUseDays else { return false }
        guard !state.askedVersions.contains(appVersion) else { return false }
        if let last = state.askedAt.max(), daysBetween(last, now, calendar) < minimumDaysBetweenRequests { return false }
        let inYear = state.askedAt.filter { daysBetween($0, now, calendar) < yearDays }
        return inYear.count < maximumRequestsPerYear
    }

    /// True when a contraction is running or one started or ended within `contractionQuietPeriod`.
    public static func hadRecentContractionUse(_ contractions: [ContractionRecord], now: Date) -> Bool {
        contractions.contains { record in
            guard let ended = record.endedAt else { return true }
            return now.timeIntervalSince(max(ended, record.startedAt)) < contractionQuietPeriod
        }
    }

    /// Marks `now` as a day of use and remembers the first one.
    public static func recordingUse(_ state: ReviewPromptState, now: Date, calendar: Calendar = .current) -> ReviewPromptState {
        var next = state
        if next.firstUseAt == nil { next.firstUseAt = now }
        if next.useDays.count < keptUseDays { next.useDays.insert(dayKey(now, calendar)) }
        return next
    }

    /// Call only once the request was actually made.
    public static func recordingAsk(_ state: ReviewPromptState, appVersion: String, now: Date) -> ReviewPromptState {
        var next = state
        next.askedAt.append(now)
        if !next.askedVersions.contains(appVersion) { next.askedVersions.append(appVersion) }
        return next
    }

    private static func momentQualifies(_ moment: ReviewMoment, state: ReviewPromptState, now: Date, calendar: Calendar) -> Bool {
        switch moment {
        case .kickSessionCompleted:
            return true
        case .periodStarted(let total):
            return total >= minimumPeriodStarts
        case .weightSaved:
            guard let first = state.firstUseAt else { return false }
            return daysBetween(first, now, calendar) >= weightMinimumDaysOfUse
        }
    }

    /// Whole calendar days from `from` to `to` (negative if `to` is earlier).
    static func daysBetween(_ from: Date, _ to: Date, _ calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: from), to: calendar.startOfDay(for: to)).day ?? 0
    }

    static func dayKey(_ date: Date, _ calendar: Calendar) -> Int {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return (parts.year ?? 0) * 10_000 + (parts.month ?? 0) * 100 + (parts.day ?? 0)
    }
}

/// Reads and writes `ReviewPromptState` in the App Group defaults.
public enum ReviewPromptStore {
    public static func load(from defaults: UserDefaults) -> ReviewPromptState {
        ReviewPromptState(
            firstUseAt: defaults.object(forKey: SettingsKey.reviewFirstUseAt) as? Date,
            useDays: Set(list(defaults, SettingsKey.reviewUseDays).compactMap { Int($0) }),
            askedAt: list(defaults, SettingsKey.reviewAskedAt).compactMap(TimeInterval.init).map(Date.init(timeIntervalSince1970:)),
            askedVersions: list(defaults, SettingsKey.reviewAskedVersions)
        )
    }

    public static func save(_ state: ReviewPromptState, to defaults: UserDefaults) {
        if let first = state.firstUseAt { defaults.set(first, forKey: SettingsKey.reviewFirstUseAt) }
        defaults.set(state.useDays.sorted().map(String.init).joined(separator: ","), forKey: SettingsKey.reviewUseDays)
        defaults.set(state.askedAt.map { String($0.timeIntervalSince1970) }.joined(separator: ","), forKey: SettingsKey.reviewAskedAt)
        defaults.set(state.askedVersions.joined(separator: ","), forKey: SettingsKey.reviewAskedVersions)
    }

    private static func list(_ defaults: UserDefaults, _ key: String) -> [String] {
        (defaults.string(forKey: key) ?? "").split(separator: ",").map(String.init)
    }
}
