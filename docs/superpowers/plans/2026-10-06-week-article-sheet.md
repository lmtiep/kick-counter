# Week article sheet and weekly articles (Phase 6) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. For the UI tasks (2–3) also apply the `ui-ux-pro-max` skill to review visual detail, but do **not** change behaviour, accessibility identifiers, strings or colour tokens fixed by this plan. Tasks 4–6 write prose, not code: follow the writing guide and fact checklists in each task exactly.

**Goal:** Turn Week detail into a fixed background (fetus image + week chips) under a draggable two-detent article sheet with Bé / Mẹ tabs, and give every week 4–42 an original vi + en article whose size sentence is generated from the Hadlock data.

**Architecture:** Everything testable lives in `KickCore` (pure Swift, tested locally): the article data model (`WeekArticle`, `LocalizedParagraphs`, an optional `article` on `WeekContent`, JSON version 3), the generated size sentence (`WeekSizeLine`, fed localized format strings and number formatters by the app), the sheet's release logic (`SheetDetentResolver`), the per-week artwork asset names (`WeekArtworkName`) and the content checks (`WeekArticleChecks`, plus bundle tests whose completeness requirement widens with each content batch). The app adds a generic in-view sheet (`App/DesignSystem/ArticleSheet.swift`), the tab content (`App/Pregnancy/WeekArticleView.swift`), asset fallbacks (`App/Pregnancy/WeekArtwork.swift`) and rebuilds `WeekDetailView` on top of them. Content is written in three batches through `scripts/set-week-articles.py`.

**Tech Stack:** Swift 6, SwiftUI (iOS 17), Swift Testing (KickCore), XCTest (UI), XcodeGen, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-06-week-article-sheet-design.md` (the requirements; build exactly what it says). Previous plan for conventions: `docs/superpowers/plans/2026-10-05-symptoms-weight.md`.

## Global Constraints

- Swift language mode 6 with strict concurrency; iOS deployment target `17.0`; package platforms `.iOS(.v17), .macOS(.v14)`. No third-party SDKs, no server, no data collection.
- Work on branch `feat/week-article-sheet` (already checked out). **Never** change the `gh` account or log in. Every commit message ends with a blank line, then the trailer block: `CI-Only-Testing: <UI test classes>` on its own line, immediately followed by `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (no blank line between them). Use `git commit -F - <<'MSG' … MSG` exactly as shown in each task. The only exception is Task 7, whose commit deliberately has **no** `CI-Only-Testing:` line so CI runs the full UI suite (spec §6, "The final review runs the full suite").
- **`KickCore` must not import SwiftUI, UIKit or SwiftData.** `WeekSizeLine` receives its localized templates and number formatters from the app, so `KickCore` stays free of `L10n` and `Formatting`.
- Every UI string goes through `L10n` (`Shared/L10n.swift`) and lives in `Shared/Localizable.xcstrings` with both `en` and `vi`. Strings are added or removed **only** with `scripts/add-strings.py` (JSON `{"key": ["English", "Tiếng Việt"]}` on stdin; `--remove key …`). Never `Text("…")` with a literal or interpolation: use `Text(L10n.…)`, `Text(someString)` for content, or `Text(verbatim:)` for symbols and previews.
- Colours come only from Luna tokens: `.luna(.<token>)` (`App/DesignSystem/LunaColor.swift`, values in `KickCore/LunaPalette.swift`). No hex in views. Every text/background pair must be declared in `LunaContrast.usages`; `ContrastTests` must stay green. Pairs used in this phase (all already declared): `textPrimary` on `card`, `articleText` on `card`, `textSecondary` on `card`, `textPrimary` on `segmentSelected`, `warningText`/`articleText` on `warningBackground`, `pregOnSoft` on `heroMiddle` (chips), `articleText` on `surface` (reviewer icon).
- Fonts: only `Font.luna(_:)` / `Font.luna(size:weight:relativeTo:)` (Dynamic Type). The one exception already in the codebase is the size emoji, drawn with `.system(size: 64)`.
- Animation is gated by `LunaMotion.isEnabled` (false under `-uiTesting`) **and** Reduce Motion (`@Environment(\.accessibilityReduceMotion)`). With either off, the sheet jumps between detents, the week content swaps instantly and the background only changes opacity (no scale).
- **Local verification only:** implementers run `scripts/test-core.sh`, `xcodegen generate --quiet` and `xcodebuild … build-for-testing` on the "iPhone 18 Pro" simulator (exact command below). They **never** run UI tests locally; UI tests and screenshots run on CI (`git push` + `scripts/ci-wait.sh`).
- Lessons from CI (mandatory):
  - SwiftUI `List` / `Form` / lazy rows only exist once scrolled near the viewport: UI tests call `app.scrollUntilHittable(element)` before asserting or tapping. Wait with `waitForExistence` / `waitForLabel`, never a fixed `sleep`.
  - Put `.accessibilityElement(children: .combine)` **before** `.accessibilityIdentifier(…)`, or the identifier lands on a child.
  - Don't scroll elements that sit under sticky insets (the sheet's handle, title and tabs are fixed above the scrolling article; tap them directly, never scroll to them).
- Keep every accessibility identifier the existing tests use: `weekDetailClose`, `weekDetailTitle`, `weekChip-N`, `weekReviewer`, `weekWarnings`, `fetusHeroButton`, `babySizeCard`, `symptomSafetyAction`. New: `weekSheetHandle`, `weekTab-baby`, `weekTab-mom`, `weekArticleScroll`, `weekArticleLead`, `weekSizeLine`, `weekReferences`.
- Content stays `"reviewed": false` for every week. Release builds keep hiding unreviewed weeks (`BuildFlags.contentVisibility`, unchanged). No "Người xem xét"/doctor name is shown.
- Out of scope (spec §2): bookmarks, a "Reviewed by" doctor name, the artwork itself, trimester/"Thông tin chuyên sâu" articles, any change to Today.

## Verification workflow

- **Local, every task with code:**
  ```bash
  scripts/test-core.sh
  xcodegen generate --quiet
  xcodebuild -project KickCounter.xcodeproj -scheme KickCounter \
    -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
    -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO -quiet build-for-testing
  ```
  `xcodebuild` must exit 0 with no `<file>.swift:<line>:<col>: error:` lines (a bare "error: the following command failed with exit code 0" line on a first build is harmless). Do not run `xcodebuild test`. KickCore test count after each task: 396 (before) → 430 (Task 1) → 431 (Task 3); Tasks 2, 4, 5, 6, 7 keep 431.
- **CI** (the done condition of **every** task): commit with the task's `CI-Only-Testing:` line, `git push`, then `scripts/ci-wait.sh`. The log prints `==> UI tests: scoped to …` when the trailer applies. Screenshots land in `ci-artifacts/screenshots/<name>_0_<UUID>.png`.
- **Known flake:** a UI test occasionally times out in `waitForExistence` in an unrelated test. If CI is red **only** for that reason, rerun the failed jobs **once**:
  ```bash
  RUN_ID="$(gh run list --workflow ci.yml --commit "$(git rev-parse HEAD)" --limit 1 --json databaseId -q '.[0].databaseId')"
  gh run rerun "$RUN_ID" --failed
  gh run watch "$RUN_ID" --exit-status --interval 20 > /dev/null && echo "CI PASSED"
  rm -rf ci-artifacts && gh run download "$RUN_ID" --dir ci-artifacts
  ```
  Red again, or a failure in the task's own tests → use `superpowers:systematic-debugging`, fix, commit (keep the task's `CI-Only-Testing:` line), push again.
- **Visual check** (UI and content tasks): open every listed PNG with the **Read tool** and check each item of the task's list. One failed item means the task is not done.
- Never mark a task complete while CI is red. Use `superpowers:verification-before-completion` before claiming a task is done.

## Spec clarifications (decisions made while planning)

| # | Spec point | Decision |
|---|---|---|
| 1 | §3.2 ✕ button vs §3.4 expanded top (8 pt below the safe area) | The ✕ button floats above the sheet (last in the `ZStack`) at the top left. When expanded, it sits over the left end of the sheet's 44 pt handle row; the handle capsule is centred, so nothing overlaps visually. |
| 2 | §3.3 title | The sheet title is `L10n.weekTitle(N)` ("Tuần 24") with the existing identifier `weekDetailTitle`. The old top-bar title and the panel headline `weekHeadline` ("What happens at N weeks") are removed; the two UI tests that used `weekHeadline` now use `weekDetailTitle`. |
| 3 | §4.2 `WeekSizeLine.make(for:language:)` and `Formatting` | `Formatting` lives in the app, not KickCore. The KickCore signature is `make(for:language:templates:numbers:)`: templates are the `L10n` format strings, numbers are closures over `Formatting`. The app calls it twice: display numbers, then spoken numbers for `accessibilityLabel`. |
| 4 | §4.2 range wording "thường từ {p10} đến {p90}" | `{p10}` is the bare number (`Formatting.weightRangeStart`), `{p90}` carries the unit (`Formatting.weightInUnit`): "thường từ 556 đến 784 g", "typically 1.5 to 2.0 kg". |
| 5 | §4.2 weeks 41–42 | The line is built from the week's own data (which repeats week 40's figures) and its own fruit; the "Hadlock's standard ends at week 40" note shows in the footnote above the estimate note, as on Today. |
| 6 | §4.3 fallback | When `article` is nil, the Bé tab still shows the artwork row and the "Bé lớn cỡ nào?" section (generated line + footnote), then the `baby` bullets; the Mẹ tab shows `mom`, `tips`, then the warnings. References list all sources. |
| 7 | §4.3 references | With an article: the strings at `article.sources`. Without: every `PregnancyContent.sources` entry. |
| 8 | §3.5 scroll reset | The article scrolls to the top when the week **or** the tab changes (a new tab is new content). |
| 9 | §3.5 Reduce Motion | `LunaMotion.sheet(reduceMotion:)` returns the spring only when motion is enabled and Reduce Motion is off; otherwise nil (a jump). The week cross-fade uses `LunaMotion.fade` under the same rule. |
| 10 | §3.4 peek before measurement / small screens | Peek top = chips `maxY` + 12, or 55 % of the height before the chips are measured, capped at `height − 220` so the handle, title and tabs stay visible. |
| 11 | §3.3 accessibility at expanded | The background (fetus, chips) is `accessibilityHidden` while expanded, so VoiceOver does not reach controls under the sheet. |
| 12 | §4.5 "every week 4–42 has an article" vs "content tests start pending" | `WeekArticleChecks.validate(_:requiredWeeks:)` reports missing articles only inside `requiredWeeks`. `BundledArticleTests.requiredArticleWeeks` is `nil` until Task 4, then `4...13`, `4...27`, and finally `WeeklyContentLibrary.weekRange` in Task 6. Every article that exists is always fully checked. |
| 13 | §4.4 word counts | Words = whitespace-separated tokens (`split(whereSeparator: \.isWhitespace)`), i.e. syllables in Vietnamese. Bé tab = lead + `sizeNote` + `development`; Mẹ tab = `body` + `todo`. The generated size line and the warnings are not counted. |
| 14 | §7 "placeholder articles for a few weeks" | A placeholder must already pass the checks (they validate every existing article), so Task 3 inserts **one** fully written article, week 24, which every UI test and screenshot uses. It is the example article in Tasks 4–6, and Task 5 re-reviews it with weeks 14–27. Week 25 shows the bullet fallback in Task 3's screenshots until Task 5 writes it. |
| 15 | §4.4 "no medicine names" | Supplements already named in the reviewed bullets (folic acid / axit folic, iron / sắt) may be named **without** doses, always "as your doctor or midwife advises". Vaccines are named by disease ("uốn ván, ho gà") as the milestones do. No product names, no doses (a bundle test rejects `mg`, `mcg`, `µg`, `IU`). |
| 16 | §4.2 numbers | `sizeNote` never states a measurement (no g, kg, mm, cm figures): the generated line owns the numbers. Weeks 4–6 describe size in words. |
| 17 | §4.6 "§2 Hadlock data" | The Hadlock item in `docs/content-review-for-doctor.md` is item 21 (in §3); §9 refers to it. |
| 18 | §6 CI scoping | Task 2 changes no screen, so its trailer names `PregnancyTodayUITests` as a smoke run. Task 7 has no trailer (full suite). |
| 19 | extra checks | Beyond spec §4.5, `BundledArticleTests` also checks dose units, Vietnamese diacritics, and that each article cites the Hadlock paper behind its size line plus at least one guideline body. |

## File Structure

```
kick-counter/
├── Packages/KickCore/
│   ├── Sources/KickCore/
│   │   ├── PregnancyContent.swift              # T1: LocalizedParagraphs, WeekArticle, WeekContent.article
│   │   ├── WeekArtworkName.swift               # T1 (new): "Fetus-W%02d" / "Fruit-W%02d"
│   │   ├── WeekSizeLine.swift                  # T1 (new): Templates, Numbers, make(for:language:templates:numbers:)
│   │   ├── SheetDetentResolver.swift           # T1 (new): SheetDetent, SheetDetentResolver
│   │   ├── WeekArticleChecks.swift             # T1 (new): ArticleTab, ArticleIssue, WeekArticleChecks
│   │   ├── ContentValidator.swift              # T1: supportedVersion = 3
│   │   └── Resources/pregnancy-content.json    # T1 version 3; T3 week 24; T4–T6 weeks 4–42
│   └── Tests/KickCoreTests/
│       ├── WeekArticleTests.swift              # T1 (new)
│       ├── WeekSizeLineTests.swift             # T1 (new)
│       ├── SheetDetentResolverTests.swift      # T1 (new)
│       ├── WeekArticleChecksTests.swift        # T1 (new)
│       ├── BundledArticleTests.swift           # T1 (new); T3 +1 test; T4–T6 widen requiredArticleWeeks
│       └── Fixtures/content-fixture.json       # T1: version 3
├── scripts/set-week-articles.py                # T1 (new): writes `article` blocks into the JSON, prints word counts
├── Shared/{L10n.swift, Localizable.xcstrings}  # T3
├── App/
│   ├── DesignSystem/Motion.swift               # T2: LunaMotion.sheetSpring, sheet(reduceMotion:)
│   ├── DesignSystem/ArticleSheet.swift         # T2 (new): generic two-detent sheet
│   ├── Pregnancy/WeekArtwork.swift             # T3 (new): asset lookup with fallbacks
│   ├── Pregnancy/WeekArticleView.swift         # T3 (new): Bé / Mẹ content, size line, references, fallback
│   └── Pregnancy/WeekDetailView.swift          # T3: rebuilt (background + ArticleSheet)
├── UITests/
│   ├── WeekArticleSheetUITests.swift           # T3 (new)
│   ├── WeekArticleScreenshotTests.swift        # T3 (new)
│   ├── PregnancyTodayUITests.swift             # T3: weekHeadline → weekDetailTitle
│   └── PregnancyScreenshotTests.swift          # T3: week-12 waits for the size line; week-24 shots move
├── README.md                                   # T7
└── docs/{content-review-for-doctor.md, release-checklist.md}   # T7
```

---
### Task 1: KickCore — article model, size line, detent resolver, content checks

Adds the version-3 data model (spec §4.1), the generated size sentence (§4.2), the pure sheet release logic (§3.5), per-week artwork names (§3.2, §4.3), and the content checks (§4.5) with a completeness requirement that is off until the content tasks widen it. Bumps `pregnancy-content.json` and the test fixture to version 3 and adds `scripts/set-week-articles.py` for the content tasks. No UI uses any of it yet; the app still compiles because `article` is optional.

**Files:**
- Create: `Packages/KickCore/Sources/KickCore/WeekArtworkName.swift`, `WeekSizeLine.swift`, `SheetDetentResolver.swift`, `WeekArticleChecks.swift` (all in `Packages/KickCore/Sources/KickCore/`)
- Create (tests): `Packages/KickCore/Tests/KickCoreTests/WeekArticleTests.swift`, `WeekSizeLineTests.swift`, `SheetDetentResolverTests.swift`, `WeekArticleChecksTests.swift`, `BundledArticleTests.swift`
- Create: `scripts/set-week-articles.py`
- Modify: `Packages/KickCore/Sources/KickCore/PregnancyContent.swift` (after `LocalizedList`; `WeekContent`), `Packages/KickCore/Sources/KickCore/ContentValidator.swift:609-610`, `Packages/KickCore/Sources/KickCore/Resources/pregnancy-content.json` (`"version"`), `Packages/KickCore/Tests/KickCoreTests/Fixtures/content-fixture.json` (`"version"`)

