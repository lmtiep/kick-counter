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
struct OnboardingView: View {
    /// Captured once, when the view first appears: RootView recomputes the
    /// `replay` argument while the cover is being dismissed, and a second tap
    /// then must not fall through to the saving path.
    @State private var isReplay: Bool
    let onFinish: () -> Void

    @Environment(CycleCoordinator.self) private var cycle
    @Environment(KickCoordinator.self) private var kicks
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
        case .result: isPregnancyBranch ? .dueDate : .lastPeriod
        case .lastPeriod, .periodLength, .cycleLength, .regularity, .contraception: .lastPeriod
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.luna(.onboardingBackground).ignoresSafeArea()
            GeometryReader { proxy in
                OnboardingHero(kind: hero)
                    .frame(width: proxy.size.width, height: (proxy.size.height + proxy.safeAreaInsets.top) * hero.heightFraction)
                    .offset(y: -proxy.safeAreaInsets.top)
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                        // Tied to the content's top edge, so text never sits on the photo
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
            .padding(.bottom, 12)
        }
        .environment(\.locale, AppLocale.locale)
        .interactiveDismissDisabled()
        .onAppear(perform: startFromCurrentValues)
        .sheet(isPresented: $showingOtherDay) { otherDaySheet }
        .sheet(isPresented: $showingDuePicker) { duePickerSheet }
        .sheet(isPresented: $showingLMPForm) { lmpFormSheet }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 8) {
            if flow.canGoBack {
                Button { change { $0.back() } } label: {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.luna(.textOnboarding))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.luna(.card).opacity(0.7)))
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.onboardingBack)
                .accessibilityIdentifier("onboardingBack")
            }
            progressDots
            Spacer()
            if flow.isQuestion {
                Button(skipTitle) { change { $0.skip() } }
                    .font(.luna(.captionMedium))
                    .foregroundStyle(.luna(.textOnboarding))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 32)
                    .background(Capsule().fill(Color.luna(.card).opacity(0.7)))
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("onboardingSkip")
            }
        }
        .padding(.top, 8)
        .padding(.horizontal, 24)
    }

    /// "Not sure" where the answer is a number or a pattern, "Skip" elsewhere.
    private var skipTitle: String {
        switch flow.step {
        case .periodLength, .cycleLength, .regularity: L10n.onboardingNotSure
        default: L10n.onboardingSkip
        }
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(Array(flow.steps.enumerated()), id: \.offset) { index, _ in
                Capsule()
                    .fill(Color.luna(.textOnboarding).opacity(index < flow.stepNumber ? 1 : 0.2))
                    .frame(width: index + 1 == flow.stepNumber ? 22 : 6, height: 6)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Capsule().fill(Color.luna(.card).opacity(0.7)))
        .animation(LunaMotion.isEnabled && !reduceMotion ? LunaMotion.dots : nil, value: flow.step)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.onboardingStep(flow.stepNumber, flow.stepCount))
        .accessibilityIdentifier("onboardingProgress")
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

    private func title(_ text: String) -> some View {
        Text(text)
            .font(.luna(.onboardingTitle))
            .tracking(-0.68)
            .lineSpacing(2)
            .foregroundStyle(.luna(.textOnboarding))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private func note(_ text: String, identifier: String) -> some View {
        Text(text)
            .font(.luna(.caption))
            .foregroundStyle(.luna(.articleText))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(identifier)
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            title(L10n.onboardingWelcomeTitle)
                .accessibilityIdentifier("onboardingWelcomeTitle")
            Text(L10n.onboardingWelcomeBody)
                .font(.luna(.body))
                .lineSpacing(4)
                .foregroundStyle(.luna(.articleText))
                .frame(maxWidth: 300, alignment: .leading)
            // The medical note of the old onboarding: always on the first step, never skipped.
            (Text(L10n.onboarding3Title).font(.luna(.captionStrong))
                + Text(verbatim: "\n")
                + Text(L10n.onboarding3Body).font(.luna(.caption)))
                .foregroundStyle(.luna(.articleText))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("onboardingMedicalNote")
            note(L10n.onboardingPrivacy, identifier: "onboardingPrivacyNote")
            SegmentedPill(options: [
                SegmentedOption(value: ContentLanguage.vi, title: L10n.languageVietnamese, identifier: "onboardingLanguageVi"),
                SegmentedOption(value: ContentLanguage.en, title: L10n.languageEnglish, identifier: "onboardingLanguageEn"),
            ], selection: languageBinding, capsule: true)
            // Hugs its segments but never grows past the screen at large text sizes.
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
        }
    }

    /// Shows the language in use; choosing one stores it for the whole app at once.
    private var languageBinding: Binding<ContentLanguage> {
        Binding(
            get: { AppLocale.language },
            set: { appLanguage = $0.rawValue }
        )
    }

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            title(L10n.onboardingModeTitle)
                .padding(.bottom, 6)
            choiceCard(
                title: L10n.onboardingGoalTracking,
                detail: L10n.onboardingGoalTrackingDetail,
                dot: .cycle,
                isSelected: flow.goal == .tracking,
                identifier: "onboardingGoal-tracking"
            ) { flow.goal = .tracking }
            choiceCard(
                title: L10n.onboardingGoalConceiving,
                detail: L10n.onboardingGoalConceivingDetail,
                dot: .fertile,
                isSelected: flow.goal == .conceiving,
                identifier: "onboardingGoal-conceiving"
            ) { flow.goal = .conceiving }
            choiceCard(
                title: L10n.onboardingGoalPregnant,
                detail: L10n.onboardingGoalPregnantDetail,
                dot: .preg,
                isSelected: flow.goal == .pregnant,
                identifier: "onboardingGoal-pregnant"
            ) { flow.goal = .pregnant }
        }
    }

    /// A large tappable card: the goal, regularity and contraception choices.
    private func choiceCard(
        title: String,
        detail: String? = nil,
        dot: LunaToken? = nil,
        isSelected: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let dot {
                    Circle().fill(.luna(dot)).frame(width: 12, height: 12)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.luna(size: 16, weight: .medium, relativeTo: .headline))
                        .foregroundStyle(.luna(.textOnboarding))
                    if let detail {
                        Text(detail)
                            .font(.luna(.caption))
                            .foregroundStyle(.luna(.textSecondary))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.luna(.textOnboarding))
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, detail == nil ? 13 : 16)
            .padding(.horizontal, 18)
            .frame(minHeight: 48)
            .background(.luna(.card), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isSelected ? Color.luna(.textOnboarding) : Color.clear, lineWidth: 1.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                }
                .buttonStyle(.pill(isOtherDay ? .filled(.cycleStrong) : .soft(.surfaceAlt, .textPrimary), height: 40))
                .accessibilityAddTraits(isOtherDay ? .isSelected : [])
                .accessibilityIdentifier("onboardingOtherDay")
            }
            .lunaCard(padding: 10)
            Button(L10n.onboardingDontRemember) {
                change {
                    $0.lastPeriodStart = nil
                    $0.next()
                }
            }
            .buttonStyle(.pill(.text(.textOnboarding), height: 44))
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
            .foregroundStyle(.luna(isSelected ? .onAccent : .textOnboarding))
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.luna(.cycleStrong) : Color.clear)
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
        .lunaCard(padding: 4)
    }

    private var regularityStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            title(L10n.onboardingRegularityTitle)
                .padding(.bottom, 6)
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
                            .foregroundStyle(.luna(.textOnboarding))
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
                    .foregroundStyle(.luna(.pregOnSoft))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.luna(.pregSoft)))
                    .accessibilityIdentifier("onboardingDueWeeks")
            }
            .frame(maxWidth: .infinity)
            .lunaCard(padding: 16)
            Button(L10n.onboardingDueFromLMP) { showingLMPForm = true }
                .buttonStyle(.pill(.text(.textOnboarding), height: 44))
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
                .foregroundStyle(.luna(.textOnboarding))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("onboardingResultText")
                .frame(maxWidth: .infinity, alignment: .leading)
                .lunaCard(padding: 16)
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
                .foregroundStyle(.luna(.textOnboarding))
                .frame(width: 42, height: 42)
                .background(Circle().fill(.luna(.onboardingBackground)))
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
            if flow.step == .result {
                Button(L10n.onboardingEnableReminders) { Task { await finish(requestingNotifications: true) } }
                    .buttonStyle(.pill(.onboarding))
                    .disabled(saving)
                    .accessibilityIdentifier("onboardingEnableReminders")
                Button(L10n.onboardingLater) { Task { await finish(requestingNotifications: false) } }
                    .buttonStyle(.pill(.text(.textOnboarding), height: 44))
                    .disabled(saving)
                    .accessibilityIdentifier("onboardingFinishLater")
            } else {
                Button(L10n.onboardingContinue) { continueTapped() }
                    .buttonStyle(.pill(.onboarding))
                    .disabled(!flow.canContinue)
                    .accessibilityIdentifier("onboardingNext")
            }
        }
        .padding(.top, 12)
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
            .background(.luna(.background))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.completionDone) { showingOtherDay = false }
                        .accessibilityIdentifier("onboardingOtherDayDone")
                }
            }
        }
        .lunaSheetPresentation(detents: [.medium, .large])
        .environment(\.locale, AppLocale.locale)
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
            .tint(.luna(.pregStrong))
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
    }

    private var lmpFormSheet: some View {
        NavigationStack {
            Form {
                PregnancyDateForm(source: $dateSelection.source, date: $dateSelection.date, now: now)
            }
            .scrollContentBackground(.hidden)
            .background(.luna(.background))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.completionDone) { showingLMPForm = false }
                        .accessibilityIdentifier("onboardingLMPDone")
                }
            }
        }
        .lunaSheetPresentation(detents: [.large])
        .environment(\.locale, AppLocale.locale)
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
    private func finish(requestingNotifications: Bool) async {
        // Replaying never changes the mode, the answers, the periods or the dates.
        guard !isReplay else { return onFinish() }
        saving = true
        defer { saving = false }
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
                _ = await kicks.requestNotificationPermission()
            }
        }
        onFinish()
    }
}

