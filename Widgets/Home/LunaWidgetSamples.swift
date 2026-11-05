import Foundation
import KickCore

/// Fixed example data for the widget gallery, the placeholder and the PNG previews.
enum LunaWidgetSamples {
    enum Kind: CaseIterable {
        case needsSetup, cycle, cycleLate, cycleOnPeriod, fertility, fertilityOvulation, pregnancy, pregnancyEarly, pregnancyPastDue
    }

    static func snapshot(_ kind: Kind, now: Date, calendar: Calendar = .current) -> WidgetSnapshot {
        WidgetSnapshot.make(input(kind, now: now, calendar: calendar), now: now, calendar: calendar)
    }

    static func input(_ kind: Kind, now: Date, calendar: Calendar) -> WidgetInput {
        let today = calendar.startOfDay(for: now)
        func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: today) ?? today }
        /// Three closed 5-day periods whose latest started `daysAgo` days ago (28-day cycles).
        func periods(startedDaysAgo daysAgo: Int) -> [PeriodRecord] {
            [-56, -28, 0].map { shift in
                let start = day(-daysAgo + shift)
                return PeriodRecord(startDate: start, endDate: calendar.date(byAdding: .day, value: 4, to: start))
            }
        }
        func cycle(goal: CycleGoal, daysAgo: Int) -> WidgetInput {
            WidgetInput(
                mode: .tryingToConceive, hasCompletedOnboarding: true,
                preferences: CyclePreferences(goal: goal), periods: periods(startedDaysAgo: daysAgo)
            )
        }
        func pregnancy(elapsed: Int, kicks: Int?) -> WidgetInput {
            WidgetInput(
                mode: .pregnant, hasCompletedOnboarding: true,
                dueDate: day(280 - elapsed), kicksToday: kicks
            )
        }
        switch kind {
        case .needsSetup: return WidgetInput(mode: .pregnant, hasCompletedOnboarding: false)
        case .cycle: return cycle(goal: .tracking, daysAgo: 17)
        case .cycleLate: return cycle(goal: .tracking, daysAgo: 31)
        case .cycleOnPeriod: return cycle(goal: .tracking, daysAgo: 1)
        case .fertility: return cycle(goal: .conceiving, daysAgo: 11)
        case .fertilityOvulation: return cycle(goal: .conceiving, daysAgo: 14)
        case .pregnancy: return pregnancy(elapsed: 30 * 7 + 3, kicks: 6)
        case .pregnancyEarly: return pregnancy(elapsed: 4 * 7 + 2, kicks: nil)
        case .pregnancyPastDue: return pregnancy(elapsed: 41 * 7 + 2, kicks: nil)
        }
    }
}
