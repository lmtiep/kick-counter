import Foundation

/// Sample cycle data for UI tests and screenshots (`-uiTesting -seedCycles <name>`).
/// Every scenario uses 5-day periods relative to `today`.
public enum CycleSeedScenario: String, Sendable, CaseIterable {
    /// Trying-to-conceive mode with nothing logged.
    case empty
    /// Regular 28-day cycles, period started yesterday and still going (cycle day 2),
    /// with flow logged yesterday and today.
    case period
    /// Regular 28-day cycles at cycle day 13, inside the fertile window, with signals
    /// logged (and a mood and a symptom yesterday).
    case fertile
    /// Regular 28-day cycles, next period 4 days late.
    case late
    /// 24/35/26/34-day cycles: low confidence and the irregular warning, cycle day 11.
    case irregular

    public struct Records: Equatable, Sendable {
        public let periods: [PeriodRecord]
        public let logs: [CycleLogRecord]
    }

    public func records(today now: Date, calendar: Calendar = .current) -> Records {
        let today = calendar.startOfDay(for: now)
        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: today) ?? today
        }
        func closed(_ offsets: [Int]) -> [PeriodRecord] {
            offsets.map { PeriodRecord(startDate: day($0), endDate: day($0 + 4)) }
        }
        switch self {
        case .empty:
            return Records(periods: [], logs: [])
        case .period:
            return Records(
                periods: closed([-85, -57, -29]) + [PeriodRecord(startDate: day(-1))],
                logs: [
                    CycleLogRecord(day: day(-1), flow: .heavy, moods: [.tired], symptoms: [.cramps]),
                    CycleLogRecord(day: day(0), flow: .medium),
                ]
            )
        case .fertile:
            return Records(
                periods: closed([-96, -68, -40, -12]),
                logs: [
                    CycleLogRecord(day: day(-4), bbtCelsius: 36.3),
                    CycleLogRecord(day: day(-3), bbtCelsius: 36.4),
                    CycleLogRecord(day: day(-2), bbtCelsius: 36.3, mucus: .sticky),
                    CycleLogRecord(day: day(-1), lh: .negative, bbtCelsius: 36.4, mucus: .creamy, moods: [.calm], symptoms: [.bloating]),
                    CycleLogRecord(day: day(0), bbtCelsius: 36.3, mucus: .eggWhite),
                ]
            )
        case .late:
            return Records(periods: closed([-116, -88, -60, -32]), logs: [])
        case .irregular:
            return Records(periods: closed([-129, -105, -70, -44, -10]), logs: [])
        }
    }
}
