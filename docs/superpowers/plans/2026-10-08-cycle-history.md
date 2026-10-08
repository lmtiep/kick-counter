# Cycle history ("Lịch sử chu kỳ", Phase 10) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. For Task 2, also apply the `ui-ux-pro-max` skill to review visual detail. Do **not** change behaviour, accessibility identifiers, strings or colour tokens that this plan fixes. Task 3 writes documentation, not code.

**Goal:** The cycle mode gets a "Lịch sử chu kỳ" page, opened from Today's "Sắp tới" card. It shows:
- a summary: average cycle length and its range, and average period length;
- every cycle, newest first, each with a proportional bar for bleeding and logged days;
- a detail page per cycle listing what was logged on each day, where tapping a day opens the existing day-log sheet.

**Architecture:**
- **KickCore (pure).** `CycleHistory.make(periods:logs:now:calendar:)` turns the existing `PeriodRecord`s and `CycleLogRecord`s into `CycleHistorySummary`. It uses the same averaging rule and constants as `CyclePredictor`, so Today and the history always show the same average.
- **App target.** `CycleHistoryView` and `CycleDetailView` read `cycle.periods` and `cycle.logs` from the `@Observable` `CycleCoordinator`. A save in the day-log sheet therefore refreshes them on its own.
- **No change to stored data, sync or CloudKit.**