**Interfaces:**
- Consumes (existing): `ContentLanguage` (`.en`, `.vi`, `CaseIterable`), `LocalizedText` (`en`, `vi`, `text(_:)`), `FruitSize.name(_:)`, `WeekContent` (`week`, `size`, `crlMm: Double?`, `weightG/weightP10G/weightP90G: Int?`, `weightBeyondStandard`), `PregnancyContent` (`version`, `sources: [String]`, `weeks`), `WeeklyContentLibrary.bundled()`, `WeeklyContentLibrary.weekRange` (`4...42`), `fixtureContent()` in `TestSupport.swift` (weeks 7–11, 2 sources).
- Produces (later tasks use exactly these):
  - `public struct LocalizedParagraphs: Codable, Equatable, Sendable { public var en: [String]; public var vi: [String]; public init(en:vi:); public func paragraphs(_ language: ContentLanguage) -> [String] }`
  - `public struct WeekArticle: Codable, Equatable, Sendable { lead: LocalizedText; sizeNote, development, body, todo: LocalizedParagraphs; sources: [Int] }` (all `public var`), internal `paragraphFields: [(name: String, paragraphs: LocalizedParagraphs)]` and `texts(_ language:) -> [(field: String, text: String)]`.
  - `WeekContent.article: WeekArticle?` (absent in JSON → nil; nil is not encoded).
  - `public enum WeekArtworkName { static func fetus(week: Int) -> String; static func fruit(week: Int) -> String }` → `"Fetus-W04"`, `"Fruit-W31"`.
  - `public enum WeekSizeLine` with `public struct Templates: Sendable { length, lengthAndWeight, weightAndRange: String; init(length:lengthAndWeight:weightAndRange:) }`, `public struct Numbers: Sendable { length: @Sendable (Double) -> String; weight: @Sendable (Int) -> String; rangeLow: @Sendable (Int, Int) -> String; rangeHigh: @Sendable (Int, Int) -> String; init(length:weight:rangeLow:rangeHigh:) }` and `public static func make(for week: WeekContent, language: ContentLanguage, templates: Templates, numbers: Numbers) -> String?`.
  - `public enum SheetDetent: Sendable, Equatable, CaseIterable { case peek, expanded }`.
  - `public struct SheetDetentResolver: Sendable, Equatable` — `init(peekOffset: Double, expandedOffset: Double)`, `peekOffset`, `expandedOffset`, `span`, `offset(for:) -> Double`, `dragOffset(from:translation:) -> Double`, `progress(atOffset:) -> Double`, `progress(for:) -> Double`, `release(at offset: Double, velocity: Double) -> SheetDetent`; statics `flickSpeed = 600`, `rubberBandFactor = 0.25`, `rubberBandLimit = 30`.
  - `public enum ArticleTab: String, Sendable, CaseIterable, Hashable { case baby, mom }` (the app's tab selection uses it too).
  - `public enum ArticleIssue: Equatable, Sendable` (cases below) and `public enum WeekArticleChecks` — `leadLimit: [ContentLanguage: Int]` (`.en: 30, .vi: 40`), `tabWords: ClosedRange<Int>` (`150...300`), `validate(_:requiredWeeks:) -> [ArticleIssue]`, `wordCount(_:) -> Int`, `tabWordCount(_:tab:language:) -> Int`, `containsImperialUnit(_:) -> Bool`.
  - `BundledArticleTests.requiredArticleWeeks: ClosedRange<Int>?` (nil now).
  - `scripts/set-week-articles.py`: JSON `{"<week>": <article>}` on stdin → writes `article` into those weeks, prints `week N en: lead L, baby B, mom M` lines.
  - `ContentValidator.supportedVersion == 3`.

- [ ] **Step 1: Write the failing model test**

`Packages/KickCore/Tests/KickCoreTests/WeekArticleTests.swift` (whole file):
```swift
import Foundation
import Testing
@testable import KickCore

/// Phase 6 spec §4.1: version-3 articles next to every existing field.
struct WeekArticleTests {
    @Test func version2FileDecodesWithoutArticles() throws {
        let json = """
        {"version": 2, "sources": ["S"], "milestones": [], "weeks": [{
          "week": 7, "reviewed": false,
          "size": {"emoji": "🫐", "en": "a blueberry", "vi": "một quả việt quất"},
          "crlMm": 9.6,
          "baby": {"en": ["a", "b"], "vi": ["a", "b"]}, "mom": {"en": ["a", "b"], "vi": ["a", "b"]},
          "tips": {"en": ["a", "b"], "vi": ["a", "b"]}, "warnings": {"en": ["a"], "vi": ["a"]}
        }]}
        """
        let content = try JSONDecoder().decode(PregnancyContent.self, from: Data(json.utf8))
        #expect(content.weeks[0].article == nil)
        #expect(content.weeks[0].crlMm == 9.6)
        #expect(content.weeks[0].baby.items(.vi) == ["a", "b"])
    }

    @Test func articleDecodesAndPicksTheLanguage() throws {
        let json = """
        {"lead": {"en": "Lead.", "vi": "Mở đầu."},
         "sizeNote": {"en": ["Size."], "vi": ["Kích thước."]},
         "development": {"en": ["One.", "Two."], "vi": ["Một.", "Hai."]},
         "body": {"en": ["Body."], "vi": ["Cơ thể."]},
         "todo": {"en": ["Do."], "vi": ["Làm."]},
         "sources": [0, 2]}
        """
        let article = try JSONDecoder().decode(WeekArticle.self, from: Data(json.utf8))
        #expect(article.lead.text(.vi) == "Mở đầu.")
        #expect(article.development.paragraphs(.en) == ["One.", "Two."])
        #expect(article.development.paragraphs(.vi) == ["Một.", "Hai."])
        #expect(article.sources == [0, 2])
        #expect(article.paragraphFields.map { $0.name } == ["sizeNote", "development", "body", "todo"])
        #expect(article.texts(.en).map { $0.field } == ["lead", "sizeNote", "development", "development", "body", "todo"])
    }

    @Test func weekWithoutArticleEncodesNoArticleKey() throws {
        let week = try #require(try fixtureContent().weeks.first)
        let text = String(decoding: try JSONEncoder().encode(week), as: UTF8.self)
        #expect(!text.contains("\"article\""))
    }

    @Test func artworkNamesUseTwoDigitWeeks() {
        #expect(WeekArtworkName.fetus(week: 4) == "Fetus-W04")
        #expect(WeekArtworkName.fetus(week: 31) == "Fetus-W31")
        #expect(WeekArtworkName.fruit(week: 9) == "Fruit-W09")
        #expect(WeekArtworkName.fruit(week: 42) == "Fruit-W42")
    }
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `scripts/test-core.sh --filter WeekArticleTests`
Expected: build FAILS with `cannot find 'WeekArticle' in scope` and `cannot find 'WeekArtworkName' in scope`.

- [ ] **Step 3: Add the model and the artwork names**

In `Packages/KickCore/Sources/KickCore/PregnancyContent.swift`, replace:
```swift
/// "Your baby is about the size of …", illustrated by an emoji (no images).
```
with:
```swift
/// Paragraphs of a week article, one array per language (phase 6 spec §4.1).
public struct LocalizedParagraphs: Codable, Equatable, Sendable {
    public var en: [String]
    public var vi: [String]

    public init(en: [String], vi: [String]) {
        self.en = en
        self.vi = vi
    }

    public func paragraphs(_ language: ContentLanguage) -> [String] {
        language == .vi ? vi : en
    }
}

/// A week's article (phase 6 spec §4.1). The Bé tab is `lead`, the generated
/// size line, `sizeNote` and `development`; the Mẹ tab is `body`, `todo` and
/// the week's `warnings`. Checked by `WeekArticleChecks`.
public struct WeekArticle: Codable, Equatable, Sendable {
    /// Bold opening of the Bé tab: at most 30 words (en) / 40 (vi).
    public var lead: LocalizedText
    /// "Bé lớn cỡ nào?", shown after the generated `WeekSizeLine`. No figures.
    public var sizeNote: LocalizedParagraphs
    /// "Bé phát triển ra sao": 2–3 paragraphs.
    public var development: LocalizedParagraphs
    /// Mẹ tab, "Cơ thể mẹ tuần này": 1–3 paragraphs.
    public var body: LocalizedParagraphs
    /// Mẹ tab, "Mẹ nên làm gì": 1–2 paragraphs.
    public var todo: LocalizedParagraphs
    /// Indices into `PregnancyContent.sources` (append-only, never reordered); at least one.
    public var sources: [Int]

    /// The paragraph fields by their JSON name, in reading order.
    var paragraphFields: [(name: String, paragraphs: LocalizedParagraphs)] {
        [
            (name: "sizeNote", paragraphs: sizeNote),
            (name: "development", paragraphs: development),
            (name: "body", paragraphs: body),
            (name: "todo", paragraphs: todo),
        ]
    }

    /// Every text of one language with its field name: the lead, then each paragraph.
    func texts(_ language: ContentLanguage) -> [(field: String, text: String)] {
        var result: [(field: String, text: String)] = [(field: "lead", text: lead.text(language))]
        for field in paragraphFields {
            for paragraph in field.paragraphs.paragraphs(language) {
                result.append((field: field.name, text: paragraph))
            }
        }
        return result
    }
}

/// "Your baby is about the size of …", illustrated by an emoji (no images).
```

In the same file, replace:
```swift
    /// "When to get care right away" — every item points to a doctor or maternity unit.
    public var warnings: LocalizedList

    public var id: Int { week }
```
with:
```swift
    /// "When to get care right away" — every item points to a doctor or maternity unit.
    public var warnings: LocalizedList
    /// The week's article (version 3); nil in a version-2 file or a week not yet written,
    /// in which case the week detail shows the bullet lists above.
    public var article: WeekArticle?

    public var id: Int { week }
```

`Packages/KickCore/Sources/KickCore/WeekArtworkName.swift` (whole file):
```swift
import Foundation

/// Asset names of the per-week artwork (phase 6 spec §3.2, §4.3). The app falls
/// back to the shared `Fetus` image and the size emoji while an asset is missing.
public enum WeekArtworkName {
    /// "Fetus-W04" … "Fetus-W42".
    public static func fetus(week: Int) -> String { "Fetus-W" + twoDigits(week) }

    /// "Fruit-W04" … "Fruit-W42".
    public static func fruit(week: Int) -> String { "Fruit-W" + twoDigits(week) }

    private static func twoDigits(_ week: Int) -> String {
        week < 10 ? "0\(week)" : "\(week)"
    }
}
```

- [ ] **Step 4: Run it to see it pass**

Run: `scripts/test-core.sh --filter WeekArticleTests`
Expected: PASS, 4 tests.

- [ ] **Step 5: Write the failing size-line test**

`Packages/KickCore/Tests/KickCoreTests/WeekSizeLineTests.swift` (whole file):
```swift
import Foundation
import Testing
@testable import KickCore

/// Phase 6 spec §4.2: the generated "Bé lớn cỡ nào?" sentence, with the app's
/// templates (`weekArticle.size.*` in Localizable.xcstrings) and number formats.
struct WeekSizeLineTests {
    static let en = WeekSizeLine.Templates(
        length: "Your baby is about %1$@ long from head to bottom, roughly the size of %2$@.",
        lengthAndWeight: "Your baby is about %1$@ long from head to bottom and weighs about %2$@, roughly the size of %3$@.",
        weightAndRange: "Your baby weighs about %1$@ (typically %2$@ to %3$@), roughly the size of %4$@."
    )
    static let vi = WeekSizeLine.Templates(
        length: "Bé dài khoảng %1$@ (từ đầu đến mông), cỡ %2$@.",
        lengthAndWeight: "Bé dài khoảng %1$@ (từ đầu đến mông) và nặng khoảng %2$@, cỡ %3$@.",
        weightAndRange: "Bé nặng khoảng %1$@ (thường từ %2$@ đến %3$@), cỡ %4$@."
    )

    static func decimal(_ value: Double, comma: Bool) -> String {
        let text = String(format: "%.1f", value)
        return comma ? text.replacingOccurrences(of: ".", with: ",") : text
    }

    /// Like the app's `Formatting`: at most one decimal for mm, kilograms with one
    /// decimal from 1,000 g, a decimal comma in Vietnamese, the range's unit once.
    static func numbers(comma: Bool, grams: String = "g", kilograms: String = "kg", millimeters: String = "mm") -> WeekSizeLine.Numbers {
        WeekSizeLine.Numbers(
            length: { mm in
                mm == mm.rounded() ? "\(Int(mm)) \(millimeters)" : "\(decimal(mm, comma: comma)) \(millimeters)"
            },
            weight: { g in
                g >= 1000 ? "\(decimal(Double(g) / 1000, comma: comma)) \(kilograms)" : "\(g) \(grams)"
            },
            rangeLow: { g, reference in
                reference >= 1000 ? decimal(Double(g) / 1000, comma: comma) : "\(g)"
            },
            rangeHigh: { g, reference in
                reference >= 1000 ? "\(decimal(Double(g) / 1000, comma: comma)) \(kilograms)" : "\(g) \(grams)"
            }
        )
    }

    let library: WeeklyContentLibrary

    init() throws {
        library = try WeeklyContentLibrary.bundled()
    }

    private func line(_ week: Int, _ language: ContentLanguage) throws -> String? {
        let content = try #require(library.content(forWeek: week))
        return WeekSizeLine.make(
            for: content,
            language: language,
            templates: language == .vi ? Self.vi : Self.en,
            numbers: Self.numbers(comma: language == .vi)
        )
    }

    @Test func weeks4To6HaveNoLine() throws {
        for week in 4...6 {
            #expect(try line(week, .vi) == nil, "week \(week)")
            #expect(try line(week, .en) == nil, "week \(week)")
        }
    }

    @Test func week8GivesTheCrownRumpLength() throws {
        #expect(try line(8, .vi) == "Bé dài khoảng 16 mm (từ đầu đến mông), cỡ một quả anh đào.")
        #expect(try line(8, .en) == "Your baby is about 16 mm long from head to bottom, roughly the size of a cherry.")
    }

    @Test func week12GivesLengthAndWeight() throws {
        #expect(try line(12, .vi) == "Bé dài khoảng 53,5 mm (từ đầu đến mông) và nặng khoảng 58 g, cỡ một quả kiwi.")
        #expect(try line(12, .en) == "Your baby is about 53.5 mm long from head to bottom and weighs about 58 g, roughly the size of a kiwi.")
    }

    @Test func week31GivesWeightAndRangeInKilograms() throws {
        #expect(try line(31, .vi) == "Bé nặng khoảng 1,8 kg (thường từ 1,5 đến 2,0 kg), cỡ một quả dưa lưới.")
        #expect(try line(31, .en) == "Your baby weighs about 1.8 kg (typically 1.5 to 2.0 kg), roughly the size of a cantaloupe.")
    }

    @Test func week40() throws {
        #expect(try line(40, .vi) == "Bé nặng khoảng 3,6 kg (thường từ 3,0 đến 4,2 kg), cỡ một quả dưa hấu vừa.")
        #expect(try line(40, .en) == "Your baby weighs about 3.6 kg (typically 3.0 to 4.2 kg), roughly the size of a medium watermelon.")
    }

    @Test func week42RepeatsWeek40sFiguresWithItsOwnComparison() throws {
        #expect(try line(42, .vi) == "Bé nặng khoảng 3,6 kg (thường từ 3,0 đến 4,2 kg), cỡ một quả dưa hấu to.")
        #expect(try line(42, .en) == "Your baby weighs about 3.6 kg (typically 3.0 to 4.2 kg), roughly the size of a large watermelon.")
        #expect(library.content(forWeek: 42)?.weightBeyondStandard == true)
    }

    /// VoiceOver reads the same sentence with the units spelled out.
    @Test func spokenNumbersAreUsedAsGiven() throws {
        let content = try #require(library.content(forWeek: 24))
        let spoken = WeekSizeLine.make(
            for: content,
            language: .en,
            templates: Self.en,
            numbers: Self.numbers(comma: false, grams: "grams", kilograms: "kilograms", millimeters: "millimeters")
        )
        #expect(spoken == "Your baby weighs about 670 grams (typically 556 to 784 grams), roughly the size of an ear of corn.")
    }
}
```

- [ ] **Step 6: Run it to see it fail**

Run: `scripts/test-core.sh --filter WeekSizeLineTests`
Expected: build FAILS with `cannot find 'WeekSizeLine' in scope`.

- [ ] **Step 7: Implement `WeekSizeLine`**

`Packages/KickCore/Sources/KickCore/WeekSizeLine.swift` (whole file):
```swift
import Foundation

/// "Bé lớn cỡ nào?": one sentence built from the week's Hadlock figures, so the
/// numbers always match the reviewed tables (phase 6 spec §4.2). The app passes
/// its localized templates (`L10n`) and number formatters (`Formatting`), which
/// keeps KickCore free of both.
public enum WeekSizeLine {
    /// Format strings with positional `%n$@` arguments.
    public struct Templates: Sendable {
        /// Weeks 7–9: %1$@ crown–rump length, %2$@ size comparison.
        public var length: String
        /// Weeks 10–13: %1$@ crown–rump length, %2$@ weight, %3$@ size comparison.
        public var lengthAndWeight: String
        /// Weeks 14–42: %1$@ weight, %2$@ low end of the typical range (bare number),
        /// %3$@ high end with its unit, %4$@ size comparison.
        public var weightAndRange: String

        public init(length: String, lengthAndWeight: String, weightAndRange: String) {
            self.length = length
            self.lengthAndWeight = lengthAndWeight
            self.weightAndRange = weightAndRange
        }
    }

    /// Number formatters; the app uses display ones for the text and spoken ones
    /// (units spelled out) for VoiceOver.
    public struct Numbers: Sendable {
        public var length: @Sendable (_ millimeters: Double) -> String
        public var weight: @Sendable (_ grams: Int) -> String
        /// The range's low end without a unit, in the unit `weight(reference)` uses.
        public var rangeLow: @Sendable (_ grams: Int, _ reference: Int) -> String
        /// The range's high end with its unit, in the unit `weight(reference)` uses.
        public var rangeHigh: @Sendable (_ grams: Int, _ reference: Int) -> String

        public init(
            length: @escaping @Sendable (Double) -> String,
            weight: @escaping @Sendable (Int) -> String,
            rangeLow: @escaping @Sendable (Int, Int) -> String,
            rangeHigh: @escaping @Sendable (Int, Int) -> String
        ) {
            self.length = length
            self.weight = weight
            self.rangeLow = rangeLow
            self.rangeHigh = rangeHigh
        }
    }

    /// The sentence for `week`, or nil when the week has no figures (weeks 4–6,
    /// where only the article's `sizeNote` is shown). Weeks 41–42 carry week 40's
    /// figures in the data, so they get week 40's numbers with their own comparison.
    public static func make(
        for week: WeekContent,
        language: ContentLanguage,
        templates: Templates,
        numbers: Numbers
    ) -> String? {
        let fruit = week.size.name(language)
        switch (week.crlMm, week.weightG) {
        case let (length?, grams?):
            return String(format: templates.lengthAndWeight, numbers.length(length), numbers.weight(grams), fruit)
        case let (length?, nil):
            return String(format: templates.length, numbers.length(length), fruit)
        case let (nil, grams?):
            guard let low = week.weightP10G, let high = week.weightP90G else { return nil }
            return String(
                format: templates.weightAndRange,
                numbers.weight(grams),
                numbers.rangeLow(low, grams),
                numbers.rangeHigh(high, grams),
                fruit
            )
        case (nil, nil):
            return nil
        }
    }
}
```

- [ ] **Step 8: Run it to see it pass**

Run: `scripts/test-core.sh --filter WeekSizeLineTests`
Expected: PASS, 7 tests.

- [ ] **Step 9: Write the failing resolver test**

`Packages/KickCore/Tests/KickCoreTests/SheetDetentResolverTests.swift` (whole file):
```swift
import Testing
@testable import KickCore

/// Phase 6 spec §3.4–3.5: where the article sheet rests and goes on release.
/// Offsets are the sheet's top edge from the top of the safe area (larger = lower).
struct SheetDetentResolverTests {
    let resolver = SheetDetentResolver(peekOffset: 400, expandedOffset: 8)

    @Test func offsetsForDetents() {
        #expect(resolver.offset(for: .peek) == 400)
        #expect(resolver.offset(for: .expanded) == 8)
        #expect(resolver.span == 392)
    }

    @Test func slowReleaseGoesToTheNearestDetent() {
        #expect(resolver.release(at: 150, velocity: 0) == .expanded)
        #expect(resolver.release(at: 300, velocity: 200) == .peek)
        #expect(resolver.release(at: 204, velocity: 0) == .expanded) // exactly halfway
    }

    @Test func fastFlickUpExpandsEvenNearPeek() {
        #expect(resolver.release(at: 390, velocity: -800) == .expanded)
    }

    @Test func fastFlickDownCollapsesEvenNearExpanded() {
        #expect(resolver.release(at: 20, velocity: 900) == .peek)
    }

    @Test func aSpeedOfExactly600IsNotAFlick() {
        #expect(resolver.release(at: 390, velocity: -600) == .peek)
        #expect(resolver.release(at: 20, velocity: 600) == .expanded)
    }

    @Test func dragIsClampedWithALittleRubberBanding() {
        #expect(resolver.dragOffset(from: .peek, translation: -100) == 300)
        #expect(resolver.dragOffset(from: .expanded, translation: -100) == -17) // 8 − 100 × 0.25
        #expect(resolver.dragOffset(from: .expanded, translation: -400) == -22) // capped at 30
        #expect(resolver.dragOffset(from: .peek, translation: 40) == 410)
        #expect(resolver.dragOffset(from: .expanded, translation: 600) == 430)
    }

    @Test func progressRunsFromPeekToExpanded() {
        #expect(resolver.progress(atOffset: 400) == 0)
        #expect(resolver.progress(atOffset: 8) == 1)
        #expect(resolver.progress(atOffset: 204) == 0.5)
        #expect(resolver.progress(atOffset: -17) == 1)
        #expect(resolver.progress(atOffset: 410) == 0)
        #expect(resolver.progress(for: .peek) == 0)
        #expect(resolver.progress(for: .expanded) == 1)
    }

    /// When the chips reach the top (huge text), there is no room to peek.
    @Test func noRoomToPeekStaysExpanded() {
        let tight = SheetDetentResolver(peekOffset: 5, expandedOffset: 8)
        #expect(tight.peekOffset == 8)
        #expect(tight.release(at: 8, velocity: 900) == .expanded)
        #expect(tight.progress(for: .peek) == 1)
    }
}
```

- [ ] **Step 10: Run it to see it fail**

Run: `scripts/test-core.sh --filter SheetDetentResolverTests`
Expected: build FAILS with `cannot find 'SheetDetentResolver' in scope`.

- [ ] **Step 11: Implement the resolver**

`Packages/KickCore/Sources/KickCore/SheetDetentResolver.swift` (whole file):
```swift
import Foundation

/// The two rest positions of the week article sheet (phase 6 spec §3.4).
public enum SheetDetent: Sendable, Equatable, CaseIterable {
    /// Top edge just below the week chips: handle, title, tabs and lead visible.
    case peek
    /// Top edge 8 pt below the top safe area.
    case expanded
}

/// Pure drag and release rules of the article sheet (phase 6 spec §3.5).
/// Offsets are the sheet's top edge in points from the top of the safe area;
/// larger values are lower on screen. Velocities are points per second,
/// positive downwards (SwiftUI's `DragGesture.Value.velocity.height`).
public struct SheetDetentResolver: Sendable, Equatable {
    /// A release faster than this goes to the detent in the direction of travel.
    public static let flickSpeed: Double = 600
    /// Past a detent the sheet moves a quarter of the finger's distance…
    public static let rubberBandFactor: Double = 0.25
    /// …and never more than this many points.
    public static let rubberBandLimit: Double = 30

    public let peekOffset: Double
    public let expandedOffset: Double

    /// A peek offset above the expanded one (no room) is raised to it.
    public init(peekOffset: Double, expandedOffset: Double) {
        self.expandedOffset = expandedOffset
        self.peekOffset = max(peekOffset, expandedOffset)
    }

    public var span: Double { peekOffset - expandedOffset }

    public func offset(for detent: SheetDetent) -> Double {
        detent == .peek ? peekOffset : expandedOffset
    }

    /// Where the top edge is while dragging `translation` points from `detent`:
    /// clamped between the detents, with a little rubber-banding past them.
    public func dragOffset(from detent: SheetDetent, translation: Double) -> Double {
        let raw = offset(for: detent) + translation
        if raw < expandedOffset { return expandedOffset - rubberBand(expandedOffset - raw) }
        if raw > peekOffset { return peekOffset + rubberBand(raw - peekOffset) }
        return raw
    }

    /// 0 at peek, 1 at expanded, clamped; 1 when there is no room to peek.
    public func progress(atOffset offset: Double) -> Double {
        guard span >= 1 else { return 1 }
        return min(max((peekOffset - offset) / span, 0), 1)
    }

    public func progress(for detent: SheetDetent) -> Double {
        progress(atOffset: offset(for: detent))
    }

    /// The detent after a release at `offset`: a flick (faster than 600 pt/s)
    /// goes in its direction, otherwise the nearest detent (expanded on a tie).
    public func release(at offset: Double, velocity: Double) -> SheetDetent {
        guard span >= 1 else { return .expanded }
        if velocity < -Self.flickSpeed { return .expanded }
        if velocity > Self.flickSpeed { return .peek }
        return offset - expandedOffset <= peekOffset - offset ? .expanded : .peek
    }

    private func rubberBand(_ distance: Double) -> Double {
        min(distance * Self.rubberBandFactor, Self.rubberBandLimit)
    }
}
```

- [ ] **Step 12: Run it to see it pass**

Run: `scripts/test-core.sh --filter SheetDetentResolverTests`
Expected: PASS, 8 tests.

- [ ] **Step 13: Write the failing content-check tests**

`Packages/KickCore/Tests/KickCoreTests/WeekArticleChecksTests.swift` (whole file):
```swift
import Foundation
import Testing
@testable import KickCore

/// Phase 6 spec §4.4–4.5 on a fixture (weeks 7–11, two sources).
struct WeekArticleChecksTests {
    /// `count` words: words(3, "chữ") == "chữ chữ chữ."
    private func words(_ count: Int, _ word: String) -> String {
        Array(repeating: word, count: count).joined(separator: " ") + "."
    }

    /// Bé tab: en 20 + 40 + 2×60 = 180, vi 30 + 50 + 2×70 = 220.
    /// Mẹ tab: en 3×60 = 180, vi 3×70 = 210.
    private func validArticle() -> WeekArticle {
        WeekArticle(
            lead: LocalizedText(en: words(20, "word"), vi: words(30, "chữ")),
            sizeNote: LocalizedParagraphs(en: [words(40, "word")], vi: [words(50, "chữ")]),
            development: LocalizedParagraphs(
                en: [words(60, "word"), words(60, "word")],
                vi: [words(70, "chữ"), words(70, "chữ")]
            ),
            body: LocalizedParagraphs(
                en: [words(60, "word"), words(60, "word")],
                vi: [words(70, "chữ"), words(70, "chữ")]
            ),
            todo: LocalizedParagraphs(en: [words(60, "word")], vi: [words(70, "chữ")]),
            sources: [0]
        )
    }

    /// The fixture with `article` on week 7.
    private func content(_ article: WeekArticle?) throws -> PregnancyContent {
        var content = try fixtureContent()
        content.weeks[0].article = article
        return content
    }

    @Test func validArticlePasses() throws {
        #expect(WeekArticleChecks.validate(try content(validArticle())).isEmpty)
    }

    @Test func missingArticlesAreReportedOnlyInsideRequiredWeeks() throws {
        let content = try content(validArticle())
        #expect(WeekArticleChecks.validate(content).isEmpty)
        #expect(WeekArticleChecks.validate(content, requiredWeeks: 7...8) == [.missingArticle(week: 8)])
    }

    @Test func emptyAndBlankParagraphsAreReported() throws {
        var article = validArticle()
        article.todo.vi = []
        article.body.en[1] = "  "
        article.lead.vi = " "
        let found = WeekArticleChecks.validate(try content(article))
        #expect(found.contains(.emptyParagraphs(week: 7, field: "todo", language: .vi)))
        #expect(found.contains(.blankText(week: 7, field: "body", language: .en)))
        #expect(found.contains(.blankText(week: 7, field: "lead", language: .vi)))
    }

    @Test func leadsOverTheLimitAreReported() throws {
        var article = validArticle()
        article.lead = LocalizedText(en: words(31, "word"), vi: words(41, "chữ"))
        let found = WeekArticleChecks.validate(try content(article))
        #expect(found.contains(.leadTooLong(week: 7, language: .en, words: 31)))
        #expect(found.contains(.leadTooLong(week: 7, language: .vi, words: 41)))
        article.lead = LocalizedText(en: words(30, "word"), vi: words(40, "chữ"))
        #expect(WeekArticleChecks.validate(try content(article)).isEmpty)
    }

    @Test func tabsOutsideTheWordRangeAreReported() throws {
        var article = validArticle()
        article.body.en = [words(40, "word")] // Mẹ en: 40 + 60 = 100
        article.development.vi = [words(120, "chữ"), words(120, "chữ")] // Bé vi: 30 + 50 + 240 = 320
        let found = WeekArticleChecks.validate(try content(article))
        #expect(found.contains(.tabLength(week: 7, tab: .mom, language: .en, words: 100)))
        #expect(found.contains(.tabLength(week: 7, tab: .baby, language: .vi, words: 320)))
        #expect(found.count == 2)
    }

    @Test func tabWordCountsFollowTheTabs() {
        let article = validArticle()
        #expect(WeekArticleChecks.tabWordCount(article, tab: .baby, language: .en) == 180)
        #expect(WeekArticleChecks.tabWordCount(article, tab: .baby, language: .vi) == 220)
        #expect(WeekArticleChecks.tabWordCount(article, tab: .mom, language: .en) == 180)
        #expect(WeekArticleChecks.tabWordCount(article, tab: .mom, language: .vi) == 210)
    }

    @Test func sourcesMustBeValidIndices() throws {
        var article = validArticle()
        article.sources = []
        #expect(WeekArticleChecks.validate(try content(article)) == [.noSources(week: 7)])
        article.sources = [1, 2, -1]
        #expect(
            WeekArticleChecks.validate(try content(article))
                == [.invalidSource(week: 7, index: 2), .invalidSource(week: 7, index: -1)]
        )
    }

    @Test func imperialUnitsAreReported() throws {
        var article = validArticle()
        article.sizeNote.en = ["Your baby weighs about 1 pound. " + words(34, "word")] // still 40 words
        article.todo.en = ["Drink 8 oz of water. " + words(55, "word")] // still 60 words
        article.development.vi[0] = "Bé dài 12″. " + words(67, "chữ") // still 70 words
        let found = WeekArticleChecks.validate(try content(article))
        #expect(found.contains(.imperialUnit(week: 7, field: "sizeNote", language: .en)))
        #expect(found.contains(.imperialUnit(week: 7, field: "todo", language: .en)))
        #expect(found.contains(.imperialUnit(week: 7, field: "development", language: .vi)))
        #expect(found.count == 3)
    }

    @Test func metricTextAndLookalikeWordsAreNotFlagged() {
        #expect(!WeekArticleChecks.containsImperialUnit("Your baby weighs about 670 g and is 30 cm long."))
        #expect(!WeekArticleChecks.containsImperialUnit("We announce a pounding heartbeat in Ozone Park."))
        #expect(WeekArticleChecks.containsImperialUnit("About 2 LBS"))
        #expect(WeekArticleChecks.containsImperialUnit("12 inches"))
        #expect(WeekArticleChecks.containsImperialUnit("5″"))
    }

    @Test func wordsAreSplitOnWhitespace() {
        #expect(WeekArticleChecks.wordCount("  Bé  nặng\nkhoảng 670 g. ") == 5)
        #expect(WeekArticleChecks.wordCount("") == 0)
    }
}
```

`Packages/KickCore/Tests/KickCoreTests/BundledArticleTests.swift` (whole file):
```swift
import Foundation
import Testing
@testable import KickCore

/// Phase 6 spec §4.5: the week articles in the shipped `pregnancy-content.json`.
struct BundledArticleTests {
    /// Weeks that must already have an article. Each content task widens it:
    /// nil (Tasks 1–3) → 4...13 (Task 4) → 4...27 (Task 5) → WeeklyContentLibrary.weekRange (Task 6).
    static let requiredArticleWeeks: ClosedRange<Int>? = nil

    let library: WeeklyContentLibrary

    init() throws {
        library = try WeeklyContentLibrary.bundled()
    }

    private var articles: [(week: WeekContent, article: WeekArticle)] {
        library.document.weeks.compactMap { week in week.article.map { (week, $0) } }
    }

