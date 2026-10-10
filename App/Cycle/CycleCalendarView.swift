import Accessibility
import KickCore
import SwiftUI

/// Trying-to-conceive mode, Calendar tab (spec §4.3): month grid in the app
/// language's week order (Monday first in Vietnamese), legend, and the selected
/// day with a "Log" button. Swipe or use the arrows to change month; future
/// days can be selected but not logged. Phase 19: "Sửa kỳ kinh" turns the grid
/// into tick circles for past period days, saved all at once
/// (`CalendarPeriodEditor.swift`).
struct CycleCalendarView: View {
    @Environment(CycleCoordinator.self) private var cycle
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var month = CycleCalendarGrid.startOfMonth(AppClock.now(), calendar: AppLocale.calendar)
    @State private var selected = AppLocale.calendar.startOfDay(for: AppClock.now())
    @State private var logDay: CycleDaySelection?
    /// Non-nil while editing period days (phase 19).
    @State private var edit: CalendarPeriodEdit?
    @State private var editError: String?
    @State private var saving = false
    @State private var confirmingDiscard = false

    /// The app language's calendar (Monday first in Vietnamese), not the device's.
    private var calendar: Calendar { AppLocale.calendar }
    private var today: Date { calendar.startOfDay(for: AppClock.now()) }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if edit != nil {
                            PeriodEditBar(canSave: (edit?.hasChanges ?? false) && !saving, onCancel: cancelEdit) {
                                Task { await saveEdit() }
                            }
                        }
                        header
                        if edit == nil {
                            PeriodEditButton(title: isBleed ? L10n.periodEditButtonBleed : L10n.periodEditButton, action: startEdit)
                                .padding(.top, 10)
                        } else if let editError {
                            PeriodEditError(message: editError)
                                .padding(.top, 12)
                                .id(Self.editErrorAnchor)
                        }
                        grid
                            .padding(.top, 18)
                        if edit != nil {
                            PeriodEditHint(text: isBleed ? L10n.periodEditHintBleed : L10n.periodEditHint)
                                .padding(.top, 14)
                        } else {
                            CycleLegend(policy: cycle.policy)
                                .padding(.top, 14)
                            selectedDayCard
                                .padding(.top, 16)
                            if cycle.forecast == nil {
                                Text(L10n.calendarEmptyHint)
                                    .font(.luna(.caption))
                                    .foregroundStyle(.luna(.textSecondary))
                                    .padding(.horizontal, 20)
                                    .padding(.top, 12)
                            }
                        }
                    }
                    .padding(.bottom, 24)
                }
                // The error sits under the title; at large text it is scrolled into view.
                .onChange(of: editError) { _, new in
                    guard new != nil else { return }
                    withAnimation(LunaMotion.isEnabled && !reduceMotion ? .easeOut(duration: 0.2) : nil) {
                        proxy.scrollTo(Self.editErrorAnchor, anchor: .center)
                    }
                }
            }
            // Content scrolled up stays out from under the status bar.
            .lunaStatusBarBackdrop()
            .lunaBackground()
            .toolbar(.hidden, for: .navigationBar)
            .simultaneousGesture(
                DragGesture(minimumDistance: 30).onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) * 2 else { return }
                    showMonth(value.translation.width < 0 ? 1 : -1)
                }
            )
            .sheet(item: $logDay) { selection in
                CycleDayLogSheet(day: selection.date, existing: cycle.log(on: selection.date))
            }
            .confirmationDialog(L10n.periodEditDiscardTitle, isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button(L10n.periodEditDiscardConfirm, role: .destructive) { leaveEdit() }
                Button(L10n.periodEditDiscardKeep, role: .cancel) {}
            }
            .onChange(of: edit?.ticked) { editError = nil }
        }
    }

    // MARK: - Phase 19: edit period days

    private static let editErrorAnchor = "periodEditErrorAnchor"

    private var isBleed: Bool { cycle.policy.predictedBleedLabel == .withdrawalBleed }

    private func startEdit() {
        editError = nil
        withAnimation(editAnimation) {
            edit = CalendarPeriodEdit(periods: cycle.periods, now: AppClock.now(), calendar: calendar)
        }
    }

    private func cancelEdit() {
        if edit?.hasChanges == true {
            confirmingDiscard = true
        } else {
            leaveEdit()
        }
    }

    private func leaveEdit() {
        editError = nil
        withAnimation(editAnimation) { edit = nil }
    }

    private var editAnimation: Animation? {
        LunaMotion.isEnabled ? LunaMotion.fade : nil
    }

    private func saveEdit() async {
        guard let edit else { return }
        switch PeriodEditPlan.make(ticked: edit.ticked, periods: cycle.periods, now: AppClock.now(), calendar: calendar) {
        case .failure(.periodTooLong):
            showEditError(isBleed ? L10n.periodEditTooLongBleed(CycleRules.longPeriodDays) : L10n.periodEditTooLong(CycleRules.longPeriodDays))
        case .success(let plan):
            saving = true
            defer { saving = false }
            if let failure = await cycle.applyPeriodEdits(plan) {
                // Shown here, not in the Today tab's alert.
                cycle.clearFailure()
                showEditError(L10n.cycleFailure(failure))
            } else {
                leaveEdit()
                AccessibilityNotification.Announcement(isBleed ? L10n.periodEditSavedBleed : L10n.periodEditSaved).post()
            }
        }
    }

    private func showEditError(_ message: String) {
        editError = message
        AccessibilityNotification.Announcement(message).post()
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                title
                Spacer(minLength: 8)
                monthSwitcher
            }
            VStack(alignment: .leading, spacing: 8) {
                title
                monthSwitcher
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private var title: some View {
        Text(edit == nil ? L10n.calendarTitle : (isBleed ? L10n.periodEditButtonBleed : L10n.periodEditButton))
            .font(.luna(.screenTitle))
            .tracking(-0.56)
            .foregroundStyle(.luna(.textPrimary))
            .accessibilityAddTraits(.isHeader)
    }

    private var monthSwitcher: some View {
        HStack(spacing: 4) {
            monthButton("chevron.left", label: L10n.calendarPrevious, identifier: "calendarPrevious") { showMonth(-1) }
            // As wide as the widest month of the year, so the arrows stay put.
            ZStack {
                ForEach(monthsOfShownYear, id: \.self) { other in
                    Text(Formatting.monthYear(other)).hidden()
                }
                Text(Formatting.monthYear(month))
                    .foregroundStyle(.luna(.textPrimary))
                    .accessibilityIdentifier("calendarMonthTitle")
            }
            .font(.luna(.bodyStrong))
            .multilineTextAlignment(.center)
            .frame(minWidth: 110)
            monthButton("chevron.right", label: L10n.calendarNext, identifier: "calendarNext") { showMonth(1) }
        }
    }

    /// The first day of every month in the shown month's year.
    private var monthsOfShownYear: [Date] {
        let year = calendar.dateInterval(of: .year, for: month)?.start ?? month
        return (0..<12).compactMap { calendar.date(byAdding: .month, value: $0, to: year) }
    }

    private func monthButton(_ symbol: String, label: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.luna(.textPrimary))
                .frame(width: 34, height: 34)
                .background(Circle().fill(.luna(.card)))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    private var grid: some View {
        let days = CycleCalendarGrid.days(inMonthOf: month, calendar: calendar)
        return VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(Array(WeekdayLabel.row(calendar: calendar).enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.luna(.tiny))
                        .foregroundStyle(.luna(.textSecondary))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day, let edit {
                        let ticked = edit.ticked.contains(day)
                        PeriodEditDayCell(
                            day: day,
                            isTicked: ticked,
                            isToday: day == today,
                            showsTick: edit.window.contains(day),
                            isEnabled: edit.canToggle(day),
                            label: CycleAccessibility.editDayLabel(day: day, isToday: day == today, isTicked: ticked, policy: cycle.policy),
                            identifier: CalendarPeriodEdit.identifier(for: day, calendar: calendar)
                        ) {
                            self.edit?.toggle(day)
                        }
                    } else if let day {
                        CalendarDayCell(
                            day: day,
                            status: cycle.forecast.map { cycle.policy.visibleStatus($0.dayStatus(for: day)) },
                            log: cycle.log(on: day),
                            isToday: day == today,
                            isSelected: day == selected,
                            policy: cycle.policy
                        ) {
                            selected = day
                        }
                    } else {
                        Color.clear
                            .frame(height: 44)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(.luna(.card), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.luna(.cardBorder), lineWidth: 1))
        .padding(.horizontal, 14)
    }

    private var selectedDayCard: some View {
        let policy = cycle.policy
        let status = cycle.forecast?.dayStatus(for: selected)
        let cycleDay = cycle.forecast?.cycleDay(on: selected)
        let line: String? = status.flatMap { status in
            cycleDay.map { CycleTexts.phase(day: $0, status: status, policy: policy) } ?? CycleTexts.status(status, policy: policy)
        }
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(selected == today ? L10n.commonToday : Formatting.weekdayDay(selected))
                    .font(.luna(.caption))
                    .foregroundStyle(.luna(.textSecondary))
                if let line {
                    Text(line)
                        .font(.luna(.cardTitle))
                        .foregroundStyle(.luna(.textPrimary))
                }
                if let summary = CycleTexts.logSummary(cycle.log(on: selected)) {
                    // One line, cut with "…"; VoiceOver still reads all of it (spec §3.1).
                    Text(summary)
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.textSecondary))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("calendarSelectedDay")
            Button(L10n.calendarLog) { logDay = CycleDaySelection(date: selected) }
                .buttonStyle(.pill(.soft(.cycleSoft, .cycleOnSoft), fullWidth: false, height: 40))
                // Future days can be looked at, not logged.
                .disabled(selected > today)
                .accessibilityIdentifier("calendarLogButton")
        }
        .lunaCard(padding: 16)
        .padding(.horizontal, 20)
    }

    private func showMonth(_ offset: Int) {
        // Off in UI tests; a plain fade with Reduce Motion.
        let animation: Animation? = LunaMotion.isEnabled ? (reduceMotion ? LunaMotion.fade : .easeInOut(duration: 0.2)) : nil
        withAnimation(animation) {
            month = CycleCalendarGrid.month(offset, from: month, calendar: calendar)
        }
    }
}

