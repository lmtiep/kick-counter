# Past periods and the Today size wording (Phase 13) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Task 2 also applies `ui-ux-pro-max`.

**Goal:**
- A period started on a past day is closed at the typical period length.
- The cycle history gets a "Thêm kỳ kinh trước đây" sheet.
- The pregnancy Today card uses the Phase 11 weight wording from week 10.

**Spec:** `docs/superpowers/specs/2026-10-08-past-periods-design.md` (binding).

## Global Constraints

- **Branch.** Work on `feat/past-periods` in `/Users/macos/Documents/kick-counter`, which is already checked out. Never change the `gh` account.
- **Forbidden edits:**
  - workflow, `ci.sh` or `test-core.sh` files;
  - entitlements.
- **KickCore imports.** `KickCore` must not import SwiftUI, UIKit, SwiftData or CloudKit.
- **Strings.**
  - Only through `scripts/add-strings.py` (en + vi, northern Vietnamese); no `Text("literal")`.
  - Never write "bất thường" or "abnormal".
- **Tokens.** Luna colour tokens only, with text/background pairs that `LunaContrast.usages` already lists. Fonts only through `Font.luna`.
- **Local verification.**
  - Run `scripts/test-core.sh` (output to a file), `xcodegen generate --quiet`, and `xcodebuild … -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO -quiet build-for-testing` on 'iPhone 18 Pro'.
  - Never run UI tests locally. Never open Xcode.
