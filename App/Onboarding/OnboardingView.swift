import KickCore
import SwiftUI

/// Phase 9 onboarding (spec §4.1): welcome with the language, the medical note
/// and the privacy note → the goal (track my cycle, trying to conceive,
/// pregnant) → that branch's questions → the result with the reminder opt-in.
/// `OnboardingFlow` (KickCore) holds the answers and the step order; every
/// question can be skipped ("Skip" / "Not sure") and has a back button.
///
/// `replay` (Profile → "Replay the introduction") starts from the current mode,
/// goal, lengths, period and due date, and finishing only closes it: no mode,
/// settings, period, answers or pregnancy dates are saved. The language choice
/// still applies, as a view preference.
///
/// Phase 18: the owner's handoff (`docs/design/handoff-2026-10-09`, README §1):
/// light only, cream background, the illustration whole at the top with the
/// wave band, the text at the bottom and the terracotta button.
struct OnboardingView: View {
    /// Captured once, when the view first appears: RootView recomputes the
    /// `replay` argument while the cover is being dismissed, and a second tap
    /// then must not fall through to the saving path.
    @State private var isReplay: Bool
    let onFinish: () -> Void

    @Environment(CycleCoordinator.self) private var cycle
    @Environment(KickCoordinator.self) private var kicks
    @Environment(BackupCenter.self) private var backup
    /// "Khôi phục từ bản sao lưu" (phase 15): a new phone is when a backup is needed.
    @State private var importingBackup = false
    @AppStorage(SettingsKey.appLanguage, store: AppGroup.defaults)
    private var appLanguage = AppLanguage.system.rawValue
    @State private var flow: OnboardingFlow
    /// The due date step's value; copied into `flow` by "Continue".
    @State private var dateSelection: PregnancyDateSelection
    @State private var showingOtherDay = false
    @State private var showingDuePicker = false
    @State private var showingLMPForm = false
    @State private var saving = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The welcome lines' round icons and the goal cards' icons grow with the text.
    @ScaledMetric(relativeTo: .footnote) private var commitmentIcon: CGFloat = 24
    @ScaledMetric(relativeTo: .footnote) private var lockSize: CGFloat = 11
    @ScaledMetric(relativeTo: .headline) private var goalIcon: CGFloat = 36
    private let now: Date

    init(replay: Bool = false, onFinish: @escaping () -> Void) {
        _isReplay = State(initialValue: replay)
        self.onFinish = onFinish
        let now = AppClock.now()
        self.now = now
        let defaults = AppGroup.defaults
        let preferences = CyclePreferences.load(from: defaults)
        let dates = PregnancyDateInput.initialSelection(for: PregnancyProfile.load(from: defaults), now: now)
        _dateSelection = State(initialValue: dates)
        _flow = State(initialValue: OnboardingFlow(
            goal: replay ? OnboardingGoal(mode: AppMode.load(from: defaults), cycleGoal: preferences.goal) : nil,
            lastPeriodStart: AppLocale.calendar.startOfDay(for: now),
            settings: CycleSettings.load(from: defaults),
            regularity: preferences.regularity,
            contraception: preferences.contraception,
            pregnancyDates: dates
        ))
    }

    private var dueDate: Date {
        dateSelection.source == .dueDate ? dateSelection.date : PregnancyDates.dueDate(fromLMP: dateSelection.date)
    }

    private var isPregnancyBranch: Bool { flow.goal == .pregnant }

    private var hero: OnboardingHeroKind {
        switch flow.step {
        case .welcome: .welcome
        case .goal: .goal
        case .dueDate: .dueDate
        case .result: isPregnancyBranch ? .dueDate : cycleHero
        case .lastPeriod, .periodLength, .cycleLength, .regularity, .contraception: cycleHero
        }
    }

