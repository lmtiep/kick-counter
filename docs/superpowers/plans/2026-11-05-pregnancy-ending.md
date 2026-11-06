# When a Pregnancy Ends: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One gentle flow for the end of a pregnancy, through loss or birth.
It stops every pregnancy reminder and activity, keeps the journey as a Memory,
returns the app to cycle tracking with predictions paused, and offers warm
check-ins a few weeks later.

**Architecture:**
- **KickCore** holds the pure rules: the ended state, the pregnancy range, the
  memory builder, the prediction pause and the check-in policy, all tested.
- **KickData** adds one `PregnancyMemory` model (JSON payload, no
  relationships). It also adds an atomic "save memory and delete the raw rows"
  store call, plus the backup, delete-all and migration support.
- **The app** adds a `PregnancyEnding` orchestrator that cancels and ends
  everything, plus the screens.

**Tech Stack:** Swift 6, SwiftUI iOS 17, SwiftData (no CloudKit), Swift
Testing, XCUITest, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-11-05-pregnancy-ending-design.md`. Read
it all; §4.6 overrides earlier sections where they differ.

## Global Constraints
- Strings only through `scripts/add-strings.py`, in vi and en. For an existing
  key, use `--remove` and then add again.
- Luna tokens (`LunaPalette`, `.luna(...)`) and `Font.luna`, in light and dark
  and at AX5. `LunaMotion` is respected.
- KickCore stays pure: no SwiftUI, UIKit, SwiftData or UserNotifications.
- Never write "bất thường", diagnosis words, medical thresholds, "try again"
  or "mong con lại" nudges, contraception wording or hotline numbers.
- The loss branch never shows celebratory copy or fruit art. The birth branch
  never shows condolence copy.
- No notification or Lock Screen text ever mentions loss, birth or pregnancy.
  The only check-in notification body is
  "Luna Mom gửi bạn một lời hỏi thăm" / "Luna Mom is checking in on you".
- Ending the pregnancy never prompts for notification permission.
- **Don't run UI tests locally.** Run them in CI with a
  `CI-Only-Testing: <Classes>` trailer.
- The pre-push hook runs `scripts/test-core.sh`. Never skip it.
- Commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus
1. **A memory save that fails must delete nothing.** Task 5 has a test that
   forces a save failure and asserts that every raw row still exists.
2. **No cycle goal stored before ending.** A user who onboarded straight into
   pregnancy must land on `.tracking`, not `.conceiving`. Task 6 tests the
   goal fallback.
3. **The completed "Done!" kick Live Activity must be ended too.** Task 6
   tests `endAll(force: true)` through the fake manager.
4. **A period logged inside the pause.** Predictions resume only after she
   confirms it is the first period. If she says no, the pause stays and the
   period is kept. Task 3 tests both answers.
5. **Pregnant again after an ending.** The ended state, the check-ins and the
   `care-checkin` notification are cleared, and memories stay. Tasks 4 and 7
   test this.

## File Structure

**KickCore** (`Packages/KickCore/Sources/KickCore/`)

| File | Contents |
|---|---|
| `PregnancyEnd.swift` | `PregnancyEndBranch`, `PregnancyEndState` (App Group defaults load/save/clear) and `PregnancyRange` |
| `PregnancyMemoryContent.swift` | The Codable payload and `PregnancyMemoryBuilder` |
| `CyclePause.swift` | The pause rule and period filtering |
| `CareCheckIn.swift` | `CareFeeling`, `CareCheckInState` and `CareCheckInPolicy` |
| `CycleCoordinator.swift` (modify) | Uses `CyclePause`; adds `endPregnancy(...)` and `confirmFirstPeriod(...)` |
| `Backup.swift`, `BackupCodec.swift`, `BackupSettings.swift`, `Settings.swift` (modify) | The new optional array and the new keys, excluded from backups |

**KickData** (`Packages/KickData/Sources/KickData/`)

| File | Contents |
|---|---|
| `Models.swift` (modify) | `@Model PregnancyMemory` |
| `PregnancyMemoryStore.swift` | Memory create/list/delete and the atomic archive |
| `KickPersistence.swift`, `DataReset.swift`, `BackupStore.swift` (modify) | The new model in the schema, delete-all, export and replace-all |

**App**

| File | Contents |
|---|---|
| `App/PregnancyEnding/PregnancyEnding.swift` | The orchestrator |
| `App/PregnancyEnding/PregnancyEndingSheet.swift` | Replaces `EndPregnancySheet` |
| `App/PregnancyEnding/MemoryListView.swift`, `MemoryDetailView.swift` | The memory screens |
| `App/Cycle/CyclePausedCard.swift`, `App/Cycle/FirstPeriodQuestion.swift` | The pause line and the first-period question |
| `App/Care/CareCheckInCard.swift`, `App/Care/CareCheckInNotifications.swift` | The check-in card and its optional notification |
| `SystemLiveActivityManager.swift`, `SystemContractionLiveActivityManager.swift`, `LiveActivityManaging.swift` (modify) | `endAll(force:)` |
| `Widgets/Home/*` (modify) | The paused line |

---

### Task 1: The ended state and the pregnancy range (KickCore)

**Files:**
- Create: `Packages/KickCore/Sources/KickCore/PregnancyEnd.swift`
- Modify: `Packages/KickCore/Sources/KickCore/Settings.swift` (new keys)
- Test: `Packages/KickCore/Tests/KickCoreTests/PregnancyEndTests.swift`

**Interfaces (produces):**
```swift
public enum PregnancyEndBranch: String, Sendable, Codable, CaseIterable { case birth, loss }

public struct PregnancyEndState: Equatable, Sendable {
    public var branch: PregnancyEndBranch
    public var endDate: Date                // start of local day
    public var firstPeriodConfirmedID: UUID? // nil = predictions paused
    public static func load(from: UserDefaults) -> PregnancyEndState?
    public func save(to: UserDefaults)
    public static func clear(_ defaults: UserDefaults)
}

public enum PregnancyRange {
    /// LMP, else dueDate − 280 d, else the earliest of the fallback dates; through endDate.
    public static func make(profile: PregnancyProfile, endDate: Date, fallbackStarts: [Date],
                            calendar: Calendar) -> ClosedRange<Date>?
}
```
- New `SettingsKey`s:
  - `pregnancyEndBranch`, `pregnancyEndDate`, `pregnancyEndFirstPeriodID`;
  - `careCheckInEnabled`, `careCheckInNotify`, `careCheckInLastShown`,
    `careCheckInLowStreak`, `careCheckInStopped`.

- [ ] **Step 1: Write the failing tests**
  - `stateRoundTripsThroughDefaults`
  - `clearRemovesEveryKey`
  - `rangeUsesLMPWhenPresent`
  - `rangeUsesDueDateMinus280`
  - `rangeFallsBackToEarliestRecord`
  - `rangeIsNilWithNoDatesAndNoRecords`
  - `rangeEndIsTheEndDay`

  Use a suite `UserDefaults` and a Gregorian calendar fixed to `Asia/Ho_Chi_Minh`.
- [ ] **Step 2:** Run `cd Packages/KickCore && swift test --filter PregnancyEndTests` and confirm it fails because the type is missing.
- [ ] **Step 3:** Implement. Store dates as `timeIntervalSince1970`. `clear` removes the keys rather than writing 0; no `@AppStorage` depends on them.
- [ ] **Step 4:** Run the same filter and confirm it passes.
- [ ] **Step 5:** Commit with `feat(core): pregnancy end state and range`.

### Task 2: The memory payload and builder (KickCore)

**Files:**
- Create: `Packages/KickCore/Sources/KickCore/PregnancyMemoryContent.swift`
- Test: `Packages/KickCore/Tests/KickCoreTests/PregnancyMemoryBuilderTests.swift`

**Interfaces:**
- Consumes: `PregnancyRange` from Task 1. Also the existing `SessionRecord`,
  `ContractionRecord`, `AppointmentRecord`, `WeightRecord`, `CycleLogRecord`,
  `SymptomTimeline.showsInPregnancy`, `PregnancyTimeline` and
  `ContractionStats`.
- Produces:
```swift
public struct PregnancyMemoryContent: Codable, Equatable, Sendable {
    public var branch: PregnancyEndBranch
    public var start: Date?, end: Date
    public var furthestWeek: Int?            // completed weeks at end, 0...42
    public var kickDays: [KickDay]           // day, sessionCount, totalKicks, bestDuration
    public var contractionEpisodes: [ContractionEpisodeSummary] // start, count, avgDuration, avgInterval
    public var appointments: [MemoryAppointment] // date, title, note
    public var weights: [MemoryWeight]       // day, kg
    public var notes: [MemoryNote]           // day, text, moods, pregnancySymptoms (raw strings)
}
public enum PregnancyMemoryBuilder {
    public static func make(branch: PregnancyEndBranch, profile: PregnancyProfile, endDate: Date,
                            sessions: [SessionRecord], contractions: [ContractionRecord],
                            appointments: [AppointmentRecord], weights: [WeightRecord],
                            logs: [CycleLogRecord], calendar: Calendar) -> PregnancyMemoryContent
    /// Which raw rows the archive deletes (spec §4.6): all sessions and contractions,
    /// appointments and weights inside the range. Never logs.
    public static func rowsToDelete(range: ClosedRange<Date>?, appointments: [AppointmentRecord],
                                    weights: [WeightRecord]) -> (appointmentIDs: Set<UUID>, weightIDs: Set<UUID>)
}
```

- [ ] **Step 1: Write the failing tests:**
  - `kicksAreGroupedPerDay`, which only counts completed sessions;
  - `contractionEpisodesUseContractionStats`;
  - `appointmentsOutsideRangeAreLeftOut`;
  - `weightsInRangeOnly`;
  - `logsKeepOnlyPregnancyFields`: a log holding flow, BBT and a note keeps only the note, moods and pregnancy symptoms;
  - `furthestWeekForLossAt12Weeks`;
  - `furthestWeekClampsAt42`;
  - `noDatesUsesFallbackStart`;
  - `contentRoundTripsThroughJSON`;
  - `rowsToDeleteNeverIncludesOutOfRange`;
  - `sameContentForBothBranches`: the only difference between branches is the `branch` field (owner decision).
- [ ] **Step 2:** Run `swift test --filter PregnancyMemoryBuilderTests` and confirm it fails.
- [ ] **Step 3:** Implement. Encode dates as ISO-8601 through a shared `JSONEncoder` factory (`PregnancyMemoryContent.encoder` / `.decoder`).
- [ ] **Step 4:** Run the filter and confirm it passes.
- [ ] **Step 5:** Commit with `feat(core): pregnancy memory content and builder`.

### Task 3: The prediction pause (KickCore + CycleCoordinator)

**Files:**
- Create: `Packages/KickCore/Sources/KickCore/CyclePause.swift`
- Modify: `Packages/KickCore/Sources/KickCore/CycleCoordinator.swift`, in `recomputeForecast`, `switchToPregnant` and the new methods
- Test: `Packages/KickCore/Tests/KickCoreTests/CyclePauseTests.swift` and `CycleCoordinatorTests.swift`

**Interfaces (produces):**
```swift
public enum CyclePause {
    /// Paused when an ended state exists and its firstPeriodConfirmedID is nil
    /// or no longer matches a stored period.
    public static func isPaused(_ state: PregnancyEndState?, periods: [PeriodRecord]) -> Bool
    /// Periods starting before endDate are dropped (they must not skew averages).
    public static func periodsForForecast(_ periods: [PeriodRecord], state: PregnancyEndState?) -> [PeriodRecord]
    /// The first stored period starting on/after endDate that she has not been asked about.
    public static func periodNeedingConfirmation(_ state: PregnancyEndState?, periods: [PeriodRecord],
                                                 declined: Set<UUID>) -> PeriodRecord?
}
// CycleCoordinator
public private(set) var isPaused: Bool
public private(set) var endState: PregnancyEndState?
public func confirmFirstPeriod(id: UUID) async        // resumes, re-syncs reminders (mayPrompt: false)
public func declineFirstPeriod(id: UUID)               // stores id in a declined set (defaults key pregnancyEndDeclinedPeriods)
public func endPregnancy(branch: PregnancyEndBranch, endDate: Date) async
    // saves .tracking if SettingsKey.cycleGoal absent; saves state; PregnancyProfile.clear;
    // AppMode.save(.tryingToConceive); refresh; syncReminders(mayPrompt: false)
```
- **While paused:** `forecast = nil`. The existing `syncReminders` path then
  cancels the prediction reminders. Pill reminders are not touched.
- **`switchToPregnant`:** also calls `PregnancyEndState.clear` and removes the
  declined set.

- [ ] **Step 1: Write the failing tests:**
  - `pausedWithNoConfirmedPeriod`
  - `resumesAfterConfirm`
  - `confirmedPeriodDeletedPausesAgain`
  - `preEndPeriodsExcludedFromForecast`
  - `periodBeforeEndDateNeverAsked`
  - `declinedPeriodNotAskedAgainAndStaysPaused`
  - In the coordinator:
    - `endPregnancyWithNoStoredGoalSavesTracking`
    - `endPregnancyKeepsAnExistingConceivingGoal`
    - `endPregnancyNeverPrompts`, via the fake notifications' `requestAuthorization` count == 0
    - `forecastNilWhilePaused`
    - `switchToPregnantClearsEndState`
- [ ] **Step 2:** Run `swift test --filter "CyclePauseTests|CycleCoordinatorTests"` and confirm the new tests fail.
- [ ] **Step 3:** Implement as specified above.
- [ ] **Step 4:** Run `scripts/test-core.sh > "$TMPDIR/core.log" 2>&1; tail -5 "$TMPDIR/core.log"` and confirm everything passes.
- [ ] **Step 5: Mutation.** Make `isPaused` always return false. At least 3 tests must go red. Revert.
- [ ] **Step 6:** Commit with `feat(cycle): pause predictions after a pregnancy ends`.

### Task 4: The check-in policy (KickCore)

**Files:**
- Create: `Packages/KickCore/Sources/KickCore/CareCheckIn.swift`
- Test: `Packages/KickCore/Tests/KickCoreTests/CareCheckInTests.swift`

**Interfaces (produces):**
```swift
public enum CareFeeling: String, CaseIterable, Sendable { case good, okay, tired, sad, heavy } // sad, heavy = low
public struct CareCheckInState: Equatable, Sendable {
    public var enabled: Bool = true, notify: Bool = false, stopped: Bool = false
    public var lastShown: Date?, lowStreak: Int = 0
    public static func load(from: UserDefaults) -> CareCheckInState
    public func save(to: UserDefaults)
    public static func clear(_ defaults: UserDefaults)
}
public enum CareCheckInPolicy {
    public static let firstDay = 21, spacingDays = 7, lastDay = 21 + 7 * 12   // 105
    public static func isDue(end: PregnancyEndState?, state: CareCheckInState, now: Date, calendar: Calendar) -> Bool
    public static func nextDate(end: PregnancyEndState?, state: CareCheckInState, now: Date, calendar: Calendar) -> Date?
    public static func record(_ feeling: CareFeeling?, state: CareCheckInState, now: Date) -> CareCheckInState // nil = "Bỏ qua"
    public static func showsShareLine(_ state: CareCheckInState) -> Bool    // lowStreak >= 2
    public static func tipIndex(now: Date, calendar: Calendar, count: Int) -> Int // stable per day
}
```

- [ ] **Step 1: Write the failing tests:**
  - `notDueOnDay20`
  - `dueOnDay21`
  - `notDueAgainWithin7Days`
  - `dueAfter7Days`
  - `neverDueAfterDay105`
  - `stoppedNeverDue`
  - `disabledNeverDue`
  - `noEndStateNeverDue`
  - `skipSetsLastShownWithoutChangingStreak`
  - `twoLowInARowShowsShareLine`
  - `aGoodFeelingResetsStreak`
  - `nextDateIsDay21ThenWeekly`
  - `nextDateNilWhenStopped`
  - `clearRemovesKeys`
- [ ] **Step 2:** Run `swift test --filter CareCheckInTests` and confirm it fails.
- [ ] **Step 3:** Implement. Day arithmetic uses `calendar.dateComponents([.day], from: startOfDay(end), to: startOfDay(now))`.
- [ ] **Step 4:** Run the filter and confirm it passes.
- [ ] **Step 5: Mutation.** Change `firstDay` to 20. At least 2 tests must go red. Revert.
- [ ] **Step 6:** Commit with `feat(core): care check-in policy`.

### Task 5: The PregnancyMemory model, atomic archive, backup and reset (KickData + KickCore backup)

**Files:**
- Modify:
  - `Packages/KickData/Sources/KickData/Models.swift`, adding `@Model PregnancyMemory`;
  - `KickPersistence.swift`: add the model to the `schema`;
  - `DataReset.swift`;
  - `BackupStore.swift`, in export, `replaceAll` and the `deleteEvery` list.
- Create: `Packages/KickData/Sources/KickData/PregnancyMemoryStore.swift`
- Modify KickCore:
  - `Backup.swift`: add `pregnancyMemories: [PregnancyMemoryDTO] = []`, following `contractions` exactly (decodeIfPresent, omit when empty);
  - `BackupCodec.swift`: summary counts, the empty-check and the sanitising pass;
  - `BackupSettings.swift`: the Task 1 and 4 keys are excluded.
- Modify: `App/Backup/AppDataReset.swift`, so delete-all clears the new keys.
- Tests:
  - KickData: `PregnancyMemoryStoreTests.swift`, `DataResetTests.swift` (update the entity list), `BackupStoreTests.swift` and `MigrationTests.swift`;
  - KickCore: the backup tests.

**Interfaces (produces):**
```swift
@Model public final class PregnancyMemory {
    public var id: UUID = UUID()
    public var createdAt: Date = Date()
    public var title: String = ""
    public var branchRaw: String = PregnancyEndBranch.birth.rawValue
    public var payload: Data = Data()     // PregnancyMemoryContent JSON
}
public struct PregnancyMemoryRecord: Equatable, Sendable, Identifiable { id, createdAt, title, content }
public final class PregnancyMemoryStore {
    public init(context: ModelContext)
    public func all() throws -> [PregnancyMemoryRecord]           // newest first
    public func rename(id: UUID, title: String) throws
    public func delete(id: UUID) throws
    /// Inserts the memory (if any) and deletes the given raw rows in ONE save; on any
    /// throw, rolls back (context.rollback()) and rethrows — nothing deleted.
    public func archive(memory: PregnancyMemoryContent?, title: String,
                        deleteAllSessions: Bool, deleteAllContractions: Bool,
                        appointmentIDs: Set<UUID>, weightIDs: Set<UUID>) throws
}
```

- [ ] **Step 1: Write the failing tests:**
  - `archiveSavesMemoryAndDeletesRows`
  - `archiveFailureDeletesNothing`: inject failure through a store-level `saveHook: (() throws -> Void)?` used only in tests; it throws before `context.save()`. Assert that every row remains and that there is no memory.
  - `archiveWithoutMemoryOnlyDeletes`
  - `logsAreNeverDeleted`
  - `allIsNewestFirst`
  - `renameAndDelete`
  - `deleteAllRemovesMemories`
  - `backupRoundTripWithMemories`
  - `backupWithoutKeyDecodesEmpty`
  - `emptyMemoriesNotWritten`
  - `newKeysExcludedFromBackup`
  - `migrationFrom1_0Store`: create a store with the 1.0 schema (every model except `PregnancyMemory`) at a temp URL, add rows, close it, reopen it with `KickPersistence.configuration(url:)`, and assert that the rows survive and a memory can be inserted.
- [ ] **Step 2:** Run `cd Packages/KickData && swift test > "$TMPDIR/data.log" 2>&1; tail -20 "$TMPDIR/data.log"` and confirm the new tests fail.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the KickData tests and `scripts/test-core.sh`, and confirm both pass.
- [ ] **Step 5: Mutation.** Move the deletes so they run after the save (two saves). `archiveFailureDeletesNothing` must go red. Revert.
- [ ] **Step 6:** Commit with `feat(data): pregnancy memories with an atomic archive`.

### Task 6: The ending orchestrator (App)

**Files:**
- Create: `App/PregnancyEnding/PregnancyEnding.swift`
- Modify:
  - `LiveActivityManaging.swift` (KickCore protocol) and `ContractionLiveActivityManaging`: add `endAll(force: Bool)`; `endAll()` stays as `endAll(force: false)`;
  - `App/SystemLiveActivityManager.swift`, `App/SystemContractionLiveActivityManager.swift`;
  - the KickCore fakes.
- Test: `Packages/KickCore/Tests/KickCoreTests/PregnancyEndingPlanTests.swift`, covering the pure step list described below.

**Interfaces:**
- Consumes: Tasks 1–5, `KickCoordinator.cancelSession`,
  `ContractionCoordinator.resetAfterDataDeletion`,
  `NotificationScheduler.cancelDailyReminder` / `cancelOverdueAlerts(except: nil)`,
  `AppointmentReminders.cancelAppointmentReminder(id:)` and
  `CycleCoordinator.endPregnancy`.
- Produces:
```swift
@MainActor final class PregnancyEnding {
    init(kicks: KickCoordinator, contractions: ContractionCoordinator, cycle: CycleCoordinator,
         container: ModelContainer, notifications: NotificationScheduling)
    enum Keep { case memory(title: String), noMemoryKeepData, noMemoryDeleteData }
    /// Order: archive (throws → stop, nothing else changed) → cancel session/contraction →
    /// end Live Activities (force) → cancel pregnancy notifications → cycle.endPregnancy.
    func end(branch: PregnancyEndBranch, endDate: Date, keep: Keep) async throws
}
```
- To keep the order testable, put it in KickCore as
  `PregnancyEndingPlan.steps(keep:) -> [PregnancyEndingStep]`. The orchestrator
  executes the steps in that order.

- [ ] **Step 1: Write the failing tests:**
  - `archiveComesFirst`
  - `noMemoryKeepDataSkipsArchive`
  - `everyPathEndsActivitiesForcedAndCancelsReminders`
  - A KickCore fake test: `forceEndAllEndsTheDoneActivity`
- [ ] **Step 2:** Run the filter and confirm it fails.
- [ ] **Step 3:** Implement. Inject the orchestrator through the environment as the other coordinators are (`KickCounterApp`). Cancel appointment reminders for the archived or in-range appointment IDs. With `noMemoryKeepData`, cancel reminders for every future appointment.
- [ ] **Step 4:** Run `xcodegen generate`, then `xcodebuild build-for-testing -scheme KickCounter -destination 'platform=iOS Simulator,name=iPhone 18 Pro' CODE_SIGNING_ALLOWED=NO > "$TMPDIR/b.log" 2>&1; tail -3 "$TMPDIR/b.log"`. Expect `** TEST BUILD SUCCEEDED **`. Run `scripts/test-core.sh` and confirm it passes.
- [ ] **Step 5:** Commit with `feat(app): pregnancy ending orchestrator`.

### Task 7: The ending sheet and the memory screens (App UI)

**Files:**
- Create:
  - `App/PregnancyEnding/PregnancyEndingSheet.swift`
  - `MemoryListView.swift`
  - `MemoryDetailView.swift`
- Modify:
  - `App/Profile/ProfileView.swift`: replace the `EndPregnancySheet` row and type, and add a "Kỷ niệm" row shown when `memories.count > 0`;
  - `App/Cycle/ImPregnantSheet.swift`: nothing beyond Task 3, but verify the flow.
- Strings via `scripts/add-strings.py`. Keys `pregnancyEnd.*` and `memory.*`, vi/en:
  - **Entry row:** "Thai kỳ của tôi đã kết thúc" / "My pregnancy has ended".
  - **Choices:** "Bé đã chào đời" / "My baby was born"; "Thai kỳ đã dừng lại" / "My pregnancy stopped".
  - **Loss opener:** "Mình rất tiếc. Bạn không cần giải thích gì cả. Luna Mom sẽ ở đây, theo nhịp của bạn." / "I'm so sorry. You don't need to explain anything. Luna Mom is here, at your pace."
  - **Birth opener:** "Chúc mừng bạn và bé. Luna Mom mong hai mẹ con thật nhiều bình yên." / "Congratulations to you and your baby. Wishing you both lots of peace."
  - **Keep question:** "Bạn có muốn giữ lại hành trình này như một kỷ niệm không?" / "Would you like to keep this journey as a memory?"
  - **No-memory option:** "Xoá dữ liệu thai kỳ" / "Delete pregnancy data". Its default is off.
  - **Memory title placeholder:** "Đặt tên cho kỷ niệm (không bắt buộc)" / "Name this memory (optional)".
- Tests:
  - `UITests/PregnancyEndingUITests.swift`
  - `UITests/PregnancyEndingScreenshotTests.swift`
  - DEBUG seed `-seedPregnancyEnded <birth|loss>:<daysAgo>` in the existing seed handler, which also creates one memory.

**Flow:** choose a branch → the opener plus an optional date picker (default
today, no future dates) → the keep question → confirm → dismiss to cycle
Today.
- A cancel button on every step. Nothing changes before confirm.
- A failure shows an alert and leaves everything unchanged.

**Memory detail:**
- **Loss:** the header shows the title (or "Hành trình của bạn"), then the
  dates, then the sections: notes, appointments, weights, kicks, contractions.
  No fruit art.
- **Birth:** the same sections, with a soft header that has no fruit art
  either *(controller's call, to keep one calm style)*.
- **Actions:** a toolbar menu to rename and to delete (with confirmation).

- [ ] **Step 1: Write the UI tests:**
  - `testLossEndingWithMemory`: the end state shows cycle Today; the pregnancy tab is gone; the Kỷ niệm row exists; opening it shows the title.
  - `testBirthEndingWithoutMemoryKeepsData`
  - `testCancelAtEachStepChangesNothing`: mode still pregnant.
  - `testDeleteMemory`
  - `testOnboardedPregnantEndsOnTrackingGoal`: launch with `-skipOnboarding -seedDueDate` and no goal; after ending, Profile shows "Theo dõi chu kỳ".
- [ ] **Step 2:** Implement the screens.
- [ ] **Step 3: Screenshot tests** (vi light/dark and AX5): the branch choice, the loss opener, the birth opener, the keep question and the memory detail.
- [ ] **Step 4:** Build for testing (as in Task 6), and confirm it passes.
- [ ] **Step 5:** Commit with trailer `CI-Only-Testing: PregnancyEndingUITests PregnancyEndingScreenshotTests ProfileUITests`, then push.
- [ ] **Step 6:** Run `scripts/ci-wait.sh`. Read the screenshots with `sips -Z 900`. Rerun failed jobs once if flaky.

### Task 8: The paused cycle, the first-period question, the check-ins and the widget (App UI)

**Files:**
- Create:
  - `App/Cycle/CyclePausedCard.swift`
  - `App/Cycle/FirstPeriodQuestion.swift`
  - `App/Care/CareCheckInCard.swift`
  - `App/Care/CareCheckInNotifications.swift`
- Modify:
  - `App/Cycle/CycleTodayView.swift`: the paused card replaces the forecast ring and headline while paused, and the check-in card goes above the other cards when due;
  - the place that saves a new period (`CycleTodayView` / `CalendarPeriodEditor`): after a save, if `CyclePause.periodNeedingConfirmation` is non-nil, present `FirstPeriodQuestion`;
  - `App/Profile/ProfileView.swift`: a "Hỏi thăm" section shown while an end state exists, with the toggles "Hỏi thăm tôi" and "Gửi thông báo nhẹ nhàng";
  - `Widgets/Home/*` and `WidgetSnapshot`: a paused state that shows the short paused line;
  - `ImPregnantSheet` path: cancel the `care-checkin` notification.
- Strings:
  - **Paused, birth:** "Sau sinh, kỳ kinh có thể quay lại sau vài tuần hoặc vài tháng, nhất là khi cho con bú." / "After birth, your period may take weeks or months to return, especially while breastfeeding."
  - **Paused, loss:** "Kỳ kinh có thể cần một thời gian để quay lại. Khi nào có, bạn chỉ cần ghi lại." / "Your period may take a while to come back. When it does, just log it."
  - **First-period question:** "Đây có phải kỳ kinh đầu tiên sau khi sinh không?" / "…sau thai kỳ không?", and the en equivalents. Buttons: "Đúng vậy" and "Chưa phải".
  - **Check-in:** "Hôm nay bạn thế nào?" / "How are you today?". Feelings use soft SF Symbols plus labels. Buttons: "Bỏ qua" / "Skip" and "Cảm ơn, mình ổn rồi" / "Thanks, I'm okay now".
  - **Share line:** "Nếu nỗi buồn cứ kéo dài, hãy chia sẻ với người thân hoặc một người bạn tin cậy." / "If the sadness lingers, share it with someone close or a friend you trust."
  - **Ten tips**, keys `care.tip.1`…`care.tip.10`. They are short and non-medical, for example: a slow walk outside; a warm drink; call someone you love; write three lines about today; rest without guilt; open a window and breathe; listen to a favourite song; a warm shower; step into the sun for a few minutes; let someone help you today.
  - **Notification body:** "Luna Mom gửi bạn một lời hỏi thăm" / "Luna Mom is checking in on you". The title is empty or "Luna Mom".
- **Notification:**
  - It is a single `UNCalendarNotificationTrigger` at 10:00 on `CareCheckInPolicy.nextDate`, with ID `care-checkin`.
  - It is rescheduled after each answer and on app active. It is cancelled on stop, on the toggle off, on delete-all and on pregnant again.
  - Turning on "Gửi thông báo nhẹ nhàng" may prompt for permission, because that is her explicit action.
- Tests:
  - `UITests/CareAfterPregnancyUITests.swift`:
    - `testPausedCardShowsAfterLoss`
    - `testFirstPeriodYesResumesForecast`
    - `testFirstPeriodNoKeepsPause`
    - `testCheckInDueAt21Days`, with seed loss:21
    - `testNotDueAt20Days`
    - `testImOkayStopsCheckIns`
    - `testTwoLowShowsShareLine`
  - Screenshot tests for the paused Today (both branches), the question and the check-in card with a tip. Widget render previews for the paused state.

- [ ] **Step 1:** Write the UI tests.
- [ ] **Step 2:** Implement.
- [ ] **Step 3:** Run the widget render test locally (`TEST_RUNNER_WIDGET_PREVIEW_DIR=…`, as in the widgets README) and look at the paused PNGs.
- [ ] **Step 4:** Build for testing and run `scripts/test-core.sh`. Both must pass.
- [ ] **Step 5:** Commit with trailer `CI-Only-Testing: CareAfterPregnancyUITests CareAfterPregnancyScreenshotTests CycleUITests`, then push and run `scripts/ci-wait.sh`. Read the screenshots.

### Task 9: Docs

- [ ] `README.md`: add a "Khi thai kỳ kết thúc" section.
- [ ] `docs/release-checklist.md`: add a "1.1 — Khi thai kỳ kết thúc" section with these device checks:
  - no pregnancy notification is left in Settings → Notifications pending (use a debug list);
  - the Lock Screen is cleared of the "Done!" activity;
  - the check-in notification text is neutral;
  - the widget shows the paused state.
- [ ] `docs/app-review-notes.md`: one line saying the app has a pregnancy-ended flow with no medical advice.
- [ ] Commit with `docs: pregnancy ending`. Open the PR with the full suite running. The PR body ends with the Claude Code line.

### After all tasks
- **Whole-branch review on the top tier.** It is required, because the
  branch includes a schema change and data deletion.
- **Fix-loop cap of 2.**
