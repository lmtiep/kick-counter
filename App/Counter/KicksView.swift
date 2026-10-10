import KickCore
import KickData
import SwiftData
import SwiftUI

/// Pregnancy mode, Kicks tab (spec §4.6): count to 10 (the first tap starts
/// the session and counts 1, keeping the Live Activity), undo / end, the
/// 2-hour alert, the last 7 days (→ History) and the Cardiff method.
struct KicksView: View {
    @Environment(KickCoordinator.self) private var coordinator
    @AppStorage(SettingsKey.dueDate, store: AppGroup.defaults) private var dueDate: Double = 0
    @AppStorage(SettingsKey.reminderEnabled, store: AppGroup.defaults) private var reminderEnabled = false
    @AppStorage(SettingsKey.reminderHour, store: AppGroup.defaults) private var reminderHour = SettingsDefault.reminderHour
    @AppStorage(SettingsKey.reminderMinute, store: AppGroup.defaults) private var reminderMinute = SettingsDefault.reminderMinute
    @AppStorage(SettingsKey.kickHapticsEnabled, store: AppGroup.defaults) private var hapticsEnabled = true
    @Query(
        filter: #Predicate<KickSession> { $0.statusRaw != "active" },
        sort: \KickSession.startedAt,
        order: .reverse
    )
    private var sessions: [KickSession]
    @State private var confirmingCancel = false
    @State private var showingSettings = false
    /// Kick time chips grow with Dynamic Type so "20:05" never squeezes.
    @ScaledMetric(relativeTo: .caption) private var chipMinWidth: CGFloat = 76
    /// Bumped only when a tap on this screen added a movement: restoring a session
    /// or a count changed elsewhere (Live Activity, widget) never vibrates.
    @State private var tapFeedback = 0

    private var count: Int { coordinator.activeSession?.count ?? 0 }

    private var dialState: KickDialState {
        if coordinator.activeSession != nil { return .running }
        if let completed = coordinator.completedSession {
            return .done(count: completed.count, duration: completed.duration ?? 0)
        }
        return .idle
    }

