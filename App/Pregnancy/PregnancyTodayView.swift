import KickCore
import KickData
import SwiftData
import SwiftUI

/// Screens pushed from pregnancy Today (phase 5 spec §3.4).
enum PregnancyRoute: Hashable {
    case symptoms
    case weight
    /// The knowledge library, opened on this trimester (phase 7 spec §4.2).
    case knowledge(trimester: Int)
}

/// Pregnancy mode, Today tab (spec §4.4): header, 7-day strip, the fetus
/// (→ week detail), weeks and days with the trimester bar, shortcuts, today's
/// movements, the baby this week, tips, the next check-up and the knowledge
/// suggestions (phase 7).
struct PregnancyTodayView: View {
    let onOpenKicks: () -> Void
    let onOpenProfile: () -> Void

    @Environment(AppointmentCoordinator.self) private var appointments
    @Environment(\.contentLibrary) private var library
    @Environment(\.knowledgeLibrary) private var knowledge
    @AppStorage(SettingsKey.dueDate, store: AppGroup.defaults) private var dueDate: Double = 0
    @AppStorage(SettingsKey.reminderEnabled, store: AppGroup.defaults) private var reminderEnabled = false
    @AppStorage(SettingsKey.reminderHour, store: AppGroup.defaults) private var reminderHour = SettingsDefault.reminderHour
    @AppStorage(SettingsKey.reminderMinute, store: AppGroup.defaults) private var reminderMinute = SettingsDefault.reminderMinute
    @Query(
        filter: #Predicate<KickSession> { $0.statusRaw != "active" },
        sort: \KickSession.startedAt,
        order: .reverse
    )
    private var sessions: [KickSession]
    @State private var showingDateSheet = false
    @State private var detailWeek: WeekSelection?
    @State private var route: PregnancyRoute?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let language = ContentLanguage.current
    private let visibility = BuildFlags.contentVisibility

    private var now: Date { AppClock.now() }

