import Foundation

/// The prediction pause after a pregnancy ends (spec §4.4, §4.6). No time
/// threshold: predictions resume only when she confirms a period as the first
/// after the end, so there is no medical rule about postpartum bleeding.
public enum CyclePause {
    /// Paused when an ended state exists and its `firstPeriodConfirmedID` is nil
    /// or no longer matches a stored period (she deleted it).
    public static func isPaused(_ state: PregnancyEndState?, periods: [PeriodRecord]) -> Bool {
        guard let state else { return false }
        return confirmedPeriod(state, periods: periods) == nil
    }

    /// The forecast's periods: all of them without an ended pregnancy; after one,
    /// only the confirmed first period and those after it, so neither the
    /// pregnancy-long gap nor bleeding she said was not her period skews the averages.
    /// While paused (no forecast is made) the periods from the end day on.
    public static func periodsForForecast(_ periods: [PeriodRecord], state: PregnancyEndState?) -> [PeriodRecord] {
        guard let state else { return periods }
        let from = confirmedPeriod(state, periods: periods)?.startDate ?? state.endDate
        return periods.filter { $0.startDate >= from }
    }

    /// While paused: the oldest stored period starting after the pregnancy's first
    /// day (on or after the end day when that is unknown) that she has not
    /// answered "not the first" for. A period logged with a date before the end
    /// day is asked about too.
    public static func periodNeedingConfirmation(
        _ state: PregnancyEndState?,
        periods: [PeriodRecord],
        declined: Set<UUID>
    ) -> PeriodRecord? {
        guard let state, isPaused(state, periods: periods) else { return nil }
        return periods
            .filter { period in
                let after = state.rangeStart.map { period.startDate > $0 } ?? (period.startDate >= state.endDate)
                return after && !declined.contains(period.id)
            }
            .min { $0.startDate < $1.startDate }
    }

    private static func confirmedPeriod(_ state: PregnancyEndState, periods: [PeriodRecord]) -> PeriodRecord? {
        guard let id = state.firstPeriodConfirmedID else { return nil }
        return periods.first { $0.id == id }
    }
}
