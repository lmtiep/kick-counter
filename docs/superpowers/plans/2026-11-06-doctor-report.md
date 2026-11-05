# Report for the doctor (PDF) Implementation Plan

> Spec `docs/superpowers/specs/2026-11-06-doctor-report-design.md` is binding.

**Global constraints:** branch `feat/doctor-report`; strings only via `scripts/add-strings.py` (vi + en); Luna tokens / `Font.luna` only in the screen; KickCore pure (no SwiftUI/UIKit/SwiftData); the report has numbers and tables only, no interpretation, advice or alert wording; never run UI tests locally (commit trailer `CI-Only-Testing: DoctorReportUITests, DoctorReportScreenshotTests`); before push run `scripts/test-core.sh` and `xcodegen generate` + `xcodebuild build-for-testing` (iPhone 18 Pro); then `scripts/ci-wait.sh`, read the screenshots and the PDF's page 1 with `sips -Z 900`.

## Task 1: `DoctorReport.make` in KickCore (pure, TDD)
- File: `Packages/KickCore/Sources/KickCore/DoctorReport.swift`; tests `Packages/KickCore/Tests/KickCoreTests/DoctorReportTests.swift`.
- API:
  - `enum ReportRange { case weeks(Int), wholePregnancy, cycles(Int) }` (weeks: the last 7n days, today included; whole pregnancy: from the first day of the last period = due date − 280 days, or the earliest record without a due date; cycles: from the start of the n-th latest period, the current one counts).
  - `enum ReportSectionKind { kicks, contractions, weights, symptoms, appointments, periods, cycleLengths, moodsAndSymptoms, bbtAndLH }` with `static func kinds(for: AppMode) -> [ReportSectionKind]`.
  - `struct DoctorReportInput { sessions, contractions, weights, logs, appointments, periods, dueDate }`.
  - `DoctorReport.make(mode:range:include:input:name:now:calendar:) -> DoctorReport` with `header: Header`, `sections: [Section]` (typed rows; empty or unselected sections omitted), `isEmpty`.
- Tests (red first, one commit with the implementation):
  `weeksRangeIncludesItsFirstDayAndNotTheDayBefore`, `rangeEndsWithTodayAndLeavesTomorrowOut`, `fourWeeksCoverTwentyEightDays`, `wholePregnancyStartsOnTheFirstDayOfTheLastPeriod`, `wholePregnancyWithoutADueDateStartsAtTheEarliestRecord`, `cyclesRangeStartsAtTheNthLatestPeriod`, `cyclesRangeWithFewerPeriodsStartsAtTheFirst`, `kicksListCompletedSessionsOnly`, `contractionsAreSummarisedPerEpisode`, `weightsAreListedOldestFirst`, `symptomsKeepPregnancySymptomsOnly`, `appointmentsKeepTheirNotes`, `emptyAndUnselectedSectionsAreOmitted`, `pregnancyHeaderHasWeekAndDueDate`, `cycleHeaderHasAverages`, `theNameIsTrimmedAndBlankMeansNone`, `periodsAndCycleLengths`, `moodsAndSymptomsOfCycleMode`, `bbtAndLH`, `partnerModeHasNoSections`.
- Mutation check: change the lower bound `>=` of the range filter to `>`; expect the edge tests red; revert.

## Task 2: Strings and texts
- `scripts/add-strings.py` keys `report.*` (vi + en); `L10n.t` becomes internal; accessors in `App/Report/ReportTexts.swift` (own file, to avoid conflicts in `Shared/L10n.swift`).

## Task 3: PDF renderer (app)
- `App/Report/DoctorReportPDF.swift`: `DoctorReportPDF.render(_ report: DoctorReport) -> Data` with `UIGraphicsPDFRenderer`, A4 (595.2 x 841.8), light colours, Be Vietnam Pro, paginated tables, footer on every page, `fileName(now:)` (`LunaMom-BaoCao-` / `LunaMom-Report-`), `write(...)` to a temp folder.
- Not covered by KickCore tests; covered by the UI render test.

## Task 4: Screen and entry
- `App/Report/DoctorReportView.swift`: range segmented choices (by mode), section toggles, optional name field (state only), export button disabled with a hint when nothing would be in the report; share sheet via the existing `BackupSharePresenter` pattern (temp folder removed on completion); DEBUG launch flag `-uiTestingReportPath <file>` writes the PDF there instead of the share sheet.
- `ProfileView`: one `NavigationLink` row (`profileDoctorReport`) for both modes.

## Task 5: UI tests (CI only)
- `UITests/DoctorReportUITests.swift`: opens, toggles, export shows the share sheet, PDF at the known path has 1+ pages (the app writes the page count into a label `reportPageCount`).
- `UITests/DoctorReportScreenshotTests.swift`: the screen vi light/dark/AX5; the render test attaches page 1 as a PNG.