/// The background behind the step's text: clear 56 pt above the content's top
/// edge, opaque 16 pt below it (inside the title's first line), then solid to
/// the bottom, so the title, body and medical note never sit on the photo.
private struct ContentScrim: View {
    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.luna(.onboardingBackground).opacity(0), Color.luna(.onboardingBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 72)
            Color.luna(.onboardingBackground)
        }
        .padding(.top, -56)
        .padding(.bottom, -200)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The picture at the top of each step (README §1).
enum OnboardingHeroKind: Hashable {
    case welcome
    case goal
    /// No photo yet (spec §4.1): a pink gradient with the same wave.
    case lastPeriod
    case dueDate

    var imageName: String? {
        switch self {
        case .welcome: "OnboardingWelcome"
        case .goal: "OnboardingGoal"
        case .lastPeriod: nil
        case .dueDate: "OnboardingDue"
        }
    }

    var heightFraction: CGFloat {
        switch self {
        case .welcome: 0.78
        case .goal: 0.58
        case .lastPeriod: 0.46
        case .dueDate: 0.62
        }
    }

    /// Which part of the photo stays visible (object-position 30–40 % in the design).
    var focus: Alignment {
        switch self {
        case .welcome, .goal: .top
        case .lastPeriod, .dueDate: .center
        }
    }
}

