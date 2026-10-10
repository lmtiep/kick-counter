import KickCore
import SwiftUI

/// The contraction timer (phase 20 spec §4.2), pushed from pregnancy Today's
/// "Cơn gò" shortcut (week 28+) or the Kicks tab's "Đếm cơn gò" row: the alert
/// card, the big start/stop button with "Hoàn tác" and "Kết thúc theo dõi", the
/// last hour's numbers, the current episode, the safety line and the history.
struct ContractionTimerView: View {
    /// Today shows the shortcut from this week (spec §4.1).
    static let shortcutFromWeek = 28

    @Environment(ContractionCoordinator.self) private var contractions
    @AppStorage(SettingsKey.dueDate, store: AppGroup.defaults) private var dueDate: Double = 0
    /// Bumped on every tap of the big button that changed something (the haptic).
    @State private var tapFeedback = 0
    /// "Hoàn tác" shows until the coordinator's `undoDeadline` after a tap.
    @State private var showsUndo = false
    @State private var undoToken = 0
    @State private var pendingDelete: ContractionEntry?
    /// "Kết thúc theo dõi" asks first: a mis-tap would split the episode.
    @State private var confirmsEndEpisode = false

    /// The pregnancy week on the app's (pinnable) clock; nil when unknown.
    private var week: GestationalWeek? {
        guard dueDate > 0 else { return nil }
        return PregnancyTimeline(dueDate: Date(timeIntervalSince1970: dueDate), now: AppClock.now())?.week
    }

    var body: some View {
        ScrollView {
            // Re-reads the stats as time passes: the last hour slides, an episode
            // ends after 2 hours. The coordinator's own clock is "now": the
            // timeline's date may be older than a contraction just started.
            TimelineView(.periodic(from: .now, by: 15)) { _ in
                let stats = contractions.stats(week: week)
                content(stats)
                    .onChange(of: stats.alert) { old, new in announceAlert(from: old, to: new) }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            // Exactly the screen's width, as Today: nothing measured wider at
            // large text sizes may widen the content past the screen's edges.
            .containerRelativeFrame(.horizontal)
        }
        .lunaStatusBarBackdrop()
        .lunaBackground()
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(weight: .medium), trigger: tapFeedback)
        // Hidden at the coordinator's deadline, so "Hoàn tác" never shows once
        // the coordinator would refuse it.
        .task(id: undoToken) {
            guard showsUndo else { return }
            if let deadline = contractions.undoDeadline {
                let remaining = deadline.timeIntervalSinceNow
                if remaining > 0 { try? await Task.sleep(for: .seconds(remaining)) }
            }
            guard !Task.isCancelled else { return }
            showsUndo = false
        }
        .confirmationDialog(
            L10n.contractionEndEpisodeConfirm,
            isPresented: $confirmsEndEpisode,
            titleVisibility: .visible
        ) {
            Button(L10n.contractionEndEpisode, role: .destructive) {
                showsUndo = false
                Task { await contractions.endEpisode() }
            }
            Button(L10n.commonCancel, role: .cancel) {}
        } message: {
            Text(L10n.contractionEndEpisodeMessage)
        }
        .confirmationDialog(
            L10n.contractionDeleteConfirm,
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button(L10n.commonDelete, role: .destructive) {
                if let entry = pendingDelete {
                    showsUndo = false
                    Task { await contractions.delete(id: entry.id) }
                }
                pendingDelete = nil
            }
            Button(L10n.commonCancel, role: .cancel) { pendingDelete = nil }
        }
        .alert(failureMessage ?? "", isPresented: Binding(
            get: { contractions.failure != nil },
            set: { if !$0 { contractions.clearFailure() } }
        )) {
            Button(L10n.commonOK) { contractions.clearFailure() }
        }
    }