    /// The cycle branch's picture follows the chosen goal (trying to conceive or tracking).
    private var cycleHero: OnboardingHeroKind {
        switch flow.goal {
        case .some(.conceiving): .cycleConceiving
        default: .cycleTracking
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            OnboardingPalette.background.ignoresSafeArea()
            GeometryReader { proxy in
                OnboardingHero(kind: hero)
                    .frame(width: proxy.size.width, height: proxy.size.height * hero.heightFraction)
                    .offset(y: hero.top)
            }
            // A new id runs the entrance animations again for every picture.
            .id(hero)
            VStack(spacing: 0) {
                topBar
                GeometryReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            stepContent
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, flow.step == .welcome ? 20 : 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        // Tied to the content's top edge, so text never sits on the picture
                        // at any Dynamic Type size or screen height.
                        .background(alignment: .top) { ContentScrim() }
                        .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .bottomLeading)
                        .lunaEntrance(.contentUp)
                        .id(flow.step)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .defaultScrollAnchor(.bottom)
                }
                buttons
                    .padding(.horizontal, 24)
            }
            .padding(.bottom, 4)
        }
        .environment(\.locale, AppLocale.locale)
        .onboardingLight()
        .interactiveDismissDisabled()
        .onAppear(perform: startFromCurrentValues)
        .sheet(isPresented: $showingOtherDay) { otherDaySheet }
        .sheet(isPresented: $showingDuePicker) { duePickerSheet }
        .sheet(isPresented: $showingLMPForm) { lmpFormSheet }
    }

    private var animates: Bool { LunaMotion.isEnabled && !reduceMotion }

    // MARK: - Top bar

    /// Handoff README §1: the progress pill with the VI / EN segment on step 1;
    /// from step 2 on, back on the left, the dots in the middle, Skip on the right.
    private var topBar: some View {
        HStack(spacing: 8) {
            if flow.canGoBack {
                TopBarLayout {
                    backButton
                    progressDots
                    skipButton
                }
            } else {
                progressDots
                Spacer(minLength: 8)
                languageSegment
            }
        }
        .frame(minHeight: 44)
        .padding(.top, 6)
        .padding(.horizontal, 24)
        // Phase 9 final fix: past AX2 the Skip pill truncated to "Không…". The bar's
        // controls are short labels and decorative dots, so they stop growing at AX2
        // (as system bars do); the question text below keeps the full size.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private var backButton: some View {
        Button { change { $0.back() } } label: {
            Image(systemName: "chevron.backward")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(OnboardingPalette.ink)
                .frame(width: 40, height: 40)
                .background(Circle().fill(OnboardingPalette.pill))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.onboardingBack)
        .accessibilityIdentifier("onboardingBack")
    }

    @ViewBuilder
    private var skipButton: some View {
        if flow.isQuestion {
            Button(skipTitle) { change { $0.skip() } }
                .font(.luna(.captionMedium))
                // One line at every text size. The bar is capped at AX2 (above); the
                // scale factor stays as a safety net for narrow (375 pt) phones, where
                // it shrinks the label a little rather than truncating it.
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(OnboardingPalette.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .background(Capsule().fill(OnboardingPalette.pill))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityIdentifier("onboardingSkip")
        } else {
            // Keeps TopBarLayout's three slots on the result step.
            Color.clear.frame(width: 0, height: 0)
        }
    }

    /// "Not sure" where the answer is a number or a pattern, "Skip" elsewhere.
    private var skipTitle: String {
        switch flow.step {
        case .periodLength, .cycleLength, .regularity: L10n.onboardingNotSure
        default: L10n.onboardingSkip
        }
    }

    private var progressDots: some View {
        HStack(spacing: 5) {
            ForEach(Array(flow.steps.enumerated()), id: \.offset) { index, _ in
                let isCurrent = index + 1 == flow.stepNumber
                Capsule()
                    .fill(isCurrent ? OnboardingPalette.accent : OnboardingPalette.dot)
                    .frame(width: isCurrent ? 20 : 6, height: 6)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Capsule().fill(OnboardingPalette.pill))
        .animation(animates ? LunaMotion.dots : nil, value: flow.step)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.onboardingStep(flow.stepNumber, flow.stepCount))
        .accessibilityIdentifier("onboardingProgress")
    }

    /// VI / EN (12/600, the chosen one on `accent`); VoiceOver reads the
    /// language's name.
    private var languageSegment: some View {
        HStack(spacing: 0) {
            languageButton(.vi, short: "VI", name: L10n.languageVietnamese, identifier: "onboardingLanguageVi")
            languageButton(.en, short: "EN", name: L10n.languageEnglish, identifier: "onboardingLanguageEn")
        }
        .padding(3)
        .background(Capsule().fill(OnboardingPalette.pill))
        .frame(minHeight: 44)
    }

    private func languageButton(_ language: ContentLanguage, short: String, name: String, identifier: String) -> some View {
        let isSelected = AppLocale.language == language
        return Button {
            appLanguage = language.rawValue
        } label: {
            Text(verbatim: short)
                .font(.luna(size: 12, weight: .semibold, relativeTo: .caption))
                .foregroundStyle(isSelected ? Color.white : OnboardingPalette.ink)
                .padding(.vertical, 6)
                .padding(.horizontal, 11)
                .background(Capsule().fill(isSelected ? OnboardingPalette.accent : Color.clear))
                // A 44 pt tall touch area around the 28 pt pill.
                .contentShape(Rectangle().inset(by: -8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Steps

    @ViewBuilder
    private var stepContent: some View {
        switch flow.step {
        case .welcome: welcomeStep
        case .goal: goalStep
        case .lastPeriod: lastPeriodStep
        case .periodLength: periodLengthStep
        case .cycleLength: cycleLengthStep
        case .regularity: regularityStep
        case .contraception: contraceptionStep
        case .dueDate: dueDateStep
        case .result: resultStep
        }
    }

    /// 32/400 on the welcome step, 26/400 on the others; tracking −0.02 em,
    /// lines balanced (`text-wrap: balance`).
    private func title(_ text: String, size: CGFloat = 26, identifier: String? = nil) -> some View {
        BalancedText {
            Text(text)
                .font(.luna(size: size, weight: .regular, relativeTo: .largeTitle))
                .tracking(-0.02 * size)
                .foregroundStyle(OnboardingPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .optionalAccessibilityIdentifier(identifier)
        }
    }

    private func note(_ text: String, identifier: String) -> some View {
        Text(text)
            .font(.luna(.caption))
            .lineSpacing(2)
            .foregroundStyle(OnboardingPalette.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(identifier)
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            title(L10n.onboardingWelcomeTitle, size: 32, identifier: "onboardingWelcomeTitle")
            Text(L10n.onboardingWelcomeBody)
                .font(.luna(size: 15, weight: .regular, relativeTo: .body))
                .lineSpacing(3)
                .foregroundStyle(OnboardingPalette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 8) {
                // Always on the first step, never skipped.
                commitment(L10n.onboardingPrivacy, identifier: "onboardingPrivacyNote") {
                    Image(systemName: "lock")
                        .font(.system(size: lockSize, weight: .semibold))
                        .foregroundStyle(OnboardingPalette.privacyIcon)
                } background: { OnboardingPalette.privacyIconBackground }
                commitment(L10n.onboardingMedical, identifier: "onboardingMedicalNote") {
                    Text(verbatim: "!")
                        .font(.luna(size: 12, weight: .bold, relativeTo: .footnote))
                        .foregroundStyle(OnboardingPalette.accent)
                } background: { OnboardingPalette.warmSoft }
            }
            .padding(.top, 2)
        }
    }

    /// A privacy or medical line: a 24 pt round icon and 13/1.4 text.
    private func commitment(
        _ text: String,
        identifier: String,
        @ViewBuilder icon: () -> some View,
        background: () -> Color
    ) -> some View {
        HStack(spacing: 10) {
            icon()
                .frame(width: commitmentIcon, height: commitmentIcon)
                .background(Circle().fill(background()))
                .accessibilityHidden(true)
            Text(text)
                .font(.luna(.caption))
                .lineSpacing(2)
                .foregroundStyle(OnboardingPalette.commitment)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier(identifier)
        }
    }

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            title(L10n.onboardingModeTitle)
                .padding(.bottom, 2)
            goalCard(.tracking, title: L10n.onboardingGoalTracking, detail: L10n.onboardingGoalTrackingDetail)
            goalCard(.conceiving, title: L10n.onboardingGoalConceiving, detail: L10n.onboardingGoalConceivingDetail)
            goalCard(.pregnant, title: L10n.onboardingGoalPregnant, detail: L10n.onboardingGoalPregnantDetail)
        }
    }

    private func goalCard(_ goal: OnboardingGoal, title: String, detail: String) -> some View {
        choiceCard(
            title: title,
            detail: detail,
            colors: OnboardingPalette.goal(goal),
            showsIcon: true,
            isSelected: flow.goal == goal,
            identifier: "onboardingGoal-\(goal.rawValue)"
        ) { flow.goal = goal }
    }

    /// A large tappable card with a radio (handoff README §1, "Màn 2"): the goal,
    /// regularity and contraception choices. Unselected: white at 60 %, no
    /// border; selected: white with a 1.5 pt border and a 7 pt radio ring in
    /// the card's colour (`accent` outside the goal step).
    private func choiceCard(
        title: String,
        detail: String? = nil,
        colors: (main: Color, soft: Color) = (OnboardingPalette.accent, OnboardingPalette.warmSoft),
        showsIcon: Bool = false,
        isSelected: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if showsIcon {
                    Circle().fill(colors.main).frame(width: 12, height: 12)
                        .frame(width: goalIcon, height: goalIcon)
                        .background(Circle().fill(colors.soft))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.luna(size: 16, weight: .medium, relativeTo: .headline))
                        .foregroundStyle(OnboardingPalette.ink)
                    if let detail {
                        Text(detail)
                            .font(.luna(.caption))
                            .lineSpacing(2)
                            .foregroundStyle(OnboardingPalette.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                Circle()
                    .strokeBorder(isSelected ? colors.main : OnboardingPalette.radio, lineWidth: isSelected ? 7 : 1.5)
                    .frame(width: 22, height: 22)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, detail == nil ? 12 : 9)
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(
                isSelected ? OnboardingPalette.card : OnboardingPalette.cardUnselected,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? colors.main : Color.clear, lineWidth: 1.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .animation(animates ? .easeOut(duration: 0.25) : nil, value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }

    private var lastPeriodStep: some View {
        let calendar = AppLocale.calendar
        let days = RecentDaysGrid.days(endingAt: now, calendar: calendar)
        let isOtherDay = flow.lastPeriodStart.map { start in
            !days.contains { calendar.isDate($0.date, inSameDayAs: start) }
        } ?? false
        return VStack(alignment: .leading, spacing: 12) {
            title(L10n.cycleEmptyTitle)
            VStack(spacing: 8) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: RecentDaysGrid.columns), spacing: 4) {
                    ForEach(days) { day in
                        dayChip(day, calendar: calendar)
                    }
                }
                Button {
                    showingOtherDay = true
                } label: {
                    Text(isOtherDay ? L10n.onboardingOtherDayValue(Formatting.shortDay(flow.lastPeriodStart ?? now)) : L10n.onboardingOtherDay)
                        .font(.luna(size: 15, weight: .medium, relativeTo: .body))
                        .foregroundStyle(isOtherDay ? OnboardingPalette.onAccent : OnboardingPalette.ink)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Capsule().fill(isOtherDay ? OnboardingPalette.accent : OnboardingPalette.soft))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOtherDay ? .isSelected : [])
                .accessibilityIdentifier("onboardingOtherDay")
            }
            .onboardingCard(padding: 10)
            Button(L10n.onboardingDontRemember) {
                change {
                    $0.lastPeriodStart = nil
                    $0.next()
                }
            }
            .buttonStyle(.onboarding(.text))
            .accessibilityIdentifier("onboardingDontRemember")
        }
    }

    private func dayChip(_ day: RecentDay, calendar: Calendar) -> some View {
        let isSelected = flow.lastPeriodStart.map { calendar.isDate(day.date, inSameDayAs: $0) } ?? false
        return Button {
            flow.lastPeriodStart = day.date
        } label: {
            VStack(spacing: 2) {
                Text(WeekdayLabel.short(for: day.date, calendar: calendar))
                    .font(.luna(size: 10, weight: .medium, relativeTo: .caption2))
                Text(Formatting.dayNumber(day.date))
                    .font(.luna(size: 15, weight: .medium))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(isSelected ? OnboardingPalette.onAccent : OnboardingPalette.ink)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? OnboardingPalette.accent : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Formatting.spokenDay(day.date) + (day.isToday ? ", " + L10n.calendarA11yToday : ""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("onboardingDay")
    }

    private var periodLengthStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            title(L10n.onboardingPeriodLengthTitle)
            daysWheel(L10n.onboardingPeriodLengthTitle, value: $flow.periodLength, range: CycleSettings.periodLengthRange)
                .accessibilityIdentifier("onboardingPeriodLengthPicker")
        }
    }

    private var cycleLengthStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            title(L10n.onboardingCycleLengthTitle)
            note(L10n.onboardingCycleLengthHint, identifier: "onboardingCycleLengthHint")
            daysWheel(L10n.onboardingCycleLengthTitle, value: $flow.cycleLength, range: CycleSettings.cycleLengthRange)
                .accessibilityIdentifier("onboardingCycleLengthPicker")
        }
    }

    private func daysWheel(_ label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        Picker(label, selection: value) {
            ForEach(Array(range), id: \.self) { days in
                Text(L10n.days(days)).tag(days)
            }
        }
        .pickerStyle(.wheel)
        .frame(maxWidth: .infinity)
        .onboardingCard(padding: 4)
    }

    private var regularityStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            title(L10n.onboardingRegularityTitle)
                .padding(.bottom, 2)
            ForEach(CycleRegularity.allCases, id: \.self) { value in
                choiceCard(
                    title: L10n.onboardingRegularity(value),
                    detail: L10n.onboardingRegularityDetail(value),
                    isSelected: flow.regularity == value,
                    identifier: "onboardingRegularity-\(value.rawValue)"
                ) { change { $0.regularity = value } }
            }
            if flow.regularity == .irregular {
                note(L10n.onboardingIrregularNote, identifier: "onboardingIrregularNote")
                    .padding(.top, 2)
                    .transition(.opacity)
            }
        }
    }

    private var contraceptionStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            title(L10n.onboardingContraceptionTitle)
            note(L10n.onboardingContraceptionWhy, identifier: "onboardingContraceptionWhy")
                .padding(.bottom, 4)
            ForEach(Contraception.allCases, id: \.self) { value in
                choiceCard(
                    title: L10n.contraception(value),
                    isSelected: flow.contraception == value,
                    identifier: "onboardingContraception-\(value.rawValue)"
                ) { flow.contraception = value }
            }
        }
    }

    private var dueDateStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            title(L10n.onboardingDueTitle)
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    roundButton("minus", label: L10n.onboardingDueEarlier, identifier: "onboardingDueEarlier") { shiftDueDate(by: -7) }
                        .disabled(shiftedDueDate(by: -7) == nil)
                    Button {
                        showingDuePicker = true
                    } label: {
                        Text(Formatting.dayMonthYear(dueDate))
                            .font(.luna(size: 22, weight: .medium, relativeTo: .title2))
                            .foregroundStyle(OnboardingPalette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(minWidth: 150, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.pregnancyDateSourceDueDate)
                    .accessibilityValue(Formatting.longDate(dueDate))
                    .accessibilityIdentifier("onboardingDueDate")
                    roundButton("plus", label: L10n.onboardingDueLater, identifier: "onboardingDueLater") { shiftDueDate(by: 7) }
                        .disabled(shiftedDueDate(by: 7) == nil)
                }
                Text(weekLabel(dueDate))
                    .font(.luna(.captionStrong))
                    .foregroundStyle(OnboardingPalette.link)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(OnboardingPalette.warmSoft))
                    .accessibilityIdentifier("onboardingDueWeeks")
            }
            .frame(maxWidth: .infinity)
            .onboardingCard(padding: 16)
            Button(L10n.onboardingDueFromLMP) { showingLMPForm = true }
                .buttonStyle(.onboarding(.text))
                .accessibilityIdentifier("onboardingFromLMP")
        }
    }

    private func weekLabel(_ dueDate: Date) -> String {
        PregnancyTimeline(dueDate: dueDate, now: now).map { L10n.pregnancyWeekLabel($0.week) } ?? ""
    }

    private var resultStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            title(L10n.onboardingResultTitle)
            Text(resultText)
                .font(.luna(size: 18, weight: .medium, relativeTo: .title3))
                .foregroundStyle(OnboardingPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("onboardingResultText")
                .frame(maxWidth: .infinity, alignment: .leading)
                .onboardingCard(padding: 16)
            note(L10n.onboardingResultReminders, identifier: "onboardingResultReminders")
        }
    }

    /// The early payoff: the predicted next period (cycle) or today's week (pregnancy).
    private var resultText: String {
        if isPregnancyBranch {
            guard let dates = flow.pregnancyDates else { return L10n.onboardingResultNoDueDate }
            let due = dates.source == .dueDate ? dates.date : PregnancyDates.dueDate(fromLMP: dates.date)
            return L10n.onboardingResultPregnant(weekLabel(due))
        }
        switch flow.prediction(now: now, calendar: AppLocale.calendar) {
        case .nextPeriod(let date)?: return L10n.onboardingResultNextPeriod(Formatting.longDate(date))
        case .late(let days)?: return L10n.onboardingResultLate(days)
        case nil: return L10n.onboardingResultNoPeriod
        }
    }

    private func roundButton(_ symbol: String, label: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(OnboardingPalette.ink)
                .frame(width: 42, height: 42)
                .background(Circle().fill(OnboardingPalette.soft))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Buttons

    private var buttons: some View {
        VStack(spacing: 2) {
            switch flow.step {
            case .result:
                Button(L10n.onboardingEnableReminders) { startFinishing(requestingNotifications: true) }
                    .buttonStyle(.onboarding())
                    .disabled(saving)
                    .accessibilityIdentifier("onboardingEnableReminders")
                Button(L10n.onboardingLater) { startFinishing(requestingNotifications: false) }
                    .buttonStyle(.onboarding(.text))
                    .disabled(saving)
                    .accessibilityIdentifier("onboardingFinishLater")
            case .welcome:
                Button(L10n.onboardingStart) { continueTapped() }
                    .buttonStyle(.onboarding())
                    .accessibilityIdentifier("onboardingNext")
                    .lunaEntrance(.buttonUp)
                // Restoring replaces everything, so a replay from Profile does not offer it.
                if !isReplay {
                    restoreLink
                        .lunaEntrance(.linkUp)
                }
            default:
                Button(L10n.onboardingContinue) { continueTapped() }
                    .buttonStyle(.onboarding())
                    .disabled(!flow.canContinue)
                    .accessibilityIdentifier("onboardingNext")
                    .lunaEntrance(.buttonUp)
            }
        }
    }

    /// "Khôi phục từ bản sao lưu" (phase 15): 13/500 `link`, centred under the button.
    private var restoreLink: some View {
        Button {
            importingBackup = true
        } label: {
            Text(L10n.onboardingRestore)
                .font(.luna(.captionMedium))
                .foregroundStyle(OnboardingPalette.link)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("onboardingRestore")
        .fileImporter(isPresented: $importingBackup, allowedContentTypes: [.lunaMomBackup, .json]) { result in
            if case .success(let url) = result { backup.open(url) }
        }
    }

    // MARK: - Sheets

    private var otherDaySheet: some View {
        NavigationStack {
            Form {
                LastPeriodPicker(date: Binding(
                    get: { flow.lastPeriodStart ?? AppLocale.calendar.startOfDay(for: now) },
                    set: { flow.lastPeriodStart = $0 }
                ), now: now)
            }
            .scrollContentBackground(.hidden)
            .background(OnboardingPalette.background)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.completionDone) { showingOtherDay = false }
                        .accessibilityIdentifier("onboardingOtherDayDone")
                }
            }
        }
        .lunaSheetPresentation(detents: [.medium, .large])
        .environment(\.locale, AppLocale.locale)
        .onboardingLight()
    }

    private var duePickerSheet: some View {
        NavigationStack {
            DatePicker(
                L10n.pregnancyDateSourceDueDate,
                selection: Binding(
                    get: { dueDate },
                    set: { dateSelection = PregnancyDateSelection(source: .dueDate, date: $0) }
                ),
                in: PregnancyDateInput.range(for: .dueDate, now: now),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(OnboardingPalette.accent)
            .padding(.horizontal)
            .accessibilityIdentifier("onboardingDuePicker")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.completionDone) { showingDuePicker = false }
                        .accessibilityIdentifier("onboardingDuePickerDone")
                }
            }
        }
        .lunaSheetPresentation(detents: [.medium, .large])
        .environment(\.locale, AppLocale.locale)
        .onboardingLight()
    }

    private var lmpFormSheet: some View {
        NavigationStack {
            Form {
                PregnancyDateForm(source: $dateSelection.source, date: $dateSelection.date, now: now)
            }
            .scrollContentBackground(.hidden)
            .background(OnboardingPalette.background)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.completionDone) { showingLMPForm = false }
                        .accessibilityIdentifier("onboardingLMPDone")
                }
            }
        }
        .lunaSheetPresentation(detents: [.large])
        .environment(\.locale, AppLocale.locale)
        .onboardingLight()
        .onAppear {
            if dateSelection.source == .dueDate {
                dateSelection = PregnancyDateSelection(
                    source: .lmp, date: PregnancyDateInput.convert(dateSelection.date, to: .lmp, now: now)
                )
            }
        }
    }

    // MARK: - Actions

    /// Every step change fades (none under UI tests or Reduce Motion).
    private func change(_ update: (inout OnboardingFlow) -> Void) {
        withAnimation(LunaMotion.isEnabled && !reduceMotion ? LunaMotion.fade : nil) { update(&flow) }
    }

    private func continueTapped() {
        change { flow in
            // The due date step's value counts once she continues past it.
            if flow.step == .dueDate { flow.pregnancyDates = dateSelection }
            flow.next()
        }
    }

    /// The due date moved by `days`, or nil when that leaves the allowed range
    /// (the button is then disabled rather than moving by less than a week).
    private func shiftedDueDate(by days: Int) -> Date? {
        guard let shifted = Calendar.current.date(byAdding: .day, value: days, to: dueDate),
              PregnancyDateInput.clamp(shifted, for: .dueDate, now: now) == shifted
        else { return nil }
        return shifted
    }

    private func shiftDueDate(by days: Int) {
        guard let shifted = shiftedDueDate(by: days) else { return }
        dateSelection = PregnancyDateSelection(source: .dueDate, date: shifted)
    }

    /// Replay: the last period step shows the current period instead of today
    /// (the goal, lengths, answers and due date already start from the stored
    /// ones, see `init`).
    private func startFromCurrentValues() {
        guard isReplay, let start = cycle.forecast?.currentPeriodStart else { return }
        flow.lastPeriodStart = AppLocale.calendar.startOfDay(for: start)
    }

    /// Saves the branch's answers with the existing stores (spec §3.2). "Turn on
    /// reminders" asks for notifications; "Later" never does. In the cycle
    /// branch `completeOnboarding` asks itself (even without a forecast), so the
    /// view never asks a second time. A failed period save shows on Today.
    /// Marks the screen as saving before the task starts, so a quick second
    /// tap on either result button is ignored instead of finishing twice.
    private func startFinishing(requestingNotifications: Bool) {
        guard !saving else { return }
        saving = true
        Task { await finish(requestingNotifications: requestingNotifications) }
    }

    private func finish(requestingNotifications: Bool) async {
        defer { saving = false }
        // Replaying never changes the mode, the answers, the periods or the dates.
        guard !isReplay else { return onFinish() }
        switch flow.finish() {
        case let .cycle(goal, settings, firstPeriodStart, regularity, contraception):
            await cycle.completeOnboarding(
                goal: goal,
                settings: settings,
                firstPeriodStart: firstPeriodStart,
                regularity: regularity,
                contraception: contraception,
                requestNotifications: requestingNotifications
            )
        case .pregnant(let dates):
            AppMode.save(.pregnant, to: AppGroup.defaults)
            if let dates {
                PregnancyProfile.save(source: dates.source, date: dates.date, to: AppGroup.defaults)
            }
            if requestingNotifications {
                await kicks.requestNotificationPermission()
            }
        }
        onFinish()
    }
}