/// Ovulation days are not told apart by colour alone (their fill is close to the
/// fertile one: 1.1:1 light, 1.4:1 dark): `DayCircleStyle.ovulation` adds a teal
/// ring (≥ 3:1 on the fill, ContrastTests) and bold numbers, like the legend swatch.
struct CalendarDayCell: View {
    let day: Date
    /// nil when nothing has been logged yet (no forecast).
    let status: CycleDayStatus?
    let log: CycleLogRecord?
    let isToday: Bool
    let isSelected: Bool
    var policy: CycleDisplayPolicy = .conceiving
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            DayCircle(
                number: Formatting.dayNumber(day),
                style: .calendar(status),
                isToday: isToday,
                isSelected: isSelected,
                fontSize: 15
            )
            .overlay(alignment: .bottom) {
                if log != nil {
                    Circle()
                        .fill(.luna(.textPrimary))
                        .frame(width: 4, height: 4)
                        .offset(y: 8)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(CycleAccessibility.dayLabel(day: day, status: status, log: log, isToday: isToday, policy: policy))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("calendarDay")
    }
}

/// Legend under the grid: period, predicted, fertile, ovulation (ringed, as on
/// the grid), logged. Phase 9: named by `policy`; no fertile or ovulation items
/// when the window is hidden.
struct CycleLegend: View {
    var policy: CycleDisplayPolicy = .conceiving

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), alignment: .leading)], alignment: .leading, spacing: 8) {
            item(L10n.calendarLegendPeriod) { Circle().fill(.luna(.cycleStrong)) }
            item(CycleTexts.predictedBleed(policy)) {
                Circle().strokeBorder(.luna(.cycle), style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
            }
            if policy.showsFertileWindow {
                item(CycleTexts.fertileTitle(policy)) {
                    Circle().fill(.luna(.fertileSoft)).overlay(Circle().strokeBorder(.luna(.fertileSoftBorder), lineWidth: 1.5))
                }
            }
            if policy.showsOvulation {
                item(L10n.calendarLegendPeak) {
                    Circle().fill(.luna(.ovulation)).overlay(Circle().strokeBorder(.luna(.teal), lineWidth: 1.5))
                }
            }
            item(L10n.calendarLegendLogged) {
                Circle().fill(.luna(.textPrimary)).frame(width: 5, height: 5)
            }
        }
        .padding(.horizontal, 22)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("calendarLegend")
    }

    private func item<Swatch: View>(_ title: String, @ViewBuilder swatch: () -> Swatch) -> some View {
        HStack(spacing: 6) {
            swatch().frame(width: 12, height: 12)
            Text(title)
                .font(.luna(.small))
                .foregroundStyle(.luna(.textSecondary))
        }
    }
}

