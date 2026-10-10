import KickCore
import SwiftUI

/// "Thuốc tránh thai" on the cycle Today (phase 17 spec §4.3): where she is in
/// the pack and the reminder time, with "Đã uống hôm nay" / "Bỏ đánh dấu", or the
/// break week with the day the new pack starts. Hidden while the reminder is off.
struct PillTodayCard: View {
    @Environment(PillCoordinator.self) private var pill
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var working = false
    @State private var failure: PillFailure?

    var body: some View {
        if let today = pill.today {
            VStack(alignment: .leading, spacing: 14) {
                header(today)
                if case .pillDay(_, _, let day, let isYesterday, let taken) = today {
                    if let taken {
                        takenRow(taken)
                    } else {
                        Button(isYesterday ? L10n.pillCardTakeYesterday : L10n.pillCardTake) { Task { await mark(day) } }
                            .buttonStyle(.pill(.filled(.cycleStrong), height: 44))
                            .disabled(working)
                            .accessibilityIdentifier("pillTakeToday")
                    }
                }
            }
            .lunaCard(padding: 16)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("pillTodayCard")
            .alert(failure.map(L10n.pillFailure) ?? "", isPresented: Binding(
                get: { failure != nil },
                set: { if !$0 { failure = nil } }
            )) {
                Button(L10n.commonOK) {}
            }
        }
    }

    private func header(_ today: PillToday) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "pills.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.luna(.cycleOnSoft))
                .frame(width: 44, height: 44)
                .background(Circle().fill(.luna(.cycleSoft)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.pillCardTitle)
                    .font(.luna(.cardTitleSmall))
                    .foregroundStyle(.luna(.textPrimary))
                    .accessibilityAddTraits(.isHeader)
                switch today {
                case .pillDay(let number, let count, _, let isYesterday, _):
                    // Just after midnight, yesterday's pill while it is still due.
                    Text(isYesterday ? L10n.pillCardNumberYesterday(number, count) : L10n.pillCardNumber(number, count))
                        .font(.luna(.statFigure))
                        .foregroundStyle(.luna(.cycleStrong))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(L10n.pillCardNumberA11y(number, count, yesterday: isYesterday))
                        .accessibilityIdentifier("pillCardNumber")
                    Text(L10n.pillCardReminderAt(Formatting.clockTime(hour: pill.settings.hour, minute: pill.settings.minute)))
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.textSecondary))
                case .breakWeek(let nextPackStart):
                    Text(L10n.pillCardBreakWeek(Formatting.dayShortMonth(nextPackStart)))
                        .font(.luna(.body))
                        .foregroundStyle(.luna(.textPrimary))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("pillBreakWeek")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func takenRow(_ taken: PillDoseRecord) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 8))
        layout {
            // One element: a `Label` gives its identifier to the icon too, which
            // VoiceOver read as "Selected".
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .accessibilityHidden(true)
                Text(L10n.pillCardTakenAt(Formatting.time(taken.takenAt)))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.luna(.bodyStrong))
            .foregroundStyle(.luna(.cycleOnSoft))
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("pillTakenLabel")
            Button(L10n.pillCardUndo) { Task { await undo(taken.day) } }
                .buttonStyle(.pill(.soft(.surfaceAlt, .textPrimary), fullWidth: false, height: 44))
                .disabled(working)
                .accessibilityLabel(L10n.pillCardUndoA11y)
                .accessibilityIdentifier("pillUndo")
        }
    }

    private func mark(_ day: CalendarDay) async {
        working = true
        defer { working = false }
        failure = await pill.markTaken(on: day)
    }

    private func undo(_ day: CalendarDay) async {
        working = true
        defer { working = false }
        failure = await pill.undo(on: day)
    }
}