    @Test func contentIsVersion3() {
        #expect(library.document.version == 3)
    }

    @Test func everyWrittenArticlePassesTheChecks() {
        let issues = WeekArticleChecks.validate(library.document, requiredWeeks: Self.requiredArticleWeeks)
        #expect(issues.isEmpty, "\(issues)")
    }

    /// Writing guide §4.4: no medicine doses.
    @Test func articlesStateNoDoses() {
        for (week, article) in articles {
            for language in ContentLanguage.allCases {
                for (field, text) in article.texts(language) {
                    #expect(text.firstMatch(of: /\b(?:mg|mcg|µg|IU)\b/) == nil, "week \(week.week) \(field).\(language.rawValue): \(text)")
                }
            }
        }
    }

    @Test func vietnameseArticleTextHasDiacritics() {
        for (week, article) in articles {
            for (field, text) in article.texts(.vi) {
                #expect(text.unicodeScalars.contains { $0.value > 127 }, "week \(week.week) \(field): \(text)")
            }
        }
    }

    /// The size line quotes Hadlock 1992 (crown–rump length, index 5) and Hadlock 1991
    /// (weight, index 4); every article also cites a guideline body (WHO, ACOG, NHS, Bộ Y tế: 0–3).
    @Test func sourcesMatchTheWeeksFigures() {
        #expect(library.sources[4].contains("Hadlock FP, Harrist RB"))
        #expect(library.sources[5].contains("Hadlock FP, Shah YP"))
        for (week, article) in articles {
            if week.crlMm != nil { #expect(article.sources.contains(5), "week \(week.week): Hadlock 1992") }
            if week.weightG != nil { #expect(article.sources.contains(4), "week \(week.week): Hadlock 1991") }
            #expect(article.sources.contains { (0...3).contains($0) }, "week \(week.week): guideline body")
        }
    }
}
```

- [ ] **Step 14: Run them to see them fail**

Run: `scripts/test-core.sh --filter "WeekArticleChecksTests|BundledArticleTests"`
Expected: build FAILS with `cannot find 'WeekArticleChecks' in scope`.

- [ ] **Step 15: Implement the checks, bump the version, add the script**

`Packages/KickCore/Sources/KickCore/WeekArticleChecks.swift` (whole file):
```swift
import Foundation

/// The two tabs of the week article sheet (phase 6 spec §3.3).
public enum ArticleTab: String, Sendable, CaseIterable, Hashable {
    case baby
    case mom
}

public enum ArticleIssue: Equatable, Sendable {
    /// The week is inside the required range but has no `article`.
    case missingArticle(week: Int)
    /// `field` ("sizeNote", "development", "body", "todo") has no paragraphs in `language`.
    case emptyParagraphs(week: Int, field: String, language: ContentLanguage)
    /// `field` ("lead" or a paragraph field) has an empty or whitespace-only text.
    case blankText(week: Int, field: String, language: ContentLanguage)
    case leadTooLong(week: Int, language: ContentLanguage, words: Int)
    /// A tab's words (Bé: lead + sizeNote + development; Mẹ: body + todo) outside 150–300.
    case tabLength(week: Int, tab: ArticleTab, language: ContentLanguage, words: Int)
    case noSources(week: Int)
    case invalidSource(week: Int, index: Int)
    /// An inch / pound / ounce unit or "″" in `field` (metric only).
    case imperialUnit(week: Int, field: String, language: ContentLanguage)
}

/// Automatic checks of the week articles (phase 6 spec §4.4–4.5), enforced by
/// unit tests on the bundled JSON. Accuracy and tone are reviewed by people.
public enum WeekArticleChecks {
    /// Maximum words in the bold lead.
    public static let leadLimit: [ContentLanguage: Int] = [.en: 30, .vi: 40]
    /// Words per tab per language (Vietnamese: syllables, which are space-separated).
    public static let tabWords: ClosedRange<Int> = 150...300

    /// Every article present is checked; `requiredWeeks` (nil = none) also reports
    /// weeks in that range without an article.
    public static func validate(_ content: PregnancyContent, requiredWeeks: ClosedRange<Int>? = nil) -> [ArticleIssue] {
        var issues: [ArticleIssue] = []
        if let requiredWeeks {
            let written = Set(content.weeks.filter { $0.article != nil }.map(\.week))
            for week in requiredWeeks where !written.contains(week) {
                issues.append(.missingArticle(week: week))
            }
        }
        for week in content.weeks {
            guard let article = week.article else { continue }
            issues += articleIssues(article, week: week.week, sourceCount: content.sources.count)
        }
        return issues
    }

    public static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    public static func tabWordCount(_ article: WeekArticle, tab: ArticleTab, language: ContentLanguage) -> Int {
        let paragraphs: [String]
        switch tab {
        case .baby:
            paragraphs = [article.lead.text(language)]
                + article.sizeNote.paragraphs(language)
                + article.development.paragraphs(language)
        case .mom:
            paragraphs = article.body.paragraphs(language) + article.todo.paragraphs(language)
        }
        return paragraphs.map(wordCount).reduce(0, +)
    }

    /// inch(es), pound(s), lb(s), ounce(s), oz as whole words (any case), or "″".
    public static func containsImperialUnit(_ text: String) -> Bool {
        text.contains("″")
            || text.firstMatch(of: /(?i)\b(?:inch|inches|pound|pounds|lb|lbs|ounce|ounces|oz)\b/) != nil
    }

    private static func articleIssues(_ article: WeekArticle, week: Int, sourceCount: Int) -> [ArticleIssue] {
        var issues: [ArticleIssue] = []
        for language in ContentLanguage.allCases {
            let lead = article.lead.text(language)
            if ContentValidator.isBlank(lead) {
                issues.append(.blankText(week: week, field: "lead", language: language))
            }
            let leadWords = wordCount(lead)
            if leadWords > leadLimit[language, default: 0] {
                issues.append(.leadTooLong(week: week, language: language, words: leadWords))
            }
            for field in article.paragraphFields {
                let paragraphs = field.paragraphs.paragraphs(language)
                if paragraphs.isEmpty {
                    issues.append(.emptyParagraphs(week: week, field: field.name, language: language))
                }
                if paragraphs.contains(where: ContentValidator.isBlank) {
                    issues.append(.blankText(week: week, field: field.name, language: language))
                }
            }
            for tab in ArticleTab.allCases {
                let words = tabWordCount(article, tab: tab, language: language)
                if !tabWords.contains(words) {
                    issues.append(.tabLength(week: week, tab: tab, language: language, words: words))
                }
            }
            for (field, text) in article.texts(language) where containsImperialUnit(text) {
                issues.append(.imperialUnit(week: week, field: field, language: language))
            }
        }
        if article.sources.isEmpty { issues.append(.noSources(week: week)) }
        for index in article.sources where !(0..<sourceCount).contains(index) {
            issues.append(.invalidSource(week: week, index: index))
        }
        return issues
    }
}
```

In `Packages/KickCore/Sources/KickCore/ContentValidator.swift`, replace:
```swift
    /// Version 2: Hadlock `crlMm` / `weightG` / `weightP10G` / `weightP90G` replace `lengthCm`.
    public static let supportedVersion = 2
```
with:
```swift
    /// Version 2: Hadlock `crlMm` / `weightG` / `weightP10G` / `weightP90G` replace `lengthCm`.
    /// Version 3: optional `article` per week (phase 6, checked by `WeekArticleChecks`).
    public static let supportedVersion = 3
```

Bump both JSON files to version 3 (keeps the committed formatting: 2-space indent, UTF-8, trailing newline):
```bash
python3 - <<'PY'
import json
for path in ["Packages/KickCore/Sources/KickCore/Resources/pregnancy-content.json",
             "Packages/KickCore/Tests/KickCoreTests/Fixtures/content-fixture.json"]:
    with open(path, encoding="utf-8") as f:
        text = f.read()
    data = json.loads(text)
    assert data["version"] == 2, path
    if path.endswith("pregnancy-content.json"):
        data["version"] = 3
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write("\n")
    else:
        # The fixture is hand-formatted: change only the version line.
        with open(path, "w", encoding="utf-8") as f:
            f.write(text.replace('"version": 2,', '"version": 3,', 1))
PY
git diff --stat
```
Expected: `pregnancy-content.json | 2 +-` and `content-fixture.json | 2 +-` (one line each).

`scripts/set-week-articles.py` (whole file):
```python
#!/usr/bin/env python3
"""Sets the `article` of weeks in pregnancy-content.json, keeping the file
formatted exactly as committed (2-space indent, UTF-8, trailing newline).

    scripts/set-week-articles.py <<'JSON'
    {"24": {"lead": {"en": "...", "vi": "..."},
            "sizeNote": {"en": ["..."], "vi": ["..."]},
            "development": {"en": ["...", "..."], "vi": ["...", "..."]},
            "body": {"en": ["..."], "vi": ["..."]},
            "todo": {"en": ["..."], "vi": ["..."]},
            "sources": [1, 2, 4]}}
    JSON

Replaces an existing article of the same week. Prints the word counts the
content checks use (KickCore WeekArticleChecks): the lead (en <= 30, vi <= 40)
and each tab (150-300): baby = lead + sizeNote + development, mom = body + todo.
The full checks run in `scripts/test-core.sh --filter BundledArticleTests`.
"""
import json
import os
import sys

PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Packages", "KickCore",
                    "Sources", "KickCore", "Resources", "pregnancy-content.json")
PARAGRAPH_FIELDS = ["sizeNote", "development", "body", "todo"]
KEYS = ["lead"] + PARAGRAPH_FIELDS + ["sources"]
LANGUAGES = ["en", "vi"]


def words(text):
    return len(text.split())


def check(week, article, source_count):
    if list(article) != KEYS:
        sys.exit(f"week {week}: keys must be {KEYS}, in this order")
    lead = article["lead"]
    if sorted(lead) != LANGUAGES or not all(isinstance(lead[l], str) and lead[l].strip() for l in LANGUAGES):
        sys.exit(f"week {week}: lead needs non-empty en and vi strings")
    for field in PARAGRAPH_FIELDS:
        value = article[field]
        if sorted(value) != LANGUAGES:
            sys.exit(f"week {week}: {field} needs exactly en and vi")
        for l in LANGUAGES:
            paragraphs = value[l]
            if not paragraphs or not all(isinstance(p, str) and p.strip() for p in paragraphs):
                sys.exit(f"week {week}: {field}.{l} needs non-empty paragraphs")
    sources = article["sources"]
    if not sources or not all(isinstance(i, int) and 0 <= i < source_count for i in sources):
        sys.exit(f"week {week}: sources must be indices 0..{source_count - 1}")


def main():
    articles = json.load(sys.stdin)
    with open(PATH, encoding="utf-8") as f:
        content = json.load(f)
    weeks = {w["week"]: w for w in content["weeks"]}
    for key, article in articles.items():
        week = int(key)
        if week not in weeks:
            sys.exit(f"unknown week: {key}")
        check(week, article, len(content["sources"]))
        weeks[week]["article"] = article
        for l in LANGUAGES:
            lead = words(article["lead"][l])
            baby = lead + sum(words(p) for f in ("sizeNote", "development") for p in article[f][l])
            mom = sum(words(p) for f in ("body", "todo") for p in article[f][l])
            print(f"week {week} {l}: lead {lead}, baby {baby}, mom {mom}")
    with open(PATH, "w", encoding="utf-8") as f:
        json.dump(content, f, ensure_ascii=False, indent=2)
        f.write("\n")


if __name__ == "__main__":
    main()
```
Then: `chmod +x scripts/set-week-articles.py`

- [ ] **Step 16: Run the whole KickCore suite**

Run: `scripts/test-core.sh`
Expected: PASS, `Test run with 430 tests` (396 + 34: `WeekArticleTests` 4, `WeekSizeLineTests` 7, `SheetDetentResolverTests` 8, `WeekArticleChecksTests` 10, `BundledArticleTests` 5). `BundledContentTests.bundledContentPassesValidation` and `ContentValidatorTests.fixtureIsValid` stay green with version 3.

Check the script does not reformat the file (an empty object must change nothing):
```bash
echo '{}' | scripts/set-week-articles.py
git diff --stat -- Packages/KickCore/Sources/KickCore/Resources/pregnancy-content.json
```
Expected: no output from the script, then `1 file changed, 1 insertion(+), 1 deletion(-)` (only Step 15's version line).

- [ ] **Step 17: Build the app**

```bash
xcodegen generate --quiet
xcodebuild -project KickCounter.xcodeproj -scheme KickCounter \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO -quiet build-for-testing
```
Expected: exit 0, no `.swift:…: error:` lines (no app code changed; `WeekContent` gained an optional field).

- [ ] **Step 18: Commit, push, verify CI**

The content file changed version, so CI smoke-tests Today and the week detail as they are now.
```bash
scripts/test-core.sh
git add Packages/KickCore scripts/set-week-articles.py
git commit -F - <<'MSG'
feat(core): week article model, size line and sheet detent rules

pregnancy-content.json moves to version 3 with an optional article per
week (lead, size note, development, body, what to do, sources). The size
sentence is generated from the Hadlock figures with templates the app
supplies, the sheet's release rule is a pure resolver, and the article
checks validate every written week. set-week-articles.py writes articles
into the JSON and prints their word counts.

CI-Only-Testing: PregnancyTodayUITests, PregnancyScreenshotTests
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`; the log has `==> UI tests: scoped to PregnancyTodayUITests PregnancyScreenshotTests`.

---
### Task 2: Design system — `ArticleSheet`

A generic in-view sheet with two detents (spec §3.3–3.5, §5): a grab handle that is an accessibility button, a fixed header, a scrolling body, a progress binding for the background, the hand-off from the inner scroll to the sheet (offset read through a `GeometryReader` preference, since `onScrollGeometryChange` needs iOS 18), and motion gated by `LunaMotion.isEnabled` and Reduce Motion. Nothing uses it yet; Task 3 builds the week detail on it. The deliverable is a compiling component with a working `#Preview`.

**Files:**
- Create: `App/DesignSystem/ArticleSheet.swift`
- Modify: `App/DesignSystem/Motion.swift` (`LunaMotion`)

**Interfaces:**
- Consumes (Task 1): `SheetDetent`, `SheetDetentResolver` (`init(peekOffset:expandedOffset:)`, `offset(for:)`, `dragOffset(from:translation:)`, `progress(atOffset:)`, `progress(for:)`, `release(at:velocity:)`).
- Produces (Task 3 uses exactly these):
  - `LunaMotion.sheetSpring: Animation` (`.spring(response: 0.35, dampingFraction: 0.85)`) and `LunaMotion.sheet(reduceMotion: Bool) -> Animation?`.
  - `struct ArticleSheet<Header: View, Content: View>: View` with
    ```swift
    init(
        detent: Binding<SheetDetent>,
        progress: Binding<Double>,
        peekTop: CGFloat,
        expandedTop: CGFloat,
        containerHeight: CGFloat,
        bottomInset: CGFloat,
        resetKey: String,
        initialAnchor: String?,
        handleIdentifier: String,
        scrollIdentifier: String,
        handleLabel: @escaping (SheetDetent) -> String,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    )
    ```
    `peekTop`/`expandedTop` are y positions in the container (top of the safe area = 0); `containerHeight` is the safe-area height; `bottomInset` the bottom safe-area inset; a change of `resetKey` scrolls the body to the top; `initialAnchor` is an `.id` inside `content` scrolled to the top 150 ms after appearing. The body's horizontal padding is 24 pt; `content` adds none.

- [ ] **Step 1: Add the sheet animation to `LunaMotion`**

In `App/DesignSystem/Motion.swift`, replace:
```swift
    static let overlay = Animation.easeOut(duration: 0.28)
    static let fade = Animation.easeOut(duration: 0.2)
}
```
with:
```swift
    static let overlay = Animation.easeOut(duration: 0.28)
    static let fade = Animation.easeOut(duration: 0.2)
    /// The week article sheet settling on a detent (phase 6 spec §3.5).
    static let sheetSpring = Animation.spring(response: 0.35, dampingFraction: 0.85)

    /// `sheetSpring`, or nil (the sheet jumps) under Reduce Motion and in UI tests.
    static func sheet(reduceMotion: Bool) -> Animation? {
        isEnabled && !reduceMotion ? sheetSpring : nil
    }
}
```

- [ ] **Step 2: Write `ArticleSheet`**

`App/DesignSystem/ArticleSheet.swift` (whole file):
```swift
import KickCore
import SwiftUI

/// The top of the scroll content in the sheet's scroll view: 0 at the top,
/// negative once scrolled down, positive while bouncing past the top.
private struct ArticleScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// A two-detent sheet drawn inside a screen (phase 6 spec §3.3–3.5), not a
/// native `.sheet`: a grab handle that is also a button, a fixed header and a
/// scrolling body on the card colour with 24 pt top corners.
///
/// - Dragging the handle or header moves the sheet, clamped between the detents
///   with a little rubber-banding; on release `SheetDetentResolver` picks the detent.
/// - At peek the body does not scroll and an upward drag on it moves the sheet.
/// - Expanded, the body scrolls; pulling down while it is at the top (offset ≤ 0)
///   hands the drag to the sheet.
/// - `progress` is 0 at peek and 1 expanded, for the caller's background.
/// - The spring is off under Reduce Motion and in UI tests (`LunaMotion.sheet`).
struct ArticleSheet<Header: View, Content: View>: View {
    @Binding private var detent: SheetDetent
    @Binding private var progress: Double
    private let peekTop: CGFloat
    private let expandedTop: CGFloat
    private let containerHeight: CGFloat
    private let bottomInset: CGFloat
    private let resetKey: String
    private let initialAnchor: String?
    private let handleIdentifier: String
    private let scrollIdentifier: String
    private let handleLabel: (SheetDetent) -> String
    private let header: Header
    private let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDragging = false
    @State private var dragTranslation: CGFloat = 0
    /// The finger's translation when an expanded body drag was handed to the sheet.
    @State private var handoffStart: CGFloat?
    @State private var scrollOffset: CGFloat = 0

    private static var topID: String { "articleSheetTop" }
    private static var scrollSpace: String { "articleSheetScroll" }

    init(
        detent: Binding<SheetDetent>,
        progress: Binding<Double>,
        peekTop: CGFloat,
        expandedTop: CGFloat,
        containerHeight: CGFloat,
        bottomInset: CGFloat,
        resetKey: String,
        initialAnchor: String?,
        handleIdentifier: String,
        scrollIdentifier: String,
        handleLabel: @escaping (SheetDetent) -> String,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) {
        _detent = detent
        _progress = progress
        self.peekTop = peekTop
        self.expandedTop = expandedTop
        self.containerHeight = containerHeight
        self.bottomInset = bottomInset
        self.resetKey = resetKey
        self.initialAnchor = initialAnchor
        self.handleIdentifier = handleIdentifier
        self.scrollIdentifier = scrollIdentifier
        self.handleLabel = handleLabel
        self.header = header()
        self.content = content()
    }

    private var resolver: SheetDetentResolver {
        SheetDetentResolver(peekOffset: Double(peekTop), expandedOffset: Double(expandedTop))
    }

    /// The sheet's top edge now.
    private var top: CGFloat {
        CGFloat(isDragging
            ? resolver.dragOffset(from: detent, translation: Double(dragTranslation))
            : resolver.offset(for: detent))
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                handle
                header
            }
            .contentShape(Rectangle())
            .simultaneousGesture(headerDrag)
            ScrollViewReader { reader in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: ArticleScrollOffsetKey.self,
                                value: geometry.frame(in: .named(Self.scrollSpace)).minY
                            )
                        }
                        .frame(height: 0)
                        .id(Self.topID)
                        content
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, bottomInset + 32)
                }
                .coordinateSpace(.named(Self.scrollSpace))
                .scrollDisabled(detent == .peek || handoffStart != nil)
                .scrollBounceBehavior(.basedOnSize)
                .accessibilityIdentifier(scrollIdentifier)
                .simultaneousGesture(bodyDrag)
                .onPreferenceChange(ArticleScrollOffsetKey.self) { value in
                    // Preference callbacks arrive on the main thread; the closure is @Sendable.
                    MainActor.assumeIsolated { scrollOffset = value }
                }
                .onChange(of: resetKey) {
                    reader.scrollTo(Self.topID, anchor: .top)
                }
                .task {
                    guard let initialAnchor else { return }
                    // Once laid out; a jump rather than an animated scroll (Reduce Motion, UI tests).
                    try? await Task.sleep(for: .milliseconds(150))
                    reader.scrollTo(initialAnchor, anchor: .top)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: containerHeight - expandedTop + bottomInset, alignment: .top)
        .background(
            .luna(.card),
            in: UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous)
        )
        .offset(y: top)
        .onAppear { progress = resolver.progress(for: detent) }
        .onChange(of: peekTop) {
            if !isDragging { progress = resolver.progress(for: detent) }
        }
        .onChange(of: detent) {
            if !isDragging { progress = resolver.progress(for: detent) }
        }
    }

    /// 36×5 pt capsule in a full-width, 44 pt tall hit area; tapping toggles the detent.
    private var handle: some View {
        Button(action: toggle) {
            Capsule()
                .fill(.luna(.chevron))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(handleLabel(detent))
        .accessibilityIdentifier(handleIdentifier)
    }

    private var headerDrag: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .onChanged { value in move(by: value.translation.height) }
            .onEnded { value in settle(velocity: value.velocity.height) }
    }

    private var bodyDrag: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { value in
                let translation = value.translation.height
                switch detent {
                case .peek:
                    move(by: translation)
                case .expanded:
                    if handoffStart == nil {
                        // Only a downward pull while the article is at its top.
                        guard scrollOffset >= -1, translation > 0 else { return }
                        handoffStart = translation
                    }
                    move(by: max(0, translation - (handoffStart ?? translation)))
                }
            }
            .onEnded { value in
                defer { handoffStart = nil }
                guard isDragging else { return }
                settle(velocity: value.velocity.height)
            }
    }

    private func move(by translation: CGFloat) {
        isDragging = true
        dragTranslation = translation
        progress = resolver.progress(atOffset: Double(top))
    }

    private func settle(velocity: CGFloat) {
        let target = resolver.release(at: Double(top), velocity: Double(velocity))
        withAnimation(LunaMotion.sheet(reduceMotion: reduceMotion)) {
            detent = target
            isDragging = false
            dragTranslation = 0
            progress = resolver.progress(for: target)
        }
    }

    private func toggle() {
        let target: SheetDetent = detent == .peek ? .expanded : .peek
        withAnimation(LunaMotion.sheet(reduceMotion: reduceMotion)) {
            detent = target
            progress = resolver.progress(for: target)
        }
    }
}

private struct ArticleSheetPreview: View {
    @State private var detent = SheetDetent.peek
    @State private var progress = 0.0

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Text(verbatim: "Background")
                    .font(.luna(.weekTitle))
                    .foregroundStyle(.luna(.textPrimary))
                    .opacity(1 - progress)
                    .padding(.top, 80)
                ArticleSheet(
                    detent: $detent,
                    progress: $progress,
                    peekTop: proxy.size.height * 0.5,
                    expandedTop: 8,
                    containerHeight: proxy.size.height,
                    bottomInset: proxy.safeAreaInsets.bottom,
                    resetKey: "preview",
                    initialAnchor: nil,
                    handleIdentifier: "previewHandle",
                    scrollIdentifier: "previewScroll",
                    handleLabel: { $0 == .peek ? "Expand" : "Collapse" }
                ) {
                    Text(verbatim: "Tuần 24")
                        .font(.luna(.sheetTitle))
                        .foregroundStyle(.luna(.textPrimary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                } content: {
                    ForEach(0..<30, id: \.self) { index in
                        Text(verbatim: "Đoạn \(index)")
                            .font(.luna(.articleBody))
                            .foregroundStyle(.luna(.articleText))
                            .padding(.vertical, 6)
                    }
                }
            }
        }
        .background(.luna(.heroMiddle))
    }
}

#Preview {
    ArticleSheetPreview()
}
```
- [ ] **Step 3: Build**

```bash
scripts/test-core.sh
xcodegen generate --quiet
xcodebuild -project KickCounter.xcodeproj -scheme KickCounter \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO -quiet build-for-testing
```
Expected: `Test run with 430 tests` passed; `xcodebuild` exits 0 with no `.swift:…: error:` lines. Open the `#Preview` in Xcode if available: at peek the sheet's top is at mid-screen, tapping the capsule expands it to 8 pt below the safe area and "Background" fades; dragging the header follows the finger; a flick up/down switches detents; expanded, the list scrolls, and pulling down from its top collapses the sheet.

- [ ] **Step 4: Commit, push, verify CI**

No screen uses the sheet yet; `PregnancyTodayUITests` is a smoke run.
```bash
git add App/DesignSystem/ArticleSheet.swift App/DesignSystem/Motion.swift
git commit -F - <<'MSG'
feat(design): two-detent article sheet

ArticleSheet is an in-view sheet with a grab handle that is also an
accessibility button, a fixed header and a scrolling body. Drags follow
the finger with a little rubber-banding, releases go through
SheetDetentResolver, and a downward pull at the top of the expanded body
hands the drag to the sheet. A progress binding drives the caller's
background; the spring is off under Reduce Motion and in UI tests.

CI-Only-Testing: PregnancyTodayUITests
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`; log has `==> UI tests: scoped to PregnancyTodayUITests`.

---
### Task 3: Week detail on the article sheet — artwork, Bé / Mẹ tabs, strings, tests, week 24

Rebuilds `WeekDetailView` as the background (hero gradient, ✕, large fetus, week chips) under `ArticleSheet` (spec §3), with `WeekArticleView` for the Bé / Mẹ tabs, the generated size line and references, and the bullet fallback when a week has no article (§4.3). Adds the strings, `WeekArtwork` fallbacks, week 24's article (the first written article, used by every UI test and screenshot), new UI and screenshot tests, and updates the existing week-detail tests.

**Files:**
- Create: `App/Pregnancy/WeekArtwork.swift`, `App/Pregnancy/WeekArticleView.swift`, `UITests/WeekArticleSheetUITests.swift`, `UITests/WeekArticleScreenshotTests.swift`
- Modify (whole file): `App/Pregnancy/WeekDetailView.swift`
- Modify: `Shared/L10n.swift:390-400`, `Shared/Localizable.xcstrings` (via script), `Packages/KickCore/Sources/KickCore/Resources/pregnancy-content.json` (via script, week 24), `Packages/KickCore/Tests/KickCoreTests/BundledArticleTests.swift`, `UITests/PregnancyTodayUITests.swift`, `UITests/PregnancyScreenshotTests.swift`

**Interfaces:**
- Consumes (Task 1): `WeekArticle`, `LocalizedParagraphs.paragraphs(_:)`, `WeekContent.article`, `ArticleTab` (`.baby`, `.mom`), `SheetDetent`, `WeekSizeLine.Templates`, `WeekSizeLine.Numbers`, `WeekSizeLine.make(for:language:templates:numbers:)`, `WeekArtworkName.fetus(week:)` / `.fruit(week:)`, `scripts/set-week-articles.py`.
- Consumes (Task 2): `ArticleSheet(detent:progress:peekTop:expandedTop:containerHeight:bottomInset:resetKey:initialAnchor:handleIdentifier:scrollIdentifier:handleLabel:header:content:)`, `LunaMotion.fade`.
- Consumes (existing): `ChipScroller`, `SegmentedPill` / `SegmentedOption(value:title:identifier:)`, `UnderReviewCard`, `BuildFlags.contentVisibility`, `WeekDisplay`, `Formatting.crownRumpLength(mm:spoken:)`, `Formatting.weight(grams:spoken:)`, `Formatting.weightRangeStart(_:unitOf:)`, `Formatting.weightInUnit(_:unitOf:spoken:)`, `L10n.weekTitle(_:)`, `L10n.weekChip(_:)`, `L10n.commonClose`, `L10n.weekReviewer`, `L10n.weekReviewed`, `L10n.weekPendingReview`, `L10n.weekBaby`, `L10n.weekMom`, `L10n.weekTips`, `L10n.weekWarnings`, `L10n.pregnancyBabyEstimateNote`, `L10n.pregnancyBabyStandardEnds(_:)`, UI test helpers `XCUIApplication.launchPinned(language:dark:dueDate:largestText:)`, `scrollUntilHittable(_:maxSwipes:)`, `openPregnancySymptoms()`, `attachScreenshot(_:_:)`, `waitForLabel(_:containing:)`, `UITestDates.dueAtWeek24`.
- Produces: `WeekDetailView(currentWeek:scrollToWarnings:)` (unchanged signature); `WeekArticleView(content:tab:sources:language:)` and `WeekArticleView.warningsAnchor == "weekWarnings"`; `WeekArtwork.fetus(_:) -> Image`, `WeekArtwork.fruit(_:) -> Image?`; `WeekSizeLine.Templates.localized`, `WeekSizeLine.Numbers.formatted(spoken:)`; L10n `weekArticle*` accessors below; identifiers `weekSheetHandle`, `weekTab-baby`, `weekTab-mom`, `weekArticleScroll`, `weekArticleLead`, `weekSizeLine`, `weekReferences`; screenshot names `week-article-*` (Task 7's checklist lists them).

- [ ] **Step 1: Week 24's article (data first, so the test below has something to find)**

Add a failing test at the end of `Packages/KickCore/Tests/KickCoreTests/BundledArticleTests.swift` — replace the file's last closing brace
```swift
            #expect(article.sources.contains { (0...3).contains($0) }, "week \(week.week): guideline body")
        }
    }
}
```
with:
```swift
            #expect(article.sources.contains { (0...3).contains($0) }, "week \(week.week): guideline body")
        }
    }

    /// Task 3: week 24 carries the first article; the UI tests and screenshots use it.
    @Test func week24HasAnArticle() throws {
        let week = try #require(library.content(forWeek: 24))
        #expect(week.article != nil)
    }
}
```
Run: `scripts/test-core.sh --filter BundledArticleTests`
Expected: FAIL in `week24HasAnArticle` (`week.article != nil` is false).

Write the article (original text; facts from ACOG and NHS week-by-week material; sources 1 = ACOG, 2 = NHS, 4 = Hadlock 1991):
```bash
scripts/set-week-articles.py <<'JSON'
{
  "24": {
    "lead": {
      "en": "Your baby's lungs are slowly getting ready for breathing after birth, and your baby now has regular times of sleeping and waking.",
      "vi": "Phổi của bé đang dần chuẩn bị cho những hơi thở đầu tiên sau khi chào đời, và bé đã có những khoảng ngủ, thức khá đều đặn."
    },
    "sizeNote": {
      "en": [
        "Your baby is still long and lean. Over the coming weeks, a layer of fat builds up under the skin, and your baby will start to look rounder. Every baby grows at their own pace, so a scan may show a slightly different number."
      ],
      "vi": [
        "Lúc này bé vẫn còn khá thon dài. Trong những tuần tới, một lớp mỡ sẽ dần hình thành dưới da, giúp bé trông tròn trịa hơn. Mỗi bé lớn theo nhịp riêng, nên con số trên siêu âm có thể hơi khác một chút."
      ]
    },
    "development": {
      "en": [
        "Deep inside the lungs, the tiny air sacs and the branches that lead to them keep developing. Some lung cells have started to make surfactant, a substance that will later help the air sacs stay open when your baby breathes. The lungs still have many weeks of growing ahead.",
        "Your baby's inner ear, which helps with balance, is now well formed. Your baby can probably hear your heartbeat, your voice and loud sounds from outside. Some babies wriggle or kick when there is a sudden noise.",
        "The skin is still thin and slightly see-through, so tiny blood vessels show beneath it. Your baby sleeps and wakes in fairly regular cycles, and you may start to notice the times of day when they are most active."
      ],
      "vi": [
        "Sâu bên trong phổi, các túi khí nhỏ li ti cùng những nhánh dẫn khí tới chúng vẫn đang tiếp tục phát triển. Một số tế bào phổi đã bắt đầu tạo ra surfactant, chất sau này giúp các túi khí không bị xẹp khi bé thở. Phổi của bé còn nhiều tuần nữa để hoàn thiện.",
        "Tai trong, bộ phận giúp bé giữ thăng bằng, nay đã hình thành khá đầy đủ. Bé có thể nghe được nhịp tim, giọng nói của mẹ và cả những âm thanh lớn bên ngoài. Có bé còn cựa mình hoặc đạp khi nghe tiếng động bất ngờ.",
        "Da bé vẫn mỏng và hơi trong, nên có thể thấy những mạch máu nhỏ bên dưới. Bé ngủ và thức theo chu kỳ khá đều, và mẹ có thể dần nhận ra những lúc trong ngày bé hay cử động nhất."
      ]
    },
    "body": {
      "en": [
        "The top of your womb is now a little above your belly button, and your bump is easy to see. As the skin stretches, it may feel tight or itchy, and stretch marks may appear. A gentle, unscented moisturiser can make it feel more comfortable.",
        "Heartburn, constipation and backache are common at this stage. Pregnancy hormones relax your muscles, and your growing womb presses on the organs around it. Some people get leg cramps at night, or feel the bump tighten for a few seconds now and then. These tightenings are usually painless and irregular.",
        "Very strong itching, especially on the palms of your hands or the soles of your feet, is different. Tell your doctor or midwife about it, as you may need a blood test."
      ],
      "vi": [
        "Đáy tử cung lúc này đã lên cao hơn rốn một chút, và bụng mẹ đã lộ rõ. Khi da bụng căng ra, mẹ có thể thấy căng, ngứa hoặc xuất hiện vết rạn. Một loại kem dưỡng ẩm dịu nhẹ, không mùi có thể giúp da dễ chịu hơn.",
        "Ợ nóng, táo bón và đau lưng khá thường gặp ở giai đoạn này. Nội tiết thai kỳ làm các cơ giãn ra, còn tử cung lớn dần thì chèn vào các cơ quan xung quanh. Một số mẹ bị chuột rút chân về đêm, hoặc thỉnh thoảng thấy bụng gò cứng trong vài giây. Những cơn gò này thường không đau và không đều.",
        "Ngứa rất nhiều, nhất là ở lòng bàn tay hay lòng bàn chân, thì lại khác. Mẹ hãy báo cho bác sĩ hoặc nữ hộ sinh, vì mẹ có thể cần làm xét nghiệm máu."
      ]
    },
    "todo": {
      "en": [
        "Many clinics offer a test for gestational diabetes between weeks 24 and 28. Ask your doctor or midwife whether you need it and how to prepare.",
        "This is also a good time to get to know your baby's usual pattern of movements: when they are active and what the movements feel like. If the movements slow down, stop or change, contact your doctor or midwife straight away, day or night. Do not wait until the next day."
      ],
      "vi": [
        "Nhiều cơ sở y tế làm xét nghiệm tầm soát tiểu đường thai kỳ trong khoảng tuần 24 đến 28. Mẹ hãy hỏi bác sĩ hoặc nữ hộ sinh xem mình có cần làm không và cần chuẩn bị thế nào.",
        "Đây cũng là lúc mẹ làm quen với nhịp cử động thường ngày của bé: bé hay cử động vào lúc nào và cảm giác ra sao. Nếu bé cử động ít đi, ngừng hẳn hoặc khác mọi ngày, mẹ hãy liên hệ bác sĩ hoặc nữ hộ sinh ngay, dù ngày hay đêm. Đừng đợi đến hôm sau."
      ]
    },
    "sources": [1, 2, 4]
  }
}
JSON
```
Expected output:
```
week 24 en: lead 22, baby 191, mom 204
week 24 vi: lead 28, baby 220, mom 250
```
Run: `scripts/test-core.sh`
Expected: PASS, `Test run with 431 tests`.

- [ ] **Step 2: Strings**

Remove the panel strings the rebuild no longer uses, then add the sheet's strings. The handle labels and headings come from spec §3.3 and §4.3; the size-line templates from §4.2.
```bash
scripts/add-strings.py --remove week.headline week.sizeLine week.typicalRange week.about
scripts/add-strings.py <<'JSON'
{
  "weekArticle.tab.baby": ["Baby", "Bé"],
  "weekArticle.tab.mom": ["You", "Mẹ"],
  "weekArticle.heading.size": ["How big is your baby?", "Bé lớn cỡ nào?"],
  "weekArticle.heading.development": ["How your baby is developing", "Bé phát triển ra sao"],
  "weekArticle.heading.body": ["Your body this week", "Cơ thể mẹ tuần này"],
  "weekArticle.heading.todo": ["What you can do", "Mẹ nên làm gì"],
  "weekArticle.references": ["References", "Tài liệu tham khảo"],
  "weekArticle.handle.expand": ["Expand article", "Mở rộng bài viết"],
  "weekArticle.handle.collapse": ["Collapse article", "Thu gọn bài viết"],
  "weekArticle.size.length": ["Your baby is about %1$@ long from head to bottom, roughly the size of %2$@.", "Bé dài khoảng %1$@ (từ đầu đến mông), cỡ %2$@."],
  "weekArticle.size.lengthWeight": ["Your baby is about %1$@ long from head to bottom and weighs about %2$@, roughly the size of %3$@.", "Bé dài khoảng %1$@ (từ đầu đến mông) và nặng khoảng %2$@, cỡ %3$@."],
  "weekArticle.size.weight": ["Your baby weighs about %1$@ (typically %2$@ to %3$@), roughly the size of %4$@.", "Bé nặng khoảng %1$@ (thường từ %2$@ đến %3$@), cỡ %4$@."]
}
JSON
```
Expected: `425 strings`, then `437 strings`. The three `weekArticle.size.*` values must stay identical to the templates in `WeekSizeLineTests` (Task 1).

In `Shared/L10n.swift`, replace:
```swift
    static func weekChip(_ week: Int) -> String { String(format: t("week.chip"), week) }
    static func weekHeadline(_ week: Int) -> String { String(format: t("week.headline"), week) }
    static var weekReviewer: String { t("week.reviewer") }
    static var weekReviewed: String { t("week.reviewed") }
    static func weekSizeLine(_ fruit: String) -> String { String(format: t("week.sizeLine"), fruit) }
    static func weekTypicalRange(_ range: String) -> String { String(format: t("week.typicalRange"), range) }
    static var commonClose: String { t("common.close") }
    /// "About 600 g": the Hadlock 50th percentile is an estimate, not a measurement.
    static func weekAbout(_ value: String) -> String { String(format: t("week.about"), value) }
```
with:
```swift
    static func weekChip(_ week: Int) -> String { String(format: t("week.chip"), week) }
    static var weekReviewer: String { t("week.reviewer") }
    static var weekReviewed: String { t("week.reviewed") }
    static var commonClose: String { t("common.close") }

    // MARK: - Phase 6: week article sheet

    static var weekArticleTabBaby: String { t("weekArticle.tab.baby") }
    static var weekArticleTabMom: String { t("weekArticle.tab.mom") }
    static var weekArticleSizeHeading: String { t("weekArticle.heading.size") }
    static var weekArticleDevelopmentHeading: String { t("weekArticle.heading.development") }
    static var weekArticleBodyHeading: String { t("weekArticle.heading.body") }
    static var weekArticleTodoHeading: String { t("weekArticle.heading.todo") }
    static var weekArticleReferences: String { t("weekArticle.references") }
    static var weekArticleExpand: String { t("weekArticle.handle.expand") }
    static var weekArticleCollapse: String { t("weekArticle.handle.collapse") }
    /// Format strings for `WeekSizeLine.Templates`; KickCore fills them in.
    static var weekArticleSizeLengthFormat: String { t("weekArticle.size.length") }
    static var weekArticleSizeLengthWeightFormat: String { t("weekArticle.size.lengthWeight") }
    static var weekArticleSizeWeightFormat: String { t("weekArticle.size.weight") }
```

- [ ] **Step 3: Artwork fallbacks**

`App/Pregnancy/WeekArtwork.swift` (whole file):
```swift
import KickCore
import SwiftUI
import UIKit

/// Per-week artwork with fallbacks (phase 6 spec §3.2, §4.3): `Fetus-W##` or the
/// shared `Fetus` image; `Fruit-W##` or nil (the caller shows the size emoji).
enum WeekArtwork {
    static func fetus(_ week: Int) -> Image {
        let name = WeekArtworkName.fetus(week: week)
        return UIImage(named: name) == nil ? Image("Fetus") : Image(name)
    }

    static func fruit(_ week: Int) -> Image? {
        let name = WeekArtworkName.fruit(week: week)
        return UIImage(named: name) == nil ? nil : Image(name)
    }
}
```

- [ ] **Step 4: The tab content**

`App/Pregnancy/WeekArticleView.swift` (whole file):
```swift
import KickCore
import SwiftUI

extension WeekSizeLine.Templates {
    /// The `weekArticle.size.*` strings in the app's language.
    static var localized: Self {
        Self(
            length: L10n.weekArticleSizeLengthFormat,
            lengthAndWeight: L10n.weekArticleSizeLengthWeightFormat,
            weightAndRange: L10n.weekArticleSizeWeightFormat
        )
    }
}

extension WeekSizeLine.Numbers {
    /// `Formatting`'s numbers; `spoken` spells the units out for VoiceOver.
    static func formatted(spoken: Bool) -> Self {
        Self(
            length: { Formatting.crownRumpLength(mm: $0, spoken: spoken) },
            weight: { Formatting.weight(grams: $0, spoken: spoken) },
            rangeLow: { Formatting.weightRangeStart($0, unitOf: $1) },
            rangeHigh: { Formatting.weightInUnit($0, unitOf: $1, spoken: spoken) }
        )
    }
}

/// The selected tab of the week article sheet (phase 6 spec §4.3). Bé: lead,
/// artwork, "Bé lớn cỡ nào?", "Bé phát triển ra sao", references. Mẹ: "Cơ thể
/// mẹ tuần này", "Mẹ nên làm gì", the warnings (anchor `weekWarnings`),
/// references. A week without an article shows the bullet lists instead.
struct WeekArticleView: View {
    static let warningsAnchor = "weekWarnings"

    let content: WeekContent
    let tab: ArticleTab
    /// `PregnancyContent.sources`.
    let sources: [String]
    let language: ContentLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch tab {
            case .baby: babyTab
            case .mom: momTab
            }
            references
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Bé

    @ViewBuilder
    private var babyTab: some View {
        if let article = content.article {
            Text(article.lead.text(language))
                .font(.luna(.cardTitle))
                .foregroundStyle(.luna(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("weekArticleLead")
        }
        artworkRow
        ArticleHeading(L10n.weekArticleSizeHeading)
        sizeLine
        if let article = content.article {
            ArticleParagraphs(article.sizeNote.paragraphs(language))
        }
        footnote
        if let article = content.article {
            ArticleHeading(L10n.weekArticleDevelopmentHeading)
            ArticleParagraphs(article.development.paragraphs(language))
        } else {
            WeekSection(title: L10n.weekBaby, items: content.baby.items(language))
        }
    }

    /// Fetus and fruit side by side; decorative.
    private var artworkRow: some View {
        HStack(spacing: 12) {
            Color.luna(.pregSoft)
                .aspectRatio(1, contentMode: .fit)
                .overlay(WeekArtwork.fetus(content.week).resizable().scaledToFit().padding(16))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            Color.luna(.fertileSoft)
                .aspectRatio(1, contentMode: .fit)
                .overlay { fruit }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(.top, content.article == nil ? 4 : 18)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var fruit: some View {
        if let image = WeekArtwork.fruit(content.week) {
            image.resizable().scaledToFit().padding(16)
        } else {
            Text(content.size.emoji)
                .font(.system(size: 64))
                .frame(width: 120, height: 120)
                .background(Circle().fill(Color.luna(.card).opacity(0.6)))
        }
    }

    /// The generated sentence (spec §4.2); VoiceOver reads the spoken units.
    @ViewBuilder
    private var sizeLine: some View {
        if let line = WeekSizeLine.make(for: content, language: language, templates: .localized, numbers: .formatted(spoken: false)) {
            let spoken = WeekSizeLine.make(for: content, language: language, templates: .localized, numbers: .formatted(spoken: true))
            Text(line)
                .font(.luna(.articleBody))
                .lineSpacing(4)
                .foregroundStyle(.luna(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .accessibilityLabel(spoken ?? line)
                .accessibilityIdentifier("weekSizeLine")
        }
    }

    /// "Hadlock's standard ends at week 40." (weeks 41–42) and the estimate note.
    @ViewBuilder
    private var footnote: some View {
        if content.weightG != nil {
            VStack(alignment: .leading, spacing: 2) {
                if content.weightBeyondStandard {
                    Text(L10n.pregnancyBabyStandardEnds(WeekContent.weightStandardLastWeek))
                }
                Text(L10n.pregnancyBabyEstimateNote)
            }
            .font(.luna(.small))
            .foregroundStyle(.luna(.textSecondary))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 10)
        }
    }

    // MARK: Mẹ

    @ViewBuilder
    private var momTab: some View {
        if let article = content.article {
            ArticleHeading(L10n.weekArticleBodyHeading)
            ArticleParagraphs(article.body.paragraphs(language))
            ArticleHeading(L10n.weekArticleTodoHeading)
            ArticleParagraphs(article.todo.paragraphs(language))
        } else {
            WeekSection(title: L10n.weekMom, items: content.mom.items(language))
            WeekSection(title: L10n.weekTips, items: content.tips.items(language))
        }
        WarningSection(items: content.warnings.items(language))
            .id(Self.warningsAnchor)
    }

    // MARK: References

    /// The article's sources, or every source for a week without an article.
    private var referenceList: [String] {
        guard let article = content.article else { return sources }
        return article.sources.compactMap { sources.indices.contains($0) ? sources[$0] : nil }
    }

    @ViewBuilder
    private var references: some View {
        if !referenceList.isEmpty {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(referenceList, id: \.self) { source in
                        Text(verbatim: source)
                            .font(.luna(.small))
                            .foregroundStyle(.luna(.textSecondary))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
            } label: {
                Text(L10n.weekArticleReferences)
                    .font(.luna(.captionStrong))
                    .foregroundStyle(.luna(.textPrimary))
            }
            .tint(.luna(.textSecondary))
            .padding(.top, 26)
            .accessibilityIdentifier("weekReferences")
        }
    }
}

/// A section heading (headline style, header trait).
private struct ArticleHeading: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.luna(.cardTitle))
            .foregroundStyle(.luna(.textPrimary))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 22)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Body paragraphs, line spacing 4 (spec §4.3).
private struct ArticleParagraphs: View {
    let paragraphs: [String]

    init(_ paragraphs: [String]) {
        self.paragraphs = paragraphs
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(.luna(.articleBody))
                    .lineSpacing(4)
                    .foregroundStyle(.luna(.articleText))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 8)
    }
}

/// The bullet fallback for a week without an article.
private struct WeekSection: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.luna(.cardTitle))
                .foregroundStyle(.luna(.textPrimary))
                .accessibilityAddTraits(.isHeader)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: "•").accessibilityHidden(true)
                    Text(item).fixedSize(horizontal: false, vertical: true)
                }
                .font(.luna(.articleBody))
                .lineSpacing(5)
                .foregroundStyle(.luna(.articleText))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 22)
        .accessibilityElement(children: .combine)
    }
}

