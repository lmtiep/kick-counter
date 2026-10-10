# Edit period days on the calendar (Phase 19) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Task 2 also applies `ui-ux-pro-max`.

**Goal:** a "Sửa kỳ kinh" mode on the cycle calendar. The user ticks past period days and saves them all at once.

**Spec:** `docs/superpowers/specs/2026-10-10-calendar-period-edit-design.md` (binding; read it first).

## Global Constraints

- **Branch.** Work on `feat/calendar-period-edit` in `/Users/macos/Documents/kick-counter`, which is already checked out. Never change the `gh` account.
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

## Task 1: KickCore plan + coordinator, KickData store method

**Files**
- Create `Packages/KickCore/Sources/KickCore/PeriodEditPlan.swift`.
- Create `Packages/KickCore/Tests/KickCoreTests/PeriodEditPlanTests.swift`.
- Modify:
  - `CycleRecords.swift`: the `CycleRepository` protocol;
  - `CycleCoordinator.swift`;
  - the KickCore test fakes in `TestSupport.swift`;
  - `CycleFailure`, if `.periodTooLong` is not representable;
  - `Packages/KickData/Sources/KickData/CycleStore.swift` and its tests.

**Interfaces (produced)**
```swift
public struct PeriodEditPlan: Equatable, Sendable {
    public var deletes: [UUID]
    public var updates: [PeriodRecord]
    public var adds: [PeriodRecord]
    public var isEmpty: Bool
    public enum Failure: Error, Equatable { case periodTooLong }
    /// Ticked days the edit starts from: every day of every stored period
    /// (CycleRules.dayRange), start-of-day.
    public static func initialDays(periods: [PeriodRecord], today: Date, calendar: Calendar) -> Set<Date>
    /// The editable window (two years back ... today), shared with AddPastPeriodSheet.
    public static func window(now: Date, calendar: Calendar) -> ClosedRange<Date>
    public static func make(ticked: Set<Date>, periods: [PeriodRecord], now: Date, calendar: Calendar) -> Result<PeriodEditPlan, Failure>
}
// CycleRepository
func applyPeriodChanges(deletes: [UUID], updates: [PeriodRecord], adds: [PeriodRecord], today: Date) throws
// CycleCoordinator
@discardableResult public func applyPeriodEdits(_ plan: PeriodEditPlan) async -> CycleFailure?
```

**Rules for `make`** (spec §2.2):
- Ignore ticked days outside the window or after today.
- Stored periods that start before the window are excluded. So are their days.
- Runs are maximal sequences of consecutive days (`calendar.date(byAdding: .day, value: 1)`).
- A run longer than `CycleRules.longPeriodDays` gives `.failure(.periodTooLong)`.
- Each run keeps the id of the earliest overlapping stored period. Other overlapping stored periods are deleted, and stored periods with no run are deleted.
- `endDate`:
  - nil when the run's last day is today;
  - otherwise the run's last day.
- Unchanged records are omitted.

**`applyPeriodChanges`** (CycleStore, SwiftData) works in this order:
1. Compute the final set of periods (existing − deletes, with updates applied, plus adds).
2. Run `CycleRules.validate` on every changed or added record against that final set.
3. Mutate the context and call `save()` once.
4. On any throw, roll back so nothing is persisted.

**`applyPeriodEdits`** goes through the coordinator's existing `write { }` path, like the other period writes, so the refresh, forecast and reminders behave the same.

**Steps (TDD)**
1. Write the `PeriodEditPlanTests` from spec §3, fail, implement, pass. Use a fixed `Calendar` with time zone Asia/Ho_Chi_Minh plus one DST zone (America/New_York) test.
2. Add coordinator tests, using the existing fake repository extended with `applyPeriodChanges`: a single call, a failure leaves the periods unchanged, the forecast is recomputed.
3. Add KickData tests: all-or-nothing, and a shrink plus an adjacent add passes.
4. Run `scripts/test-core.sh`, then commit "feat(cycle): period edit plan and atomic period changes" with no UI trailer (`CI-Only-Testing: none` if the script supports it; otherwise list `CycleHistoryUITests`).

## Task 2: App edit mode

**Files**
- Modify `App/Cycle/CycleCalendarView.swift`. Split the edit grid into a new `App/Cycle/CalendarPeriodEditor.swift` if the file grows past about 400 lines.
- Add strings.
- Add `UITests/CalendarPeriodEditUITests.swift` and `UITests/CalendarPeriodEditScreenshotTests.swift`. Follow the existing screenshot test pattern: vi light, vi dark, AX5.
- Update `README` and the release checklist ("Giai đoạn 19": tick past days across two months on a device, then check History and the forecast).

**Behaviour:** spec §2.1 and §2.3 exactly.
- `@State var editing: Bool`, plus `@State var ticked: Set<Date>` seeded from `PeriodEditPlan.initialDays` when entering.
- Save calls `PeriodEditPlan.make`:
  - `.periodTooLong` shows the inline error;
  - otherwise `await cycle.applyPeriodEdits(plan)`. If that returns a failure, show `L10n.cycleFailure(...)` inline and stay in edit mode. If it succeeds, leave edit mode and announce.
- Cancel uses `.confirmationDialog` when `ticked != initial`.
- Day cells in edit mode are toggle `Button`s with:
  - accessibility label = spoken date (+ "ngày có kinh" when ticked);
  - `.isSelected` when ticked;
  - identifier `periodEditDay-yyyymmdd`;
  - future days and days before the window `.disabled`.
- Minimum hit size 44 pt. Respect `LunaMotion.isEnabled`.
- The UI tests use the existing cycle seed launch arguments (look at `CycleHistoryUITests` / `CalendarUITests` for how periods are seeded and how History is opened).

**Steps**
1. Build the edit mode and the strings, then run `build-for-testing`.
2. Write the UI tests and the screenshot tests.
3. Commit "feat(cycle): edit period days on the calendar" with the trailer `CI-Only-Testing: CalendarPeriodEditUITests,CalendarPeriodEditScreenshotTests`. Push, then run `scripts/ci-wait.sh` until it passes. Read the screenshots it downloads, and fix anything that looks wrong (clipped text, low contrast, ticks misaligned at AX5).
