# Siri, Action Button and Control Center: implementation plan

Spec: `docs/superpowers/specs/2026-11-06-siri-controls-design.md`. Branch `feat/siri-controls`.

## Shape
- **KickCore (pure + testable):** `SiriPlanner.plan(_:_:)` decides, from the mode and state, what a command
  does. `SiriControls` (a `@MainActor` struct holding `KickCoordinator`, `ContractionCoordinator` and the
  defaults) loads the state, runs the plan on the real coordinators and returns a `SiriResult`.
- **Shared (app and widget extension):** three `LiveActivityIntent`s (the app process runs them, as the
  Live Activity buttons already do) that map a `SiriResult` to a short generic dialog.
  `SiriIntentBridge.run` is set by the app at launch, like the other bridges.
- **App:** `LunaShortcuts: AppShortcutsProvider` with `AppShortcuts.xcstrings` (vi, en).
- **Widgets:** `LunaControlsBundle`-style controls, `@available(iOS 18, *)`, added to the bundle through a
  `WidgetBundleBuilder` `buildLimitedAvailability`.
- Shared-file edits are minimal: `KickCounterApp.init` (one line), the widget bundle, `project.yml` (none expected).
  `ContractionCoordinator` is not edited: the extra read is an extension in its own file.

## Decisions
- "Start counting kicks": no session means it starts one (the first kick starts a session, there is no
  empty session). A session already running means it does nothing and says so; it never adds a kick, so a
  repeated phrase or button press cannot inflate a count. Kicks are added from the Live Activity card.
- Outside pregnancy mode (or before onboarding) no intent starts anything; the dialog is generic.
  A background intent cannot open the app conditionally on iOS 17 (`ForegroundContinuableIntent` is
  unavailable in extensions and deprecated in 26), so the dialog asks her to open the app.

## Tasks (TDD: test first, watch it fail, then code)
1. `SiriPlannerTests` (KickCore), then `SiriPlanner.swift`.
   `enum SiriCommand { startKicks, timeContraction, stopContractions }`,
   `struct SiriState { mode: AppMode, onboarded: Bool, kickSessionActive: Bool, contractionRunning: Bool, contractionEpisodeActive: Bool }`,
   `enum SiriPlan { recordKick, kickAlreadyRunning, toggleContraction, endContractionTracking, nothingToEnd, needsPregnancyMode }`.
   Tests: `onlyPregnancyModeActs`, `notOnboardedNeverActs`, `startKicksStartsWhenNoSession`,
   `startKicksDoesNotAddWhileRunning`, `timeContractionAlwaysToggles`, `stopEndsRunningOrActiveEpisode`,
   `stopWithNothingToEnd`.
2. `SiriControlsTests` (KickCore, real coordinators on fakes), then `SiriControls.swift`
   (+ `ContractionCoordinator+Siri.swift` for `isTrackingEpisode`).
   Tests: `startKicksStartsSessionAndLiveActivity`, `startKicksTwiceKeepsOneKick`, `timeContractionStartsThenStops`,
   `shortContractionIsDiscarded`, `stopContractionsEndsEpisode`, `stopContractionsWhenIdleChangesNothing`,
   `trackingIsPregnancyOnly` (nothing changes in cycle or partner mode), `notOnboardedChangesNothing`.
3. Strings via `scripts/add-strings.py` (vi + en): titles, descriptions, dialogs, control labels, short titles;
   `L10n` accessors.
4. Intents, bridge wiring, `AppShortcutsProvider` and `AppShortcuts.xcstrings`.
5. Controls (iOS 18) in the widget extension, bundle registration.
6. Release checklist section (device-only), README line.
7. Pre-push gate (core tests, xcodegen, build-for-testing, iOS 17 build if a runtime exists), PR, CI
   (`CI-Only-Testing:` trailer; no UI test is added: the logic is covered in KickCore).

## Mutation check
On `SiriPlanner`: flip the running-session branch and the pregnancy gate; report the red count, then revert.
