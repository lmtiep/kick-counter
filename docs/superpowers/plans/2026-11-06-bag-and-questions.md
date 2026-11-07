# Hospital bag and doctor questions: implementation plan

Spec: `docs/superpowers/specs/2026-11-06-hospital-bag-questions-design.md`. TDD: each task
writes its test first and watches it fail. KickCore stays pure; views read `@Query`, so
`AppEnvironment`, `AppDataReload` and the coordinators are untouched (small shared edits).

## Decisions
- "Đồ đi sinh" row: **Profile, pregnancy mode, directly under "Lịch khám"** (any week).
  Kicks tab is about counting; Profile already holds the other pregnancy lists.
- Today: a bag card from week 32, and a "Ghi câu hỏi cho bác sĩ" card (any week with a due date).
- Built-in text lives in `Localizable.xcstrings` (`bag.item.<id>`, `bag.group.<group>`),
  added only by `scripts/add-strings.py`; KickCore holds ids and groups only.
- Unassigned questions are adopted when a new upcoming appointment is saved (editor, via
  `ChecklistStore.adoptUnassignedQuestions`), guarded by `QuestionRouting.canAdopt`.
- Deleting an appointment deletes its questions inside `AppointmentStore.delete` (one save);
  the confirmation names them when there are any.

## Task 1: KickCore `Checklist.swift` (tests: `ChecklistTests.swift`)
Types: `ChecklistKind {bag, question}`, `BagGroup {documents, mother, baby, companion}`,
`ChecklistItemRecord(id:kind:group:builtInID:text:isDone:isHidden:order:appointmentID:createdAt:)`,
`BagBuiltIn(id:group:)`, `BagCatalog.items`, `BagEntry`, `BagSection`.
- `BagList.sections(overrides:) -> [BagSection]` (merge), `BagList.progress(_:) -> ChecklistProgress`
- `BagRules.todayCardFromWeek = 32`, `BagRules.showsTodayCard(week:)`
- `ChecklistText.clean(_:maxLength:) -> String?`
Tests: `catalogHasUniqueIdsAndAllFourGroups`, `catalogSizeIsBetween25And35`,
`everyBuiltInHasViAndEnStrings`, `noBuiltInMentionsMedicine`, `untouchedBuiltInsAreUndone`,
`overrideTicksABuiltIn`, `hiddenBuiltInLeavesTheSectionAndTheCount`, `customItemsFollowBuiltInsByOrder`,
`customItemsKeepTheirTickAndOrderTies`, `overrideForAnUnknownBuiltInIsIgnored`, `progressCountsVisibleOnly`,
`todayCardFromWeek32`, `cleanTrimsAndRejectsEmpty`.

## Task 2: KickCore `QuestionRouting` (tests: `QuestionRoutingTests.swift`)
- `QuestionRouting.target(upcoming:now:calendar:) -> UUID?` (soonest upcoming, nil if none)
- `QuestionRouting.canAdopt(_:now:calendar:) -> Bool`
- `QuestionRouting.questions(for:in:)`, `unassigned(in:)`
Tests: `routesToTheNextUpcomingAppointment`, `skipsDoneAndPastAppointments`, `noAppointmentMeansUnassigned`,
`aNewUpcomingAppointmentCanAdopt`, `aPastOrDoneAppointmentCannotAdopt`, `questionsAreFilteredPerAppointment`.

## Task 3: KickData model + schema + `ChecklistStore` (tests: `ChecklistStoreTests.swift`)
`ChecklistItem` @Model, every property defaulted, no relationships; one line in
`KickPersistence.schema` and `DataReset`. `ChecklistStore`: `items()`, `addBagItem`, `addQuestion`,
`setBuiltInDone`, `setBuiltInHidden`, `setDone(id:)`, `delete(id:)`, `resetBagTicks()`,
`unhideAllBuiltIns()`, `adoptUnassignedQuestions(into:)`, `deleteQuestions(appointmentID:)`.
Tests: `untouchedBuiltInsStoreNothing`, `tickingABuiltInStoresOneOverride`, `hidingAndUnhiding`,
`addingACustomItemTrimsAndOrders`, `blankTextIsRejected`, `resetClearsTicksButKeepsHidden`,
`questionsAttachToAnAppointment`, `adoptMovesOnlyUnassignedQuestions`, `deleteRemovesAnItem`.

## Task 4: appointment delete cascade (tests added to `AppointmentStoreTests`, `DataResetTests`)
`deletingAnAppointmentDeletesItsQuestionsOnly`, `deleteAllEmptiesEveryModel` (+ ChecklistItem),
`deleteAllCoversEverySchemaEntity` (+ ChecklistItem), `aStoreCreatedWithoutChecklistItemOpensWithItsRows`
(`SchemaUpgradeTests.swift`: a store file made from the old schema list, reopened with the current one).

## Task 5: backup (tests: `ChecklistBackupTests.swift` in KickCore, cases in `BackupStoreTests`)
Optional `checklistItems` array in `BackupDocument` (not written when empty), `ChecklistItemDTO`
(raw strings), `BackupRecords.checklistItems`, summary count, validation (known kind, non-empty text
for custom items and questions, unique ids). KickCore: `checklistRoundTrips`, `anOlderFileLoadsAsEmpty`,
`emptyListIsNotWritten`, `validationDropsUnknownKindsAndBlankText`. KickData:
`exportAndReplaceRoundTripChecklistItems`, `replaceAllRemovesOldChecklistItems`.

## Task 6: UI
Strings via `scripts/add-strings.py` + `L10n` (appended section "Bag and questions (1.1)").
`App/Checklists/`: `BagChecklistView`, `AddBagItemSheet`, `BagTodayCard`, `QuickQuestionCard`/`QuickQuestionSheet`,
`QuestionsSection` (editor, pending and unassigned modes). Edits: `PregnancyTodayView` (two cards),
`ProfileView` (one row), `AppointmentEditorSheet` (questions + adoption), `AppointmentsView`
(unassigned section, delete message, question counts), `AppointmentRows`.
No launch-argument seeds (they would touch `UITestLaunchOptions` and `AppEnvironment`, shared with other branches): UI tests create their data through the UI.

## Task 7: UI tests (CI only) `BagChecklistUITests`, `QuestionsUITests`, `BagQuestionsScreenshotTests`
Tick and add an item; hide a built-in; reset; quick-add then see it on the next appointment and tick;
delete an appointment confirmation mentions questions. Screenshots: bag list, Today card at week 33,
appointment with questions: vi light/dark, AX5.

## Gate
`scripts/test-core.sh`, `cd Packages/KickData && swift test`, `xcodegen generate`, `build-for-testing`.
Mutations: built-in/override merge and quick-add routing (report red counts).