/// The top bar from step 2 on: back on the left, Skip on the right at their
/// own sizes, the progress dots centred on the screen when they fit between
/// them, otherwise centred in the space that is left.
private struct TopBarLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let height = subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
        return CGSize(width: proposal.width ?? subviews.reduce(0) { $0 + $1.sizeThatFits(.unspecified).width }, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 3 else { return }
        let left = subviews[0].sizeThatFits(.unspecified)
        let center = subviews[1].sizeThatFits(.unspecified)
        // Skip may shrink (minimumScaleFactor) when the bar is too narrow.
        let rightWidth = min(subviews[2].sizeThatFits(.unspecified).width, bounds.width - left.width - center.width - 2 * spacing)
        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading, proposal: ProposedViewSize(left))
        subviews[2].place(
            at: CGPoint(x: bounds.maxX, y: bounds.midY), anchor: .trailing,
            proposal: ProposedViewSize(width: max(rightWidth, 0), height: nil)
        )
        let minX = bounds.minX + left.width + spacing
        let maxX = bounds.maxX - max(rightWidth, 0) - spacing
        var x = bounds.midX
        if x - center.width / 2 < minX || x + center.width / 2 > maxX {
            x = (minX + maxX) / 2
        }
        subviews[1].place(at: CGPoint(x: x, y: bounds.midY), anchor: .center, proposal: ProposedViewSize(center))
    }
}

