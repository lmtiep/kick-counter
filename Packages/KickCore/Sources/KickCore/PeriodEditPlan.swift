import Foundation

/// What saving the calendar's "edit period days" mode writes (phase 19 spec
/// §2.2): the ticked days, compared with the stored periods, as deletes,
/// updates and adds that `CycleCoordinator.applyPeriodEdits` saves at once.
public struct PeriodEditPlan: Equatable, Sendable {
    /// Stored periods no ticked run overlaps, or merged into an earlier one.
    public var deletes: [UUID]
    /// Stored periods whose days changed, keeping their id. Oldest first.
    public var updates: [PeriodRecord]
    /// Runs that overlap no stored period. Oldest first.
    public var adds: [PeriodRecord]

    public enum Failure: Error, Equatable, Sendable {
        /// A run is longer than `CycleRules.longPeriodDays`.
        case periodTooLong
    }

    public init(deletes: [UUID] = [], updates: [PeriodRecord] = [], adds: [PeriodRecord] = []) {
        self.deletes = deletes
        self.updates = updates
        self.adds = adds
    }

    /// Nothing to write.
    public var isEmpty: Bool { deletes.isEmpty && updates.isEmpty && adds.isEmpty }

    /// Ticked days the edit starts from: every day of every stored period
    /// (`CycleRules.dayRange`), start-of-day.
    public static func initialDays(periods: [PeriodRecord], today: Date, calendar: Calendar) -> Set<Date> {
        var result: Set<Date> = []
        for period in periods {
            let range = CycleRules.dayRange(of: period, today: today, calendar: calendar)
            var current = range.lowerBound
            while current <= range.upperBound {
                result.insert(current)
                guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
                current = next
            }
        }
        return result
    }

    /// The editable window (two years back ... today), shared with AddPastPeriodSheet.
    public static func window(now: Date, calendar: Calendar) -> ClosedRange<Date> {
        let today = calendar.startOfDay(for: now)
        let earliest = calendar.date(byAdding: .year, value: -2, to: today) ?? today
        return earliest...today
    }

    /// Compares the ticked days with the stored periods. Consecutive ticked days
    /// form a run; each run keeps the id of the earliest stored period it
    /// overlaps (the others it overlaps are deleted), or is added. A run ending
    /// today is stored open. Periods starting before the window, their days and
    /// ticked days outside the window are left out; unchanged periods are not
    /// written.
    public static func make(ticked: Set<Date>, periods: [PeriodRecord], now: Date, calendar: Calendar) -> Result<PeriodEditPlan, Failure> {
        let window = window(now: now, calendar: calendar)
        let today = window.upperBound
        let normalized = periods.map { CycleRules.normalized($0, calendar: calendar) }
        let outside = normalized.filter { $0.startDate < window.lowerBound }
        let editable = normalized
            .filter { $0.startDate >= window.lowerBound }
            .sorted { ($0.startDate, $0.id.uuidString) < ($1.startDate, $1.id.uuidString) }
        let lockedDays = initialDays(periods: outside, today: now, calendar: calendar)

        let days = Set(ticked.map { calendar.startOfDay(for: $0) })
            .filter { window.contains($0) && !lockedDays.contains($0) }
            .sorted()
        let runs = runs(of: days, calendar: calendar)
        if runs.contains(where: { $0.count > CycleRules.longPeriodDays }) {
            return .failure(.periodTooLong)
        }

        var plan = PeriodEditPlan()
        var claimed: Set<UUID> = []
        /// Untouched open periods whose ticks stop before today (past day 10).
        var staleOpen: [PeriodRecord] = []
        for run in runs {
            guard let first = run.first, let last = run.last else { continue }
            let range = first...last
            let owner = editable.first { period in
                !claimed.contains(period.id)
                    && CycleRules.dayRange(of: period, today: now, calendar: calendar).overlaps(range)
            }
            let endDate = last == today ? nil : last
            guard let owner else {
                plan.adds.append(PeriodRecord(startDate: first, endDate: endDate))
                continue
            }
            claimed.insert(owner.id)
            // Same days as stored (e.g. an open period past day 10): leave it be.
            if CycleRules.dayRange(of: owner, today: now, calendar: calendar) == range {
                if owner.isOpen, last != today {
                    staleOpen.append(PeriodRecord(id: owner.id, startDate: first, endDate: last))
                }
                continue
            }
            plan.updates.append(PeriodRecord(id: owner.id, startDate: first, endDate: endDate))
        }
        // Never leave two open periods (as `CycleCoordinator.addPastPeriod`): when
        // the edit opens a period through today, a stale one closes on its last tick.
        if (plan.adds + plan.updates).contains(where: \.isOpen) {
            plan.updates = (plan.updates + staleOpen).sorted { $0.startDate < $1.startDate }
        }
        plan.deletes = editable.filter { !claimed.contains($0.id) }.map(\.id)
        return .success(plan)
    }

    /// Splits sorted, distinct days into maximal runs of consecutive days.
    private static func runs(of days: [Date], calendar: Calendar) -> [[Date]] {
        var runs: [[Date]] = []
        for day in days {
            if let last = runs.last?.last, calendar.date(byAdding: .day, value: 1, to: last) == day {
                runs[runs.count - 1].append(day)
            } else {
                runs.append([day])
            }
        }
        return runs
    }
}