/// "When to get care right away" in the warning colours (unchanged from phase 5).
private struct WarningSection: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L10n.weekWarnings, systemImage: "exclamationmark.triangle.fill")
                .font(.luna(.cardTitleSmall))
                .foregroundStyle(.luna(.warningText))
            ForEach(items, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: "•").accessibilityHidden(true)
                    Text(item).fixedSize(horizontal: false, vertical: true)
                }
                .font(.luna(.body))
                .foregroundStyle(.luna(.articleText))
            }
        }
        .lunaCard(.warningBackground, border: .warningBorder, padding: 16)
        .padding(.top, 22)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("weekWarnings")
    }
}
```

- [ ] **Step 5: Rebuild `WeekDetailView`**

`App/Pregnancy/WeekDetailView.swift` (whole file):
```swift
import KickCore
import SwiftUI

/// The week opened from Today (fetus, "This week", baby and tips cards).
struct WeekSelection: Identifiable, Equatable {
    let week: Int
    var id: Int { week }
}

/// The week chips' bottom edge in the week detail's coordinate space.
private struct WeekChipsBottomKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Full-screen week detail, weeks 4…42 (phase 6 spec §3). The background holds
/// the ✕ button, a large fetus image and the week chips; a horizontal swipe on it
/// changes the week. The article sheet sits on top with two detents: peek (below
/// the chips) and expanded. From the symptoms safety card it opens expanded, on
/// the Mẹ tab, scrolled to "When to get care right away" (spec §3.6).
struct WeekDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.contentLibrary) private var library
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selection: Int
    @State private var tab: ArticleTab
    @State private var detent: SheetDetent
    @State private var progress: Double
    @State private var chipsBottom: CGFloat = 0
    private let scrollToWarnings: Bool
    private let language = ContentLanguage.current

    private static let space = "weekDetail"
    /// The sheet's top edge when expanded: 8 pt below the top safe area (spec §3.4).
    private static let expandedTop: CGFloat = 8
    /// Room for the ✕ button above the fetus.
    private static let closeRowHeight: CGFloat = 52

    init(currentWeek: Int, scrollToWarnings: Bool = false) {
        _selection = State(initialValue: WeeklyContentLibrary.clampedWeek(currentWeek))
        _tab = State(initialValue: scrollToWarnings ? .mom : .baby)
        _detent = State(initialValue: scrollToWarnings ? .expanded : .peek)
        _progress = State(initialValue: scrollToWarnings ? 1 : 0)
        self.scrollToWarnings = scrollToWarnings
    }

    private var display: WeekDisplay? {
        library?.display(forWeek: selection, visibility: BuildFlags.contentVisibility)
    }

    /// Chips' bottom + 12 pt (spec §3.4); 55 % of the height until measured;
    /// never so low that the handle, title and tabs leave the screen.
    private static func peekTop(chipsBottom: CGFloat, height: CGFloat) -> CGFloat {
        let measured = chipsBottom > 0 ? chipsBottom + 12 : height * 0.55
        return min(measured, height - 220)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                backgroundLayer(height: proxy.size.height)
                ArticleSheet(
                    detent: $detent,
                    progress: $progress,
                    peekTop: Self.peekTop(chipsBottom: chipsBottom, height: proxy.size.height),
                    expandedTop: Self.expandedTop,
                    containerHeight: proxy.size.height,
                    bottomInset: proxy.safeAreaInsets.bottom,
                    resetKey: "\(selection)-\(tab.rawValue)",
                    initialAnchor: scrollToWarnings ? WeekArticleView.warningsAnchor : nil,
                    handleIdentifier: "weekSheetHandle",
                    scrollIdentifier: "weekArticleScroll",
                    handleLabel: { $0 == .peek ? L10n.weekArticleExpand : L10n.weekArticleCollapse }
                ) {
                    sheetHeader
                } content: {
                    sheetContent
                }
                closeButton
            }
            .coordinateSpace(.named(Self.space))
            .onPreferenceChange(WeekChipsBottomKey.self) { value in
                MainActor.assumeIsolated { chipsBottom = value }
            }
        }
        .background {
            LinearGradient(
                stops: [
                    .init(color: .luna(.heroTop), location: 0),
                    .init(color: .luna(.heroMiddle), location: 0.45),
                    .init(color: .luna(.background), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        // VoiceOver two-finger scrub closes the cover, like the ✕ button.
        .accessibilityAction(.escape) { dismiss() }
        .onAppear {
            // Accessibility text sizes open expanded (spec §3.4).
            if dynamicTypeSize.isAccessibilitySize, detent == .peek {
                detent = .expanded
                progress = 1
            }
        }
    }

    // MARK: Background

    private func backgroundLayer(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: Self.closeRowHeight)
            WeekArtwork.fetus(selection)
                .resizable()
                .scaledToFit()
                .padding(28)
                .background(
                    RadialGradient(
                        colors: [Color.luna(.card).opacity(0.7), Color.luna(.card).opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 150
                    )
                    .clipShape(Circle())
                )
                .frame(height: min(height * 0.36, 320))
                .frame(maxWidth: .infinity)
                .opacity(1 - progress)
                .scaleEffect(reduceMotion ? 1 : 1 - 0.1 * progress)
                .accessibilityHidden(true)
            ChipScroller(
                values: Array(WeeklyContentLibrary.weekRange),
                selection: $selection,
                title: { L10n.weekChip($0) },
                identifier: { "weekChip-\($0)" },
                accessibilityTitle: { L10n.weekTitle($0) }
            )
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(key: WeekChipsBottomKey.self, value: geometry.frame(in: .named(Self.space)).maxY)
                }
            }
            .opacity(1 - progress)
            .padding(.top, 8)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 30).onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 2 else { return }
                changeWeek(by: value.translation.width < 0 ? 1 : -1)
            }
        )
        // Under the expanded sheet, VoiceOver must not reach the chips.
        .accessibilityHidden(detent == .expanded)
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.luna(.textPrimary))
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.luna(.card).opacity(0.55)))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.commonClose)
        .accessibilityIdentifier("weekDetailClose")
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    // MARK: Sheet

    private var sheetHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.weekTitle(selection))
                .font(.luna(.sheetTitle))
                .foregroundStyle(.luna(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("weekDetailTitle")
            if case .content(_, let pendingReview)? = display {
                reviewer(pendingReview: pendingReview)
                SegmentedPill(
                    options: [
                        SegmentedOption(value: ArticleTab.baby, title: L10n.weekArticleTabBaby, identifier: "weekTab-baby"),
                        SegmentedOption(value: ArticleTab.mom, title: L10n.weekArticleTabMom, identifier: "weekTab-mom"),
                    ],
                    selection: $tab
                )
                .padding(.top, 14)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.bottom, 14)
    }

    private func reviewer(pendingReview: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "stethoscope")
                .font(.system(size: 15, weight: .medium))
                // articleText, not textSecondary: drawn on `surface` (AA rule).
                .foregroundStyle(.luna(.articleText))
                .frame(width: 38, height: 38)
                .background(Circle().fill(.luna(.surface)))
            VStack(alignment: .leading, spacing: 0) {
                Text(L10n.weekReviewer)
                    .font(.luna(.small))
                    .foregroundStyle(.luna(.textSecondary))
                // No doctor's name yet (spec §4.6).
                Text(pendingReview ? L10n.weekPendingReview : L10n.weekReviewed)
                    .font(.luna(.label))
                    .foregroundStyle(.luna(.textPrimary))
            }
        }
        .padding(.top, 10)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("weekReviewer")
    }

    /// Cross-fades over 0.2 s when the week changes; instant under Reduce Motion or in UI tests.
    private var sheetContent: some View {
        ZStack(alignment: .topLeading) {
            Group {
                switch display {
                case .content(let content, _)?:
                    WeekArticleView(content: content, tab: tab, sources: library?.sources ?? [], language: language)
                case .underReview?:
                    UnderReviewCard()
                case nil:
                    EmptyView()
                }
            }
            .id(selection)
            .transition(.opacity)
        }
        .animation(LunaMotion.isEnabled && !reduceMotion ? LunaMotion.fade : nil, value: selection)
    }

    private func changeWeek(by offset: Int) {
        let week = selection + offset
        guard WeeklyContentLibrary.weekRange.contains(week) else { return }
        selection = week
    }
}
```
- [ ] **Step 6: Update the existing week-detail UI tests**

In `UITests/PregnancyTodayUITests.swift`, replace **both** occurrences of:
```swift
        XCTAssertTrue(app.staticTexts["weekHeadline"].waitForExistence(timeout: 5))
