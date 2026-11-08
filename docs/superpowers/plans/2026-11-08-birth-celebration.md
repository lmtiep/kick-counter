# Birth Celebration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After a birth ending is confirmed, show a joyful full-screen celebration plus a tap-paged recap; add a Today card from week 37 and a visible Profile card to reach the ending.

**Architecture:** Pure rules and the recap model live in KickCore (TDD). `PregnancyEnding.end` returns a `PregnancyRecap?` (birth only) and the sheet hands it to an `@Observable` holder (`pendingCelebration`) that `RootView` binds a `fullScreenCover(item:)` to. The view is SwiftUI-only (`Canvas` + `TimelineView`).

**Tech Stack:** Swift 6, SwiftUI iOS 17, SwiftData, XcodeGen, Swift Testing, XCUITest.

**Spec:** `docs/superpowers/specs/2026-11-08-birth-celebration-design.md`

## Global Constraints

- Strings only via `scripts/add-strings.py` (en + vi), accessed through `L10n` accessors; Vietnamese copy from the spec verbatim.
- No new dependency; Reduce Motion: no moving particles, no count-up, cross-fade pages.
- No celebration, confetti or recap on the loss branch.
- Today card only from week 37 (`week >= 37`).
- Close button (`birthCelebrationClose`) always reachable; the ending is saved before the cover appears.
- Identifiers: `birthPromptCard`, `birthCelebrationNext`, `birthCelebrationDone`, `birthCelebrationClose`; `profilePregnancyEnded` is kept.
- UI tests are written but never run locally.

## Review Focus

- Week 36 / 37 / 42 boundaries of the Today card (Task 1).
- Loss branch never yields a recap (Task 2 test, mutation).
- Pregnancy with no dates (nil start / furthestWeek): `.journey` page skipped, days nil, no crash (Task 2).
- Very short pregnancy (week 6) and the week-4 clamp for `journeyWeeks` (Task 2).
- One weight entry gives no weight page (Task 2).

---

### Task 1: BirthPromptRules (KickCore)

**Files:** Create `Packages/KickCore/Sources/KickCore/BirthPrompt.swift`; Test `Packages/KickCore/Tests/KickCoreTests/BirthPromptRulesTests.swift`

**Produces:** `BirthPromptRules.todayCardFromWeek = 37`, `BirthPromptRules.showsTodayCard(week: Int) -> Bool`

- [ ] Write `BirthPromptRulesTests`: week 36 false; 37, 38, 42 true.
- [ ] Run `scripts/test-core.sh --filter BirthPromptRulesTests`: fails to compile.
- [ ] Implement as `BagRules` does. Run: passes.
- [ ] Commit.

### Task 2: PregnancyRecap (KickCore)

**Files:** Create `Packages/KickCore/Sources/KickCore/PregnancyRecap.swift`; Test `.../PregnancyRecapTests.swift`

**Produces:** `public struct PregnancyRecap: Equatable, Sendable, Identifiable` with the spec's fields plus `keptAsMemory: Bool` and `id: Date { birthDate }`; nested `enum Page { celebration, journey, kicks, contractions, appointments, weight, thanks }`;
`static func make(content: PregnancyMemoryContent, keptAsMemory: Bool = false, calendar: Calendar) -> PregnancyRecap`;
`static func forEnding(content: PregnancyMemoryContent, keptAsMemory: Bool, calendar: Calendar) -> PregnancyRecap?` (nil unless `content.branch == .birth`).

- [ ] Tests: empty content gives `[.celebration, .thanks]`; full content gives all seven pages in order; kick/session/contraction sums; weight change needs 2+ entries (last minus first); `journeyWeeks` (week 40: first 4, last 40, <= 8, ascending, unique; week 6: [4,5,6]; week 2: [4]; week 42 fine); nil start gives nil days; `forEnding` nil for loss, non-nil for birth.
- [ ] Run: fails. Implement; sampling for n = last - 4 + 1 > 8: `4 + round(i*(n-1)/7)` for i in 0..<8. Run: passes.
- [ ] Commit.

### Task 3: PregnancyEnding returns the recap

**Files:** Modify `App/PregnancyEnding/PregnancyEnding.swift`.

- [ ] `archive` builds content when `keep.memoryTitle != nil || branch == .birth`, saves it only when kept, returns it.
- [ ] `end(...)` becomes `@discardableResult ... async throws -> PregnancyRecap?` via `PregnancyRecap.forEnding`.
- [ ] Add `var pendingCelebration: PregnancyRecap?` on the observable. Compile check; commit.

### Task 4: Strings and L10n

- [ ] Add all new keys via `scripts/add-strings.py`; accessors in `Shared/L10n.swift`. Commit.

### Task 5: BirthCelebrationView

**Files:** Create `App/PregnancyEnding/BirthCelebrationView.swift`, `App/PregnancyEnding/ConfettiView.swift`.

**Interfaces:** `BirthCelebrationView(recap: PregnancyRecap, playsHaptic: Bool, onClose: () -> Void)`.

- [ ] Tap/Next paging, dots, close on every page, Done on last; Reduce Motion variants; AX scroll; dark mode. Compile check; commit.

### Task 6: Wiring

- [ ] Sheet: `initialBranch`, `onEnded: (PregnancyRecap?) -> Void`, set `pendingCelebration` after dismiss.
- [ ] RootView `fullScreenCover(item:)`; Profile forwards and gets its own card; `BirthPromptCard` on Today after `WeekProgressCard`; replay button in `MemoryDetailView` for birth.
- [ ] Compile check; commit.

### Task 7: UI tests

- [ ] `UITests/BirthCelebrationUITests.swift`: week-38 card, birth, keep, Next through, Done, cycle mode; week-30 no card; loss from Profile no cover. Commit.

### Task 8: Verify, mutate, PR

- [ ] Full `scripts/test-core.sh`, build-for-testing, the two mutations, clean build dirs, push, `gh pr create`.
