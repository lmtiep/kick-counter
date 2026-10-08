# Cycle history (Phase 10)

Date: 2026-10-08 · Status: approved in conversation · Branch: `feat/cycle-history`

## 1. Goal

The cycle mode gets a "Lịch sử chu kỳ" page that answers three questions:
- How long are my cycles and periods on average, and how much do they vary?
- What did each past cycle look like?
- What did I log during it?

The page reads only the data that already exists, `PeriodEntry` and `CycleLog`. It adds no stored data and needs no CloudKit schema change.

## 2. Decisions made with the user

| Topic | Decision |
|---|---|
| Scope | A history page only. No new log fields, no pill reminder, no symptom-by-phase patterns (all left for later) |
| Content | A summary at the top, a list of cycles, and a detail page for each cycle |
| Entry | A "Xem lịch sử chu kỳ ›" row in Today's "Sắp tới" card, below the three stats. It appears for both goals (tracking and conceiving). Partner and pregnancy modes do not have it |
| Wording | A cycle outside 21–45 days is labelled "Không tính vào trung bình". The words "bất thường" and "abnormal" are never used |

## 3. KickCore: `CycleHistory` (pure)

```swift
public struct PastCycle: Equatable, Sendable, Identifiable {
    public var id: UUID { periodID }
    public let periodID: UUID
    public let start: Date            // start of the period that opens the cycle
    public let length: Int?           // days to the next period start; nil for the current cycle
    public let periodLength: Int      // days of bleeding (CycleRules.dayRange, capped at longPeriodDays)
    public let isCurrent: Bool
    public let cycleDay: Int?         // today's day number, current cycle only
    public let countsTowardAverage: Bool  // length in CyclePredictor.usableCycleLengths (false for the current cycle)
    public let loggedDays: [Int]      // 0-based day offsets with a CycleLog that has any content, ascending
}

public struct CycleHistorySummary: Equatable, Sendable {
    public let averageCycleLength: Int?   // nil with fewer than one usable cycle
    public let cycleLengthRange: ClosedRange<Int>?  // min...max of the usable cycles; nil with fewer than two
    public let averagePeriodLength: Int?  // mean periodLength of closed periods (endDate != nil) among the last 6; nil if none
    public let cycles: [PastCycle]        // newest first
}

public enum CycleHistory {
    public static func make(periods: [PeriodRecord], logs: [CycleLogRecord], now: Date, calendar: Calendar = .current) -> CycleHistorySummary
}
```

Rules:
- **Inputs.** Periods are normalised with `CycleRules.normalized`, periods starting after today are dropped, and the rest are sorted by start. Each period opens one cycle, which ends the day before the next period starts. The last cycle is the current one.
- **Average cycle length.** It uses the same rule as `CyclePredictor`: the last `maxCyclesAveraged` (6) cycle lengths that fall within `usableCycleLengths` (21…45), with the mean rounded. With the same input, Today's average and the history average are always equal. `CyclePredictor` exposes these constants as `internal`, and `CycleHistory` lives in the same module, so it reuses them directly.
- **Period length.** For each period it is the day count of `CycleRules.dayRange(of:today:calendar:)`, which already caps at 10 days and treats an open period as running up to today.
- **Logged days.** A day counts if its `CycleLog` has any of: flow, a mood, a symptom, mucus, LH, BBT, or a non-blank note. Only days within the cycle's own span are counted; for the current cycle that span runs up to today.
- **Empty input.** No periods gives an empty `cycles` list and all three summary values nil.

## 4. Screens

### 4.1 Entry

`ComingUpCard` gains a row below its stats: "Xem lịch sử chu kỳ" with a chevron, at least 44 pt tall, identifier `cycleHistoryLink`. It pushes `CycleHistoryView` onto the Today `NavigationStack`.

### 4.2 `CycleHistoryView`

The navigation title is "Lịch sử chu kỳ". The page has these parts:

- **Summary card** (`cycleHistorySummary`). Two stats:
  - "Chu kỳ trung bình": **29 ngày**, with "26–31 ngày" below it when a range exists.
  - "Kỳ kinh trung bình": **5 ngày**.

  The period stat's label follows `CycleDisplayPolicy.predictedBleedLabel`: hormonal users see "Ra máu trung bình". Without an average, the card shows "Ghi thêm kỳ kinh để xem độ dài chu kỳ."
- **List of cycles** (`cycleHistoryRow`), newest first. Each row shows:
  - **Title.** "Chu kỳ hiện tại · ngày 12" for the current cycle; otherwise the start date, e.g. "3 thg 9".
  - **Trailing value.** "29 ngày", or nothing for the current cycle.
  - **Bar.** Its width is proportional to the length, with 45 days filling the row (longer cycles are capped). The current cycle uses its cycle day and is drawn dashed. The bleeding days are a rose segment at the start. Logged days are small dots on the bar.
  - **Note.** "Không tính vào trung bình" in secondary text when `countsTowardAverage` is false and the cycle is not the current one.
  - **Accessibility.** The bar is decorative. The row reads as one sentence, for example "Bắt đầu 3 tháng 9, 29 ngày, hành kinh 5 ngày, 4 ngày có ghi". When the cycle doesn't count, ", không tính vào trung bình" is added. Hormonal users hear "ra máu" instead of "hành kinh".
- **Empty state.** With no periods logged, the page says "Chưa có kỳ kinh nào được ghi."

### 4.3 `CycleDetailView`

Tapping a row pushes this page.

- **Title.** The date range, e.g. "3 thg 9 – 1 thg 10", or "Chu kỳ hiện tại".
- **Content.** Every logged day in the cycle, oldest first (`cycleDetailDay`). Each one shows the date with its cycle day ("Ngày 2 · 4 thg 9"), then one line each for:
  - flow;
  - moods;
  - symptoms;
  - mucus;
  - LH;
  - BBT;
  - the note.

  The same localized names as the day-log sheet are used, and empty fields are skipped.
- **Editing.** Tapping a day opens the existing `CycleDayLogSheet` for that date. When the sheet closes, the page reloads.
- **Empty state.** With no logged days, the page says "Chưa ghi gì trong chu kỳ này."
- **Policy.** For tracking, LH and BBT lines appear only if the policy shows them or a value exists. Any value the user has logged is always shown.

### 4.4 Out of scope

These are not part of this phase:
- editing or deleting periods from the history (the calendar already does this);
- charts;
- export;
- symptom patterns;
- new log fields.

## 5. Testing

- **KickCore (`CycleHistoryTests`):**
  - no periods;
  - one period (current only);
  - three cycles, checking lengths, the current cycle's day and the logged-day offsets;
  - an 18-day and a 50-day cycle (`countsTowardAverage` false, excluded from the average and the range);
  - the average equals `CyclePredictor.forecast(...).averageCycleLength` on the same input;
  - an open period counted up to today, capped at 10 days;
  - a future period ignored;
  - an empty log (only a blank note) not counted.
- **UI tests (`CycleHistoryUITests`):**
  - open the page from Today with the `fertile` seed and check the summary and the row count;
  - open a cycle and check its logged day;
  - edit that day and see the change;
  - empty state.
- **Screenshots:** the history page and the detail page in vi/en, light/dark and AX5.
- Scoped CI per task. The final task runs the full suite.

## 6. Delivery (branch `feat/cycle-history`)

1. **KickCore:** `CycleHistory`, `PastCycle` and `CycleHistorySummary`, with tests.
2. **Screens:**
   - the history page and the detail page;
   - the entry row in `ComingUpCard`;
   - strings (vi/en) and accessibility;
   - UI tests and screenshots.
3. **Docs:**
   - doctor review §12: the "Không tính vào trung bình" wording and the 21–45 range;
   - README;
   - the release checklist (no CloudKit change).

   This task runs the full CI suite.