/// CSS `text-wrap: balance` for a title: the narrowest width that keeps the
/// line count of the full width, so a two-line title splits evenly instead of
/// leaving one word on the second line. The view still takes the full width.
private struct BalancedText: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let text = subviews.first else { return .zero }
        guard let width = proposal.width else { return text.sizeThatFits(proposal) }
        let height = text.sizeThatFits(ProposedViewSize(width: balancedWidth(text, in: width), height: nil)).height
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let text = subviews.first else { return }
        text.place(at: bounds.origin, proposal: ProposedViewSize(width: balancedWidth(text, in: bounds.width), height: nil))
    }

    private func balancedWidth(_ text: LayoutSubview, in width: CGFloat) -> CGFloat {
        guard width.isFinite, text.sizeThatFits(.unspecified).width > width else { return width }
        let height = text.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
        var low = width * 0.4
        var high = width
        for _ in 0..<10 {
            let mid = (low + high) / 2
            if text.sizeThatFits(ProposedViewSize(width: mid, height: nil)).height <= height + 0.5 {
                high = mid
            } else {
                low = mid
            }
        }
        return high.rounded(.up)
    }
}

/// The background behind the step's text: clear 56 pt above the content's top
/// edge, opaque 16 pt below it (inside the title's first line), then solid to
/// the bottom, so the title, body and notes never sit on the picture.
private struct ContentScrim: View {
    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [OnboardingPalette.background.opacity(0), OnboardingPalette.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 72)
            OnboardingPalette.background
        }
        .padding(.top, -56)
        .padding(.bottom, -200)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The picture at the top of each step (phase 18 handoff §1).
