# Luna Mom 1.2 — Cycle logging, insights, app lock Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship 1.2: richer cycle day logs (spotting, sex, sex drive, pregnancy test, more moods/symptoms), on-device insights (length chart, regularity, symptom patterns, Today line), and a Face ID app lock.

**Architecture:** All rules live in KickCore as pure, tested types (`CycleLogRecord` fields, `CycleInsights`, `AppLockPolicy`). KickData gains four optional `CycleLog` attributes (lightweight migration, verified against a 1.1 fixture store) and the backup DTO gains optional keys. The app adds sections to `CycleDayLogSheet`, an insights block on `CycleHistoryView`, one line on `CycleTodayView`, and a lock overlay at the `WindowGroup` root.

**Tech Stack:** Swift 6, SwiftUI iOS 17, SwiftData, Swift Charts, LocalAuthentication, Swift Testing, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-11-09-cycle-logging-insights-lock-design.md`

## Global Constraints

- Strings only via `scripts/add-strings.py` (`{"key":["en","vi"]}`); accessors in `Shared/L10n.swift`. Info.plist strings in `Shared/InfoPlist.xcstrings`.
- New `CycleLog` attributes optional or defaulted; unversioned schema (lightweight migration).
- Backup: new keys optional (`decodeIfPresent`), encoded only when set; unknown raw values round-trip.
- Spotting never counts as a period day and never changes `CyclePredictor` output.
- Insight copy is observation only ("bạn hay…"); footnote "Đây là quan sát từ ghi chép của bạn, không phải chẩn đoán." / "These are observations from your logs, not a diagnosis."
- The lock never locks her out: `.deviceOwnerAuthentication` (passcode fallback); unusable policy → open, toggle off.
- `-uiTesting` never locks; UI tests run on CI only.
- `MARKETING_VERSION: "1.2.0"` in `project.yml`.
- Tests: `scripts/test-core.sh` (KickCore), `(cd Packages/KickData && swift test)`, app build:
  `xcodegen generate && xcodebuild -project KickCounter.xcodeproj -scheme KickCounter -destination 'generic/platform=iOS Simulator' -derivedDataPath <scratchpad>/dd build-for-testing CODE_SIGNING_ALLOWED=NO`.
- Commit trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. A 1.1 store opens in 1.2 with every cycle log intact and the new fields at their defaults — Task 2 fixture test.
2. A 1.1 backup (no new keys) restores into 1.2, and a 1.2 backup with a raw value this build does not know keeps it on re-export — Task 2.
3. A day with only spotting (or only sex) is saved, not deleted as empty, and shows in history `loggedDays` — Task 1.
4. A long gap (pregnancy, > 45 days) never yields a pattern or a regularity verdict — Task 3.
5. The Face ID prompt itself (scene → inactive) never re-locks; ≥60 s in background does — Task 5 policy test.

---

### Task 1: KickCore — new log kinds on `CycleLogRecord`

**Files:**
- Modify: `Packages/KickCore/Sources/KickCore/SymptomKinds.swift`, `CycleRecords.swift`, `CycleLogSummary.swift`, `CycleHistory.swift` (`hasContent`)
- Test: `Packages/KickCore/Tests/KickCoreTests/SymptomKindsTests.swift`, `CycleLogSummaryTests.swift`, `CycleHistoryTests.swift`, new `CycleLogRecordTests.swift`

**Interfaces — Produces:**
- `enum SexLog: String { case unprotected, protected }`, `enum SexDrive: String { case low, normal, high }`, `enum PregnancyTestResult: String { case negative, positive }` (all `Sendable, CaseIterable`) in `CycleRecords.swift`.
- `Mood` appends `irritable, sad, energetic` (after existing cases; raw values = names).
- `Symptom` appends `diarrhea, constipation, dizziness`. `var mode: AppMode` is replaced by `var modes: Set<AppMode>`; `static func cases(for: AppMode) -> [Symptom]` returns an explicit order:
  - `.tryingToConceive`: cramps, headache, tenderBreasts, acne, bloating, cravings, backPain, insomnia, nausea, diarrhea, constipation, dizziness
  - `.pregnant`: unchanged list (nausea, heartburn, swollenFeet, backPain, legCramps, insomnia, contractions).
- `CycleLogRecord` gains `spotting: Bool = false`, `sex: SexLog?`, `sexDrive: SexDrive?`, `pregnancyTest: PregnancyTestResult?` (init params defaulted; `withID` copies them). Unknown raw values of these three are kept at the model/DTO layer, as `lh`/`mucus` are (Task 2), not in the record.
- `CycleLogSummaryItem` gains `.spotting`, `.sex(SexLog)`, `.sexDrive(SexDrive)`, `.pregnancyTest(PregnancyTestResult)`; order: flow · spotting · moods · symptoms · temperature · LH · mucus · pregnancyTest · sex · sexDrive · note.

- [ ] **Step 1: Write failing tests**
  - `SymptomKindsTests.cycleListOrder`: `Symptom.cases(for: .tryingToConceive)` equals the 12-item list above; `cases(for: .pregnant)` unchanged.
  - `SymptomKindsTests.sharedSymptomsInBothModes`: `.backPain`, `.insomnia`, `.nausea` have `modes == [.tryingToConceive, .pregnant]`.
  - `CycleLogRecordTests.deselectingSharedSymptomInCycleModeRemovesIt`: record with `[.nausea, .heartburn]`, `setSymptoms([], for: .tryingToConceive)` → `[.heartburn]`.
  - `CycleLogRecordTests.spottingAloneIsNotEmpty` / `sexAloneIsNotEmpty` / `pregnancyTestAloneIsNotEmpty` / `sexDriveAloneIsNotEmpty`: `isEmpty == false`, `hasContent == true`.
  - `CycleLogRecordTests.withIDKeepsNewFields`.
  - `CycleLogSummaryTests.newItemsInOrder`: a record with flow .light, spotting, mood .sad, test .positive, sex .protected, sexDrive .high → items `[.flow(.light), .spotting, .mood(.sad), .pregnancyTest(.positive), .sex(.protected), .sexDrive(.high)]`.
- [ ] **Step 2:** `scripts/test-core.sh --filter "SymptomKinds|CycleLogRecord|CycleLogSummary|CycleHistory"` → FAIL (compile errors).
- [ ] **Step 3:** Implement. `symptoms(for:)` / `setSymptoms` use `modes.contains(mode)`. Fix every `Symptom.mode` call site (App/Symptoms/SymptomChips.swift, pregnancy timeline) to `modes`/`cases(for:)`.
- [ ] **Step 4:** Same command → PASS; then full `scripts/test-core.sh` → PASS.
- [ ] **Step 5:** Commit `feat(cycle): spotting, sex, sex drive, pregnancy test and more moods and symptoms in KickCore`.

### Task 2: KickData + backup — store the new fields (schema change)

**Files:**
- Modify: `Packages/KickData/Sources/KickData/Models.swift` (`CycleLog`), `Packages/KickCore/Sources/KickCore/Backup.swift` (`CycleLogDTO`), `Packages/KickData/Sources/KickData/BackupStore.swift` (if it maps raw values), `Packages/KickData/Package.swift` (test resources)
- Create: `Packages/KickData/Tests/KickDataTests/Fixtures/store-1.1.sqlite` (+ `-shm`/`-wal` if produced; prefer a checkpointed single file)
- Test: `SchemaUpgradeTests.swift`, `CycleStoreTests.swift`, KickCore `BackupTests.swift`

**Interfaces — Consumes:** Task 1 enums/fields. **Produces:** `CycleLog.spotting: Bool = false`, `sexRaw`, `sexDriveRaw`, `pregnancyTestRaw: String?`; `CycleLogDTO.spotting: Bool?` (encoded only when true), `sex`, `sexDrive`, `pregnancyTest: String?`; `CycleLogDTO.init(_ record:, lhRaw:, mucusRaw:, flowRaw:, sexRaw:, sexDriveRaw:, pregnancyTestRaw:)` (new params defaulted nil).

- [ ] **Step 0: Make the 1.1 fixture before touching the model.** On the current model, write a throwaway test (not committed) that creates a store at a temp URL with one `PeriodEntry` and one `CycleLog` (day 2026-10-05, flow light, moods "tired", symptoms "cramps", note "x"), checkpoints (close the container), and copies the sqlite to `Fixtures/store-1.1.sqlite`. Commit only the fixture. Add `resources: [.copy("Fixtures")]` to the KickData test target.
- [ ] **Step 1: Failing tests**
  - `SchemaUpgradeTests.aStoreFrom11OpensWithCycleLogsIntact`: copy fixture to temp, open with `KickPersistence.schema`, the log reads back with flow .light, moods [.tired], symptoms [.cramps], note "x", `spotting == false`, `sex == nil`, `sexDrive == nil`, `pregnancyTest == nil`; the period is there.
  - `CycleStoreTests.savesAndReadsNewFields`: save a record with spotting, .unprotected, .low, .positive → read back equal.
  - `CycleStoreTests.unknownSexRawIsKeptWhenFieldUnchanged`: model with `sexRaw = "future"`, apply a record with `sex == nil` changed only in note → `sexRaw == "future"` (mirror the `lhRaw` rule).
  - `BackupTests.cycleLogWithoutNewKeysDecodes` (1.1 JSON) → defaults.
  - `BackupTests.cycleLogNewFieldsRoundTrip` and `unknownPregnancyTestRawRoundTrips` (`"pregnancyTest":"faint"` survives decode → encode).
  - `BackupTests.spottingFalseIsNotEncoded`: encoded JSON lacks `"spotting"`.
- [ ] **Step 2:** `(cd Packages/KickData && swift test --filter "SchemaUpgrade|CycleStore")` and `scripts/test-core.sh --filter Backup` → FAIL.
- [ ] **Step 3:** Implement: model attrs + `record`/`apply` (keep unknown raw unless the record changes that field, as for `lhRaw`); DTO keys; `BackupStore` passes stored raw values into the DTO init, and restore writes raw strings back.
- [ ] **Step 4:** Both commands → PASS; full `scripts/test-core.sh` and `(cd Packages/KickData && swift test)` → PASS.
- [ ] **Step 5:** Commit `feat(data): store and back up the new cycle log fields`.

### Task 3: KickCore — `CycleInsights`

**Files:** Create `Packages/KickCore/Sources/KickCore/CycleInsights.swift`; Test `Packages/KickCore/Tests/KickCoreTests/CycleInsightsTests.swift`.

**Interfaces — Consumes:** `CycleHistory` (`cycles: [PastCycle]`, `countsTowardAverage`, `length`, `start`), `CycleLogRecord`, `CycleForecast` (`cycleDay`, `daysUntilNextPeriod`, `confidence`, `daysLate`). **Produces:**

```swift
public struct CycleInsights: Equatable, Sendable {
    public struct LengthBar: Equatable, Sendable { public let start: Date; public let length: Int; public let counts: Bool }
    public enum Regularity: Equatable, Sendable { case regular(spread: Int), somewhatVariable(spread: Int), variable(spread: Int) }
    public enum Item: Equatable, Sendable { case mood(Mood), symptom(Symptom), spotting }
    public enum Anchor: Equatable, Sendable { case startDay, daysBefore }
    public struct Pattern: Equatable, Sendable {
        public let item: Item; public let anchor: Anchor; public let window: ClosedRange<Int>
        public let cyclesWithItem: Int; public let cyclesLogged: Int
    }
    public let lengths: [LengthBar]      // completed cycles, oldest first, last ≤12; empty if <2
    public let regularity: Regularity?   // nil with <3 counted lengths
    public let patterns: [Pattern]       // ≤5, ranked
    public static func make(history: CycleHistory, logs: [CycleLogRecord], calendar: Calendar) -> CycleInsights
    public func todayPattern(forecast: CycleForecast?, today: Date, calendar: Calendar) -> Pattern?
}
```

Rules (verbatim from spec §2/§2b): regularity spread = max−min of the last 6 counted lengths: ≤7 regular, 8–9 somewhatVariable, ≥10 variable. Patterns over the last 6 completed counted cycles; denominator = those with ≥1 log with `hasContent`; item qualifies with ≥3 cycles and ≥50 %; occurrence = first day of the item in the cycle as `startDay` (1-based) and `daysBefore = length − startDay + 1`; window = narrowest range covering ⌈0.75·n⌉ occurrences, qualifies when `upper−lower+1 ≤ 5`; both → narrower, tie → `.startDay`; ranking: ratio desc, width asc, item display order (moods in enum order, then `Symptom.cases(for: .tryingToConceive)` order, then spotting). Only cycle-mode symptoms. `todayPattern`: nil without forecast or while paused/pregnant (caller passes nil forecast then); `.startDay` tests `forecast.cycleDay`; `.daysBefore` tests `daysUntilNextPeriod + 1` only if `confidence` is not the low case and `daysLate == 0`.

- [ ] **Step 1: Failing tests** (build `CycleHistory` via its existing factory from periods, as `CycleHistoryTests` does):
  - `workedExample`: 5 periods giving lengths 28, 30, 27, 29 + current; headache logged on cycle days 26, 28, 25, none; another log in cycle 4 → one pattern `item .symptom(.headache)`, `anchor .daysBefore`, `window 3...3`, `cyclesWithItem 3`, `cyclesLogged 4`.
  - `belowThreeCyclesIsNoPattern` (2/2 cycles) and `belowHalfIsNoPattern` (3/7 impossible → use 3 of 6 = 50 % qualifies; 2 of 6 not).
  - `windowWiderThanFiveIsNoPattern`: start days 1, 8, 15 and daysBefore spread too → no pattern.
  - `tieGoesToStartDay`.
  - `pregnancySymptomOnlyIsIgnored`: `.heartburn` in 4/4 cycles → no pattern; `.nausea` (shared) → pattern.
  - `longGapIsExcluded`: a 120-day "cycle" between periods is never in lengths' counted set nor in patterns' cycles; regularity computed from the other cycles only.
  - `regularityBands`: spreads 7, 8, 9, 10 → regular, somewhatVariable, somewhatVariable, variable; 2 counted → nil.
  - `lengthsNeedTwo` and `lengthsKeepLastTwelve`.
  - `rankingAndCap`: 7 qualifying items → 5, ordered by ratio then width.
  - `todayPatternStartDay`, `todayPatternDaysBeforeSkippedWhenLate`, `todayPatternDaysBeforeSkippedWhenLowConfidence`, `todayPatternNilWithoutForecast`.
- [ ] **Step 2:** `scripts/test-core.sh --filter CycleInsights` → FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** → PASS; full suite PASS.
- [ ] **Step 5:** Commit `feat(cycle): insights from cycle history and day logs`.

### Task 4: App — day log sheet, calendar marks, history insights, Today line

**Files:** Modify `App/Cycle/CycleDayLogSheet.swift`, `App/Cycle/CycleCards.swift` (summary words), `App/Cycle/CycleCalendarView.swift` / `CycleCalendarGrid` marks, `App/Cycle/CycleHistoryView.swift`, `App/Cycle/CycleTodayView.swift`, `App/Symptoms/SymptomChips.swift`; strings via `scripts/add-strings.py`. Create `App/Cycle/CycleInsightsSection.swift`.

**Interfaces — Consumes:** Tasks 1–3. `CycleCoordinator` already exposes history/logs/forecast; add `var insights: CycleInsights` computed on the coordinator if it already caches `history`, else compute in the view from `cycle.history` and `cycle.logs`.

- [ ] **Step 1: Strings** (en / vi): `dayLog.spotting` Spotting / Ra máu lấm tấm; `dayLog.sex` Sex / Quan hệ; `sex.unprotected` Unprotected / Không bảo vệ; `sex.protected` Protected / Có bảo vệ; `dayLog.sexDrive` Sex drive / Ham muốn; `sexDrive.low/normal/high` Low/Normal/High · Thấp/Bình thường/Cao; `dayLog.pregnancyTest` Pregnancy test / Que thử thai; `pregnancyTest.negative/positive` Negative/Positive · Âm tính/Dương tính; moods `irritable/sad/energetic` Irritable/Sad/Energetic · Cáu gắt/Buồn/Tràn đầy năng lượng; symptoms `diarrhea/constipation/dizziness` Diarrhea/Constipation/Dizziness · Tiêu chảy/Táo bón/Chóng mặt; `positiveTest.title` Congratulations! Switch to pregnancy tracking? / Chúc mừng! Bạn muốn chuyển sang theo dõi thai kỳ?; `positiveTest.switch` Switch / Chuyển; `positiveTest.later` Later / Để sau; `insights.chartTitle` Cycle length / Độ dài chu kỳ; `insights.regular` Your cycle is fairly regular (varies by %d days) / Chu kỳ của bạn khá đều (chênh %d ngày); `insights.somewhat` Your cycle varies a little (%d days) / Chu kỳ của bạn hơi dao động (%d ngày); `insights.variable` Your cycle varies quite a lot (%d days) / Chu kỳ của bạn dao động khá nhiều (%d ngày); `insights.patternsTitle` What you often notice / Điều bạn hay gặp; `insights.pattern.startDay` You often have %@ on day %@ of your period (%d/%d recent cycles) / Bạn hay %@ vào ngày %@ của kỳ kinh (%d/%d chu kỳ gần đây); `insights.pattern.daysBefore` …%@ days before your period… / …%@ ngày trước kỳ kinh…; `insights.empty` Log how you feel for a few cycles and Luna will show what you often notice. / Ghi lại cảm nhận vài chu kỳ, Luna sẽ chỉ ra điều bạn hay gặp.; `insights.footnote` (Global Constraints); `insights.today` In recent cycles you often had %@ around this time. / Mấy chu kỳ gần đây, bạn hay %@ vào khoảng thời gian này. Item phrases for patterns use lower-case verb phrases: add `insightItem.<raw>` per mood/symptom/spotting (vi e.g. "đau bụng", "đau đầu", "thấy mệt", "ra máu lấm tấm"). Ranges render "1–2" or "3" (single day).
- [ ] **Step 2: Day log sheet.** Sections in spec §1 order. Spotting = toggle chip in the period section. Sex and sex drive = single-select chips, tap selected again clears. Pregnancy test chips after LH/BBT (shown for every goal). On save: if the saved test is `.positive` and the loaded value was not, after dismiss present an alert (`positiveTest.*`); "Chuyển" opens `ImPregnantSheet` (present from the sheet's host, `CycleTodayView`/calendar, via a binding/callback `onPositiveTest`). Identifiers: `dayLogSpotting`, `dayLogSexUnprotected`, `dayLogSexProtected`, `dayLogSexDrive.<raw>`, `dayLogTestPositive`, `dayLogTestNegative`, `positiveTestSwitch`, `positiveTestLater`.
- [ ] **Step 3: Summary + calendar.** Words for the new `CycleLogSummaryItem` cases in the day card; calendar: spotting dot (period colour 40 %) only on non-period days; a small heart glyph under the day number when `sex != nil` (accessibility label "Quan hệ"/"Sex").
- [ ] **Step 4: History.** `CycleInsightsSection(insights:)` inserted after the averages: Swift Charts `BarMark` per `LengthBar` (counted = accent, not counted = muted), `RectangleMark` band 24–38, `RuleMark` at the average; regularity line (variable → also the existing irregular advice string); patterns list or empty text; footnote. Identifier `cycleInsights`, `cycleInsightPattern`.
- [ ] **Step 5: Today line.** Under `ComingUpCard`: `insights.todayPattern(forecast:today:calendar:)` → one secondary-text line with a sparkles icon; hidden when paused/pregnant (forecast nil there). Identifier `cycleTodayInsight`.
- [ ] **Step 6:** App build command (Global Constraints) → `** TEST BUILD SUCCEEDED **`.
- [ ] **Step 7:** Commit `feat(cycle): log, show and learn from the new day log fields`.

### Task 5: App lock

**Files:** Create `Packages/KickCore/Sources/KickCore/AppLockPolicy.swift` + `Tests/KickCoreTests/AppLockPolicyTests.swift`; create `App/Privacy/AppLock.swift` (observable + LAContext), `App/Privacy/AppLockView.swift`; modify `App/KickCounterApp.swift` (overlay at WindowGroup root), `App/Profile/ProfileView.swift` (toggle), `Packages/KickCore/Sources/KickCore/Settings.swift` (`SettingsKey.appLockEnabled = "appLockEnabled"`), `App/Info.plist` / `project.yml` (`NSFaceIDUsageDescription`), `Shared/InfoPlist.xcstrings`.

**Interfaces — Produces:**
```swift
public struct AppLockPolicy: Equatable, Sendable {
    public static let backgroundGrace: TimeInterval = 60
    public enum Event: Sendable { case launch, enteredBackground(Date), becameActive(Date) }
    public private(set) var isLocked: Bool
    public init(enabled: Bool, canAuthenticate: Bool)   // locked at launch iff both
    public mutating func handle(_ event: Event, enabled: Bool, canAuthenticate: Bool)
    public mutating func unlocked()
}
```
`becameActive(now)` locks only if a prior `enteredBackground(t)` exists and `now − t ≥ 60`; `.inactive` is never an event (the Face ID sheet). `canAuthenticate == false` → never locked (the app also turns the setting off).

- [ ] **Step 1: Failing tests** `AppLockPolicyTests`: `launchLocksWhenEnabled`, `launchOpenWhenDisabled`, `launchOpenWhenCannotAuthenticate`, `returnAfter59sStaysOpen`, `returnAfter60sLocks`, `activeWithoutBackgroundNeverLocks` (models the Face ID prompt's inactive→active), `unlockedClears`.
- [ ] **Step 2:** `scripts/test-core.sh --filter AppLockPolicy` → FAIL. **Step 3:** implement → PASS.
- [ ] **Step 4: App.** `AppLock` (`@Observable @MainActor`): reads `SettingsKey.appLockEnabled` from `AppGroup.defaults`; `canAuthenticate` = `LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)`; if enabled but cannot authenticate → set the key false. `authenticate()` runs `evaluatePolicy(.deviceOwnerAuthentication, localizedReason: L10n.appLockReason)`. Disabled entirely when `AppClock.launchOptions` has `-uiTesting`. Root: `.overlay { if lock.isLocked { AppLockView() } else if scenePhase != .active && lock.enabled { PrivacyCover() } }` — attach at the WindowGroup root view; verify a presented sheet is covered on device, else host the cover in a separate `UIWindow` at `.alert + 1` (spec Approaches, Lock B). `AppLockView`: app icon, "Luna Mom đã khoá"/"Luna Mom is locked", button "Mở khoá"/"Unlock" (identifier `appLockUnlock`), auto-auth on appear.
- [ ] **Step 5: Profile.** Under the privacy rows: toggle "Khoá bằng Face ID" (label from `LAContext.biometryType`: Face ID / Touch ID / "mật mã"), footer "Widget và thông báo vẫn hiện như cài đặt của iPhone." Turning on authenticates first; failure leaves it off. Hidden when `canAuthenticate` is false. Identifier `profileAppLock`.
- [ ] **Step 6: Strings + plist:** `appLock.title`, `appLock.unlock`, `appLock.reason` ("Mở khoá Luna Mom"/"Unlock Luna Mom"), `appLock.toggle.faceID/touchID/passcode`, `appLock.footer`; `NSFaceIDUsageDescription` en "Luna Mom uses Face ID to keep your diary private." vi "Luna Mom dùng Face ID để giữ nhật ký của bạn riêng tư."
- [ ] **Step 7:** App build → SUCCEEDED; full KickCore suite PASS. Commit `feat(privacy): lock the app with Face ID`.

### Task 6: UI tests, version, verification

**Files:** `UITests/CycleUITests.swift` (or the existing cycle UI test file), `UITests/UITestSupport.swift`, `project.yml`.

- [ ] **Step 1:** UI test `testDayLogNewFieldsAndPositiveTestPrompt`: seeded cycle (`-seedCycles`), open today's log, tap `dayLogSpotting`, `dayLogSexProtected`, `dayLogTestPositive`, save → alert `positiveTestLater` exists → tap it; reopen the log → the three chips are selected.
- [ ] **Step 2:** UI test `testHistoryShowsInsights`: seed ≥4 cycles with a repeated symptom (extend the `-seedCycles` seed option with logs, in `CycleSeed`, behind the existing debug launch options) → open history → `cycleInsights` and one `cycleInsightPattern` exist.
- [ ] **Step 3:** `MARKETING_VERSION: "1.2.0"`.
- [ ] **Step 4:** Full local gate: `scripts/test-core.sh`, `(cd Packages/KickData && swift test)`, app `build-for-testing` → all green. Commit `test(ui): 1.2 cycle logging and insights; version 1.2.0`.
- [ ] **Step 5 (after merge, before submission):** install the 1.2 TestFlight build over the owner's 1.1 data; the owner confirms logs, periods and memories are intact (migration on the real store).
