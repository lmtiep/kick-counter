# Cycle tracking goal and a new onboarding ("Theo dõi chu kỳ", Phase 9) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. For the UI tasks (2, 3 and 4) also apply the `ui-ux-pro-max` skill to review visual detail, but do **not** change behaviour, accessibility identifiers, strings or colour tokens fixed by this plan. Task 5 writes documentation, not code.

**Goal:** The cycle mode gains a goal, "track my cycle" or "trying to conceive": tracking puts the next period first, names the fertile window "High chance of pregnancy" with a "not contraception" note, hides LH/BBT logging and, on hormonal contraception, hides the fertile window and ovulation; onboarding becomes a short three-branch flow (goal, last period, period and cycle length, regularity, contraception, an early "next period around …" result and a notification opt-in); Profile gets a three-choice goal picker, a contraception row and an LH/BBT override.

**Architecture:** Everything decidable without a screen lives in `KickCore` (pure Swift, tested by `scripts/test-core.sh`, which CI already runs): `CycleGoal`, `Contraception`, `CycleRegularity` and their App Group persistence (`CyclePreferences`), the pure `CycleDisplayPolicy` (what each goal × contraception shows, which reminder kinds are scheduled), the pure `OnboardingFlow` (step order per branch, skips, "I don't remember", the result's prediction and what `finish()` saves), and the `CycleCoordinator` entry points the screens call (`updatePreferences`, `activateCycleMode(goal:)`, `completeOnboarding(...)`). The forecast (`CyclePredictor`) is untouched: the goal only changes presentation. The App target reads `cycle.policy` in Today, the calendar, the day log and Profile, and rebuilds `OnboardingView` on `OnboardingFlow`. Nothing is synced: the new values sit next to `CycleSettings` in `AppGroup.defaults`, so CloudKit and the SwiftData store do not change.

**Tech Stack:** Swift 6 (strict concurrency), SwiftUI (iOS 17), Swift Testing (KickCore), XCTest (UI), XcodeGen, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-08-cycle-tracking-design.md` (the requirements; build exactly what it says, as clarified below). Previous plan for conventions: `docs/superpowers/plans/2026-10-07-partner.md`.

## Global Constraints

- **No CI script, workflow or entitlement changes.** Do not edit `.github/workflows/*`, `scripts/ci.sh`, `scripts/test-core.sh`, `App/KickCounter.entitlements` or the `entitlements:` of `project.yml`; changing what CI tests needs the user's approval. That is why every rule of this phase (`CyclePreferences`, `CycleDisplayPolicy`, `OnboardingFlow`, the coordinator entry points) and all their tests live in `KickCore`, which `scripts/test-core.sh` (and so CI) already runs.
- Swift language mode 6 with strict concurrency; iOS deployment target `17.0`; package platforms `.iOS(.v17), .macOS(.v14)`. No third-party SDKs, no server, no data collection.
- **KickCore import rules:** `KickCore` must not import SwiftUI, UIKit, SwiftData or CloudKit (Foundation, Observation, OSLog and the existing `@preconcurrency import UserNotifications` of the reminder files only).
- **Existing users are never re-onboarded and keep today's behaviour.** Nothing in this phase touches `SettingsKey.hasCompletedOnboarding`. With no `cycleGoal` stored the goal is `conceiving` (`CyclePreferences.load`), whose `CycleDisplayPolicy` equals the pre-phase-9 screens and reminders exactly (`CycleDisplayPolicy.conceiving`). Every App call site that gains a `policy:` parameter gets `.conceiving` as its default.
- **Partner sharing (Phase 8) still stops on pregnant → cycle mode.** `RootView`'s `.onChange(of: appMode)` (old `pregnant`, new `tryingToConceive` → `partnerShare.stopSharingAfterLeavingPregnancy`) is not edited. Both cycle choices of the three-choice picker go through the same `CycleCoordinator.activateCycleMode(goal:)`, which stores the goal and then calls the existing `activateTryingToConceive()`, so the stored mode changes exactly as before and that `onChange` fires. `EndPregnancySheet` keeps calling `activateTryingToConceive()` (the stored goal, `conceiving` by default, is kept).
- Every UI string goes through `L10n` (`Shared/L10n.swift`) and lives in `Shared/Localizable.xcstrings` with both `en` and `vi`. Strings are added or removed **only** with `scripts/add-strings.py` (JSON `{"key": ["English", "Tiếng Việt"]}` on stdin; `--remove key …`). Never `Text("…")` with a literal or interpolation: use `Text(L10n.…)` or `Text(verbatim:)`. Vietnamese copy is northern Vietnamese.
- **Medical copy is warm and hedged** ("thường", "có thể", "chỉ để tham khảo", "bạn nên đi khám") and never says the app can be used to avoid pregnancy. The new medical keys are listed for the doctor in Task 5 (`docs/content-review-for-doctor.md` §11); do not reword them without updating that list.
- Colours come only from Luna tokens: `.luna(.<token>)`. No hex in views. Every text/background pair must already be in `LunaContrast.usages` (`ContrastTests` stay green). Pairs used by this phase, all already declared: `textOnboarding`/`textSecondary` on `card` (choice cards), `articleText` on `onboardingBackground` (notes), `textOnboarding` on `onboardingBackground`, `textSecondary` on `card` (Coming up notes, Profile hints), `cycleOnSoft` on `card` (the contraception menu), `onAccent` on `cycleStrong` (day chips).
- Fonts: only `Font.luna(_:)` / `Font.luna(size:weight:relativeTo:)`. SF Symbols may use `.system(size:weight:)`.
- Animation is gated by `LunaMotion.isEnabled` (false under `-uiTesting`) **and** Reduce Motion. The only animations in this phase are onboarding's step change (`LunaMotion.fade` through `change(_:)`) and the progress dots (`LunaMotion.dots`, as before).
- Work on branch `feat/cycle-tracking` (already checked out). **Never** change the `gh` account or log in. Every commit message ends with a blank line, then the trailer block: `CI-Only-Testing: <UI test classes>` on its own line, immediately followed by `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (no blank line between them). Use `git commit -F - <<'MSG' … MSG` exactly as shown in each task. The only exception is Task 5, whose commit deliberately has **no** `CI-Only-Testing:` line so CI runs the full UI suite.
- **Local verification only:** implementers run `scripts/test-core.sh`, `xcodegen generate --quiet` and `xcodebuild … build-for-testing` on the "iPhone 18 Pro" simulator (command below) with `-derivedDataPath build/DerivedData` and **no other DerivedData path** (the disk is nearly full). They **never** run UI tests locally; UI tests and screenshots run on CI (`git push` + `scripts/ci-wait.sh`).
- UI test lessons (mandatory):
  - Wait with `waitForExistence` / `waitForLabel` / an `XCTNSPredicateExpectation`, never a fixed `sleep`.
  - Rows below the fold (List, Form, long ScrollViews) may not exist until scrolled near: call `app.scrollUntilHittable(element)` before asserting on or tapping them. Onboarding's steps are anchored to the bottom, so a long list there starts at its end: use the new `app.scrollDownUntilHittable(element)`.
  - Put `.accessibilityElement(children: .combine)` (or `.contain`) **before** `.accessibilityIdentifier(…)`, or the identifier lands on a child; put an identifier on a `Text` **before** wrapping it in a card (`onboardingResultText`).
  - Never put a Button inside a draggable sheet header, and never tap one there. This phase adds no sheet.
- **Every UI test that walks through onboarding is updated in Task 2** (they are: `OnboardingUITests`, `KickCounterUITests.completeOnboarding`, `ScreenshotTests.testOnboardingAndSettingsScreens`, `ProfileUITests.testReplayingTheIntroductionKeepsTheData` and `…InCycleModeKeepsModeAndCycle`). Every other UI test launches with `-skipOnboarding` (`XCUIApplication.launchPinned`'s default) and is unaffected; `grep -rn "onboarding[A-Z]" UITests` after Task 2 must list only `OnboardingUITests.swift` and `UITestSupport.swift`.
- Keep every existing accessibility identifier except the onboarding ones this plan replaces (`onboardingModeTTC`, `onboardingModePregnant`, `onboardingSaveCycle`, `onboardingSkipCycle`, `onboardingSaveDate`, `onboardingSkipDate`, `onboardingCycleShorter`, `onboardingCycleLonger`, `onboardingCycleLength`). Kept: `onboardingNext`, `onboardingSkip`, `onboardingProgress`, `onboardingWelcomeTitle`, `onboardingMedicalNote`, `onboardingLanguageVi`/`En`, `onboardingDay`, `onboardingOtherDay`, `onboardingOtherDayDone`, `onboardingDueDate`, `onboardingDueEarlier`, `onboardingDueLater`, `onboardingDueWeeks`, `onboardingFromLMP`, `onboardingDuePicker(Done)`, `onboardingLMPDone`, `settingsModePicker`, `cycleStatusCard`, `cycleFertileCard`, `cycleNextPeriodCard`, `calendarLegend`, `calendarSelectedDay`, `dayLogLHPicker`, `dayLogBBTField`, `dayLogMucusPicker`. New: `onboardingBack`, `onboardingPrivacyNote`, `onboardingGoal-tracking`, `onboardingGoal-conceiving`, `onboardingGoal-pregnant`, `onboardingDontRemember`, `onboardingPeriodLengthPicker`, `onboardingCycleLengthPicker`, `onboardingCycleLengthHint`, `onboardingRegularity-<regular|irregular|unknown>`, `onboardingIrregularNote`, `onboardingContraceptionWhy`, `onboardingContraception-<Contraception raw value>`, `onboardingResultText`, `onboardingResultReminders`, `onboardingEnableReminders`, `onboardingFinishLater`, `cycleNotContraceptionNote`, `cycleHormonalNote`, `profileContraception`, `profileShowFertilityTests`.
- **The working tree must be clean before Task 1.** At planning time `git status` showed Xcode's reformat of `Shared/Localizable.xcstrings` and `Shared/InfoPlist.xcstrings` (spaces around `:`, extracted entries with only `en`). `scripts/add-strings.py` refuses a catalog with entries missing `vi`, and those changes must not be committed. Before Task 1, if `git status --short Shared/` lists either file, **stop and ask the user** whether to discard them (`git checkout -- Shared/Localizable.xcstrings Shared/InfoPlist.xcstrings`); never commit them, and never open the project in Xcode while implementing (it rewrites the catalogs).
- Out of scope (spec §2): birth year, gynaecological conditions, sleep/skin/sex-life questions, Apple Health, user name, social-proof stats, commitment ritual, partner sharing and knowledge features in the cycle mode.

## Verification workflow

- **Local, every task with code:**
```bash
scripts/test-core.sh
xcodegen generate --quiet
xcodebuild -project KickCounter.xcodeproj -scheme KickCounter \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO -quiet build-for-testing
```
  `xcodebuild` must exit 0 with no `<file>.swift:<line>:<col>: error:` lines (a bare "error: the following command failed with exit code 0" line on a first build is harmless; the existing warnings in `Motion.swift` and `KickCounterUITests.swift` are not this phase's). Do not run `xcodebuild test`. KickCore test count: 566 (before) → 610 (Task 1); Tasks 2–5 keep 610. After every task: `grep -rn "import SwiftUI\|import UIKit\|import SwiftData\|import CloudKit" Packages/KickCore/Sources` prints nothing.
- **CI** (the done condition of **every** task): commit with the task's `CI-Only-Testing:` line, `git push`, then `scripts/ci-wait.sh`. The log prints `==> UI tests: scoped to …` when the trailer applies. Screenshots land in `ci-artifacts/screenshots/<name>_0_<UUID>.png`.
- **Known flake:** a UI test occasionally times out in `waitForExistence` in an unrelated test. If CI is red **only** for that reason, rerun the failed jobs **once**:
```bash
RUN_ID="$(gh run list --workflow ci.yml --commit "$(git rev-parse HEAD)" --limit 1 --json databaseId -q '.[0].databaseId')"
gh run rerun "$RUN_ID" --failed
gh run watch "$RUN_ID" --exit-status --interval 20 > /dev/null && echo "CI PASSED"
rm -rf ci-artifacts && gh run download "$RUN_ID" --dir ci-artifacts
```
  Red again, or a failure in the task's own tests → use `superpowers:systematic-debugging`, fix, commit (keep the task's `CI-Only-Testing:` line), push again.
- **Visual check** (Tasks 2, 3 and 4): open every listed PNG with the **Read tool** and check each item of the task's list. One failed item means the task is not done.
- Never mark a task complete while CI is red. Use `superpowers:verification-before-completion` before claiming a task is done.

## Spec clarifications (decisions made while planning)

| # | Spec point | Decision |
|---|---|---|
| 1 | §3.1 `reminderKinds` `[.periodSoon, .periodLate]` | The existing `CycleReminderKind` cases are `fertile`, `period` (1 day before) and `late` (3 days late). Tracking schedules `[.period, .late]`; conceiving keeps all three. `NotificationScheduler.scheduleCycleReminders` gains `kinds:` (default: all), always cancels all three first, and `CycleCoordinator` passes `policy.reminderKinds`. Changing the goal reschedules at once (`updatePreferences`, never prompting). |
| 2 | §3.1 `headline` | The ring already leads with the next period in both goals ("Next period · N days", "Period · Day X", "N days late"): `CycleRingHeadline` is unchanged. `headline` decides the phase pill and VoiceOver's status: `.fertility` (conceiving) words every day as today ("Day 13 · Low chance of conceiving"); `.nextPeriod` (tracking) gives ordinary days no status ("Day 13 of your cycle") and fertile/ovulation days "High chance of pregnancy". Tracking therefore **never** says "Low chance of conceiving", which could be read as a contraceptive green light. |
| 3 | §3.1 hormonal | `CycleDisplayPolicy.visibleStatus(_:)` maps `.fertile`/`.peak` to `.low` when the window is hidden; the ring (`CycleRingGeometry.segments(for:policy:calendar:)`), the 7-day strip, the calendar cells, the legend and "Coming up" all go through it. `predictedBleedLabel == .withdrawalBleed` renames "Next period" (ring title, Coming up row, VoiceOver) and "Predicted period" (legend, predicted days) to "Expected bleed". Hormonal tracking also shows a short "hormonal note" in Coming up (`cycleHormonalNote`) explaining why there are no fertile days; the doctor reviews it (Task 5). The forecast itself, and so every date, is unchanged. |
| 4 | §3.1 conceiving × contraception | The policy ignores a stored contraception while trying to conceive (a user who switches goal keeps her answer for later), and onboarding's conceiving branch never saves one. |
| 5 | §3.1 `showsLHAndBBT` | Hides only the LH and BBT rows of `CycleDayLogSheet`; cervical mucus and the "Ovulation signs" title stay (the spec names only LH/BBT). A stored LH result or temperature is kept on save (the sheet's state starts from the record), still shows in the day summary and is still read by VoiceOver. |
| 6 | §3 storage | One value type, `CyclePreferences` (`goal`, `contraception`, `regularity`, `showsFertilityTests`), loads and saves the four new `SettingsKey`s: `cycleGoal`, `contraception`, `cycleRegularity`, `cycleShowsFertilityTests`. A nil contraception removes its key. Unknown raw values load as the defaults. `CycleCoordinator` publishes `preferences` and `policy` and reloads them with the settings on every `refresh()`. |
| 7 | §3.2 skips | Welcome and result have no "Skip" (they ask nothing). Skipping the goal means pregnancy, as before phase 9. The skip button reads "Not sure" on period length, cycle length and regularity, "Skip" elsewhere. A skipped length goes back to its default (5 / 28) even if the wheel was moved; a skipped regularity is `.unknown`; "Continue" on a question with nothing chosen keeps the current value (regularity `.unknown`, contraception nil). Until a goal is chosen the progress counts the longest branch (8). |
| 8 | §4.1 step 3 | "I don't remember" (`onboardingDontRemember`) and "Skip" both leave no period and move on. A new user's last-period step starts on today, as before. |
| 9 | §4.1 step 8 | `OnboardingFlow.prediction(now:calendar:)` assumes the answered period length (`CycleRules.assumedPeriod`) and runs `CyclePredictor` with the answered lengths. If the entered period is already older than one cycle the result says "may be about N days late" instead of a past date. Dates use `Formatting.longDate` ("October 20, 2026" / "20 tháng 10, 2026"). |
| 10 | §4.1 notification opt-in | Cycle branches finish through `CycleCoordinator.completeOnboarding(goal:settings:firstPeriodStart:regularity:contraception:requestNotifications:)`: "Turn on reminders" may prompt, "Later" never does (before phase 9 finishing always prompted). The pregnancy branch asks through the new `KickCoordinator.requestNotificationPermission()`. Under `-uiTesting` the disabled notification centre answers without a system prompt. |
| 11 | §4.1 pregnancy "existing ending" | The due-date step keeps its content; its old "Get started" / "Later" become "Continue" / "Skip", and the result step says "Today you are 21 weeks, 0 days pregnant." (or "You can add your due date later in Profile.") above the same two buttons. |
| 12 | §4.1 replay | Profile → "Replay the introduction" starts from the stored goal (`OnboardingGoal(mode:cycleGoal:)`), lengths, answers, period and due date and still saves nothing. The two replay UI tests walk through with Continue/Skip (`skipThroughReplayedOnboarding()`). |
| 13 | §4.3 "Mục tiêu" row vs the 3-choice picker | One control, not two: the mode card is renamed "Goal" / "Mục tiêu" and its segmented picker (identifier unchanged, `settingsModePicker`) offers "Track cycle · Trying to conceive · Pregnant" / "Theo dõi chu kỳ · Mong con · Mang thai". A second goal row would duplicate it. The contraception row (a menu with "Not set" + the 8 methods) and the LH/BBT toggle sit at the end of the cycle card, tracking only. |
| 14 | §4.3 mode picker routing | Both cycle segments call `cycle.activateCycleMode(goal:)` (also when already in the cycle mode, to change the goal); "Pregnant" opens `ImPregnantSheet` as before. Selecting the segment already shown does nothing. |
| 15 | Strings | New keys `mode.tracking` and `mode.pregnant.short` ("Mang thai", as the spec writes it); `mode.pregnant` ("Đang mang thai") stays for its other uses. Removed with `--remove` because nothing uses them any more: `onboarding.goal.cycle(.detail)`, `onboarding.cycle.shorter`/`.longer`, `onboarding.start`; `onboarding.goal.pregnant` is removed and re-added as "Pregnant" / "Đang mang thai". The conceiving card's subtitle, which the spec leaves open: "See your fertile days and ovulation" / "Biết những ngày dễ thụ thai và ngày rụng trứng". |
| 16 | §5 UI tests | Launch arguments `-seedCycleGoal <tracking\|conceiving>` and `-seedContraception <raw value>` (parsed by `UITestLaunchOptions`, applied in `AppEnvironment` only with `-uiTesting`), exposed as `launchPinned(cycleGoal:contraception:)`. Without them a seeded cycle user is a pre-phase-9 user: that is the "legacy TTC user is not re-onboarded" test. |
| 17 | §4.2 "Nothing else changes" | The late card, "Think you might be pregnant?", the irregular and long-period notices and the disclaimer stay in both goals. Partner sharing stays pregnancy-only (spec §2 out of scope). |

## File Structure

```
kick-counter/
├── Packages/KickCore/
│   ├── Sources/KickCore/
│   │   ├── CycleGoal.swift                          # T1 (new): CycleGoal, Contraception, CycleRegularity, CyclePreferences
│   │   ├── CycleDisplayPolicy.swift                 # T1 (new): what each goal × contraception shows
│   │   ├── OnboardingFlow.swift                     # T1 (new): OnboardingGoal/Step/Prediction/Outcome, OnboardingFlow
│   │   ├── CycleCoordinator.swift                   # T1: preferences, policy, updatePreferences, activateCycleMode, completeOnboarding
│   │   ├── CycleReminders.swift                     # T1: scheduleCycleReminders(kinds:)
│   │   ├── CycleRing.swift                          # T1: segments(for:policy:calendar:)
│   │   ├── KickCoordinator.swift                    # T1: requestNotificationPermission()
│   │   ├── Settings.swift                           # T1: four SettingsKeys
│   │   └── UITestLaunchOptions.swift                # T1: -seedCycleGoal, -seedContraception
│   └── Tests/KickCoreTests/
│       ├── CyclePreferencesTests.swift              # T1 (new, 5 tests)
│       ├── CycleDisplayPolicyTests.swift            # T1 (new, 6)
│       ├── OnboardingFlowTests.swift                # T1 (new, 17)
│       ├── CycleCoordinatorGoalTests.swift          # T1 (new, 10)
│       ├── KickNotificationPermissionTests.swift    # T1 (new, 2)
│       ├── CycleRemindersTests.swift                # T1: +1
│       ├── CycleRingTests.swift                     # T1: +1
│       └── UITestLaunchOptionsTests.swift           # T1: +2
├── App/
│   ├── AppEnvironment.swift                         # T1: applies the two launch arguments
│   ├── Onboarding/OnboardingView.swift              # T2: rebuilt on OnboardingFlow (hero, wave, scrim unchanged)
│   ├── Cycle/CycleCards.swift                       # T3: CycleTexts by policy, ring/strip/Coming up policy
│   ├── Cycle/CycleTodayView.swift                   # T3: reads cycle.policy
│   ├── Cycle/CycleCalendarView.swift                # T3: cells, legend, selected day, VoiceOver by policy
│   ├── Cycle/CycleDayLogSheet.swift                 # T3: LH/BBT behind showsLHAndBBT
│   └── Profile/ProfileView.swift                    # T4: Goal picker (3 choices), contraception row, LH/BBT toggle
├── Shared/{L10n.swift, Localizable.xcstrings}       # T2–T4
├── UITests/
│   ├── UITestSupport.swift                          # T2: scrollDownUntilHittable, onboarding helpers; T3: launchPinned(cycleGoal:contraception:)
│   ├── OnboardingUITests.swift                      # T2: rewritten for the new flow
│   ├── KickCounterUITests.swift, ScreenshotTests.swift, ProfileUITests.swift   # T2: walk the new onboarding
│   ├── CycleGoalUITests.swift                       # T3 (new)
│   ├── CycleGoalScreenshotTests.swift               # T3 (new)
│   └── ProfileGoalUITests.swift                     # T4 (new, with Profile screenshots)
├── README.md                                        # T5
└── docs/{content-review-for-doctor.md, release-checklist.md}   # T5
```

---
### Task 1: KickCore — goal, contraception, regularity, display policy, onboarding flow

Adds the data of spec §3 with its persistence, `CycleDisplayPolicy` (§3.1), the reminder kinds per goal, `OnboardingFlow` (§3.2), the coordinator entry points Tasks 2 and 4 call, and the two UI-test launch arguments. No screen changes: every new parameter defaults to today's behaviour, so the app looks exactly the same after this task.

**Files:**
- Create: `Packages/KickCore/Sources/KickCore/CycleGoal.swift`, `CycleDisplayPolicy.swift`, `OnboardingFlow.swift`
- Create (tests): `Packages/KickCore/Tests/KickCoreTests/CyclePreferencesTests.swift`, `CycleDisplayPolicyTests.swift`, `OnboardingFlowTests.swift`, `CycleCoordinatorGoalTests.swift`, `KickNotificationPermissionTests.swift`
- Modify: `Packages/KickCore/Sources/KickCore/Settings.swift`, `CycleReminders.swift`, `CycleRing.swift`, `CycleCoordinator.swift`, `KickCoordinator.swift`, `UITestLaunchOptions.swift`; `Packages/KickCore/Tests/KickCoreTests/CycleRemindersTests.swift`, `CycleRingTests.swift`, `UITestLaunchOptionsTests.swift`; `App/AppEnvironment.swift`

**Interfaces:**
- Consumes (existing): `CycleSettings` (`init(typicalCycleLength:typicalPeriodLength:remindersEnabled:)`, `load(from:)`, `save(to:)`, ranges `21...45` / `2...10`, defaults 28 / 5), `CycleRules.assumedPeriod(startingOn:typicalLength:today:calendar:)`, `CyclePredictor.forecast(periods:logs:settings:now:calendar:) -> CycleForecast?` (`nextPeriodStart`, `daysLate`), `CycleDayStatus` (`.period(isPredicted:)`, `.fertile`, `.peak`, `.low`), `CycleReminderKind` (`.fertile`, `.period`, `.late`), `NotificationScheduler.requestAuthorizationIfNeeded()`, `PregnancyDateSelection(source:date:)`, `AppMode`, test helpers `date(_:)`, `utcCalendar`, `makeTestDefaults()`, `FakeCycleRepository`, `FakeNotificationCenter`, `FakeSessionRepository`, `FakeLiveActivities`, `TestClock`.
- Produces (later tasks use exactly these):
  - `public enum CycleGoal: String, Sendable, CaseIterable { case tracking, conceiving }`
  - `public enum Contraception: String, Sendable, CaseIterable { case none, condom, pill, implantOrInjection, hormonalIUD, copperIUD, fertilityAwarenessOrWithdrawal, otherOrPrivate }` with `var isHormonal: Bool` (pill, implantOrInjection, hormonalIUD).
  - `public enum CycleRegularity: String, Sendable, CaseIterable { case regular, irregular, unknown }`
  - `public struct CyclePreferences: Equatable, Sendable` — `var goal: CycleGoal` (default `.conceiving`), `var contraception: Contraception?` (nil), `var regularity: CycleRegularity` (`.unknown`), `var showsFertilityTests: Bool` (false); `init(goal:contraception:regularity:showsFertilityTests:)` (all defaulted); `static func load(from: UserDefaults) -> CyclePreferences`; `func save(to: UserDefaults)`.
  - `SettingsKey.cycleGoal`, `.contraception`, `.cycleRegularity`, `.cycleShowsFertilityTests`.
  - `public struct CycleDisplayPolicy: Equatable, Sendable` — `enum FertileLabel { case fertileWindow, highPregnancyChance }`, `enum BleedLabel { case predictedPeriod, withdrawalBleed }`, `enum Headline { case fertility, nextPeriod }`; `init(goal:contraception:showsFertilityTestsOverride: = false)`, `init(_ preferences: CyclePreferences)`, `static let conceiving`; `showsFertileWindow`, `showsOvulation`, `fertileLabel`, `showsNotContraceptionNote`, `showsLHAndBBT`, `predictedBleedLabel`, `headline`, `reminderKinds: Set<CycleReminderKind>`; `func visibleStatus(_: CycleDayStatus) -> CycleDayStatus`.
  - `NotificationScheduler.scheduleCycleReminders(for:now:texts:kinds: = all, calendar:)`.
  - `CycleRingGeometry.segments(for:policy: = .conceiving, calendar:)`.
  - `CycleCoordinator`: `public private(set) var preferences: CyclePreferences`; `var policy: CycleDisplayPolicy`; `func updatePreferences(_: CyclePreferences) async`; `func activateCycleMode(goal: CycleGoal) async`; `@discardableResult func completeOnboarding(goal:settings:firstPeriodStart:regularity:contraception:requestNotifications:) async -> CycleFailure?`.
  - `KickCoordinator`: `@discardableResult func requestNotificationPermission() async -> Bool`.
  - `public enum OnboardingGoal: String, Sendable, CaseIterable { case tracking, conceiving, pregnant }` — `mode: AppMode`, `cycleGoal: CycleGoal?`, `init?(mode:cycleGoal:)`.
  - `public enum OnboardingStep: String, Sendable, CaseIterable { case welcome, goal, lastPeriod, periodLength, cycleLength, regularity, contraception, dueDate, result }`
  - `public enum OnboardingPrediction: Equatable, Sendable { case nextPeriod(Date), late(days: Int) }`
  - `public enum OnboardingOutcome: Equatable, Sendable { case cycle(goal:settings:firstPeriodStart:regularity:contraception:), pregnant(dates: PregnancyDateSelection?) }` — `mode: AppMode`.
  - `public struct OnboardingFlow: Equatable, Sendable` — `step` (`public private(set)`), `goal`, `lastPeriodStart`, `periodLength`, `cycleLength`, `regularity`, `contraception`, `pregnancyDates`, `remindersEnabled` (let); `init(goal: = nil, lastPeriodStart:settings: = CycleSettings(), regularity: = .unknown, contraception: = nil, pregnancyDates:)`; `static func steps(for:) -> [OnboardingStep]`; `steps`, `stepNumber`, `stepCount`, `isQuestion`, `canGoBack`, `canContinue`, `settings`; `mutating func next()`, `back()`, `skip()`; `func prediction(now:calendar:) -> OnboardingPrediction?`; `func finish() -> OnboardingOutcome`.
  - `UITestLaunchOptions.seedCycleGoal: CycleGoal?`, `.seedContraception: Contraception?`.

- [ ] **Step 1: Write the failing tests for the preferences and the policy**

Create `Packages/KickCore/Tests/KickCoreTests/CyclePreferencesTests.swift`:
```swift
import Foundation
import Testing
@testable import KickCore

/// Phase 9 spec §3: the cycle goal, contraception and regularity in the App Group defaults.
struct CyclePreferencesTests {
    @Test func nothingStoredMeansConceivingForExistingUsers() {
        let defaults = makeTestDefaults()
        AppMode.save(.tryingToConceive, to: defaults)
        CycleSettings(typicalCycleLength: 30).save(to: defaults)
        #expect(CyclePreferences.load(from: defaults) == CyclePreferences(
            goal: .conceiving, contraception: nil, regularity: .unknown, showsFertilityTests: false
        ))
    }

    @Test func everyValueRoundTrips() {
        let defaults = makeTestDefaults()
        let preferences = CyclePreferences(goal: .tracking, contraception: .copperIUD, regularity: .irregular, showsFertilityTests: true)
        preferences.save(to: defaults)
        #expect(defaults.string(forKey: SettingsKey.cycleGoal) == "tracking")
        #expect(defaults.string(forKey: SettingsKey.contraception) == "copperIUD")
        #expect(defaults.string(forKey: SettingsKey.cycleRegularity) == "irregular")
        #expect(defaults.bool(forKey: SettingsKey.cycleShowsFertilityTests))
        #expect(CyclePreferences.load(from: defaults) == preferences)
    }

    @Test func savingNoContraceptionRemovesTheStoredOne() {
        let defaults = makeTestDefaults()
        CyclePreferences(goal: .tracking, contraception: .pill).save(to: defaults)
        CyclePreferences(goal: .tracking, contraception: nil).save(to: defaults)
        #expect(defaults.object(forKey: SettingsKey.contraception) == nil)
        #expect(CyclePreferences.load(from: defaults).contraception == nil)
    }

    @Test func unknownStoredValuesFallBackToTheDefaults() {
        let defaults = makeTestDefaults()
        defaults.set("avoiding", forKey: SettingsKey.cycleGoal)
        defaults.set("patch", forKey: SettingsKey.contraception)
        defaults.set("sometimes", forKey: SettingsKey.cycleRegularity)
        #expect(CyclePreferences.load(from: defaults) == CyclePreferences())
    }

    @Test func onlyThePillImplantInjectionAndHormonalIUDAreHormonal() {
        let hormonal = Contraception.allCases.filter(\.isHormonal)
        #expect(hormonal == [.pill, .implantOrInjection, .hormonalIUD])
        #expect(Contraception.allCases.count == 8)
    }
}
```

Create `Packages/KickCore/Tests/KickCoreTests/CycleDisplayPolicyTests.swift`:
```swift
import Foundation
import Testing
@testable import KickCore

/// Phase 9 spec §3.1: what each goal × contraception shows.
struct CycleDisplayPolicyTests {
    @Test func conceivingShowsEverythingWhateverTheContraception() {
        for contraception in [nil] + Contraception.allCases.map(Optional.some) {
            let policy = CycleDisplayPolicy(goal: .conceiving, contraception: contraception)
            #expect(policy.showsFertileWindow)
            #expect(policy.showsOvulation)
            #expect(policy.fertileLabel == .fertileWindow)
            #expect(policy.showsNotContraceptionNote == false)
            #expect(policy.showsLHAndBBT)
            #expect(policy.predictedBleedLabel == .predictedPeriod)
            #expect(policy.headline == .fertility)
            #expect(policy.reminderKinds == [.fertile, .period, .late])
        }
    }

    @Test func trackingWithoutHormonalContraceptionLabelsTheWindowAndWarns() {
        let nonHormonal: [Contraception?] = [nil, .none, .condom, .copperIUD, .fertilityAwarenessOrWithdrawal, .otherOrPrivate]
        for contraception in nonHormonal {
            let policy = CycleDisplayPolicy(goal: .tracking, contraception: contraception)
            #expect(policy.showsFertileWindow)
            #expect(policy.showsOvulation)
            #expect(policy.fertileLabel == .highPregnancyChance)
            #expect(policy.showsNotContraceptionNote)
            #expect(policy.showsLHAndBBT == false)
            #expect(policy.predictedBleedLabel == .predictedPeriod)
            #expect(policy.headline == .nextPeriod)
            #expect(policy.reminderKinds == [.period, .late])
        }
    }

    @Test func trackingWithHormonalContraceptionHidesTheWindow() {
        for contraception in [Contraception.pill, .implantOrInjection, .hormonalIUD] {
            let policy = CycleDisplayPolicy(goal: .tracking, contraception: contraception)
            #expect(policy.showsFertileWindow == false)
            #expect(policy.showsOvulation == false)
            #expect(policy.showsNotContraceptionNote == false)
            #expect(policy.showsLHAndBBT == false)
            #expect(policy.predictedBleedLabel == .withdrawalBleed)
            #expect(policy.headline == .nextPeriod)
            #expect(policy.reminderKinds == [.period, .late])
        }
    }

    @Test func theProfileOverrideShowsLHAndBBTWhileTracking() {
        let policy = CycleDisplayPolicy(goal: .tracking, contraception: .pill, showsFertilityTestsOverride: true)
        #expect(policy.showsLHAndBBT)
        #expect(CycleDisplayPolicy(CyclePreferences(goal: .tracking, showsFertilityTests: true)).showsLHAndBBT)
    }

    @Test func hiddenFertileDaysLookLikeAnyOtherDay() {
        let hormonal = CycleDisplayPolicy(goal: .tracking, contraception: .hormonalIUD)
        #expect(hormonal.visibleStatus(.fertile) == .low)
        #expect(hormonal.visibleStatus(.peak) == .low)
        #expect(hormonal.visibleStatus(.period(isPredicted: true)) == .period(isPredicted: true))
        #expect(hormonal.visibleStatus(.low) == .low)
        let tracking = CycleDisplayPolicy(goal: .tracking, contraception: .condom)
        #expect(tracking.visibleStatus(.peak) == .peak)
        #expect(CycleDisplayPolicy.conceiving.visibleStatus(.fertile) == .fertile)
    }

    @Test func thePolicyComesFromThePreferences() {
        let preferences = CyclePreferences(goal: .tracking, contraception: .pill, regularity: .regular)
        #expect(CycleDisplayPolicy(preferences) == CycleDisplayPolicy(goal: .tracking, contraception: .pill))
        #expect(CycleDisplayPolicy(CyclePreferences()) == .conceiving)
    }
}
```

- [ ] **Step 2: Write the failing tests for the onboarding flow**

The pinned "now" is 2026-10-02 12:00 UTC, like the UI tests. 2026-09-20 + 30 days = 2026-10-20; 2026-08-30 + 28 days = 2026-09-27, 5 days before now.

Create `Packages/KickCore/Tests/KickCoreTests/OnboardingFlowTests.swift`:
```swift
import Foundation
import Testing
@testable import KickCore

/// Phase 9 spec §3.2: step order, skips, "I don't remember" and what is saved.
struct OnboardingFlowTests {
    private let now = date("2026-10-02T12:00:00Z")
    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00Z") }

    private func newFlow() -> OnboardingFlow {
        OnboardingFlow(lastPeriodStart: day("2026-10-02"), pregnancyDates: PregnancyDateSelection(source: .dueDate, date: day("2027-02-19")))
    }

    /// Walks with "Continue" and records every step.
    private func walk(_ flow: inout OnboardingFlow) -> [OnboardingStep] {
        var seen = [flow.step]
        while flow.step != .result {
            flow.next()
            seen.append(flow.step)
        }
        return seen
    }

    @Test func eachGoalHasItsOwnSteps() {
        #expect(OnboardingFlow.steps(for: .tracking) == [.welcome, .goal, .lastPeriod, .periodLength, .cycleLength, .regularity, .contraception, .result])
        #expect(OnboardingFlow.steps(for: .conceiving) == [.welcome, .goal, .lastPeriod, .periodLength, .cycleLength, .regularity, .result])
        #expect(OnboardingFlow.steps(for: .pregnant) == [.welcome, .goal, .dueDate, .result])
    }

    @Test func continueFollowsTheChosenBranch() {
        for goal in OnboardingGoal.allCases {
            var flow = newFlow()
            flow.next()
            flow.goal = goal
            #expect(walk(&flow) == Array(OnboardingFlow.steps(for: goal).dropFirst()))
            #expect(flow.stepNumber == flow.stepCount)
        }
    }

    @Test func theGoalStepNeedsAnAnswerToContinue() {
        var flow = newFlow()
        flow.next()
        #expect(flow.step == .goal)
        #expect(flow.canContinue == false)
        flow.next()
        #expect(flow.step == .goal)
        flow.goal = .conceiving
        flow.next()
        #expect(flow.step == .lastPeriod)
    }

    @Test func progressCountsTheLongestBranchUntilAGoalIsChosen() {
        var flow = newFlow()
        #expect(flow.stepNumber == 1)
        #expect(flow.stepCount == 8)
        flow.next()
        flow.goal = .pregnant
        #expect(flow.stepNumber == 2)
        #expect(flow.stepCount == 4)
    }

    @Test func backReturnsToThePreviousStepAndStopsAtWelcome() {
        var flow = newFlow()
        #expect(flow.canGoBack == false)
        flow.back()
        #expect(flow.step == .welcome)
        flow.next()
        flow.goal = .tracking
        flow.next()
        flow.next()
        #expect(flow.step == .periodLength)
        flow.back()
        #expect(flow.step == .lastPeriod)
    }

    @Test func onlyQuestionStepsCanBeSkipped() {
        var flow = newFlow()
        #expect(flow.isQuestion == false)
        flow.skip()
        #expect(flow.step == .welcome)
        flow.next()
        #expect(flow.isQuestion)
    }

    @Test func skippingTheGoalMeansPregnancy() {
        var flow = newFlow()
        flow.next()
        flow.skip()
        #expect(flow.goal == .pregnant)
        #expect(flow.step == .dueDate)
    }

    @Test func skippedAnswersKeepTheirDefaults() {
        var flow = newFlow()
        flow.next()
        flow.goal = .tracking
        flow.next()
        flow.skip() // last period
        flow.periodLength = 7
        flow.skip()
        flow.cycleLength = 35
        flow.skip()
        flow.regularity = .irregular
        flow.skip()
        flow.contraception = .pill
        flow.skip()
        #expect(flow.step == .result)
        #expect(flow.finish() == .cycle(
            goal: .tracking, settings: CycleSettings(), firstPeriodStart: nil, regularity: .unknown, contraception: nil
        ))
    }

    @Test func dontRememberLeavesNoPeriodAndNoPrediction() {
        var flow = newFlow()
        flow.lastPeriodStart = nil
        #expect(flow.prediction(now: now, calendar: utcCalendar) == nil)
    }

    @Test func thePredictionUsesTheAnsweredLengths() {
        var flow = newFlow()
        flow.lastPeriodStart = day("2026-09-20")
        flow.cycleLength = 30
        #expect(flow.prediction(now: now, calendar: utcCalendar) == .nextPeriod(day("2026-10-20")))
    }

    @Test func aPeriodOlderThanOneCycleIsLate() {
        var flow = newFlow()
        flow.lastPeriodStart = day("2026-08-30")
        #expect(flow.prediction(now: now, calendar: utcCalendar) == .late(days: 5))
    }

    @Test func lengthsStayInTheirRanges() {
        var flow = newFlow()
        flow.periodLength = 1
        flow.cycleLength = 60
        #expect(flow.periodLength == 2)
        #expect(flow.cycleLength == 45)
    }

    @Test func trackingFinishesWithEveryAnswer() {
        var flow = newFlow()
        flow.goal = .tracking
        flow.lastPeriodStart = day("2026-09-20")
        flow.periodLength = 4
        flow.cycleLength = 31
        flow.regularity = .regular
        flow.contraception = .condom
        #expect(flow.finish() == .cycle(
            goal: .tracking,
            settings: CycleSettings(typicalCycleLength: 31, typicalPeriodLength: 4),
            firstPeriodStart: day("2026-09-20"),
            regularity: .regular,
            contraception: .condom
        ))
        #expect(flow.finish().mode == .tryingToConceive)
    }

    @Test func conceivingNeverSavesAContraception() {
        var flow = newFlow()
        flow.goal = .conceiving
        flow.contraception = .pill
        guard case .cycle(let goal, _, _, _, let contraception) = flow.finish() else {
            Issue.record("expected the cycle branch")
            return
        }
        #expect(goal == .conceiving)
        #expect(contraception == nil)
    }

    @Test func pregnancyFinishesWithTheDatesOrNone() {
        var flow = newFlow()
        flow.goal = .pregnant
        #expect(flow.finish() == .pregnant(dates: PregnancyDateSelection(source: .dueDate, date: day("2027-02-19"))))
        #expect(flow.finish().mode == .pregnant)
        flow.next()
        flow.next()
        #expect(flow.step == .dueDate)
        flow.skip()
        #expect(flow.finish() == .pregnant(dates: nil))
    }

    @Test func remindersSettingIsKept() {
        let flow = OnboardingFlow(lastPeriodStart: nil, settings: CycleSettings(remindersEnabled: false), pregnancyDates: nil)
        #expect(flow.settings.remindersEnabled == false)
    }

    @Test func replayStartsFromTheStoredGoal() {
        #expect(OnboardingGoal(mode: .tryingToConceive, cycleGoal: .tracking) == .tracking)
        #expect(OnboardingGoal(mode: .tryingToConceive, cycleGoal: .conceiving) == .conceiving)
        #expect(OnboardingGoal(mode: .pregnant, cycleGoal: .tracking) == .pregnant)
        #expect(OnboardingGoal(mode: .partner, cycleGoal: .conceiving) == nil)
        #expect(OnboardingGoal.tracking.cycleGoal == .tracking)
        #expect(OnboardingGoal.pregnant.cycleGoal == nil)
        #expect(OnboardingGoal.conceiving.mode == .tryingToConceive)
    }
}
```

- [ ] **Step 3: Write the failing tests for the coordinator, the reminder kinds, the ring, the launch arguments and the permission request**

Create `Packages/KickCore/Tests/KickCoreTests/CycleCoordinatorGoalTests.swift` (its own fixture, so `CycleCoordinatorTests.swift` stays as it is):
```swift
import Foundation
import Testing
@preconcurrency import UserNotifications
@testable import KickCore

/// Phase 9: the goal in the coordinator — reminders per goal, Profile's goal
/// and mode choices, and finishing onboarding.
@MainActor
struct CycleCoordinatorGoalTests {
    let repository: FakeCycleRepository
    let center: FakeNotificationCenter
    let defaults: UserDefaults
    let coordinator: CycleCoordinator

    init() {
        let repository = FakeCycleRepository()
        let center = FakeNotificationCenter()
        let clock = TestClock(date("2026-09-05T12:00:00Z"))
        let defaults = makeTestDefaults()
        AppMode.save(.tryingToConceive, to: defaults)
        self.repository = repository
        self.center = center
        self.defaults = defaults
        coordinator = CycleCoordinator(
            store: repository,
            notifications: NotificationScheduler(center: center),
            reminderTexts: CycleReminderTexts(
                fertile: NotificationText(title: "Fertile window soon", body: "In 2 days"),
                period: NotificationText(title: "Period tomorrow", body: "Due tomorrow"),
                late: NotificationText(title: "Period is late", body: "Consider a test")
            ),
            defaults: defaults,
            calendar: utcCalendar,
            now: { clock.now }
        )
    }

    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00Z") }

    /// Regular 28-day cycles; current period 2026-09-03 → next period 10-01.
    private func seedRegularCycles() {
        repository.seed(periods: ["2026-07-09", "2026-08-06", "2026-09-03"].map {
            PeriodRecord(startDate: day($0), endDate: utcCalendar.date(byAdding: .day, value: 4, to: day($0)))
        })
    }

    private var reminderIDs: Set<String> { Set(center.added.map(\.identifier)) }

    @Test func existingUsersKeepConceivingAndAllThreeReminders() async {
        seedRegularCycles()
        await coordinator.load()
        #expect(coordinator.preferences.goal == .conceiving)
        #expect(coordinator.policy == .conceiving)
        #expect(reminderIDs == ["cycle-fertile", "cycle-period", "cycle-late"])
    }

    @Test func trackingSchedulesOnlyThePeriodReminders() async {
        CyclePreferences(goal: .tracking).save(to: defaults)
        seedRegularCycles()
        await coordinator.load()
        #expect(coordinator.policy.goal == .tracking)
        #expect(reminderIDs == ["cycle-period", "cycle-late"])
    }

    @Test func changingTheGoalReschedulesWithoutPrompting() async {
        seedRegularCycles()
        await coordinator.load()
        center.status = .authorized
        await coordinator.updatePreferences(CyclePreferences(goal: .tracking, contraception: .pill))
        #expect(coordinator.preferences.contraception == .pill)
        #expect(CyclePreferences.load(from: defaults).goal == .tracking)
        #expect(reminderIDs == ["cycle-period", "cycle-late"])
        await coordinator.updatePreferences(CyclePreferences(goal: .conceiving))
        #expect(reminderIDs == ["cycle-fertile", "cycle-period", "cycle-late"])
        #expect(center.requestCount == 0)
    }

    @Test func choosingACycleGoalFromPregnancySwitchesModeAndKeepsTheOtherAnswers() async {
        AppMode.save(.pregnant, to: defaults)
        CyclePreferences(goal: .conceiving, contraception: .copperIUD, regularity: .regular).save(to: defaults)
        seedRegularCycles()
        await coordinator.load()
        #expect(center.added.isEmpty)

        await coordinator.activateCycleMode(goal: .tracking)

        #expect(coordinator.mode == .tryingToConceive)
        #expect(coordinator.preferences == CyclePreferences(goal: .tracking, contraception: .copperIUD, regularity: .regular))
        #expect(reminderIDs == ["cycle-period", "cycle-late"])
    }

    @Test func endingThePregnancyKeepsTheStoredGoal() async {
        AppMode.save(.pregnant, to: defaults)
        CyclePreferences(goal: .tracking).save(to: defaults)
        await coordinator.activateTryingToConceive()
        #expect(coordinator.preferences.goal == .tracking)
    }

    @Test func finishingOnboardingStoresEveryAnswerAndThePeriod() async throws {
        AppMode.save(.pregnant, to: defaults)
        let failure = await coordinator.completeOnboarding(
            goal: .tracking,
            settings: CycleSettings(typicalCycleLength: 30, typicalPeriodLength: 4),
            firstPeriodStart: day("2026-08-30"),
            regularity: .irregular,
            contraception: .condom,
            requestNotifications: true
        )
        #expect(failure == nil)
        #expect(coordinator.mode == .tryingToConceive)
        #expect(coordinator.settings == CycleSettings(typicalCycleLength: 30, typicalPeriodLength: 4))
        #expect(CyclePreferences.load(from: defaults) == CyclePreferences(goal: .tracking, contraception: .condom, regularity: .irregular))
        let period = try #require(repository.storedPeriods.first)
        #expect(period.startDate == day("2026-08-30"))
        #expect(period.endDate == day("2026-09-02"))
        #expect(coordinator.forecast?.nextPeriodStart == day("2026-09-29"))
        #expect(center.requestCount == 0) // already authorized: nothing to ask
        #expect(reminderIDs == ["cycle-period", "cycle-late"])
    }

    @Test func turnOnRemindersAsksForPermission() async {
        center.status = .notDetermined
        await coordinator.completeOnboarding(
            goal: .conceiving, settings: CycleSettings(), firstPeriodStart: day("2026-09-03"),
            regularity: .unknown, contraception: nil, requestNotifications: true
        )
        #expect(center.requestCount == 1)
        #expect(reminderIDs == ["cycle-fertile", "cycle-period", "cycle-late"])
    }

    @Test func laterNeverAsksForPermission() async {
        center.status = .notDetermined
        await coordinator.completeOnboarding(
            goal: .conceiving, settings: CycleSettings(), firstPeriodStart: day("2026-09-03"),
            regularity: .unknown, contraception: nil, requestNotifications: false
        )
        #expect(center.requestCount == 0)
        #expect(center.added.isEmpty)
        #expect(coordinator.periods.count == 1)
    }

    @Test func finishingWithoutAPeriodHasNoForecast() async {
        await coordinator.completeOnboarding(
            goal: .tracking, settings: CycleSettings(), firstPeriodStart: nil,
            regularity: .unknown, contraception: nil, requestNotifications: true
        )
        #expect(coordinator.forecast == nil)
        #expect(repository.storedPeriods.isEmpty)
        #expect(coordinator.mode == .tryingToConceive)
    }

    @Test func aFailedPeriodSaveIsReturnedAndTheAnswersAreKept() async {
        repository.failNextWrite = true
        let failure = await coordinator.completeOnboarding(
            goal: .tracking, settings: CycleSettings(typicalCycleLength: 33), firstPeriodStart: day("2026-09-03"),
            regularity: .regular, contraception: nil, requestNotifications: false
        )
        #expect(failure == .saveFailed)
        #expect(coordinator.failure == .saveFailed)
        #expect(coordinator.settings.typicalCycleLength == 33)
        #expect(coordinator.preferences.goal == .tracking)
        #expect(coordinator.mode == .tryingToConceive)
    }
}
```

Create `Packages/KickCore/Tests/KickCoreTests/KickNotificationPermissionTests.swift`:
```swift
import Foundation
import Testing
@preconcurrency import UserNotifications
@testable import KickCore

/// Phase 9: the pregnancy branch's "Turn on reminders" on the result step.
@MainActor
struct KickNotificationPermissionTests {
    private func makeCoordinator(_ center: FakeNotificationCenter) -> KickCoordinator {
        KickCoordinator(
            store: FakeSessionRepository(),
            notifications: NotificationScheduler(center: center),
            liveActivities: FakeLiveActivities(),
            overdueText: NotificationText(title: "Overdue", body: "Call your doctor")
        )
    }

    @Test func asksOnceWhenNeverAsked() async {
        let center = FakeNotificationCenter()
        center.status = .notDetermined
        #expect(await makeCoordinator(center).requestNotificationPermission())
        #expect(center.requestCount == 1)
    }

    @Test func neverAsksAgainAfterARefusal() async {
        let center = FakeNotificationCenter()
        center.status = .denied
        #expect(await makeCoordinator(center).requestNotificationPermission() == false)
        #expect(center.requestCount == 0)
    }
}
```

In `Packages/KickCore/Tests/KickCoreTests/CycleRemindersTests.swift`:

Replace:

```swift
    }

    @Test func remindersWhoseTimeHasPassedAreSkipped() async throws {
        // 2026-09-10 at 09:00 exactly: the fertile reminder is not in the future.
```

with:

```swift
    }

    /// Phase 9: tracking schedules only the kinds it asks for; the others are cancelled.
    @Test func onlyTheRequestedKindsAreScheduled() async throws {
        try await scheduler.scheduleCycleReminders(for: try regularForecast(), now: date("2026-09-05T12:00:00Z"), texts: texts, calendar: utcCalendar)
        let scheduled = try await scheduler.scheduleCycleReminders(
            for: try regularForecast(), now: date("2026-09-05T12:00:00Z"), texts: texts, kinds: [.period, .late], calendar: utcCalendar
        )
        #expect(scheduled == [.period, .late])
        #expect(Set(center.added.map(\.identifier)) == ["cycle-period", "cycle-late"])
    }

    @Test func remindersWhoseTimeHasPassedAreSkipped() async throws {
        // 2026-09-10 at 09:00 exactly: the fertile reminder is not in the future.
```

In `Packages/KickCore/Tests/KickCoreTests/CycleRingTests.swift`:

Replace:

```swift
        ]
        #expect(segments == expected.map { CycleRingSegment(kind: $0.0, start: Double($0.1) / 28, end: Double($0.2) / 28) })
    }
```

with:

```swift
        ]
        #expect(segments == expected.map { CycleRingSegment(kind: $0.0, start: Double($0.1) / 28, end: Double($0.2) / 28) })
    }

    /// Phase 9: hormonal contraception hides the fertile window on the ring too.
    @Test func aHiddenFertileWindowLeavesOnlyPeriodAndBase() throws {
        let policy = CycleDisplayPolicy(goal: .tracking, contraception: .pill)
        let segments = CycleRingGeometry.segments(for: try forecast(on: "2026-09-05"), policy: policy, calendar: utcCalendar)
        #expect(segments == [CycleRingSegment(kind: .period, start: 0, end: 5.0 / 28), CycleRingSegment(kind: .base, start: 5.0 / 28, end: 1)])
    }
```

Append to `Packages/KickCore/Tests/KickCoreTests/UITestLaunchOptionsTests.swift`:
```swift
struct UITestCycleGoalOptionTests {
    @Test func parsesTheGoalAndContraceptionWhenUITesting() {
        let options = UITestLaunchOptions(arguments: ["-uiTesting", "-seedCycleGoal", "tracking", "-seedContraception", "pill"])
        #expect(options.seedCycleGoal == .tracking)
        #expect(options.seedContraception == .pill)
    }

    @Test func ignoresThemWithoutUITestingOrWhenUnknown() {
        #expect(UITestLaunchOptions(arguments: ["-seedCycleGoal", "tracking"]).seedCycleGoal == nil)
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-seedCycleGoal", "avoiding"]).seedCycleGoal == nil)
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-seedContraception", "patch"]).seedContraception == nil)
    }
}
```

- [ ] **Step 4: Run the tests to see them fail**

Run: `scripts/test-core.sh`
Expected: the build fails with errors such as `cannot find 'CyclePreferences' in scope`, `cannot find type 'OnboardingFlow' in scope` and `extra argument 'kinds' in call`.

- [ ] **Step 5: Add the goal, contraception, regularity and their keys**

Create `Packages/KickCore/Sources/KickCore/CycleGoal.swift`:
```swift
import Foundation

/// What the cycle mode is for (phase 9 spec §3): following the cycle, or trying
/// to conceive. Same data, calendar and predictions; only the presentation changes.
public enum CycleGoal: String, Sendable, CaseIterable {
    case tracking
    case conceiving
}

/// The contraception the mother uses, asked on the tracking branch only.
/// The app only tracks it: it changes what Today and the calendar show.
public enum Contraception: String, Sendable, CaseIterable {
    case none
    case condom
    case pill
    case implantOrInjection
    case hormonalIUD
    case copperIUD
    case fertilityAwarenessOrWithdrawal
    case otherOrPrivate

    /// Hormonal methods usually stop ovulation, so the fertile window and
    /// ovulation are hidden and the bleed is a withdrawal bleed.
    public var isHormonal: Bool {
        switch self {
        case .pill, .implantOrInjection, .hormonalIUD: true
        case .none, .condom, .copperIUD, .fertilityAwarenessOrWithdrawal, .otherOrPrivate: false
        }
    }
}

public enum CycleRegularity: String, Sendable, CaseIterable {
    case regular
    case irregular
    case unknown
}

/// The cycle mode's goal and answers, kept in `AppGroup.defaults` next to
/// `CycleSettings` (not synced). Every value loads with a default:
/// - `goal`: `.conceiving`, so cycle-mode users from before phase 9 keep today's behaviour;
/// - `contraception`: nil (not asked), treated like `.none`;
/// - `regularity`: `.unknown`;
/// - `showsFertilityTests`: false (Profile's "Show ovulation tests & temperature").
public struct CyclePreferences: Equatable, Sendable {
    public var goal: CycleGoal
    public var contraception: Contraception?
    public var regularity: CycleRegularity
    /// Shows the LH test and BBT rows in the day log while tracking.
    public var showsFertilityTests: Bool

    public init(
        goal: CycleGoal = .conceiving,
        contraception: Contraception? = nil,
        regularity: CycleRegularity = .unknown,
        showsFertilityTests: Bool = false
    ) {
        self.goal = goal
        self.contraception = contraception
        self.regularity = regularity
        self.showsFertilityTests = showsFertilityTests
    }

    public static func load(from defaults: UserDefaults) -> CyclePreferences {
        CyclePreferences(
            goal: defaults.string(forKey: SettingsKey.cycleGoal).flatMap(CycleGoal.init(rawValue:)) ?? .conceiving,
            contraception: defaults.string(forKey: SettingsKey.contraception).flatMap(Contraception.init(rawValue:)),
            regularity: defaults.string(forKey: SettingsKey.cycleRegularity).flatMap(CycleRegularity.init(rawValue:)) ?? .unknown,
            showsFertilityTests: defaults.bool(forKey: SettingsKey.cycleShowsFertilityTests)
        )
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(goal.rawValue, forKey: SettingsKey.cycleGoal)
        if let contraception {
            defaults.set(contraception.rawValue, forKey: SettingsKey.contraception)
        } else {
            defaults.removeObject(forKey: SettingsKey.contraception)
        }
        defaults.set(regularity.rawValue, forKey: SettingsKey.cycleRegularity)
        defaults.set(showsFertilityTests, forKey: SettingsKey.cycleShowsFertilityTests)
    }
}
```

In `Packages/KickCore/Sources/KickCore/Settings.swift`:

Replace:

```swift
    /// Fertile-window, period and late-period reminders. Missing means on.
    public static let cycleRemindersEnabled = "cycleRemindersEnabled"
    /// `AppLanguage` raw value (`"system"`, `"vi"`, `"en"`). Missing means `system`.
    public static let appLanguage = "appLanguage"
```

with:

```swift
    /// Fertile-window, period and late-period reminders. Missing means on.
    public static let cycleRemindersEnabled = "cycleRemindersEnabled"
    /// `CycleGoal` raw value (`"tracking"`, `"conceiving"`). Missing means conceiving (everyone before phase 9).
    public static let cycleGoal = "cycleGoal"
    /// `Contraception` raw value. Missing means not asked (treated like none).
    public static let contraception = "contraception"
    /// `CycleRegularity` raw value. Missing means unknown.
    public static let cycleRegularity = "cycleRegularity"
    /// Shows the LH test and BBT rows while tracking. Missing means off.
    public static let cycleShowsFertilityTests = "cycleShowsFertilityTests"
    /// `AppLanguage` raw value (`"system"`, `"vi"`, `"en"`). Missing means `system`.
    public static let appLanguage = "appLanguage"
```

- [ ] **Step 6: Add the display policy, the reminder kinds and the ring's policy**

Create `Packages/KickCore/Sources/KickCore/CycleDisplayPolicy.swift`:
```swift
import Foundation

/// What the cycle screens show for a goal and a contraception (phase 9 spec §3.1).
/// Today, the calendar, the day log and the reminders all read it; the forecast
/// itself never changes.
public struct CycleDisplayPolicy: Equatable, Sendable {
    /// The fertile window's name: "Fertile window" while trying to conceive,
    /// "High chance of pregnancy" while tracking.
    public enum FertileLabel: Equatable, Sendable {
        case fertileWindow
        case highPregnancyChance
    }

    /// The predicted bleed's name: a withdrawal bleed on hormonal contraception.
    public enum BleedLabel: Equatable, Sendable {
        case predictedPeriod
        case withdrawalBleed
    }

    /// Today's phase line: the chance of conceiving for every day (`fertility`),
    /// or only the cycle day, with a status on period and fertile days (`nextPeriod`).
    public enum Headline: Equatable, Sendable {
        case fertility
        case nextPeriod
    }

    public let goal: CycleGoal
    public let contraception: Contraception?
    public let showsFertilityTestsOverride: Bool

    public init(goal: CycleGoal, contraception: Contraception?, showsFertilityTestsOverride: Bool = false) {
        self.goal = goal
        self.contraception = contraception
        self.showsFertilityTestsOverride = showsFertilityTestsOverride
    }

    public init(_ preferences: CyclePreferences) {
        self.init(
            goal: preferences.goal,
            contraception: preferences.contraception,
            showsFertilityTestsOverride: preferences.showsFertilityTests
        )
    }

    /// Before phase 9 every cycle-mode user saw this.
    public static let conceiving = CycleDisplayPolicy(goal: .conceiving, contraception: nil)

    /// Only while tracking: trying to conceive ignores a stored contraception.
    private var isHormonal: Bool { goal == .tracking && contraception?.isHormonal == true }

    public var showsFertileWindow: Bool { !isHormonal }
    public var showsOvulation: Bool { !isHormonal }
    public var fertileLabel: FertileLabel { goal == .conceiving ? .fertileWindow : .highPregnancyChance }
    public var showsNotContraceptionNote: Bool { goal == .tracking && !isHormonal }
    /// The LH test and BBT rows of the day log.
    public var showsLHAndBBT: Bool { goal == .conceiving || showsFertilityTestsOverride }
    public var predictedBleedLabel: BleedLabel { isHormonal ? .withdrawalBleed : .predictedPeriod }
    public var headline: Headline { goal == .conceiving ? .fertility : .nextPeriod }

    /// Tracking: only "period due tomorrow" and "period late".
    public var reminderKinds: Set<CycleReminderKind> {
        goal == .conceiving ? Set(CycleReminderKind.allCases) : [.period, .late]
    }

    /// A day's colour and wording on screen: fertile and ovulation days look
    /// like any other day when the fertile window is hidden.
    public func visibleStatus(_ status: CycleDayStatus) -> CycleDayStatus {
        switch status {
        case .fertile, .peak: showsFertileWindow ? status : .low
        case .period, .low: status
        }
    }
}
```

In `Packages/KickCore/Sources/KickCore/CycleReminders.swift`:

Replace:

```swift
    }

    /// Replaces all three cycle reminders with those for `forecast` whose time is
    /// still ahead of `now`. Returns the kinds that were scheduled.
    @discardableResult
    public func scheduleCycleReminders(
```

with:

```swift
    }

    /// Replaces all three cycle reminders with those of `kinds` for `forecast`
    /// whose time is still ahead of `now` (the others stay cancelled). Returns
    /// the kinds that were scheduled.
    @discardableResult
    public func scheduleCycleReminders(
```

Replace:

```swift
        now: Date,
        texts: CycleReminderTexts,
        calendar: Calendar = .current
    ) async throws -> Set<CycleReminderKind> {
```

with:

```swift
        now: Date,
        texts: CycleReminderTexts,
        kinds: Set<CycleReminderKind> = Set(CycleReminderKind.allCases),
        calendar: Calendar = .current
    ) async throws -> Set<CycleReminderKind> {
```

Replace:

```swift
        let fireDates = Self.cycleReminderFireDates(for: forecast, calendar: calendar)
        var scheduled: Set<CycleReminderKind> = []
        for kind in CycleReminderKind.allCases {
            guard let fireDate = fireDates[kind], fireDate > now else { continue }
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
```

with:

```swift
        let fireDates = Self.cycleReminderFireDates(for: forecast, calendar: calendar)
        var scheduled: Set<CycleReminderKind> = []
        for kind in CycleReminderKind.allCases where kinds.contains(kind) {
            guard let fireDate = fireDates[kind], fireDate > now else { continue }
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
```

In `Packages/KickCore/Sources/KickCore/CycleRing.swift`:

Replace:

```swift

    /// Consecutive days with the same colour merged into one segment, from day 1.
    public static func segments(for forecast: CycleForecast, calendar: Calendar = .current) -> [CycleRingSegment] {
        let length = length(of: forecast)
        var segments: [CycleRingSegment] = []
```

with:

```swift

    /// Consecutive days with the same colour merged into one segment, from day 1.
    /// `policy` hides the fertile window (hormonal contraception, phase 9).
    public static func segments(
        for forecast: CycleForecast,
        policy: CycleDisplayPolicy = .conceiving,
        calendar: Calendar = .current
    ) -> [CycleRingSegment] {
        let length = length(of: forecast)
        var segments: [CycleRingSegment] = []
```

Replace:

```swift
            let kind: CycleRingKind? = index == length ? nil : calendar
                .date(byAdding: .day, value: index, to: forecast.currentPeriodStart)
                .map { CycleRingKind(forecast.dayStatus(for: $0)) }
            if kind != runKind || index == length {
                if let runKind, index > runStart {
```

with:

```swift
            let kind: CycleRingKind? = index == length ? nil : calendar
                .date(byAdding: .day, value: index, to: forecast.currentPeriodStart)
                .map { CycleRingKind(policy.visibleStatus(forecast.dayStatus(for: $0))) }
            if kind != runKind || index == length {
                if let runKind, index > runStart {
```

- [ ] **Step 7: Add the onboarding flow**

Create `Packages/KickCore/Sources/KickCore/OnboardingFlow.swift`:
```swift
import Foundation

/// The first question of onboarding (phase 9 spec §4.1, step 2).
public enum OnboardingGoal: String, Sendable, CaseIterable {
    case tracking
    case conceiving
    case pregnant

    public var mode: AppMode { self == .pregnant ? .pregnant : .tryingToConceive }

    /// nil for pregnancy.
    public var cycleGoal: CycleGoal? {
        switch self {
        case .tracking: .tracking
        case .conceiving: .conceiving
        case .pregnant: nil
        }
    }

    /// The goal a stored mode and cycle goal stand for (onboarding replay).
    public init?(mode: AppMode, cycleGoal: CycleGoal) {
        switch mode {
        case .tryingToConceive: self = cycleGoal == .tracking ? .tracking : .conceiving
        case .pregnant: self = .pregnant
        case .partner: return nil
        }
    }
}

public enum OnboardingStep: String, Sendable, CaseIterable {
    case welcome
    case goal
    case lastPeriod
    case periodLength
    case cycleLength
    case regularity
    case contraception
    case dueDate
    case result
}

/// What the result screen says about the next period.
public enum OnboardingPrediction: Equatable, Sendable {
    /// "Your next period should start around …".
    case nextPeriod(Date)
    /// The entered period is older than one cycle: about this many days late.
    case late(days: Int)
}

/// What onboarding saves (`OnboardingFlow.finish()`); the view writes it with
/// the existing stores.
public enum OnboardingOutcome: Equatable, Sendable {
    case cycle(
        goal: CycleGoal,
        settings: CycleSettings,
        firstPeriodStart: Date?,
        regularity: CycleRegularity,
        contraception: Contraception?
    )
    /// `dates` is nil when the due date step was skipped.
    case pregnant(dates: PregnancyDateSelection?)

    public var mode: AppMode {
        switch self {
        case .cycle: .tryingToConceive
        case .pregnant: .pregnant
        }
    }
}

/// Onboarding's answers and step order (phase 9 spec §3.2). Pure: the view
/// shows `step`, edits the answers and calls `next()`, `skip()` and `back()`.
///
/// - tracking: welcome, goal, lastPeriod, periodLength, cycleLength, regularity, contraception, result
/// - conceiving: welcome, goal, lastPeriod, periodLength, cycleLength, regularity, result
/// - pregnant: welcome, goal, dueDate, result
public struct OnboardingFlow: Equatable, Sendable {
    public private(set) var step: OnboardingStep = .welcome
    public var goal: OnboardingGoal?
    /// The first day of the last period; nil after "I don't remember" or a skip.
    public var lastPeriodStart: Date?
    public var periodLength: Int {
        didSet { periodLength = Self.clamp(periodLength, to: CycleSettings.periodLengthRange) }
    }
    public var cycleLength: Int {
        didSet { cycleLength = Self.clamp(cycleLength, to: CycleSettings.cycleLengthRange) }
    }
    public var regularity: CycleRegularity
    /// nil when not answered (skipped), as in `CyclePreferences`.
    public var contraception: Contraception?
    /// The due date step's value; nil once that step is skipped.
    public var pregnancyDates: PregnancyDateSelection?
    /// Kept from the stored settings: onboarding has no reminder switch.
    public let remindersEnabled: Bool

    public init(
        goal: OnboardingGoal? = nil,
        lastPeriodStart: Date?,
        settings: CycleSettings = CycleSettings(),
        regularity: CycleRegularity = .unknown,
        contraception: Contraception? = nil,
        pregnancyDates: PregnancyDateSelection?
    ) {
        self.goal = goal
        self.lastPeriodStart = lastPeriodStart
        periodLength = settings.typicalPeriodLength
        cycleLength = settings.typicalCycleLength
        remindersEnabled = settings.remindersEnabled
        self.regularity = regularity
        self.contraception = contraception
        self.pregnancyDates = pregnancyDates
    }

    public static func steps(for goal: OnboardingGoal) -> [OnboardingStep] {
        switch goal {
        case .tracking: [.welcome, .goal, .lastPeriod, .periodLength, .cycleLength, .regularity, .contraception, .result]
        case .conceiving: [.welcome, .goal, .lastPeriod, .periodLength, .cycleLength, .regularity, .result]
        case .pregnant: [.welcome, .goal, .dueDate, .result]
        }
    }

    /// The chosen branch; before a goal is chosen, the longest one (tracking),
    /// so the progress never claims fewer steps than there may be.
    public var steps: [OnboardingStep] { Self.steps(for: goal ?? .tracking) }

    /// 1-based, for "Step 3 of 8".
    public var stepNumber: Int { (steps.firstIndex(of: step) ?? 0) + 1 }
    public var stepCount: Int { steps.count }

    /// Every step but welcome and result asks something and can be skipped.
    public var isQuestion: Bool { step != .welcome && step != .result }
    public var canGoBack: Bool { step != .welcome }
    /// The goal step needs an answer before "Continue" (or "Skip").
    public var canContinue: Bool { step != .goal || goal != nil }

    public mutating func next() {
        guard canContinue, let index = steps.firstIndex(of: step), index + 1 < steps.count else { return }
        step = steps[index + 1]
    }

    public mutating func back() {
        guard let index = steps.firstIndex(of: step), index > 0 else { return }
        step = steps[index - 1]
    }

    /// "Skip" / "Not sure": the step's answer goes back to its default, then the
    /// next step. A skipped goal means pregnancy, as before phase 9.
    public mutating func skip() {
        switch step {
        case .welcome, .result: return
        case .goal: if goal == nil { goal = .pregnant }
        case .lastPeriod: lastPeriodStart = nil
        case .periodLength: periodLength = CycleSettings.defaultPeriodLength
        case .cycleLength: cycleLength = CycleSettings.defaultCycleLength
        case .regularity: regularity = .unknown
        case .contraception: contraception = nil
        case .dueDate: pregnancyDates = nil
        }
        next()
    }

    /// The typical lengths as answered (clamped by `CycleSettings`).
    public var settings: CycleSettings {
        CycleSettings(typicalCycleLength: cycleLength, typicalPeriodLength: periodLength, remindersEnabled: remindersEnabled)
    }

    /// nil without a last period (the result asks her to log the next one).
    public func prediction(now: Date, calendar: Calendar = .current) -> OnboardingPrediction? {
        guard let lastPeriodStart else { return nil }
        let period = CycleRules.assumedPeriod(
            startingOn: lastPeriodStart, typicalLength: periodLength, today: now, calendar: calendar
        )
        guard let forecast = CyclePredictor.forecast(
            periods: [period], logs: [], settings: settings, now: now, calendar: calendar
        ) else { return nil }
        return forecast.daysLate > 0 ? .late(days: forecast.daysLate) : .nextPeriod(forecast.nextPeriodStart)
    }

    /// What to save. Skipping the goal step makes it pregnancy.
    public func finish() -> OnboardingOutcome {
        switch goal ?? .pregnant {
        case .pregnant:
            return .pregnant(dates: pregnancyDates)
        case let cycleBranch:
            let isTracking = cycleBranch == .tracking
            return .cycle(
                goal: isTracking ? .tracking : .conceiving,
                settings: settings,
                firstPeriodStart: lastPeriodStart,
                regularity: regularity,
                contraception: isTracking ? contraception : nil
            )
        }
    }

    private static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
```

- [ ] **Step 8: Teach the coordinators the goal and the onboarding finish**

`completeOnboarding` writes the period itself instead of going through `write`, because `write` always may prompt; it then syncs reminders once, prompting only for "Turn on reminders".

In `Packages/KickCore/Sources/KickCore/CycleCoordinator.swift`:

Replace:

```swift
    public private(set) var forecast: CycleForecast?
    public private(set) var settings: CycleSettings
    /// Store errors for the screen to show; validation errors are only returned.
    public private(set) var failure: CycleFailure?
```

with:

```swift
    public private(set) var forecast: CycleForecast?
    public private(set) var settings: CycleSettings
    /// The goal, contraception, regularity and LH/BBT override (phase 9).
    public private(set) var preferences: CyclePreferences
    /// Store errors for the screen to show; validation errors are only returned.
    public private(set) var failure: CycleFailure?
```

Replace:

```swift
        self.now = now
        settings = CycleSettings.load(from: defaults)
    }

    public var mode: AppMode { AppMode.load(from: defaults) }

    /// The log for that calendar day, if any.
```

with:

```swift
        self.now = now
        settings = CycleSettings.load(from: defaults)
        preferences = CyclePreferences.load(from: defaults)
    }

    public var mode: AppMode { AppMode.load(from: defaults) }

    /// What the cycle screens show for the current goal and contraception.
    public var policy: CycleDisplayPolicy { CycleDisplayPolicy(preferences) }

    /// The log for that calendar day, if any.
```

Replace:

```swift
    }

    /// Onboarding or Settings chose "Trying to conceive". Pregnancy data,
    /// appointments and their reminders are left as they are.
```

with:

```swift
    }

    /// Profile changed the goal, contraception or the LH/BBT override: the
    /// reminders follow the new goal. Never prompts for permission.
    public func updatePreferences(_ newPreferences: CyclePreferences) async {
        newPreferences.save(to: defaults)
        preferences = CyclePreferences.load(from: defaults)
        await syncReminders(generation: bump(), mayPrompt: false)
    }

    /// Profile's mode picker chose "Track my cycle" or "Trying to conceive":
    /// stores the goal, then switches to the cycle mode like
    /// `activateTryingToConceive()` (from pregnancy, RootView then stops partner sharing).
    public func activateCycleMode(goal: CycleGoal) async {
        var updated = CyclePreferences.load(from: defaults)
        updated.goal = goal
        updated.save(to: defaults)
        await activateTryingToConceive()
    }

    /// Finishing onboarding on a cycle branch (phase 9 spec §3.2): stores the
    /// lengths, goal, regularity and contraception, switches to the cycle mode
    /// and, when given, the last period (assumed `settings.typicalPeriodLength`
    /// long). Asks for notifications only when `requestNotifications` ("Turn on
    /// reminders"); "Later" never prompts. Returns a failed period save.
    @discardableResult
    public func completeOnboarding(
        goal: CycleGoal,
        settings newSettings: CycleSettings,
        firstPeriodStart: Date?,
        regularity: CycleRegularity,
        contraception: Contraception?,
        requestNotifications: Bool
    ) async -> CycleFailure? {
        newSettings.save(to: defaults)
        settings = CycleSettings.load(from: defaults)
        var updated = CyclePreferences.load(from: defaults)
        updated.goal = goal
        updated.regularity = regularity
        updated.contraception = contraception
        updated.save(to: defaults)
        AppMode.save(.tryingToConceive, to: defaults)
        var failure: CycleFailure?
        if let firstPeriodStart {
            let record = CycleRules.assumedPeriod(
                startingOn: firstPeriodStart, typicalLength: settings.typicalPeriodLength, today: now(), calendar: calendar
            )
            do {
                try store.addPeriod(record, today: now())
            } catch {
                logger.error("Saving the onboarding period failed: \(error.localizedDescription)")
                failure = report(CycleFailure(error))
            }
        }
        guard refresh() else { return failure }
        await syncReminders(generation: bump(), mayPrompt: requestNotifications)
        return failure
    }

    /// Onboarding or Settings chose "Trying to conceive". Pregnancy data,
    /// appointments and their reminders are left as they are.
```

Replace:

```swift
        }
        do {
            try await notifications.scheduleCycleReminders(for: forecast, now: now(), texts: reminderTexts, calendar: calendar)
        } catch {
            logger.error("Scheduling cycle reminders failed: \(error.localizedDescription)")
```

with:

```swift
        }
        do {
            try await notifications.scheduleCycleReminders(
                for: forecast, now: now(), texts: reminderTexts, kinds: policy.reminderKinds, calendar: calendar
            )
        } catch {
            logger.error("Scheduling cycle reminders failed: \(error.localizedDescription)")
```

Replace:

```swift
    private func refresh() -> Bool {
        settings = CycleSettings.load(from: defaults)
        let loadedPeriods: [PeriodRecord]
        let loadedLogs: [CycleLogRecord]
```

with:

```swift
    private func refresh() -> Bool {
        settings = CycleSettings.load(from: defaults)
        preferences = CyclePreferences.load(from: defaults)
        let loadedPeriods: [PeriodRecord]
        let loadedLogs: [CycleLogRecord]
```

In `Packages/KickCore/Sources/KickCore/KickCoordinator.swift`:

Replace:

```swift
    }

    private func publish(_ record: SessionRecord?) {
        activeSession = record?.state
```

with:

```swift
    }

    /// Onboarding's "Turn on reminders" (phase 9): asks only if never asked.
    @discardableResult
    public func requestNotificationPermission() async -> Bool {
        await notifications.requestAuthorizationIfNeeded()
    }

    private func publish(_ record: SessionRecord?) {
        activeSession = record?.state
```

- [ ] **Step 9: The UI-test launch arguments**

In `Packages/KickCore/Sources/KickCore/UITestLaunchOptions.swift`:

Replace:

```swift
/// - `-uiTestingSharing <state>` shares through `FakePartnerSharing` in that mother state.
/// - `-uiTestingPartner <state>` starts in partner mode with `FakePartnerSharing` in that partner state.
public struct UITestLaunchOptions: Equatable, Sendable {
    public let isUITesting: Bool
```

with:

```swift
/// - `-uiTestingSharing <state>` shares through `FakePartnerSharing` in that mother state.
/// - `-uiTestingPartner <state>` starts in partner mode with `FakePartnerSharing` in that partner state.
/// - `-seedCycleGoal <goal>` stores that `CycleGoal` (`tracking`, `conceiving`).
/// - `-seedContraception <method>` stores that `Contraception` (e.g. `pill`, `condom`).
public struct UITestLaunchOptions: Equatable, Sendable {
    public let isUITesting: Bool
```

Replace:

```swift
    public let sharing: FakePartnerSharing.MotherState?
    public let partner: FakePartnerSharing.PartnerState?

    public init(arguments: [String]) {
```

with:

```swift
    public let sharing: FakePartnerSharing.MotherState?
    public let partner: FakePartnerSharing.PartnerState?
    public let seedCycleGoal: CycleGoal?
    public let seedContraception: Contraception?

    public init(arguments: [String]) {
```

Replace:

```swift
            ? Self.value(after: "-uiTestingPartner", in: arguments).flatMap(FakePartnerSharing.PartnerState.init(rawValue:))
            : nil
    }
```

with:

```swift
            ? Self.value(after: "-uiTestingPartner", in: arguments).flatMap(FakePartnerSharing.PartnerState.init(rawValue:))
            : nil
        seedCycleGoal = isUITesting ? Self.value(after: "-seedCycleGoal", in: arguments).flatMap(CycleGoal.init(rawValue:)) : nil
        seedContraception = isUITesting
            ? Self.value(after: "-seedContraception", in: arguments).flatMap(Contraception.init(rawValue:))
            : nil
    }
```

In `App/AppEnvironment.swift`:

Replace:

```swift
            if AppClock.launchOptions.seedCycles != nil {
                AppMode.save(.tryingToConceive, to: AppGroup.defaults)
            }
            if AppClock.launchOptions.partner != nil {
```

with:

```swift
            if AppClock.launchOptions.seedCycles != nil {
                AppMode.save(.tryingToConceive, to: AppGroup.defaults)
            }
            // Phase 9: `-seedCycleGoal` / `-seedContraception`; neither means a
            // user from before phase 9 (conceiving, not asked).
            let options = AppClock.launchOptions
            if options.seedCycleGoal != nil || options.seedContraception != nil {
                CyclePreferences(goal: options.seedCycleGoal ?? .conceiving, contraception: options.seedContraception)
                    .save(to: AppGroup.defaults)
            }
            if AppClock.launchOptions.partner != nil {
```

- [ ] **Step 10: Run the KickCore suite**

Run: `scripts/test-core.sh`
Expected: `Test run with 610 tests` passed (566 + 44: `CyclePreferencesTests` 5, `CycleDisplayPolicyTests` 6, `OnboardingFlowTests` 17, `CycleCoordinatorGoalTests` 10, `KickNotificationPermissionTests` 2, `CycleRemindersTests` +1, `CycleRingTests` +1, `UITestCycleGoalOptionTests` 2). Run it twice more: the coordinator suites are `@MainActor` and must be stable.

- [ ] **Step 11: Build the app**

```bash
scripts/test-core.sh
xcodegen generate --quiet
xcodebuild -project KickCounter.xcodeproj -scheme KickCounter \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO -quiet build-for-testing
```
Expected: 610 tests passed; `xcodebuild` exits 0 with no `.swift:…: error:` lines (no App file uses the new API yet except `AppEnvironment`). `grep -rn "import SwiftUI\|import UIKit\|import SwiftData\|import CloudKit" Packages/KickCore/Sources` prints nothing.

- [ ] **Step 12: Commit, push, verify CI**

```bash
git add Packages/KickCore App/AppEnvironment.swift
git commit -F - <<'MSG'
feat(core): cycle goal, contraception, display policy and onboarding flow

The cycle mode gains a goal (tracking or trying to conceive), the
contraception and the regularity, stored next to CycleSettings with
defaults that keep every existing user on trying to conceive.
CycleDisplayPolicy decides what each goal and contraception shows and
which reminders are scheduled; OnboardingFlow holds the new onboarding's
answers, step order, skips and prediction. Nothing on screen changes yet.

CI-Only-Testing: CycleUITests, CycleTodayUITests
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`; the KickCore step reports 610 tests; `CycleUITests` and `CycleTodayUITests` are green (nothing visible changed).

---
### Task 2: Onboarding — three goals, the new questions, the result and the reminder opt-in

Rebuilds `OnboardingView` on `OnboardingFlow` (spec §4.1): welcome gains the privacy note; the goal step has three cards; the tracking branch asks last period, period length, cycle length, regularity and contraception, the conceiving branch the same without contraception, the pregnancy branch the due date; every question has "Skip" / "Not sure" and a back button; the result shows the predicted next period (or the pregnancy week) with "Turn on reminders" and "Later". Every UI test that walks through onboarding moves to the new steps.

**Files:**
- Modify: `App/Onboarding/OnboardingView.swift` (the `OnboardingView` struct is replaced; `ContentScrim`, `OnboardingHeroKind`, `OnboardingHero`, `WaveBand`, `WaveShape` stay as they are), `Shared/L10n.swift`, `Shared/Localizable.xcstrings` (via the script)
- Modify (tests): `UITests/OnboardingUITests.swift` (rewritten), `UITests/UITestSupport.swift`, `UITests/KickCounterUITests.swift`, `UITests/ScreenshotTests.swift`, `UITests/ProfileUITests.swift`

**Interfaces:**
- Consumes (Task 1): `OnboardingFlow` and its types, `CyclePreferences.load(from:)`, `CycleCoordinator.completeOnboarding(goal:settings:firstPeriodStart:regularity:contraception:requestNotifications:)`, `KickCoordinator.requestNotificationPermission()`, `Contraception`, `CycleRegularity`. Existing: `RecentDaysGrid`, `LastPeriodPicker(date:now:)`, `PregnancyDateForm`, `PregnancyDateInput`, `PregnancyTimeline`, `PregnancyProfile.save(source:date:to:)`, `Formatting.longDate/shortDay/dayMonthYear/spokenDay/dayNumber`, `.pill(...)` button styles, `.lunaCard(padding:)`, `SegmentedPill`.
- Produces: `L10n.contraception(_ value: Contraception) -> String` (Task 4 uses it), `L10n.onboardingRegularity(_:)`, `L10n.onboardingRegularityDetail(_:)`, the onboarding identifiers listed in Global Constraints, and in `UITestSupport.swift`: `XCUIApplication.scrollDownUntilHittable(_:maxSwipes:)`, `completeOnboardingPregnantWithoutDates()`, `skipThroughReplayedOnboarding()`.

- [ ] **Step 1: Write the UI tests first**

They cannot run locally (CI runs them in Step 7); they describe the flow the view must satisfy.

Overwrite `UITests/OnboardingUITests.swift`:
```swift
import XCTest

/// Phase 9 spec §4.1 and §5: the three onboarding branches, skipping, going
/// back, the language on the first step, the result screen, and screenshots of
/// every step. The clock is pinned to 2026-10-02.
final class OnboardingUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(language: String = "en", dark: Bool = false, largestText: Bool = false) -> XCUIApplication {
        XCUIApplication.launchPinned(language: language, dark: dark, skipOnboarding: false, largestText: largestText)
    }

    /// Welcome → goal → that goal's first question.
    @MainActor
    private func choose(_ goal: String, in app: XCUIApplication) {
        let next = app.buttons["onboardingNext"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        next.tap()
        let card = app.buttons["onboardingGoal-\(goal)"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        next.tap()
    }

    /// Tracking: every question answered → the predicted date on the result →
    /// "Turn on reminders" → Today at the right cycle day.
    @MainActor
    func testTrackingBranchShowsThePredictedDate() {
        let app = launch()
        choose("tracking", in: app)
        let progress = app.descendants(matching: .any)["onboardingProgress"]
        waitForLabel(progress, containing: "Step 3 of 8")

        let day = app.buttons.matching(
            NSPredicate(format: "identifier == 'onboardingDay' AND label BEGINSWITH 'September 20'")
        ).firstMatch
        XCTAssertTrue(day.waitForExistence(timeout: 5))
        day.tap()
        XCTAssertTrue(day.isSelected)
        let next = app.buttons["onboardingNext"]
        next.tap()

        XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 5)) // period length, keep 5
        next.tap()
        XCTAssertTrue(app.staticTexts["onboardingCycleLengthHint"].waitForExistence(timeout: 5))
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "30 days")
        next.tap()

        let irregular = app.buttons["onboardingRegularity-irregular"]
        XCTAssertTrue(irregular.waitForExistence(timeout: 5))
        irregular.tap()
        XCTAssertTrue(app.staticTexts["onboardingIrregularNote"].waitForExistence(timeout: 5))
        app.buttons["onboardingRegularity-regular"].tap()
        XCTAssertFalse(app.staticTexts["onboardingIrregularNote"].exists)
        next.tap()

        XCTAssertTrue(app.staticTexts["onboardingContraceptionWhy"].waitForExistence(timeout: 5))
        let condom = app.buttons["onboardingContraception-condom"]
        app.scrollDownUntilHittable(condom)
        condom.tap()
        XCTAssertTrue(condom.isSelected)
        next.tap()

        // 2026-09-20 + 30 days.
        let result = app.staticTexts["onboardingResultText"]
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertTrue(result.label.contains("October 20"), result.label)
        waitForLabel(progress, containing: "Step 8 of 8")
        XCTAssertFalse(app.buttons["onboardingSkip"].exists)
        app.buttons["onboardingEnableReminders"].tap()

        let status = app.descendants(matching: .any)["cycleStatusCard"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertTrue(status.label.contains("Day 13 of your cycle"), status.label)
        XCTAssertTrue(app.tabBars.buttons["Calendar"].exists)
    }

    /// Trying to conceive: 7 steps, no contraception question; "I don't
    /// remember" leaves no period, so the result asks to log the next one.
    @MainActor
    func testConceivingBranchWithoutALastPeriod() {
        let app = launch()
        choose("conceiving", in: app)
        let progress = app.descendants(matching: .any)["onboardingProgress"]
        waitForLabel(progress, containing: "Step 3 of 7")
        let dontRemember = app.buttons["onboardingDontRemember"]
        XCTAssertTrue(dontRemember.waitForExistence(timeout: 5))
        dontRemember.tap()
        waitForLabel(progress, containing: "Step 4 of 7")

        let skip = app.buttons["onboardingSkip"]
        XCTAssertEqual(skip.label, "Not sure")
        skip.tap() // period length
        skip.tap() // cycle length
        XCTAssertTrue(app.buttons["onboardingRegularity-unknown"].waitForExistence(timeout: 5))
        skip.tap() // regularity

        let result = app.staticTexts["onboardingResultText"]
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertTrue(result.label.contains("Log the first day of your next period"), result.label)
        XCTAssertFalse(app.buttons["onboardingContraception-pill"].exists)
        app.buttons["onboardingFinishLater"].tap()

        XCTAssertTrue(app.buttons["cycleAddPeriodButton"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Calendar"].exists)
    }

    /// Pregnant: −/+ move the due date a week at a time → the week on the
    /// result and on Today.
    @MainActor
    func testPregnancyBranchMovesTheDueDateAWeekAtATime() {
        let app = launch()
        choose("pregnant", in: app)

        // The default due date is 140 days ahead: 20 weeks today.
        let weeks = app.staticTexts["onboardingDueWeeks"]
        XCTAssertTrue(weeks.waitForExistence(timeout: 5))
        XCTAssertEqual(weeks.label, "20 weeks, 0 days")
        app.buttons["onboardingDueLater"].tap()
        waitForLabel(weeks, containing: "19 weeks, 0 days")
        app.buttons["onboardingDueEarlier"].tap()
        app.buttons["onboardingDueEarlier"].tap()
        waitForLabel(weeks, containing: "21 weeks, 0 days")
        app.buttons["onboardingNext"].tap()

        let result = app.staticTexts["onboardingResultText"]
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertTrue(result.label.contains("21 weeks, 0 days"), result.label)
        waitForLabel(app.descendants(matching: .any)["onboardingProgress"], containing: "Step 4 of 4")
        app.buttons["onboardingFinishLater"].tap()

        let progress = app.descendants(matching: .any)["weekProgressCard"]
        XCTAssertTrue(progress.waitForExistence(timeout: 10))
        XCTAssertTrue(progress.label.contains("21 weeks, 0 days"), progress.label)
        XCTAssertTrue(app.tabBars.buttons["Kicks"].exists)
    }

    /// Welcome has no "Skip"; skipping the goal means pregnancy, and skipping
    /// the due date saves none. The medical and privacy notes are on step 1.
    @MainActor
    func testSkippingTheGoalMeansPregnancy() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["onboardingMedicalNote"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["onboardingPrivacyNote"].exists)
        let progress = app.descendants(matching: .any)["onboardingProgress"]
        XCTAssertEqual(progress.label, "Step 1 of 8")
        XCTAssertFalse(app.buttons["onboardingSkip"].exists)
        XCTAssertFalse(app.buttons["onboardingBack"].exists)
        app.buttons["onboardingNext"].tap()

        let skip = app.buttons["onboardingSkip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["onboardingNext"].isEnabled) // nothing chosen yet
        skip.tap()
        XCTAssertTrue(app.buttons["onboardingDueDate"].waitForExistence(timeout: 5))
        waitForLabel(progress, containing: "Step 3 of 4")
        skip.tap()
        let later = app.buttons["onboardingFinishLater"]
        XCTAssertTrue(later.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["onboardingResultText"].label.contains("add your due date later"))
        later.tap()
        XCTAssertTrue(app.buttons["pregnancyAddDateButton"].waitForExistence(timeout: 10))
    }

    /// "Back" returns to the previous step with the answer kept.
    @MainActor
    func testBackKeepsTheAnswer() {
        let app = launch()
        choose("tracking", in: app)
        let back = app.buttons["onboardingBack"]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
        let tracking = app.buttons["onboardingGoal-tracking"]
        XCTAssertTrue(tracking.waitForExistence(timeout: 5))
        XCTAssertTrue(tracking.isSelected)
        back.tap()
        XCTAssertTrue(app.staticTexts["onboardingWelcomeTitle"].waitForExistence(timeout: 5))
        XCTAssertFalse(back.exists)
    }

    /// Spec §2.2 (phase 4): the language chosen on the first step applies at once.
    @MainActor
    func testChoosingALanguageOnTheFirstStepAppliesAtOnce() {
        let app = launch(language: "vi")
        let title = app.staticTexts["onboardingWelcomeTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, "Chào mừng đến với Luna Mom")
        app.buttons["onboardingLanguageEn"].tap()
        waitForLabel(title, containing: "Welcome to Luna Mom")
        XCTAssertTrue(app.buttons["onboardingLanguageEn"].isSelected)
        app.buttons["onboardingNext"].tap()
        XCTAssertTrue(app.staticTexts["What would you like to track?"].waitForExistence(timeout: 5))
    }

    /// The welcome text stays on the plain background at the largest text size.
    @MainActor
    func testWelcomeScreenAtLargestText() {
        for dark in [false, true] {
            let app = launch(language: "vi", dark: dark, largestText: true)
            XCTAssertTrue(app.buttons["onboardingNext"].waitForExistence(timeout: 10))
            attachScreenshot(app, "ax5-onboarding-welcome-vi-\(dark ? "dark" : "light")")
            app.terminate()
        }
    }

    /// The longest new steps at AX5: contraception (8 choices) and the result.
    @MainActor
    func testNewStepsAtLargestText() {
        let app = launch(language: "vi", largestText: true)
        choose("tracking", in: app)
        let skip = app.buttons["onboardingSkip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        for _ in 0..<4 { skip.tap() } // last period, period length, cycle length, regularity
        XCTAssertTrue(app.buttons["onboardingContraception-otherOrPrivate"].waitForExistence(timeout: 5))
        attachScreenshot(app, "ax5-onboarding-contraception-vi-light")
        skip.tap()
        XCTAssertTrue(app.buttons["onboardingFinishLater"].waitForExistence(timeout: 5))
        attachScreenshot(app, "ax5-onboarding-result-vi-light")
    }

    @MainActor
    func testOnboardingScreens() {
        for (language, dark) in UITestVariants.all {
            let suffix = UITestVariants.suffix(language, dark)
            let app = launch(language: language, dark: dark)
            let next = app.buttons["onboardingNext"]
            XCTAssertTrue(next.waitForExistence(timeout: 10))
            attachScreenshot(app, "onboarding-welcome-\(suffix)")
            next.tap()
            let tracking = app.buttons["onboardingGoal-tracking"]
            XCTAssertTrue(tracking.waitForExistence(timeout: 5))
            tracking.tap()
            attachScreenshot(app, "onboarding-goal-\(suffix)")
            next.tap()
            XCTAssertTrue(app.buttons["onboardingDontRemember"].waitForExistence(timeout: 5))
            attachScreenshot(app, "onboarding-last-period-\(suffix)")
            next.tap()
            XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 5))
            attachScreenshot(app, "onboarding-period-length-\(suffix)")
            next.tap()
            XCTAssertTrue(app.staticTexts["onboardingCycleLengthHint"].waitForExistence(timeout: 5))
            attachScreenshot(app, "onboarding-cycle-length-\(suffix)")
            next.tap()
            let irregular = app.buttons["onboardingRegularity-irregular"]
            XCTAssertTrue(irregular.waitForExistence(timeout: 5))
            irregular.tap()
            XCTAssertTrue(app.staticTexts["onboardingIrregularNote"].waitForExistence(timeout: 5))
            attachScreenshot(app, "onboarding-regularity-\(suffix)")
            next.tap()
            XCTAssertTrue(app.staticTexts["onboardingContraceptionWhy"].waitForExistence(timeout: 5))
            attachScreenshot(app, "onboarding-contraception-\(suffix)")
            next.tap()
            XCTAssertTrue(app.staticTexts["onboardingResultText"].waitForExistence(timeout: 5))
            attachScreenshot(app, "onboarding-result-\(suffix)")
            app.terminate()

            let pregnant = launch(language: language, dark: dark)
            choose("pregnant", in: pregnant)
            XCTAssertTrue(pregnant.staticTexts["onboardingDueWeeks"].waitForExistence(timeout: 5))
            attachScreenshot(pregnant, "onboarding-due-\(suffix)")
            pregnant.buttons["onboardingNext"].tap()
            XCTAssertTrue(pregnant.staticTexts["onboardingResultText"].waitForExistence(timeout: 5))
            attachScreenshot(pregnant, "onboarding-result-pregnant-\(suffix)")
            pregnant.terminate()
        }
    }
}
```

In `UITests/UITestSupport.swift`:

Replace:

```swift
            remaining -= 1
        }
    }
}
```

with:

```swift
            remaining -= 1
        }
    }

    /// Swipes down until `element` is hittable: onboarding's steps are anchored
    /// to the bottom, so a long list starts scrolled to its end.
    func scrollDownUntilHittable(_ element: XCUIElement, maxSwipes: Int = 4) {
        var remaining = maxSwipes
        while !(element.exists && element.isHittable), remaining > 0 {
            swipeDown()
            remaining -= 1
        }
    }

    /// Phase 9 onboarding, pregnancy branch without a due date: Continue →
    /// "Pregnant" → Continue → Skip (due date) → Later.
    func completeOnboardingPregnantWithoutDates() {
        let next = buttons["onboardingNext"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        next.tap()
        let pregnant = buttons["onboardingGoal-pregnant"]
        XCTAssertTrue(pregnant.waitForExistence(timeout: 5))
        pregnant.tap()
        next.tap()
        XCTAssertTrue(buttons["onboardingDueDate"].waitForExistence(timeout: 5))
        buttons["onboardingSkip"].tap()
        let later = buttons["onboardingFinishLater"]
        XCTAssertTrue(later.waitForExistence(timeout: 5))
        later.tap()
    }

    /// Replaying onboarding (the goal is preselected): Continue twice, skip
    /// every question, then "Later". Replay saves nothing.
    func skipThroughReplayedOnboarding() {
        let next = buttons["onboardingNext"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        next.tap() // welcome
        XCTAssertTrue(next.isEnabled) // the current goal is already chosen
        next.tap() // goal
        let skip = buttons["onboardingSkip"]
        let later = buttons["onboardingFinishLater"]
        for _ in 0..<8 where !later.exists {
            XCTAssertTrue(skip.waitForExistence(timeout: 5))
            skip.tap()
        }
        XCTAssertTrue(later.waitForExistence(timeout: 5))
        later.tap()
    }
}
```

The other tests that walk through onboarding:
In `UITests/KickCounterUITests.swift`:

Replace:

```swift

    private func completeOnboarding() {
        let next = app.buttons["onboardingNext"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        next.tap()
        let pregnant = app.buttons["onboardingModePregnant"]
        XCTAssertTrue(pregnant.waitForExistence(timeout: 5))
        pregnant.tap()
        next.tap()
        let later = app.buttons["onboardingSkipDate"]
        XCTAssertTrue(later.waitForExistence(timeout: 5))
        later.tap()
    }
```

with:

```swift

    private func completeOnboarding() {
        app.completeOnboardingPregnantWithoutDates()
    }
```

In `UITests/ScreenshotTests.swift`:

Replace:

```swift

        // Onboarding screenshots: OnboardingUITests.testOnboardingScreens.
        let next = app.buttons["onboardingNext"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        next.tap()
        let pregnant = app.buttons["onboardingModePregnant"]
        XCTAssertTrue(pregnant.waitForExistence(timeout: 5))
        pregnant.tap()
        next.tap()
        let later = app.buttons["onboardingSkipDate"]
        XCTAssertTrue(later.waitForExistence(timeout: 5))
        later.tap()

        app.openTab(.profile)
```

with:

```swift

        // Onboarding screenshots: OnboardingUITests.testOnboardingScreens.
        app.completeOnboardingPregnantWithoutDates()

        app.openTab(.profile)
```

In `UITests/ProfileUITests.swift`:

Replace:

```swift
        app.scrollUntilHittable(replay)
        replay.tap()
        let skip = app.buttons["onboardingSkip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        skip.tap()
        app.buttons["onboardingSkipDate"].tap()

        app.openTab(.today)
```

with:

```swift
        app.scrollUntilHittable(replay)
        replay.tap()
        app.skipThroughReplayedOnboarding()

        app.openTab(.today)
```

Replace:

```swift
        app.scrollUntilHittable(replay)
        replay.tap()
        let skip = app.buttons["onboardingSkip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        skip.tap()
        let later = app.buttons["onboardingSkipCycle"]
        XCTAssertTrue(later.waitForExistence(timeout: 5))
        later.tap()

        XCTAssertTrue(app.tabBars.buttons["Calendar"].waitForExistence(timeout: 5))
```

with:

```swift
        app.scrollUntilHittable(replay)
        replay.tap()
        app.skipThroughReplayedOnboarding()

        XCTAssertTrue(app.tabBars.buttons["Calendar"].waitForExistence(timeout: 5))
```

Then `grep -rn "onboarding[A-Z]" UITests | grep -v "OnboardingUITests.swift\|UITestSupport.swift"` must print only the doc comment in `ProfileUITests.swift` ("replaying the introduction") — no identifier.

- [ ] **Step 2: Strings**

Remove the keys the old onboarding used, then add the new ones (the medical ones — `onboarding.cycleLength.hint`, `onboarding.regularity.irregularNote`, `onboarding.contraception.why`, `contraception.*` — go to the doctor in Task 5):
```bash
scripts/add-strings.py --remove onboarding.goal.cycle onboarding.goal.cycle.detail onboarding.goal.pregnant onboarding.cycle.shorter onboarding.cycle.longer onboarding.start
scripts/add-strings.py <<'JSON'
{
  "onboarding.privacy": [
    "Your data stays on your iPhone and in your iCloud. No ads, and your data is never sold.",
    "Dữ liệu chỉ nằm trên máy và iCloud của bạn. Không quảng cáo, không bán dữ liệu."
  ],
  "onboarding.back": [
    "Back",
    "Quay lại"
  ],
  "onboarding.notSure": [
    "Not sure",
    "Không chắc"
  ],
  "onboarding.goal.tracking": [
    "Track my cycle",
    "Theo dõi chu kỳ"
  ],
  "onboarding.goal.tracking.detail": [
    "Understand your body and know when your period is coming",
    "Hiểu cơ thể, biết trước kỳ kinh"
  ],
  "onboarding.goal.conceiving": [
    "Trying to conceive",
    "Mong con"
  ],
  "onboarding.goal.conceiving.detail": [
    "See your fertile days and ovulation",
    "Biết những ngày dễ thụ thai và ngày rụng trứng"
  ],
  "onboarding.goal.pregnant": [
    "Pregnant",
    "Đang mang thai"
  ],
  "onboarding.dontRemember": [
    "I don't remember",
    "Không nhớ"
  ],
  "onboarding.periodLength.title": [
    "How many days does your period usually last?",
    "Kỳ kinh của bạn thường kéo dài mấy ngày?"
  ],
  "onboarding.cycleLength.title": [
    "How long is your cycle usually?",
    "Chu kỳ của bạn thường dài bao nhiêu ngày?"
  ],
  "onboarding.cycleLength.hint": [
    "Count from the first day of one period to the day before the next one starts. Many cycles are 21 to 35 days long; yours may differ.",
    "Tính từ ngày đầu của một kỳ kinh đến hết ngày trước kỳ kinh sau. Nhiều người có chu kỳ từ 21 đến 35 ngày, của bạn có thể khác."
  ],
  "onboarding.regularity.title": [
    "Is your cycle regular?",
    "Chu kỳ của bạn có đều không?"
  ],
  "onboarding.regularity.regular": [
    "Regular",
    "Đều"
  ],
  "onboarding.regularity.regular.detail": [
    "About the same length every month",
    "Độ dài gần như nhau mỗi tháng"
  ],
  "onboarding.regularity.irregular": [
    "Irregular",
    "Không đều"
  ],
  "onboarding.regularity.irregular.detail": [
    "It changes from month to month",
    "Thay đổi từ tháng này sang tháng khác"
  ],
  "onboarding.regularity.unknown": [
    "I don't know",
    "Không rõ"
  ],
  "onboarding.regularity.unknown.detail": [
    "That's fine: Luna Mom learns as you log",
    "Không sao, Luna Mom sẽ học dần khi bạn ghi lại"
  ],
  "onboarding.regularity.irregularNote": [
    "Cycles that vary a little are common, especially after giving birth, while breastfeeding or at stressful times. Predictions usually get closer as you log more periods. If your cycles are often shorter than 21 days or longer than 45 days, it is worth talking to a doctor.",
    "Chu kỳ dao động một chút là chuyện thường gặp, nhất là sau sinh, khi đang cho con bú hoặc lúc căng thẳng. Bạn ghi càng nhiều kỳ kinh, dự đoán thường càng sát hơn. Nếu chu kỳ hay ngắn hơn 21 ngày hoặc dài hơn 45 ngày, bạn nên đi khám để bác sĩ tư vấn."
  ],
  "onboarding.contraception.title": [
    "Do you use any contraception?",
    "Bạn đang dùng biện pháp tránh thai nào?"
  ],
  "onboarding.contraception.why": [
    "Why we ask: some methods, such as the pill, usually stop ovulation, so Luna Mom will not show fertile days that may not apply to you. This only changes what the app shows.",
    "Vì sao hỏi: một số biện pháp như thuốc tránh thai thường làm ngừng rụng trứng, nên Luna Mom sẽ không hiện những ngày dễ thụ thai có thể không đúng với bạn. Thông tin này chỉ dùng để chọn nội dung hiển thị."
  ],
  "contraception.none": [
    "None",
    "Không dùng"
  ],
  "contraception.condom": [
    "Condoms",
    "Bao cao su"
  ],
  "contraception.pill": [
    "The pill",
    "Thuốc tránh thai hằng ngày"
  ],
  "contraception.implantOrInjection": [
    "Implant or injection",
    "Que cấy hoặc thuốc tiêm tránh thai"
  ],
  "contraception.hormonalIUD": [
    "Hormonal IUD",
    "Vòng tránh thai có nội tiết"
  ],
  "contraception.copperIUD": [
    "Copper IUD",
    "Vòng tránh thai chữ T bằng đồng"
  ],
  "contraception.fertilityAwarenessOrWithdrawal": [
    "Counting days or withdrawal",
    "Tính ngày hoặc xuất tinh ngoài"
  ],
  "contraception.otherOrPrivate": [
    "Something else, or I'd rather not say",
    "Cách khác hoặc không muốn nói"
  ],
  "onboarding.result.title": [
    "You're all set",
    "Mọi thứ đã sẵn sàng"
  ],
  "onboarding.result.nextPeriod": [
    "Your next period should start around %@.",
    "Kỳ kinh tới dự kiến khoảng %@."
  ],
  "onboarding.result.late": [
    "From the date you entered, your period may be about %ld days late.",
    "Theo ngày bạn nhập, kỳ kinh có thể đã trễ khoảng %ld ngày."
  ],
  "onboarding.result.noPeriod": [
    "Log the first day of your next period so Luna Mom can predict the ones after it.",
    "Ghi ngày bắt đầu kỳ kinh tới để Luna Mom dự đoán cho bạn."
  ],
  "onboarding.result.pregnant": [
    "Today you are %@ pregnant.",
    "Hôm nay thai được %@."
  ],
  "onboarding.result.noDueDate": [
    "You can add your due date later in Profile.",
    "Bạn có thể nhập ngày dự sinh sau trong mục Cá nhân."
  ],
  "onboarding.result.reminders": [
    "Turn on reminders and Luna Mom will give you a gentle nudge on the days that matter.",
    "Bật nhắc nhở để Luna Mom báo bạn nhẹ nhàng vào những ngày quan trọng."
  ],
  "onboarding.enableReminders": [
    "Turn on reminders",
    "Bật nhắc nhở"
  ]
}
JSON
```
Expected output: `473 strings`, then `511 strings`.

In `Shared/L10n.swift`:

Replace:

```swift
    static var onboardingSkip: String { t("onboarding.skip") }
    static var onboardingContinue: String { t("onboarding.continue") }
    static var onboardingStart: String { t("onboarding.start") }
    /// VoiceOver for the progress dots: "Step 2 of 3".
    static func onboardingStep(_ step: Int, _ count: Int) -> String { String(format: t("onboarding.step"), step, count) }
    static var onboardingWelcomeTitle: String { t("onboarding.welcome.title") }
    static var onboardingWelcomeBody: String { t("onboarding.welcome.body") }
    static var onboardingGoalCycle: String { t("onboarding.goal.cycle") }
    static var onboardingGoalCycleDetail: String { t("onboarding.goal.cycle.detail") }
    static var onboardingGoalPregnant: String { t("onboarding.goal.pregnant") }
    static var onboardingGoalPregnantDetail: String { t("onboarding.goal.pregnant.detail") }
    static var onboardingOtherDay: String { t("onboarding.otherDay") }
    static func onboardingOtherDayValue(_ date: String) -> String { String(format: t("onboarding.otherDay.value"), date) }
    static var onboardingCycleShorter: String { t("onboarding.cycle.shorter") }
    static var onboardingCycleLonger: String { t("onboarding.cycle.longer") }
    static var onboardingDueTitle: String { t("onboarding.due.title") }
    static var onboardingDueEarlier: String { t("onboarding.due.earlier") }
```

with:

```swift
    static var onboardingSkip: String { t("onboarding.skip") }
    static var onboardingContinue: String { t("onboarding.continue") }
    /// VoiceOver for the progress dots: "Step 2 of 3".
    static func onboardingStep(_ step: Int, _ count: Int) -> String { String(format: t("onboarding.step"), step, count) }
    static var onboardingWelcomeTitle: String { t("onboarding.welcome.title") }
    static var onboardingWelcomeBody: String { t("onboarding.welcome.body") }
    static var onboardingGoalPregnant: String { t("onboarding.goal.pregnant") }
    static var onboardingGoalPregnantDetail: String { t("onboarding.goal.pregnant.detail") }
    static var onboardingOtherDay: String { t("onboarding.otherDay") }
    static func onboardingOtherDayValue(_ date: String) -> String { String(format: t("onboarding.otherDay.value"), date) }
    static var onboardingDueTitle: String { t("onboarding.due.title") }
    static var onboardingDueEarlier: String { t("onboarding.due.earlier") }
```

Replace:

```swift
    static var partnerModeName: String { t("partner.modeName") }
    static var partnerAboutTitle: String { t("partner.about.title") }
}
```

with:

```swift
    static var partnerModeName: String { t("partner.modeName") }
    static var partnerAboutTitle: String { t("partner.about.title") }

    // MARK: - Phase 9: onboarding

    static var onboardingPrivacy: String { t("onboarding.privacy") }
    static var onboardingBack: String { t("onboarding.back") }
    static var onboardingNotSure: String { t("onboarding.notSure") }
    static var onboardingGoalTracking: String { t("onboarding.goal.tracking") }
    static var onboardingGoalTrackingDetail: String { t("onboarding.goal.tracking.detail") }
    static var onboardingGoalConceiving: String { t("onboarding.goal.conceiving") }
    static var onboardingGoalConceivingDetail: String { t("onboarding.goal.conceiving.detail") }
    static var onboardingDontRemember: String { t("onboarding.dontRemember") }
    static var onboardingPeriodLengthTitle: String { t("onboarding.periodLength.title") }
    static var onboardingCycleLengthTitle: String { t("onboarding.cycleLength.title") }
    static var onboardingCycleLengthHint: String { t("onboarding.cycleLength.hint") }
    static var onboardingRegularityTitle: String { t("onboarding.regularity.title") }
    static func onboardingRegularity(_ value: CycleRegularity) -> String { t("onboarding.regularity.\(value.rawValue)") }
    static func onboardingRegularityDetail(_ value: CycleRegularity) -> String {
        t("onboarding.regularity.\(value.rawValue).detail")
    }
    static var onboardingIrregularNote: String { t("onboarding.regularity.irregularNote") }
    static var onboardingContraceptionTitle: String { t("onboarding.contraception.title") }
    static var onboardingContraceptionWhy: String { t("onboarding.contraception.why") }
    /// "The pill" / "Thuốc tránh thai hằng ngày" (onboarding and Profile).
    static func contraception(_ value: Contraception) -> String { t("contraception.\(value.rawValue)") }
    static var onboardingResultTitle: String { t("onboarding.result.title") }
    /// "Your next period should start around October 20, 2026."
    static func onboardingResultNextPeriod(_ date: String) -> String { String(format: t("onboarding.result.nextPeriod"), date) }
    static func onboardingResultLate(_ days: Int) -> String { String(format: t("onboarding.result.late"), days) }
    static var onboardingResultNoPeriod: String { t("onboarding.result.noPeriod") }
    /// "Today you are 21 weeks, 0 days pregnant."
    static func onboardingResultPregnant(_ weeks: String) -> String { String(format: t("onboarding.result.pregnant"), weeks) }
    static var onboardingResultNoDueDate: String { t("onboarding.result.noDueDate") }
    static var onboardingResultReminders: String { t("onboarding.result.reminders") }
    static var onboardingEnableReminders: String { t("onboarding.enableReminders") }
}
```

- [ ] **Step 3: Rebuild `OnboardingView`**

Overwrite `App/Onboarding/OnboardingView.swift` with the file below. Only `struct OnboardingView` changes; everything from `/// The background behind the step's text` to the end of the file is the current code, unchanged.
```swift
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
                    Image(systemName: "chevron.left")
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
                ) { flow.regularity = value }
            }
            if flow.regularity == .irregular {
                note(L10n.onboardingIrregularNote, identifier: "onboardingIrregularNote")
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
    /// reminders" asks for notifications; "Later" never does. A failed period
    /// save shows on Today.
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
                await kicks.requestNotificationPermission()
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
```

Notes for the reviewer:
- `@State flow` is the only source of truth for the step and the answers; `dateSelection` is the due-date editor's value, copied into `flow.pregnancyDates` by "Continue" (`continueTapped`) and cleared by "Skip".
- Replay (`isReplay`) starts from the stored goal and values and `finish` returns before saving anything, exactly as before.
- `finish(requestingNotifications:)` is the only place that saves: the cycle branch through `cycle.completeOnboarding`, the pregnancy branch through `AppMode.save` + `PregnancyProfile.save` (as before) and, for "Turn on reminders", `kicks.requestNotificationPermission()`.
- The fullScreenCover inherits `KickCoordinator` from `RootView`'s environment (`KickCounterApp` injects it at the root), like `CycleCoordinator` already.

- [ ] **Step 4: Build**

```bash
scripts/test-core.sh
xcodegen generate --quiet
xcodebuild -project KickCounter.xcodeproj -scheme KickCounter \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO -quiet build-for-testing
```
Expected: 610 tests passed; `xcodebuild` exits 0 with no `.swift:…: error:` lines (the UI tests compile; do not run them).

- [ ] **Step 5: Check nothing else used the removed identifiers or keys**

Run: `grep -rn "onboardingModeTTC\|onboardingModePregnant\|onboardingSave\|onboardingSkipCycle\|onboardingSkipDate\|onboardingGoalCycle\|onboardingStart\|onboardingCycleShorter" App UITests Shared`
Expected: no output.

- [ ] **Step 6: Commit, push, verify CI**

```bash
git add App/Onboarding/OnboardingView.swift Shared UITests
git commit -F - <<'MSG'
feat(onboarding): three goals, cycle questions, early prediction

Onboarding asks the goal first (track my cycle, trying to conceive,
pregnant), then that branch's questions: last period with "I don't
remember", period and cycle length, regularity and, when tracking,
contraception. Every question can be skipped and has a back button. The
result shows when the next period should start (or the pregnancy week)
and offers to turn on reminders; "Later" never asks for notifications.
The privacy note joins the welcome step.

CI-Only-Testing: OnboardingUITests, ProfileUITests, KickCounterUITests, ScreenshotTests
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED` with all `OnboardingUITests` (9 tests), `ProfileUITests` (both replay tests walk the new flow), `KickCounterUITests` and `ScreenshotTests`.

- [ ] **Step 7: Visual check**

Open each PNG in `ci-artifacts/screenshots/` with the Read tool:
- `onboarding-welcome-vi-light`, `-en-dark`: the photo, title, body, the medical note, then the privacy note "Dữ liệu chỉ nằm trên máy và iCloud của bạn. Không quảng cáo, không bán dữ liệu." / "Your data stays on your iPhone and in your iCloud. …", the language pill; no back button, no "Skip"; 8 progress dots, the first wide.
- `onboarding-goal-*`: three white cards "Theo dõi chu kỳ" (pink dot, "Hiểu cơ thể, biết trước kỳ kinh"), "Mong con" (green dot), "Đang mang thai" (peach dot); the first has a dark border and a checkmark; back button left of the dots; "Bỏ qua" right.
- `onboarding-last-period-*`: the 14-day grid with today selected, "Ngày khác", and "Không nhớ" as a text button under the card.
- `onboarding-period-length-*` / `onboarding-cycle-length-*`: a white card with a wheel showing "5 ngày" / "28 ngày" in the middle; the cycle step's hint above it; skip reads "Không chắc" / "Not sure".
- `onboarding-regularity-*`: three cards, "Không đều" selected, the reassurance paragraph under them, fully readable.
- `onboarding-contraception-*`: the "Vì sao hỏi: …" line, then the 8 methods (scrolled to the end: "Cách khác hoặc không muốn nói" visible); no card selected.
- `onboarding-result-*`: "Mọi thứ đã sẵn sàng", a white card "Kỳ kinh tới dự kiến khoảng …" / "Your next period should start around October 30, 2026." with the long date of 2026-10-30 (today 2026-10-02 + 28 days), the reminders line, a dark "Bật nhắc nhở" pill and "Để sau"; no skip.
- `onboarding-due-*`, `onboarding-result-pregnant-*`: the due-date card with "20 tuần, 0 ngày"; the result card "Hôm nay thai được 20 tuần, 0 ngày." / "Today you are 20 weeks, 0 days pregnant."; 4 dots.
- `ax5-onboarding-contraception-vi-light`, `ax5-onboarding-result-vi-light`: huge text wraps without cutting; the buttons stay visible at the bottom.

---
### Task 3: Cycle screens by goal — Today, calendar, day log

Today, the 7-day strip, the ring, "Coming up", the calendar (cells, legend, selected day, VoiceOver) and the day log read `cycle.policy` (spec §4.2). Reminders already follow the goal since Task 1. Trying to conceive looks exactly as before.

**Files:**
- Modify: `App/Cycle/CycleCards.swift`, `App/Cycle/CycleTodayView.swift`, `App/Cycle/CycleCalendarView.swift`, `App/Cycle/CycleDayLogSheet.swift`, `Shared/L10n.swift`, `Shared/Localizable.xcstrings` (via the script)
- Create (tests): `UITests/CycleGoalUITests.swift`, `UITests/CycleGoalScreenshotTests.swift`
- Modify (tests): `UITests/UITestSupport.swift`

**Interfaces:**
- Consumes (Task 1): `CycleCoordinator.policy`, `CycleDisplayPolicy` (`visibleStatus`, `fertileLabel`, `predictedBleedLabel`, `headline`, `showsFertileWindow`, `showsOvulation`, `showsNotContraceptionNote`, `showsLHAndBBT`), `CycleRingGeometry.segments(for:policy:calendar:)`; launch arguments `-seedCycleGoal`, `-seedContraception`.
- Produces: `CycleTexts.status(_:policy:) -> String?` (was non-optional), `CycleTexts.spokenStatus(_:policy:)`, `CycleTexts.phase(day:status:policy:)`, `CycleTexts.nextBleedTitle(_:)`, `CycleTexts.predictedBleed(_:)`, `CycleTexts.fertileTitle(_:)`; `policy:` parameters (default `.conceiving`) on `CycleRingView`, `CycleWeekStrip`, `ComingUpCard`, `CycleLegend`, `CalendarDayCell` and `CycleAccessibility.dayLabel`; `XCUIApplication.launchPinned(…, cycleGoal:contraception:…)`.

- [ ] **Step 1: Write the UI tests first**

In `UITests/UITestSupport.swift`:

Replace:

```swift
    /// optionally with a stored due date, or — with `seedCycles` (a `CycleSeedScenario`
    /// name: empty, period, fertile, late, irregular) — in trying-to-conceive mode with
    /// sample cycles. `largestText` uses Dynamic Type AX5; `extraArguments` adds
    /// more test-only flags (`-seedSessions`, `-seedOverdueSession`). Only the
    /// pregnancy, appointment, cycle and history screens use the pinned clock;
```

with:

```swift
    /// optionally with a stored due date, or — with `seedCycles` (a `CycleSeedScenario`
    /// name: empty, period, fertile, late, irregular) — in trying-to-conceive mode with
    /// sample cycles, and `cycleGoal` / `contraception` (phase 9: `CycleGoal` and
    /// `Contraception` raw values; none means a user from before phase 9, i.e.
    /// trying to conceive). `largestText` uses Dynamic Type AX5; `extraArguments` adds
    /// more test-only flags (`-seedSessions`, `-seedOverdueSession`). Only the
    /// pregnancy, appointment, cycle and history screens use the pinned clock;
```

Replace:

```swift
        dueDate: String? = nil,
        seedCycles: String? = nil,
        skipOnboarding: Bool = true,
        largestText: Bool = false,
```

with:

```swift
        dueDate: String? = nil,
        seedCycles: String? = nil,
        cycleGoal: String? = nil,
        contraception: String? = nil,
        skipOnboarding: Bool = true,
        largestText: Bool = false,
```

Replace:

```swift
        if let dueDate { app.launchArguments += ["-seedDueDate", dueDate] }
        if let seedCycles { app.launchArguments += ["-seedCycles", seedCycles] }
        if dark { app.launchArguments.append("-forceDarkMode") }
        if largestText {
```

with:

```swift
        if let dueDate { app.launchArguments += ["-seedDueDate", dueDate] }
        if let seedCycles { app.launchArguments += ["-seedCycles", seedCycles] }
        if let cycleGoal { app.launchArguments += ["-seedCycleGoal", cycleGoal] }
        if let contraception { app.launchArguments += ["-seedContraception", contraception] }
        if dark { app.launchArguments.append("-forceDarkMode") }
        if largestText {
```

Create `UITests/CycleGoalUITests.swift`:
```swift
import XCTest

/// Phase 9 spec §4.2 and §5: Today, the calendar and the day log by goal.
/// "fertile" is cycle day 13, inside the fertile window, with signals logged.
final class CycleGoalUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Opens today's log from Today.
    @MainActor
    private func openTodaysLog(_ app: XCUIApplication) {
        let logToday = app.buttons["cycleLogTodayButton"]
        XCTAssertTrue(logToday.waitForExistence(timeout: 5))
        app.scrollUntilHittable(logToday)
        logToday.tap()
        XCTAssertTrue(app.buttons["dayLogSave"].waitForExistence(timeout: 5))
    }

    /// A cycle-mode user from before phase 9 (no goal stored) is not shown
    /// onboarding again and keeps the trying-to-conceive screens.
    @MainActor
    func testLegacyCycleUserKeepsTryingToConceive() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "fertile")
        let status = app.descendants(matching: .any)["cycleStatusCard"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["onboardingNext"].exists)
        XCTAssertTrue(status.label.contains("High chance of conceiving"), status.label)
        let fertile = app.descendants(matching: .any)["cycleFertileCard"]
        app.scrollUntilHittable(fertile)
        XCTAssertTrue(fertile.label.contains("Fertile window"), fertile.label)
        XCTAssertFalse(app.staticTexts["cycleNotContraceptionNote"].exists)
        app.swipeDown()
        openTodaysLog(app)
        XCTAssertTrue(app.segmentedControls["dayLogLHPicker"].exists)
    }

    /// Tracking: the window is "High chance of pregnancy" with the
    /// "not contraception" note, and the day log has no LH or BBT rows.
    @MainActor
    func testTrackingLabelsTheWindowAndHidesTheTests() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "fertile", cycleGoal: "tracking")
        let status = app.descendants(matching: .any)["cycleStatusCard"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertTrue(status.label.contains("High chance of pregnancy"), status.label)
        let fertile = app.descendants(matching: .any)["cycleFertileCard"]
        app.scrollUntilHittable(fertile)
        XCTAssertTrue(fertile.label.contains("High chance of pregnancy"), fertile.label)
        let note = app.staticTexts["cycleNotContraceptionNote"]
        app.scrollUntilHittable(note)
        XCTAssertTrue(note.exists)
        XCTAssertTrue(note.label.contains("not a method of contraception"), note.label)

        for _ in 0..<3 { app.swipeDown() }
        openTodaysLog(app)
        XCTAssertFalse(app.segmentedControls["dayLogLHPicker"].exists)
        XCTAssertFalse(app.textFields["dayLogBBTField"].exists)
        let mucus = app.descendants(matching: .any)["dayLogMucusPicker"]
        app.scrollUntilHittable(mucus)
        XCTAssertTrue(mucus.exists)
    }

    /// Tracking on the pill: no fertile window or ovulation anywhere, the
    /// hormonal note, and "Expected bleed" instead of "Next period".
    @MainActor
    func testTrackingOnThePillHidesTheFertileWindow() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "fertile", cycleGoal: "tracking", contraception: "pill")
        let status = app.descendants(matching: .any)["cycleStatusCard"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertFalse(status.label.contains("chance"), status.label)
        XCTAssertTrue(status.label.contains("Day 13 of your cycle"), status.label)
        XCTAssertTrue(status.label.contains("Expected bleed"), status.label)
        let next = app.descendants(matching: .any)["cycleNextPeriodCard"]
        app.scrollUntilHittable(next)
        XCTAssertTrue(next.label.contains("Expected bleed"), next.label)
        XCTAssertFalse(app.descendants(matching: .any)["cycleFertileCard"].exists)
        XCTAssertFalse(app.staticTexts["cycleNotContraceptionNote"].exists)
        let hormonal = app.staticTexts["cycleHormonalNote"]
        app.scrollUntilHittable(hormonal)
        XCTAssertTrue(hormonal.exists)

        app.openCycleTab(.calendar)
        let legend = app.descendants(matching: .any)["calendarLegend"]
        XCTAssertTrue(legend.waitForExistence(timeout: 5))
        XCTAssertTrue(legend.label.contains("Expected bleed"), legend.label)
        XCTAssertFalse(legend.label.contains("Fertile window"), legend.label)
        XCTAssertFalse(legend.label.contains("Ovulation"), legend.label)
        let selected = app.descendants(matching: .any)["calendarSelectedDay"]
        XCTAssertTrue(selected.waitForExistence(timeout: 5))
        XCTAssertTrue(selected.label.contains("Day 13 of your cycle"), selected.label)
    }
}
```

Create `UITests/CycleGoalScreenshotTests.swift`:
```swift
import XCTest

/// Phase 9 spec §5: Today and the calendar while tracking, with and without
/// hormonal contraception (pinned clock, "fertile": cycle day 13).
final class CycleGoalScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launchTracking(_ language: String, dark: Bool, contraception: String? = nil, largestText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication.launchPinned(
            language: language,
            dark: dark,
            seedCycles: "fertile",
            cycleGoal: "tracking",
            contraception: contraception,
            largestText: largestText
        )
        XCTAssertTrue(app.descendants(matching: .any)["cycleStatusCard"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    func testTrackingTodayScreens() {
        for (language, dark) in UITestVariants.all {
            let suffix = UITestVariants.suffix(language, dark)
            let app = launchTracking(language, dark: dark)
            attachScreenshot(app, "cycle-tracking-today-\(suffix)")
            let note = app.staticTexts["cycleNotContraceptionNote"]
            app.scrollUntilHittable(note)
            attachScreenshot(app, "cycle-tracking-coming-up-\(suffix)")
            app.terminate()
        }
    }

    @MainActor
    func testTrackingOnThePillScreens() {
        for (language, dark) in UITestVariants.all {
            let suffix = UITestVariants.suffix(language, dark)
            let app = launchTracking(language, dark: dark, contraception: "pill")
            attachScreenshot(app, "cycle-pill-today-\(suffix)")
            let note = app.staticTexts["cycleHormonalNote"]
            app.scrollUntilHittable(note)
            attachScreenshot(app, "cycle-pill-coming-up-\(suffix)")
            app.openCycleTab(.calendar)
            XCTAssertTrue(app.descendants(matching: .any)["calendarLegend"].waitForExistence(timeout: 5))
            attachScreenshot(app, "cycle-pill-calendar-\(suffix)")
            app.terminate()
        }
    }

    @MainActor
    func testTrackingAtLargestText() {
        let app = launchTracking("vi", dark: false, largestText: true)
        attachScreenshot(app, "ax5-cycle-tracking-today-vi-light")
        let note = app.staticTexts["cycleNotContraceptionNote"]
        app.scrollUntilHittable(note, maxSwipes: 10)
        attachScreenshot(app, "ax5-cycle-tracking-note-vi-light")
        app.terminate()

        let pill = launchTracking("vi", dark: false, contraception: "pill", largestText: true)
        let hormonal = pill.staticTexts["cycleHormonalNote"]
        pill.scrollUntilHittable(hormonal, maxSwipes: 10)
        attachScreenshot(pill, "ax5-cycle-pill-note-vi-light")
    }
}
```

- [ ] **Step 2: Strings**

`cycle.notContraception` and `cycle.hormonalNote` are medical copy for the doctor (Task 5).
```bash
scripts/add-strings.py <<'JSON'
{
  "cycle.highPregnancyChance": [
    "High chance of pregnancy",
    "Khả năng thụ thai cao"
  ],
  "cycle.withdrawalBleed": [
    "Expected bleed",
    "Chảy máu dự kiến"
  ],
  "cycle.notContraception": [
    "These are the days when pregnancy is most likely. Predictions are only estimates and are not a method of contraception: if you want to avoid pregnancy, use a reliable method every time.",
    "Đây là những ngày dễ có thai nhất. Dự đoán chỉ là ước tính, không phải biện pháp tránh thai: nếu chưa muốn có thai, bạn hãy dùng một biện pháp tránh thai đáng tin cậy mỗi lần."
  ],
  "cycle.hormonalNote": [
    "Hormonal contraception usually stops ovulation, so Luna Mom doesn't show fertile days. Bleeding on the pill, implant, injection or hormonal IUD can differ from a natural period, so the expected date is only a rough guide.",
    "Biện pháp tránh thai có nội tiết thường làm ngừng rụng trứng, nên Luna Mom không hiện những ngày dễ thụ thai. Khi dùng thuốc, que cấy, thuốc tiêm hoặc vòng nội tiết, lần ra máu có thể khác kỳ kinh tự nhiên, nên ngày dự kiến chỉ để tham khảo."
  ]
}
JSON
```
Expected output: `515 strings`.

In `Shared/L10n.swift`:

Replace:

```swift
    static var onboardingResultReminders: String { t("onboarding.result.reminders") }
    static var onboardingEnableReminders: String { t("onboarding.enableReminders") }
}
```

with:

```swift
    static var onboardingResultReminders: String { t("onboarding.result.reminders") }
    static var onboardingEnableReminders: String { t("onboarding.enableReminders") }

    // MARK: - Phase 9: cycle screens by goal

    /// The fertile window while tracking (title, legend and status).
    static var cycleHighPregnancyChance: String { t("cycle.highPregnancyChance") }
    /// The predicted bleed on hormonal contraception.
    static var cycleWithdrawalBleed: String { t("cycle.withdrawalBleed") }
    static var cycleNotContraception: String { t("cycle.notContraception") }
    static var cycleHormonalNote: String { t("cycle.hormonalNote") }
}
```

- [ ] **Step 3: Texts, ring, strip and "Coming up" by policy**

`CycleTexts.status` becomes optional: nil is "no status to show" (an ordinary day while tracking). Its two callers change in Steps 4 and 5.

In `App/Cycle/CycleCards.swift`:

Replace:

```swift
    }

    /// The status of a day in words (calendar card, phase pill).
    static func status(_ status: CycleDayStatus) -> String {
        switch status {
        case .period(isPredicted: false): L10n.calendarLegendPeriod
        case .period(isPredicted: true): L10n.calendarLegendPredicted
        default: L10n.cycleStatus(status)
        }
    }
}
```

with:

```swift
    }

    /// The status of a day in words (calendar card, phase pill), as `policy`
    /// shows it. nil for an ordinary day while tracking: tracking never says
    /// "Low chance of conceiving" (phase 9 spec §3.1).
    static func status(_ status: CycleDayStatus, policy: CycleDisplayPolicy = .conceiving) -> String? {
        let visible = policy.visibleStatus(status)
        switch visible {
        case .period(isPredicted: false): return L10n.calendarLegendPeriod
        case .period(isPredicted: true): return predictedBleed(policy)
        case .fertile, .peak:
            return policy.fertileLabel == .highPregnancyChance ? L10n.cycleHighPregnancyChance : L10n.cycleStatus(visible)
        case .low:
            return policy.headline == .nextPeriod ? nil : L10n.cycleStatus(visible)
        }
    }

    /// What VoiceOver says about today in the ring: the trying-to-conceive
    /// wording, or `status(_:policy:)`'s while tracking.
    static func spokenStatus(_ status: CycleDayStatus, policy: CycleDisplayPolicy) -> String? {
        if policy.headline == .fertility { return L10n.cycleStatus(status) }
        if case .period = status { return L10n.cycleStatus(status) }
        return Self.status(status, policy: policy)
    }

    /// "Day 13 · High chance of pregnancy", or "Day 13 of your cycle" when the
    /// day has no status to show.
    static func phase(day: Int, status: CycleDayStatus, policy: CycleDisplayPolicy) -> String {
        Self.status(status, policy: policy).map { L10n.cyclePhase(day, $0) } ?? L10n.cycleDay(day)
    }

    /// "Next period", or "Expected bleed" on hormonal contraception.
    static func nextBleedTitle(_ policy: CycleDisplayPolicy) -> String {
        policy.predictedBleedLabel == .withdrawalBleed ? L10n.cycleWithdrawalBleed : L10n.cycleNextPeriodTitle
    }

    /// "Predicted period", or "Expected bleed" on hormonal contraception.
    static func predictedBleed(_ policy: CycleDisplayPolicy) -> String {
        policy.predictedBleedLabel == .withdrawalBleed ? L10n.cycleWithdrawalBleed : L10n.calendarLegendPredicted
    }

    /// "Fertile window" while trying to conceive, "High chance of pregnancy" while tracking.
    static func fertileTitle(_ policy: CycleDisplayPolicy) -> String {
        policy.fertileLabel == .highPregnancyChance ? L10n.cycleHighPregnancyChance : L10n.cycleFertileTitle
    }
}
```

Replace:

```swift
struct CycleRingView<Center: View>: View {
    let forecast: CycleForecast
    @ViewBuilder var center: Center
```

with:

```swift
struct CycleRingView<Center: View>: View {
    let forecast: CycleForecast
    var policy: CycleDisplayPolicy = .conceiving
    @ViewBuilder var center: Center
```

Replace:

```swift
        ZStack {
            ZStack {
                let segments = CycleRingGeometry.segments(for: forecast)
                // Half the gap, as a fraction of the ring's centre line.
                let inset = segments.count > 1 ? Double(gap / (.pi * (diameter - thickness))) / 2 : 0
```

with:

```swift
        ZStack {
            ZStack {
                let segments = CycleRingGeometry.segments(for: forecast, policy: policy)
                // Half the gap, as a fraction of the ring's centre line.
                let inset = segments.count > 1 ? Double(gap / (.pi * (diameter - thickness))) / 2 : 0
```

Replace:

```swift
struct CycleWeekStrip: View {
    let forecast: CycleForecast?
    let today: Date
    let log: (Date) -> CycleLogRecord?
```

with:

```swift
struct CycleWeekStrip: View {
    let forecast: CycleForecast?
    var policy: CycleDisplayPolicy = .conceiving
    let today: Date
    let log: (Date) -> CycleLogRecord?
```

Replace:

```swift
        HStack(spacing: 0) {
            ForEach(WeekStrip.days(endingAt: today, calendar: AppLocale.calendar)) { day in
                let status = forecast?.dayStatus(for: day.date)
                Button {
                    onSelect(day.date)
```

with:

```swift
        HStack(spacing: 0) {
            ForEach(WeekStrip.days(endingAt: today, calendar: AppLocale.calendar)) { day in
                let status = forecast.map { policy.visibleStatus($0.dayStatus(for: day.date)) }
                Button {
                    onSelect(day.date)
```

Replace:

```swift
                }
                .buttonStyle(.plain)
                .accessibilityLabel(CycleAccessibility.dayLabel(day: day.date, status: status, log: log(day.date), isToday: day.isToday))
                .accessibilityIdentifier("stripDay")
            }
```

with:

```swift
                }
                .buttonStyle(.plain)
                .accessibilityLabel(CycleAccessibility.dayLabel(
                    day: day.date, status: status, log: log(day.date), isToday: day.isToday, policy: policy
                ))
                .accessibilityIdentifier("stripDay")
            }
```

Replace:

```swift
/// "Coming up" (spec §4.2): next period; fertile window and ovulation while not
/// late; average cycle length, typical period length, and regular / not yet.
struct ComingUpCard: View {
    let forecast: CycleForecast
    let typicalPeriodLength: Int

    var body: some View {
```

with:

```swift
/// "Coming up" (spec §4.2): next period; fertile window and ovulation while not
/// late; average cycle length, typical period length, and regular / not yet.
/// Phase 9: `policy` names the window, adds the "not contraception" note while
/// tracking, and hides the window on hormonal contraception (with its note).
struct ComingUpCard: View {
    let forecast: CycleForecast
    let typicalPeriodLength: Int
    var policy: CycleDisplayPolicy = .conceiving

    var body: some View {
```

Replace:

```swift
                .foregroundStyle(.luna(.textPrimary))
                .accessibilityAddTraits(.isHeader)
            row(dot: .cycle, title: L10n.cycleNextPeriodTitle, value: nextPeriodValue)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L10n.cycleNextPeriodTitle + ": " + CycleTexts.nextPeriod(forecast, format: Formatting.spokenDay))
                .accessibilityIdentifier("cycleNextPeriodCard")
            // While late the window has passed; showing it beside "late" confuses.
            if forecast.daysLate <= 0 {
                fertileRows
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(fertileSpoken)
                    .accessibilityIdentifier("cycleFertileCard")
            }
            LunaDivider()
```

with:

```swift
                .foregroundStyle(.luna(.textPrimary))
                .accessibilityAddTraits(.isHeader)
            row(dot: .cycle, title: CycleTexts.nextBleedTitle(policy), value: nextPeriodValue)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(CycleTexts.nextBleedTitle(policy) + ": " + CycleTexts.nextPeriod(forecast, format: Formatting.spokenDay))
                .accessibilityIdentifier("cycleNextPeriodCard")
            // While late the window has passed; showing it beside "late" confuses.
            if forecast.daysLate <= 0, policy.showsFertileWindow {
                fertileRows
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(fertileSpoken)
                    .accessibilityIdentifier("cycleFertileCard")
            }
            if policy.showsNotContraceptionNote {
                goalNote(L10n.cycleNotContraception, identifier: "cycleNotContraceptionNote")
            }
            if !policy.showsFertileWindow {
                goalNote(L10n.cycleHormonalNote, identifier: "cycleHormonalNote")
            }
            LunaDivider()
```

Replace:

```swift
    }

    private var fertileRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            row(dot: .fertile, title: L10n.cycleFertileTitle, value: CycleTexts.fertileRange(forecast, format: Formatting.shortDay))
            row(dot: .teal, ringed: true, title: L10n.cycleOvulationTitle, value: Formatting.shortDay(forecast.ovulationDate))
            if forecast.ovulationConfirmed {
```

with:

```swift
    }

    private func goalNote(_ text: String, identifier: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "info.circle")
                .accessibilityHidden(true)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(identifier)
        }
        .font(.luna(.label))
        .foregroundStyle(.luna(.textSecondary))
    }

    private var fertileRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            row(dot: .fertile, title: CycleTexts.fertileTitle(policy), value: CycleTexts.fertileRange(forecast, format: Formatting.shortDay))
            row(dot: .teal, ringed: true, title: L10n.cycleOvulationTitle, value: Formatting.shortDay(forecast.ovulationDate))
            if forecast.ovulationConfirmed {
```

Replace:

```swift
    private var fertileSpoken: String {
        var parts = [
            L10n.cycleFertileTitle + ": " + CycleTexts.fertileRange(forecast, format: Formatting.spokenDay),
            CycleTexts.ovulation(forecast, format: Formatting.spokenDay),
        ]
```

with:

```swift
    private var fertileSpoken: String {
        var parts = [
            CycleTexts.fertileTitle(policy) + ": " + CycleTexts.fertileRange(forecast, format: Formatting.spokenDay),
            CycleTexts.ovulation(forecast, format: Formatting.spokenDay),
        ]
```

- [ ] **Step 4: Today**

In `App/Cycle/CycleTodayView.swift`:

Replace:

```swift
                        onTrailing: onOpenCalendar
                    )
                    CycleWeekStrip(forecast: cycle.forecast, today: today, log: { cycle.log(on: $0) }) { day in
                        logDay = CycleDaySelection(date: day)
                    }
```

with:

```swift
                        onTrailing: onOpenCalendar
                    )
                    CycleWeekStrip(forecast: cycle.forecast, policy: cycle.policy, today: today, log: { cycle.log(on: $0) }) { day in
                        logDay = CycleDaySelection(date: day)
                    }
```

Replace:

```swift
        let headline = CycleRingHeadline(forecast: forecast)
        return VStack(spacing: 12) {
            CycleRingView(forecast: forecast) {
                ringCenter(forecast, headline: headline)
            }
```

with:

```swift
        let headline = CycleRingHeadline(forecast: forecast)
        return VStack(spacing: 12) {
            CycleRingView(forecast: forecast, policy: cycle.policy) {
                ringCenter(forecast, headline: headline)
            }
```

Replace:

```swift
                .padding(.top, 10)
            notices(forecast)
            ComingUpCard(forecast: forecast, typicalPeriodLength: cycle.settings.typicalPeriodLength)
            maybePregnantCard
            footnotes
```

with:

```swift
                .padding(.top, 10)
            notices(forecast)
            ComingUpCard(forecast: forecast, typicalPeriodLength: cycle.settings.typicalPeriodLength, policy: cycle.policy)
            maybePregnantCard
            footnotes
```

Replace:

```swift
    private func ringTitle(_ headline: CycleRingHeadline) -> String {
        if case .periodDay = headline { return L10n.calendarLegendPeriod }
        return L10n.cycleNextPeriodTitle
    }
```

with:

```swift
    private func ringTitle(_ headline: CycleRingHeadline) -> String {
        if case .periodDay = headline { return L10n.calendarLegendPeriod }
        return CycleTexts.nextBleedTitle(cycle.policy)
    }
```

Replace:

```swift

    /// "Day 13 of your cycle, High chance of conceiving, Next period: October 18 (in 16 days)".
    private func statusLabel(_ forecast: CycleForecast) -> String {
        let status = forecast.daysLate > 0 ? L10n.cycleStatusLate : L10n.cycleStatus(forecast.dayStatus(for: forecast.today))
        return [
            L10n.cycleDay(forecast.cycleDay),
            status,
            L10n.cycleNextPeriodTitle + ": " + CycleTexts.nextPeriod(forecast, format: Formatting.spokenDay),
        ].joined(separator: ", ")
    }
```

with:

```swift

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
```

Replace:

```swift

    private func phasePill(_ forecast: CycleForecast) -> some View {
        let status = forecast.dayStatus(for: forecast.today)
        let fill: LunaToken
        let text: LunaToken
```

with:

```swift

    private func phasePill(_ forecast: CycleForecast) -> some View {
        let policy = cycle.policy
        let status = policy.visibleStatus(forecast.dayStatus(for: forecast.today))
        let fill: LunaToken
        let text: LunaToken
```

Replace:

```swift
            }
        }
        let label = forecast.daysLate > 0 ? L10n.cycleStatusLate : CycleTexts.status(status)
        return Text(L10n.cyclePhase(forecast.cycleDay, label))
            .font(.luna(.captionStrong))
            .foregroundStyle(.luna(text))
```

with:

```swift
            }
        }
        let label = forecast.daysLate > 0
            ? L10n.cyclePhase(forecast.cycleDay, L10n.cycleStatusLate)
            : CycleTexts.phase(day: forecast.cycleDay, status: status, policy: policy)
        return Text(label)
            .font(.luna(.captionStrong))
            .foregroundStyle(.luna(text))
```

- [ ] **Step 5: Calendar**

In `App/Cycle/CycleCalendarView.swift`:

Replace:

```swift
                    grid
                        .padding(.top, 18)
                    CycleLegend()
                        .padding(.top, 14)
                    selectedDayCard
```

with:

```swift
                    grid
                        .padding(.top, 18)
                    CycleLegend(policy: cycle.policy)
                        .padding(.top, 14)
                    selectedDayCard
```

Replace:

```swift
                        CalendarDayCell(
                            day: day,
                            status: cycle.forecast?.dayStatus(for: day),
                            log: cycle.log(on: day),
                            isToday: day == today,
                            isSelected: day == selected
                        ) {
                            selected = day
```

with:

```swift
                        CalendarDayCell(
                            day: day,
                            status: cycle.forecast.map { cycle.policy.visibleStatus($0.dayStatus(for: day)) },
                            log: cycle.log(on: day),
                            isToday: day == today,
                            isSelected: day == selected,
                            policy: cycle.policy
                        ) {
                            selected = day
```

Replace:

```swift

    private var selectedDayCard: some View {
        let status = cycle.forecast?.dayStatus(for: selected)
        let cycleDay = cycle.forecast?.cycleDay(on: selected)
        let line: String? = status.map { status in
            cycleDay.map { L10n.cyclePhase($0, CycleTexts.status(status)) } ?? CycleTexts.status(status)
        }
        return HStack(spacing: 14) {
```

with:

```swift

    private var selectedDayCard: some View {
        let policy = cycle.policy
        let status = cycle.forecast?.dayStatus(for: selected)
        let cycleDay = cycle.forecast?.cycleDay(on: selected)
        let line: String? = status.flatMap { status in
            cycleDay.map { CycleTexts.phase(day: $0, status: status, policy: policy) } ?? CycleTexts.status(status, policy: policy)
        }
        return HStack(spacing: 14) {
```

Replace:

```swift
    let isToday: Bool
    let isSelected: Bool
    let action: () -> Void
```

with:

```swift
    let isToday: Bool
    let isSelected: Bool
    var policy: CycleDisplayPolicy = .conceiving
    let action: () -> Void
```

Replace:

```swift
        }
        .buttonStyle(.plain)
        .accessibilityLabel(CycleAccessibility.dayLabel(day: day, status: status, log: log, isToday: isToday))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("calendarDay")
```

with:

```swift
        }
        .buttonStyle(.plain)
        .accessibilityLabel(CycleAccessibility.dayLabel(day: day, status: status, log: log, isToday: isToday, policy: policy))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("calendarDay")
```

Replace:

```swift

/// Legend under the grid: period, predicted, fertile, ovulation (ringed, as on
/// the grid), logged.
struct CycleLegend: View {
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), alignment: .leading)], alignment: .leading, spacing: 8) {
            item(L10n.calendarLegendPeriod) { Circle().fill(.luna(.cycleStrong)) }
            item(L10n.calendarLegendPredicted) {
                Circle().strokeBorder(.luna(.cycle), style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
            }
            item(L10n.calendarLegendFertile) { Circle().fill(.luna(.fertileSoft)) }
            item(L10n.calendarLegendPeak) {
                Circle().fill(.luna(.ovulation)).overlay(Circle().strokeBorder(.luna(.teal), lineWidth: 1.5))
            }
            item(L10n.calendarLegendLogged) {
```

with:

```swift

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
                item(policy.fertileLabel == .highPregnancyChance ? L10n.cycleHighPregnancyChance : L10n.calendarLegendFertile) {
                    Circle().fill(.luna(.fertileSoft))
                }
            }
            if policy.showsOvulation {
                item(L10n.calendarLegendPeak) {
                    Circle().fill(.luna(.ovulation)).overlay(Circle().strokeBorder(.luna(.teal), lineWidth: 1.5))
                }
            }
            item(L10n.calendarLegendLogged) {
```

Replace:

```swift
/// "October 12, fertile window, positive LH test logged".
enum CycleAccessibility {
    static func dayLabel(day: Date, status: CycleDayStatus?, log: CycleLogRecord?, isToday: Bool) -> String {
        var parts = [Formatting.spokenDay(day)]
        if isToday { parts.append(L10n.calendarA11yToday) }
        switch status {
        case .period(isPredicted: false)?: parts.append(L10n.calendarA11yPeriod)
        case .period(isPredicted: true)?: parts.append(L10n.calendarA11yPredicted)
        case .fertile?: parts.append(L10n.calendarA11yFertile)
        case .peak?: parts.append(L10n.calendarA11yPeak)
        case .low?, nil: break
```

with:

```swift
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
```

- [ ] **Step 6: Day log — LH and BBT behind the policy**

The two rows move, unchanged, into `fertilityTests`; nothing else in the sheet changes and `save()` still writes `lh` and `bbtCelsius` from the state that started from the stored record.

In `App/Cycle/CycleDayLogSheet.swift`:

Replace:

```swift
                .accessibilityAddTraits(.isHeader)

            LunaSheetSectionTitle(title: L10n.dayLogLH)
            Picker(L10n.dayLogLH, selection: $lh) {
                Text(L10n.dayLogLHNone).tag(LHResult?.none)
                Text(L10n.dayLogLHNegative).tag(LHResult?.some(.negative))
                Text(L10n.dayLogLHPositive).tag(LHResult?.some(.positive))
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("dayLogLHPicker")

            LunaSheetSectionTitle(title: L10n.dayLogBBT)
            VStack(alignment: .leading, spacing: 6) {
                TextField(L10n.dayLogBBTPlaceholder, text: $temperatureText)
                    .keyboardType(.decimalPad)
                    .font(.luna(.body))
                    .padding(14)
                    .background(.luna(.card), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityLabel(L10n.dayLogBBT)
                    .accessibilityIdentifier("dayLogBBTField")
                    .onChange(of: temperatureText) { temperatureInvalid = false }
                if temperatureInvalid {
                    Label(L10n.cycleFailure(.invalidTemperature), systemImage: "exclamationmark.triangle.fill")
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.warningText))
                        .accessibilityIdentifier("dayLogBBTError")
                }
                Text(L10n.dayLogBBTHint)
                    .font(.luna(.small))
                    .foregroundStyle(.luna(.textSecondary))
            }
```

with:

```swift
                .accessibilityAddTraits(.isHeader)

            // Phase 9: hidden while tracking unless Profile turns them on; a
            // stored LH result or temperature is kept as it is.
            if cycle.policy.showsLHAndBBT {
                fertilityTests
            }
```

Replace:

```swift
            }
            Button(L10n.commonCancel, role: .cancel) {}
        }
    }
```

with:

```swift
            }
            Button(L10n.commonCancel, role: .cancel) {}
        }
    }

    /// The LH test and basal body temperature (trying to conceive, or
    /// tracking with Profile's override on).
    @ViewBuilder
    private var fertilityTests: some View {
        LunaSheetSectionTitle(title: L10n.dayLogLH)
        Picker(L10n.dayLogLH, selection: $lh) {
            Text(L10n.dayLogLHNone).tag(LHResult?.none)
            Text(L10n.dayLogLHNegative).tag(LHResult?.some(.negative))
            Text(L10n.dayLogLHPositive).tag(LHResult?.some(.positive))
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("dayLogLHPicker")

        LunaSheetSectionTitle(title: L10n.dayLogBBT)
        VStack(alignment: .leading, spacing: 6) {
            TextField(L10n.dayLogBBTPlaceholder, text: $temperatureText)
                .keyboardType(.decimalPad)
                .font(.luna(.body))
                .padding(14)
                .background(.luna(.card), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityLabel(L10n.dayLogBBT)
                .accessibilityIdentifier("dayLogBBTField")
                .onChange(of: temperatureText) { temperatureInvalid = false }
            if temperatureInvalid {
                Label(L10n.cycleFailure(.invalidTemperature), systemImage: "exclamationmark.triangle.fill")
                    .font(.luna(.caption))
                    .foregroundStyle(.luna(.warningText))
                    .accessibilityIdentifier("dayLogBBTError")
            }
            Text(L10n.dayLogBBTHint)
                .font(.luna(.small))
                .foregroundStyle(.luna(.textSecondary))
        }
    }
```

- [ ] **Step 7: Build**

```bash
scripts/test-core.sh
xcodegen generate --quiet
xcodebuild -project KickCounter.xcodeproj -scheme KickCounter \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO -quiet build-for-testing
```
Expected: 610 tests passed; `xcodebuild` exits 0 with no `.swift:…: error:` lines.

- [ ] **Step 8: Commit, push, verify CI**

```bash
git add App/Cycle Shared UITests
git commit -F - <<'MSG'
feat(cycle): show the cycle screens by goal and contraception

While tracking, the fertile window is called "High chance of
pregnancy" and comes with a note that predictions are not
contraception; ordinary days get no "low chance" wording, and the day
log hides the LH test and temperature. On hormonal contraception the
fertile window and ovulation disappear from the ring, strip, calendar
and Coming up, the bleed is "Expected bleed", and a short note explains
why. Trying to conceive is unchanged.

CI-Only-Testing: CycleGoalUITests, CycleGoalScreenshotTests, CycleTodayUITests, CycleUITests, CycleSymptomsUITests, CycleScreenshotTests
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED` with the 3 `CycleGoalUITests` and 3 `CycleGoalScreenshotTests`; the existing cycle classes (pre-phase-9 users) still green.

- [ ] **Step 9: Visual check**

Open each PNG in `ci-artifacts/screenshots/` with the Read tool:
- `cycle-tracking-today-vi-light`, `-en-dark`: the ring with the fertile (green) and ovulation (teal, thicker) stretches as before; the pill under it "Ngày 13 · Khả năng thụ thai cao" / "Day 13 · High chance of pregnancy".
- `cycle-tracking-coming-up-*`: "Dự đoán sắp tới": "Kỳ kinh tiếp theo", then "Khả năng thụ thai cao" with the date range and the ovulation row, then the grey ⓘ note "Đây là những ngày dễ có thai nhất. …" in full, then the divider and the three stats.
- `cycle-pill-today-*`: the ring has only the period stretch and the grey track (no green or teal), the pill reads "Ngày 13 của chu kỳ" / "Day 13 of your cycle" on grey; the ring title "Chảy máu dự kiến" / "Expected bleed".
- `cycle-pill-coming-up-*`: "Chảy máu dự kiến" row, **no** fertile or ovulation rows, the ⓘ hormonal note in full.
- `cycle-pill-calendar-*`: no green or teal days in the month; the legend lists "Kỳ kinh", "Chảy máu dự kiến", "Có ghi dấu hiệu" only.
- `ax5-cycle-tracking-*`, `ax5-cycle-pill-note-vi-light`: the notes wrap without cutting at AX5.

---
### Task 4: Profile — goal picker, contraception, LH/BBT override

The mode card becomes "Goal" with three choices; while tracking, the cycle card ends with the contraception menu and the "Show ovulation tests & temperature" toggle (spec §4.3). Both cycle choices go through `activateCycleMode(goal:)`, so leaving pregnancy for either still stops partner sharing.

**Files:**
- Modify: `App/Profile/ProfileView.swift`, `Shared/L10n.swift`, `Shared/Localizable.xcstrings` (via the script)
- Create (tests): `UITests/ProfileGoalUITests.swift`

**Interfaces:**
- Consumes (Task 1): `CycleCoordinator.preferences`, `updatePreferences(_:)`, `activateCycleMode(goal:)`, `CycleGoal`, `Contraception`; (Task 2) `L10n.contraception(_:)`; (Task 3) `launchPinned(cycleGoal:contraception:)`, the hormonal Today (`cycleHormonalNote`, "Expected bleed"). Existing: `ImPregnantSheet`, `PartnerShareCard` (`partnerShareRow`), `-uiTestingSharing joined`.
- Produces: `enum ProfileModeChoice { case tracking, conceiving, pregnant }` (App target, file-level in `ProfileView.swift`); identifiers `profileContraception`, `profileShowFertilityTests`.

- [ ] **Step 1: Write the UI tests first**

`testTrackCycleFromPregnancyStopsSharing` is the Phase 8 guarantee: leaving pregnancy through the new "Track cycle" segment stops the share exactly like "Trying to conceive" (the fake's state is `notShared` again when she comes back).

Create `UITests/ProfileGoalUITests.swift`:
```swift
import XCTest

/// Phase 9 spec §4.3 and §5: Profile's goal picker (track my cycle · trying to
/// conceive · pregnant), the contraception row and the LH/BBT override.
final class ProfileGoalUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Cycle mode's Profile, scrolled to the cycle card's tracking rows when they exist.
    @MainActor
    private func openCycleProfile(_ app: XCUIApplication) {
        app.openCycleTab(.profile)
        XCTAssertTrue(app.segmentedControls["settingsModePicker"].waitForExistence(timeout: 10))
    }

    /// Choosing "Track cycle" in Profile changes Today at once; choosing the pill
    /// then hides the fertile window.
    @MainActor
    func testSwitchingTheGoalInProfileUpdatesToday() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "fertile")
        let status = app.descendants(matching: .any)["cycleStatusCard"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertTrue(status.label.contains("High chance of conceiving"), status.label)

        openCycleProfile(app)
        let conceiving = app.segmentedControls.buttons["Trying to conceive"]
        XCTAssertTrue(conceiving.isSelected)
        XCTAssertFalse(app.buttons["profileContraception"].exists)
        app.segmentedControls.buttons["Track cycle"].tap()
        let contraception = app.buttons["profileContraception"]
        XCTAssertTrue(contraception.waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Profile"].isSelected) // Profile stays open

        app.openCycleTab(.today)
        waitForLabel(status, containing: "High chance of pregnancy")

        openCycleProfile(app)
        app.scrollUntilHittable(contraception)
        contraception.tap()
        let pill = app.buttons["The pill"]
        XCTAssertTrue(pill.waitForExistence(timeout: 5))
        pill.tap()
        waitForLabel(contraception, containing: "The pill")

        app.openCycleTab(.today)
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        waitForLabel(status, containing: "Expected bleed")
        XCTAssertFalse(app.descendants(matching: .any)["cycleFertileCard"].exists)
    }

    /// The override brings the LH test and temperature back to the day log.
    @MainActor
    func testTheOverrideShowsTheTestsWhileTracking() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "fertile", cycleGoal: "tracking")
        openCycleProfile(app)
        let toggle = app.switches["profileShowFertilityTests"]
        app.scrollUntilHittable(toggle)
        XCTAssertTrue(toggle.exists)
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.switches.firstMatch.tap()
        XCTAssertEqual(toggle.value as? String, "1")

        app.openCycleTab(.today)
        let logToday = app.buttons["cycleLogTodayButton"]
        XCTAssertTrue(logToday.waitForExistence(timeout: 5))
        app.scrollUntilHittable(logToday)
        logToday.tap()
        XCTAssertTrue(app.segmentedControls["dayLogLHPicker"].waitForExistence(timeout: 5))
    }

    /// From pregnancy, "Track cycle" switches mode at once (three cycle tabs,
    /// tracking rows) and, like "Trying to conceive", stops partner sharing.
    @MainActor
    func testTrackCycleFromPregnancyStopsSharing() {
        let app = XCUIApplication.launchPinned(
            language: "en",
            dueDate: UITestDates.dueAtWeek24,
            extraArguments: ["-uiTestingSharing", "joined"]
        )
        app.openTab(.profile)
        let row = app.buttons["partnerShareRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        app.scrollUntilHittable(row)
        waitForLabel(row, containing: "Baby's dad is following")

        for _ in 0..<3 { app.swipeDown() }
        let track = app.segmentedControls.buttons["Track cycle"]
        XCTAssertTrue(track.waitForExistence(timeout: 5))
        track.tap()
        XCTAssertTrue(app.tabBars.buttons["Calendar"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["profileContraception"].waitForExistence(timeout: 5))

        // Back to pregnancy: the share was stopped on the way out.
        app.segmentedControls.buttons["Pregnant"].tap()
        let save = app.buttons["imPregnantSave"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        XCTAssertTrue(app.tabBars.buttons["Kicks"].waitForExistence(timeout: 5))
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        app.scrollUntilHittable(row)
        waitForLabel(row, containing: "Invite baby's dad to follow the journey", timeout: 10)
    }

    @MainActor
    func testProfileGoalScreens() {
        for (language, dark) in UITestVariants.all {
            let suffix = UITestVariants.suffix(language, dark)
            let app = XCUIApplication.launchPinned(
                language: language, dark: dark, seedCycles: "fertile", cycleGoal: "tracking", contraception: "copperIUD"
            )
            openCycleProfile(app)
            attachScreenshot(app, "profile-tracking-\(suffix)")
            let toggle = app.switches["profileShowFertilityTests"]
            app.scrollUntilHittable(toggle)
            attachScreenshot(app, "profile-tracking-rows-\(suffix)")
            app.terminate()
        }
        let large = XCUIApplication.launchPinned(
            language: "vi", seedCycles: "fertile", cycleGoal: "tracking", contraception: "copperIUD", largestText: true
        )
        large.openCycleTab(.profile)
        XCTAssertTrue(large.segmentedControls["settingsModePicker"].waitForExistence(timeout: 10))
        attachScreenshot(large, "ax5-profile-goal-vi-light")
        let toggle = large.switches["profileShowFertilityTests"]
        large.scrollUntilHittable(toggle, maxSwipes: 10)
        attachScreenshot(large, "ax5-profile-tracking-rows-vi-light")
    }
}
```

- [ ] **Step 2: Strings**

```bash
scripts/add-strings.py <<'JSON'
{
  "profile.goal": [
    "Goal",
    "Mục tiêu"
  ],
  "mode.tracking": [
    "Track cycle",
    "Theo dõi chu kỳ"
  ],
  "mode.pregnant.short": [
    "Pregnant",
    "Mang thai"
  ],
  "profile.contraception": [
    "Contraception",
    "Biện pháp tránh thai"
  ],
  "profile.contraception.notSet": [
    "Not set",
    "Chưa chọn"
  ],
  "profile.showFertilityTests": [
    "Show ovulation tests & temperature",
    "Hiện que thử rụng trứng & nhiệt độ"
  ],
  "profile.showFertilityTests.hint": [
    "Adds the LH test and basal body temperature to the day log.",
    "Thêm que thử rụng trứng (LH) và nhiệt độ cơ thể cơ bản vào phần ghi hằng ngày."
  ]
}
JSON
```
Expected output: `522 strings`.

In `Shared/L10n.swift`:

Replace:

```swift
    static var cycleNotContraception: String { t("cycle.notContraception") }
    static var cycleHormonalNote: String { t("cycle.hormonalNote") }
}
```

with:

```swift
    static var cycleNotContraception: String { t("cycle.notContraception") }
    static var cycleHormonalNote: String { t("cycle.hormonalNote") }

    // MARK: - Phase 9: Profile

    static var profileGoal: String { t("profile.goal") }
    static var modeTracking: String { t("mode.tracking") }
    static var modePregnantShort: String { t("mode.pregnant.short") }
    static var profileContraception: String { t("profile.contraception") }
    static var profileContraceptionNotSet: String { t("profile.contraception.notSet") }
    static var profileShowFertilityTests: String { t("profile.showFertilityTests") }
    static var profileShowFertilityTestsHint: String { t("profile.showFertilityTests.hint") }
}
```

- [ ] **Step 3: The goal picker, the contraception row and the override**

In `App/Profile/ProfileView.swift`:

Replace:

```swift
import SwiftUI

/// The Profile tab (spec §4.8), replacing Settings: language, mode (and ending
/// the pregnancy), pregnancy dates or cycle numbers, kick reminder, check-ups,
/// permissions, medical information, replaying the introduction, version.
```

with:

```swift
import SwiftUI

/// The three choices of Profile's goal picker (phase 9 spec §4.3): the two
/// cycle goals and pregnancy, as in onboarding.
enum ProfileModeChoice: Hashable {
    case tracking
    case conceiving
    case pregnant
}

/// The Profile tab (spec §4.8), replacing Settings: language, goal (and ending
/// the pregnancy), pregnancy dates or cycle numbers, kick reminder, check-ups,
/// permissions, medical information, replaying the introduction, version.
```

Replace:

```swift
    }

    private var modeCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.settingsModeSection)
                    .font(.luna(.bodyStrong))
                    .foregroundStyle(.luna(.textPrimary))
                Picker(L10n.settingsModeSection, selection: modeBinding) {
                    Text(L10n.modeTryingToConceive).tag(AppMode.tryingToConceive)
                    Text(L10n.modePregnant).tag(AppMode.pregnant)
                }
                .pickerStyle(.segmented)
```

with:

```swift
    }

    /// "Goal": track my cycle · trying to conceive · pregnant (phase 9).
    private var modeCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.profileGoal)
                    .font(.luna(.bodyStrong))
                    .foregroundStyle(.luna(.textPrimary))
                Picker(L10n.profileGoal, selection: modeBinding) {
                    Text(L10n.modeTracking).tag(ProfileModeChoice.tracking)
                    Text(L10n.modeTryingToConceive).tag(ProfileModeChoice.conceiving)
                    Text(L10n.modePregnantShort).tag(ProfileModeChoice.pregnant)
                }
                .pickerStyle(.segmented)
```

Replace:

```swift
            .font(.luna(.caption))
            .foregroundStyle(.luna(.textSecondary))
        }
        .font(.luna(.body))
        .foregroundStyle(.luna(.textPrimary))
        .lunaCard()
    }
```

with:

```swift
            .font(.luna(.caption))
            .foregroundStyle(.luna(.textSecondary))
            if cycle.preferences.goal == .tracking {
                trackingRows
            }
        }
        .font(.luna(.body))
        .foregroundStyle(.luna(.textPrimary))
        .lunaCard()
    }

    /// Tracking only (phase 9 spec §4.3): the contraception and the LH/BBT override.
    @ViewBuilder
    private var trackingRows: some View {
        LunaDivider()
        HStack(spacing: 8) {
            Text(L10n.profileContraception)
                .frame(maxWidth: .infinity, alignment: .leading)
            Picker(L10n.profileContraception, selection: contraceptionBinding) {
                Text(L10n.profileContraceptionNotSet).tag(Contraception?.none)
                ForEach(Contraception.allCases, id: \.self) { value in
                    Text(L10n.contraception(value)).tag(Contraception?.some(value))
                }
            }
            .pickerStyle(.menu)
            .tint(.luna(.cycleOnSoft))
            .accessibilityIdentifier("profileContraception")
        }
        Toggle(L10n.profileShowFertilityTests, isOn: fertilityTestsBinding)
            .tint(.luna(.cycleStrong))
            .accessibilityIdentifier("profileShowFertilityTests")
        Text(L10n.profileShowFertilityTestsHint)
            .font(.luna(.caption))
            .foregroundStyle(.luna(.textSecondary))
    }
```

Replace:

```swift
    // MARK: - Bindings

    /// Switching to "Trying to conceive" is immediate; switching to "Pregnant"
    /// goes through the "I'm pregnant" sheet so the due date is set.
    private var modeBinding: Binding<AppMode> {
        Binding(
            get: { mode },
            set: { newMode in
                guard newMode != mode else { return }
                switch newMode {
                case .tryingToConceive:
                    Task {
                        await cycle.activateTryingToConceive()
                        await refreshPermissions()
                    }
                case .pregnant:
                    showingImPregnant = true
                case .partner:
                    // The picker offers only the two modes of the mother.
                    break
                }
            }
        )
```

with:

```swift
    // MARK: - Bindings

    /// Both cycle choices are immediate and take the same path,
    /// `activateCycleMode(goal:)`: from pregnancy it switches the mode, which
    /// makes RootView stop partner sharing. "Pregnant" goes through the
    /// "I'm pregnant" sheet so the due date is set.
    private var modeBinding: Binding<ProfileModeChoice> {
        Binding(
            get: {
                guard mode == .tryingToConceive else { return .pregnant }
                return cycle.preferences.goal == .tracking ? .tracking : .conceiving
            },
            set: { choice in
                switch choice {
                case .tracking, .conceiving:
                    let goal: CycleGoal = choice == .tracking ? .tracking : .conceiving
                    guard mode != .tryingToConceive || goal != cycle.preferences.goal else { return }
                    Task {
                        await cycle.activateCycleMode(goal: goal)
                        await refreshPermissions()
                    }
                case .pregnant:
                    guard mode != .pregnant else { return }
                    showingImPregnant = true
                }
            }
        )
    }

    private var contraceptionBinding: Binding<Contraception?> {
        Binding(
            get: { cycle.preferences.contraception },
            set: { value in
                var preferences = cycle.preferences
                preferences.contraception = value
                Task { await cycle.updatePreferences(preferences) }
            }
        )
    }

    private var fertilityTestsBinding: Binding<Bool> {
        Binding(
            get: { cycle.preferences.showsFertilityTests },
            set: { shows in
                var preferences = cycle.preferences
                preferences.showsFertilityTests = shows
                Task { await cycle.updatePreferences(preferences) }
            }
        )
```

- [ ] **Step 4: Build**

```bash
scripts/test-core.sh
xcodegen generate --quiet
xcodebuild -project KickCounter.xcodeproj -scheme KickCounter \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO -quiet build-for-testing
```
Expected: 610 tests passed; `xcodebuild` exits 0 with no `.swift:…: error:` lines. `git diff HEAD~1 -- App/RootView.swift` is empty (the pregnant → cycle `onChange` is untouched).

- [ ] **Step 5: Commit, push, verify CI**

```bash
git add App/Profile/ProfileView.swift Shared UITests/ProfileGoalUITests.swift
git commit -F - <<'MSG'
feat(profile): goal picker, contraception and LH/BBT override

Profile's mode card becomes "Goal" with three choices: track my
cycle, trying to conceive, pregnant. Both cycle choices take the same
path, so leaving pregnancy for either still stops partner sharing.
While tracking, the cycle card lets her change the contraception and
bring back the LH test and temperature in the day log.

CI-Only-Testing: ProfileGoalUITests, ProfileUITests, CycleUITests, PartnerShareUITests
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED` with the 4 `ProfileGoalUITests`; `CycleUITests` (the two-choice tests now tap "Trying to conceive" / "Pregnant" in the three-segment picker), `ProfileUITests` and `PartnerShareUITests` still green.

- [ ] **Step 6: Visual check**

Open each PNG in `ci-artifacts/screenshots/` with the Read tool:
- `profile-tracking-vi-light`, `-en-dark`: the card "Mục tiêu" / "Goal" with a three-segment picker "Theo dõi chu kỳ | Mong con | Mang thai", "Theo dõi chu kỳ" selected, every segment readable (no "…" in light vi; if a segment truncates, report it rather than changing the strings); "Tôi đã có thai" row below.
- `profile-tracking-rows-*`: the cycle card ends with a divider, "Biện pháp tránh thai" with "Vòng tránh thai chữ T bằng đồng" on the right in the cycle colour, the "Hiện que thử rụng trứng & nhiệt độ" toggle (off) and its grey hint.
- `ax5-profile-goal-vi-light`, `ax5-profile-tracking-rows-vi-light`: the picker and rows at AX5; segment text may shrink but the screen does not overflow horizontally.

---
### Task 5: Docs — doctor review, release checklist, README; full CI

Lists the new medical copy for the doctor (§11 of `docs/content-review-for-doctor.md`), adds the phase to the release checklist (no CloudKit change) and documents the code in the README. The commit has **no** `CI-Only-Testing:` line, so CI runs every UI test class.

**Files:**
- Modify: `docs/content-review-for-doctor.md` (new §11 at the end), `docs/release-checklist.md` (new phase 9 section at the end), `README.md` (new section at the end)

**Interfaces:**
- Consumes: the string keys of Tasks 2–4, the screenshot names of Tasks 2–4, `CycleDisplayPolicy`'s table, the launch arguments of Task 1.
- Produces: documentation only.

- [ ] **Step 1: Doctor review**

Append at the end of `docs/content-review-for-doctor.md`:
```markdown

## 11. Mục tiêu "Theo dõi chu kỳ" và phần giới thiệu mới (giai đoạn 9)

Người dùng không mong con giờ có thể chọn "Theo dõi chu kỳ". Dữ liệu và dự đoán giống hệt chế độ "Mong con"
(quy tắc ở mục 6 không đổi); chỉ cách trình bày khác. Các chuỗi dưới đây nằm trong `Shared/Localizable.xcstrings`
(không có cờ `reviewed`), nên **phải được duyệt trước khi gửi App Store**. Xem câu chữ thật trên ảnh chụp
`onboarding-regularity-*`, `onboarding-contraception-*`, `onboarding-cycle-length-*`, `cycle-tracking-coming-up-*`,
`cycle-pill-*` và `profile-tracking-rows-*` trong `ci-artifacts/screenshots/` của lần CI gần nhất.

| Khóa | Nội dung (vi) cần duyệt |
|---|---|
| `contraception.none`, `.condom`, `.pill`, `.implantOrInjection`, `.hormonalIUD`, `.copperIUD`, `.fertilityAwarenessOrWithdrawal`, `.otherOrPrivate` | Tám lựa chọn: Không dùng · Bao cao su · Thuốc tránh thai hằng ngày · Que cấy hoặc thuốc tiêm tránh thai · Vòng tránh thai có nội tiết · Vòng tránh thai chữ T bằng đồng · Tính ngày hoặc xuất tinh ngoài · Cách khác hoặc không muốn nói |
| `onboarding.contraception.why` | "Vì sao hỏi: một số biện pháp như thuốc tránh thai thường làm ngừng rụng trứng, nên Luna Mom sẽ không hiện những ngày dễ thụ thai có thể không đúng với bạn. Thông tin này chỉ dùng để chọn nội dung hiển thị." |
| `cycle.notContraception` | Ghi chú dưới "Khả năng thụ thai cao" khi theo dõi chu kỳ: "Đây là những ngày dễ có thai nhất. Dự đoán chỉ là ước tính, không phải biện pháp tránh thai: nếu chưa muốn có thai, bạn hãy dùng một biện pháp tránh thai đáng tin cậy mỗi lần." |
| `cycle.highPregnancyChance` | Tên cửa sổ thụ thai khi theo dõi chu kỳ: "Khả năng thụ thai cao" (chế độ Mong con vẫn gọi "Cửa sổ thụ thai") |
| `cycle.hormonalNote`, `cycle.withdrawalBleed` | Khi dùng thuốc, que cấy/thuốc tiêm hoặc vòng nội tiết: "Biện pháp tránh thai có nội tiết thường làm ngừng rụng trứng, nên Luna Mom không hiện những ngày dễ thụ thai. Khi dùng thuốc, que cấy, thuốc tiêm hoặc vòng nội tiết, lần ra máu có thể khác kỳ kinh tự nhiên, nên ngày dự kiến chỉ để tham khảo." và nhãn "Chảy máu dự kiến" thay cho "Kỳ kinh tiếp theo" / "Kỳ kinh dự đoán" |
| `onboarding.regularity.irregularNote` | Hiện khi chọn "Không đều": "Chu kỳ dao động một chút là chuyện thường gặp, nhất là sau sinh, khi đang cho con bú hoặc lúc căng thẳng. Bạn ghi càng nhiều kỳ kinh, dự đoán thường càng sát hơn. Nếu chu kỳ hay ngắn hơn 21 ngày hoặc dài hơn 45 ngày, bạn nên đi khám để bác sĩ tư vấn." |
| `onboarding.cycleLength.hint` | "Tính từ ngày đầu của một kỳ kinh đến hết ngày trước kỳ kinh sau. Nhiều người có chu kỳ từ 21 đến 35 ngày, của bạn có thể khác." |
| `onboarding.regularity.*`, `onboarding.result.late`, `profile.showFertilityTests(.hint)` | Đều / Không đều / Không rõ và mô tả; "Theo ngày bạn nhập, kỳ kinh có thể đã trễ khoảng N ngày."; "Hiện que thử rụng trứng & nhiệt độ" |

53. [ ] Bác sĩ đã duyệt (hoặc sửa) toàn bộ các khóa trong bảng trên, cả bản vi lẫn en.
54. [ ] **Nhóm "có nội tiết"** (`Contraception.isHormonal` trong `Packages/KickCore/Sources/KickCore/CycleGoal.swift`):
        thuốc tránh thai hằng ngày, que cấy hoặc thuốc tiêm, vòng có nội tiết. Với nhóm này app **ẩn** cửa sổ thụ thai và
        ngày rụng trứng, gọi lần ra máu là "Chảy máu dự kiến" và không đổi cách tính ngày. Vòng chữ T bằng đồng, bao cao
        su, tính ngày/xuất tinh ngoài vẫn **hiện** "Khả năng thụ thai cao" kèm ghi chú "không phải biện pháp tránh thai".
        Xác nhận cách chia này (thuốc chỉ có progestin, que cấy và vòng nội tiết không phải lúc nào cũng ngừng rụng trứng —
        có nên vẫn ẩn, hay hiện kèm ghi chú?).
55. [ ] **Khi theo dõi chu kỳ, ngày thường không có nhãn "Khả năng thụ thai thấp"** (chỉ "Ngày 13 của chu kỳ"), để
        không ai hiểu nhầm là ngày "an toàn". Xác nhận cách làm này.
56. [ ] **Nhắc nhở khi theo dõi chu kỳ**: chỉ còn "Ngày mai có thể đến kỳ kinh" và "Kỳ kinh đã trễ 3 ngày / Bạn có thể
        thử thai" (không nhắc trước cửa sổ thụ thai). Xác nhận câu nhắc trễ kinh (đã duyệt ở mục 6) cũng phù hợp cho
        người đang dùng biện pháp tránh thai.
57. [ ] **Ngưỡng 21–35 ngày** trong lời giải thích độ dài chu kỳ và **21/45 ngày** trong lời trấn an chu kỳ không đều:
        xác nhận hai cách nói này khớp nhau và đúng với người lớn (giới hạn 45 ngày là ngưỡng app dùng để cảnh báo, mục 6).
```

- [ ] **Step 2: Release checklist**

Append at the end of `docs/release-checklist.md`:
```markdown

## Giai đoạn 9 — Mục tiêu "Theo dõi chu kỳ" và phần giới thiệu mới

### Trước khi gửi App Store
- [ ] **Không đổi CloudKit.** Mục tiêu, biện pháp tránh thai, độ đều của chu kỳ và công tắc "Hiện que thử rụng trứng &
      nhiệt độ" nằm trong App Group (`cycleGoal`, `contraception`, `cycleRegularity`, `cycleShowsFertilityTests`), không
      đồng bộ, như `CycleSettings`. Không cần deploy schema; entitlements và `project.yml` không đổi.
- [ ] **Người dùng cũ không phải xem lại phần giới thiệu.** Cài bản TestFlight đè lên bản trước trên một máy đang ở chế
      độ Mong con có dữ liệu: mở app → vào thẳng Hôm nay, vẫn "Cửa sổ thụ thai", vẫn có que thử LH và nhiệt độ trong phần
      ghi, Cá nhân → "Mục tiêu" đang chọn "Mong con". Làm lại với một máy ở chế độ Mang thai: không đổi gì.
- [ ] **Bác sĩ đã duyệt mục 11** của [`content-review-for-doctor.md`](content-review-for-doctor.md) (các lựa chọn tránh
      thai, ghi chú "không phải biện pháp tránh thai", ghi chú nội tiết, lời trấn an chu kỳ không đều).
- [ ] **Quyền riêng tư.** Biện pháp tránh thai là dữ liệu nhạy cảm: chỉ lưu trên máy (App Group), không gửi đi đâu, không
      nằm trong `PartnerSnapshot`; App Privacy vẫn là "Data Not Collected". Câu ở bước chào mừng ("Dữ liệu chỉ nằm trên
      máy và iCloud của bạn. Không quảng cáo, không bán dữ liệu.") phải còn đúng.
- [ ] **Thông báo.** Cài mới, đi hết nhánh Theo dõi chu kỳ, chọn "Để sau": iOS **không** hỏi quyền thông báo. Cài mới
      lần nữa, chọn "Bật nhắc nhở": iOS hỏi một lần. Khi theo dõi chu kỳ chỉ có nhắc kỳ kinh và trễ kinh (Cài đặt → Thông
      báo không cần kiểm tra; xem bằng cách đổi ngày trên máy thử nếu cần).
- [ ] Ảnh chụp App Store (nếu dùng): `onboarding-goal-vi-light`, `onboarding-result-vi-light`,
      `cycle-tracking-today-vi-light`.
- [ ] Ghi chú phát hành: "Theo dõi chu kỳ" — chọn mục tiêu ngay từ đầu: theo dõi kỳ kinh (biết trước kỳ kinh tới, có tính
      đến biện pháp tránh thai), mong con hoặc mang thai; phần giới thiệu ngắn gọn, câu nào cũng có thể bỏ qua.
```

- [ ] **Step 3: README**

Append at the end of `README.md`:
```markdown

## Mục tiêu "Theo dõi chu kỳ" và phần giới thiệu mới (giai đoạn 9)
- Chế độ chu kỳ có **mục tiêu** (`CycleGoal`): `tracking` (theo dõi kỳ kinh) hoặc `conceiving` (mong con). Cùng dữ liệu,
  lịch và dự đoán; mục tiêu chỉ đổi cách trình bày. Đặc tả: `docs/superpowers/specs/2026-10-08-cycle-tracking-design.md`.
- Lưu trong App Group, không đồng bộ (`CyclePreferences` trong `KickCore/CycleGoal.swift`): mục tiêu (mặc định
  `conceiving`, nên người dùng cũ giữ nguyên mọi thứ), biện pháp tránh thai (`Contraception`, nil = chưa hỏi), độ đều
  (`CycleRegularity`) và công tắc hiện que thử LH/nhiệt độ khi theo dõi chu kỳ.
- `CycleDisplayPolicy` (`KickCore/CycleDisplayPolicy.swift`, thuần, có test) quyết định màn hình nào hiện gì: tên cửa sổ
  thụ thai, ghi chú "không phải biện pháp tránh thai", ẩn cửa sổ và ngày rụng trứng khi dùng biện pháp có nội tiết, "Chảy
  máu dự kiến", có hiện LH/BBT không, và loại nhắc nhở (`reminderKinds`). Hôm nay, Lịch, phần ghi ngày và
  `CycleCoordinator` (nhắc nhở) đều đọc `cycle.policy`.
- Phần giới thiệu: `OnboardingFlow` (`KickCore/OnboardingFlow.swift`) giữ câu trả lời và thứ tự bước cho từng nhánh
  (theo dõi 8 bước, mong con 7, mang thai 4), cách bỏ qua, "Không nhớ", dự đoán ở bước kết quả và những gì cần lưu
  (`finish()`). `OnboardingView` chỉ hiển thị; nhánh chu kỳ lưu qua `CycleCoordinator.completeOnboarding(…)`
  (chỉ hỏi quyền thông báo khi chọn "Bật nhắc nhở").
- Cá nhân: thẻ "Mục tiêu" có ba lựa chọn (Theo dõi chu kỳ · Mong con · Mang thai); hai lựa chọn chu kỳ cùng đi qua
  `CycleCoordinator.activateCycleMode(goal:)`, nên rời chế độ Mang thai bằng lựa chọn nào cũng dừng chia sẻ với bố bé
  (`RootView`, giai đoạn 8). Khi theo dõi chu kỳ, thẻ Chu kỳ có thêm "Biện pháp tránh thai" và công tắc LH/BBT.
- UI test: `-seedCycleGoal <tracking|conceiving>` và `-seedContraception <pill|condom|…>` (cùng `-uiTesting`, thường đi với
  `-seedCycles`); không có hai cờ này là người dùng cũ (mong con).
```

- [ ] **Step 4: Final local checks, commit, push, full CI**

```bash
scripts/test-core.sh
xcodegen generate --quiet
xcodebuild -project KickCounter.xcodeproj -scheme KickCounter \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO -quiet build-for-testing
git status --short .github scripts App/KickCounter.entitlements   # must print nothing
git add README.md docs/content-review-for-doctor.md docs/release-checklist.md
git commit -F - <<'MSG'
docs: cycle tracking goal for the doctor, release checklist and README

The doctor review lists the new medical copy: the contraception
options and why we ask, the "not contraception" note, the hormonal
note and what hormonal contraception hides, and the regularity and
cycle-length wording. The release checklist adds the phase (no
CloudKit change); the README explains the design.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `Test run with 610 tests`; `xcodebuild` exits 0; the `git status` line prints nothing; the CI log shows `==> UI tests: full suite`; `CI PASSED`, including classes no task scoped (`NavigationUITests`, `PregnancyUITests`, `PregnancyTodayUITests`, `KicksUITests`, `HistoryUITests`, `WeightUITests`, `PartnerUITests`, `PartnerScreenshotTests`, `KnowledgeUITests`, `WeekArticleSheetUITests`, `SheetsUITests`, …).

- [ ] **Step 5: Final visual pass and hand-off**

Open every `onboarding-*`, `cycle-tracking-*`, `cycle-pill-*` and `profile-tracking-*` PNG from this run with the Read tool and recheck the Task 2–4 lists. Tell the user that the new medical strings (§11 of `docs/content-review-for-doctor.md`) must be approved by the doctor before an App Store release. Then use `superpowers:finishing-a-development-branch` to open the PR `feat/cycle-tracking` → `main` (run `scripts/test-core.sh` before pushing, as the pre-push hook does).

---
## Self-review

**Spec coverage** (spec section → task):
- §1 goal, §2 decisions (one cycle mode with a goal; tracking presentation; compact onboarding with every question skippable; out of scope) → Tasks 1–4; `CyclePredictor` and the stores are untouched, so the goal only changes presentation.
- §3 data (`CycleGoal`, `Contraception` + `isHormonal`, `CycleRegularity`; App Group keys, not synced; defaults `conceiving` / nil / `.unknown`; lengths still in `CycleSettings`) → `CycleGoal.swift`, `Settings.swift`, `CyclePreferencesTests` (Task 1).
- §3.1 `CycleDisplayPolicy` (every row of the table, the Profile override) → `CycleDisplayPolicy.swift`, `CycleDisplayPolicyTests` (every goal × contraception, Task 1); reminder kinds → `scheduleCycleReminders(kinds:)`, `CycleCoordinator` (Task 1, `CycleCoordinatorGoalTests`); screens → Task 3; override toggle → Task 4.
- §3.2 `OnboardingFlow` (step orders, skipped length keeps the default, "I don't remember" → no date, skipped contraception nil, `finish()` values) → `OnboardingFlow.swift`, `OnboardingFlowTests` (Task 1); the view saves through `completeOnboarding` (cycle period via `CycleCoordinator`, as the spec asks) or `AppMode` + `PregnancyProfile` (Task 2).
- §4.1 screens 1–8 (privacy note, three goal cards with their identifiers, last period + "Không nhớ", wheels 2–10 / 21–45 with the cycle explanation, regularity with the reassurance, contraception with "Vì sao hỏi", result with the predicted date or the "log your next period" line, "Bật nhắc nhở" / "Để sau", pregnancy ending with the same buttons; progress, back, skip) → Task 2.
- §4.2 Today, calendar, day log, reminders by policy → Task 3 (reminders in Task 1).
- §4.3 Profile (goal, contraception row, LH/BBT override, three-choice mode picker, partner unaffected) → Task 4 (clarification 13: the goal row is the picker).
- §5 tests: KickCore (policy matrix, persistence and legacy default, flow order/skips/"don't know"/`finish()`, reminder kinds per goal) → Task 1; UI (each branch completes: `OnboardingUITests`; tracking + pill hides the window: `CycleGoalUITests`, `ProfileGoalUITests`; switching the goal in Profile updates Today: `ProfileGoalUITests`; legacy TTC user not re-onboarded: `CycleGoalUITests.testLegacyCycleUserKeepsTryingToConceive`; result shows the predicted date: `OnboardingUITests.testTrackingBranchShowsThePredictedDate`); screenshots (new steps, tracking Today with and without the pill, Profile rows; vi/en, light/dark, AX5) → Tasks 2–4; scoped CI per task, full suite in Task 5.
- §6 delivery 1–5 → Tasks 1–5 one to one; the doctor list (contraception wording, "not contraception" note, hormonal behaviour, regularity copy), README and release checklist (no CloudKit change) → Task 5.
- Global: pregnant → cycle stops partner sharing through both cycle choices (`activateCycleMode` → `activateTryingToConceive`; `RootView` untouched; `ProfileGoalUITests.testTrackCycleFromPregnancyStopsSharing`); every onboarding-walking UI test updated (Task 2 list, `grep` check in Step 5).

**Placeholder scan:** no "TBD", "TODO", "similar to Task N" or code-free code steps. Every Swift change is a whole file or an exact Replace/with block whose `Replace` text occurs exactly once in the file at that point; the only `<…>` markers are in prose (`<file>.swift`, `<raw value>`).

**Type consistency:** `CycleGoal`, `Contraception` (`isHormonal`), `CycleRegularity`, `CyclePreferences` (`goal`, `contraception`, `regularity`, `showsFertilityTests`, `load(from:)`, `save(to:)`), `CycleDisplayPolicy` (`init(goal:contraception:showsFertilityTestsOverride:)`, `init(_:)`, `.conceiving`, `visibleStatus(_:)`, `reminderKinds`, …), `CycleCoordinator.preferences` / `policy` / `updatePreferences(_:)` / `activateCycleMode(goal:)` / `completeOnboarding(goal:settings:firstPeriodStart:regularity:contraception:requestNotifications:)`, `KickCoordinator.requestNotificationPermission()`, `OnboardingFlow` (`step`, `steps`, `stepNumber`, `stepCount`, `isQuestion`, `canGoBack`, `canContinue`, `next()`, `back()`, `skip()`, `prediction(now:calendar:)`, `finish()`), `OnboardingGoal(mode:cycleGoal:)`, `OnboardingOutcome.cycle(goal:settings:firstPeriodStart:regularity:contraception:)`, `CycleTexts.status(_:policy:)` / `spokenStatus` / `phase(day:status:policy:)` / `nextBleedTitle` / `predictedBleed` / `fertileTitle`, `ProfileModeChoice`, `L10n.contraception(_:)`, the `SettingsKey` names, the launch arguments and every accessibility identifier are spelled the same in every task.

**Verified in a scratch copy:** every code block and `add-strings.py` call of Tasks 1–4 was applied, task by task, by a script to a clone of `feat/cycle-tracking` at `0f4263a` outside the repository, and the result matched, file for file, the tree in which the code was written and checked. After Task 1 `scripts/test-core.sh` passed with 610 tests (three runs); after each task `xcodegen generate` + `xcodebuild build-for-testing` (one `build/DerivedData` inside the clone) exited 0 with no new warnings. Once, outside the implementers' workflow, the new and changed functional UI tests were run on the iPhone 18 Pro simulator: all of `OnboardingUITests` except the screenshot loops, `CycleGoalUITests`, `ProfileGoalUITests` (except the screenshot test), both replay tests of `ProfileUITests`, `KickCounterUITests.testUndoRemovesLastMovement` and the two mode tests of `CycleUITests` passed. The screenshot tests were compiled but left to CI. The clone was deleted afterwards.
