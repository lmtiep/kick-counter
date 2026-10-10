import KickCore
import SwiftUI

/// The calendar's "Sửa kỳ kinh" mode (phase 19 spec §2.1): which days can be
/// ticked, which are, and what changed since entering.
struct CalendarPeriodEdit: Equatable {
    /// Ticked days, start-of-day; kept across months until Save or Cancel.
    var ticked: Set<Date>
    /// The stored periods' days the edit is based on; `ticked` minus this is
    /// what the user added, this minus `ticked` what they removed.
    private(set) var initial: Set<Date>
    /// Days of periods that start before the window: shown ticked, never changed.
    private(set) var locked: Set<Date>
    private(set) var window: ClosedRange<Date>

    init(periods: [PeriodRecord], now: Date, calendar: Calendar) {
        let window = PeriodEditPlan.window(now: now, calendar: calendar)
        let days = PeriodEditPlan.initialDays(periods: periods, today: now, calendar: calendar)
        let outside = periods.filter { calendar.startOfDay(for: $0.startDate) < window.lowerBound }
        self.window = window
        initial = days
        ticked = days
        locked = PeriodEditPlan.initialDays(periods: outside, today: now, calendar: calendar)
    }

    var hasChanges: Bool { ticked != initial }

    /// Keeps the user's changes on top of the periods as they are now (a period
    /// started from Today, deleted elsewhere, or an open one growing past
    /// midnight), with the window moved to today.
    mutating func rebase(periods: [PeriodRecord], now: Date, calendar: Calendar) {
        let added = ticked.subtracting(initial)
        let removed = initial.subtracting(ticked)
        var fresh = CalendarPeriodEdit(periods: periods, now: now, calendar: calendar)
        fresh.ticked = fresh.initial.union(added).subtracting(removed)
        self = fresh
    }

    /// Days from the window start up to today, outside a locked period.
    func canToggle(_ day: Date) -> Bool {
        window.contains(day) && !locked.contains(day)
    }

    mutating func toggle(_ day: Date) {
        guard canToggle(day) else { return }
        if ticked.contains(day) { ticked.remove(day) } else { ticked.insert(day) }
    }

    /// `periodEditDay-20260910`, for UI tests.
    static func identifier(for day: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "periodEditDay-%04d%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

/// A day in edit mode (spec §2.3): the number with a tick circle under it, as a
/// toggle button. Ticked: a `cycleStrong` disc with an `onAccent` check;
/// unticked: a `textSecondary` outline. Future days and days outside the window
/// show no circle and are dimmed and disabled; a locked day keeps its tick.
struct PeriodEditDayCell: View {
    let day: Date
    let isTicked: Bool
    let isToday: Bool
    /// Inside the window (today or earlier): a circle is drawn.
    let showsTick: Bool
    let isEnabled: Bool
    let label: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(Formatting.dayNumber(day))
                    .font(.luna(size: 15, weight: isToday ? .bold : .medium, relativeTo: .body))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(.luna(isToday ? .cycleText : .textPrimary))
                    .frame(height: 20)
                tick
                    .frame(width: 24, height: 24)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .opacity(isEnabled ? 1 : 0.35)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isTicked ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder private var tick: some View {
        if isTicked {
            Circle()
                .fill(.luna(.cycleStrong))
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.luna(.onAccent))
                }
        } else if showsTick {
            Circle().strokeBorder(.luna(.textSecondary), lineWidth: 1.5)
        } else {
            Color.clear
        }
    }
}

extension CycleAccessibility {
    /// "October 4, today, period day" in edit mode (spec §2.3).
    static func editDayLabel(day: Date, isToday: Bool, isTicked: Bool, policy: CycleDisplayPolicy) -> String {
        var parts = [Formatting.spokenDay(day)]
        if isToday { parts.append(L10n.calendarA11yToday) }
        if isTicked {
            parts.append(policy.predictedBleedLabel == .withdrawalBleed ? L10n.periodEditA11yTickedBleed : L10n.periodEditA11yTicked)
        }
        return parts.joined(separator: ", ")
    }
}

/// "Sửa kỳ kinh" under the month row (spec §2.1), trailing.
struct PeriodEditButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            Button(action: action) {
                Label(title, systemImage: "pencil")
            }
            .buttonStyle(.pill(.soft(.cycleSoft, .cycleOnSoft), fullWidth: false, height: 44))
            .accessibilityIdentifier("calendarEditPeriods")
        }
        .padding(.horizontal, 20)
    }
}

/// Hủy and Lưu above the title while editing; Save waits for a change.
struct PeriodEditBar: View {
    let canSave: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(L10n.commonCancel, action: onCancel)
                .buttonStyle(.pill(.text(.textSecondary), fullWidth: false, height: 44))
                .accessibilityIdentifier("periodEditCancel")
            Spacer(minLength: 0)
            Button(L10n.commonSave, action: onSave)
                .buttonStyle(.pill(.filled(.cycleStrong), fullWidth: false, height: 44))
                .disabled(!canSave)
                .accessibilityIdentifier("periodEditSave")
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }
}

/// "Mỗi kỳ kinh tối đa 10 ngày…" or a save failure, under the buttons.
struct PeriodEditError: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.luna(.caption))
            .foregroundStyle(.luna(.warningText))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 20)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("periodEditError")
    }
}

/// Replaces the legend and the selected day while editing; wraps at large text.
struct PeriodEditHint: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.luna(.caption))
            .foregroundStyle(.luna(.textSecondary))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 22)
            .accessibilityIdentifier("periodEditHint")
    }
}
