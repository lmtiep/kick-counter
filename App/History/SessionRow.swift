import KickCore
import KickData
import SwiftUI

/// One counting session (spec §4.7): count tile, day, start–end time, and the
/// time to 10 — or "Cancelled". Cancelled and over-2-hour sessions are marked in
/// the warning colours.
struct SessionRow: View {
    let session: KickSession
    let now: Date

    var body: some View {
        let state = session.state
        let isCompleted = state.status == .completed
        let isWarning = !isCompleted || state.exceededThreshold
        HStack(spacing: 12) {
            Text(state.count, format: .number)
                .font(.luna(.bodyStrong))
                .foregroundStyle(.luna(isWarning ? .warningText : .pregOnSoft))
                .frame(width: 38, height: 38)
                .background(
                    .luna(isWarning ? .warningBackground : .pregSoft),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(day(state.startedAt))
                    .font(.luna(.bodyStrong))
                    .foregroundStyle(.luna(.textPrimary))
                Text(times(state))
                    .font(.luna(.small))
                    .monospacedDigit()
                    .foregroundStyle(.luna(.textSecondary))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(trailing(state))
                .font(.luna(.bodyStrong))
                .foregroundStyle(.luna(isCompleted ? .textPrimary : .warningText))
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([L10n.historyRowCount(state.count), day(state.startedAt), times(state), trailing(state)].joined(separator: ", "))
        .accessibilityIdentifier("sessionRow")
    }

    private func day(_ date: Date) -> String {
        Calendar.current.isDate(date, inSameDayAs: now) ? L10n.commonToday : Formatting.weekdayDay(date)
    }

    private func times(_ state: SessionState) -> String {
        guard let end = state.endedAt else { return Formatting.time(state.startedAt) }
        return "\(Formatting.time(state.startedAt)) – \(Formatting.time(end))"
    }

    private func trailing(_ state: SessionState) -> String {
        guard state.status == .completed, let duration = state.duration else { return L10n.historyStatusCancelled }
        return Formatting.minutes(duration / 60)
    }
}