/// Photo (or gradient) fading into the background, with the wave band at the
/// bottom; reveal, Ken Burns and wave-rise run when it appears.
private struct OnboardingHero: View {
    let kind: OnboardingHeroKind

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                ZStack(alignment: .bottom) {
                    picture
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: kind.focus)
                        .clipped()
                        .lunaEntrance(.kenBurns)
                    LinearGradient(
                        stops: [
                            .init(color: Color.luna(.onboardingBackground).opacity(0), location: 0),
                            .init(color: Color.luna(.onboardingBackground).opacity(0.85), location: 0.6),
                            .init(color: Color.luna(.onboardingBackground), location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: proxy.size.height * 0.45)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .lunaEntrance(.reveal)
                WaveBand()
                    .frame(height: 64)
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
        if let name = kind.imageName {
            Image(name).resizable().scaledToFill()
        } else {
            LinearGradient(
                colors: [Color.luna(.cycleSoft), Color.luna(.onboardingBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

/// The background-coloured wave (README: path `M0 34 C100 4 300 4 400 34 C500 64
/// 700 64 800 34 L800 64 L0 64 Z`, one period over twice the width) drifting
/// left at one width per 9 s. Two periods are drawn so the loop is seamless.
private struct WaveBand: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var drifts: Bool { !reduceMotion && LunaMotion.isEnabled }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            TimelineView(.animation(paused: !drifts)) { context in
                let phase = drifts ? context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 18) / 18 : 0
                WaveShape()
                    .fill(.luna(.onboardingBackground))
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