    private var subtitle: String {
        guard dueDate > 0,
              let timeline = PregnancyTimeline(dueDate: Date(timeIntervalSince1970: dueDate), now: AppClock.now())
        else { return L10n.counterSubtitleNoWeek(SessionRules.targetCount) }
        return L10n.counterSubtitle(timeline.week.weeks, SessionRules.targetCount)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    reminderPill
                        .padding(.top, 12)
                    KickDial(
                        state: dialState,
                        count: count,
                        target: SessionRules.targetCount,
                        startedAt: coordinator.activeSession?.startedAt
                    ) {
                        Task {
                            switch await coordinator.recordKick() {
                            case .added, .completed:
                                if hapticsEnabled { tapFeedback += 1 }
                            case .ignoredDebounce, .ignoredInactive:
                                break
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 18)
                    .padding(.bottom, 8)
                    if let session = coordinator.activeSession {
                        runningControls(session)
                    }
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        if coordinator.isOverdue(at: context.date) {
                            OverdueCard()
                                .padding(.top, 16)
                        }
                    }
                    lastSevenDays
                        .padding(.top, 16)
                    contractionsLink
                        .padding(.top, 12)
                    cardiffCard
                        .padding(.top, 12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            // Content scrolled up stays out from under the status bar.
            .lunaStatusBarBackdrop()
            .lunaBackground()
            .toolbar(.hidden, for: .navigationBar)
            // A light tap for every counted movement, when turned on (spec §4.6).
            .sensoryFeedback(.impact(weight: .light), trigger: tapFeedback)
            .confirmationDialog(L10n.counterCancelConfirmTitle, isPresented: $confirmingCancel, titleVisibility: .visible) {
                Button(L10n.counterCancel, role: .destructive) {
                    Task { await coordinator.cancelSession() }
                }
                Button(L10n.counterKeepCounting, role: .cancel) {}
            } message: {
                Text(L10n.counterCancelConfirmMessage)
            }
            .sheet(isPresented: completionBinding) {
                if let session = coordinator.completedSession {
                    CompletionView(session: session) { coordinator.dismissCompletion() }
                        .lunaSheetPresentation(detents: [.medium, .large])
                }
            }
            .sheet(isPresented: $showingSettings) {
                KickSettingsSheet()
                    .lunaSheetPresentation(detents: [.medium, .large])
            }
            .alert(failureMessage ?? "", isPresented: failureBinding) {
                Button(L10n.commonOK) { coordinator.clearFailure() }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.counterTitle)
                    .font(.luna(.screenTitle))
                    .tracking(-0.56)
                    .foregroundStyle(.luna(.textPrimary))
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(.luna(.caption))
                    .foregroundStyle(.luna(.textSecondary))
                    .accessibilityIdentifier("counterSubtitle")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(L10n.counterSettings) { showingSettings = true }
                .buttonStyle(.pill(.light, fullWidth: false, height: 36))
                .padding(.top, 6)
                .accessibilityIdentifier("kickSettingsButton")
        }
        .padding(.top, 10)
    }

    private var reminderPill: some View {
        Button {
            showingSettings = true
        } label: {
            Text(reminderEnabled
                 ? L10n.counterReminderPill(Formatting.clockTime(hour: reminderHour, minute: reminderMinute))
                 : L10n.counterReminderOff)
                .font(.luna(.label))
                .foregroundStyle(.luna(.articleText))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(.luna(.surfaceAlt)))
                .frame(minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("kickReminderPill")
    }

    private func runningControls(_ session: SessionState) -> some View {
        VStack(spacing: 14) {
            Text(L10n.counterTapHint)
                .font(.luna(.caption))
                .foregroundStyle(.luna(.textSecondary))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            // Side by side; stacked when large text doesn't fit (spec §5).
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { sessionButtons(session) }
                VStack(spacing: 10) { sessionButtons(session) }
            }
            if !session.kicks.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: chipMinWidth), spacing: 6)], spacing: 6) {
                    ForEach(Array(session.kicks.enumerated()), id: \.offset) { _, time in
                        Text(Formatting.time(time))
                            .font(.luna(.small))
                            .lineLimit(1)
                            .fixedSize()
                            .monospacedDigit()
                            .foregroundStyle(.luna(.articleText))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(.luna(.surfaceAlt)))
                    }
                }
                .padding(.horizontal, 10)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("kickTimes")
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func sessionButtons(_ session: SessionState) -> some View {
        Button { Task { await coordinator.undo() } } label: {
            Text(L10n.counterUndo).lineLimit(1).fixedSize(horizontal: true, vertical: false)
        }
            .buttonStyle(.pill(.light, fullWidth: false, height: 44))
            .disabled(session.count == 0)
            .accessibilityIdentifier("undoButton")
        Button { confirmingCancel = true } label: {
            Text(L10n.counterCancel).lineLimit(1).fixedSize(horizontal: true, vertical: false)
        }
            .buttonStyle(.pill(.dark, fullWidth: false, height: 44))
            .accessibilityIdentifier("cancelSessionButton")
    }

    /// The last 7 days in small bars; the whole card opens History (spec §2.3).
    private var lastSevenDays: some View {
        let bars = HistoryStats.daily(sessions.map(\.state), endingAt: AppClock.now())
        return NavigationLink {
            HistoryView()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(L10n.kicksLastSevenDays)
                        .font(.luna(.cardTitleSmall))
                        .foregroundStyle(.luna(.textPrimary))
                    Spacer()
                    Text(L10n.historyTitle + " ›")
                        .font(.luna(.captionStrong))
                        .foregroundStyle(.luna(.pregText))
                }
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(bars) { bar in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(barColor(bar))
                                .frame(maxWidth: 26)
                                .frame(height: bar.minutes.map { max(6, HistoryStats.barFraction(minutes: $0) * 44) } ?? 4)
                            Text(bar.isCurrent ? L10n.historyToday : WeekdayLabel.short(for: bar.start, calendar: AppLocale.calendar))
                                .font(.luna(size: 10, weight: .regular, relativeTo: .caption2))
                                .foregroundStyle(.luna(.textSecondary))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(minHeight: 64, alignment: .bottom)
                .accessibilityHidden(true)
            }
            .lunaCard(padding: 16)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("kicksHistoryButton")
    }

    /// "Đếm cơn gò" (phase 20 spec §4.1): the contraction timer, in any week.
    private var contractionsLink: some View {
        NavigationLink {
            ContractionTimerView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "stopwatch")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(.luna(.pregOnSoft))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.luna(.pregSoft)))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.kicksContractionsLink)
                        .font(.luna(.cardTitleSmall))
                        .foregroundStyle(.luna(.textPrimary))
                    Text(L10n.kicksContractionsLinkDetail)
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.luna(.chevron))
                    .accessibilityHidden(true)
            }
            .lunaCard(padding: 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("kicksContractionsLink")
    }

    private func barColor(_ bar: HistoryBar) -> Color {
        guard bar.minutes != nil else { return .luna(.track) }
        return bar.isCurrent ? .luna(.pregStrong) : .luna(.pregBar)
    }

    private var cardiffCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.kicksCardiffTitle)
                .font(.luna(.bodyStrong))
                .foregroundStyle(.luna(.textPrimary))
            Text(L10n.kicksCardiffBody)
                .font(.luna(.caption))
                .lineSpacing(3)
                .foregroundStyle(.luna(.articleText))
                .fixedSize(horizontal: false, vertical: true)
        }
        .lunaCard(.surface, padding: 16)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("kicksCardiffCard")
    }

    private var completionBinding: Binding<Bool> {
        Binding(
            get: { coordinator.completedSession != nil },
            set: { if !$0 { coordinator.dismissCompletion() } }
        )
    }

    private var failureMessage: String? {
        switch coordinator.failure {
        case .saveFailed: L10n.errorSave
        case .loadFailed: L10n.errorLoad
        case nil: nil
        }
    }

    private var failureBinding: Binding<Bool> {
        Binding(
            get: { coordinator.failure != nil },
            set: { if !$0 { coordinator.clearFailure() } }
        )
    }
}

/// The 2-hour alert (spec §4.6): the phase 1 text in the warning colours. In
/// Vietnamese it offers the emergency number 115; English has no single number,
/// so only the text (the push notification at 2 hours stays as it was).
struct OverdueCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.overdueTitle)
                    .font(.luna(.cardTitleSmall))
                    .foregroundStyle(.luna(.warningText))
                Text(L10n.overdueBody)
                    .font(.luna(.caption))
                    .lineSpacing(3)
                    .foregroundStyle(.luna(.articleText))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("overdueCard")
            EmergencyCallButton(identifier: "overdueCallButton")
        }
        .lunaCard(.warningBackground, border: .warningBorder, padding: 16)
    }
}