**Tech Stack:** Swift 6 (strict concurrency), SwiftUI (iOS 17), Swift Testing (KickCore), XCTest (UI), XcodeGen, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-08-cycle-history-design.md`. Previous plan, for conventions: `docs/superpowers/plans/2026-10-08-cycle-tracking.md`.

## Global Constraints

- **No CI script, workflow or entitlement changes.** Do not edit:
  - `.github/workflows/*`;
  - `scripts/ci.sh` or `scripts/test-core.sh`;
  - `App/KickCounter.entitlements`;
  - the `entitlements:` section of `project.yml`.
- **Language and platforms.**
  - Swift language mode 6 with strict concurrency.
  - iOS deployment target `17.0`.
  - Package platforms `.iOS(.v17), .macOS(.v14)`.
  - No third-party SDKs.
- **KickCore imports.** `KickCore` must not import SwiftUI, UIKit, SwiftData or CloudKit.
- **Strings.**
  - Every UI string goes through `L10n` (`Shared/L10n.swift`) and lives in `Shared/Localizable.xcstrings` with both `en` and `vi`.
  - Add strings **only** with `scripts/add-strings.py` (JSON on stdin).
  - Never write `Text("…")` with a literal; use `Text(L10n.…)` or `Text(verbatim:)`.
  - Vietnamese copy is northern Vietnamese.
- **Wording.** Never write "bất thường" or "abnormal". A cycle outside 21–45 days is described only as "Không tính vào trung bình" / "Not counted in the average".
- **Colours.** Use only Luna tokens (`.luna(.<token>)`), never hex. Every text/background pair must already be in `LunaContrast.usages`, so `ContrastTests` stay green. The pairs this phase uses, all already declared, are:
  - `textPrimary` on `card`;
  - `textSecondary` on `card`;
  - `cycleOnSoft` on `card`.

  The bar's fills are decorative shapes, not text: `cycle` for bleeding, `cycleSoft` for the track, `cycleStrong` for the dots.
- **Fonts.** Use only `Font.luna(_:)`. SF Symbols may use `.system(size:weight:)`.
- **Motion.** No animation in this phase.
- **Commits.**
  - Work on branch `feat/cycle-history`, which is already checked out with the spec committed.
  - **Never** change the `gh` account or log in.
  - Every commit message ends with a blank line followed by the trailer block: a `CI-Only-Testing: <UI test classes>` line, then immediately `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, with no blank line between them.
  - Task 3's commit deliberately has **no** `CI-Only-Testing:` line, so CI runs the full UI suite.
- **Local verification only.**
  - Run `scripts/test-core.sh`, `xcodegen generate --quiet` and `xcodebuild … build-for-testing` with `-derivedDataPath build/DerivedData`. Use no other DerivedData path.
  - **Never** run UI tests locally, and never open the project in Xcode (it rewrites the string catalogs).
  - If `git status --short Shared/` lists any file before you start, stop and report it. Do not commit it.
- **UI test rules.**
  - Wait with `waitForExistence`, `waitForLabel` or an `XCTNSPredicateExpectation`; never use `sleep`.
  - Call `app.scrollUntilHittable(element)` before touching anything below the fold.
  - Put `.accessibilityElement(children: .combine)` **before** `.accessibilityIdentifier(…)`.
- Keep every existing accessibility identifier. The new ones are:
  - `cycleHistoryLink`
  - `cycleHistorySummary`
  - `cycleHistoryAverageCycle`
  - `cycleHistoryAveragePeriod`
  - `cycleHistoryNeedMore`
  - `cycleHistoryEmpty`
  - `cycleHistoryRow`
  - `cycleDetailDay`
  - `cycleDetailEmpty`

## Verification workflow

- **Locally, for every task with code:**
```bash
scripts/test-core.sh > build/test-core.log 2>&1; tail -5 build/test-core.log
xcodegen generate --quiet
xcodebuild -project KickCounter.xcodeproj -scheme KickCounter \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO -quiet build-for-testing
```
  - `xcodebuild` must exit 0 with no `<file>.swift:<line>:<col>: error:` lines.
  - The KickCore test count is 613 before this phase, 625 after Task 1, and stays 625 through Tasks 2–3.
  - After every task, `grep -rn "import SwiftUI\|import UIKit\|import SwiftData\|import CloudKit" Packages/KickCore/Sources` must print nothing.
- **CI is the done condition of every task:**
  1. Commit with the task's `CI-Only-Testing:` line.
  2. Run `git push` (the pre-push hook runs `scripts/test-core.sh`).
  3. Run `scripts/ci-wait.sh`.

  Screenshots land in `ci-artifacts/screenshots/<name>_0_<UUID>.png`.
- **Known flake:** an unrelated UI test sometimes times out in `waitForExistence`. If that is the only failure, rerun the failed jobs **once** with `gh run rerun <id> --failed`. If it fails again, or a task's own test fails, use `superpowers:systematic-debugging`.
- **Visual check (Task 2):** open every listed PNG with the Read tool and check each item. Use `superpowers:verification-before-completion` before calling a task done.

## Spec clarifications (decisions made while planning)

1. **Detail page content.**
   - Each logged day shows one summary line built by the existing `CycleTexts.logSummary(log, mode: .tryingToConceive)`, e.g. "Lượng kinh: Ít · Bình thản · Đầy hơi · 36,4 °C". This is the same wording as Today's log card and the calendar.
   - When the note is not blank, its text follows on a second line in secondary style.
   - This replaces the spec's field-by-field lines; the information is the same. Logged values are always shown, LH and BBT included, which matches the spec's "any value the user has logged is always shown".
2. **Range display.** `cycleLengthRange` follows the spec (nil with fewer than two usable cycles). The view shows the range line only when `lowerBound < upperBound`; "28–28 ngày" says nothing.
3. **Reloading.** No explicit reload is needed. The pages compute from `cycle.periods` and `cycle.logs`, which `CycleCoordinator` (`@Observable`) refreshes after `saveLog`.
4. **Navigation.** Today's `NavigationStack` hides its bar (`.toolbar(.hidden, for: .navigationBar)`). Both new pages set `.toolbar(.visible, for: .navigationBar)` and `.navigationBarTitleDisplayMode(.inline)`, so the system back button appears. The link is a `NavigationLink(value: CycleHistoryRoute.list)`. Today gains `.navigationDestination(for: CycleHistoryRoute.self)`.
5. **Fixture dates (pinned clock `2026-10-02T12:00:00Z`, seed `fertile`).**
   - Periods start on Jun 28, Jul 26, Aug 23 and Sep 20 2026. Each is closed and lasts 5 days.
   - The cycles are three of 28 days, plus the current one at day 13.
   - The current cycle has logged days on Sep 28 – Oct 2, which are offsets 8–12.
   - The older cycles have no logs.
   - So the summary shows 28 days with no range line, and a 5-day average period. There are 4 rows. The current cycle's detail lists 5 days, the first being "Ngày 9 · 28 thg 9" / "Day 9 · Sep 28".

## File Structure

- Create `Packages/KickCore/Sources/KickCore/CycleHistory.swift`: `PastCycle`, `CycleHistorySummary`, `CycleHistory.make`, and `CycleLogRecord.hasContent`.
- Create `Packages/KickCore/Tests/KickCoreTests/CycleHistoryTests.swift`.
- Create `App/Cycle/CycleHistoryView.swift`, with:
  - `CycleHistoryRoute`;
  - `CycleHistoryView`;
  - `CycleHistoryRowView`;
  - `CycleHistoryBar`;
  - `CycleDetailView`;
  - `CycleHistoryTexts`, the spoken sentences.
- Modify `App/Cycle/CycleCards.swift`: `ComingUpCard` gains the link row.
- Modify `App/Cycle/CycleTodayView.swift`: add `.navigationDestination`.
- Modify `Shared/L10n.swift` and `Shared/Localizable.xcstrings` (through the script).
- Create `UITests/CycleHistoryUITests.swift` and `UITests/CycleHistoryScreenshotTests.swift`.
- Modify `docs/content-review-for-doctor.md`, `docs/release-checklist.md` and `README.md` (Task 3).

---

### Task 1: KickCore — `CycleHistory`

**Files:**
- Create: `Packages/KickCore/Sources/KickCore/CycleHistory.swift`
- Test: `Packages/KickCore/Tests/KickCoreTests/CycleHistoryTests.swift`

**Interfaces:**
- **Consumes:**
  - `CycleRules.normalized(_:calendar:)` for both `PeriodRecord` and `CycleLogRecord`;
  - `CycleRules.dayRange(of:today:calendar:)`;
  - the internal constants `CyclePredictor.usableCycleLengths` (21...45) and `CyclePredictor.maxCyclesAveraged` (6);
  - for tests, `utcCalendar` and `date(_:)` from the KickCore test support.
- **Produces:**
  - `public struct PastCycle` with `periodID: UUID`, `id: UUID`, `start: Date`, `length: Int?`, `periodLength: Int`, `isCurrent: Bool`, `cycleDay: Int?`, `countsTowardAverage: Bool` and `loggedDays: [Int]`;
  - `public struct CycleHistorySummary` with `averageCycleLength: Int?`, `cycleLengthRange: ClosedRange<Int>?`, `averagePeriodLength: Int?` and `cycles: [PastCycle]` (newest first);
  - `public enum CycleHistory { public static func make(periods:logs:now:calendar:) -> CycleHistorySummary }`;
  - `extension CycleLogRecord { public var hasContent: Bool }`.

- [ ] **Step 1: Write the failing tests** (12 tests)

```swift
import Foundation
import Testing
@testable import KickCore

struct CycleHistoryTests {
    let calendar = utcCalendar

    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00Z") }
    private func noon(_ iso: String) -> Date { date("\(iso)T12:00:00Z") }

    /// Closed 5-day periods starting on each day (any order).
    private func periods(_ starts: String...) -> [PeriodRecord] {
        starts.map { PeriodRecord(startDate: day($0), endDate: calendar.date(byAdding: .day, value: 4, to: day($0))) }
    }

    private func history(_ periods: [PeriodRecord], logs: [CycleLogRecord] = [], now: String) -> CycleHistorySummary {
        CycleHistory.make(periods: periods, logs: logs, now: noon(now), calendar: calendar)
    }

    @Test func noPeriodsGivesAnEmptyHistory() {
        let result = history([], now: "2026-10-02")
        #expect(result.cycles.isEmpty)
        #expect(result.averageCycleLength == nil)
        #expect(result.cycleLengthRange == nil)
        #expect(result.averagePeriodLength == nil)
    }

    @Test func onePeriodIsTheCurrentCycleOnly() throws {
        let result = history(periods("2026-09-20"), now: "2026-10-02")
        let only = try #require(result.cycles.first)
        #expect(result.cycles.count == 1)
        #expect(only.isCurrent)
        #expect(only.length == nil)
        #expect(only.cycleDay == 13)
        #expect(only.countsTowardAverage == false)
        #expect(only.periodLength == 5)
        #expect(result.averageCycleLength == nil)
        #expect(result.cycleLengthRange == nil)
        #expect(result.averagePeriodLength == 5)
    }

    @Test func cyclesAreNewestFirstWithLengths() {
        let result = history(periods("2026-07-26", "2026-06-28", "2026-09-20", "2026-08-23"), now: "2026-10-02")
        #expect(result.cycles.map(\.start) == [day("2026-09-20"), day("2026-08-23"), day("2026-07-26"), day("2026-06-28")])
        #expect(result.cycles.map(\.length) == [nil, 28, 28, 28])
        #expect(result.cycles.map(\.isCurrent) == [true, false, false, false])
        #expect(result.cycles.map(\.cycleDay) == [13, nil, nil, nil])
        #expect(result.averageCycleLength == 28)
        #expect(result.cycleLengthRange == 28...28)
    }

    @Test func rangeAndAverageUseUsableCyclesOnly() {
        // 26, 18 (too short), 31, 50 (too long), then the current cycle.
        let result = history(periods("2026-04-01", "2026-04-27", "2026-05-15", "2026-06-15", "2026-08-04"), now: "2026-08-10")
        #expect(result.cycles.map(\.length) == [nil, 50, 31, 18, 26])
        #expect(result.cycles.map(\.countsTowardAverage) == [false, false, true, false, true])
        #expect(result.cycleLengthRange == 26...31)
        #expect(result.averageCycleLength == 29) // (26 + 31) / 2 = 28.5, rounded
    }

    @Test func averageMatchesTheForecast() throws {
        let input = periods("2026-03-01", "2026-03-27", "2026-04-27", "2026-05-24", "2026-06-23", "2026-07-20", "2026-08-19", "2026-09-17")
        let forecast = try #require(CyclePredictor.forecast(periods: input, logs: [], settings: CycleSettings(), now: noon("2026-10-02"), calendar: calendar))
        #expect(history(input, now: "2026-10-02").averageCycleLength == forecast.averageCycleLength)
    }

    @Test func onlyTheLastSixUsableCyclesAreAveraged() {
        // Seven 30-day cycles, then one 22-day cycle: the oldest 30 drops out.
        let starts = ["2026-01-01", "2026-01-31", "2026-03-02", "2026-04-01", "2026-05-01", "2026-05-31", "2026-06-30", "2026-07-30", "2026-08-21"]
        let result = CycleHistory.make(periods: starts.flatMap { periods($0) }, logs: [], now: noon("2026-09-01"), calendar: calendar)
        #expect(result.averageCycleLength == 29) // (5 × 30 + 22) / 6 = 28.67
        #expect(result.cycleLengthRange == 22...30)
    }

    @Test func openPeriodCountsUpToTodayCappedAtTenDays() {
        let open = [PeriodRecord(startDate: day("2026-09-28"))]
        #expect(history(open, now: "2026-10-02").cycles.first?.periodLength == 5)
        let long = [PeriodRecord(startDate: day("2026-09-10"))]
        #expect(history(long, now: "2026-10-02").cycles.first?.periodLength == 10)
    }

    @Test func averagePeriodLengthUsesClosedPeriodsOnly() {
        let closed = PeriodRecord(startDate: day("2026-08-23"), endDate: day("2026-08-28")) // 6 days
        let open = PeriodRecord(startDate: day("2026-09-20"))
        #expect(history([closed, open], now: "2026-10-02").averagePeriodLength == 6)
    }

    @Test func futurePeriodsAreIgnored() {
        let result = history(periods("2026-09-20", "2026-10-10"), now: "2026-10-02")
        #expect(result.cycles.count == 1)
        #expect(result.cycles.first?.isCurrent == true)
    }

    @Test func loggedDaysAreOffsetsWithinTheCycle() {
        let logs = [
            CycleLogRecord(day: day("2026-08-23"), flow: .heavy),          // offset 0 of the August cycle
            CycleLogRecord(day: day("2026-09-19"), moods: [.tired]),       // offset 27, last day of August's cycle
            CycleLogRecord(day: day("2026-09-20"), symptoms: [.cramps]),   // offset 0 of the current cycle
            CycleLogRecord(day: day("2026-10-02"), bbtCelsius: 36.4),      // offset 12
            CycleLogRecord(day: day("2026-10-05"), flow: .light),          // after today: ignored
        ]
        let result = history(periods("2026-08-23", "2026-09-20"), logs: logs, now: "2026-10-02")
        #expect(result.cycles.map(\.loggedDays) == [[0, 12], [0, 27]])
    }

    @Test func aBlankNoteIsNotContent() {
        #expect(CycleLogRecord(day: day("2026-10-01"), note: "  \n").hasContent == false)
        #expect(CycleLogRecord(day: day("2026-10-01")).hasContent == false)
        #expect(CycleLogRecord(day: day("2026-10-01"), note: "đau lưng").hasContent)
        #expect(CycleLogRecord(day: day("2026-10-01"), lh: .negative).hasContent)
        #expect(CycleLogRecord(day: day("2026-10-01"), mucus: .dry).hasContent)
        #expect(CycleLogRecord(day: day("2026-10-01"), flow: .noFlow).hasContent)
    }

    @Test func emptyLogsAreNotLoggedDays() {
        let logs = [CycleLogRecord(day: day("2026-09-22"), note: " ")]
        #expect(history(periods("2026-09-20"), logs: logs, now: "2026-10-02").cycles.first?.loggedDays == [])
    }
}
```

Before running, check that the helper names exist: `grep -rn "let utcCalendar\|func date(" Packages/KickCore/Tests/KickCoreTests | head`. If `date(_:)` takes a different label, adapt the two private helpers only. Also check `CycleLogRecord`'s init parameter order (`id, day, lh, bbtCelsius, mucus, note, flow, moods, symptoms`) in `CycleRecords.swift` and keep the labels in that order.

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `scripts/test-core.sh > build/test-core.log 2>&1; grep -E "error:|CycleHistory" build/test-core.log | head`
Expected: the build fails with "cannot find 'CycleHistory' in scope".

- [ ] **Step 3: Implement**

```swift
import Foundation

/// One cycle in the history (phase 10 spec §3): from the start of a period to
/// the day before the next one; the last cycle runs to today.
public struct PastCycle: Equatable, Sendable, Identifiable {
    public var id: UUID { periodID }
    /// The period that opens the cycle.
    public let periodID: UUID
    /// Start of the period's first day.
    public let start: Date
    /// Days to the next period's start; nil for the current cycle.
    public let length: Int?
    /// Days of bleeding (`CycleRules.dayRange`: an open period runs to today,
    /// at most `CycleRules.longPeriodDays`).
    public let periodLength: Int
    public let isCurrent: Bool
    /// Today's day of the cycle (1-based); current cycle only.
    public let cycleDay: Int?
    /// `length` is within `CyclePredictor.usableCycleLengths`; never the current cycle.
    public let countsTowardAverage: Bool
    /// 0-based day offsets with something logged (`CycleLogRecord.hasContent`), ascending.
    public let loggedDays: [Int]
}

/// The "Cycle history" page's data.
public struct CycleHistorySummary: Equatable, Sendable {
    /// `CyclePredictor`'s average: the last 6 usable lengths, rounded. nil without one.
    public let averageCycleLength: Int?
    /// Shortest...longest of those lengths; nil with fewer than two.
    public let cycleLengthRange: ClosedRange<Int>?
    /// Mean bleeding days of the closed periods among the last 6; nil without one.
    public let averagePeriodLength: Int?
    /// Newest first.
    public let cycles: [PastCycle]
}

public enum CycleHistory {
    static let periodsAveraged = 6

    public static func make(
        periods: [PeriodRecord],
        logs: [CycleLogRecord],
        now: Date,
        calendar: Calendar = .current
    ) -> CycleHistorySummary {
        let today = calendar.startOfDay(for: now)
        let sorted = periods
            .map { CycleRules.normalized($0, calendar: calendar) }
            .filter { $0.startDate <= today }
            .sorted { $0.startDate < $1.startDate }
        let logged = Set(
            logs.map { CycleRules.normalized($0, calendar: calendar) }
                .filter { $0.hasContent && $0.day <= today }
                .map(\.day)
        )
        func days(_ start: Date, _ end: Date) -> Int {
            calendar.dateComponents([.day], from: start, to: end).day ?? 0
        }

        var cycles: [PastCycle] = []
        for (index, period) in sorted.enumerated() {
            let next = sorted.indices.contains(index + 1) ? sorted[index + 1] : nil
            let length = next.map { days(period.startDate, $0.startDate) }
            let lastDay = next.flatMap { calendar.date(byAdding: .day, value: -1, to: $0.startDate) } ?? today
            let bleeding = CycleRules.dayRange(of: period, today: today, calendar: calendar)
            cycles.append(PastCycle(
                periodID: period.id,
                start: period.startDate,
                length: length,
                periodLength: days(bleeding.lowerBound, bleeding.upperBound) + 1,
                isCurrent: next == nil,
                cycleDay: next == nil ? days(period.startDate, today) + 1 : nil,
                countsTowardAverage: length.map(CyclePredictor.usableCycleLengths.contains) ?? false,
                loggedDays: logged
                    .filter { $0 >= period.startDate && $0 <= lastDay }
                    .map { days(period.startDate, $0) }
                    .sorted()
            ))
        }

        let usable = Array(cycles.filter(\.countsTowardAverage).compactMap(\.length).suffix(CyclePredictor.maxCyclesAveraged))
        let average = usable.isEmpty ? nil : Int((Double(usable.reduce(0, +)) / Double(usable.count)).rounded())
        let range = usable.count >= 2 ? (usable.min() ?? 0)...(usable.max() ?? 0) : nil
        let closedLengths = zip(sorted, cycles)
            .suffix(periodsAveraged)
            .filter { $0.0.endDate != nil }
            .map(\.1.periodLength)
        let averagePeriod = closedLengths.isEmpty
            ? nil
            : Int((Double(closedLengths.reduce(0, +)) / Double(closedLengths.count)).rounded())

        return CycleHistorySummary(
            averageCycleLength: average,
            cycleLengthRange: range,
            averagePeriodLength: averagePeriod,
            cycles: cycles.reversed()
        )
    }
}

extension CycleLogRecord {
    /// Something is logged: flow (even "none"), a mood, a symptom, mucus, LH,
    /// a temperature or a non-blank note.
    public var hasContent: Bool {
        flow != nil || !moods.isEmpty || !symptoms.isEmpty || mucus != nil || lh != nil
            || bbtCelsius != nil || !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
```

If `CyclePredictor.usableCycleLengths` or `maxCyclesAveraged` are `private`, change them to `static let` with internal access. Make no other change to `CyclePredictor`.

Note on `averagePeriodLengthUsesClosedPeriodsOnly`: the open period starting Sep 20 runs to Oct 2, so its bleeding is capped at 10 days. Only the closed 6-day period counts toward the average, which makes it 6.

- [ ] **Step 4: Run the tests and confirm they pass**

Run: `scripts/test-core.sh > build/test-core.log 2>&1; tail -5 build/test-core.log`
Expected: all 625 tests pass (613 + 12).

- [ ] **Step 5: Commit, push and wait for CI**

```bash
git add Packages/KickCore/Sources/KickCore/CycleHistory.swift Packages/KickCore/Tests/KickCoreTests/CycleHistoryTests.swift Packages/KickCore/Sources/KickCore/CyclePredictor.swift
git commit -F - <<'MSG'
feat(cycle-history): past cycles, average length and range in KickCore

CI-Only-Testing: CycleUITests
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push -u origin feat/cycle-history
scripts/ci-wait.sh
```

---

### Task 2: The history page, the detail page and the link

**Files:**
- Create: `App/Cycle/CycleHistoryView.swift`
- Modify: `App/Cycle/CycleCards.swift` (`ComingUpCard`, below the stats `HStack`)
- Modify: `App/Cycle/CycleTodayView.swift` (`.navigationDestination` on the `ScrollView` inside the `NavigationStack`)
- Modify: `Shared/L10n.swift`, `Shared/Localizable.xcstrings` (through the script)
- Create: `UITests/CycleHistoryUITests.swift`, `UITests/CycleHistoryScreenshotTests.swift`

**Interfaces:**
- **Consumes:**
  - from Task 1: `CycleHistory.make(periods:logs:now:calendar:)`, `PastCycle` and `CycleHistorySummary`;
  - `CycleCoordinator.periods`, `.logs`, `.policy` and `.log(on:)`;
  - `CycleDisplayPolicy.predictedBleedLabel` (`.withdrawalBleed` when hormonal);
  - `CycleTexts.logSummary(_:mode:)`;
  - `Formatting.shortDay`, `Formatting.spokenDay`, `L10n.days(_:)` and `AppClock.now()`;
  - `CycleDayLogSheet(day:existing:)` and `CycleDaySelection`;
  - from the UI test support: `XCUIApplication.launchPinned(language:dark:seedCycles:cycleGoal:contraception:largestText:)`, `UITestVariants.all/suffix`, `attachScreenshot`, `scrollUntilHittable` and `waitForLabel`.
- **Produces:** `enum CycleHistoryRoute: Hashable { case list; case cycle(UUID) }`. The keys are the identifiers listed in Global Constraints.

- [ ] **Step 1: Add the strings**

```bash
scripts/add-strings.py <<'JSON'
{
  "cycleHistory.link": ["See cycle history", "Xem lịch sử chu kỳ"],
  "cycleHistory.title": ["Cycle history", "Lịch sử chu kỳ"],
  "cycleHistory.averageCycle": ["Average cycle", "Chu kỳ trung bình"],
  "cycleHistory.averagePeriod": ["Average period", "Kỳ kinh trung bình"],
  "cycleHistory.averageBleed": ["Average bleed", "Ra máu trung bình"],
  "cycleHistory.range": ["%1$d–%2$d days", "%1$d–%2$d ngày"],
  "cycleHistory.needMore": ["Log more periods to see your cycle length.", "Ghi thêm kỳ kinh để xem độ dài chu kỳ."],
  "cycleHistory.empty": ["No periods logged yet.", "Chưa có kỳ kinh nào được ghi."],
  "cycleHistory.current": ["Current cycle · day %d", "Chu kỳ hiện tại · ngày %d"],
  "cycleHistory.currentTitle": ["Current cycle", "Chu kỳ hiện tại"],
  "cycleHistory.notCounted": ["Not counted in the average", "Không tính vào trung bình"],
  "cycleHistory.spoken.started": ["Started %@", "Bắt đầu %@"],
  "cycleHistory.spoken.period": ["period %@", "hành kinh %@"],
  "cycleHistory.spoken.bleed": ["bleeding %@", "ra máu %@"],
  "cycleHistory.spoken.loggedOne": ["1 day logged", "1 ngày có ghi"],
  "cycleHistory.spoken.logged": ["%d days logged", "%d ngày có ghi"],
  "cycleHistory.spoken.notCounted": ["not counted in the average", "không tính vào trung bình"],
  "cycleHistory.detailDay": ["Day %1$d · %2$@", "Ngày %1$d · %2$@"],
  "cycleHistory.detailEmpty": ["Nothing logged in this cycle.", "Chưa ghi gì trong chu kỳ này."]
}
JSON
```

In `Shared/L10n.swift`, add a `// MARK: - Phase 10: cycle history` block in the same style as its neighbours (`t(...)` and `String(format:)`):

```swift
    // MARK: - Phase 10: cycle history

    static var cycleHistoryLink: String { t("cycleHistory.link") }
    static var cycleHistoryTitle: String { t("cycleHistory.title") }
    static var cycleHistoryAverageCycle: String { t("cycleHistory.averageCycle") }
    static var cycleHistoryAveragePeriod: String { t("cycleHistory.averagePeriod") }
    static var cycleHistoryAverageBleed: String { t("cycleHistory.averageBleed") }
    static func cycleHistoryRange(_ low: Int, _ high: Int) -> String { String(format: t("cycleHistory.range"), low, high) }
    static var cycleHistoryNeedMore: String { t("cycleHistory.needMore") }
    static var cycleHistoryEmpty: String { t("cycleHistory.empty") }
    static func cycleHistoryCurrent(_ day: Int) -> String { String(format: t("cycleHistory.current"), day) }
    static var cycleHistoryCurrentTitle: String { t("cycleHistory.currentTitle") }
    static var cycleHistoryNotCounted: String { t("cycleHistory.notCounted") }
    static func cycleHistorySpokenStarted(_ date: String) -> String { String(format: t("cycleHistory.spoken.started"), date) }
    static func cycleHistorySpokenPeriod(_ days: String) -> String { String(format: t("cycleHistory.spoken.period"), days) }
    static func cycleHistorySpokenBleed(_ days: String) -> String { String(format: t("cycleHistory.spoken.bleed"), days) }
    static func cycleHistorySpokenLogged(_ count: Int) -> String {
        count == 1 ? t("cycleHistory.spoken.loggedOne") : String(format: t("cycleHistory.spoken.logged"), count)
    }
    static var cycleHistorySpokenNotCounted: String { t("cycleHistory.spoken.notCounted") }
    static func cycleHistoryDetailDay(_ day: Int, _ date: String) -> String { String(format: t("cycleHistory.detailDay"), day, date) }
    static var cycleHistoryDetailEmpty: String { t("cycleHistory.detailEmpty") }
```

- [ ] **Step 2: Write the UI tests (they fail until Step 3)**

`UITests/CycleHistoryUITests.swift`:

```swift
import XCTest

/// Phase 10: the cycle history page and a cycle's detail (pinned clock,
/// "fertile": three 28-day cycles, cycle day 13, logs on Sep 28 – Oct 2).
final class CycleHistoryUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openHistory(_ app: XCUIApplication) {
        let link = app.buttons["cycleHistoryLink"]
        app.scrollUntilHittable(link)
        link.tap()
        XCTAssertTrue(app.descendants(matching: .any)["cycleHistorySummary"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testHistoryShowsTheSummaryAndEveryCycle() {
        let app = XCUIApplication.launchPinned(seedCycles: "fertile")
        openHistory(app)
        XCTAssertTrue(app.staticTexts["cycleHistoryAverageCycle"].label.contains("28 days"))
        XCTAssertTrue(app.staticTexts["cycleHistoryAveragePeriod"].label.contains("5 days"))
        let rows = app.buttons.matching(identifier: "cycleHistoryRow")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(rows.firstMatch.label.contains("Current cycle"), rows.firstMatch.label)
        app.scrollUntilHittable(rows.element(boundBy: 3))
        XCTAssertEqual(rows.count, 4)
        XCTAssertTrue(rows.element(boundBy: 1).label.contains("28 days"), rows.element(boundBy: 1).label)
        XCTAssertTrue(rows.element(boundBy: 1).label.contains("period 5 days"), rows.element(boundBy: 1).label)
    }

    @MainActor
    func testCycleDetailListsLoggedDaysAndEditsOne() {
        let app = XCUIApplication.launchPinned(seedCycles: "fertile")
        openHistory(app)
        app.buttons.matching(identifier: "cycleHistoryRow").firstMatch.tap()
        let days = app.buttons.matching(identifier: "cycleDetailDay")
        XCTAssertTrue(days.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(days.count, 5)
        XCTAssertTrue(days.firstMatch.label.hasPrefix("Day 9"), days.firstMatch.label)
        let last = days.element(boundBy: 4)
        app.scrollUntilHittable(last)
        XCTAssertTrue(last.label.hasPrefix("Day 13"), last.label)
        last.tap()
        let note = app.textViews["dayLogNoteField"].exists ? app.textViews["dayLogNoteField"] : app.textFields["dayLogNoteField"]
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        app.scrollUntilHittable(note)
        note.tap()
        note.typeText("Mild back pain")
        app.buttons["dayLogSave"].tap()
        let edited = app.buttons.matching(NSPredicate(format: "identifier == 'cycleDetailDay' AND label CONTAINS %@", "Mild back pain")).firstMatch
        XCTAssertTrue(edited.waitForExistence(timeout: 5))
    }

    @MainActor
    func testAnOlderCycleWithoutLogsSaysSo() {
        let app = XCUIApplication.launchPinned(seedCycles: "fertile")
        openHistory(app)
        let rows = app.buttons.matching(identifier: "cycleHistoryRow")
        XCTAssertTrue(rows.element(boundBy: 1).waitForExistence(timeout: 5))
        rows.element(boundBy: 1).tap()
        XCTAssertTrue(app.staticTexts["cycleDetailEmpty"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testHormonalUsersReadBleedingNotPeriod() {
        let app = XCUIApplication.launchPinned(seedCycles: "fertile", cycleGoal: "tracking", contraception: "pill")
        openHistory(app)
        XCTAssertTrue(app.staticTexts["cycleHistoryAveragePeriod"].label.contains("Average bleed"))
        let row = app.buttons.matching(identifier: "cycleHistoryRow").element(boundBy: 1)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("bleeding 5 days"), row.label)
    }
}
```

Check how `dayLogNoteField` is declared in `CycleDayLogSheet.swift` (`TextField(axis: .vertical)` shows up as a text view or a text field) and keep only the matching query. Remove the ternary once you know which one it is.

`UITests/CycleHistoryScreenshotTests.swift`:

```swift
import XCTest

/// Phase 10 spec §5: the history and a cycle's detail in vi/en, light/dark and AX5.
final class CycleHistoryScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openHistory(_ app: XCUIApplication) {
        XCTAssertTrue(app.descendants(matching: .any)["cycleStatusCard"].waitForExistence(timeout: 10))
        let link = app.buttons["cycleHistoryLink"]
        app.scrollUntilHittable(link, maxSwipes: 12)
        link.tap()
        XCTAssertTrue(app.descendants(matching: .any)["cycleHistorySummary"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testHistoryScreens() {
        for (language, dark) in UITestVariants.all {
            let suffix = UITestVariants.suffix(language, dark)
            let app = XCUIApplication.launchPinned(language: language, dark: dark, seedCycles: "fertile")
            let link = app.buttons["cycleHistoryLink"]
            XCTAssertTrue(app.descendants(matching: .any)["cycleStatusCard"].waitForExistence(timeout: 10))
            app.scrollUntilHittable(link)
            attachScreenshot(app, "cycle-history-link-\(suffix)")
            openHistory(app)
            attachScreenshot(app, "cycle-history-\(suffix)")
            app.buttons.matching(identifier: "cycleHistoryRow").firstMatch.tap()
            XCTAssertTrue(app.buttons.matching(identifier: "cycleDetailDay").firstMatch.waitForExistence(timeout: 5))
            attachScreenshot(app, "cycle-detail-\(suffix)")
            app.terminate()
        }
    }

    @MainActor
    func testHistoryAtLargestText() {
        let app = XCUIApplication.launchPinned(language: "vi", seedCycles: "fertile", largestText: true)
        openHistory(app)
        attachScreenshot(app, "ax5-cycle-history-vi-light")
        let row = app.buttons.matching(identifier: "cycleHistoryRow").element(boundBy: 1)
        app.scrollUntilHittable(row, maxSwipes: 10)
        attachScreenshot(app, "ax5-cycle-history-rows-vi-light")
        row.tap()
        XCTAssertTrue(app.staticTexts["cycleDetailEmpty"].waitForExistence(timeout: 5))
        attachScreenshot(app, "ax5-cycle-detail-vi-light")
        app.terminate()
    }
}
```

Check that `attachScreenshot` and `UITestVariants` are the helpers `CycleGoalScreenshotTests` uses. They are; reuse them exactly.

- [ ] **Step 3: Build the pages**

`App/Cycle/CycleHistoryView.swift`:

```swift
import KickCore
import SwiftUI

/// Today → "Coming up" → history → one cycle (phase 10 spec §4).
enum CycleHistoryRoute: Hashable {
    case list
    case cycle(UUID)
}

/// What VoiceOver reads for a history row (spec §4.2).
enum CycleHistoryTexts {
    static func spokenRow(_ cycle: PastCycle, policy: CycleDisplayPolicy) -> String {
        var parts: [String] = []
        if cycle.isCurrent, let day = cycle.cycleDay {
            parts.append(L10n.cycleHistoryCurrent(day))
        } else {
            parts.append(L10n.cycleHistorySpokenStarted(Formatting.spokenDay(cycle.start)))
        }
        if let length = cycle.length { parts.append(L10n.days(length)) }
        let bleeding = L10n.days(cycle.periodLength)
        parts.append(policy.predictedBleedLabel == .withdrawalBleed
            ? L10n.cycleHistorySpokenBleed(bleeding)
            : L10n.cycleHistorySpokenPeriod(bleeding))
        parts.append(L10n.cycleHistorySpokenLogged(cycle.loggedDays.count))
        if !cycle.isCurrent, !cycle.countsTowardAverage { parts.append(L10n.cycleHistorySpokenNotCounted) }
        return parts.joined(separator: ", ")
    }
}

struct CycleHistoryView: View {
    @Environment(CycleCoordinator.self) private var cycle

    private var history: CycleHistorySummary {
        CycleHistory.make(periods: cycle.periods, logs: cycle.logs, now: AppClock.now())
    }

    var body: some View {
        let history = history
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if history.cycles.isEmpty {
                    Text(L10n.cycleHistoryEmpty)
                        .font(.luna(.body))
                        .foregroundStyle(.luna(.textSecondary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lunaCard()
                        .accessibilityIdentifier("cycleHistoryEmpty")
                } else {
                    summaryCard(history)
                    VStack(spacing: 0) {
                        ForEach(Array(history.cycles.enumerated()), id: \.element.id) { index, item in
                            if index > 0 { LunaDivider() }
                            NavigationLink(value: CycleHistoryRoute.cycle(item.periodID)) {
                                CycleHistoryRowView(cycle: item)
                            }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(CycleHistoryTexts.spokenRow(item, policy: cycle.policy))
                            .accessibilityAddTraits(.isButton)
                            .accessibilityIdentifier("cycleHistoryRow")
                        }
                    }
                    .lunaCard()
                }
            }
            .padding(20)
        }
        .background(.luna(.background))
        .navigationTitle(L10n.cycleHistoryTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private func summaryCard(_ history: CycleHistorySummary) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if let average = history.averageCycleLength {
                    Text(L10n.days(average))
                        .font(.luna(.cardTitle))
                        .foregroundStyle(.luna(.textPrimary))
                    if let range = history.cycleLengthRange, range.lowerBound < range.upperBound {
                        Text(L10n.cycleHistoryRange(range.lowerBound, range.upperBound))
                            .font(.luna(.label))
                            .foregroundStyle(.luna(.textSecondary))
                    }
                    Text(L10n.cycleHistoryAverageCycle)
                        .font(.luna(.label))
                        .foregroundStyle(.luna(.textSecondary))
                } else {
                    Text(L10n.cycleHistoryNeedMore)
                        .font(.luna(.body))
                        .foregroundStyle(.luna(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("cycleHistoryNeedMore")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("cycleHistoryAverageCycle")
            if let period = history.averagePeriodLength {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.days(period))
                        .font(.luna(.cardTitle))
                        .foregroundStyle(.luna(.textPrimary))
                    Text(cycle.policy.predictedBleedLabel == .withdrawalBleed ? L10n.cycleHistoryAverageBleed : L10n.cycleHistoryAveragePeriod)
                        .font(.luna(.label))
                        .foregroundStyle(.luna(.textSecondary))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("cycleHistoryAveragePeriod")
            }
        }
        .lunaCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cycleHistorySummary")
    }
}

/// Title, length, the bar and the "not counted" note (spec §4.2).
struct CycleHistoryRowView: View {
    let cycle: PastCycle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(cycle.isCurrent ? L10n.cycleHistoryCurrent(cycle.cycleDay ?? 1) : Formatting.shortDay(cycle.start))
                    .font(.luna(.bodyEmphasis))
                    .foregroundStyle(.luna(.textPrimary))
                Spacer(minLength: 8)
                if let length = cycle.length {
                    Text(L10n.days(length))
                        .font(.luna(.body))
                        .foregroundStyle(.luna(.textSecondary))
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.luna(.textSecondary))
            }
            CycleHistoryBar(cycle: cycle)
            if !cycle.isCurrent, !cycle.countsTowardAverage {
                Text(L10n.cycleHistoryNotCounted)
                    .font(.luna(.label))
                    .foregroundStyle(.luna(.textSecondary))
            }
        }
        .padding(.vertical, 12)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

/// The track is as wide as 45 days; bleeding is a rose segment, logged days are dots.
struct CycleHistoryBar: View {
    let cycle: PastCycle
    private static let fullDays = 45

    var body: some View {
        GeometryReader { proxy in
            let dayWidth = proxy.size.width / CGFloat(Self.fullDays)
            let days = min(cycle.length ?? cycle.cycleDay ?? 1, Self.fullDays)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.luna(.cycleSoft))
                    .overlay {
                        if cycle.isCurrent {
                            Capsule().strokeBorder(.luna(.cycle), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        }
                    }
                    .frame(width: dayWidth * CGFloat(days))
                Capsule()
                    .fill(.luna(.cycle))
                    .frame(width: dayWidth * CGFloat(min(cycle.periodLength, days)))
                ForEach(cycle.loggedDays.filter { $0 < days }, id: \.self) { offset in
                    Circle()
                        .fill(.luna(.cycleStrong))
                        .frame(width: 4, height: 4)
                        .offset(x: dayWidth * (CGFloat(offset) + 0.5) - 2)
                }
            }
        }
        .frame(height: 10)
        .accessibilityHidden(true)
    }
}

/// One cycle's logged days, oldest first; tapping a day opens the day log (spec §4.3).
struct CycleDetailView: View {
    let periodID: UUID
    @Environment(CycleCoordinator.self) private var cycle
    @State private var logDay: CycleDaySelection?

    private var past: PastCycle? {
        CycleHistory.make(periods: cycle.periods, logs: cycle.logs, now: AppClock.now())
            .cycles.first { $0.periodID == periodID }
    }

    var body: some View {
        let past = past
        ScrollView {
            VStack(spacing: 0) {
                if let past, !past.loggedDays.isEmpty {
                    ForEach(Array(past.loggedDays.enumerated()), id: \.element) { index, offset in
                        if index > 0 { LunaDivider() }
                        dayRow(past, offset: offset)
                    }
                } else {
                    Text(L10n.cycleHistoryDetailEmpty)
                        .font(.luna(.body))
                        .foregroundStyle(.luna(.textSecondary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("cycleDetailEmpty")
                }
            }
            .lunaCard()
            .padding(20)
        }
        .background(.luna(.background))
        .navigationTitle(past.map(title) ?? L10n.cycleHistoryTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .sheet(item: $logDay) { selection in
            CycleDayLogSheet(day: selection.date, existing: cycle.log(on: selection.date))
        }
    }

    private func title(_ past: PastCycle) -> String {
        guard let length = past.length,
              let last = Calendar.current.date(byAdding: .day, value: length - 1, to: past.start)
        else { return L10n.cycleHistoryCurrentTitle }
        return Formatting.shortDay(past.start) + " – " + Formatting.shortDay(last)
    }

    private func dayRow(_ past: PastCycle, offset: Int) -> some View {
        let date = Calendar.current.date(byAdding: .day, value: offset, to: past.start) ?? past.start
        let log = cycle.log(on: date)
        let summary = CycleTexts.logSummary(log) ?? ""
        let note = log?.note.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let heading = L10n.cycleHistoryDetailDay(offset + 1, Formatting.shortDay(date))
        let spokenHeading = L10n.cycleHistoryDetailDay(offset + 1, Formatting.spokenDay(date))
        return Button {
            logDay = CycleDaySelection(date: date)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(heading)
                        .font(.luna(.bodyEmphasis))
                        .foregroundStyle(.luna(.textPrimary))
                    if !summary.isEmpty {
                        Text(summary)
                            .font(.luna(.body))
                            .foregroundStyle(.luna(.textPrimary))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !note.isEmpty {
                        Text(verbatim: note)
                            .font(.luna(.label))
                            .foregroundStyle(.luna(.textSecondary))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.luna(.textSecondary))
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([spokenHeading, summary, note].filter { !$0.isEmpty }.joined(separator: ", "))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("cycleDetailDay")
    }
}
```

Font names: check `App/DesignSystem/LunaFont.swift` for the real style names (`.cardTitle`, `.body`, `.bodyEmphasis`, `.label`) and substitute the closest existing ones if any differ. Check `Color.luna` tokens in the same way (`cycle`, `cycleSoft`, `cycleStrong`, `textPrimary`, `textSecondary`, `background`). Use only existing tokens.

In `ComingUpCard` (`App/Cycle/CycleCards.swift`), after the stats `HStack(...)…accessibilityElement(children: .combine)`, add:

```swift
            LunaDivider()
            NavigationLink(value: CycleHistoryRoute.list) {
                HStack {
                    Text(L10n.cycleHistoryLink)
                        .font(.luna(.bodyEmphasis))
                        .foregroundStyle(.luna(.cycleOnSoft))
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.luna(.cycleOnSoft))
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("cycleHistoryLink")
```

Update the doc comment above `ComingUpCard` with "Phase 10: a link to the cycle history."

In `CycleTodayView`, on the `ScrollView` inside `NavigationStack`, next to the existing modifiers (`.background`, `.toolbar(.hidden…)`), add:

```swift
            .navigationDestination(for: CycleHistoryRoute.self) { route in
                switch route {
                case .list: CycleHistoryView()
                case .cycle(let id): CycleDetailView(periodID: id)
                }
            }
```

Then check:
- `grep -rn "ComingUpCard(" App` to confirm every call site sits inside a `NavigationStack`. If one does not (for example a preview), the link stays harmless.
- `grep -rn "Text(\"" App/Cycle/CycleHistoryView.swift` must print nothing.

- [ ] **Step 4: Verify locally**

Run the local verification commands. The KickCore count stays at 625 and `build-for-testing` exits 0.

- [ ] **Step 5: Commit, push, wait for CI and check the screenshots**

```bash
git add App/Cycle/CycleHistoryView.swift App/Cycle/CycleCards.swift App/Cycle/CycleTodayView.swift Shared/L10n.swift Shared/Localizable.xcstrings UITests/CycleHistoryUITests.swift UITests/CycleHistoryScreenshotTests.swift KickCounter.xcodeproj
git commit -F - <<'MSG'
feat(cycle-history): history page, cycle detail and the link from Today

CI-Only-Testing: CycleHistoryUITests CycleHistoryScreenshotTests CycleTodayUITests CycleGoalUITests
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```

(If `KickCounter.xcodeproj` is gitignored, leave it out of `git add`.)

**Visual check.** Read each PNG and confirm each item:
- `cycle-history-link-*`: the link row is inside "Sắp tới" / "Coming up", below the three stats. Its chevron is aligned and nothing is clipped.
- `cycle-history-*` (vi/en, light/dark): back button and title; summary "28 ngày"/"28 days" with no range line and "5 ngày"/"5 days". There are four rows. The first reads "Chu kỳ hiện tại · ngày 13" with a dashed bar about 13/45 wide. The older bars are about 28/45 wide with a rose start segment. The colours are readable in dark mode.
- `cycle-detail-*`: five days, from "Ngày 9 · 28 thg 9" to "Ngày 13 · 2 thg 10". Each has a summary line and the summary text wraps instead of truncating.
- `ax5-cycle-history-vi-light` and `ax5-cycle-history-rows-vi-light`: every text is complete with nothing truncated, and the rows stay tappable.
- `ax5-cycle-detail-vi-light`: shows the empty message in full.

---

### Task 3: Docs and full CI

**Files:**
- Modify: `docs/content-review-for-doctor.md` (new §12)
- Modify: `docs/release-checklist.md`
- Modify: `README.md`

- [ ] **Step 1: Doctor review §12.** Append it after §11 in the same table style:

```markdown
## 12. Lịch sử chu kỳ (giai đoạn 10)

| # | Chuỗi (vi) | Câu hỏi cho bác sĩ |
|---|---|---|
| 59 | "Không tính vào trung bình" (chu kỳ ngắn hơn 21 hoặc dài hơn 45 ngày) | Khoảng 21–45 ngày có phù hợp để loại khỏi trung bình không? Có nên gợi ý đi khám khi gặp chu kỳ như vậy không, hay giữ trung lập như hiện tại? |
| 60 | "Chu kỳ trung bình" / "26–31 ngày" | Hiển thị khoảng dao động (ngắn nhất – dài nhất) có dễ hiểu và không gây lo lắng không? |
| 61 | "Kỳ kinh trung bình" / "Ra máu trung bình" (khi dùng biện pháp tránh thai nội tiết) | Cách gọi "ra máu" thay cho "kỳ kinh" với người dùng thuốc/que cấy/vòng nội tiết có đúng không? |
```

  Check the numbering: `grep -n "^| 5[0-9] " docs/content-review-for-doctor.md | tail -1` should show 58 as the last item. If not, continue from the real last number.

- [ ] **Step 2: Release checklist.** Add a "Giai đoạn 10" block in the existing style:
  - no CloudKit schema change;
  - check "Xem lịch sử chu kỳ" on a device with real data;
  - check that the average equals the one on Today.
- [ ] **Step 3: README.** Add one line under the cycle-mode features: "Lịch sử chu kỳ: độ dài trung bình, khoảng dao động, từng chu kỳ và những ngày đã ghi."
- [ ] **Step 4: Commit with no `CI-Only-Testing:` line (full suite), push and wait**

```bash
git add docs/content-review-for-doctor.md docs/release-checklist.md README.md
git commit -F - <<'MSG'
docs: cycle history for the doctor, release checklist and README

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```

Expected: the full CI run is green (about 50–70 minutes).

## Self-review

- **Spec coverage:**
  - §3 data → Task 1;
  - §4.1 entry, §4.2 history and §4.3 detail → Task 2;
  - §5 tests → Tasks 1 and 2;
  - §6 docs → Task 3.
- **Deviations, recorded in Spec clarifications:** the detail shows one summary line per day instead of field-by-field lines, and the range line is hidden when min equals max.
- **Types:** `PastCycle.periodID`, `CycleHistoryRoute.cycle(UUID)` and `CycleHistorySummary` field names are used consistently in Tasks 1 and 2.
