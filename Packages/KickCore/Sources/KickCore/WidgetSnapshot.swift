import Foundation

/// Everything the Home Screen / Lock Screen widget reads, as plain values. The
/// widget extension fills it from the App Group (defaults + a read-only store).
public struct WidgetInput: Equatable, Sendable {
    public var mode: AppMode
    public var hasCompletedOnboarding: Bool
    public var preferences: CyclePreferences
    public var settings: CycleSettings
    public var periods: [PeriodRecord]
    public var logs: [CycleLogRecord]
    public var dueDate: Date?
    /// The count of today's latest finished kick session, nil when none.
    public var kicksToday: Int?
    /// An ended pregnancy (1.1 item 4): predictions pause until the first period after it.
    public var endState: PregnancyEndState?

    public init(
        mode: AppMode,
        hasCompletedOnboarding: Bool,
        preferences: CyclePreferences = CyclePreferences(),
        settings: CycleSettings = CycleSettings(),
        periods: [PeriodRecord] = [],
        logs: [CycleLogRecord] = [],
        dueDate: Date? = nil,
        kicksToday: Int? = nil,
        endState: PregnancyEndState? = nil
    ) {
        self.mode = mode
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.preferences = preferences
        self.settings = settings
        self.periods = periods
        self.logs = logs
        self.dueDate = dueDate
        self.kicksToday = kicksToday
        self.endState = endState
    }
}

/// What the widget shows for one moment (spec: one adaptive widget following the
/// app's mode). The numbers are the ones Today shows: they come from
/// `CyclePredictor`/`PregnancyTimeline`, nothing is recomputed here. No strings
/// live here; the widget maps these cases to the app's localized wording.
public struct WidgetSnapshot: Equatable, Sendable {
    public enum Content: Equatable, Sendable {
        /// Not onboarded, partner mode, or no data yet: "Open Luna Mom to get started".
        case needsSetup
        /// Cycle mode while tracking.
        case cycle(CycleContent)
        /// Cycle mode while trying to conceive.
        case fertility(FertilityContent)
        case pregnancy(PregnancyContent)
        /// Cycle mode after a pregnancy ended, before the first period is confirmed:
        /// no prediction, one gentle line (never naming the pregnancy).
        case paused
    }

    public enum PeriodHeadline: Equatable, Sendable {
        case onPeriod(day: Int)
        case late(days: Int)
        case dueToday
        case upcoming(days: Int)
    }

    public struct CycleContent: Equatable, Sendable {
        public let headline: PeriodHeadline
        public let nextPeriodDate: Date
        public let cycleDay: Int
        /// Hormonal contraception: the bleed is "expected bleed", not a period.
        public let expectsWithdrawalBleed: Bool
        public let ring: [CycleRingSegment]
        /// 0...1 clockwise from 12 o'clock, the middle of today.
        public let markerFraction: Double
    }

    public enum FertilityStatus: Equatable, Sendable {
        case period
        case late(days: Int)
        case ovulationDay
        case high
        case low
    }

    public struct StripDay: Equatable, Sendable {
        public let date: Date
        public let status: CycleDayStatus
        public let isToday: Bool
    }

    public struct FertilityContent: Equatable, Sendable {
        public let status: FertilityStatus
        public let cycleDay: Int
        public let fertileWindow: ClosedRange<Date>
        /// Today and the six days after it.
        public let strip: [StripDay]
        public let nextPeriodDate: Date
    }

    public enum KickLine: Equatable, Sendable {
        /// Before week 28 the app does not suggest counting.
        case hidden
        case notCounted
        case counted(Int)
    }

    public struct PregnancyContent: Equatable, Sendable {
        public let weeks: Int
        public let days: Int
        public let daysRemaining: Int
        public let daysPastDue: Int
        /// The week whose fruit artwork is shown (4...42, as in the app).
        public let fruitWeek: Int
        public let kicks: KickLine
    }

    public let content: Content
    /// The next local midnight: everything shown changes by whole days.
    public let refreshDate: Date

    static let stripLength = 7