```
with:
```swift
        XCTAssertTrue(app.staticTexts["weekDetailTitle"].waitForExistence(timeout: 5))
```
and replace:
```swift
        app.buttons["weekChip-25"].tap()
        waitForLabel(title, containing: "Week 25")
        XCTAssertEqual(app.staticTexts["weekHeadline"].label, "What happens at 25 weeks")
```
with:
```swift
        app.buttons["weekChip-25"].tap()
        waitForLabel(title, containing: "Week 25")
        XCTAssertEqual(app.buttons["weekSheetHandle"].label, "Expand article") // still at peek
```

In `UITests/PregnancyScreenshotTests.swift`, replace (inside `testWeek12DetailScreens`):
```swift
            babyCard.tap()
            XCTAssertTrue(app.descendants(matching: .any)["weekWarnings"].firstMatch.waitForExistence(timeout: 5))
            attachScreenshot(app, "week-12-\(language)-light")
```
with:
```swift
            babyCard.tap()
            let sizeLine = app.staticTexts["weekSizeLine"]
            XCTAssertTrue(sizeLine.waitForExistence(timeout: 5))
            if language == "en" {
                XCTAssertTrue(sizeLine.label.contains("53.5"), sizeLine.label)
            }
            app.buttons["weekSheetHandle"].tap()
            attachScreenshot(app, "week-12-\(language)-light")
```
and delete the whole `testWeekDetailScreens` function (now covered by `WeekArticleScreenshotTests`):
```swift
    @MainActor
    func testWeekDetailScreens() {
        for (language, dark) in UITestVariants.all {
            let suffix = UITestVariants.suffix(language, dark)
            let app = XCUIApplication.launchPinned(language: language, dark: dark, dueDate: UITestDates.dueAtWeek24)
            let babyCard = app.buttons["babySizeCard"]
            XCTAssertTrue(babyCard.waitForExistence(timeout: 10))
            app.scrollUntilHittable(babyCard)
            babyCard.tap()
            XCTAssertTrue(app.descendants(matching: .any)["weekWarnings"].firstMatch.waitForExistence(timeout: 5))
            attachScreenshot(app, "week-24-\(suffix)")
            app.swipeUp()
            attachScreenshot(app, "week-24-warnings-\(suffix)")
            if language == "vi", !dark {
                app.swipeDown()
                app.swipeDown()
                app.buttons["weekChip-25"].tap()
                waitForLabel(app.staticTexts["weekDetailTitle"], containing: "Tuần 25")
                attachScreenshot(app, "week-25-vi-light")
            }
            app.terminate()
        }
    }

```
`UITests/PregnancySymptomsUITests.swift` needs no edit: `testContractionsShowTheSafetyCardAndOpenTheWarnings` still expects `weekWarnings` to become hittable and `weekDetailTitle` to read "Week 24"; it runs in this task's CI scope to prove it.

- [ ] **Step 7: New UI tests**

`UITests/WeekArticleSheetUITests.swift` (whole file):
```swift
import XCTest

/// Phase 6 spec §3 and §6: the week detail's article sheet.
final class WeekArticleSheetUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Today (week 24) → fetus → week detail.
    @MainActor
    private func openWeek24(language: String = "en", largestText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication.launchPinned(language: language, dueDate: UITestDates.dueAtWeek24, largestText: largestText)
        let fetus = app.buttons["fetusHeroButton"]
        XCTAssertTrue(fetus.waitForExistence(timeout: 10))
        fetus.tap()
        XCTAssertTrue(app.buttons["weekSheetHandle"].waitForExistence(timeout: 5))
        return app
    }

    /// §3.4: opens at peek on the Bé tab; the chips stay reachable above the sheet.
    @MainActor
    func testOpensAtPeekOnTheBabyTab() {
        let app = openWeek24()
        XCTAssertEqual(app.buttons["weekSheetHandle"].label, "Expand article")
        XCTAssertEqual(app.staticTexts["weekDetailTitle"].label, "Week 24")
        XCTAssertTrue(app.buttons["weekTab-baby"].isSelected)
        XCTAssertFalse(app.buttons["weekTab-mom"].isSelected)
        XCTAssertTrue(app.buttons["weekChip-24"].isHittable)
        XCTAssertTrue(app.staticTexts["weekArticleLead"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["weekWarnings"].exists)
    }

    /// §3.3: tapping the handle expands the sheet and changes its label; tapping again collapses it.
    @MainActor
    func testHandleTogglesTheDetent() {
        let app = openWeek24()
        let handle = app.buttons["weekSheetHandle"]
        handle.tap()
        waitForLabel(handle, containing: "Collapse article")
        XCTAssertFalse(app.buttons["weekChip-24"].exists) // hidden under the expanded sheet
        handle.tap()
        waitForLabel(handle, containing: "Expand article")
        XCTAssertTrue(app.buttons["weekChip-24"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["weekChip-24"].isHittable)
    }

    /// §4.3: the Mẹ tab holds the warnings.
    @MainActor
    func testMomTabShowsTheWarnings() {
        let app = openWeek24()
        app.buttons["weekTab-mom"].tap()
        XCTAssertTrue(app.buttons["weekTab-mom"].isSelected)
        XCTAssertTrue(app.descendants(matching: .any)["weekWarnings"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Your body this week"].exists)
        XCTAssertFalse(app.staticTexts["weekArticleLead"].exists)
    }

    /// §3.5: a chip changes the week; the tab and the detent are kept.
    @MainActor
    func testChangingWeekKeepsTheTabAndDetent() {
        let app = openWeek24()
        app.buttons["weekTab-mom"].tap()
        app.buttons["weekChip-25"].tap()
        waitForLabel(app.staticTexts["weekDetailTitle"], containing: "Week 25")
        XCTAssertTrue(app.buttons["weekTab-mom"].isSelected)
        XCTAssertEqual(app.buttons["weekSheetHandle"].label, "Expand article")
        XCTAssertTrue(app.descendants(matching: .any)["weekWarnings"].firstMatch.waitForExistence(timeout: 5))
    }

    /// §3.5: pulling down on the expanded article at its top hands the drag to the sheet.
    @MainActor
    func testPullingDownAtTheTopOfTheArticleCollapses() {
        let app = openWeek24()
        let handle = app.buttons["weekSheetHandle"]
        handle.tap()
        waitForLabel(handle, containing: "Collapse article")
        app.scrollViews["weekArticleScroll"].swipeDown()
        waitForLabel(handle, containing: "Expand article")
    }

    /// §3.6: from the symptoms safety card the sheet is expanded, on Mẹ, at the warnings.
    @MainActor
    func testSafetyCardOpensTheWarningsExpanded() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        app.openPregnancySymptoms()
        app.buttons["symptomsLogToday"].tap()
        let contractions = app.buttons["symptomChip-contractions"]
        XCTAssertTrue(contractions.waitForExistence(timeout: 5))
        app.scrollUntilHittable(contractions)
        contractions.tap()
        let action = app.buttons["symptomSafetyAction"]
        app.scrollUntilHittable(action)
        action.tap()

        let handle = app.buttons["weekSheetHandle"]
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        XCTAssertEqual(handle.label, "Collapse article")
        XCTAssertTrue(app.buttons["weekTab-mom"].isSelected)
        let warnings = app.descendants(matching: .any)["weekWarnings"].firstMatch
        let inView = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: warnings)
        XCTAssertEqual(XCTWaiter().wait(for: [inView], timeout: 5), .completed)
    }

    /// §3.4: accessibility text sizes open the sheet expanded.
    @MainActor
    func testLargestTextOpensExpanded() {
        let app = openWeek24(largestText: true)
        waitForLabel(app.buttons["weekSheetHandle"], containing: "Collapse article")
    }
}
```

`UITests/WeekArticleScreenshotTests.swift` (whole file):
```swift
import XCTest

/// Phase 6 spec §6: screenshots of the week article sheet (week 24, pinned clock).
final class WeekArticleScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openWeek24(language: String, dark: Bool = false, largestText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication.launchPinned(language: language, dark: dark, dueDate: UITestDates.dueAtWeek24, largestText: largestText)
        let fetus = app.buttons["fetusHeroButton"]
        XCTAssertTrue(fetus.waitForExistence(timeout: 10))
        fetus.tap()
        XCTAssertTrue(app.buttons["weekSheetHandle"].waitForExistence(timeout: 5))
        return app
    }

    /// Peek and expanded × Bé and Mẹ, vi light; then week 25 from its chip.
    @MainActor
    func testVietnameseLightPeekAndExpanded() {
        let app = openWeek24(language: "vi")
        let handle = app.buttons["weekSheetHandle"]
        attachScreenshot(app, "week-article-peek-baby-vi-light")
        handle.tap()
        waitForLabel(handle, containing: "Thu gọn bài viết")
        attachScreenshot(app, "week-article-expanded-baby-vi-light")
        app.swipeUp()
        attachScreenshot(app, "week-article-expanded-baby-vi-light-scrolled")
        app.buttons["weekTab-mom"].tap()
        let warnings = app.descendants(matching: .any)["weekWarnings"].firstMatch
        XCTAssertTrue(warnings.waitForExistence(timeout: 5))
        attachScreenshot(app, "week-article-expanded-mom-vi-light")
        app.scrollUntilHittable(warnings)
        attachScreenshot(app, "week-article-warnings-vi-light")
        handle.tap()
        waitForLabel(handle, containing: "Mở rộng bài viết")
        attachScreenshot(app, "week-article-peek-mom-vi-light")
        app.buttons["weekChip-25"].tap()
        waitForLabel(app.staticTexts["weekDetailTitle"], containing: "Tuần 25")
        attachScreenshot(app, "week-article-25-vi-light")
    }

    @MainActor
    func testEnglishDark() {
        let app = openWeek24(language: "en", dark: true)
        let handle = app.buttons["weekSheetHandle"]
        attachScreenshot(app, "week-article-peek-baby-en-dark")
        handle.tap()
        waitForLabel(handle, containing: "Collapse article")
        attachScreenshot(app, "week-article-expanded-baby-en-dark")
        app.buttons["weekTab-mom"].tap()
        let warnings = app.descendants(matching: .any)["weekWarnings"].firstMatch
        XCTAssertTrue(warnings.waitForExistence(timeout: 5))
        attachScreenshot(app, "week-article-expanded-mom-en-dark")
        app.scrollUntilHittable(warnings)
        attachScreenshot(app, "week-article-warnings-en-dark")
    }

    /// AX5 opens expanded; nothing is cut.
    @MainActor
    func testLargestText() {
        let app = openWeek24(language: "vi", largestText: true)
        let handle = app.buttons["weekSheetHandle"]
        waitForLabel(handle, containing: "Thu gọn bài viết")
        attachScreenshot(app, "week-article-vi-ax5")
        app.swipeUp()
        attachScreenshot(app, "week-article-vi-ax5-scrolled")
        app.buttons["weekTab-mom"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["weekWarnings"].firstMatch.waitForExistence(timeout: 5))
        attachScreenshot(app, "week-article-mom-vi-ax5")
    }

    /// Opened from the symptoms safety card: expanded, Mẹ, at the warnings.
    @MainActor
    func testFromTheSafetyCard() {
        let app = XCUIApplication.launchPinned(language: "vi", dueDate: UITestDates.dueAtWeek24)
        app.openPregnancySymptoms()
        app.buttons["symptomsLogToday"].tap()
        let contractions = app.buttons["symptomChip-contractions"]
        XCTAssertTrue(contractions.waitForExistence(timeout: 5))
        app.scrollUntilHittable(contractions)
        contractions.tap()
        let action = app.buttons["symptomSafetyAction"]
        app.scrollUntilHittable(action)
        action.tap()
        let warnings = app.descendants(matching: .any)["weekWarnings"].firstMatch
        let inView = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: warnings)
        XCTAssertEqual(XCTWaiter().wait(for: [inView], timeout: 5), .completed)
        attachScreenshot(app, "week-article-from-safety-vi-light")
    }
}
```

- [ ] **Step 8: Build**

```bash
scripts/test-core.sh
xcodegen generate --quiet
xcodebuild -project KickCounter.xcodeproj -scheme KickCounter \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO -quiet build-for-testing
```
Expected: `Test run with 431 tests` passed; `xcodebuild` exits 0 with no `.swift:…: error:` lines. `grep -rn "weekHeadline\|weekSizeLine(\|weekTypicalRange\|weekAbout" App Shared UITests` prints nothing.

- [ ] **Step 9: Commit, push, verify CI**

```bash
git add App Shared UITests Packages/KickCore
git commit -F - <<'MSG'
feat(pregnancy): week detail as a draggable article sheet

The fetus and week chips become a fixed background under a two-detent
article sheet with Baby / You tabs. The Baby tab has the lead, the
artwork, a size sentence generated from the Hadlock figures and the
development text; the You tab has the body, what to do and the warning
signs. Weeks without an article fall back to the bullet lists. Week 24
has the first written article. From the symptoms safety card the sheet
opens expanded on the You tab at the warnings.

CI-Only-Testing: WeekArticleSheetUITests, WeekArticleScreenshotTests, PregnancyTodayUITests, PregnancySymptomsUITests, PregnancyScreenshotTests
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED` with all 7 `WeekArticleSheetUITests` and 4 `WeekArticleScreenshotTests`; `PregnancyTodayUITests.testWeekChipsChangeTheWeekAndCloseReturns` and `PregnancySymptomsUITests.testContractionsShowTheSafetyCardAndOpenTheWarnings` still green.

- [ ] **Step 10: Visual check**

Open each PNG in `ci-artifacts/screenshots/` with the Read tool:
- `week-article-peek-baby-vi-light`: hero gradient (peach top fading down); ✕ in a light circle at top left; large fetus image in roughly the top 40 % with a soft glow; chip row "… 24 tuần …" with 24 selected (white capsule) and readable `pregOnSoft` text; the white sheet starts just below the chips with 24 pt rounded top corners; centred grey capsule handle; "Tuần 24" 22/700; stethoscope row "Người xem xét / Nội dung đang chờ bác sĩ duyệt"; segmented pill "Bé | Mẹ" with Bé selected; the bold lead "Phổi của bé đang dần chuẩn bị…" visible.
- `week-article-expanded-baby-vi-light`: sheet top 8 pt under the status bar; ✕ sits over the sheet's top-left corner and does not cover the handle or title; fetus and chips not visible; under the lead: two square tiles (fetus on peach, 🌽 in a circle on mint); "Bé lớn cỡ nào?" heading; "Bé nặng khoảng 670 g (thường từ 556 đến 784 g), cỡ một bắp ngô."; the size note paragraph; small grey "Cân nặng ước tính qua siêu âm có thể chênh lệch khoảng 10–15%.".
- `week-article-expanded-baby-vi-light-scrolled`: "Bé phát triển ra sao" with three paragraphs (line spacing visibly looser than the old bullets); "Tài liệu tham khảo" collapsed with a chevron; header (handle, title, tabs) still fixed at the top.
- `week-article-expanded-mom-vi-light`: Mẹ selected; article scrolled back to the top; "Cơ thể mẹ tuần này" and paragraphs.
- `week-article-warnings-vi-light`: "Mẹ nên làm gì" paragraphs, then the pink warning card "⚠ Khi nào cần đi khám ngay" (dark-red title, bullets).
- `week-article-peek-mom-vi-light`: back at peek, Mẹ still selected, fetus and chips fully visible again (opacity 1, normal size).
- `week-article-25-vi-light`: "Tuần 25", chip 25 selected, Mẹ still selected, sheet at peek; content is the fallback ("Mẹ" and "Lời khuyên" bullet lists) because week 25 has no article yet.
- `week-article-*-en-dark`: dark gradient and dark card `#262019`; "Week 24", "Baby | You", "Your baby weighs about 670 g (typically 556 to 784 g), roughly the size of an ear of corn."; warning card dark red `#4A1E18` with `#FF9C8A` title; all text readable.
- `week-article-vi-ax5`, `-scrolled`, `week-article-mom-vi-ax5`: opened expanded; huge text wraps, nothing cut or overlapping; tabs wrap to two lines if needed; ✕ does not cover the title.
- `week-article-from-safety-vi-light`: expanded, Mẹ selected, warning card at the top of the visible article.
- `week-12-vi-light` / `week-12-en-light`: expanded; "Bé dài khoảng 53,5 mm (từ đầu đến mông) và nặng khoảng 58 g, cỡ một quả kiwi." / "Your baby is about 53.5 mm long from head to bottom and weighs about 58 g, roughly the size of a kiwi."; week 12 has no article yet, so the Bé fallback bullets follow.

---
### Task 4: Content — articles for weeks 4–13

Write original vi + en articles for weeks 4–13 and require them in the bundle test. This task writes prose, not code. Apply the writing guide below to every sentence.

**Files:**
- Modify: `Packages/KickCore/Sources/KickCore/Resources/pregnancy-content.json` (via `scripts/set-week-articles.py` only), `Packages/KickCore/Tests/KickCoreTests/BundledArticleTests.swift` (`requiredArticleWeeks`)

**Interfaces:**
- Consumes: `scripts/set-week-articles.py` (Task 1), `WeekArticleChecks` and `BundledArticleTests` (Task 1), the week's existing `size`, `crlMm`, `weightG`, `baby`, `mom`, `tips`, `warnings` (read-only).
- Produces: `article` for weeks 4–13; `BundledArticleTests.requiredArticleWeeks == 4...13`.

**Writing guide (spec §4.4, verbatim):**

- **Original text only.** No sentence may be copied or closely paraphrased from Flo or any website.
- **Facts** come from the sources listed in `PregnancyContent.sources`.
- **Vietnamese is written natively**, not translated. English is written in parallel and says the same things.
- **Voice:**
  - Vietnamese uses "mẹ" and "bé"; English uses "you" and "your baby".
  - Tone is warm and calm, with short sentences of about 25 words at most.
- **Hedged wording** ("thường", "khoảng", "có thể" / "usually", "about", "may"):
  - no diagnosis;
  - no fear language;
  - no promises about individual babies.
- **Units:** metric only (g, kg, mm, cm). No inch, pound or ounce in either language.
- **Medicine:** no medicine names or doses. Any medical action points to "bác sĩ hoặc nữ hộ sinh" / "your doctor or midwife".
- **Length per tab per language:** 150–300 words (Vietnamese counted in syllables/words split by spaces).
- **Accuracy:** every development claim must fit the week. Reviewers check it against ACOG and NHS week-by-week material.