enum OnboardingHeroKind: Hashable {
    case welcome
    case goal
    /// The cycle branch's steps: a woman at ease (tracking) or planning with a
    /// calendar (trying to conceive).
    case cycleTracking
    case cycleConceiving
    case dueDate

    var imageName: String {
        switch self {
        case .welcome: "OnboardingWelcome"
        case .goal: "OnboardingGoal"
        case .cycleTracking: "OnboardingTrack"
        case .cycleConceiving: "OnboardingConceive"
        case .dueDate: "OnboardingDue"
        }
    }

    /// The picture's top, below the safe area (the handoff's 96 / 100 px on an
    /// 844 px screen with a 50 px status bar).
    var top: CGFloat {
        switch self {
        case .welcome: 46
        default: 50
        }
    }

    /// The picture's height as a share of the safe area's height (340 / 760 on
    /// the welcome step, 320 / 760 on the goal step); the question steps keep
    /// more room for their cards, wheels and day grid.
    var heightFraction: CGFloat {
        switch self {
        case .welcome: 0.45
        case .goal: 0.42
        case .cycleTracking, .cycleConceiving: 0.36
        case .dueDate: 0.36
        }
    }

    /// The due date step still uses a photo (until its illustration arrives),
    /// which is not on the cream background: it gets rounded corners.
    var isPhoto: Bool { self == .dueDate }
}

