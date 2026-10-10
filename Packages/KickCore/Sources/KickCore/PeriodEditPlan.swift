import Foundation

/// What saving the calendar's "edit period days" mode writes (phase 19 spec
/// §2.2): the ticked days, compared with the stored periods, as deletes,
/// updates and adds that `CycleCoordinator.applyPeriodEdits` saves at once.
public struct PeriodEditPlan: Equatable, Sendable {
    /// Touched stored periods no run overlaps, or merged into an earlier one.
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
            result.formUnion(days(in: CycleRules.dayRange(of: period, today: today, calendar: calendar), calendar: calendar))
        }
        return result
    }

    /// The editable window (two years back ... today), shared with AddPastPeriodSheet.
    public static func window(now: Date, calendar: Calendar) -> ClosedRange<Date> {
        let today = calendar.startOfDay(for: now)
        let earliest = calendar.date(byAdding: .year, value: -2, to: today) ?? today
        return earliest...today
    }

    /// Turns an edit into writes; only what the user touched changes (spec §2.2).
    ///
    /// - `initial`: the ticked days the edit started from; `ticked`: the ticked
    ///   days now. Days the user added or removed (inside the window, up to
    ///   today as of `now`, outside periods that start before the window) are
    ///   the *toggled* days. No toggled day gives an empty plan.
    /// - A stored period is *touched* when a toggled day is one of its days or
    ///   the day right before or after it, or when a run built from touched days
    ///   meets or overlaps it. Untouched periods are never written or deleted,
    ///   and their length is not checked.
    /// - The touched periods' days, plus added days, minus removed days, form
    ///   runs of consecutive days. Each run keeps the id of the earliest touched
    ///   period it overlaps (the others it overlaps are deleted), or is added; a
    ///   touched period no run overlaps is deleted. A run ending today is stored
    ///   open; when one is, any other open period that has run past
    ///   `CycleRules.longPeriodDays` closes at `typicalPeriodLength`.
    public static func make(
        initial: Set<Date>,
        ticked: Set<Date>,
        periods: [PeriodRecord],
        now: Date,
        typicalPeriodLength: Int,
        calendar: Calendar
    ) -> Result<PeriodEditPlan, Failure> {
        let window = window(now: now, calendar: calendar)
        let today = window.upperBound
        let normalized = periods.map { CycleRules.normalized($0, calendar: calendar) }
        let outside = normalized.filter { $0.startDate < window.lowerBound }
        let editable = normalized
            .filter { $0.startDate >= window.lowerBound }
            .sorted { ($0.startDate, $0.id.uuidString) < ($1.startDate, $1.id.uuidString) }
        let lockedDays = initialDays(periods: outside, today: now, calendar: calendar)
        let editableDay = { (day: Date) in window.contains(day) && !lockedDays.contains(day) }

        let start = Set(initial.map { calendar.startOfDay(for: $0) })
        let end = Set(ticked.map { calendar.startOfDay(for: $0) })
        let added = end.subtracting(start).filter(editableDay)
        let removed = start.subtracting(end).filter(editableDay)
        let toggled = added.union(removed)
        guard !toggled.isEmpty else { return .success(PeriodEditPlan()) }

        let ranges = Dictionary(uniqueKeysWithValues: editable.map {
            ($0.id, CycleRules.dayRange(of: $0, today: now, calendar: calendar))
        })
        /// A period's days with the day before and after: what touching it means.
        func reach(_ period: PeriodRecord) -> ClosedRange<Date> {
            let range = ranges[period.id]!
            let before = calendar.date(byAdding: .day, value: -1, to: range.lowerBound) ?? range.lowerBound
            return calendar.startOfDay(for: before)...CycleRules.nextDay(after: range.upperBound, calendar: calendar)
        }

        var touched = Set(editable.filter { period in toggled.contains { reach(period).contains($0) } }.map(\.id))
        var runs: [ClosedRange<Date>] = []
        while true {
            var days = added
            for period in editable where touched.contains(period.id) {
                days.formUnion(Self.days(in: ranges[period.id]!, calendar: calendar))
            }
            runs = Self.runs(of: days.subtracting(removed).filter(editableDay).sorted(), calendar: calendar)
            // A run that now meets or overlaps another stored period touches it too.
            let reached = editable.filter { period in
                !touched.contains(period.id) && runs.contains { $0.overlaps(reach(period)) }
            }
            if reached.isEmpty { break }
            touched.formUnion(reached.map(\.id))
        }
        let length = { (run: ClosedRange<Date>) in
            (calendar.dateComponents([.day], from: run.lowerBound, to: run.upperBound).day ?? 0) + 1
        }
        if runs.contains(where: { length($0) > CycleRules.longPeriodDays }) {
            return .failure(.periodTooLong)
        }

        var plan = PeriodEditPlan()
        var claimed: Set<UUID> = []
        /// Open periods the plan leaves as they are.
        var keptOpen = normalized.filter { $0.isOpen && !touched.contains($0.id) }
        for run in runs {
            let owner = editable.first { period in
                touched.contains(period.id) && !claimed.contains(period.id) && ranges[period.id]!.overlaps(run)
            }
            let endDate = run.upperBound == today ? nil : run.upperBound
            guard let owner else {
                plan.adds.append(PeriodRecord(startDate: run.lowerBound, endDate: endDate))
                continue
            }
            claimed.insert(owner.id)
            // Same days as stored (e.g. an open period past day 10): leave it be.
            if ranges[owner.id] == run {
                if owner.isOpen { keptOpen.append(owner) }
                continue
            }
            plan.updates.append(PeriodRecord(id: owner.id, startDate: run.lowerBound, endDate: endDate))
        }
        // Never leave two open periods (as `CycleCoordinator.startPeriod`): when the
        // edit opens one through today, a stale one closes at the typical length.
        if let opened = (plan.adds + plan.updates).first(where: \.isOpen) {
            let closed = keptOpen.compactMap {
                CycleRules.closingStale($0, before: opened.startDate, typicalLength: typicalPeriodLength, calendar: calendar)
            }
            plan.updates = (plan.updates + closed).sorted { $0.startDate < $1.startDate }
        }
        plan.deletes = editable.filter { touched.contains($0.id) && !claimed.contains($0.id) }.map(\.id)
        return .success(plan)
    }

    /// Every day of `range`, start-of-day.
    private static func days(in range: ClosedRange<Date>, calendar: Calendar) -> Set<Date> {
        var result: Set<Date> = []
        var current = calendar.startOfDay(for: range.lowerBound)
        while current <= range.upperBound {
            result.insert(current)
            current = CycleRules.nextDay(after: current, calendar: calendar)
        }
        return result
    }

    /// Splits sorted, distinct days into maximal runs of consecutive days.
    private static func runs(of days: [Date], calendar: Calendar) -> [ClosedRange<Date>] {
        var runs: [ClosedRange<Date>] = []
        for day in days {
            if let last = runs.last, CycleRules.nextDay(after: last.upperBound, calendar: calendar) == day {
                runs[runs.count - 1] = last.lowerBound...day
            } else {
                runs.append(day...day)
            }
        }
        return runs
    }
}
