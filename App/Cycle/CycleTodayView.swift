import KickCore
import SwiftUI

/// The period just started from the ring, which "Undo" may delete.
private struct UndoOffer: Equatable {
    let id: UUID
    let day: Date
    /// About as long as the start toast is on screen; 30 s with VoiceOver,
    /// which needs time to reach the button; 20 s under UI tests, which need
    /// a few seconds to read the screen before tapping Undo.
    let lifetime: Duration

    init(id: UUID, day: Date, voiceOver: Bool) {
        self.id = id
        self.day = day
        lifetime = voiceOver ? .seconds(30) : AppClock.launchOptions.isUITesting ? .seconds(20) : .seconds(6)
    }
}

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
    /// The period just started with the ring button: for a short while the
    /// button offers to undo it (see `UndoOffer`).
    @State private var undoOffer: UndoOffer?
    @State private var toast: String?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
                    CycleWeekStrip(forecast: cycle.forecast, policy: cycle.policy, today: today, log: { cycle.log(on: $0) }) { day in
                        logDay = CycleDaySelection(date: day)
                    }
                    if let forecast = cycle.forecast {
                        content(for: forecast)
                    } else {
                        emptyState
                    }
                }
                .padding(.bottom, 24)
                // Exactly the screen's width: a card that measures even a pixel
                // wider (wrapped text rounds up) would widen the scroll content
                // and let the whole screen pan and bounce sideways.
                .containerRelativeFrame(.horizontal)
            }
            // Content scrolled up stays out from under the status bar.
            .lunaStatusBarBackdrop()
            .background(.luna(.background))
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: CycleHistoryRoute.self) { route in
                switch route {
                case .list: CycleHistoryView()
                case .cycle(let id): CycleDetailView(periodID: id)
                }
            }
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
            // Undo is only offered right after the start: it expires, and goes
            // when she leaves the screen or the app.
            .task(id: undoOffer) {
                guard undoOffer != nil else { return }
                guard let lifetime = undoOffer?.lifetime else { return }
                try? await Task.sleep(for: lifetime)
                guard !Task.isCancelled else { return }
                undoOffer = nil
            }
            .onDisappear { undoOffer = nil }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { undoOffer = nil }
            }
        }
    }

    private func content(for forecast: CycleForecast) -> some View {
        let headline = CycleRingHeadline(forecast: forecast)
        return VStack(spacing: 12) {
            CycleRingView(forecast: forecast, policy: cycle.policy) {
                ringCenter(forecast, headline: headline)
            }
            .padding(.top, 22)
            phasePill(forecast)
            logCard
                .padding(.top, 10)
            notices(forecast)
            ComingUpCard(forecast: forecast, typicalPeriodLength: cycle.settings.typicalPeriodLength, policy: cycle.policy)
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
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    // At accessibility sizes the label sits where the circle's
                    // inner chord is about 157 pt: wrap within it.
                    .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? 150 : nil)
                Text(ringFigure(headline))
                    .font(.luna(.ringNumber))
                    .tracking(-1.5)
                    .foregroundStyle(.luna(.cycleStrong))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                // While late the expected date has passed: "N days late" says it all.
                if let date = ringDate(headline, forecast) {
                    Text(Formatting.shortDay(date))
                        .font(.luna(.body))
                        .foregroundStyle(.luna(.textSecondary))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
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
        return CycleTexts.nextBleedTitle(cycle.policy)
    }

    private func ringFigure(_ headline: CycleRingHeadline) -> String {
        switch headline {
        case .periodDay(let day): L10n.cycleRingDay(day)
        case .daysUntilNextPeriod(let days): L10n.days(days)
        case .nextPeriodToday: L10n.commonToday
        case .late(let days): L10n.cycleRingLate(days)
        }
    }

    private func ringDate(_ headline: CycleRingHeadline, _ forecast: CycleForecast) -> Date? {
        switch headline {
        case .periodDay: forecast.today
        case .late: nil
        case .daysUntilNextPeriod, .nextPeriodToday: forecast.nextPeriodStart
        }
    }

    /// "Day 13 of your cycle, High chance of conceiving, Next period: October 18 (in 16 days)".
    /// While tracking an ordinary day has no status (never "Low chance of conceiving").
    private func statusLabel(_ forecast: CycleForecast) -> String {
        let policy = cycle.policy
        let status = forecast.daysLate > 0
            ? L10n.cycleStatusLate
            : CycleTexts.spokenStatus(forecast.dayStatus(for: forecast.today), policy: policy)
        return [
            L10n.cycleDay(forecast.cycleDay),
            status,
            CycleTexts.nextBleedTitle(policy) + ": " + CycleTexts.nextPeriod(forecast, format: Formatting.spokenDay),
        ].compactMap { $0 }.joined(separator: ", ")
    }

    private func periodButton(_ forecast: CycleForecast) -> some View {
        // A period open for weeks was never ended: offer to start the new one
        // (the coordinator closes the old one); its real end goes in the day log.
        let open = forecast.isLongOpenPeriod ? nil : forecast.openPeriod
        // Only the record created by this button, only on the day it was started.
        let undoable = undoOffer.flatMap { offer in
            offer.day == today ? cycle.periods.first { $0.id == offer.id } : nil
        }
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
            if failure == nil {
                undoOffer = nil
                // The toast is read out by VoiceOver.
                toast = L10n.cycleToastPeriodUndone
            }
        } else if let open {
            failure = await cycle.endPeriod(id: open.id, on: AppClock.now())
            if failure == nil { toast = L10n.cycleToastPeriodEnded }
        } else {
            switch await cycle.startPeriodReturningID(on: AppClock.now()) {
            case .success(let id):
                failure = nil
                undoOffer = UndoOffer(id: id, day: today, voiceOver: voiceOverEnabled)
                toast = L10n.cycleToastPeriodStarted
            case .failure(let error):
                failure = error
            }
        }
        if let failure {
            cycle.clearFailure()
            actionFailure = failure
        }
    }

    // MARK: - Cards

    private func phasePill(_ forecast: CycleForecast) -> some View {
        let policy = cycle.policy
        let status = policy.visibleStatus(forecast.dayStatus(for: forecast.today))
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
        let label = forecast.daysLate > 0
            ? L10n.cyclePhase(forecast.cycleDay, L10n.cycleStatusLate)
            : CycleTexts.phase(day: forecast.cycleDay, status: status, policy: policy)
        return Text(label)
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
                    // One line, cut with "…"; VoiceOver still reads all of it (spec §3.1).
                    Text(CycleTexts.logSummary(cycle.log(on: today)) ?? L10n.cycleLogPrompt)
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.textSecondary))
                        .lineLimit(1)
                        .truncationMode(.tail)
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
