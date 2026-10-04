import KickCore
import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @Environment(CycleCoordinator.self) private var cycle
    @State private var page = 0
    @State private var step = Step.intro
    @State private var dateSource: PregnancyDateSource
    @State private var date: Date
    @State private var lastPeriod: Date
    @State private var cycleLength = CycleSettings.defaultCycleLength
    @State private var periodLength = CycleSettings.defaultPeriodLength
    @State private var saving = false
    private let now: Date

    /// Intro pages → mode → pregnancy dates or cycle. The mode step comes after
    /// "I understand" so the medical disclaimer can't be swiped past.
    private enum Step {
        case intro
        case mode
        case pregnancy
        case cycle
    }

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        let now = AppClock.now()
        self.now = now
        let selection = PregnancyDateInput.initialSelection(for: PregnancyProfile.load(from: AppGroup.defaults), now: now)
        _dateSource = State(initialValue: selection.source)
        _date = State(initialValue: selection.date)
        _lastPeriod = State(initialValue: now)
    }

    private struct Page {
        let symbol: String
        let title: String
        let body: String
    }

    private var pages: [Page] {
        [
            Page(symbol: "hand.tap.fill", title: L10n.onboarding1Title, body: L10n.onboarding1Body),
            Page(symbol: "moon.stars.fill", title: L10n.onboarding2Title, body: L10n.onboarding2Body),
            Page(symbol: "stethoscope", title: L10n.onboarding3Title, body: L10n.onboarding3Body),
        ]
    }

    var body: some View {
        Group {
            switch step {
            case .intro: introPages
            case .mode: modeStep
            case .pregnancy: pregnancyStep
            case .cycle: cycleStep
            }
        }
        .interactiveDismissDisabled()
    }

    private var introPages: some View {
        VStack {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    VStack(spacing: 24) {
                        Image(systemName: pages[index].symbol)
                            .font(.system(size: 72))
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)
                        Text(pages[index].title)
                            .font(.title.bold())
                            .multilineTextAlignment(.center)
                        Text(pages[index].body)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .padding(32)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            if page < pages.count - 1 {
                Button {
                    withAnimation { page += 1 }
                } label: {
                    Text(L10n.onboardingNext).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityIdentifier("onboardingNext")
                .padding(24)
            } else {
                Button {
                    withAnimation { step = .mode }
                } label: {
                    Text(L10n.onboardingAgree).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("onboardingAgree")
                .padding(24)
            }
        }
    }

    private var modeStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                header(symbol: "heart.circle.fill", title: L10n.onboardingModeTitle, body: L10n.onboardingModeBody)
                VStack(spacing: 12) {
                    modeButton(
                        title: L10n.modeTryingToConceive,
                        detail: L10n.onboardingModeTTCDetail,
                        symbol: "drop.circle.fill",
                        identifier: "onboardingModeTTC"
                    ) {
                        withAnimation { step = .cycle }
                    }
                    modeButton(
                        title: L10n.modePregnant,
                        detail: L10n.onboardingModePregnantDetail,
                        symbol: "heart.text.square.fill",
                        identifier: "onboardingModePregnant"
                    ) {
                        AppMode.save(.pregnant, to: AppGroup.defaults)
                        withAnimation { step = .pregnancy }
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 24)
        }
    }

    private func modeButton(
        title: String,
        detail: String,
        symbol: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.title)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 44)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    Text(detail).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private func header(symbol: String, title: String, body: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text(title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text(body)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 32)
        .padding(.top, 32)
    }

    private var pregnancyStep: some View {
        VStack(spacing: 0) {
            header(symbol: "calendar.badge.clock", title: L10n.onboarding4Title, body: L10n.onboarding4Body)

            Form {
                PregnancyDateForm(source: $dateSource, date: $date, now: now)
            }
            .scrollContentBackground(.hidden)

            VStack(spacing: 12) {
                Button {
                    PregnancyProfile.save(source: dateSource, date: date, to: AppGroup.defaults)
                    onFinish()
                } label: {
                    Text(L10n.commonSave).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("onboardingSaveDate")

                Button(action: onFinish) {
                    Text(L10n.onboardingLater).frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .accessibilityIdentifier("onboardingSkipDate")
            }
            .padding(24)
        }
    }

    private var cycleStep: some View {
        VStack(spacing: 0) {
            header(symbol: "drop.circle.fill", title: L10n.onboardingCycleTitle, body: L10n.onboardingCycleBody)

            Form {
                LastPeriodPicker(date: $lastPeriod, now: now)
                Section {
                    Stepper(L10n.cycleSettingsCycleLength(cycleLength), value: $cycleLength, in: CycleSettings.cycleLengthRange)
                        .accessibilityIdentifier("onboardingCycleLength")
                    Stepper(L10n.cycleSettingsPeriodLength(periodLength), value: $periodLength, in: CycleSettings.periodLengthRange)
                        .accessibilityIdentifier("onboardingPeriodLength")
                } footer: {
                    Text(L10n.cycleSettingsHint)
                }
            }
            .scrollContentBackground(.hidden)

            VStack(spacing: 12) {
                Button {
                    Task { await finishCycleStep(savingLastPeriod: true) }
                } label: {
                    Text(L10n.commonSave).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(saving)
                .accessibilityIdentifier("onboardingSaveCycle")

                Button {
                    Task { await finishCycleStep(savingLastPeriod: false) }
                } label: {
                    Text(L10n.onboardingLater).frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .disabled(saving)
                .accessibilityIdentifier("onboardingSkipCycle")
            }
            .padding(24)
        }
    }

    /// Saves the cycle numbers, switches to trying-to-conceive mode and — unless
    /// skipped — the last period. A failed save shows on the Cycle tab.
    private func finishCycleStep(savingLastPeriod: Bool) async {
        saving = true
        defer { saving = false }
        // CycleSettings lengths are set only through its clamping init.
        await cycle.updateSettings(CycleSettings(
            typicalCycleLength: cycleLength,
            typicalPeriodLength: periodLength,
            remindersEnabled: cycle.settings.remindersEnabled
        ))
        await cycle.activateTryingToConceive()
        if savingLastPeriod {
            await cycle.logLastPeriod(startingOn: lastPeriod)
        }
        onFinish()
    }
}