**Plan rules (in addition to the guide; see "Spec clarifications" 13, 15, 16):**
- `lead` ≤ 30 words (en) / ≤ 40 (vi). Bé tab = `lead` + `sizeNote` + `development`; Mẹ tab = `body` + `todo`; each 150–300 words per language. Aim for en 170–230 and vi 200–280 so edits stay in range.
- `sizeNote` states **no figures** (no g, kg, mm, cm numbers): the generated line above it gives them (weeks 7–42). Weeks 4–6 have no line, so their `sizeNote` describes the size in words, using the week's comparison (`size.vi` / `size.en`).
- `development`: 2–3 paragraphs. `body`: 1–3 paragraphs. `todo`: 1–2 paragraphs.
- Read the week's existing `baby`, `mom`, `tips` and `warnings` bullets first (`python3 -c "import json;w=json.load(open('Packages/KickCore/Sources/KickCore/Resources/pregnancy-content.json'))['weeks'];print(json.dumps([x for x in w if x['week']==7][0],ensure_ascii=False,indent=1))"` — change `7`). The article must not contradict them; Today's cards still show them.
- Do not repeat the warning list in `todo` (the Mẹ tab shows `warnings` right below). One sentence may point to it: "mẹ hãy xem phần dấu hiệu cần đi khám bên dưới" / "see the warning signs below".
- Supplements already named in the bullets (folic acid / axit folic, iron / sắt) may be named **without** a dose, "as your doctor or midwife advises" / "theo hướng dẫn của bác sĩ hoặc nữ hộ sinh". No other medicine or product names; no doses (a test rejects `mg`, `mcg`, `µg`, `IU`).
- Never state a baby's sex, a percentage risk, or that something "will" happen to this baby.
- `sources`: the indices you actually used. 0 = WHO, 1 = ACOG, 2 = NHS, 3 = Bộ Y tế, 4 = Hadlock 1991 (weight, weeks 10–42), 5 = Hadlock 1992 (crown–rump length, weeks 7–13). Required by `sourcesMatchTheWeeksFigures`: weeks 7–13 include 5; weeks 10–13 also include 4; every week includes at least one of 0–3.
- Every Vietnamese text has diacritics; keep `"reviewed": false`.

**JSON shape** (one object per week, keys in this order; the script rejects anything else):
```json
{
  "<week>": {
    "lead": {"en": "<one sentence>", "vi": "<một câu>"},
    "sizeNote": {"en": ["<paragraph>"], "vi": ["<đoạn>"]},
    "development": {"en": ["<p1>", "<p2>", "<p3>"], "vi": ["<đ1>", "<đ2>", "<đ3>"]},
    "body": {"en": ["<p1>", "<p2>"], "vi": ["<đ1>", "<đ2>"]},
    "todo": {"en": ["<p1>"], "vi": ["<đ1>"]},
    "sources": [1, 2]
  }
}
```

**Example — week 24, already in the file since Task 3** (the bar for quality, tone and length; do not reuse its sentences in other weeks):
```json
{
  "24": {
    "lead": {
      "en": "Your baby's lungs are slowly getting ready for breathing after birth, and your baby now has regular times of sleeping and waking.",
      "vi": "Phổi của bé đang dần chuẩn bị cho những hơi thở đầu tiên sau khi chào đời, và bé đã có những khoảng ngủ, thức khá đều đặn."
    },
    "sizeNote": {
      "en": [
        "Your baby is still long and lean. Over the coming weeks, a layer of fat builds up under the skin, and your baby will start to look rounder. Every baby grows at their own pace, so a scan may show a slightly different number."
      ],
      "vi": [
        "Lúc này bé vẫn còn khá thon dài. Trong những tuần tới, một lớp mỡ sẽ dần hình thành dưới da, giúp bé trông tròn trịa hơn. Mỗi bé lớn theo nhịp riêng, nên con số trên siêu âm có thể hơi khác một chút."
      ]
    },
    "development": {
      "en": [
        "Deep inside the lungs, the tiny air sacs and the branches that lead to them keep developing. Some lung cells have started to make surfactant, a substance that will later help the air sacs stay open when your baby breathes. The lungs still have many weeks of growing ahead.",
        "Your baby's inner ear, which helps with balance, is now well formed. Your baby can probably hear your heartbeat, your voice and loud sounds from outside. Some babies wriggle or kick when there is a sudden noise.",
        "The skin is still thin and slightly see-through, so tiny blood vessels show beneath it. Your baby sleeps and wakes in fairly regular cycles, and you may start to notice the times of day when they are most active."
      ],
      "vi": [
        "Sâu bên trong phổi, các túi khí nhỏ li ti cùng những nhánh dẫn khí tới chúng vẫn đang tiếp tục phát triển. Một số tế bào phổi đã bắt đầu tạo ra surfactant, chất sau này giúp các túi khí không bị xẹp khi bé thở. Phổi của bé còn nhiều tuần nữa để hoàn thiện.",
        "Tai trong, bộ phận giúp bé giữ thăng bằng, nay đã hình thành khá đầy đủ. Bé có thể nghe được nhịp tim, giọng nói của mẹ và cả những âm thanh lớn bên ngoài. Có bé còn cựa mình hoặc đạp khi nghe tiếng động bất ngờ.",
        "Da bé vẫn mỏng và hơi trong, nên có thể thấy những mạch máu nhỏ bên dưới. Bé ngủ và thức theo chu kỳ khá đều, và mẹ có thể dần nhận ra những lúc trong ngày bé hay cử động nhất."
      ]
    },
    "body": {
      "en": [
        "The top of your womb is now a little above your belly button, and your bump is easy to see. As the skin stretches, it may feel tight or itchy, and stretch marks may appear. A gentle, unscented moisturiser can make it feel more comfortable.",
        "Heartburn, constipation and backache are common at this stage. Pregnancy hormones relax your muscles, and your growing womb presses on the organs around it. Some people get leg cramps at night, or feel the bump tighten for a few seconds now and then. These tightenings are usually painless and irregular.",
        "Very strong itching, especially on the palms of your hands or the soles of your feet, is different. Tell your doctor or midwife about it, as you may need a blood test."
      ],
      "vi": [
        "Đáy tử cung lúc này đã lên cao hơn rốn một chút, và bụng mẹ đã lộ rõ. Khi da bụng căng ra, mẹ có thể thấy căng, ngứa hoặc xuất hiện vết rạn. Một loại kem dưỡng ẩm dịu nhẹ, không mùi có thể giúp da dễ chịu hơn.",
        "Ợ nóng, táo bón và đau lưng khá thường gặp ở giai đoạn này. Nội tiết thai kỳ làm các cơ giãn ra, còn tử cung lớn dần thì chèn vào các cơ quan xung quanh. Một số mẹ bị chuột rút chân về đêm, hoặc thỉnh thoảng thấy bụng gò cứng trong vài giây. Những cơn gò này thường không đau và không đều.",
        "Ngứa rất nhiều, nhất là ở lòng bàn tay hay lòng bàn chân, thì lại khác. Mẹ hãy báo cho bác sĩ hoặc nữ hộ sinh, vì mẹ có thể cần làm xét nghiệm máu."
      ]
    },
    "todo": {
      "en": [
        "Many clinics offer a test for gestational diabetes between weeks 24 and 28. Ask your doctor or midwife whether you need it and how to prepare.",
        "This is also a good time to get to know your baby's usual pattern of movements: when they are active and what the movements feel like. If the movements slow down, stop or change, contact your doctor or midwife straight away, day or night. Do not wait until the next day."
      ],
      "vi": [
        "Nhiều cơ sở y tế làm xét nghiệm tầm soát tiểu đường thai kỳ trong khoảng tuần 24 đến 28. Mẹ hãy hỏi bác sĩ hoặc nữ hộ sinh xem mình có cần làm không và cần chuẩn bị thế nào.",
        "Đây cũng là lúc mẹ làm quen với nhịp cử động thường ngày của bé: bé hay cử động vào lúc nào và cảm giác ra sao. Nếu bé cử động ít đi, ngừng hẳn hoặc khác mọi ngày, mẹ hãy liên hệ bác sĩ hoặc nữ hộ sinh ngay, dù ngày hay đêm. Đừng đợi đến hôm sau."
      ]
    },
    "sources": [1, 2, 4]
  }
}
```
Its counts: en lead 22, Bé 191, Mẹ 204; vi lead 28, Bé 220, Mẹ 250.

**Fact checklist, weeks 4–13** (key milestones from ACOG and NHS week-by-week material, aligned with the reviewed bullets and the doctor-review points in `docs/content-review-for-doctor.md` §2–3; cover each listed fact, add nothing that contradicts it):

- **Week 4** — no size line; `sizeNote` in words ("a poppy seed" / "một hạt anh túc"). Sources `[0, 1, 2]`.
  - Bé: the fertilised egg (a ball of cells) has implanted in the womb lining; the inner cells will become the embryo, the outer cells the placenta; the amniotic sac and the yolk sac (early nourishment) begin to form. Pregnancy weeks are counted from the first day of the last period, so conception was about two weeks ago.
  - Mẹ: the period is late; a home test may now be positive; light spotting, mild cramps, tiredness or tender breasts are possible; many feel nothing yet.
  - Làm: folic acid as the doctor or midwife advises (no dose); stop alcohol and smoking, avoid second-hand smoke; check any medicines with a doctor or pharmacist; book a first appointment.
  - Avoid: any heartbeat claim; calling a test result certain.
- **Week 5** — no size line; `sizeNote` in words ("a sesame seed" / "một hạt vừng"). Sources `[0, 1, 2]`.
  - Bé: the embryo forms three layers that will make every organ; the neural tube (future brain and spinal cord) is forming; a simple heart tube takes shape and **starts to beat around this time** (doctor point 2: hedge it).
  - Mẹ: tiredness, sore breasts, peeing more; nausea may start and can come at any time of day; mood changes.
  - Làm: book the first antenatal visit; food safety (no raw or undercooked meat, fish, eggs; no unpasteurised milk); cut down on coffee, strong tea, energy drinks.
  - Avoid: saying a scan will show the heartbeat this week.
- **Week 6** — no size line; `sizeNote` in words ("a mung bean" / "một hạt đậu xanh"). Sources `[0, 1, 2]`.
  - Bé: the neural tube closes; a vaginal scan **may** show the heartbeat as a flicker; small buds appear for arms and legs; dark spots mark where the eyes will be; the face begins to form.
  - Mẹ: nausea and a strong sense of smell; quick mood changes; tiredness.
  - Làm: small, frequent, plain meals; ginger as food; sip water through the day; rest. Vomiting so often that no fluids stay down → contact the doctor or midwife.
  - Avoid: implying anything is wrong if a scan does not show a heartbeat yet.
- **Week 7** — line: crown–rump length + "a blueberry". Sources `[0, 1, 2, 5]`.
  - Bé: the brain grows quickly and the head looks large for the body; arm buds lengthen into flat paddles that will become hands; leg buds follow; the kidneys begin to form; the umbilical cord links the embryo to the placenta.
  - Mẹ: the womb grows but the bump does not show; bloating, constipation, extra saliva; peeing often.
  - Làm: the first check-up is usually around weeks 6–8 (milestone `confirm-pregnancy`); write down questions; fibre-rich vegetables, fruit and water for constipation.
- **Week 8** — line: crown–rump length + "a cherry". Sources `[0, 1, 2, 5]`.
  - Bé: fingers and toes begin to form, still joined by webbing; eyelids, the upper lip and the tip of the nose are forming; the embryo makes tiny movements that cannot be felt; the heart beats steadily and is dividing into chambers.
  - Mẹ: waistbands feel tighter; nausea and tiredness are often strongest around now; breasts change.
  - Làm: first-visit checks usually include blood tests, urine and blood pressure; keep results in the pregnancy record book (sổ khám thai); wash fruit, vegetables and hands well.
- **Week 9** — line: crown–rump length + "a grape". Sources `[0, 1, 2, 5]`.
  - Bé: all the main organs have begun to form; muscles develop and the arms can bend at the elbows; the early tail-like end has gone; the outer ears and tooth buds begin to form.
  - Mẹ: breasts grow and their veins look more visible; heartburn; mood swings; tiredness.
  - Làm: a supportive, well-fitting bra; smaller meals and not lying down right after eating.
- **Week 10** — line: crown–rump length + weight + "a knob of ginger". Sources `[0, 1, 2, 4, 5]`.
  - Bé: from now the baby is called a fetus; the major organs are in place and keep maturing; fingers and toes have separated; nails start to grow; bones begin to harden.
  - Mẹ: mild aches low in the belly as the womb stretches; feeling emotional or anxious is common, and talking helps.
  - Làm: ask the doctor or midwife about the nuchal translucency scan and double test in weeks 11–14 and whether they are needed (doctor point 7); gentle walking or swimming with the doctor's agreement.
- **Week 11** — line: crown–rump length + weight + "a bulb of garlic". Sources `[0, 1, 2, 4, 5]`.
  - Bé: the head is about half the body's length; bones keep hardening; the baby kicks, stretches and may hiccup, though nothing can be felt yet; hair follicles form.
  - Mẹ: nausea may start to ease for some; more vaginal discharge, clear or white, is normal.
  - Làm: the nuchal translucency scan / double test window is weeks 11–14 (milestone `nt-scan`); protein, iron-rich foods and dairy in meals.
- **Week 12** — line: crown–rump length + weight + "a kiwi". Sources `[0, 1, 2, 4, 5]`.
  - Bé: reflexes develop: the fingers open and close, the toes curl, and sucking movements may start; the kidneys make urine; the intestines move into the belly.
  - Mẹ: the womb rises above the pubic bone; energy slowly returns; nausea often eases.
  - Làm: the screening scan if not done yet; keep taking the supplements the doctor or midwife recommends.
- **Week 13** — line: crown–rump length + weight + "a lemon". Sources `[0, 1, 2, 4, 5]`.
  - Bé: the vocal cords form; the intestines have settled inside the belly; fingerprints start to form on the fingertips; the skeleton keeps hardening.
  - Mẹ: the last week of the first trimester; many feel more energetic as nausea eases; skin may feel dry or itchy over the belly.
  - Làm: plan the second-trimester check-ups and note them in the record book; moisturise belly and hips.

- [ ] **Step 1: Read the bullets of weeks 4–13** with the command in the plan rules (one week at a time) and note anything the article must agree with.

- [ ] **Step 2: Write weeks 4–7**

Write one JSON object with keys `"4"`, `"5"`, `"6"`, `"7"` in the shape above, then run:
```bash
scripts/set-week-articles.py <<'JSON'
{ "4": { … }, "5": { … }, "6": { … }, "7": { … } }
JSON
```
(Replace each `{ … }` with the full article; the script refuses anything incomplete.)
Expected: eight lines `week N en|vi: lead L, baby B, mom M` with every `L` ≤ 30 (en) / ≤ 40 (vi) and every `B`, `M` between 150 and 300. If a number is out of range, edit that article and run the script again with only that week.

- [ ] **Step 3: Write weeks 8–10**, the same way (keys `"8"`, `"9"`, `"10"`). Expected: six count lines, all in range.

- [ ] **Step 4: Write weeks 11–13**, the same way (keys `"11"`, `"12"`, `"13"`). Expected: six count lines, all in range.

- [ ] **Step 5: Require weeks 4–13 and run the checks**

In `Packages/KickCore/Tests/KickCoreTests/BundledArticleTests.swift`, replace:
```swift
    static let requiredArticleWeeks: ClosedRange<Int>? = nil
```
with:
```swift
    static let requiredArticleWeeks: ClosedRange<Int>? = 4...13
```
Run: `scripts/test-core.sh --filter "BundledArticleTests|BundledContentTests|WeekSizeLineTests"`
Expected: PASS. Any failure names the week, field and language; fix the text, rerun the script for that week, rerun the tests.

- [ ] **Step 6: Accuracy and tone review**

Reread all ten articles against the fact checklist and the writing guide, one week at a time:
- Every listed fact for the week is covered; no development claim belongs to another week.
- No sentence copied or closely paraphrased from any website or app; Vietnamese reads as native writing, not translation; en and vi say the same things.
- Hedged wording; no fear language, diagnosis, promises, sex of the baby, percentages, medicine names (other than folic acid / iron without dose) or doses; every medical action points to "bác sĩ hoặc nữ hộ sinh" / "your doctor or midwife".
- Sentences about 25 words at most (vi: about 35 syllables); "mẹ"/"bé" and "you"/"your baby" throughout.
- `sizeNote` has no figures; weeks 4–6 describe size in words.
Fix anything that fails with the script and rerun Step 5.

- [ ] **Step 7: Commit, push, verify CI**

