# Week sizes by Hadlock weight and fruit artwork (Phase 11) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax. Task 2 also applies the `ui-ux-pro-max` skill.

**Goal:**
- From week 10, the size comparison ("cỡ một quả …") is chosen by the produce's typical **weight**, sourced and within ±25 % of the Hadlock 1991 50th-percentile weight the app shows.
- Every week has its own fruit illustration.

**Architecture:**
- **Content.** `pregnancy-content.json` moves to v4.
  - `weeks[].size` gains `typicalGrams` and `sourceKey`.
  - A new top-level `produceSources` object holds the sources.
  - `ContentValidator` enforces presence, source keys and tolerance.
  - `WeekSizeLine` words the comparison as weight ("nặng cỡ …" / "about as heavy as …") whenever the week has a weight.
- **Artwork.** 39 hand-written SVG imagesets `Fruit-W04…W42`, which the existing `WeekArtwork.fruit(_:)` picks up.
- No other app code changes.

**Tech Stack:** Swift 6, SwiftUI (iOS 17), Swift Testing, XCTest, SVG in the asset catalog.

**Spec:** `docs/superpowers/specs/2026-10-08-week-sizes-design.md`. **Research (the table to use):** `docs/research/2026-10-08-produce-weights.md` and `.json`. **Fetus brief (done):** `docs/design/fetus-artwork-brief.md`.

## Global Constraints

- **Worktree and branch.** Work **only** in the worktree `/Users/macos/Documents/kick-counter-week-sizes` on branch `feat/week-sizes`. Never touch `/Users/macos/Documents/kick-counter`: Phase 10 runs there on another branch.
- **Forbidden edits.** No CI script, workflow or entitlement edits. Never change the `gh` account.
- **KickCore imports.** `KickCore` must not import SwiftUI, UIKit, SwiftData or CloudKit.
- **Strings.**
  - Strings change only through `scripts/add-strings.py`, which takes en + vi; use `--remove` to delete.
  - Vietnamese is northern Vietnamese.
  - Medical copy stays hedged ("khoảng", "cỡ").
- **Local verification.**
  - Run `scripts/test-core.sh` (redirect its output to a file and read the summary), `xcodegen generate --quiet`, and `xcodebuild … -derivedDataPath build/DerivedData … build-for-testing`. The worktree has its own `build/`.
  - Never run UI tests locally. Never open Xcode.
