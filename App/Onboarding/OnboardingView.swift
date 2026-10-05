import KickCore
import SwiftUI

/// Three steps (spec §4.1): welcome with the language and the medical note →
/// what to track → the last period (trying to conceive) or the due date
/// (pregnant). "Skip" on the first two steps jumps to the last one.
///
/// `replay` (Profile → "Replay the introduction") starts from the current mode,
/// cycle length, period and due date, and finishing or skipping only closes it:
/// no mode, settings, period or pregnancy dates are saved. The language
/// choice still applies, as a view preference.
struct OnboardingView: View {
    let replay: Bool
    let onFinish: () -> Void

    @Environment(CycleCoordinator.self) private var cycle
    @AppStorage(SettingsKey.appLanguage, store: AppGroup.defaults)
    private var appLanguage = AppLanguage.system.rawValue
    @State private var step = Step.welcome
    @State private var goal: AppMode?
    @State private var lastPeriod: Date
    @State private var cycleLength = CycleSettings.defaultCycleLength
    @State private var dateSelection: PregnancyDateSelection
    @State private var showingOtherDay = false
    @State private var showingDuePicker = false
    @State private var showingLMPForm = false
    @State private var saving = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let now: Date

    enum Step: Int, CaseIterable {
        case welcome
        case goal
        case details
    }

    init(replay: Bool = false, onFinish: @escaping () -> Void) {
        self.replay = replay
        self.onFinish = onFinish
        let now = AppClock.now()
        self.now = now
        _goal = State(initialValue: replay ? AppMode.load(from: AppGroup.defaults) : nil)
        _lastPeriod = State(initialValue: AppLocale.calendar.startOfDay(for: now))
        _dateSelection = State(initialValue: PregnancyDateInput.initialSelection(
            for: PregnancyProfile.load(from: AppGroup.defaults), now: now
        ))
    }

    /// Skipping before choosing keeps the old default: pregnant.
    private var isCycleBranch: Bool { goal == .tryingToConceive }

    private var dueDate: Date {
        dateSelection.source == .dueDate ? dateSelection.date : PregnancyDates.dueDate(fromLMP: dateSelection.date)
    }