- **Commits.** The trailer is `CI-Only-Testing: A,B` (comma-separated) followed by `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. After each commit: push, then `scripts/ci-wait.sh`. Do not push while a run for this branch is in progress.
- **UI test rules.** Use waits, never `sleep`. Call `scrollUntilHittable` before touching anything below the fold. Put `.accessibilityElement` before `.accessibilityIdentifier`.

## Task 1: KickCore

**Files:**
- `Packages/KickCore/Sources/KickCore/CycleCoordinator.swift`.
- Tests in `CycleCoordinatorTests.swift`, or a new `PastPeriodTests.swift`, using the existing fakes and fixtures in that test file.

**Changes:**
- `startPeriodReturningID(on:)`: build the record with the helper below.

  ```swift
  /// A period started on a day long enough ago that it is over by today is
  /// stored closed at the typical length (phase 13 spec §3.1); otherwise open.
  func newPeriod(startingOn day: Date) -> PeriodRecord
  ```

  It returns `CycleRules.assumedPeriod(startingOn: start, typicalLength: settings.typicalPeriodLength, today: now(), calendar: calendar)`. Check that `assumedPeriod` already returns an open record when the period is not over yet; if not, implement the condition explicitly: closed when `start + typical − 1 < today`.
- Add:

  ```swift
  public func addPastPeriod(start: Date, length: Int) async -> CycleFailure?
  ```

  - `length` is clamped to 2…10.
  - The end is `start + length − 1`. If that is after today, the record is open.
  - It goes through `write { try store.addPeriod(record, today: now()) }`, so validation and reporting work as for the other writes.
  - It must map overlap and future errors to distinguishable `CycleFailure` values. Check the existing cases and add `.overlapsExistingPeriod` and `.futureDate` if missing; keep existing raw behaviour.

**Tests (TDD), with a pinned clock:**
- `startOnALongPastDayIsClosedAtTypicalLength`: 20 days ago, typical 5, gives `endDate = start + 4`.
- `startTodayStaysOpen`.
- `startTwoDaysAgoWithTypicalFiveStaysOpen`.
- `addPastPeriodClosed`.
- `addPastPeriodEndingAfterTodayIsOpen`.
- `addPastPeriodOverlapFails`: the failure is returned and nothing is stored.
- `addPastPeriodFutureFails`.
- `addingPastPeriodsFeedsTheAverage`: use `CycleHistory.make` on the coordinator's periods; the average appears after the second period.

**Commit trailer:** `CI-Only-Testing: CycleUITests,CycleTodayUITests`.

## Task 2: App, the sheet, the history entry, the Today wording, tests, docs

**Strings** (`scripts/add-strings.py`), as `[en, vi]`:

| Key | en | vi |
|---|---|---|
| `cycleHistory.addPast` | "Add a past period" | "Thêm kỳ kinh trước đây" |
| `cycleHistory.addPastBleed` | "Add a past bleed" | "Thêm lần ra máu trước đây" |
| `addPast.start` | "Start date" | "Ngày bắt đầu" |
| `addPast.length` | "Days of bleeding" | "Số ngày hành kinh" |
| `addPast.lengthBleed` | "Days of bleeding" | "Số ngày ra máu" |
| `addPast.range` | "From %1$@ to %2$@" | "Từ %1$@ đến %2$@" |
| `addPast.ongoing` | "Still going on" | "Vẫn đang diễn ra" |
| `addPast.save` | "Save" | "Lưu" |
| `addPast.saved` | "Period added" | "Đã thêm kỳ kinh" |
| `addPast.errorOverlap` | "This overlaps a period you've already logged." | "Trùng với một kỳ kinh đã ghi." |
| `addPast.errorFuture` | "You can't choose a date in the future." | "Không chọn được ngày trong tương lai." |
| `addPast.errorSave` | "Couldn't save. Please try again." | "Không lưu được. Bạn thử lại nhé." |
| `pregnancy.baby.sizeWeight` | "Your baby weighs about as much as %@" | "Bé nặng tương đương %@" |

Reuse `common.cancel` and `L10n.days`.

**Files:**
- Create `App/Cycle/AddPastPeriodSheet.swift`.
- Modify:
  - `App/Cycle/CycleHistoryView.swift`: the button below the summary and in the empty state, the `.sheet`, and the toast (reuse the app's `.toast` modifier from Today);
  - `App/Pregnancy/PregnancyCards.swift`: the size line uses `sizeWeight` when the week has `weightG`;
  - `App/Partner/PartnerTodayView.swift`: the same rule;
  - `Shared/L10n.swift`.
- UI tests in `UITests/CycleHistoryUITests.swift` and `PregnancyTodayUITests.swift`.
- Screenshots in `CycleHistoryScreenshotTests.swift`.

**The sheet:** see spec §3.2. A graphical `DatePicker` in `...today`, a `Stepper` from 2 to 10 with the value `L10n.days(n)`, a live range line, an inline error (`addPastError`) and a Save pill (`addPastSave`) disabled while saving.

**UI tests:**
- `testAddPastPeriodFromHistory`: seed `fertile`, which has 4 rows. Open the history, add a period that starts 120 days before the pinned clock with 5 days, and expect 5 rows. Pick the date by typing or by picker interaction. If a graphical `DatePicker` is too hard to drive, use a `.compact` picker and set it the way the existing onboarding last-period tests do; check `OnboardingUITests`.
- `testAddPastPeriodOverlapShowsError`: a start inside an existing period shows the error and keeps 4 rows.
- `testStartingAPeriodOnAnOldDayClosesIt`: seed `empty` or `fertile`. On the calendar, go back months, open a day, tap `dayLogStartPeriod`. In the history, the row label contains "period 5 days".
- `testTodayCardUsesWeightWording`: pregnancy at week 24 shows "weighs about as much as"; at week 8 (pick a due date that gives week 8) it shows "about the size of". Use the existing `seedDueDate` helpers.

**Screenshots:**
- `cycle-add-past-vi-light`;
- `cycle-add-past-vi-dark`;
- `ax5-cycle-add-past-vi-light`;
- `cycle-history-with-add-vi-light`.

**Docs:**
- `docs/content-review-for-doctor.md`: a new §14 continuing the item numbers after the current last one. It covers:
  - the assumed typical length for back-filled periods;
  - the wording "Thêm lần ra máu trước đây" for hormonal users;
  - "Bé nặng tương đương".
- README: a line in the cycle history section.
- `docs/release-checklist.md`: a "Giai đoạn 13" block with a manual check: add 3 past periods and check that the prediction changes.

**Commit trailer:** `CI-Only-Testing: CycleHistoryUITests,CycleHistoryScreenshotTests,PregnancyTodayUITests,CycleUITests`.
