import Foundation

/// The prediction pause after a pregnancy ends (spec §4.4, §4.6). No time
/// threshold: predictions resume only when she confirms a period as the first
/// after the end, so there is no medical rule about postpartum bleeding.
public enum CyclePause {
    /// Paused when an ended state exists and its `firstPeriodConfirmedID` is nil
    /// or no longer matches a stored period (she deleted it).
    public static func isPaused(_ state: PregnancyEndState?, periods: [PeriodRecord]) -> Bool {
        guard let state else { return false }
        guard let confirmed = state.firstPeriodConfirmedID else { return true }
        return !periods.contains { $0.id == confirmed }
    }

    /// Periods starting before the end day are dropped, so the pregnancy-long
    /// gap never skews the averages.
    public static func periodsForForecast(_ periods: [PeriodRecord], state: PregnancyEndState?) -> [PeriodRecord] {
        guard let state else { return periods }
        return periods.filter { $0.startDate >= state.endDate }
    }

    /// While paused: the oldest stored period starting on or after the end day
    /// that she has not answered "not the first" for.
    public static func periodNeedingConfirmation(
        _ state: PregnancyEndState?,
        periods: [PeriodRecord],
        declined: Set<UUID>
    ) -> PeriodRecord? {
        guard let state, isPaused(state, periods: periods) else { return nil }
        return periods
            .filter { $0.startDate >= state.endDate && !declined.contains($0.id) }
            .min { $0.startDate < $1.startDate }
    }
}