```bash
scripts/test-core.sh
git add Packages/KickCore
git commit -F - <<'MSG'
content: week articles for weeks 4 to 13

Original Vietnamese and English articles for the first trimester: lead,
size note, development, the mother's body and what to do, with sources.
Facts follow ACOG and NHS week-by-week guidance; every week stays
unreviewed until the obstetrician signs off. The bundle test now
requires an article for weeks 4 to 13.

CI-Only-Testing: WeekArticleSheetUITests, WeekArticleScreenshotTests, PregnancyScreenshotTests
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `Test run with 431 tests` locally; `CI PASSED`.

- [ ] **Step 8: Visual check**

- `week-12-vi-light`, `week-12-en-light`: expanded at week 12; the size line, then week 12's own size note (no figures in it), then "Bé phát triển ra sao" / "How your baby is developing" with 2–3 paragraphs (no more bullet fallback); paragraphs wrap cleanly.

---
### Task 5: Content — articles for weeks 14–27 (and a second look at week 24)

Write original vi + en articles for weeks 14–23 and 25–27, re-review week 24 against this batch, and require weeks 4–27. This task writes prose, not code.

**Files:**
- Modify: `Packages/KickCore/Sources/KickCore/Resources/pregnancy-content.json` (via `scripts/set-week-articles.py` only), `Packages/KickCore/Tests/KickCoreTests/BundledArticleTests.swift` (`requiredArticleWeeks`)

**Interfaces:**
- Consumes: `scripts/set-week-articles.py`, `WeekArticleChecks`, `BundledArticleTests` (Task 1); weeks 4–13 written (Task 4); week 24 written (Task 3).
- Produces: `article` for weeks 14–27; `BundledArticleTests.requiredArticleWeeks == 4...27`.

**Writing guide (spec §4.4, verbatim):**

- **Original text only.** No sentence may be copied or closely paraphrased from Flo or any website.
- **Facts** come from the sources listed in `PregnancyContent.sources`.
- **Vietnamese is written natively**, not translated. English is written in parallel and says the same things.
- **Voice:**
  - Vietnamese uses "mẹ" and "bé"; English uses "you" and "your baby".
  - Tone is warm and calm, with short sentences of about 25 words at most.
- **Hedged wording** ("thường", "khoảng", "có thể" / "usually", "about", "may"):
  - no diagnosis;
  - no fear language;
  - no promises about individual babies.
- **Units:** metric only (g, kg, mm, cm). No inch, pound or ounce in either language.
- **Medicine:** no medicine names or doses. Any medical action points to "bác sĩ hoặc nữ hộ sinh" / "your doctor or midwife".
- **Length per tab per language:** 150–300 words (Vietnamese counted in syllables/words split by spaces).
- **Accuracy:** every development claim must fit the week. Reviewers check it against ACOG and NHS week-by-week material.

**Plan rules (in addition to the guide; see "Spec clarifications" 13, 15, 16):**
- `lead` ≤ 30 words (en) / ≤ 40 (vi). Bé tab = `lead` + `sizeNote` + `development`; Mẹ tab = `body` + `todo`; each 150–300 words per language. Aim for en 170–230 and vi 200–280.
- `sizeNote` states **no figures** (no g, kg, mm, cm numbers): the generated line above it gives them.
- `development`: 2–3 paragraphs. `body`: 1–3 paragraphs. `todo`: 1–2 paragraphs.
- Read the week's existing `baby`, `mom`, `tips` and `warnings` bullets first (`python3 -c "import json;w=json.load(open('Packages/KickCore/Sources/KickCore/Resources/pregnancy-content.json'))['weeks'];print(json.dumps([x for x in w if x['week']==14][0],ensure_ascii=False,indent=1))"` — change `14`). The article must not contradict them.
- Do not repeat the warning list in `todo`; one sentence may point to "phần dấu hiệu cần đi khám bên dưới" / "the warning signs below".
- Supplements already named in the bullets (iron / sắt) may be named **without** a dose, "as your doctor or midwife advises". Vaccines are named by disease ("uốn ván, ho gà" / "tetanus and whooping cough"), never by product. No doses (a test rejects `mg`, `mcg`, `µg`, `IU`).
- Never state a baby's sex, a percentage risk, or that something "will" happen to this baby. Do not say "there is no set number of movements": from week 28 the app's tips ask mothers to count movements daily.
- `sources`: 0 = WHO, 1 = ACOG, 2 = NHS, 3 = Bộ Y tế, 4 = Hadlock 1991 (weight), 5 = Hadlock 1992. Weeks 14–27 must include 4 and at least one of 0–3; add 3 where you describe Vietnamese practice (e.g. the vaccination schedule).
- Every Vietnamese text has diacritics; keep `"reviewed": false`.

**JSON shape** (one object per week, keys in this order; the script rejects anything else):
```json
{
  "<week>": {
    "lead": {"en": "<one sentence>", "vi": "<một câu>"},
    "sizeNote": {"en": ["<paragraph>"], "vi": ["<đoạn>"]},
    "development": {"en": ["<p1>", "<p2>", "<p3>"], "vi": ["<đ1>", "<đ2>", "<đ3>"]},
    "body": {"en": ["<p1>", "<p2>"], "vi": ["<đ1>", "<đ2>"]},
    "todo": {"en": ["<p1>"], "vi": ["<đ1>"]},
    "sources": [1, 2, 4]
  }
}
```

**Example — week 24, already in the file since Task 3** (the bar for quality, tone and length; do not reuse its sentences in other weeks):
```json
{
  "24": {
    "lead": {
      "en": "Your baby's lungs are slowly getting ready for breathing after birth, and your baby now has regular times of sleeping and waking.",
      "vi": "Phổi của bé đang dần chuẩn bị cho những hơi thở đầu tiên sau khi chào đời, và bé đã có những khoảng ngủ, thức khá đều đặn."
    },
    "sizeNote": {
      "en": [
        "Your baby is still long and lean. Over the coming weeks, a layer of fat builds up under the skin, and your baby will start to look rounder. Every baby grows at their own pace, so a scan may show a slightly different number."
      ],
      "vi": [
        "Lúc này bé vẫn còn khá thon dài. Trong những tuần tới, một lớp mỡ sẽ dần hình thành dưới da, giúp bé trông tròn trịa hơn. Mỗi bé lớn theo nhịp riêng, nên con số trên siêu âm có thể hơi khác một chút."
      ]
    },
    "development": {
      "en": [
        "Deep inside the lungs, the tiny air sacs and the branches that lead to them keep developing. Some lung cells have started to make surfactant, a substance that will later help the air sacs stay open when your baby breathes. The lungs still have many weeks of growing ahead.",
        "Your baby's inner ear, which helps with balance, is now well formed. Your baby can probably hear your heartbeat, your voice and loud sounds from outside. Some babies wriggle or kick when there is a sudden noise.",
        "The skin is still thin and slightly see-through, so tiny blood vessels show beneath it. Your baby sleeps and wakes in fairly regular cycles, and you may start to notice the times of day when they are most active."
      ],
      "vi": [
        "Sâu bên trong phổi, các túi khí nhỏ li ti cùng những nhánh dẫn khí tới chúng vẫn đang tiếp tục phát triển. Một số tế bào phổi đã bắt đầu tạo ra surfactant, chất sau này giúp các túi khí không bị xẹp khi bé thở. Phổi của bé còn nhiều tuần nữa để hoàn thiện.",
        "Tai trong, bộ phận giúp bé giữ thăng bằng, nay đã hình thành khá đầy đủ. Bé có thể nghe được nhịp tim, giọng nói của mẹ và cả những âm thanh lớn bên ngoài. Có bé còn cựa mình hoặc đạp khi nghe tiếng động bất ngờ.",
        "Da bé vẫn mỏng và hơi trong, nên có thể thấy những mạch máu nhỏ bên dưới. Bé ngủ và thức theo chu kỳ khá đều, và mẹ có thể dần nhận ra những lúc trong ngày bé hay cử động nhất."
      ]
    },
    "body": {
      "en": [
        "The top of your womb is now a little above your belly button, and your bump is easy to see. As the skin stretches, it may feel tight or itchy, and stretch marks may appear. A gentle, unscented moisturiser can make it feel more comfortable.",
        "Heartburn, constipation and backache are common at this stage. Pregnancy hormones relax your muscles, and your growing womb presses on the organs around it. Some people get leg cramps at night, or feel the bump tighten for a few seconds now and then. These tightenings are usually painless and irregular.",
        "Very strong itching, especially on the palms of your hands or the soles of your feet, is different. Tell your doctor or midwife about it, as you may need a blood test."
      ],
      "vi": [
        "Đáy tử cung lúc này đã lên cao hơn rốn một chút, và bụng mẹ đã lộ rõ. Khi da bụng căng ra, mẹ có thể thấy căng, ngứa hoặc xuất hiện vết rạn. Một loại kem dưỡng ẩm dịu nhẹ, không mùi có thể giúp da dễ chịu hơn.",
        "Ợ nóng, táo bón và đau lưng khá thường gặp ở giai đoạn này. Nội tiết thai kỳ làm các cơ giãn ra, còn tử cung lớn dần thì chèn vào các cơ quan xung quanh. Một số mẹ bị chuột rút chân về đêm, hoặc thỉnh thoảng thấy bụng gò cứng trong vài giây. Những cơn gò này thường không đau và không đều.",
        "Ngứa rất nhiều, nhất là ở lòng bàn tay hay lòng bàn chân, thì lại khác. Mẹ hãy báo cho bác sĩ hoặc nữ hộ sinh, vì mẹ có thể cần làm xét nghiệm máu."
      ]
    },
    "todo": {
      "en": [
        "Many clinics offer a test for gestational diabetes between weeks 24 and 28. Ask your doctor or midwife whether you need it and how to prepare.",
        "This is also a good time to get to know your baby's usual pattern of movements: when they are active and what the movements feel like. If the movements slow down, stop or change, contact your doctor or midwife straight away, day or night. Do not wait until the next day."
      ],
      "vi": [
        "Nhiều cơ sở y tế làm xét nghiệm tầm soát tiểu đường thai kỳ trong khoảng tuần 24 đến 28. Mẹ hãy hỏi bác sĩ hoặc nữ hộ sinh xem mình có cần làm không và cần chuẩn bị thế nào.",
        "Đây cũng là lúc mẹ làm quen với nhịp cử động thường ngày của bé: bé hay cử động vào lúc nào và cảm giác ra sao. Nếu bé cử động ít đi, ngừng hẳn hoặc khác mọi ngày, mẹ hãy liên hệ bác sĩ hoặc nữ hộ sinh ngay, dù ngày hay đêm. Đừng đợi đến hôm sau."
      ]
    },
    "sources": [1, 2, 4]
  }
}
```
Its counts: en lead 22, Bé 191, Mẹ 204; vi lead 28, Bé 220, Mẹ 250.

**Fact checklist, weeks 14–27** (ACOG and NHS week-by-week milestones, aligned with the reviewed bullets and doctor-review points 3–5, 7–8):

- **Week 14** — weight + "a peach". Sources `[0, 1, 2, 4]`.
  - Bé: can squint, frown and make other expressions; fine lanugo hair starts to grow; the neck lengthens and the head is more upright; the liver makes bile and the spleen helps make blood cells.
  - Mẹ: the second trimester begins, often the most comfortable stage; appetite returns; the bump may start to show.
  - Làm: regular gentle exercise such as walking if the doctor agrees; see a dentist, as gums can swell and bleed.
- **Week 15** — "an apple". Sources `[0, 1, 2, 4]`.
  - Bé: the skeleton keeps hardening and shows on a scan; even with closed eyelids the baby can sense light (doctor point 3); the legs are now longer than the arms.
  - Mẹ: a stuffy nose or small nosebleeds; gums may bleed when brushing.
  - Làm: ask whether the triple test (weeks 15–18, milestone `triple-test`) is needed (doctor point 7); soft toothbrush, regular brushing and flossing.
- **Week 16** — "an avocado". Sources `[0, 1, 2, 4]`.
  - Bé: the eyes move slowly behind closed eyelids (doctor point 3); the heart pumps a large amount of blood each day; facial muscles keep working.
  - Mẹ: some feel first flutters, especially in a second pregnancy; feeling nothing yet is normal — most first feel movements between 16 and 24 weeks.
  - Làm: iron-rich foods (lean meat, eggs, beans, green leafy vegetables); plenty of water, few sugary drinks.
- **Week 17** — "a pear". Sources `[0, 1, 2, 4]`.
  - Bé: fat starts to form under the skin; soft cartilage turns into bone; the umbilical cord grows thicker and stronger.
  - Mẹ: brief sharp pains at the sides of the bump as ligaments stretch; balance changes.
  - Làm: get up slowly and change position gently; flat, comfortable shoes.
- **Week 18** — "a bell pepper". Sources `[0, 1, 2, 4]`.
  - Bé: the ears reach their final position and the baby may start to hear sounds (doctor point 3); yawns, stretches, may suck a thumb.
  - Mẹ: dizziness when standing up quickly; backache as posture changes.
  - Làm: the detailed anomaly scan is usually in weeks 18–22 (milestone `anomaly-scan`); talking and singing to the baby.
- **Week 19** — "a mango". Sources `[0, 1, 2, 4]`.
  - Bé: a creamy coating (vernix / chất gây) forms to protect the skin; hearing, taste, smell and touch keep developing.
  - Mẹ: a dark line may appear down the belly and darker patches on the face; both usually fade after birth.
  - Làm: sun protection; sleeping on the side with a pillow between the knees for comfort.
- **Week 20** — "a banana". Sources `[0, 1, 2, 4]`.
  - Bé: halfway; the baby swallows amniotic fluid, which helps the gut develop, and the first stool (meconium / phân su) starts to form in the bowel.
  - Mẹ: the top of the womb is around the belly button; many feel movements now; in a first pregnancy it may be closer to weeks 20–22 (doctor point 4).
  - Làm: the anomaly scan if not done yet; blood pressure at every visit.
- **Week 21** — "a carrot". Sources `[0, 1, 2, 4]`.
  - Bé: movements become stronger and more frequent; the taste buds work and the baby can taste flavours in the amniotic fluid (doctor point 3).
  - Mẹ: night leg cramps; swollen veins in the legs; mild ankle swelling in the evening.
  - Làm: stretch the calves before bed, stay active; avoid standing for long; feet up when resting.
- **Week 22** — "a cucumber". Sources `[0, 1, 2, 4]`.
  - Bé: eyebrows and eyelashes grow; the baby can grip and may hold the umbilical cord; the senses keep sharpening.
  - Mẹ: stretch marks may appear on the belly, breasts or thighs; feeling warmer and sweating more.
  - Làm: loose, breathable clothes and enough water; ask about antenatal classes.
- **Week 23** — "a large sweet potato". Sources `[0, 1, 2, 4]`.
  - Bé: hears loud sounds from outside; the lungs develop the branches they will need; the skin is still wrinkled and reddish; rapid eye movements begin.
  - Mẹ: mild swelling of feet and ankles in the evening is common (sudden swelling of face or hands is in the warnings); the belly button may pop out.
  - Làm: rest with feet raised; keep every antenatal appointment even when well.
- **Week 24** — already written (Task 3). Reread it beside weeks 23 and 25: no fact repeated word for word in a neighbour, no contradiction. Change it only if the review finds a problem; if you do, rerun the script for `"24"` and keep its `sources` including 4.
- **Week 25** — "a head of broccoli". Sources `[0, 1, 2, 4]`.
  - Bé: may respond to your voice with movement; the hands are fully formed and explore by touch; fat keeps filling out the body.
  - Mẹ: hair may look thicker; tingling or numbness in the hands as fluid builds up; constipation or piles.
  - Làm: whole grains, vegetables and protein for steady energy; notice when the baby is most active.
- **Week 26** — "a head of lettuce". Sources `[0, 1, 2, 4]`.
  - Bé: the eyes are beginning to open (doctor point 3); may startle at loud noises; the lungs keep developing.
  - Mẹ: practice contractions (cơn gò sinh lý / Braxton Hicks): painless tightenings that come and go; sleep gets harder as the bump grows.
  - Làm: change position or rest when tightenings come, they should ease; sleep on the side with pillows supporting the bump.
- **Week 27** — "a head of napa cabbage". Sources `[0, 1, 2, 3, 4]`.
  - Bé: the brain is very active, with clear sleep and wake cycles; rhythmic jolts may be hiccups.
  - Mẹ: the last week of the second trimester; backache and leg cramps may increase.
  - Làm: ask the doctor or midwife about the tetanus and whooping cough vaccines in pregnancy, given on the schedule of the clinic where you are seen (milestone `tetanus-pertussis`, doctor point 8); keep learning the baby's daily movement pattern.

- [ ] **Step 1: Read the bullets of weeks 14–27** with the command in the plan rules and note anything the article must agree with.

- [ ] **Step 2: Write weeks 14–17**

```bash
scripts/set-week-articles.py <<'JSON'
{ "14": { … }, "15": { … }, "16": { … }, "17": { … } }
JSON
```
(Replace each `{ … }` with the full article.) Expected: eight count lines, every lead ≤ 30 (en) / ≤ 40 (vi), every tab 150–300.

- [ ] **Step 3: Write weeks 18–21**, the same way (keys `"18"`–`"21"`). Expected: eight count lines, all in range.

- [ ] **Step 4: Write weeks 22, 23, 25**, the same way. Expected: six count lines, all in range.

- [ ] **Step 5: Write weeks 26–27 and review week 24**, the same way (keys `"26"`, `"27"`; add `"24"` only if you changed it). Expected: four (or six) count lines, all in range.

- [ ] **Step 6: Require weeks 4–27 and run the checks**

In `Packages/KickCore/Tests/KickCoreTests/BundledArticleTests.swift`, replace:
```swift
    static let requiredArticleWeeks: ClosedRange<Int>? = 4...13
```
with:
```swift
    static let requiredArticleWeeks: ClosedRange<Int>? = 4...27
```
Run: `scripts/test-core.sh --filter "BundledArticleTests|BundledContentTests|WeekSizeLineTests"`
Expected: PASS. Fix any reported week/field/language with the script and rerun.

- [ ] **Step 7: Accuracy and tone review**

Reread all fourteen articles (14–27) against the fact checklist and the writing guide:
- Every listed fact covered; no claim from another week; quickening and the senses are hedged as in doctor points 3–4.
- No copied or closely paraphrased sentence; native Vietnamese; en and vi say the same.
- Hedged, calm, no diagnosis or fear language; no medicine names (iron allowed without dose), no doses, no vaccine product names; medical actions point to "bác sĩ hoặc nữ hộ sinh" / "your doctor or midwife".
- Sentences about 25 words at most (vi: about 35 syllables); `sizeNote` without figures.
- Neighbouring weeks do not repeat each other's sentences.
Fix and rerun Step 6.

- [ ] **Step 8: Commit, push, verify CI**

```bash
scripts/test-core.sh
git add Packages/KickCore
git commit -F - <<'MSG'
content: week articles for weeks 14 to 27

Original Vietnamese and English articles for the second trimester, with
week 24 reread beside its neighbours. Facts follow ACOG and NHS
week-by-week guidance and the doctor-review notes on the senses,
quickening, screening and vaccines; every week stays unreviewed. The
bundle test now requires an article for weeks 4 to 27.

CI-Only-Testing: WeekArticleSheetUITests, WeekArticleScreenshotTests
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `Test run with 431 tests` locally; `CI PASSED`.

- [ ] **Step 9: Visual check**

- `week-article-25-vi-light`: week 25 now shows its article on the Mẹ tab ("Cơ thể mẹ tuần này", "Mẹ nên làm gì", then the warning card) instead of the bullet fallback.
- `week-article-expanded-baby-vi-light` and `-scrolled`: week 24 text reads as in Task 3 (or as revised); nothing cut.

---
### Task 6: Content — articles for weeks 28–42, all weeks required

Write original vi + en articles for weeks 28–42 and switch the bundle test to require every week 4–42 (spec §4.5 fully enforced). This task writes prose, not code.

**Files:**
- Modify: `Packages/KickCore/Sources/KickCore/Resources/pregnancy-content.json` (via `scripts/set-week-articles.py` only), `Packages/KickCore/Tests/KickCoreTests/BundledArticleTests.swift` (`requiredArticleWeeks`)

**Interfaces:**
- Consumes: `scripts/set-week-articles.py`, `WeekArticleChecks`, `BundledArticleTests` (Task 1); weeks 4–27 written (Tasks 3–5); `WeeklyContentLibrary.weekRange`.
- Produces: `article` for every week 4–42; `BundledArticleTests.requiredArticleWeeks == WeeklyContentLibrary.weekRange`.

**Writing guide (spec §4.4, verbatim):**

- **Original text only.** No sentence may be copied or closely paraphrased from Flo or any website.
- **Facts** come from the sources listed in `PregnancyContent.sources`.
- **Vietnamese is written natively**, not translated. English is written in parallel and says the same things.
- **Voice:**
  - Vietnamese uses "mẹ" and "bé"; English uses "you" and "your baby".
  - Tone is warm and calm, with short sentences of about 25 words at most.
- **Hedged wording** ("thường", "khoảng", "có thể" / "usually", "about", "may"):
  - no diagnosis;
  - no fear language;
  - no promises about individual babies.
- **Units:** metric only (g, kg, mm, cm). No inch, pound or ounce in either language.
- **Medicine:** no medicine names or doses. Any medical action points to "bác sĩ hoặc nữ hộ sinh" / "your doctor or midwife".
- **Length per tab per language:** 150–300 words (Vietnamese counted in syllables/words split by spaces).
- **Accuracy:** every development claim must fit the week. Reviewers check it against ACOG and NHS week-by-week material.

