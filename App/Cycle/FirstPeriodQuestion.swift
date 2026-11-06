import KickCore
import SwiftUI

/// "Is this your first period since…?" (1.1 item 4, spec §4.6): asked once for
/// the first period logged on or after the end day while predictions are
/// paused. "Đúng vậy" resumes predictions from it; "Chưa phải" keeps the pause
/// and the period, and that period is not asked about again.
struct FirstPeriodQuestion: ViewModifier {
    /// True while something else is on screen (a sheet, an error alert).
    let isBlocked: Bool

    @Environment(CycleCoordinator.self) private var cycle

    private var period: PeriodRecord? { isBlocked ? nil : cycle.periodNeedingConfirmation }

    func body(content: Content) -> some View {
        content.alert(
            cycle.endState.map { L10n.firstPeriodQuestion($0.branch) } ?? "",
            isPresented: Binding(get: { period != nil }, set: { _ in }),
            presenting: period
        ) { period in
            Button(L10n.firstPeriodYes) {
                Task { await cycle.confirmFirstPeriod(id: period.id) }
            }
            .accessibilityIdentifier("firstPeriodYes")
            Button(L10n.firstPeriodNo, role: .cancel) {
                cycle.declineFirstPeriod(id: period.id)
            }
            .accessibilityIdentifier("firstPeriodNo")
        } message: { _ in
            Text(L10n.firstPeriodMessage)
        }
    }
}

extension View {
    func firstPeriodQuestion(isBlocked: Bool) -> some View {
        modifier(FirstPeriodQuestion(isBlocked: isBlocked))
    }
}
