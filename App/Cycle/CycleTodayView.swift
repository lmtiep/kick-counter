import KickCore
import SwiftUI

/// A calendar day picked for the day log sheet.
struct CycleDaySelection: Identifiable {
    let date: Date
    var id: Date { date }
}

/// Trying-to-conceive mode, Today tab (spec §4.2): header, 7-day strip, cycle
/// ring with the period button, phase, "How are you feeling today?", notices,
/// "Coming up" and "Think you might be pregnant?".
struct CycleTodayView: View {
    let onOpenProfile: () -> Void
    let onOpenCalendar: () -> Void

    @Environment(CycleCoordinator.self) private var cycle
    @State private var showingLastPeriodSheet = false
    @State private var logDay: CycleDaySelection?
    @State private var actionFailure: CycleFailure?
    @State private var working = false
    @State private var showingImPregnant = false
    /// The period started with the ring button on this screen: until it is gone
    /// (or the screen is rebuilt) the button offers to undo it.
    @State private var startedPeriodID: UUID?
    @State private var toast: String?

    private var today: Date { Calendar.current.startOfDay(for: AppClock.now()) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ScreenHeader(
                        title: Formatting.shortDay(today),
                        avatarLabel: L10n.profileTitle,
                        trailingSymbol: "calendar",
                        trailingLabel: L10n.tabCalendar,
                        trailingIdentifier: "headerCalendar",
                        onAvatar: onOpenProfile,
                        onTrailing: onOpenCalendar
                    )
                    CycleWeekStrip(forecast: cycle.forecast, today: today, log: { cycle.log(on: $0) }) { day in
                        logDay = CycleDaySelection(date: day)
                    }
                    if let forecast = cycle.forecast {
                        content(for: forecast)
                    } else {
                        emptyState
                    }
                }
                .padding(.bottom, 24)
            }
            .background(.luna(.background))
            .toolbar(.hidden, for: .navigationBar)
            .toast($toast)
            .sheet(isPresented: $showingLastPeriodSheet) { LastPeriodSheet() }
            .sheet(item: $logDay) { selection in
                CycleDayLogSheet(day: selection.date, existing: cycle.log(on: selection.date))
            }
            .sheet(isPresented: $showingImPregnant) {
                ImPregnantSheet(lastPeriodStart: cycle.forecast?.currentPeriodStart)
            }
            .alert(failureMessage ?? "", isPresented: failureBinding) {
                Button(L10n.commonOK) {}
            }
        }
    }

    private func content(for forecast: CycleForecast) -> some View {
        let headline = CycleRingHeadline(forecast: forecast)
        return VStack(spacing: 12) {
            CycleRingView(forecast: forecast) {
                ringCenter(forecast, headline: headline)
            }
            .padding(.top, 22)
            phasePill(forecast)
            logCard
                .padding(.top, 10)
            notices(forecast)
            ComingUpCard(forecast: forecast, typicalPeriodLength: cycle.settings.typicalPeriodLength)
            maybePregnantCard
            footnotes
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Ring

    private func ringCenter(_ forecast: CycleForecast, headline: CycleRingHeadline) -> some View {
        VStack(spacing: 4) {
            VStack(spacing: 4) {
                Text(ringTitle(headline))
                    .lunaLabelStyle()
                    .multilineTextAlignment(.center)
                Text(ringFigure(headline))
                    .font(.luna(.ringNumber))
                    .tracking(-1.5)
                    .foregroundStyle(.luna(.cycleStrong))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                Text(Formatting.shortDay(ringDate(headline, forecast)))
                    .font(.luna(.body))
                    .foregroundStyle(.luna(.textSecondary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(statusLabel(forecast))
            .accessibilityIdentifier("cycleStatusCard")
            periodButton(forecast)
                .padding(.top, 8)
        }
    }

    private func ringTitle(_ headline: CycleRingHeadline) -> String {
        if case .periodDay = headline { return L10n.calendarLegendPeriod }
        return L10n.cycleNextPeriodTitle
    }

    private func ringFigure(_ headline: CycleRingHeadline) -> String {
        switch headline {
        case .periodDay(let day): L10n.cycleRingDay(day)
        case .daysUntilNextPeriod(let days): L10n.days(days)
        case .nextPeriodToday: L10n.commonToday
        case .late(let days): L10n.cycleRingLate(days)
        }
    }

    private func ringDate(_ headline: CycleRingHeadline, _ forecast: CycleForecast) -> Date {
        if case .periodDay = headline { return forecast.today }
        return forecast.nextPeriodStart
    }

    /// "Day 13 of your cycle, High chance of conceiving, Next period: October 18 (in 16 days)".
    private func statusLabel(_ forecast: CycleForecast) -> String {
        let status = forecast.daysLate > 0 ? L10n.cycleStatusLate : L10n.cycleStatus(forecast.dayStatus(for: forecast.today))
        return [
            L10n.cycleDay(forecast.cycleDay),
            status,
            L10n.cycleNextPeriodTitle + ": " + CycleTexts.nextPeriod(forecast, format: Formatting.spokenDay),
        ].joined(separator: ", ")
    }

    private func periodButton(_ forecast: CycleForecast) -> some View {
        // A period open for weeks was never ended: offer to start the new one
        // (the coordinator closes the old one); its real end goes in the day log.
        let open = forecast.isLongOpenPeriod ? nil : forecast.openPeriod
        let undoable = startedPeriodID.flatMap { id in cycle.periods.first { $0.id == id } }
        let title: String
        let spoken: String
        if undoable != nil {
            title = L10n.cycleRingUndo
            spoken = L10n.cycleRingUndoA11y
        } else if open != nil {
            title = L10n.cycleRingEnd
            spoken = L10n.cycleEndPeriod
        } else {
            title = L10n.cycleRingStart
            spoken = L10n.cycleStartPeriod
        }
        return Button(title) {
            Task { await periodAction(open: open, undo: undoable) }
        }
        .buttonStyle(.pill(.filled(.cycleStrong), fullWidth: false, height: 44))
        .disabled(working)
        .accessibilityLabel(spoken)
        .accessibilityIdentifier("cyclePeriodButton")
    }

    private func periodAction(open: PeriodRecord?, undo: PeriodRecord?) async {
        working = true
        defer { working = false }
        let failure: CycleFailure?
        if let undo {
            failure = await cycle.deletePeriod(id: undo.id)
            if failure == nil { startedPeriodID = nil }
        } else if let open {
            failure = await cycle.endPeriod(id: open.id, on: AppClock.now())
            if failure == nil { toast = L10n.cycleToastPeriodEnded }
        } else {
            failure = await cycle.startPeriod(on: AppClock.now())
            if failure == nil {
                startedPeriodID = cycle.period(on: AppClock.now())?.id
                toast = L10n.cycleToastPeriodStarted
            }
        }
        if let failure {
            cycle.clearFailure()
            actionFailure = failure
        }
    }

    // MARK: - Cards

    private func phasePill(_ forecast: CycleForecast) -> some View {
        let status = forecast.dayStatus(for: forecast.today)
        let fill: LunaToken
        let text: LunaToken
        if forecast.daysLate > 0 {
            fill = .warningBackground
            text = .warningText
        } else {
            switch status {
            case .period:
                fill = .cycleSoft
                text = .cycleOnSoft
            case .fertile, .peak:
                fill = .fertileSoft
                text = .tealStrong
            case .low:
                fill = .surfaceAlt
                text = .textPrimary
            }
        }
        let label = forecast.daysLate > 0 ? L10n.cycleStatusLate : CycleTexts.status(status)
        return Text(L10n.cyclePhase(forecast.cycleDay, label))
            .font(.luna(.captionStrong))
            .foregroundStyle(.luna(text))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(.luna(fill)))
            // Read out as part of the ring's status.
            .accessibilityHidden(true)
    }

    private var logCard: some View {
        Button {
            logDay = CycleDaySelection(date: today)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.luna(.cycleOnSoft))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.luna(.cycleSoft)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.cycleLogTitle)
                        .font(.luna(.cardTitleSmall))
                        .foregroundStyle(.luna(.textPrimary))
                    Text(CycleTexts.logSummary(cycle.log(on: today)) ?? L10n.cycleLogPrompt)
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.luna(.chevron))
            }
            .lunaCard(padding: 16)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("cycleLogTodayButton")
    }

    @ViewBuilder
    private func notices(_ forecast: CycleForecast) -> some View {
        if forecast.isLongOpenPeriod {
            CycleNoticeCard(
                title: L10n.cycleLongPeriodTitle(forecast.cycleDay),
                message: L10n.cycleLongPeriodBody,
                style: .soft,
                identifier: "cycleLongPeriodCard"
            )
        }
        if forecast.isNoticeablyLate {
            CycleNoticeCard(
                title: L10n.cycleLateTitle(forecast.daysLate),
                message: L10n.cycleLateBody,
                style: .warning,
                identifier: "cycleLateCard"
            ) {
                Button(L10n.cycleImPregnant) { showingImPregnant = true }
                    .buttonStyle(.pill(.filled(.pregStrong), height: 44))
                    .accessibilityIdentifier("imPregnantButton")
            }
        }
        if forecast.irregularWarning {
            CycleNoticeCard(
                title: L10n.cycleIrregularTitle,
                message: L10n.cycleIrregularBody,
                style: .soft,
                identifier: "cycleIrregularCard"
            )
        }
    }

    private var maybePregnantCard: some View {
        Button {
            showingImPregnant = true
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(.luna(.preg))
                    .frame(width: 44, height: 44)
                    .overlay(Circle().fill(.luna(.card)).frame(width: 16, height: 16))
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.cycleMaybePregnantTitle)
                        .font(.luna(.cardTitleSmall))
                        .foregroundStyle(.luna(.pregOnSoft))
                    Text(L10n.cycleMaybePregnantBody)
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.textPrimary))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.luna(.pregOnSoft))
            }
            .lunaCard(.pregSoft, padding: 16)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("cycleMaybePregnantCard")
    }

    private var footnotes: some View {
        VStack(alignment: .leading, spacing: 8) {
            if cycle.notificationsDenied {
                Text(L10n.cycleNotificationsOff)
            }
            Text(L10n.cycleDisclaimer)
        }
        .font(.luna(.caption))
        .foregroundStyle(.luna(.textSecondary))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "drop.circle")
                    .font(.system(size: 34))
                    .foregroundStyle(.luna(.cycleStrong))
                    .accessibilityHidden(true)
                Text(L10n.cycleEmptyTitle)
                    .font(.luna(.sheetTitle))
                    .foregroundStyle(.luna(.textPrimary))
                Text(L10n.cycleEmptyBody)
                    .font(.luna(.body))
                    .foregroundStyle(.luna(.textSecondary))
                Button(L10n.cycleEmptyAction) { showingLastPeriodSheet = true }
                    .buttonStyle(.pill(.filled(.cycleStrong)))
                    .accessibilityIdentifier("cycleAddPeriodButton")
            }
            .lunaCard()
            maybePregnantCard
            footnotes
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
    }

    // MARK: - Errors

    private var failureMessage: String? {
        (actionFailure ?? cycle.failure).map(L10n.cycleFailure)
    }

    /// Only while no sheet is open: the sheets report their own errors.
    private var failureBinding: Binding<Bool> {
        Binding(
            get: { failureMessage != nil && logDay == nil && !showingLastPeriodSheet && !showingImPregnant },
            set: { if !$0 { actionFailure = nil; cycle.clearFailure() } }
        )
    }
}