- **Commits.** Every commit message ends with a blank line, then a `CI-Only-Testing: <classes>` line, immediately followed by `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. The branch is pushed with `git push -u origin feat/week-sizes`, then `scripts/ci-wait.sh`.
- **Emoji decisions.** The research JSON is used as is, except for these overrides (the emoji is only the fallback when an image is missing):
  - week 13: 🍋‍🟩 → 🍋, because the lime emoji needs iOS 17.4 and the deployment target is 17.0;
  - weeks 37, 38 and 41 (pumpkin): 🎃 → 🍈, because `noJackOLanternEmoji` forbids the jack-o'-lantern.
- **Repeats.** The research flags are accepted as they stand:
  - weeks 41–42 repeat earlier items;
  - weeks 33–42 use range midpoints;
  - week 32 is durian;
  - week 10 is passion fruit;
  - week 13 is "chanh không hạt";
  - week 21 is corn with husk.

  They are listed for the doctor in Task 1.

## Verification workflow

The same as `docs/superpowers/plans/2026-10-08-cycle-tracking.md` "Verification workflow". The KickCore test count is printed by `scripts/test-core.sh`; record the before and after numbers in the report.

---

### Task 1: Content v4, validator, size line and doctor review

**Files:**
- Modify:
  - `Packages/KickCore/Sources/KickCore/PregnancyContent.swift`: `WeekSize` gains `typicalGrams: Int?` and `sourceKey: String?`; the document gains `produceSources: [String: ProduceSource]`, where `ProduceSource` has `title`, `url` and `note`, all `String`.
  - `Packages/KickCore/Sources/KickCore/ContentValidator.swift`
  - `Packages/KickCore/Sources/KickCore/WeekSizeLine.swift` and its templates in `Shared/L10n.swift` and `Shared/Localizable.xcstrings`
  - `Packages/KickCore/Sources/KickCore/Resources/pregnancy-content.json`
  - `Packages/KickCore/Tests/KickCoreTests/Fixtures/content-fixture.json`
  - `BundledContentTests.swift`, `ContentValidatorTests.swift` and `WeekSizeLineTests.swift`
  - `docs/content-review-for-doctor.md`
  - `README.md`

**Interfaces:**
- **Produces:**
  - `ContentValidator.supportedVersion = 4`;
  - `ContentValidator.comparisonWeeks = 10...42`;
  - `ContentValidator.comparisonTolerance = 0.25`;
  - new `ContentIssue` cases `missingTypicalWeight(week: Int)`, `unknownProduceSource(week: Int, key: String)` and `comparisonOutOfTolerance(week: Int, typicalGrams: Int, referenceGrams: Int)`.

Steps (TDD, tests first):

- [ ] **Step 1: Validator tests** in `ContentValidatorTests`, against fixture variants built in code, the way the existing tests mutate the fixture:
  - a week-10 size without `typicalGrams` raises `missingTypicalWeight(week: 10)`;
  - `typicalGrams` on week 8 raises `unexpectedMeasurement(week: 8, field: "typicalGrams")`;
  - an unknown key raises `unknownProduceSource`;
  - 35 g against 45 g (−22 %) passes, and 30 g against 45 g (−33 %) raises `comparisonOutOfTolerance`;
  - weeks 41 and 42 use their own `weightG`, which already equals week 40;
  - `version` 3 raises `unsupportedVersion(3)`.

  Update `content-fixture.json` to v4 with `typicalGrams`/`sourceKey` for its weeks ≥ 10 and a `produceSources` entry.
- [ ] **Step 2: Bundled tests** in `BundledContentTests`:
  - Replace `sizeComparisonsAreDistinct` with `noComparisonRunsLongerThanTwoWeeks`: no `size.en` appears in three consecutive weeks.
  - In `sizeEmojiDepictsTheItem`, delete the `unsupported` names loop (pumpkin, pomelo and lime are allowed now that there is artwork). Add rules `("pumpkin", ["🍈"])` and `("lime", ["🍋"])`.
  - Add `everyComparisonFromWeek10IsWithinTolerance`: for each week ≥ 10, |typicalGrams − weightG| / weightG ≤ 0.25.
  - Add `everyComparisonCitesASource`: every `sourceKey` exists, and every source has a non-empty title and an `https` URL.
  - Add `comparisonsMatchTheResearchTable`: the week 10, 20, 31 and 40 rows equal the research JSON values, i.e. passion fruit 35, Asian pear 302, pineapple 1775 and watermelon 3500.
- [ ] **Step 3: Size line test** (`WeekSizeLineTests`).

  When the week has a weight, the fruit clause becomes a weight comparison. Week 12:
  - vi: "Bé dài khoảng 53,5 mm (từ đầu đến mông) và nặng khoảng 58 g, nặng cỡ một quả mận."
  - en: "Your baby is about 53.5 mm long from head to bottom and weighs about 58 g, about as heavy as a plum."

  Add the equivalent check for week 24's weight-and-range template, matching that template's current shape. Length-only weeks (7–9) keep "cỡ …" / "roughly the size of …".

  Look at the current templates in `WeekSizeLine.swift` and `L10n`. Change only the fruit clause, by editing the existing keys' values with `add-strings.py` (remove, then add).
- [ ] **Step 4:** Run the tests and watch them fail. Then implement the model, the validator and the template change.
- [ ] **Step 5: JSON.**
  - Set `version` to 4.
  - Copy `produceSources` from the research JSON.
  - For each week 10–42, set `size.emoji/en/vi/typicalGrams/sourceKey` from the research rows, applying the emoji overrides.
  - Weeks 4–9 stay unchanged.

  Use a small Python script, and check that `git diff` touches only `size` blocks, `version` and `produceSources`.
- [ ] **Step 6:** Run `scripts/test-core.sh`; all tests must pass. Fix any other test that pinned an old item; `grep -rn "kiwi\|knob of ginger\|củ gừng" Packages UITests` should list none outside the history. Then run `build-for-testing`.
- [ ] **Step 7: Docs.**
  - **`content-review-for-doctor.md`:** add a new section, "So sánh kích thước theo cân nặng (giai đoạn 11)". It should hold:
    - the full table: week, Hadlock g, the vi item, typical g, deviation %;
    - the accepted research flags;
    - the new sentence wording ("nặng cỡ …");
    - a pointer to `docs/design/fetus-artwork-brief.md` §5 (fetus checklist).

    Number its items after the current last number.
  - **README:** add a "Kích thước theo tuần (giai đoạn 11)" section, 3–5 lines, that links the research and the fetus brief.
- [ ] **Step 8:** Commit, push and run `ci-wait`.

```bash
git add -A Packages Shared docs README.md
git commit -F - <<'MSG'
feat(content): compare the baby's weight with sourced produce weights