/// What VoiceOver reads for a calendar day, e.g.
/// "October 12, fertile window, positive LH test logged".
enum CycleAccessibility {
    /// `status` is already what `policy` shows (`CycleDisplayPolicy.visibleStatus`).
    static func dayLabel(
        day: Date,
        status: CycleDayStatus?,
        log: CycleLogRecord?,
        isToday: Bool,
        policy: CycleDisplayPolicy = .conceiving
    ) -> String {
        var parts = [Formatting.spokenDay(day)]
        if isToday { parts.append(L10n.calendarA11yToday) }
        switch status {
        case .period(isPredicted: false)?: parts.append(L10n.calendarA11yPeriod)
        case .period(isPredicted: true)?:
            parts.append(policy.predictedBleedLabel == .withdrawalBleed ? L10n.cycleWithdrawalBleed : L10n.calendarA11yPredicted)
        case .fertile?:
            parts.append(policy.fertileLabel == .highPregnancyChance ? L10n.cycleHighPregnancyChance : L10n.calendarA11yFertile)
        case .peak?: parts.append(L10n.calendarA11yPeak)
        case .low?, nil: break
        }
        if let log {
            switch log.lh {
            case .positive?: parts.append(L10n.calendarA11yLHPositive)
            case .negative?: parts.append(L10n.calendarA11yLHNegative)
            case nil: break
            }
            if let bbt = log.bbtCelsius { parts.append(L10n.calendarA11yTemperature(Formatting.temperature(bbt))) }
            if let mucus = log.mucus { parts.append(L10n.mucus(mucus)) }
            if !log.note.isEmpty { parts.append(L10n.calendarA11yNote) }
        }
        return parts.joined(separator: ", ")
    }
}