    private var hero: OnboardingHeroKind {
        switch step {
        case .welcome: .welcome
        case .goal: .goal
        case .details: isCycleBranch ? .lastPeriod : .dueDate
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
            // A new id runs the entrance animations again for every step.
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
                        .id(step)
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
        HStack {
            progressDots
            Spacer()
            if step != .details {
                Button(L10n.onboardingSkip) { skip() }
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

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.self) { item in
                Capsule()
                    .fill(Color.luna(.textOnboarding).opacity(item.rawValue <= step.rawValue ? 1 : 0.2))
                    .frame(width: item == step ? 22 : 6, height: 6)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Capsule().fill(Color.luna(.card).opacity(0.7)))
        .animation(LunaMotion.isEnabled && !reduceMotion ? LunaMotion.dots : nil, value: step)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.onboardingStep(step.rawValue + 1, Step.allCases.count))
        .accessibilityIdentifier("onboardingProgress")
    }

    // MARK: - Steps

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome: welcomeStep
        case .goal: goalStep
        case .details:
            if isCycleBranch {
                lastPeriodStep
            } else {
                dueDateStep
            }
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
            goalCard(
                .tryingToConceive,
                title: L10n.onboardingGoalCycle,
                detail: L10n.onboardingGoalCycleDetail,
                dot: .cycle,
                identifier: "onboardingModeTTC"
            )
            goalCard(
                .pregnant,
                title: L10n.onboardingGoalPregnant,
                detail: L10n.onboardingGoalPregnantDetail,
                dot: .preg,
                identifier: "onboardingModePregnant"
            )
        }
    }

    private func goalCard(_ mode: AppMode, title: String, detail: String, dot: LunaToken, identifier: String) -> some View {
        let isSelected = goal == mode
        return Button {
            goal = mode
        } label: {
            HStack(spacing: 14) {
                Circle().fill(.luna(dot)).frame(width: 12, height: 12)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.luna(size: 16, weight: .medium, relativeTo: .headline))
                        .foregroundStyle(.luna(.textOnboarding))
                    Text(detail)
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.textSecondary))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 18)
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
        let isOtherDay = !days.contains { calendar.isDate($0.date, inSameDayAs: lastPeriod) }
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
                    Text(isOtherDay ? L10n.onboardingOtherDayValue(Formatting.shortDay(lastPeriod)) : L10n.onboardingOtherDay)
                }
                .buttonStyle(.pill(isOtherDay ? .filled(.cycleStrong) : .soft(.surfaceAlt, .textPrimary), height: 40))
                .accessibilityAddTraits(isOtherDay ? .isSelected : [])
                .accessibilityIdentifier("onboardingOtherDay")
            }
            .lunaCard(padding: 10)
            HStack(spacing: 10) {
                Text(L10n.cycleLengthTitle)
                    .font(.luna(size: 14, weight: .medium))
                    .foregroundStyle(.luna(.textOnboarding))
                    .frame(maxWidth: .infinity, alignment: .leading)
                roundButton("minus", label: L10n.onboardingCycleShorter, identifier: "onboardingCycleShorter") {
                    cycleLength = max(CycleSettings.cycleLengthRange.lowerBound, cycleLength - 1)
                }
                .disabled(cycleLength <= CycleSettings.cycleLengthRange.lowerBound)
                Text(L10n.days(cycleLength))
                    .font(.luna(.cardTitleSmall))
                    .foregroundStyle(.luna(.textOnboarding))
                    .frame(minWidth: 70)
                    .accessibilityIdentifier("onboardingCycleLength")
                roundButton("plus", label: L10n.onboardingCycleLonger, identifier: "onboardingCycleLonger") {
                    cycleLength = min(CycleSettings.cycleLengthRange.upperBound, cycleLength + 1)
                }
                .disabled(cycleLength >= CycleSettings.cycleLengthRange.upperBound)
            }
            .lunaCard(padding: 12)
        }
    }

    private func dayChip(_ day: RecentDay, calendar: Calendar) -> some View {
        let isSelected = calendar.isDate(day.date, inSameDayAs: lastPeriod)
        return Button {
            lastPeriod = day.date
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
                Text(PregnancyTimeline(dueDate: dueDate, now: now).map { L10n.pregnancyWeekLabel($0.week) } ?? "")
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
            switch step {
            case .welcome:
                Button(L10n.onboardingContinue) { go(to: .goal) }
                    .buttonStyle(.pill(.onboarding))
                    .accessibilityIdentifier("onboardingNext")
            case .goal:
                Button(L10n.onboardingContinue) { go(to: .details) }
                    .buttonStyle(.pill(.onboarding))
                    .disabled(goal == nil)
                    .accessibilityIdentifier("onboardingNext")
            case .details:
                if isCycleBranch {
                    Button(L10n.onboardingStart) { Task { await finishCycle(savingLastPeriod: true) } }
                        .buttonStyle(.pill(.onboarding))
                        .disabled(saving)
                        .accessibilityIdentifier("onboardingSaveCycle")
                    Button(L10n.onboardingLater) { Task { await finishCycle(savingLastPeriod: false) } }
                        .buttonStyle(.pill(.text(.textOnboarding), height: 44))
                        .disabled(saving)
                        .accessibilityIdentifier("onboardingSkipCycle")
                } else {
                    Button(L10n.onboardingStart) { finishPregnancy(savingDates: true) }
                        .buttonStyle(.pill(.onboarding))
                        .accessibilityIdentifier("onboardingSaveDate")
                    Button(L10n.onboardingLater) { finishPregnancy(savingDates: false) }
                        .buttonStyle(.pill(.text(.textOnboarding), height: 44))
                        .accessibilityIdentifier("onboardingSkipDate")
                }
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Sheets

    private var otherDaySheet: some View {
        NavigationStack {
            Form {
                LastPeriodPicker(date: $lastPeriod, now: now)
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

    private func go(to next: Step) {
        withAnimation(LunaMotion.isEnabled ? LunaMotion.fade : nil) { step = next }
    }

    private func skip() {
        if goal == nil { goal = .pregnant }
        go(to: .details)
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

    /// Replay: the cycle step shows the stored cycle length and the current
    /// period instead of the first-run defaults (the due date already starts
    /// from the stored one, see `init`).
    private func startFromCurrentValues() {
        guard replay else { return }
        cycleLength = cycle.settings.typicalCycleLength
        if let start = cycle.forecast?.currentPeriodStart {
            lastPeriod = AppLocale.calendar.startOfDay(for: start)
        }
    }

    private func finishPregnancy(savingDates: Bool) {
        // Replaying never changes the mode or the pregnancy dates.
        guard !replay else { return onFinish() }
        AppMode.save(.pregnant, to: AppGroup.defaults)
        if savingDates {
            PregnancyProfile.save(source: dateSelection.source, date: dateSelection.date, to: AppGroup.defaults)
        }
        onFinish()
    }

    /// Saves the cycle length, switches to trying-to-conceive mode and — unless
    /// skipped — the last period. A failed save shows on Today.
    private func finishCycle(savingLastPeriod: Bool) async {
        // Replaying never changes the mode, the cycle settings or the periods.
        guard !replay else { return onFinish() }
        saving = true
        defer { saving = false }
        // CycleSettings lengths are set only through its clamping init.
        await cycle.updateSettings(CycleSettings(
            typicalCycleLength: cycleLength,
            typicalPeriodLength: cycle.settings.typicalPeriodLength,
            remindersEnabled: cycle.settings.remindersEnabled
        ))
        await cycle.activateTryingToConceive()
        if savingLastPeriod {
            await cycle.logLastPeriod(startingOn: lastPeriod)
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