CI-Only-Testing: PregnancyUITests WeekArticleSheetUITests PregnancyTodayUITests
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push -u origin feat/week-sizes
scripts/ci-wait.sh
```

---

### Task 2: 39 fruit illustrations

**Files:** Create `App/Images.xcassets/Fruit-W04.imageset` … `Fruit-W42.imageset`. Each holds one `.svg` and a `Contents.json`:

```json
{ "images" : [ { "filename" : "Fruit-W12.svg", "idiom" : "universal" } ],
  "info" : { "author" : "xcode", "version" : 1 },
  "properties" : { "preserves-vector-representation" : true } }
```

Steps:

- [ ] **Step 1: Item list.** Draw one SVG per **distinct item**: weeks 4–9 use their current comparisons (poppy seed … grape), and weeks 10–42 use the Task 1 items. Copy the file to each week that uses the same item, renamed per week.
- [ ] **Step 2: Style** (spec §4).
  - Canvas `viewBox="0 0 240 240"`, transparent, with at least 16 units of padding.
  - Flat shapes in 2–4 tones per object, and a darker edge tone on every silhouette so it reads on both the light and the dark card.
  - Soft shadow as a flat ellipse at low opacity.
  - No filters, gradients only as plain `linearGradient`/`radialGradient` (no masks), no text, and no external references.
  - Palette: natural produce colours harmonised with the Mầm palette (`docs/design/mam-handoff`, `App/DesignSystem/LunaPalette.swift`).
  - Recognisable at 60 pt. For tiny items (poppy seed, sesame seed), draw the item large; the text gives the scale.
  - Every file must be valid XML and under 12 KB.
- [ ] **Step 3: Review page.** Write `/private/tmp/claude-501/-Users-macos-Documents-kick-counter/a0f7485e-07d6-4f94-b15a-56704d72c972/scratchpad/fruit-review.html`. It shows a grid of all 39 weeks (week number, vi name, image) twice: on the light `pregSoft`/`card` colours and on the dark ones. Show each at 120 px and 60 px, and inline the SVGs.

  **Stop here and report** to the controller with the file path. The controller shows it to the user, and nothing goes into the asset catalog until the user approves.
- [ ] **Step 4 (after approval): Asset catalog.**
  - Add the imagesets and run `xcodegen generate --quiet` and `build-for-testing`.
  - Add `WeekArticleScreenshotTests` coverage, if missing, for weeks 12, 24 and 38: open the week article and attach `week-article-fruit-<week>-vi-light` and `…-vi-dark` screenshots.
  - Commit with `CI-Only-Testing: WeekArticleScreenshotTests`, then push and run `ci-wait`.
  - Read the screenshots: the illustration must replace the emoji, sit centred and read in both modes.

## Self-review

- **Spec coverage:**
  - §3 data and the validator → Task 1;
  - §4 artwork with its review gate → Task 2;
  - §5 brief → already committed (a9d92f3), with the README link added in Task 1 Step 7;
  - §6 research → committed (f65d5ac).
- **Deviation:** the size sentence wording changes to a weight comparison. It follows from the user's decision and is listed for the doctor.