**Plan rules (in addition to the guide; see "Spec clarifications" 13, 15, 16):**
- `lead` ≤ 30 words (en) / ≤ 40 (vi). Bé tab = `lead` + `sizeNote` + `development`; Mẹ tab = `body` + `todo`; each 150–300 words per language. Aim for en 170–230 and vi 200–280.
- `sizeNote` states **no figures**: the generated line gives them. Weeks 41–42 show week 40's figures with a note that Hadlock's standard ends at week 40; their `sizeNote` may say growth continues after the due date without giving numbers.
- `development`: 2–3 paragraphs. `body`: 1–3 paragraphs. `todo`: 1–2 paragraphs.
- Read the week's existing bullets first (`python3 -c "import json;w=json.load(open('Packages/KickCore/Sources/KickCore/Resources/pregnancy-content.json'))['weeks'];print(json.dumps([x for x in w if x['week']==28][0],ensure_ascii=False,indent=1))"` — change `28`). The article must not contradict them; from week 28 the tips ask mothers to **count movements every day** at a usual active time, so the articles say the same and never "there is no set number of movements".
- Do not repeat the warning list in `todo`; one sentence may point to "phần dấu hiệu cần đi khám bên dưới" / "the warning signs below". Reduced or changed movements always → contact the doctor or midwife straight away, day or night (as in week 24's example).
- No medicine names (no names of labour-inducing drugs or anti-D products), no doses, no procedure promises; induction and monitoring are "trao đổi với bác sĩ" / "talk with your doctor".
- Never state a baby's sex, a percentage risk, or a date the baby "will" arrive.
- `sources`: 0 = WHO, 1 = ACOG, 2 = NHS, 3 = Bộ Y tế, 4 = Hadlock 1991, 5 = Hadlock 1992. Weeks 28–42 must include 4 and at least one of 0–3.
- Every Vietnamese text has diacritics; keep `"reviewed": false`.

**JSON shape** (one object per week, keys in this order; the script rejects anything else):
```json
{
  "<week>": {
    "lead": {"en": "<one sentence>", "vi": "<một câu>"},
    "sizeNote": {"en": ["<paragraph>"], "vi": ["<đoạn>"]},
    "development": {"en": ["<p1>", "<p2>", "<p3>"], "vi": ["<đ1>", "<đ2>", "<đ3>"]},
    "body": {"en": ["<p1>", "<p2>"], "vi": ["<đ1>", "<đ2>"]},
    "todo": {"en": ["<p1>"], "vi": ["<đ1>"]},
    "sources": [1, 2, 4]
  }
}
```

**Example — week 24, already in the file since Task 3** (the bar for quality, tone and length; do not reuse its sentences):
```json
{
  "24": {
    "lead": {
      "en": "Your baby's lungs are slowly getting ready for breathing after birth, and your baby now has regular times of sleeping and waking.",
      "vi": "Phổi của bé đang dần chuẩn bị cho những hơi thở đầu tiên sau khi chào đời, và bé đã có những khoảng ngủ, thức khá đều đặn."
    },
    "sizeNote": {
      "en": [
        "Your baby is still long and lean. Over the coming weeks, a layer of fat builds up under the skin, and your baby will start to look rounder. Every baby grows at their own pace, so a scan may show a slightly different number."
      ],
      "vi": [
        "Lúc này bé vẫn còn khá thon dài. Trong những tuần tới, một lớp mỡ sẽ dần hình thành dưới da, giúp bé trông tròn trịa hơn. Mỗi bé lớn theo nhịp riêng, nên con số trên siêu âm có thể hơi khác một chút."
      ]
    },
    "development": {
      "en": [
        "Deep inside the lungs, the tiny air sacs and the branches that lead to them keep developing. Some lung cells have started to make surfactant, a substance that will later help the air sacs stay open when your baby breathes. The lungs still have many weeks of growing ahead.",
        "Your baby's inner ear, which helps with balance, is now well formed. Your baby can probably hear your heartbeat, your voice and loud sounds from outside. Some babies wriggle or kick when there is a sudden noise.",
        "The skin is still thin and slightly see-through, so tiny blood vessels show beneath it. Your baby sleeps and wakes in fairly regular cycles, and you may start to notice the times of day when they are most active."
      ],
      "vi": [
        "Sâu bên trong phổi, các túi khí nhỏ li ti cùng những nhánh dẫn khí tới chúng vẫn đang tiếp tục phát triển. Một số tế bào phổi đã bắt đầu tạo ra surfactant, chất sau này giúp các túi khí không bị xẹp khi bé thở. Phổi của bé còn nhiều tuần nữa để hoàn thiện.",
        "Tai trong, bộ phận giúp bé giữ thăng bằng, nay đã hình thành khá đầy đủ. Bé có thể nghe được nhịp tim, giọng nói của mẹ và cả những âm thanh lớn bên ngoài. Có bé còn cựa mình hoặc đạp khi nghe tiếng động bất ngờ.",
        "Da bé vẫn mỏng và hơi trong, nên có thể thấy những mạch máu nhỏ bên dưới. Bé ngủ và thức theo chu kỳ khá đều, và mẹ có thể dần nhận ra những lúc trong ngày bé hay cử động nhất."
      ]
    },
    "body": {
      "en": [
        "The top of your womb is now a little above your belly button, and your bump is easy to see. As the skin stretches, it may feel tight or itchy, and stretch marks may appear. A gentle, unscented moisturiser can make it feel more comfortable.",
        "Heartburn, constipation and backache are common at this stage. Pregnancy hormones relax your muscles, and your growing womb presses on the organs around it. Some people get leg cramps at night, or feel the bump tighten for a few seconds now and then. These tightenings are usually painless and irregular.",
        "Very strong itching, especially on the palms of your hands or the soles of your feet, is different. Tell your doctor or midwife about it, as you may need a blood test."
      ],
      "vi": [
        "Đáy tử cung lúc này đã lên cao hơn rốn một chút, và bụng mẹ đã lộ rõ. Khi da bụng căng ra, mẹ có thể thấy căng, ngứa hoặc xuất hiện vết rạn. Một loại kem dưỡng ẩm dịu nhẹ, không mùi có thể giúp da dễ chịu hơn.",
        "Ợ nóng, táo bón và đau lưng khá thường gặp ở giai đoạn này. Nội tiết thai kỳ làm các cơ giãn ra, còn tử cung lớn dần thì chèn vào các cơ quan xung quanh. Một số mẹ bị chuột rút chân về đêm, hoặc thỉnh thoảng thấy bụng gò cứng trong vài giây. Những cơn gò này thường không đau và không đều.",
        "Ngứa rất nhiều, nhất là ở lòng bàn tay hay lòng bàn chân, thì lại khác. Mẹ hãy báo cho bác sĩ hoặc nữ hộ sinh, vì mẹ có thể cần làm xét nghiệm máu."
      ]
    },
    "todo": {
      "en": [
        "Many clinics offer a test for gestational diabetes between weeks 24 and 28. Ask your doctor or midwife whether you need it and how to prepare.",
        "This is also a good time to get to know your baby's usual pattern of movements: when they are active and what the movements feel like. If the movements slow down, stop or change, contact your doctor or midwife straight away, day or night. Do not wait until the next day."
      ],
      "vi": [
        "Nhiều cơ sở y tế làm xét nghiệm tầm soát tiểu đường thai kỳ trong khoảng tuần 24 đến 28. Mẹ hãy hỏi bác sĩ hoặc nữ hộ sinh xem mình có cần làm không và cần chuẩn bị thế nào.",
        "Đây cũng là lúc mẹ làm quen với nhịp cử động thường ngày của bé: bé hay cử động vào lúc nào và cảm giác ra sao. Nếu bé cử động ít đi, ngừng hẳn hoặc khác mọi ngày, mẹ hãy liên hệ bác sĩ hoặc nữ hộ sinh ngay, dù ngày hay đêm. Đừng đợi đến hôm sau."
      ]
    },
    "sources": [1, 2, 4]
  }
}
```
Its counts: en lead 22, Bé 191, Mẹ 204; vi lead 28, Bé 220, Mẹ 250.

**Fact checklist, weeks 28–42** (ACOG and NHS week-by-week milestones, aligned with the reviewed bullets and doctor-review points 3, 5, 6, 9, 11, 12):

- **Week 28** — weight + "a small pineapple". Sources `[0, 1, 2, 4]`.
  - Bé: can open and close the eyes and blink; eyelashes have grown; the brain grows fast and lays down more connections.
  - Mẹ: the third trimester begins; check-ups usually become more frequent.
  - Làm: count movements every day at a usual active time; go to sleep on your side rather than your back; if your blood group is Rh negative, ask the doctor or midwife what extra care you need (doctor point 9: no product names).
- **Week 29** — "a coconut". Sources `[0, 1, 2, 4]`.
  - Bé: muscles and lungs keep maturing; kicks and jabs are strong and easy to feel; the bones store calcium.
  - Mẹ: shortness of breath as the womb presses upwards; peeing often again; heartburn.
  - Làm: count movements daily; calcium-rich foods (milk, yoghurt, tofu, small fish eaten with their bones).
- **Week 30** — "a head of cabbage". Sources `[0, 1, 2, 4]`.
  - Bé: the bone marrow now makes red blood cells; the lanugo hair starts to disappear; the brain keeps growing quickly.
  - Mẹ: tiredness and heartburn return; feeling clumsier as the bump grows.
  - Làm: count movements daily; a growth scan is often done in weeks 30–32 (milestone `growth-scan`), ask the doctor.
- **Week 31** — "a cantaloupe". Sources `[0, 1, 2, 4]`.
  - Bé: all five senses are working (doctor point 3); turns the head from side to side; keeps putting on fat.
  - Mẹ: practice contractions more often; breasts may leak a little colostrum (sữa non).
  - Làm: count movements daily; start learning about breastfeeding with the doctor or midwife.
- **Week 32** — "a bunch of bananas". Sources `[0, 1, 2, 4]`.
  - Bé: practises breathing movements with amniotic fluid; fingernails and toenails have grown in; many babies turn head-down in the coming weeks (the position is usually checked around week 36).
  - Mẹ: needing more rest during the day.
  - Làm: count movements daily; talk with the doctor about where you plan to give birth.
- **Week 33** — "a pineapple". Sources `[0, 1, 2, 4]`.
  - Bé: the bones harden, but the skull stays soft to help with birth; antibodies pass from you to your baby to help protect them after birth.
  - Mẹ: feet and ankles swell more by evening (sudden swelling is in the warnings); a comfortable sleeping position is harder to find.
  - Làm: count movements daily; start packing the hospital bag (documents, pregnancy record book).
- **Week 34** — "a large cantaloupe". Sources `[0, 1, 2, 4]`.
  - Bé: the nervous system and lungs keep maturing; a layer of fat fills out the body.
  - Mẹ: pressure low in the pelvis; tiredness and broken sleep.
  - Làm: count movements daily; learn the signs of labour and how to reach the maternity unit.
- **Week 35** — "a honeydew melon". Sources `[0, 1, 2, 4]`.
  - Bé: the kidneys are fully developed (doctor point 3); there is less room, so movements may feel more like rolls than kicks, **but they should not become fewer** (doctor point 5).
  - Mẹ: peeing more as the baby presses on the bladder; practice contractions may feel stronger.
  - Làm: count movements daily; the group B strep test is often done in weeks 35–37 (milestone `gbs-test`, doctor point 6), ask the doctor.
- **Week 36** — "a pair of coconuts". Sources `[0, 1, 2, 4]`.
  - Bé: may drop lower into the pelvis, especially in a first pregnancy; most of the lanugo has gone; the doctor or midwife may check whether the baby is head-down.
  - Mẹ: breathing may feel easier once the baby drops, with more pressure on the bladder and pelvis.
  - Làm: count movements daily; finish packing the hospital bag and keep it near the door.
- **Week 37** — "a pair of pineapples". Sources `[0, 1, 2, 4]`.
  - Bé: now considered early term (from 37 weeks; doctor point 11); practises sucking, blinking and breathing movements.
  - Mẹ: check-ups usually every week from now (milestone `weekly-checks`); a mucus show may appear as the cervix gets ready.
  - Làm: count movements daily; know the signs of labour: regular, stronger contractions, the waters breaking, a show.
- **Week 38** — "a small watermelon". Sources `[0, 1, 2, 4]`.
  - Bé: a firm grasp; the organs are ready to work outside the womb.
  - Mẹ: feeling uncomfortable and impatient is normal; frequent practice contractions.
  - Làm: count movements daily; rest when you can; light, regular meals.
- **Week 39** — "a large head of cabbage". Sources `[0, 1, 2, 4]`.
  - Bé: full term (from 39 weeks; doctor point 11); a layer of fat helps keep warm after birth; the brain keeps developing.
  - Mẹ: labour could start any day; a burst of energy or deep tiredness are both common.
  - Làm: count movements daily — babies keep moving right up to and during labour; keep the phone charged and the bag ready.
- **Week 40** — "a medium watermelon". Sources `[0, 1, 2, 4]`.
  - Bé: ready to be born; the skull bones are not yet joined so the head can mould during birth; only a few babies arrive exactly on their due date.
  - Mẹ: the due date is here; waiting a little longer is common; the doctor checks mother and baby more closely (milestone `post-dates`).
  - Làm: count movements daily; keep check-up appointments after the due date.
- **Week 41** — same figures as week 40, "two bunches of bananas"; the footnote says Hadlock's standard ends at week 40. Sources `[0, 1, 2, 4]`.
  - Bé: keeps growing; the skin may be a little dry or peeling at birth; nails may reach past the fingertips.
  - Mẹ: more frequent monitoring; the doctor may talk about inducing labour (doctor point 12: "có thể sẽ trao đổi về khởi phát chuyển dạ").
  - Làm: count movements daily; ask the doctor about the plan if labour does not start on its own.
- **Week 42** — same figures as week 40, "a large watermelon"; the standard-ends footnote. Sources `[0, 1, 2, 4]`.
  - Bé: past term; the care team watches closely; less lanugo and vernix at birth.
  - Mẹ: the doctor checks the baby's heartbeat and the amount of amniotic fluid; helping labour to start is usually recommended (doctor point 12).
  - Làm: count movements daily; follow the doctor's plan for monitoring and the timing of birth.
  - Tone: calm and practical; no blame, no risk figures.

- [ ] **Step 1: Read the bullets of weeks 28–42** with the command in the plan rules.

- [ ] **Step 2: Write weeks 28–31**

```bash
scripts/set-week-articles.py <<'JSON'
{ "28": { … }, "29": { … }, "30": { … }, "31": { … } }
JSON
```
(Replace each `{ … }` with the full article.) Expected: eight count lines, every lead ≤ 30 (en) / ≤ 40 (vi), every tab 150–300.

- [ ] **Step 3: Write weeks 32–35**, the same way. Expected: eight count lines, all in range.

- [ ] **Step 4: Write weeks 36–39**, the same way. Expected: eight count lines, all in range.

- [ ] **Step 5: Write weeks 40–42**, the same way. Expected: six count lines, all in range.

- [ ] **Step 6: Require every week and run the checks**

In `Packages/KickCore/Tests/KickCoreTests/BundledArticleTests.swift`, replace:
```swift
    /// Weeks that must already have an article. Each content task widens it:
    /// nil (Tasks 1–3) → 4...13 (Task 4) → 4...27 (Task 5) → WeeklyContentLibrary.weekRange (Task 6).
    static let requiredArticleWeeks: ClosedRange<Int>? = 4...27
```
with:
```swift
    /// Every week 4–42 must have an article (phase 6 spec §4.5).
    static let requiredArticleWeeks: ClosedRange<Int>? = WeeklyContentLibrary.weekRange
```
Run: `scripts/test-core.sh`
Expected: PASS, `Test run with 431 tests`. Then confirm every week has an article and nothing is marked reviewed:
```bash
python3 -c "import json;d=json.load(open('Packages/KickCore/Sources/KickCore/Resources/pregnancy-content.json'));print([w['week'] for w in d['weeks'] if 'article' not in w],[w['week'] for w in d['weeks'] if w['reviewed']])"
```
Expected: `[] []`.

- [ ] **Step 7: Accuracy and tone review**

Reread all fifteen articles (28–42) against the fact checklist and the writing guide:
- Every listed fact covered; movement counting is consistent with the tips; reduced movements always point to contacting the doctor or midwife straight away.
- No copied or closely paraphrased sentence; native Vietnamese; en and vi say the same.
- Hedged and calm, especially weeks 40–42; no medicine names, doses, risk figures, or promises about dates.
- Sentences about 25 words at most (vi: about 35 syllables); `sizeNote` without figures.
Then skim all 39 leads in order (`python3 -c "import json;[print(w['week'],w['article']['lead']['vi']) for w in json.load(open('Packages/KickCore/Sources/KickCore/Resources/pregnancy-content.json'))['weeks']]"`): no two leads start the same way in neighbouring weeks. Fix and rerun Step 6.

- [ ] **Step 8: Commit, push, verify CI**

```bash
scripts/test-core.sh
git add Packages/KickCore
git commit -F - <<'MSG'
content: week articles for weeks 28 to 42

Original Vietnamese and English articles for the third trimester and
the weeks after the due date, consistent with the daily movement count
and the doctor-review notes on term, monitoring and induction. Every
week from 4 to 42 now has an article and the content checks require it;
all weeks stay unreviewed until the obstetrician signs off.

CI-Only-Testing: WeekArticleSheetUITests, WeekArticleScreenshotTests
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`.

---
### Task 7: Docs — doctor review §9, README, release checklist; full CI

Records the articles for the obstetrician (spec §4.6), documents the new code and script, and adds the phase to the release checklist (no CloudKit change: content is bundled). The commit has **no** `CI-Only-Testing:` line, so CI runs every UI test class.

**Files:**
- Modify: `docs/content-review-for-doctor.md` (§7 table row; new §9 at the end), `README.md` (new section at the end), `docs/release-checklist.md` (phase 2 screenshot line; new phase 6 section at the end)

**Interfaces:**
- Consumes: the strings of Task 3, the script of Task 1, the screenshot names of Task 3, the articles of Tasks 3–6.
- Produces: documentation only.

- [ ] **Step 1: Doctor review §7 and §9**

In `docs/content-review-for-doctor.md`, replace:
```markdown
| `week.sizeLine`, `week.about`, `week.typicalRange` | "Ở tuần này, bé có kích thước bằng %@." / "Khoảng %@" / "Thường %@" — câu diễn giải kích thước bé ở Chi tiết tuần (cùng số liệu Hadlock đã duyệt ở mục 1–2, chỉ đổi câu chữ) |
```
with:
```markdown
| `week.sizeLine`, `week.about`, `week.typicalRange` | *Đã bỏ ở giai đoạn 6* — thay bằng câu kích thước tự sinh `weekArticle.size.*` (mục 9). |
```

Append at the end of the file:
```markdown

## 9. Bài viết theo tuần (giai đoạn 6)

Chi tiết tuần nay là một bài viết ngắn cho mỗi tuần 4–42, chia hai thẻ **Bé** và **Mẹ**, viết mới bằng
tiếng Việt và tiếng Anh (không dịch máy, không chép từ ứng dụng hay trang web khác). Nội dung nằm trong
trường `article` của từng tuần trong `pregnancy-content.json`; mọi tuần vẫn `"reviewed": false`. Xem trên
ảnh chụp `week-article-*` trong `ci-artifacts/screenshots/` của lần CI gần nhất, hoặc trong bản TestFlight.

Cấu trúc mỗi bài:
- **Thẻ Bé:** câu mở đầu in đậm; "Bé lớn cỡ nào?" (câu kích thước tự sinh + đoạn mô tả); "Bé phát triển ra sao".
- **Thẻ Mẹ:** "Cơ thể mẹ tuần này"; "Mẹ nên làm gì"; rồi mục "Khi nào cần đi khám ngay" (giữ nguyên như cũ).
- "Tài liệu tham khảo": các nguồn bài viết dùng (WHO, ACOG, NHS, Bộ Y tế, Hadlock).

**Câu kích thước** không viết tay: app tự ghép từ số liệu Hadlock đã có (mục 21), nên con số luôn khớp bảng
chuẩn. Mẫu câu (cần duyệt câu chữ, không cần duyệt lại số):

| Khóa | Nội dung (vi) |
|---|---|
| `weekArticle.size.length` (tuần 7–9) | "Bé dài khoảng 16 mm (từ đầu đến mông), cỡ một quả anh đào." |
| `weekArticle.size.lengthWeight` (tuần 10–13) | "Bé dài khoảng 53,5 mm (từ đầu đến mông) và nặng khoảng 58 g, cỡ một quả kiwi." |
| `weekArticle.size.weight` (tuần 14–42) | "Bé nặng khoảng 670 g (thường từ 556 đến 784 g), cỡ một bắp ngô." Tuần 41–42 dùng số của tuần 40 kèm dòng "Số liệu chuẩn Hadlock chỉ đến tuần 40." |
| `weekArticle.heading.*`, `weekArticle.tab.*` | "Bé lớn cỡ nào?", "Bé phát triển ra sao", "Cơ thể mẹ tuần này", "Mẹ nên làm gì"; thẻ "Bé" / "Mẹ" |

Tuần 4–6 không có số đo, chỉ có đoạn mô tả bằng lời.

**Nguyên tắc viết** (tác giả đã áp dụng; bác sĩ kiểm tra theo):
- Chỉ viết mới; không câu nào chép hoặc diễn đạt lại sát từ Flo hay bất kỳ trang web nào.
- Dữ kiện lấy từ các nguồn trong danh sách nguồn; mỗi ý về sự phát triển của bé phải đúng với tuần đó
  (đối chiếu tài liệu theo tuần của ACOG và NHS).
- Tiếng Việt viết trực tiếp, không dịch; bản tiếng Anh viết song song, nói cùng nội dung.
- Xưng "mẹ" và "bé"; giọng ấm áp, bình tĩnh; câu ngắn (khoảng 25 từ trở xuống).
- Dùng từ rào đón ("thường", "khoảng", "có thể"); không chẩn đoán, không gây sợ hãi, không hứa hẹn về
  từng em bé; không nêu giới tính hay tỉ lệ phần trăm rủi ro.
- Chỉ dùng đơn vị mét (g, kg, mm, cm).
- Không nêu tên thuốc hay liều. Ngoại lệ: axit folic và sắt được nhắc tên (không liều), "theo hướng dẫn của
  bác sĩ hoặc nữ hộ sinh", như các gạch đầu dòng đã có. Vắc-xin chỉ gọi theo bệnh (uốn ván, ho gà). Mọi việc
  liên quan y tế đều hướng tới "bác sĩ hoặc nữ hộ sinh".
- Mỗi thẻ, mỗi ngôn ngữ dài 150–300 chữ (tiếng Việt đếm theo âm tiết); câu mở đầu tối đa 30 từ (en) / 40 âm
  tiết (vi). Các giới hạn này và việc không có inch/pound/ounce được kiểm tra tự động (`scripts/test-core.sh`).

35. [ ] **Duyệt từng tuần** (đúng dữ kiện, đúng tuần, giọng văn, không mâu thuẫn với các thẻ ở màn Hôm nay):
    - [ ] Tuần 4
    - [ ] Tuần 5
    - [ ] Tuần 6
    - [ ] Tuần 7
    - [ ] Tuần 8
    - [ ] Tuần 9
    - [ ] Tuần 10
    - [ ] Tuần 11
    - [ ] Tuần 12
    - [ ] Tuần 13
    - [ ] Tuần 14
    - [ ] Tuần 15
    - [ ] Tuần 16
    - [ ] Tuần 17
    - [ ] Tuần 18
    - [ ] Tuần 19
    - [ ] Tuần 20
    - [ ] Tuần 21
    - [ ] Tuần 22
    - [ ] Tuần 23
    - [ ] Tuần 24
    - [ ] Tuần 25
    - [ ] Tuần 26
    - [ ] Tuần 27
    - [ ] Tuần 28
    - [ ] Tuần 29
    - [ ] Tuần 30
    - [ ] Tuần 31
    - [ ] Tuần 32
    - [ ] Tuần 33
    - [ ] Tuần 34
    - [ ] Tuần 35
    - [ ] Tuần 36
    - [ ] Tuần 37
    - [ ] Tuần 38
    - [ ] Tuần 39
    - [ ] Tuần 40
    - [ ] Tuần 41
    - [ ] Tuần 42
36. [ ] Duyệt câu chữ câu kích thước tự sinh và các tiêu đề (bảng trên).
37. [ ] **Câu hỏi:** cho phép nhắc tên axit folic và sắt (không liều) trong bài viết như các gạch đầu dòng cũ,
        hay bỏ hẳn tên?
38. [ ] **Câu hỏi:** dòng "Người xem xét" hiện chỉ ghi "Nội dung đang chờ bác sĩ duyệt", không có tên. Sau khi
        duyệt, bác sĩ có đồng ý hiện tên mình trên từng tuần không? (Chưa làm ở giai đoạn này.)
- [ ] Khi bác sĩ duyệt xong một tuần: đổi `"reviewed": true` cho tuần đó như mục 1 — cờ này áp dụng cho cả
      các gạch đầu dòng lẫn bài viết của tuần.
```

- [ ] **Step 2: README**

Append at the end of `README.md`:
```markdown

## Bài viết theo tuần (giai đoạn 6)
- Chi tiết tuần: nền cố định (ảnh thai nhi + hàng chip tuần) dưới một sheet kéo được hai nấc
  (`App/DesignSystem/ArticleSheet.swift`, quy tắc thả tay `KickCore/SheetDetentResolver.swift`), thẻ Bé / Mẹ
  trong `App/Pregnancy/WeekArticleView.swift`.
- Bài viết: trường `article` của mỗi tuần trong `pregnancy-content.json` (phiên bản 3). Thêm hoặc sửa bằng
  `scripts/set-week-articles.py` (JSON qua stdin, xem đầu file; in số chữ mỗi thẻ). Kiểm tra tự động:
  `scripts/test-core.sh --filter "BundledArticleTests|WeekArticleChecksTests"`.
- Câu "Bé lớn cỡ nào?" tự sinh từ số liệu Hadlock (`KickCore/WeekSizeLine.swift`, mẫu câu `weekArticle.size.*`).
- Ảnh riêng từng tuần (chưa có): thêm asset `Fetus-W##` / `Fruit-W##` (ví dụ `Fetus-W31`) vào
  `App/Images.xcassets`; khi thiếu, app dùng ảnh `Fetus` chung và emoji kích thước.
- Nội dung vẫn chờ bác sĩ duyệt: `docs/content-review-for-doctor.md` mục 9.
```

- [ ] **Step 3: Release checklist**

In `docs/release-checklist.md`, replace:
```markdown
- [ ] Ảnh chụp App Store mới cho tab Thai kỳ (vi + en): `ci-artifacts/screenshots/pregnancy-home-24-*`, `week-24-*`, `appointments-*`.
```
with:
```markdown
- [ ] Ảnh chụp App Store mới cho tab Thai kỳ (vi + en): `ci-artifacts/screenshots/pregnancy-home-24-*`, `week-article-*` (thay `week-24-*` từ giai đoạn 6), `appointments-*`.
```

Append at the end of the file:
```markdown

## Giai đoạn 6 — Bài viết theo tuần

### Trước khi gửi App Store
- [ ] Không thay đổi CloudKit: bài viết nằm trong `pregnancy-content.json` đóng gói cùng app (phiên bản 3).
- [ ] Bác sĩ đã duyệt bài viết từng tuần — mục 9 của [`docs/content-review-for-doctor.md`](content-review-for-doctor.md).
      Tuần chưa duyệt vẫn bị ẩn ở bản App Store (không đổi so với giai đoạn 2).
- [ ] Mọi tuần 4–42 có bài viết — lệnh sau in ra `[]`:
      `python3 -c "import json;d=json.load(open('Packages/KickCore/Sources/KickCore/Resources/pregnancy-content.json'));print([w['week'] for w in d['weeks'] if 'article' not in w])"`
- [ ] Ảnh chụp App Store cho Chi tiết tuần: `week-article-peek-baby-vi-light`, `week-article-expanded-baby-vi-light`,
      `week-article-expanded-mom-vi-light`, `week-article-*-en-dark`.
- [ ] Ghi chú phát hành: Chi tiết tuần mới — bài viết theo tuần, chia thẻ Bé / Mẹ, kéo lên để đọc toàn bài.

### Kiểm thử thủ công trên iPhone qua TestFlight (vi và en)
- [ ] Mở Chi tiết tuần từ ảnh thai nhi ở Hôm nay: sheet ở nấc thấp, thấy tiêu đề, thẻ Bé / Mẹ và câu mở đầu.
- [ ] Kéo tay nắm lên/xuống: sheet theo tay, thả chậm về nấc gần nhất, vuốt nhanh về nấc theo hướng vuốt;
      ảnh thai nhi và hàng chip mờ dần khi kéo lên.
- [ ] Ở nấc cao: bài viết cuộn bình thường; cuộn lên đầu bài rồi kéo xuống → sheet thu về nấc thấp.
- [ ] Đổi tuần bằng chip hoặc vuốt ngang trên nền: giữ nguyên nấc và thẻ đang chọn, bài viết về đầu.
- [ ] Triệu chứng → "Cơn gò" → "Xem dấu hiệu cần đi khám": sheet mở ở nấc cao, thẻ Mẹ, đúng mục cảnh báo.
- [ ] VoiceOver: tay nắm đọc "Mở rộng bài viết" / "Thu gọn bài viết" và chạm hai lần để đổi nấc; câu kích thước
      đọc đơn vị đầy đủ ("gam", "milimét"); ở nấc cao không chạm tới chip tuần phía sau.
- [ ] Reduce Motion bật: sheet chuyển nấc tức thì, ảnh nền chỉ mờ đi chứ không thu nhỏ.
- [ ] Dynamic Type lớn nhất: Chi tiết tuần mở thẳng nấc cao, chữ không bị cắt.
- [ ] Tuần 4–6 không có câu số đo; tuần 41–42 có dòng "Số liệu chuẩn Hadlock chỉ đến tuần 40."
```

- [ ] **Step 4: Final local checks, commit, push, full CI**

```bash
scripts/test-core.sh
xcodegen generate --quiet
xcodebuild -project KickCounter.xcodeproj -scheme KickCounter \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO -quiet build-for-testing
git add README.md docs/content-review-for-doctor.md docs/release-checklist.md
git commit -F - <<'MSG'
docs: week articles for the doctor review, README and release checklist

Section 9 of the doctor review lists every week's article, the writing
guide and the generated size sentence (from the Hadlock data already
reviewed). The README explains the sheet, the article field and
set-week-articles.py; the release checklist adds the phase 6 checks.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `Test run with 431 tests`; `xcodebuild` exits 0; CI log shows `==> UI tests: full suite`; `CI PASSED`, including classes no task scoped (`KickCounterUITests`, `ScreenshotTests`, `HistoryUITests`, `KicksUITests`, `OnboardingUITests`, `NavigationUITests`, `CycleUITests`, `WeightUITests`, …).

- [ ] **Step 5: Final visual pass and hand-off**

Open every `week-article-*`, `week-12-*` and `pregnancy-home-*` PNG from this run with the Read tool and recheck the Task 3 list (now with written articles in every shown week). Do not trigger TestFlight; tell the user they can run `gh workflow run testflight.yml --ref feat/week-article-sheet` and follow "Giai đoạn 6" in the release checklist. Then use `superpowers:finishing-a-development-branch` to open the PR `feat/week-article-sheet` → `main` (run `scripts/test-core.sh` before pushing, as the pre-push hook does).

---

## Self-review

**1. Spec coverage**

| Spec | Task |
|---|---|
| §1 layout: fixed background + draggable sheet, two detents, spring, Reduce Motion | T2 (`ArticleSheet`, `LunaMotion.sheet`), T3 (`WeekDetailView`) |
| §1 writing: articles for weeks 4–42, Bé / Mẹ, headings, references | T3 (`WeekArticleView`, week 24), T4–T6 |
| §2 image slots with fallbacks | T1 (`WeekArtworkName`), T3 (`WeekArtwork`) |
| §3.1 entry points unchanged | T3 (signature kept; Today and Symptoms untouched; tests through both) |
| §3.2 background: gradient, ✕, escape, large fetus, chips `weekChip-N`, horizontal swipe rule | T3 |
| §3.3 sheet: 24 pt corners, card colour, handle button `weekSheetHandle` with expand/collapse labels, title + pending-review row, `SegmentedPill` `weekTab-baby/mom`, scrolling body | T2, T3 |
| §3.4 detents, progress → fetus opacity/scale and chip opacity, initial detent (default, `scrollToWarnings`, AX sizes) | T1 (resolver), T2, T3 |
| §3.5 drag, clamp + rubber band, 600 pt/s flick, nearest, hand-off at offset ≤ 0 via GeometryReader preference, peek body drag, week change keeps detent/tab, scroll reset, 0.2 s cross-fade, spring, no animation when disabled, no scale under Reduce Motion | T1, T2, T3 |
| §3.6 from the safety card: expanded, Mẹ, `weekWarnings` | T3 (+ `WeekArticleSheetUITests.testSafetyCardOpensTheWarningsExpanded`) |
| §4.1 model, version 3, v2 decodes as nil, sources append-only | T1 |
| §4.2 generated size line per week range, decimal comma, `weekArticle.size.*`, estimate note kept, tiles removed, spoken reading | T1, T3 |
| §4.3 tab content and order, emoji fallback 64 pt in 120 pt circle, `DisclosureGroup` references `weekReferences`, bullet fallback, typography, tokens | T3 |
| §4.4 writing guide | T4–T6 (verbatim), T7 (§9 in Vietnamese) |
| §4.5 content checks: completeness, non-empty, word limits, sources, imperial units, version 3, size-line cases 5/8/12/31/40/42 | T1 (checks + tests), T4–T6 (completeness widened, fully enforced in T6) |
| §4.6 reviewed false, release hiding unchanged, doctor §9, no reviewer name | T4–T6, T7 |
| §5 components and files | T1–T3 (same names and locations) |
| §6 KickCore tests, UI tests (peek/expand/collapse, Bé→Mẹ warnings, chip keeps Mẹ, safety card), screenshots (peek/expanded × Bé/Mẹ vi light, en dark, AX5, safety card), scoped CI + full final run | T1, T3, T7 |
| §7 delivery order | T1–T7 |
| §8 risks: hand-off only at offset ≤ 0 with UI + unit tests; content in three batches with guide and checks; AX opens expanded with AX5 screenshot | T1, T2, T3, T4–T6 |

No gaps.

**2. Placeholder scan.** Code steps contain complete code. The `{ … }` in Tasks 4–6 stand for the articles those tasks exist to write; each is specified by the writing guide, the JSON shape, the full week-24 example, the per-week fact checklist and automatic checks that reject incomplete or out-of-range text.

**3. Type consistency.** `ArticleTab` (T1) is the tab type in T3; `SheetDetent` / `SheetDetentResolver` method names match between T1 and T2; `ArticleSheet`'s initializer in T2's Interfaces matches its use in T3; `WeekSizeLine.Templates(length:lengthAndWeight:weightAndRange:)` and `Numbers(length:weight:rangeLow:rangeHigh:)` match between T1, the T1 tests and T3's `localized` / `formatted(spoken:)`; `WeekArtworkName.fetus(week:)` / `.fruit(week:)` match T3; `WeekArticleView.warningsAnchor == "weekWarnings"` is used by `WeekDetailView`'s `initialAnchor`; `BundledArticleTests.requiredArticleWeeks` goes nil → `4...13` → `4...27` → `WeeklyContentLibrary.weekRange` with each replacement quoting the previous value; the three `weekArticle.size.*` strings in T3 equal the templates in `WeekSizeLineTests`. KickCore test counts: 396 → 430 (T1: 4 + 7 + 8 + 10 + 5) → 431 (T3).