    private var timeline: PregnancyTimeline? {
        dueDate > 0 ? PregnancyTimeline(dueDate: Date(timeIntervalSince1970: dueDate), now: now) : nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ScreenHeader(
                        title: Formatting.shortDay(now),
                        avatarLabel: L10n.profileTitle,
                        trailingSymbol: "calendar",
                        trailingLabel: L10n.pregnancySeeWeek,
                        trailingIdentifier: "headerWeek",
                        onAvatar: onOpenProfile,
                        onTrailing: openCurrentWeek
                    )
                    PregnancyWeekStrip(today: now)
                    content
                }
                .padding(.bottom, 24)
            }
            // Content scrolled up stays out from under the status bar.
            .lunaStatusBarBackdrop()
            .background(.luna(.background))
            .toolbar(.hidden, for: .navigationBar)
            // Slides up over everything (spec §4.5).
            .fullScreenCover(item: $detailWeek) { selection in
                WeekDetailView(currentWeek: selection.week)
            }
            .sheet(isPresented: $showingDateSheet) {
                PregnancyDateSheet()
            }
            .navigationDestination(item: $route) { route in
                switch route {
                case .symptoms: PregnancySymptomsView()
                case .weight: WeightView()
                case .knowledge(let trimester): KnowledgeLibraryView(initialTrimester: trimester)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if dueDate <= 0 {
            datesCard(
                title: L10n.pregnancyEmptyTitle,
                message: L10n.pregnancyEmptyBody,
                action: L10n.pregnancyEmptyAction,
                identifier: "pregnancyAddDateButton",
                prominent: true
            )
        } else if let timeline {
            cards(for: timeline)
        } else {
            datesCard(
                title: L10n.pregnancyInvalidTitle,
                message: L10n.pregnancyInvalidBody,
                action: L10n.pregnancyEditDate,
                identifier: "pregnancyFixDateButton",
                prominent: false
            )
        }
    }

    private func cards(for timeline: PregnancyTimeline) -> some View {
        let contentWeek = WeeklyContentLibrary.clampedWeek(timeline.week.weeks)
        let display = library?.display(forWeek: contentWeek, visibility: visibility)
        return VStack(spacing: 12) {
            FetusHero(week: contentWeek) { detailWeek = WeekSelection(week: contentWeek) }
                .padding(.top, 16)
            WeekProgressCard(progress: PregnancyProgress(timeline: timeline))
            shortcuts(week: timeline.week.weeks, contentWeek: contentWeek)
            if timeline.isKickCountingWeek {
                kicksTodayCard
                    .padding(.top, 12)
            }
            switch display {
            case .content(let week, let pendingReview)?:
                Button { detailWeek = WeekSelection(week: contentWeek) } label: {
                    BabySizeCard(week: week, language: language, pendingReview: pendingReview)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("babySizeCard")

                weightCard(dueDate: timeline.dueDate)

                Button { detailWeek = WeekSelection(week: contentWeek) } label: {
                    WeekTipsCard(tips: Array(week.tips.items(language).prefix(2)))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("weekTipsCard")
            case .underReview?:
                Button { detailWeek = WeekSelection(week: contentWeek) } label: { UnderReviewCard() }
                    .buttonStyle(.plain)
                weightCard(dueDate: timeline.dueDate)
            case nil:
                weightCard(dueDate: timeline.dueDate)
            }
            NavigationLink {
                AppointmentsView()
            } label: {
                NextAppointmentCard(
                    appointment: appointments.nextAppointment,
                    milestone: library?.suggestedMilestones(
                        atWeek: timeline.week.weeks,
                        visibility: visibility,
                        excluding: Set((appointments.upcoming + appointments.past).compactMap(\.milestoneID))
                    ).first,
                    language: language
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("nextAppointmentCard")
            knowledgeCard(for: timeline)
        }
        .padding(.horizontal, 20)
    }

    /// "Suggested for trimester N" (phase 7 spec §4.1); hidden when the library
    /// failed to load or nothing is visible (release builds until reviewed).
    @ViewBuilder
    private func knowledgeCard(for timeline: PregnancyTimeline) -> some View {
        if let knowledge {
            let suggestions = knowledge.suggestions(forWeek: timeline.week.weeks, visibility: visibility)
            if !suggestions.isEmpty {
                KnowledgeCard(
                    trimester: timeline.trimester.rawValue,
                    suggestions: suggestions,
                    topics: knowledge.topics,
                    language: language
                ) { route = .knowledge(trimester: timeline.trimester.rawValue) }
            }
        }
    }

    /// Round shortcuts (phase 5 spec §3.4); two per row at accessibility text
    /// sizes so no label is cut.
    private func shortcuts(week: Int, contentWeek: Int) -> some View {
        let kicks = shortcut(L10n.pregnancyShortcutKicks, identifier: "shortcutKicks", action: onOpenKicks) {
            Circle()
                .fill(.luna(.preg))
                .overlay(
                    Circle()
                        .fill(.luna(.card))
                        .frame(width: 16, height: 16)
                        .padding(6)
                        .background(Circle().fill(Color.luna(.card).opacity(0.3)))
                )
        }
        let symptoms = shortcut(L10n.pregnancyShortcutSymptoms, identifier: "shortcutSymptoms", action: { route = .symptoms }) {
            symbolIcon("plus")
        }
        let weight = shortcut(L10n.pregnancyShortcutWeight, identifier: "shortcutWeight", action: { route = .weight }) {
            symbolIcon("scalemass")
        }
        let weekShortcut = shortcut(L10n.pregnancyShortcutWeek, identifier: "shortcutWeek", action: { detailWeek = WeekSelection(week: contentWeek) }) {
            Circle()
                .fill(.luna(.card))
                .overlay(
                    Text(week, format: .number)
                        .font(.luna(size: 15, weight: .bold))
                        .foregroundStyle(.luna(.textPrimary))
                )
        }
        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                Grid(horizontalSpacing: 8, verticalSpacing: 18) {
                    GridRow { kicks; symptoms }
                    GridRow { weight; weekShortcut }
                }
            } else {
                HStack(alignment: .top, spacing: 8) { kicks; symptoms; weight; weekShortcut }
            }
        }
        .padding(.top, 22)
    }

    /// A white 58 pt circle with a symbol, like the design's "+".
    private func symbolIcon(_ name: String) -> some View {
        Circle()
            .fill(.luna(.card))
            .overlay(
                Image(systemName: name)
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(.luna(.textPrimary))
            )
    }

    private func shortcut<Icon: View>(
        _ title: String,
        identifier: String,
        action: @escaping () -> Void,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                icon().frame(width: 58, height: 58)
                Text(title)
                    .font(.luna(size: 12, weight: .medium, relativeTo: .caption))
                    .foregroundStyle(.luna(.textPrimary))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // An equal share of the row each (the design's 4-column grid).
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    /// "Your weight" (phase 5 spec §3.4), after the baby's size.
    private func weightCard(dueDate: Date) -> some View {
        Button { route = .weight } label: {
            WeightTodayCard(dueDate: dueDate)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("weightCard")
    }

    /// "Movements today" (spec §4.4): today's latest finished count, or a nudge.
    private var kicksTodayCard: some View {
        let states = sessions.map(\.state)
        let latest = HistoryStats.latestCompleted(states, on: now)
        let average = HistoryStats.averageMinutes(states, endingAt: now, days: 7)
        return Button(action: onOpenKicks) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.pregnancyKicksTodayTitle)
                        .lunaLabelStyle(.pregStrong)
                    Text(latest.map { L10n.pregnancyKicksTodayDone($0.count, Formatting.minutes(($0.duration ?? 0) / 60)) }
                        ?? L10n.pregnancyKicksTodayNone)
                        .font(.luna(.cardTitle))
                        .foregroundStyle(.luna(.textPrimary))
                    Text(kicksDetail(latest: latest, average: average))
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.textSecondary))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(latest == nil ? L10n.pregnancyKicksTodayCount : L10n.pregnancyKicksTodayView)
                    .font(.luna(.captionStrong))
                    .foregroundStyle(.luna(.pregOnSoft))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(.luna(.pregSoft)))
            }
            .lunaCard(padding: 16)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("kickCountCard")
    }

    private func kicksDetail(latest: SessionState?, average: Double?) -> String {
        if let latest {
            return L10n.pregnancyKicksTodayDoneDetail(
                Formatting.time(latest.startedAt),
                Formatting.minutes(average ?? (latest.duration ?? 0) / 60)
            )
        }
        if reminderEnabled {
            return L10n.pregnancyKicksTodayReminder(Formatting.clockTime(hour: reminderHour, minute: reminderMinute))
        }
        if let average {
            return L10n.pregnancyKicksTodayAverage(Formatting.minutes(average))
        }
        return L10n.pregnancyKickCardBody
    }

    private func datesCard(title: String, message: String, action: String, identifier: String, prominent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 30))
                .foregroundStyle(.luna(.pregStrong))
                .accessibilityHidden(true)
            Text(title)
                .font(.luna(.sheetTitle))
                .foregroundStyle(.luna(.textPrimary))
            Text(message)
                .font(.luna(.body))
                .foregroundStyle(.luna(.textSecondary))
            Button(action) { showingDateSheet = true }
                .buttonStyle(.pill(prominent ? .filled(.pregStrong) : .dark))
                .accessibilityIdentifier(identifier)
        }
        .lunaCard()
        .padding(.horizontal, 20)
        .padding(.top, 22)
    }

    private func openCurrentWeek() {
        if let timeline {
            detailWeek = WeekSelection(week: WeeklyContentLibrary.clampedWeek(timeline.week.weeks))
        } else {
            showingDateSheet = true
        }
    }
}