/// The illustration, whole and top-aligned (`object-fit: contain`,
/// `object-position: 50% 0%`), with a 16 % fade at the bottom and the wave
/// band; reveal, Ken Burns and wave-rise run when it appears.
private struct OnboardingHero: View {
    let kind: OnboardingHeroKind

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                ZStack(alignment: .bottom) {
                    picture
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                        .lunaEntrance(.kenBurns)
                    LinearGradient(
                        colors: [OnboardingPalette.background.opacity(0), OnboardingPalette.background],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: proxy.size.height * 0.16)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .lunaEntrance(.reveal)
                WaveBand()
                    .frame(height: 56)
                    .offset(y: 1)
                    .lunaEntrance(.waveRise)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var picture: some View {
        let image = Image(kind.imageName).resizable().scaledToFit()
        if kind.isPhoto {
            image.clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        } else {
            image
        }
    }
}

/// The background-coloured wave (README: path `M0 34 C100 4 300 4 400 34 C500 64
/// 700 64 800 34 L800 64 L0 64 Z`, one period over twice the width) drifting
/// left at one width per 9 s. Two periods are drawn so the loop is seamless.
/// Still under Reduce Motion and in UI tests.
private struct WaveBand: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var drifts: Bool { !reduceMotion && LunaMotion.isEnabled }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            TimelineView(.animation(paused: !drifts)) { context in
                let phase = drifts ? context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 18) / 18 : 0
                WaveShape()
                    .fill(OnboardingPalette.background)
                    .frame(width: width * 4, height: proxy.size.height)
                    .offset(x: -width * 2 * phase)
            }
            .frame(width: width, height: proxy.size.height, alignment: .leading)
            .clipped()
        }
    }
}

private struct WaveShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scaleX = rect.width / 1600
        let scaleY = rect.height / 64
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scaleX, y: rect.minY + y * scaleY)
        }
        var path = Path()
        path.move(to: point(0, 34))
        for start in [CGFloat(0), 800] {
            path.addCurve(to: point(start + 400, 34), control1: point(start + 100, 4), control2: point(start + 300, 4))
            path.addCurve(to: point(start + 800, 34), control1: point(start + 500, 64), control2: point(start + 700, 64))
        }
        path.addLine(to: point(1600, 64))
        path.addLine(to: point(0, 64))
        path.closeSubpath()
        return path
    }
}