    private func content(_ stats: ContractionStats) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if stats.alert != .none {
                ContractionAlertCard(alert: stats.alert)
                    .padding(.top, 16)
            }
            ContractionToggleButton(runningSince: stats.running?.startedAt, pulse: tapFeedback) {
                Task { await toggle() }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
            controls(hasEpisode: stats.currentEpisode != nil)
                .padding(.top, 14)
            ContractionStatsCard(summary: stats.lastHour)
                .padding(.top, 20)
            ContractionEpisodeCard(episode: stats.currentEpisode) { pendingDelete = $0 }
                .padding(.top, 12)
            safetyCard
                .padding(.top, 12)
            historyLink
                .padding(.top, 12)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.contractionTitle)
                .font(.luna(.screenTitle))
                .tracking(-0.56)
                .foregroundStyle(.luna(.textPrimary))
                .accessibilityAddTraits(.isHeader)
            Text(L10n.contractionSubtitle)
                .font(.luna(.caption))
                .foregroundStyle(.luna(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    /// "Hoàn tác" for 5 s after a tap, and "Kết thúc theo dõi" while there is an
    /// episode; side by side, stacked when large text does not fit.
    @ViewBuilder
    private func controls(hasEpisode: Bool) -> some View {
        let undo = showsUndo && contractions.lastToggle != nil
        if undo || hasEpisode {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { controlButtons(undo: undo, hasEpisode: hasEpisode, stacked: false) }
                VStack(spacing: 10) { controlButtons(undo: undo, hasEpisode: hasEpisode, stacked: true) }
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    /// `stacked`: one per row, full width, wrapping at the largest text sizes.
    private func controlButtons(undo: Bool, hasEpisode: Bool, stacked: Bool) -> some View {
        if undo {
            Button {
                showsUndo = false
                Task {
                    if await !contractions.undoLast() {
                        AccessibilityNotification.Announcement(L10n.contractionUndoFailed).post()
                    }
                }
            } label: {
                Label(L10n.contractionUndo, systemImage: "arrow.uturn.backward")
                    .lineLimit(stacked ? nil : 1)
                    .fixedSize(horizontal: !stacked, vertical: stacked)
            }
            .buttonStyle(.pill(.light, fullWidth: stacked, height: 44))
            .accessibilityIdentifier("contractionUndo")
        }
        if hasEpisode {
            Button {
                confirmsEndEpisode = true
            } label: {
                Text(L10n.contractionEndEpisode)
                    .lineLimit(stacked ? nil : 1)
                    .fixedSize(horizontal: !stacked, vertical: stacked)
            }
            .buttonStyle(.pill(.dark, fullWidth: stacked, height: 44))
            .accessibilityIdentifier("contractionEndEpisode")
        }
    }

    /// Always shown (spec §4.3).
    private var safetyCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "cross.case.fill")
                .font(.system(size: 18))
                .foregroundStyle(.luna(.warningButton))
                .accessibilityHidden(true)
            Text(L10n.contractionSafety)
                .font(.luna(.captionMedium))
                .lineSpacing(3)
                .foregroundStyle(.luna(.articleText))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .lunaCard(padding: 16)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("contractionSafety")
    }

    private var historyLink: some View {
        NavigationLink {
            ContractionHistoryView()
        } label: {
            HStack(spacing: 12) {
                Text(L10n.contractionHistory)
                    .font(.luna(.bodyStrong))
                    .foregroundStyle(.luna(.textPrimary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.luna(.chevron))
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .lunaCard(padding: 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("contractionHistory")
    }

    /// VoiceOver hears the alert once, when it turns on while the screen is open.
    private func announceAlert(from old: ContractionAlert, to new: ContractionAlert) {
        guard old == .none else { return }
        let text: String? = switch new {
        case .none: nil
        case .fiveOneOne: L10n.contractionAlertFiveOneOne
        case .pretermRegular: L10n.contractionAlertPreterm
        }
        if let text { AccessibilityNotification.Announcement(text).post() }
    }

    private func toggle() async {
        guard await contractions.toggle() != nil else { return }
        tapFeedback += 1
        showsUndo = true
        undoToken += 1
    }

    private var failureMessage: String? {
        switch contractions.failure {
        case .saveFailed: L10n.errorSave
        case .loadFailed: L10n.errorLoad
        case nil: nil
        }
    }
}
