# Editing contractions during labour: implementation plan

Spec: `docs/superpowers/specs/2026-11-06-contraction-edit-design.md`. Branch `feat/contraction-edit`.
Every task is test first: write the test, see it fail, then implement.

## Decisions fixed by this plan
- A running contraction is not editable (stop it first). Only completed rows open the edit sheet.
- Start and end pickers have minute resolution; a changed time keeps the original seconds, so a 45 s
  contraction can still be moved without becoming 0 s or 60 s. A duration stepper (5 s steps) edits the end too.
- "Overlap" is open-interval: end == another start is allowed. A running neighbour counts as ending at `now`.
- A water-broke marker belongs to the episode whose span, widened by `ContractionRules.episodeGap` on both
  sides, contains it (nearest start wins); otherwise it is "loose" and shows in the current list while
  recent (after the episode-ended mark), else in history under its day.
- Edits never notify when the alert goes down or stays on: only `.none` to on, deduped as today.

## 1. KickCore (pure), `scripts/test-core.sh`
1. `ContractionEditRules` (new file `ContractionEditRules.swift`)
   - `enum ContractionEditError: Error, Equatable, Sendable { startInFuture, endInFuture, endNotAfterStart, tooShort, tooLong, overlapsNeighbour, notEditable }`
   - `static func validate(id: UUID?, start: Date, end: Date, existing: [ContractionRecord], now: Date) -> ContractionEditError?`
   - `static func validateMarker(at: Date, now: Date) -> ContractionEditError?`
   - `static func keepingSeconds(of original: Date, in picked: Date, calendar: Calendar) -> Date`
   - Tests `ContractionEditRulesTests`: `validEditHasNoError`, `startInFutureIsRefused`, `endInFutureIsRefused`,
     `endMustBeAfterStart`, `underThreeSecondsIsTooShort`, `exactlyThreeSecondsIsAllowed`, `overFiveMinutesIsTooLong`,
     `exactlyFiveMinutesIsAllowed`, `overlapAtTheStartEdgeIsRefused`, `overlapAtTheEndEdgeIsRefused`,
     `containingANeighbourIsRefused`, `touchingANeighbourIsAllowed`, `itsOwnRecordIsIgnored`,
     `aRunningNeighbourEndsAtNow`, `markerInFutureIsRefused`, `keepingSecondsKeepsTheOriginalSeconds`.
2. `LabourMarkerRecord`, `LabourMarkerRepository` (new file `LabourMarkers.swift`), `InMemoryLabourMarkerRepository`.
3. `ContractionStats(…, markers:)`: `ContractionEpisode.markers`, `ContractionStats.currentMarkers`,
   `ContractionDay.markers` (loose past markers), `pastDays(calendar:)` includes marker-only days.
   Tests (`ContractionStatsMarkerTests`): `markerInsideAnEpisodeJoinsIt`, `markerBeforeFirstContractionJoinsWithinTheGap`,
   `looseRecentMarkerIsCurrent`, `looseOldMarkerGoesToHistoryByDay`, `markerBeforeEpisodeEndMarkIsNotCurrent`.
4. `ContractionCoordinator` (extra init params `markers: LabourMarkerRepository = InMemoryLabourMarkerRepository()`)
   - `enum ContractionEditOutcome: Equatable, Sendable { saved, invalid(ContractionEditError), failed }`
   - `update(id: UUID, start: Date, end: Date) async -> ContractionEditOutcome`
   - `addMissed(start: Date, duration: TimeInterval) async -> ContractionEditOutcome`
   - `markWaterBroke(at: Date) async -> ContractionEditOutcome`, `updateMarker(id:at:)`, `deleteMarker(id:) async`
   - `markers: [LabourMarkerRecord]` observable; `load()` and `resetAfterDataDeletion()` cover markers.
   - Tests (`ContractionEditCoordinatorTests`): `updateChangesTheTimesAndRecomputesTheStats`,
     `updateRefusesAnOverlapAndChangesNothing`, `updateOfARunningContractionIsNotEditable`,
     `updateMovesAContractionIntoAnotherEpisode`, `updateSyncsTheLiveActivity`, `updateReportsAStoreFailure`,
     `addMissedJoinsTheEpisodeByTime`, `addMissedRefusesTheFuture`, `addMissedRefusesAnOverlap`,
     `addMissedSyncsTheLiveActivity`, `markWaterBrokeStoresTheMarker`, `markWaterBrokeRefusesTheFuture`,
     `updateMarkerAndDeleteMarker`, `anEditThatCrossesAThresholdNotifiesOnce`,
     `anEditThatFallsBelowAThresholdNeverNotifies`, `anAddThatCrossesAThresholdNotifies`,
     `anEditDoesNotNotifyAgainForTheSameRun`.
5. Backup: `BackupDocument.labourMarkers: [LabourMarkerDTO] = []` (optional, not written when empty),
   `BackupRecords.labourMarkers`, summary `isEmpty`, validation (no future, unique ids).
   Tests (`LabourMarkerBackupTests`): `roundTripKeepsMarkers`, `fileWithoutMarkersDecodesAsEmpty`,
   `emptyMarkersAreNotWritten`, `futureMarkerIsSkipped`, `duplicateMarkerIdIsSkipped`, `markersOnlyBackupIsNotEmpty`.

## 2. KickData, `cd Packages/KickData && swift test`
- `LabourMarker` @Model (`id`, `kind`, `at`, all defaulted, no relationships), `LabourMarkerStore`.
- One line each in `KickPersistence.schema`, `DataReset`, `BackupStore` (export and replace).
- Tests: `LabourMarkerStoreTests` (`savesAndReadsOldestFirst`, `savingTheSameIdReplaces`, `deleteIgnoresUnknownIds`,
  `failedSaveRollsBack`); `DataResetTests` (counts and entity list); `BackupStoreTests` (`exportsAndRestoresMarkers`);
  `StoreMigrationTests.aStoreCreatedWithoutLabourMarkersOpensAndKeepsItsRows`.

## 3. App
- Strings through `scripts/add-strings.py` (vi + en): edit/add/water-broke titles, labels, five error messages,
  accessibility labels. The water-broke card reuses `contraction.safety`.
- `ContractionEditSheet` (edit and add missed), `LabourMarkerSheet` (add, edit, delete), the water-broke card,
  marker rows in the list and history, `ContractionEpisodeDetailView` (history drill-down so history rows are editable).
- Wiring: `ContractionTimerView` buttons `contractionAddMissed`, `contractionWaterBroke`; `AppEnvironment` passes `LabourMarkerStore`.
- UI tests `ContractionEditUITests` (edit a row, add missed, water broke and the card, delete a marker) and
  `ContractionEditScreenshotTests` (edit sheet, add sheet, card; vi light, dark, AX5). Run only in CI (`CI-Only-Testing`).

## 4. Gates
`scripts/test-core.sh`, KickData tests, `xcodegen generate` and build-for-testing, then push, PR, `scripts/ci-wait.sh`.
Mutations: remove the overlap check (expect red in `ContractionEditRulesTests` and coordinator tests);
notify on any alert change (expect the falls-below test red). Revert each.
