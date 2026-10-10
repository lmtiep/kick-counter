# Contraction timer (Phase 20) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Tasks 2–3 also apply `ui-ux-pro-max`.

**Goal:** a contraction timer with 5-1-1 and preterm alerts, history, and a Live Activity with a Start/Stop button.

**Spec:** `docs/superpowers/specs/2026-10-10-contraction-timer-design.md` (binding; read it first).

## Global Constraints

- **Branch.** Work on `feat/contraction-timer` in `/Users/macos/Documents/kick-counter`, which is already checked out. Never change the `gh` account.
- **Forbidden edits:**
  - workflow, `ci.sh` or `test-core.sh` files;
  - entitlements.
- **KickCore imports.** `KickCore` must not import SwiftUI, UIKit, SwiftData or CloudKit.
- **Strings.**
  - Only through `scripts/add-strings.py` (en + vi, northern Vietnamese); no `Text("literal")`.
  - Never write "bất thường" or "abnormal".
- **Tokens.** Luna colour tokens only, with text/background pairs that `LunaContrast.usages` already lists (add a usage and a contrast test if a new pair is needed). Fonts only through `Font.luna`.
- **Local verification.**
  - Run `scripts/test-core.sh` (output to a file, read the summary), `xcodegen generate --quiet`, and `xcodebuild … -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO -quiet build-for-testing` on 'iPhone 18 Pro'.
  - Never run UI tests locally. Never open Xcode.
- **Commits.** The trailer is `CI-Only-Testing: A,B` (comma-separated UI test classes this task touches) followed by `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. After each commit: push, then `scripts/ci-wait.sh`. Do not push while a run for this branch is in progress.
- **UI test rules.** Use waits, never `sleep`. Call `scrollUntilHittable` before touching anything below the fold. Put `.accessibilityElement` before `.accessibilityIdentifier`.

## Task 1: KickCore + KickData (spec §3, §5 KickCore/KickData)
- **Patterns to follow:**
  - `PillDose` / `PillDoseStore` / `PillDoseDTO` (Phase 17) for the model, store, `DataReset` and the backup array;
  - `KickCoordinator` for the coordinator;
  - the existing Live Activity protocol and fake used by `KickCoordinator` for the contraction activity protocol.
- **Files:**
  - `ContractionRules.swift`, `ContractionStats.swift` and `ContractionCoordinator.swift` in KickCore;
  - `Contraction` model + `ContractionStore` in KickData;
  - `Backup`/`BackupCodec`/`BackupStore` additions;
  - tests.
- **Steps (TDD):** stats and rules tests → coordinator tests → store, reset and backup tests. Then run `test-core.sh` and KickData `swift test`, and commit "feat(contractions): rules, stats, coordinator and storage" with the trailer `CI-Only-Testing: BackupUITests` (or another existing small class if that one does not exist).
- **Produces** (exact names are up to you; list them in your report): the stats API, `ContractionAlert`, the coordinator API (`toggle`, `undoLast`, `delete(id:)`, `endEpisode`), and the Live Activity protocol.

## Task 2: App screen and entries (spec §4.1–4.3, §4.5 strings)
- **Screen:** `App/Contractions/ContractionTimerView.swift`, plus history and card views as needed. Use the call-button logic from the kick alert in `App/Counter/KicksView.swift`; extract a shared view if that is cleaner.
- **Entries:**
  - the Today shortcut in `App/Pregnancy/PregnancyTodayView.swift` `shortcuts(...)`, for week ≥ 28;
  - the Kicks tab row.
- **Wiring:** create the coordinator in the app environment, as `KickCoordinator` is. Add the DEBUG seeds `-seedContractions 511|preterm`, following the existing seed launch arguments.
- **Tests:** `UITests/ContractionTimerUITests.swift` and `UITests/ContractionTimerScreenshotTests.swift`. Commit with the trailer `CI-Only-Testing: ContractionTimerUITests,ContractionTimerScreenshotTests`, push, and run ci-wait. Then read the screenshots (`sips -Z 900`) and fix any visual problems.

## Task 3: Live Activity (spec §4.4)
- **Shared:**
  - `Shared/ContractionActivityAttributes.swift`;
  - `Shared/ToggleContractionIntent.swift`, with a bridge like `KickIntentBridge`, set at launch in `KickCounterApp.swift`.
- **Widgets:** `Widgets/ContractionLiveActivityWidget.swift`, registered in `KickCounterWidgetsBundle.swift`. Match the look of `KickLiveActivityWidget`, light and dark.
- **App:** a system implementation of the Task 1 protocol next to `SystemLiveActivityManager`. It ends the activity on foreground or launch after 2 h idle, on end-episode and on delete-all.
- **`project.yml`:** update only if the target membership needs it, then run `xcodegen generate`.
- **Commit** with the UI trailer of Task 2, so its tests guard regressions.

## Task 4: Docs (spec §4.5)
- **Doctor doc:** `docs/content-review-for-doctor.md` §18, items 96–100. Also add rows to `~/Downloads/Luna Mom - doi chieu y khoa.xlsx` with openpyxl, matching the existing columns and styles.
- **Other docs:** the README section, `docs/release-checklist.md` "Giai đoạn 20", and `docs/app-review-notes.md`.
- **Commit** with the trailer `CI-Only-Testing: ContractionTimerUITests`.