    public static func make(_ input: WidgetInput, now: Date, calendar: Calendar = .current) -> WidgetSnapshot {
        let today = calendar.startOfDay(for: now)
        let refresh = calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86_400)
        return WidgetSnapshot(content: content(input, now: now, calendar: calendar), refreshDate: refresh)
    }

    private static func content(_ input: WidgetInput, now: Date, calendar: Calendar) -> Content {
        guard input.hasCompletedOnboarding else { return .needsSetup }
        switch input.mode {
        case .partner:
            return .needsSetup
        case .pregnant:
            return pregnancy(input, now: now, calendar: calendar)
        case .tryingToConceive:
            if CyclePause.isPaused(input.endState, periods: input.periods) { return .paused }
            guard let forecast = CyclePredictor.forecast(
                periods: CyclePause.periodsForForecast(input.periods, state: input.endState),
                logs: input.logs, settings: input.settings, now: now, calendar: calendar
            ) else { return .needsSetup }
            let policy = CycleDisplayPolicy(input.preferences)
            return input.preferences.goal == .tracking
                ? .cycle(cycle(forecast, policy: policy, calendar: calendar))
                : .fertility(fertility(forecast, policy: policy, calendar: calendar))
        }
    }

    private static func cycle(_ forecast: CycleForecast, policy: CycleDisplayPolicy, calendar: Calendar) -> CycleContent {
        let headline: PeriodHeadline
        switch CycleRingHeadline(forecast: forecast) {
        case .periodDay(let day): headline = .onPeriod(day: day)
        case .late(let days): headline = .late(days: days)
        case .nextPeriodToday: headline = .dueToday
        case .daysUntilNextPeriod(let days): headline = .upcoming(days: days)
        }
        let length = Double(CycleRingGeometry.length(of: forecast))
        return CycleContent(
            headline: headline,
            nextPeriodDate: forecast.nextPeriodStart,
            cycleDay: forecast.cycleDay,
            expectsWithdrawalBleed: policy.predictedBleedLabel == .withdrawalBleed,
            ring: CycleRingGeometry.segments(for: forecast, policy: policy, calendar: calendar),
            markerFraction: (Double(forecast.cycleDay) - 0.5) / length
        )
    }

    private static func fertility(_ forecast: CycleForecast, policy: CycleDisplayPolicy, calendar: Calendar) -> FertilityContent {
        let today = forecast.today
        let status: FertilityStatus
        if forecast.dayStatus(for: today) == .period(isPredicted: false) {
            status = .period
        } else if forecast.daysLate > 0 {
            status = .late(days: forecast.daysLate)
        } else if policy.showsOvulation, forecast.ovulationDate == today {
            status = .ovulationDay
        } else {
            switch policy.visibleStatus(forecast.dayStatus(for: today)) {
            case .fertile, .peak: status = .high
            case .period, .low: status = .low
            }
        }
        let strip = (0..<stripLength).compactMap { offset -> StripDay? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            return StripDay(date: day, status: policy.visibleStatus(forecast.dayStatus(for: day)), isToday: offset == 0)
        }
        return FertilityContent(
            status: status,
            cycleDay: forecast.cycleDay,
            fertileWindow: forecast.fertileWindow,
            strip: strip,
            nextPeriodDate: forecast.nextPeriodStart
        )
    }

    private static func pregnancy(_ input: WidgetInput, now: Date, calendar: Calendar) -> Content {
        guard let dueDate = input.dueDate,
              let timeline = PregnancyTimeline(dueDate: dueDate, now: now, calendar: calendar)
        else { return .needsSetup }
        let kicks: KickLine
        if !timeline.isKickCountingWeek {
            kicks = .hidden
        } else if let count = input.kicksToday, count > 0 {
            kicks = .counted(count)
        } else {
            kicks = .notCounted
        }
        return .pregnancy(PregnancyContent(
            weeks: timeline.week.weeks,
            days: timeline.week.days,
            daysRemaining: timeline.daysRemaining,
            daysPastDue: timeline.daysPastDue,
            fruitWeek: WeeklyContentLibrary.clampedWeek(timeline.week.weeks),
            kicks: kicks
        ))
    }
}
