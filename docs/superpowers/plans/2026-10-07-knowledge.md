# Knowledge: in-depth articles by trimester (Phase 7) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. For the UI task (2) also apply the `ui-ux-pro-max` skill to review visual detail, but do **not** change behaviour, accessibility identifiers, strings or colour tokens fixed by this plan. Tasks 3–5 write prose, not code (apart from one line of UI test each in Tasks 3 and 5): follow the writing guide, the review rules and the fact checklists in each task exactly.

**Goal:** Give pregnancy mode 18 original vi + en in-depth articles in 6 topics, tagged by trimester, reachable from a "Suggested for trimester N" card on Today, a library screen with trimester chips, and a reading screen built on Phase 6's `ArticleSheet`.

**Architecture:** Everything testable lives in `KickCore` (pure Swift, tested locally): the data model (`KnowledgeContent`, `KnowledgeTopic`, `KnowledgeArticle`, `KnowledgeSection`, reusing `LocalizedText` and `LocalizedParagraphs`), the bundled `knowledge-content.json` (version 1) and its loader with a nil-on-failure path (`KnowledgeLibrary`), visibility filtering and library sections, the pure `KnowledgeSuggester`, the content checks (`KnowledgeChecks`, plus bundle tests whose required-article set widens with each content batch), and `SheetDragState`, which fixes Phase 6's stuck-drag follow-up in `ArticleSheet`. The app adds shared reading pieces (`App/DesignSystem/ArticleText.swift`, extracted from `WeekArticleView` and `WeekDetailView` without changing their output), the Today card, the library and the reading screen (`App/Knowledge/`). Content is written in three batches through `scripts/set-knowledge-articles.py`.

**Tech Stack:** Swift 6, SwiftUI (iOS 17), Swift Testing (KickCore), XCTest (UI), XcodeGen, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-07-knowledge-design.md` (the requirements; build exactly what it says). Previous plan for conventions: `docs/superpowers/plans/2026-10-06-week-article-sheet.md`. Phase 6 writing guide: `docs/superpowers/specs/2026-10-06-week-article-sheet-design.md` §4.4.

## Global Constraints

- Swift language mode 6 with strict concurrency; iOS deployment target `17.0`; package platforms `.iOS(.v17), .macOS(.v14)`. No third-party SDKs, no server, no data collection, no CloudKit change (content is bundled).
- Work on branch `feat/knowledge` (already checked out). **Never** change the `gh` account or log in. Every commit message ends with a blank line, then the trailer block: `CI-Only-Testing: <UI test classes>` on its own line, immediately followed by `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (no blank line between them). Use `git commit -F - <<'MSG' … MSG` exactly as shown in each task. The only exception is Task 6, whose commit deliberately has **no** `CI-Only-Testing:` line so CI runs the full UI suite (spec §5, "The docs task runs the full suite").
- **`KickCore` must not import SwiftUI, UIKit or SwiftData.** The asset lookup (`UIImage(named:)`) stays in the app; KickCore only builds the name (`KnowledgeArtworkName`).
- Every UI string goes through `L10n` (`Shared/L10n.swift`) and lives in `Shared/Localizable.xcstrings` with both `en` and `vi`. Strings are added or removed **only** with `scripts/add-strings.py` (JSON `{"key": ["English", "Tiếng Việt"]}` on stdin; `--remove key …`). Never `Text("…")` with a literal or interpolation: use `Text(L10n.…)`, `Text(someString)` for content, or `Text(verbatim:)` for symbols and previews.
- Colours come only from Luna tokens: `.luna(.<token>)` (`App/DesignSystem/LunaColor.swift`, values in `KickCore/LunaPalette.swift`). No hex in views. Every text/background pair must be declared in `LunaContrast.usages`; `ContrastTests` must stay green. Pairs used in this phase (all already declared): `textPrimary` on `card`, `textSecondary` on `card`, `articleText` on `card`, `pregOnSoft` on `pregSoft` (row icon, "See more" pill, selected chip, artwork fallback), `textSecondary` on `background` (idle chip), `textPrimary` on `background` (topic headings), `articleText` on `surface` (reviewer icon); the ✕ is `textPrimary` on `card`.
- Fonts: only `Font.luna(_:)` / `Font.luna(size:weight:relativeTo:)` (Dynamic Type). SF Symbols may use `.system(size:weight:)`, as the existing ✕ and reviewer icons do; the artwork fallback symbol is `.system(size: 96, weight: .light)` (spec §4.3).
- Animation is gated by `LunaMotion.isEnabled` (false under `-uiTesting`) **and** Reduce Motion, exactly as `ArticleSheet` already does. The reading screen inherits it; the artwork only fades and shrinks (no shrink under Reduce Motion), like the week detail's fetus.
- **Local verification only:** implementers run `scripts/test-core.sh`, `xcodegen generate --quiet` and `xcodebuild … build-for-testing` on the "iPhone 18 Pro" simulator (exact command below). They **never** run UI tests locally; UI tests and screenshots run on CI (`git push` + `scripts/ci-wait.sh`).
- Lessons from Phase 6 CI and review (mandatory):
  - **No Button in a draggable sheet header.** The sheet follows the finger, so a Button in the header stays under it and fires its tap on release. The reading screen's header holds only the title and the review row (no Buttons). If a later change ever puts a Button there, it must pass `headerDragActive:` to `ArticleSheet` and ignore the Button's action while that flag is true, as `WeekDetailView` does for its tab pill.
  - The ✕ uses the Phase 6 treatment: opaque `card` circle, hairline `divider` border, `accessibilitySortPriority(1)` (shared as `ArticleCloseButton`). The sheet opens expanded at accessibility text sizes or with VoiceOver on.
  - SwiftUI `List` / lazy rows / anything below the fold only exist once scrolled near the viewport: UI tests call `app.scrollUntilHittable(element)` before asserting or tapping. Wait with `waitForExistence` / `waitForLabel` / an `XCTNSPredicateExpectation`, never a fixed `sleep`.
  - Put `.accessibilityElement(children: .combine)` (or `.contain`) **before** `.accessibilityIdentifier(…)`, or the identifier lands on a child.
  - Don't scroll elements that sit under sticky insets (the sheet's handle and title are fixed above the scrolling article; tap them directly).
- Keep every accessibility identifier the existing tests use (`weekDetailClose`, `weekReviewer`, `weekReferences`, `weekSheetHandle`, …). New: `knowledgeCard`, `knowledgeSuggestion-<id>`, `knowledgeSeeMore`, `knowledgeTrimester-1…3`, `knowledgeArticle-<id>`, `knowledgeSheetHandle`, `knowledgeArticleScroll`, `knowledgeTitle`, `knowledgeReviewer`, `knowledgeSummary`, `knowledgeReferences`, `knowledgeClose`.
- Content stays `"reviewed": false` for every article (a check enforces it). Release builds hide unreviewed articles (`BuildFlags.contentVisibility`, unchanged), so release builds show neither the card nor the library until the doctor signs articles off.
- Out of scope (spec §2): read/unread state, bookmarks, search, trying-to-conceive content, the artwork itself, any tab-bar change.

## Verification workflow

- **Local, every task with code:**
  ```bash
  scripts/test-core.sh
  xcodegen generate --quiet
  xcodebuild -project KickCounter.xcodeproj -scheme KickCounter \
    -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
    -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO -quiet build-for-testing
  ```
  `xcodebuild` must exit 0 with no `<file>.swift:<line>:<col>: error:` lines (a bare "error: the following command failed with exit code 0" line on a first build is harmless). Do not run `xcodebuild test`. KickCore test count after each task: 431 (before) → 472 (Task 1); Tasks 2–6 keep 472.
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
| 1 | §3.3 `suggestions(for:from:count:)` needs "topic display order" but takes no topics | The KickCore signature is `KnowledgeSuggester.suggestions(for week: Int, from: [KnowledgeArticle], topicOrder: [String], count: Int = 3)`. Topics missing from `topicOrder` sort last. The app calls the convenience `KnowledgeLibrary.suggestions(forWeek:visibility:count:)`, which passes the file's topic order. |
| 2 | §3.3 "rotate by `week % eligible.count`" | Rotate **left**: the rotated list starts at index `clampedWeek % eligible.count`. The clamped week (4…42, `WeeklyContentLibrary.clampedWeek`) is used both for the trimester and for the rotation. The result keeps pick order: the one-per-topic pass, then the fill. |
| 3 | §3.5 "each trimester has at least 3 articles" vs "completeness widens step by step" | Trimester coverage is reported only once `requiredArticleIDs` contains all 18 ids (Task 5). Every article that exists is always checked in full. |
| 4 | §3.5 "exactly the 6 topics and 18 article ids" | `KnowledgeChecks.catalogue` holds §3.1's ids with their topic and trimesters. An article must be in it (`unknownArticle`), unique, and have exactly the catalogue's topic and trimesters. `BundledKnowledgeTests` also requires catalogue order in the file; the script keeps it. |
| 5 | §3.5 "allow-list for caffeine" | `KnowledgeChecks.doseAllowList` holds two exact sentences (en, vi) with "200 mg". `food-safety` copies them verbatim; a dose unit anywhere else fails. |
| 6 | §3.2 "missing or invalid" | Invalid = undecodable JSON or `version != 1`. `KnowledgeLibrary.load(from: URL?) -> KnowledgeLibrary?` logs and returns nil (unit-tested); `loadBundled()` calls it with the bundle URL. `AppEnvironment` stores the result; the environment key `knowledgeLibrary` is nil on failure, which hides the card. |
| 7 | §5 "Today shows the card with 3 suggestions" while Task 2 has one article | In Task 2 the UI test expects 1 suggestion (`safe-exercise`); Task 3 changes it to exactly 3 (trimester 2 then has 5 articles in 2 topics). |
| 8 | §5 "tapping trimester 3 shows `signs-of-labour`" before that article exists | Until Task 5 the test checks `safe-exercise` (trimesters 1–3); Task 5 switches the row to `signs-of-labour`. |
| 9 | §4.3 identifiers and strings not named | Handle `knowledgeSheetHandle`, scroll view `knowledgeArticleScroll`, review row `knowledgeReviewer`. Reused strings: handle labels `weekArticleExpand`/`weekArticleCollapse`, `weekArticleReferences`, `commonClose`, `weekReviewer`, `weekPendingReview`, chip titles `pregnancyTrimester(n)` ("Tam cá nguyệt 2"). New strings (4): `knowledge.card.title`, `knowledge.seeMore`, `knowledge.title`, `knowledge.reviewed` ("…has reviewed this article": `week.reviewed` says "this week"). |
| 10 | §4.3 "the existing pending-review row" and "the Phase 6 treatment" for ✕ | Both move from `WeekDetailView` into `App/DesignSystem/ArticleText.swift` as `ArticleReviewerRow` and `ArticleCloseButton`, with `ArticleHeading`, `ArticleParagraphs` and `ArticleReferences` from `WeekArticleView`. The week detail's output is unchanged; its UI tests and screenshots run in Task 2's CI scope to prove it. |
| 11 | §4.3 peek position (no chips) | Peek top = 52 pt (✕ row) + artwork height + 12, artwork height = `min(0.36 × height, 320)`, capped at `height − 220` so the handle, title and review row stay visible. |
| 12 | §4.1 placement / §4.2 navigation | The card is the last card on pregnancy Today, after the next check-up card. "See more" pushes `PregnancyRoute.knowledge(trimester:)` onto Today's `NavigationStack`. The card and the library each present the reading screen with their own `fullScreenCover(item:)`. The library's default chip is the trimester Today passes; `nil` (no due date) gives 1. |
| 13 | Phase 6 follow-up: `isDragging`, `dragTranslation`, `headerDragActive` stuck after a cancelled drag | Task 1: the drag lives in one KickCore value (`SheetDragState`, unit-tested); two `@GestureState` flags reset by themselves on cancel, and when both are false the sheet clears whatever `onEnded` did not (back to its detent, `headerDragActive = false`). Normal drags behave exactly as before. |
| 14 | §3.2 `sources` | `knowledge-content.json` has its own 10 citations (Task 1 lists them; append-only). Topic symbols: `fork.knife`, `figure.walk`, `moon.zzz`, `heart`, `stethoscope`, `figure.and.child.holdinghands` (all iOS 16+). |
| 15 | §3.4 "medicine names" | As in Phase 6: folic acid / axit folic and iron / sắt may be named **without** doses, "as your doctor or midwife advises"; vaccines are named by disease; no other medicine or product names; no procedure promises. |
| 16 | §3.4 "word count" | Words = whitespace-separated tokens (Vietnamese: syllables). Article = summary + every heading + every paragraph; the title is not counted. |
| 17 | §6 "the facts added beyond the brief" (Task 6) | Each content commit lists its added facts in an `Added beyond the checklist:` block of the commit body; Task 6 collects them with `git log`. |

## File Structure

```
kick-counter/
├── Packages/KickCore/
│   ├── Sources/KickCore/
│   │   ├── KnowledgeContent.swift              # T1 (new): model + KnowledgeArtworkName
│   │   ├── KnowledgeLibrary.swift              # T1 (new): loader, visibility, sections, suggestions, references
│   │   ├── KnowledgeSuggester.swift            # T1 (new): the pure 3-article pick
│   │   ├── KnowledgeChecks.swift               # T1 (new): KnowledgeIssue, catalogue, checks
│   │   ├── SheetDragState.swift                # T1 (new): the sheet's in-flight drag
│   │   └── Resources/knowledge-content.json    # T1 version 1, topics, sources; T2 safe-exercise; T3–T5 the rest
│   └── Tests/KickCoreTests/
│       ├── KnowledgeTestSupport.swift          # T1 (new): fixtures
│       ├── KnowledgeContentTests.swift         # T1 (new)
│       ├── KnowledgeSuggesterTests.swift       # T1 (new)
│       ├── KnowledgeLibraryTests.swift         # T1 (new)
│       ├── KnowledgeChecksTests.swift          # T1 (new)
│       ├── BundledKnowledgeTests.swift         # T1 (new); T2–T5 widen requiredArticleIDs
│       └── SheetDragStateTests.swift           # T1 (new)
├── scripts/set-knowledge-articles.py           # T1 (new): writes articles, prints word counts
├── App/
│   ├── DesignSystem/ArticleSheet.swift         # T1: cancelled-drag fix
│   ├── DesignSystem/ArticleText.swift          # T2 (new): heading, paragraphs, references, reviewer row, ✕
│   ├── Pregnancy/WeekArticleView.swift         # T2: uses ArticleText
│   ├── Pregnancy/WeekDetailView.swift          # T2: uses ArticleText
│   ├── Pregnancy/PregnancyTodayView.swift      # T2: knowledge card + route
│   ├── Knowledge/KnowledgeRows.swift           # T2 (new): rows + KnowledgeSelection
│   ├── Knowledge/KnowledgeCard.swift           # T2 (new): Today card
│   ├── Knowledge/KnowledgeLibraryView.swift    # T2 (new): library
│   ├── Knowledge/KnowledgeArticleView.swift    # T2 (new): reading screen + KnowledgeArtwork
│   ├── ContentEnvironment.swift                # T2: knowledgeLibrary key
│   ├── AppEnvironment.swift, KickCounterApp.swift   # T2: load + inject
├── Shared/{L10n.swift, Localizable.xcstrings}  # T2
├── UITests/
│   ├── KnowledgeUITests.swift                  # T2 (new); T3, T5 one line each
│   └── KnowledgeScreenshotTests.swift          # T2 (new)
├── README.md                                   # T6
└── docs/{content-review-for-doctor.md, release-checklist.md}   # T6
```

---
### Task 1: KickCore — knowledge model, loader, suggester, checks; the sheet's cancelled-drag fix

Adds the version-1 data model and bundled JSON (spec §3.2), the loader with its failure path, visibility filtering and library sections, the pure suggester (§3.3), the content checks with a required-article set that starts empty (§3.5), and `scripts/set-knowledge-articles.py`. It also closes the Phase 6 follow-up: `ArticleSheet` no longer stays half-dragged when a drag is cancelled. No screen shows knowledge yet.

**Files:**
- Create: `Packages/KickCore/Sources/KickCore/KnowledgeContent.swift`, `KnowledgeLibrary.swift`, `KnowledgeSuggester.swift`, `KnowledgeChecks.swift`, `SheetDragState.swift`, `Resources/knowledge-content.json` (all in `Packages/KickCore/Sources/KickCore/`)
- Create (tests): `Packages/KickCore/Tests/KickCoreTests/KnowledgeTestSupport.swift`, `KnowledgeContentTests.swift`, `KnowledgeSuggesterTests.swift`, `KnowledgeLibraryTests.swift`, `KnowledgeChecksTests.swift`, `BundledKnowledgeTests.swift`, `SheetDragStateTests.swift`
- Create: `scripts/set-knowledge-articles.py`
- Modify: `App/DesignSystem/ArticleSheet.swift` (state, `top`, `body` modifiers, `headerDrag`, `bodyDrag`, `move`, `settle`)

**Interfaces:**
- Consumes (existing): `ContentLanguage` (`.en`, `.vi`, `CaseIterable`), `LocalizedText` (`en`, `vi`, `text(_:)`, internal memberwise init), `LocalizedParagraphs` (`en`, `vi`, `init(en:vi:)`, `paragraphs(_:)`), `Trimester` (`.first/.second/.third`, `rawValue` 1…3, `init(week:)`, `CaseIterable`), `WeeklyContentLibrary.clampedWeek(_:)`, `ContentVisibility` (`.all`, `.reviewedOnly`), `ContentValidator.isBlank(_:)` (internal), `WeekArticleChecks.wordCount(_:)` and `.containsImperialUnit(_:)`, `SheetDetentResolver` (unchanged).
- Produces (later tasks use exactly these):
  - `public struct KnowledgeContent: Codable, Equatable, Sendable { version: Int; sources: [String]; topics: [KnowledgeTopic]; articles: [KnowledgeArticle] }`
  - `public struct KnowledgeTopic: Codable, Equatable, Sendable, Identifiable { id: String; name: LocalizedText; symbol: String }`
  - `public struct KnowledgeArticle: Codable, Equatable, Sendable, Identifiable { id: String; topic: String; trimesters: [Int]; reviewed: Bool; title: LocalizedText; summary: LocalizedText; sections: [KnowledgeSection]; sources: [Int] }` with `public func applies(to: Trimester) -> Bool` and internal `texts(_ language:) -> [(field: String, text: String)]` (fields `"title"`, `"summary"`, `"section N heading"`, `"section N"`).
  - `public struct KnowledgeSection: Codable, Equatable, Sendable { heading: LocalizedText; paragraphs: LocalizedParagraphs }`
  - `public enum KnowledgeArtworkName { static func asset(articleID: String) -> String }` → `"Knowledge-safe-exercise"`.
  - `public enum KnowledgeLoadError: Error, Equatable { case resourceMissing, unsupportedVersion(Int) }`
  - `public struct KnowledgeTopicSection: Equatable, Sendable, Identifiable { topic: KnowledgeTopic; articles: [KnowledgeArticle]; id: String }`
  - `public struct KnowledgeLibrary: Sendable` — `resourceName = "knowledge-content"`, `supportedVersion = 1`, `document`, `init(document:)`, `init(data:) throws`, `topics`, `sources`, `topic(id:)`, `article(id:)`, `articles(visibility:)`, `sections(trimester:visibility:) -> [KnowledgeTopicSection]`, `suggestions(forWeek:visibility:count:) -> [KnowledgeArticle]`, `references(for:) -> [String]`, `static bundled() throws`, `static load(from: URL?) -> KnowledgeLibrary?`, `static loadBundled() -> KnowledgeLibrary?`.
  - `public enum KnowledgeSuggester { static let defaultCount = 3; static func suggestions(for week: Int, from: [KnowledgeArticle], topicOrder: [String], count: Int = 3) -> [KnowledgeArticle] }`
  - `public enum KnowledgeIssue` (cases in Step 8) and `public enum KnowledgeChecks` — `Entry`, `topicIDs`, `catalogue`, `articleIDs`, `summaryLimit` (`.en: 35, .vi: 45`), `articleWords` (`300...500`), `sectionRange` (`2...4`), `paragraphRange` (`1...4`), `minimumPerTrimester` (`3`), `doseAllowList`, `validate(_:requiredArticleIDs:) -> [KnowledgeIssue]`, `wordCount(_:)`, `articleWordCount(_:language:)`, `containsDoseUnit(_:)`.
  - `BundledKnowledgeTests.requiredArticleIDs: Set<String>` (`[]` now).
  - `public struct SheetDragState: Sendable, Equatable` — `translation: Double?`, `handoffStart: Double?` (both `public private(set)`), `isDragging`, `move(by:)`, `beginHandoff(at:)`, `@discardableResult end() -> Bool`.
  - `scripts/set-knowledge-articles.py`: JSON `{"<id>": <article without id>}` on stdin → writes the articles in catalogue order, prints `<id> en|vi: summary S, words W, sections N`.

- [ ] **Step 1: Write the failing model test**

`Packages/KickCore/Tests/KickCoreTests/KnowledgeTestSupport.swift` (whole file):
```swift
import Foundation
@testable import KickCore

/// `count` words ending in a full stop: knowledgeWords(3, "chữ") == "chữ chữ chữ."
func knowledgeWords(_ count: Int, _ word: String) -> String {
    Array(repeating: word, count: count).joined(separator: " ") + "."
}

/// The topic ids of spec §3.1, in display order.
let knowledgeTopicIDs = ["nutrition", "movement", "sleep", "feelings", "checkups", "birth"]

/// A topic with a placeholder name.
func knowledgeTopic(_ id: String) -> KnowledgeTopic {
    KnowledgeTopic(id: id, name: LocalizedText(en: "Topic \(id)", vi: "Chủ đề \(id)"), symbol: "book")
}

/// An article that passes every check with two sources available.
/// en: summary 20 + headings 2 × 3 + paragraphs 4 × 75 = 326 words.
/// vi: summary 30 + headings 2 × 4 + paragraphs 4 × 80 = 358 words.
func knowledgeArticle(
    _ id: String,
    topic: String,
    trimesters: [Int],
    reviewed: Bool = false
) -> KnowledgeArticle {
    let section = KnowledgeSection(
        heading: LocalizedText(en: knowledgeWords(3, "word"), vi: knowledgeWords(4, "mục")),
        paragraphs: LocalizedParagraphs(
            en: [knowledgeWords(75, "word"), knowledgeWords(75, "word")],
            vi: [knowledgeWords(80, "chữ"), knowledgeWords(80, "chữ")]
        )
    )
    return KnowledgeArticle(
        id: id,
        topic: topic,
        trimesters: trimesters,
        reviewed: reviewed,
        title: LocalizedText(en: "Title \(id)", vi: "Tiêu đề \(id)"),
        summary: LocalizedText(en: knowledgeWords(20, "word"), vi: knowledgeWords(30, "chữ")),
        sections: [section, section],
        sources: [0]
    )
}

/// Version 1 with the six topics of spec §3.1, two sources and `articles`.
func knowledgeContent(_ articles: [KnowledgeArticle]) -> KnowledgeContent {
    KnowledgeContent(
        version: 1,
        sources: ["Source A", "Source B"],
        topics: knowledgeTopicIDs.map(knowledgeTopic),
        articles: articles
    )
}
```

`Packages/KickCore/Tests/KickCoreTests/KnowledgeContentTests.swift` (whole file):
```swift
import Foundation
import Testing
@testable import KickCore

/// Phase 7 spec §3.2: the knowledge data model.
struct KnowledgeContentTests {
    @Test func documentDecodes() throws {
        let json = """
        {"version": 1, "sources": ["S0", "S1"],
         "topics": [{"id": "movement", "name": {"en": "Movement", "vi": "Vận động"}, "symbol": "figure.walk"}],
         "articles": [{
           "id": "safe-exercise", "topic": "movement", "trimesters": [1, 2, 3], "reviewed": false,
           "title": {"en": "Title", "vi": "Tiêu đề"},
           "summary": {"en": "Summary.", "vi": "Tóm tắt."},
           "sections": [
             {"heading": {"en": "One", "vi": "Một"}, "paragraphs": {"en": ["A.", "B."], "vi": ["A.", "B."]}},
             {"heading": {"en": "Two", "vi": "Hai"}, "paragraphs": {"en": ["C."], "vi": ["C."]}}
           ],
           "sources": [1]
         }]}
        """
        let content = try JSONDecoder().decode(KnowledgeContent.self, from: Data(json.utf8))
        #expect(content.version == 1)
        #expect(content.topics[0].name.text(.vi) == "Vận động")
        #expect(content.topics[0].symbol == "figure.walk")
        let article = try #require(content.articles.first)
        #expect(article.id == "safe-exercise")
        #expect(article.trimesters == [1, 2, 3])
        #expect(article.sections[0].paragraphs.paragraphs(.en) == ["A.", "B."])
        #expect(article.sources == [1])
        #expect(
            article.texts(.en).map(\.field)
                == ["title", "summary", "section 1 heading", "section 1", "section 1", "section 2 heading", "section 2"]
        )
    }

    @Test func appliesToItsTrimesters() {
        let article = knowledgeArticle("sleep-positions", topic: "sleep", trimesters: [2, 3])
        #expect(!article.applies(to: .first))
        #expect(article.applies(to: .second))
        #expect(article.applies(to: .third))
    }

    @Test func artworkAssetName() {
        #expect(KnowledgeArtworkName.asset(articleID: "safe-exercise") == "Knowledge-safe-exercise")
    }
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `scripts/test-core.sh --filter KnowledgeContentTests`
Expected: build FAILS with `cannot find type 'KnowledgeArticle' in scope` (and the other knowledge types).

- [ ] **Step 3: Add the model**

`Packages/KickCore/Sources/KickCore/KnowledgeContent.swift` (whole file):
```swift
import Foundation

/// Root of `knowledge-content.json` (phase 7 spec §3.2): in-depth articles
/// grouped by topic and tagged by trimester. Checked by `KnowledgeChecks`.
public struct KnowledgeContent: Codable, Equatable, Sendable {
    public var version: Int
    /// Full citations; articles refer to them by index (append-only, never reordered).
    public var sources: [String]
    /// In display order.
    public var topics: [KnowledgeTopic]
    public var articles: [KnowledgeArticle]
}

public struct KnowledgeTopic: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: LocalizedText
    /// SF Symbol name: the row icon, and the reading screen's artwork fallback.
    public var symbol: String
}

public struct KnowledgeArticle: Codable, Equatable, Sendable, Identifiable {
    /// Stable kebab-case id, e.g. "safe-exercise".
    public var id: String
    /// A `KnowledgeTopic.id`.
    public var topic: String
    /// The trimesters the article applies to: a non-empty, ascending subset of 1...3.
    public var trimesters: [Int]
    /// False until the obstetrician signs the article off; release builds hide it.
    public var reviewed: Bool
    public var title: LocalizedText
    /// One sentence: the row subtitle and the bold lead of the reading screen.
    public var summary: LocalizedText
    /// 2–4 sections.
    public var sections: [KnowledgeSection]
    /// Indices into `KnowledgeContent.sources`; at least one.
    public var sources: [Int]

    public func applies(to trimester: Trimester) -> Bool {
        trimesters.contains(trimester.rawValue)
    }

    /// Every text of one language with its field name, in reading order:
    /// "title", "summary", then "section N heading" and "section N" (paragraphs), N from 1.
    func texts(_ language: ContentLanguage) -> [(field: String, text: String)] {
        var result: [(field: String, text: String)] = [
            (field: "title", text: title.text(language)),
            (field: "summary", text: summary.text(language)),
        ]
        for (index, section) in sections.enumerated() {
            result.append((field: "section \(index + 1) heading", text: section.heading.text(language)))
            for paragraph in section.paragraphs.paragraphs(language) {
                result.append((field: "section \(index + 1)", text: paragraph))
            }
        }
        return result
    }
}

public struct KnowledgeSection: Codable, Equatable, Sendable {
    public var heading: LocalizedText
    /// 1–4 paragraphs per language.
    public var paragraphs: LocalizedParagraphs
}

/// The optional per-article artwork asset (phase 7 spec §4.3). The app falls back
/// to the topic's SF Symbol while an asset is missing.
public enum KnowledgeArtworkName {
    /// "Knowledge-safe-exercise".
    public static func asset(articleID: String) -> String { "Knowledge-" + articleID }
}
```

Run: `scripts/test-core.sh --filter KnowledgeContentTests`
Expected: PASS, 3 tests.

- [ ] **Step 4: Write the failing suggester test**

`Packages/KickCore/Tests/KickCoreTests/KnowledgeSuggesterTests.swift` (whole file):
```swift
import Testing
@testable import KickCore

/// Phase 7 spec §3.3: three stable, rotating, topic-spread suggestions.
struct KnowledgeSuggesterTests {
    /// Trimester 2: a1, a2, b1, c1. Trimester 3: a1, b1, c1, c2. Trimester 1: a1, b2.
    let articles = [
        knowledgeArticle("c2", topic: "c", trimesters: [3]),
        knowledgeArticle("b1", topic: "b", trimesters: [2, 3]),
        knowledgeArticle("a2", topic: "a", trimesters: [2]),
        knowledgeArticle("c1", topic: "c", trimesters: [2, 3]),
        knowledgeArticle("b2", topic: "b", trimesters: [1]),
        knowledgeArticle("a1", topic: "a", trimesters: [1, 2, 3]),
    ]
    let order = ["a", "b", "c"]

    private func ids(_ week: Int, order: [String]? = nil, from list: [KnowledgeArticle]? = nil) -> [String] {
        KnowledgeSuggester.suggestions(for: week, from: list ?? articles, topicOrder: order ?? self.order).map(\.id)
    }

    @Test func onlyTheWeeksTrimester() {
        #expect(ids(10) == ["a1", "b2"]) // trimester 1: fewer than three, all of them
        #expect(!ids(30).contains("a2")) // a2 is trimester 2 only
        #expect(!ids(20).contains("c2")) // c2 is trimester 3 only
    }

    @Test func theSameWeekGivesTheSameArticles() {
        #expect(ids(24) == ids(24))
        #expect(ids(24) == ["a1", "b1", "c1"]) // 24 % 4 = 0
    }

    @Test func eachWeekStartsOneArticleLater() {
        #expect(ids(25) == ["a2", "b1", "c1"]) // a2, b1, c1, a1
        #expect(ids(26) == ["b1", "c1", "a1"]) // b1, c1, a1, a2
        #expect(ids(27) == ["c1", "a1", "b1"]) // c1, a1, a2, b1
        #expect(ids(24).first != ids(25).first)
    }

    @Test func oneArticlePerTopicFirst() {
        #expect(ids(30) == ["c1", "a1", "b1"]) // 30 % 4 = 2: c1, c2, a1, b1; c2 skipped
    }

    @Test func freeSlotsAreFilledInRotatedOrder() {
        let twoTopics = [
            knowledgeArticle("a1", topic: "a", trimesters: [2]),
            knowledgeArticle("a2", topic: "a", trimesters: [2]),
            knowledgeArticle("a3", topic: "a", trimesters: [2]),
            knowledgeArticle("b1", topic: "b", trimesters: [2]),
        ]
        #expect(ids(14, from: twoTopics) == ["a3", "b1", "a1"]) // 14 % 4 = 2: a3, b1, a1, a2
    }

    @Test func sortsByTopicDisplayOrderThenID() {
        #expect(ids(24, order: ["c", "a", "b"]) == ["c1", "a1", "b1"]) // c1, a1, a2, b1
    }

    @Test func noEligibleArticlesGivesNothing() {
        let thirdOnly = [knowledgeArticle("c2", topic: "c", trimesters: [3])]
        #expect(ids(10, from: thirdOnly).isEmpty)
        #expect(ids(10, from: []).isEmpty)
    }

    @Test func weeksAreClampedTo4Through42() {
        #expect(ids(45) == ids(42)) // 42 % 4 = 2: c1, a1, b1 (45 would start at c2)
        #expect(ids(45) == ["c1", "a1", "b1"])
        #expect(ids(1) == ids(4)) // 4 % 2 = 0: a1, b2 (1 would start at b2)
        #expect(ids(1) == ["a1", "b2"])
    }
}
```

Run: `scripts/test-core.sh --filter KnowledgeSuggesterTests`
Expected: build FAILS with `cannot find 'KnowledgeSuggester' in scope`.

- [ ] **Step 5: Implement the suggester**

`Packages/KickCore/Sources/KickCore/KnowledgeSuggester.swift` (whole file):
```swift
import Foundation

/// The three articles on Today's knowledge card (phase 7 spec §3.3). Pure, so
/// the same week always gives the same articles.
public enum KnowledgeSuggester {
    public static let defaultCount = 3

    /// 1. Keep the articles for the trimester of `week` (clamped to 4…42 first).
    /// 2. Sort them by topic display order (`topicOrder`; unknown topics last), then id.
    /// 3. Rotate left by `week % eligible.count`, so the next week starts one article later.
    /// 4. Walk the rotated list taking one article per topic, then fill any free
    ///    slots in rotated order. Fewer than `count` eligible → all of them; none → [].
    public static func suggestions(
        for week: Int,
        from articles: [KnowledgeArticle],
        topicOrder: [String],
        count: Int = defaultCount
    ) -> [KnowledgeArticle] {
        let clamped = WeeklyContentLibrary.clampedWeek(week)
        let trimester = Trimester(week: clamped)
        let rank = Dictionary(topicOrder.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        let eligible = articles
            .filter { $0.applies(to: trimester) }
            .sorted { (rank[$0.topic] ?? Int.max, $0.id) < (rank[$1.topic] ?? Int.max, $1.id) }
        guard !eligible.isEmpty, count > 0 else { return [] }
        let start = clamped % eligible.count
        let rotated = Array(eligible[start...] + eligible[..<start])

        var picked: [KnowledgeArticle] = []
        var topics: Set<String> = []
        for article in rotated where picked.count < count && !topics.contains(article.topic) {
            picked.append(article)
            topics.insert(article.topic)
        }
        for article in rotated where picked.count < count && !picked.contains(where: { $0.id == article.id }) {
            picked.append(article)
        }
        return picked
    }
}
```

Run: `scripts/test-core.sh --filter KnowledgeSuggesterTests`
Expected: PASS, 8 tests.

- [ ] **Step 6: Write the failing library test**

`Packages/KickCore/Tests/KickCoreTests/KnowledgeLibraryTests.swift` (whole file):
```swift
import Foundation
import Testing
@testable import KickCore

/// Phase 7 spec §3.2: loading, visibility and the library sections.
struct KnowledgeLibraryTests {
    private func temporaryFile(_ text: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("knowledge-\(UUID().uuidString).json")
        try Data(text.utf8).write(to: url)
        return url
    }

    private func encoded(_ content: KnowledgeContent) throws -> String {
        String(decoding: try JSONEncoder().encode(content), as: UTF8.self)
    }

    @Test func aMissingFileGivesNil() {
        #expect(KnowledgeLibrary.load(from: nil) == nil)
        let gone = FileManager.default.temporaryDirectory.appendingPathComponent("no-such-\(UUID().uuidString).json")
        #expect(KnowledgeLibrary.load(from: gone) == nil)
    }

    @Test func malformedJSONGivesNil() throws {
        #expect(KnowledgeLibrary.load(from: try temporaryFile("{\"version\": 1, \"topics\": ")) == nil)
    }

    @Test func anotherVersionGivesNil() throws {
        var content = knowledgeContent([])
        content.version = 2
        #expect(KnowledgeLibrary.load(from: try temporaryFile(try encoded(content))) == nil)
        #expect(throws: KnowledgeLoadError.unsupportedVersion(2)) {
            try KnowledgeLibrary(data: Data(try encoded(content).utf8))
        }
    }

    @Test func aValidFileLoads() throws {
        let content = knowledgeContent([knowledgeArticle("safe-exercise", topic: "movement", trimesters: [1, 2, 3])])
        let library = try #require(KnowledgeLibrary.load(from: try temporaryFile(try encoded(content))))
        #expect(library.document == content)
        #expect(library.topics.map(\.id) == knowledgeTopicIDs)
        #expect(library.article(id: "safe-exercise")?.topic == "movement")
        #expect(library.article(id: "nope") == nil)
        #expect(library.topic(id: "sleep")?.name.text(.en) == "Topic sleep")
    }

    @Test func reviewedOnlyDropsUnreviewedArticles() {
        let library = KnowledgeLibrary(document: knowledgeContent([
            knowledgeArticle("food-safety", topic: "nutrition", trimesters: [1, 2, 3], reviewed: true),
            knowledgeArticle("safe-exercise", topic: "movement", trimesters: [1, 2, 3]),
        ]))
        #expect(library.articles(visibility: .all).map(\.id) == ["food-safety", "safe-exercise"])
        #expect(library.articles(visibility: .reviewedOnly).map(\.id) == ["food-safety"])
        #expect(library.suggestions(forWeek: 24, visibility: .reviewedOnly).map(\.id) == ["food-safety"])
    }

    @Test func nothingReviewedMeansNoSuggestionsAndNoSections() {
        let library = KnowledgeLibrary(document: knowledgeContent([
            knowledgeArticle("safe-exercise", topic: "movement", trimesters: [1, 2, 3]),
        ]))
        #expect(library.suggestions(forWeek: 24, visibility: .reviewedOnly).isEmpty)
        #expect(library.sections(trimester: .second, visibility: .reviewedOnly).isEmpty)
    }

    @Test func sectionsFollowTopicOrderAndSkipEmptyTopics() {
        let library = KnowledgeLibrary(document: knowledgeContent([
            knowledgeArticle("signs-of-labour", topic: "birth", trimesters: [3]),
            knowledgeArticle("food-safety", topic: "nutrition", trimesters: [1, 2, 3]),
            knowledgeArticle("sleep-positions", topic: "sleep", trimesters: [2, 3]),
            knowledgeArticle("iron-calcium-balanced-meals", topic: "nutrition", trimesters: [2, 3]),
        ]))
        let third = library.sections(trimester: .third, visibility: .all)
        #expect(third.map(\.topic.id) == ["nutrition", "sleep", "birth"])
        #expect(third[0].articles.map(\.id) == ["food-safety", "iron-calcium-balanced-meals"])
        #expect(library.sections(trimester: .first, visibility: .all).map(\.id) == ["nutrition"])
    }

    @Test func referencesSkipInvalidIndices() {
        var article = knowledgeArticle("safe-exercise", topic: "movement", trimesters: [1, 2, 3])
        article.sources = [1, 7, 0]
        let library = KnowledgeLibrary(document: knowledgeContent([article]))
        #expect(library.references(for: article) == ["Source B", "Source A"])
    }
}
```

Run: `scripts/test-core.sh --filter KnowledgeLibraryTests`
Expected: build FAILS with `cannot find 'KnowledgeLibrary' in scope`.

- [ ] **Step 7: Implement the library and loader**

`Packages/KickCore/Sources/KickCore/KnowledgeLibrary.swift` (whole file):
```swift
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "content")

public enum KnowledgeLoadError: Error, Equatable {
    case resourceMissing
    case unsupportedVersion(Int)
}

/// One topic and its articles for a trimester: a section of the library screen.
public struct KnowledgeTopicSection: Equatable, Sendable, Identifiable {
    public let topic: KnowledgeTopic
    public let articles: [KnowledgeArticle]

    public var id: String { topic.id }
}

/// The bundled knowledge articles (phase 7 spec §3.2–3.3).
public struct KnowledgeLibrary: Sendable {
    public static let resourceName = "knowledge-content"
    public static let supportedVersion = 1

    public let document: KnowledgeContent

    public init(document: KnowledgeContent) {
        self.document = document
    }

    /// Throws on malformed JSON or a version other than `supportedVersion`.
    public init(data: Data) throws {
        let document = try JSONDecoder().decode(KnowledgeContent.self, from: data)
        guard document.version == Self.supportedVersion else {
            throw KnowledgeLoadError.unsupportedVersion(document.version)
        }
        self.init(document: document)
    }

    /// In display order.
    public var topics: [KnowledgeTopic] { document.topics }
    public var sources: [String] { document.sources }

    public func topic(id: String) -> KnowledgeTopic? {
        document.topics.first { $0.id == id }
    }

    public func article(id: String) -> KnowledgeArticle? {
        document.articles.first { $0.id == id }
    }

    /// Every article, minus the unreviewed ones under `.reviewedOnly` (release builds).
    public func articles(visibility: ContentVisibility) -> [KnowledgeArticle] {
        switch visibility {
        case .all: document.articles
        case .reviewedOnly: document.articles.filter(\.reviewed)
        }
    }

    /// The library screen for `trimester`: topics in display order, each with its
    /// articles in file order; topics without an article for the trimester are left out.
    public func sections(trimester: Trimester, visibility: ContentVisibility) -> [KnowledgeTopicSection] {
        let visible = articles(visibility: visibility).filter { $0.applies(to: trimester) }
        return document.topics.compactMap { topic in
            let articles = visible.filter { $0.topic == topic.id }
            return articles.isEmpty ? nil : KnowledgeTopicSection(topic: topic, articles: articles)
        }
    }

    /// Today's card: `KnowledgeSuggester` over the visible articles.
    public func suggestions(forWeek week: Int, visibility: ContentVisibility, count: Int = KnowledgeSuggester.defaultCount) -> [KnowledgeArticle] {
        KnowledgeSuggester.suggestions(
            for: week,
            from: articles(visibility: visibility),
            topicOrder: document.topics.map(\.id),
            count: count
        )
    }

    /// The article's citations, skipping any index that does not exist.
    public func references(for article: KnowledgeArticle) -> [String] {
        article.sources.compactMap { sources.indices.contains($0) ? sources[$0] : nil }
    }

    /// The content bundled in KickCore's resources. Throws if it is missing or invalid.
    public static func bundled() throws -> KnowledgeLibrary {
        guard let url = Bundle.module.url(forResource: resourceName, withExtension: "json") else {
            throw KnowledgeLoadError.resourceMissing
        }
        return try KnowledgeLibrary(data: Data(contentsOf: url))
    }

    /// Loads `url`; logs and returns nil when it is nil, unreadable, malformed or
    /// of another version, so the app hides the card and the library instead of crashing.
    public static func load(from url: URL?) -> KnowledgeLibrary? {
        do {
            guard let url else { throw KnowledgeLoadError.resourceMissing }
            return try KnowledgeLibrary(data: Data(contentsOf: url))
        } catch {
            logger.error("Loading knowledge content failed: \(String(describing: error))")
            return nil
        }
    }

    /// `load(from:)` for the bundled file.
    public static func loadBundled() -> KnowledgeLibrary? {
        load(from: Bundle.module.url(forResource: resourceName, withExtension: "json"))
    }
}
```

Run: `scripts/test-core.sh --filter KnowledgeLibraryTests`
Expected: PASS, 8 tests. (`aMissingFileGivesNil` and the other failure tests log "Loading knowledge content failed"; that is expected.)

- [ ] **Step 8: Write the failing content-check tests**

`Packages/KickCore/Tests/KickCoreTests/KnowledgeChecksTests.swift` (whole file):
```swift
import Foundation
import Testing
@testable import KickCore

/// Phase 7 spec §3.5 on fixtures (`KnowledgeTestSupport.swift`).
struct KnowledgeChecksTests {
    /// Every catalogue article (spec §3.1), each passing the checks.
    private func completeKnowledgeContent() -> KnowledgeContent {
        knowledgeContent(KnowledgeChecks.catalogue.map { knowledgeArticle($0.id, topic: $0.topic, trimesters: $0.trimesters) })
    }

    private func safeExercise() -> KnowledgeArticle {
        knowledgeArticle("safe-exercise", topic: "movement", trimesters: [1, 2, 3])
    }

    private func issues(_ article: KnowledgeArticle) -> [KnowledgeIssue] {
        KnowledgeChecks.validate(knowledgeContent([article]))
    }

    @Test func catalogueMatchesTheSpec() {
        #expect(KnowledgeChecks.topicIDs == knowledgeTopicIDs)
        #expect(KnowledgeChecks.catalogue.count == 18)
        #expect(KnowledgeChecks.articleIDs.count == 18)
        for topic in KnowledgeChecks.topicIDs {
            #expect(KnowledgeChecks.catalogue.filter { $0.topic == topic }.count == 3, "\(topic)")
        }
        let perTrimester = (1...3).map { trimester in KnowledgeChecks.catalogue.filter { $0.trimesters.contains(trimester) }.count }
        #expect(perTrimester == [7, 9, 11])
    }

    @Test func validContentPasses() {
        #expect(KnowledgeChecks.validate(knowledgeContent([])).isEmpty)
        #expect(issues(safeExercise()).isEmpty)
        #expect(KnowledgeChecks.validate(completeKnowledgeContent(), requiredArticleIDs: KnowledgeChecks.articleIDs).isEmpty)
    }

    @Test func versionSourcesAndTopicsAreChecked() {
        var content = knowledgeContent([])
        content.version = 2
        content.sources[1] = " "
        content.topics.swapAt(0, 1)
        content.topics[2].name.vi = ""
        content.topics[3].symbol = ""
        let found = KnowledgeChecks.validate(content)
        #expect(found.contains(.wrongVersion(2)))
        #expect(found.contains(.blankSource(index: 1)))
        #expect(found.contains(.topicsMismatch(found: ["movement", "nutrition", "sleep", "feelings", "checkups", "birth"])))
        #expect(found.contains(.blankTopic(topic: "sleep", language: .vi)))
        #expect(found.contains(.blankTopic(topic: "feelings", language: nil)))
        #expect(found.count == 5)
    }

    @Test func missingArticlesAreReportedOnlyWhenRequired() {
        let content = knowledgeContent([safeExercise()])
        #expect(KnowledgeChecks.validate(content, requiredArticleIDs: ["safe-exercise"]).isEmpty)
        #expect(
            KnowledgeChecks.validate(content, requiredArticleIDs: ["safe-exercise", "food-safety"])
                == [.missingArticle(id: "food-safety")]
        )
    }

    @Test func unknownDuplicateAndMisfiledArticlesAreReported() {
        var wrongTopic = knowledgeArticle("food-safety", topic: "movement", trimesters: [1, 2, 3])
        wrongTopic.sources = [1]
        let found = KnowledgeChecks.validate(knowledgeContent([
            safeExercise(),
            safeExercise(),
            knowledgeArticle("yoga", topic: "movement", trimesters: [2]),
            wrongTopic,
            knowledgeArticle("hospital-bag", topic: "birth", trimesters: [2, 3]),
            knowledgeArticle("signs-of-labour", topic: "birth", trimesters: []),
        ]))
        #expect(
            found == [
                .duplicateArticle(id: "safe-exercise"),
                .unknownArticle(id: "yoga"),
                .wrongTopic(article: "food-safety", topic: "movement"),
                .wrongTrimesters(article: "hospital-bag", trimesters: [2, 3]),
                .wrongTrimesters(article: "signs-of-labour", trimesters: []),
            ]
        )
    }

    @Test func trimesterCoverageIsCheckedOnceEverythingIsRequired() {
        var content = completeKnowledgeContent()
        content.articles.removeAll { $0.trimesters == [1] } // leaves 3 for trimester 1: food-safety, safe-exercise, antenatal
        #expect(KnowledgeChecks.validate(content).isEmpty)
        content.articles.removeAll { $0.id == "food-safety" }
        let found = KnowledgeChecks.validate(content, requiredArticleIDs: KnowledgeChecks.articleIDs)
        #expect(found.contains(.trimesterCoverage(trimester: 1, articles: 2)))
        #expect(!found.contains { if case .trimesterCoverage(trimester: 2, _) = $0 { true } else { false } })
    }

    @Test func sectionAndParagraphCountsAreChecked() {
        var article = safeExercise()
        article.sections = [article.sections[0]]
        #expect(issues(article).contains(.sectionCount(article: "safe-exercise", count: 1)))
        article = safeExercise()
        article.sections += article.sections + article.sections // 6 sections
        #expect(issues(article).contains(.sectionCount(article: "safe-exercise", count: 6)))
        article = safeExercise()
        article.sections[1].paragraphs.vi = []
        article.sections[0].paragraphs.en = Array(repeating: knowledgeWords(30, "word"), count: 5)
        let found = issues(article)
        #expect(found.contains(.paragraphCount(article: "safe-exercise", section: 2, language: .vi, count: 0)))
        #expect(found.contains(.paragraphCount(article: "safe-exercise", section: 1, language: .en, count: 5)))
    }

    @Test func blankTextIsReported() {
        var article = safeExercise()
        article.title.en = " "
        article.sections[1].heading.vi = ""
        article.sections[0].paragraphs.en[1] = "\n"
        let found = issues(article)
        #expect(found.contains(.blankText(article: "safe-exercise", field: "title", language: .en)))
        #expect(found.contains(.blankText(article: "safe-exercise", field: "section 2 heading", language: .vi)))
        #expect(found.contains(.blankText(article: "safe-exercise", field: "section 1", language: .en)))
    }

    @Test func summaryLimits() {
        var article = safeExercise()
        article.summary = LocalizedText(en: knowledgeWords(36, "word"), vi: knowledgeWords(46, "chữ"))
        let found = issues(article)
        #expect(found.contains(.summaryTooLong(article: "safe-exercise", language: .en, words: 36)))
        #expect(found.contains(.summaryTooLong(article: "safe-exercise", language: .vi, words: 46)))
        article.summary = LocalizedText(en: knowledgeWords(35, "word"), vi: knowledgeWords(45, "chữ"))
        #expect(issues(article).isEmpty)
    }

    @Test func lengthCountsSummaryHeadingsAndParagraphsButNotTheTitle() {
        var article = safeExercise()
        #expect(KnowledgeChecks.articleWordCount(article, language: .en) == 326)
        #expect(KnowledgeChecks.articleWordCount(article, language: .vi) == 358)
        article.title.en = knowledgeWords(200, "word")
        #expect(KnowledgeChecks.articleWordCount(article, language: .en) == 326)
        article = safeExercise()
        article.sections[0].paragraphs.en = [knowledgeWords(20, "word")] // 326 − 150 + 20 = 196
        article.sections[1].paragraphs.vi[0] = knowledgeWords(250, "chữ") // 358 − 80 + 250 = 528
        let found = issues(article)
        #expect(found.contains(.length(article: "safe-exercise", language: .en, words: 196)))
        #expect(found.contains(.length(article: "safe-exercise", language: .vi, words: 528)))
    }

    @Test func sourcesMustBeValid() {
        var article = safeExercise()
        article.sources = []
        #expect(issues(article) == [.noSources(article: "safe-exercise")])
        article.sources = [1, 2, -1]
        #expect(
            issues(article) == [
                .invalidSource(article: "safe-exercise", index: 2),
                .invalidSource(article: "safe-exercise", index: -1),
            ]
        )
    }

    @Test func imperialUnitsAreReported() {
        var article = safeExercise()
        article.sections[0].paragraphs.en[0] = "Walk about 2 miles or carry 10 lbs. " + knowledgeWords(67, "word")
        let found = issues(article)
        #expect(found == [.imperialUnit(article: "safe-exercise", field: "section 1", language: .en)])
    }

    @Test func doseUnitsAreReportedOutsideTheCaffeineSentences() {
        var article = safeExercise()
        article.sections[0].paragraphs.en[0] = "Take 400 mcg a day. " + knowledgeWords(70, "word")
        article.sections[1].paragraphs.vi[0] = "Uống 1000 IU mỗi ngày. " + knowledgeWords(75, "chữ")
        #expect(
            issues(article) == [
                .doseUnit(article: "safe-exercise", field: "section 1", language: .en),
                .doseUnit(article: "safe-exercise", field: "section 2", language: .vi),
            ]
        )
        article = safeExercise()
        article.sections[0].paragraphs.en[0] = KnowledgeChecks.doseAllowList[0] + " " + knowledgeWords(55, "word")
        article.sections[0].paragraphs.vi[0] = KnowledgeChecks.doseAllowList[1] + " " + knowledgeWords(50, "chữ")
        #expect(!issues(article).contains { if case .doseUnit = $0 { true } else { false } })
        #expect(KnowledgeChecks.containsDoseUnit(KnowledgeChecks.doseAllowList[0] + " Then 300 mg more."))
    }

    @Test func vietnameseTextNeedsDiacritics() {
        var article = safeExercise()
        article.sections[0].heading.vi = "Yoga cho ba bau"
        #expect(issues(article) == [.missingDiacritics(article: "safe-exercise", field: "section 1 heading")])
    }

    @Test func reviewedArticlesAreReported() {
        #expect(
            issues(knowledgeArticle("safe-exercise", topic: "movement", trimesters: [1, 2, 3], reviewed: true))
                == [.reviewed(article: "safe-exercise")]
        )
    }
}
```

`Packages/KickCore/Tests/KickCoreTests/BundledKnowledgeTests.swift` (whole file):
```swift
import Foundation
import Testing
@testable import KickCore

/// Phase 7 spec §3.5: the knowledge articles in the shipped `knowledge-content.json`.
struct BundledKnowledgeTests {
    /// Articles that must already be written. Each task widens it:
    /// [] (Task 1) → safe-exercise (Task 2) → + nutrition and movement (Task 3)
    /// → + sleep and feelings (Task 4) → KnowledgeChecks.articleIDs (Task 5).
    static let requiredArticleIDs: Set<String> = []

    let library: KnowledgeLibrary

    init() throws {
        library = try KnowledgeLibrary.bundled()
    }

    @Test func contentIsVersion1WithTheSixTopics() {
        #expect(library.document.version == KnowledgeLibrary.supportedVersion)
        #expect(library.topics.map(\.id) == KnowledgeChecks.topicIDs)
        #expect(KnowledgeLibrary.loadBundled() != nil)
    }

    @Test func everyWrittenArticlePassesTheChecks() {
        let issues = KnowledgeChecks.validate(library.document, requiredArticleIDs: Self.requiredArticleIDs)
        #expect(issues.isEmpty, "\(issues)")
    }

    @Test func articlesAreInCatalogueOrder() {
        let order = KnowledgeChecks.catalogue.map(\.id)
        let written = library.document.articles.map(\.id)
        #expect(written == order.filter { written.contains($0) })
    }
}
```

Run: `scripts/test-core.sh --filter "KnowledgeChecksTests|BundledKnowledgeTests"`
Expected: build FAILS with `cannot find 'KnowledgeChecks' in scope`.

- [ ] **Step 9: Implement the checks and add the JSON**

`Packages/KickCore/Sources/KickCore/KnowledgeChecks.swift` (whole file):
```swift
import Foundation

public enum KnowledgeIssue: Equatable, Sendable {
    /// `version` is not `KnowledgeLibrary.supportedVersion`.
    case wrongVersion(Int)
    case blankSource(index: Int)
    /// The topic ids are not exactly `KnowledgeChecks.topicIDs`, in that order.
    case topicsMismatch(found: [String])
    /// A topic's name is blank in `language`, or its symbol is blank (`language` nil).
    case blankTopic(topic: String, language: ContentLanguage?)
    /// An article id that is not in `KnowledgeChecks.catalogue`.
    case unknownArticle(id: String)
    case duplicateArticle(id: String)
    /// A required article (`requiredArticleIDs`) is not in the file.
    case missingArticle(id: String)
    /// The article's `topic` is not the one the catalogue gives it.
    case wrongTopic(article: String, topic: String)
    /// `trimesters` is empty, outside 1...3, not strictly ascending, or not the catalogue's.
    case wrongTrimesters(article: String, trimesters: [Int])
    /// Fewer than `minimumPerTrimester` articles for a trimester (checked once every article is required).
    case trimesterCoverage(trimester: Int, articles: Int)
    case sectionCount(article: String, count: Int)
    /// Section `section` (from 1) has a paragraph count outside 1...4 in `language`.
    case paragraphCount(article: String, section: Int, language: ContentLanguage, count: Int)
    /// `field` ("title", "summary", "section N heading", "section N") is empty or whitespace.
    case blankText(article: String, field: String, language: ContentLanguage)
    case summaryTooLong(article: String, language: ContentLanguage, words: Int)
    /// Summary + headings + paragraphs outside 300–500 words.
    case length(article: String, language: ContentLanguage, words: Int)
    case noSources(article: String)
    case invalidSource(article: String, index: Int)
    case imperialUnit(article: String, field: String, language: ContentLanguage)
    /// mg, mcg, µg or IU outside an allow-listed caffeine sentence.
    case doseUnit(article: String, field: String, language: ContentLanguage)
    /// A Vietnamese text without any non-ASCII letter (likely English or unaccented).
    case missingDiacritics(article: String, field: String)
    /// `reviewed` is true; only the obstetrician's sign-off may set it (spec §3.5).
    case reviewed(article: String)
}

/// Automatic checks of `knowledge-content.json` (phase 7 spec §3.5), enforced by
/// unit tests on the bundled file. Accuracy and tone are reviewed by people.
public enum KnowledgeChecks {
    /// An article of spec §3.1: its id, topic and trimesters.
    public struct Entry: Sendable, Equatable {
        public let id: String
        public let topic: String
        public let trimesters: [Int]
    }

    /// The six topics, in display order.
    public static let topicIDs = ["nutrition", "movement", "sleep", "feelings", "checkups", "birth"]

    /// The 18 articles of spec §3.1, in file order.
    public static let catalogue: [Entry] = [
        Entry(id: "nutrition-first-trimester", topic: "nutrition", trimesters: [1]),
        Entry(id: "food-safety", topic: "nutrition", trimesters: [1, 2, 3]),
        Entry(id: "iron-calcium-balanced-meals", topic: "nutrition", trimesters: [2, 3]),
        Entry(id: "safe-exercise", topic: "movement", trimesters: [1, 2, 3]),
        Entry(id: "gentle-exercise-second-trimester", topic: "movement", trimesters: [2]),
        Entry(id: "pelvic-floor-posture", topic: "movement", trimesters: [2, 3]),
        Entry(id: "first-trimester-tiredness", topic: "sleep", trimesters: [1]),
        Entry(id: "sleep-positions", topic: "sleep", trimesters: [2, 3]),
        Entry(id: "sleeping-well-late-pregnancy", topic: "sleep", trimesters: [3]),
        Entry(id: "early-pregnancy-worries", topic: "feelings", trimesters: [1]),
        Entry(id: "changing-body-feelings", topic: "feelings", trimesters: [2]),
        Entry(id: "preparing-for-motherhood", topic: "feelings", trimesters: [3]),
        Entry(id: "antenatal-checkup-milestones", topic: "checkups", trimesters: [1, 2, 3]),
        Entry(id: "first-trimester-screening", topic: "checkups", trimesters: [1]),
        Entry(id: "anomaly-scan-glucose-test", topic: "checkups", trimesters: [2]),
        Entry(id: "signs-of-labour", topic: "birth", trimesters: [3]),
        Entry(id: "hospital-bag", topic: "birth", trimesters: [3]),
        Entry(id: "birth-plan-breastfeeding", topic: "birth", trimesters: [3]),
    ]

    public static var articleIDs: Set<String> { Set(catalogue.map(\.id)) }

    /// Maximum words in the summary.
    public static let summaryLimit: [ContentLanguage: Int] = [.en: 35, .vi: 45]
    /// Summary + headings + paragraphs, per language (Vietnamese: syllables).
    public static let articleWords: ClosedRange<Int> = 300...500
    public static let sectionRange: ClosedRange<Int> = 2...4
    public static let paragraphRange: ClosedRange<Int> = 1...4
    public static let minimumPerTrimester = 3

    /// The only sentences that may contain a dose unit: the caffeine limit used in
    /// `food-safety` (spec §3.5). Copy them into the article exactly.
    public static let doseAllowList: [String] = [
        "Most guidelines suggest keeping caffeine below 200 mg a day in total, counting coffee, tea, cola, energy drinks and chocolate.",
        "Phần lớn các hướng dẫn khuyên mẹ giữ tổng lượng caffeine dưới 200 mg mỗi ngày, tính cả cà phê, trà, nước cola, nước tăng lực và sô-cô-la.",
    ]

    /// Every article present is checked in full; `requiredArticleIDs` also reports
    /// the ones missing. Trimester coverage is checked once every catalogue article is required.
    public static func validate(_ content: KnowledgeContent, requiredArticleIDs: Set<String> = []) -> [KnowledgeIssue] {
        var issues: [KnowledgeIssue] = []
        if content.version != KnowledgeLibrary.supportedVersion {
            issues.append(.wrongVersion(content.version))
        }
        for (index, source) in content.sources.enumerated() where ContentValidator.isBlank(source) {
            issues.append(.blankSource(index: index))
        }
        issues += topicIssues(content.topics)

        let entries = Dictionary(uniqueKeysWithValues: catalogue.map { ($0.id, $0) })
        var seen: Set<String> = []
        for article in content.articles {
            if !seen.insert(article.id).inserted {
                issues.append(.duplicateArticle(id: article.id))
                continue
            }
            if let entry = entries[article.id] {
                if article.topic != entry.topic {
                    issues.append(.wrongTopic(article: article.id, topic: article.topic))
                }
                if article.trimesters != entry.trimesters || !isValidTrimesterList(article.trimesters) {
                    issues.append(.wrongTrimesters(article: article.id, trimesters: article.trimesters))
                }
            } else {
                issues.append(.unknownArticle(id: article.id))
            }
            issues += articleIssues(article, sourceCount: content.sources.count)
        }
        for entry in catalogue where requiredArticleIDs.contains(entry.id) && !seen.contains(entry.id) {
            issues.append(.missingArticle(id: entry.id))
        }
        if articleIDs.isSubset(of: requiredArticleIDs) {
            for trimester in Trimester.allCases {
                let count = content.articles.filter { $0.applies(to: trimester) }.count
                if count < minimumPerTrimester {
                    issues.append(.trimesterCoverage(trimester: trimester.rawValue, articles: count))
                }
            }
        }
        return issues
    }

    public static func wordCount(_ text: String) -> Int {
        WeekArticleChecks.wordCount(text)
    }

    /// Summary + headings + paragraphs (spec §3.4); the title is not counted.
    public static func articleWordCount(_ article: KnowledgeArticle, language: ContentLanguage) -> Int {
        article.texts(language)
            .filter { $0.field != "title" }
            .map { wordCount($0.text) }
            .reduce(0, +)
    }

    /// mg, mcg, µg or IU as a whole word, once the allow-listed sentences are removed.
    public static func containsDoseUnit(_ text: String) -> Bool {
        let remaining = doseAllowList.reduce(text) { $0.replacingOccurrences(of: $1, with: "") }
        return remaining.firstMatch(of: /\b(?:mg|mcg|µg|IU)\b/) != nil
    }

    private static func isValidTrimesterList(_ trimesters: [Int]) -> Bool {
        !trimesters.isEmpty
            && trimesters.allSatisfy { (1...3).contains($0) }
            && zip(trimesters, trimesters.dropFirst()).allSatisfy { $0 < $1 }
    }

    private static func topicIssues(_ topics: [KnowledgeTopic]) -> [KnowledgeIssue] {
        var issues: [KnowledgeIssue] = []
        if topics.map(\.id) != topicIDs {
            issues.append(.topicsMismatch(found: topics.map(\.id)))
        }
        for topic in topics {
            for language in ContentLanguage.allCases where ContentValidator.isBlank(topic.name.text(language)) {
                issues.append(.blankTopic(topic: topic.id, language: language))
            }
            if ContentValidator.isBlank(topic.symbol) {
                issues.append(.blankTopic(topic: topic.id, language: nil))
            }
        }
        return issues
    }

    private static func articleIssues(_ article: KnowledgeArticle, sourceCount: Int) -> [KnowledgeIssue] {
        let id = article.id
        var issues: [KnowledgeIssue] = []
        if article.reviewed { issues.append(.reviewed(article: id)) }
        if !sectionRange.contains(article.sections.count) {
            issues.append(.sectionCount(article: id, count: article.sections.count))
        }
        for language in ContentLanguage.allCases {
            for (index, section) in article.sections.enumerated() {
                let count = section.paragraphs.paragraphs(language).count
                if !paragraphRange.contains(count) {
                    issues.append(.paragraphCount(article: id, section: index + 1, language: language, count: count))
                }
            }
            let texts = article.texts(language)
            for (field, text) in texts {
                if ContentValidator.isBlank(text) {
                    issues.append(.blankText(article: id, field: field, language: language))
                }
                if WeekArticleChecks.containsImperialUnit(text) {
                    issues.append(.imperialUnit(article: id, field: field, language: language))
                }
                if containsDoseUnit(text) {
                    issues.append(.doseUnit(article: id, field: field, language: language))
                }
                if language == .vi, !text.unicodeScalars.contains(where: { $0.value > 127 }) {
                    issues.append(.missingDiacritics(article: id, field: field))
                }
            }
            let summaryWords = wordCount(article.summary.text(language))
            if summaryWords > summaryLimit[language, default: 0] {
                issues.append(.summaryTooLong(article: id, language: language, words: summaryWords))
            }
            let words = articleWordCount(article, language: language)
            if !articleWords.contains(words) {
                issues.append(.length(article: id, language: language, words: words))
            }
        }
        if article.sources.isEmpty { issues.append(.noSources(article: id)) }
        for index in article.sources where !(0..<sourceCount).contains(index) {
            issues.append(.invalidSource(article: id, index: index))
        }
        return issues
    }
}
```

The JSON below is in the format the script writes (2-space indent, UTF-8, trailing newline). Its source indices are fixed from now on (append-only).

`Packages/KickCore/Sources/KickCore/Resources/knowledge-content.json` (whole file):
```json
{
  "version": 1,
  "sources": [
    "WHO recommendations on antenatal care for a positive pregnancy experience (World Health Organization, 2016)",
    "WHO guidelines on physical activity and sedentary behaviour (World Health Organization, 2020)",
    "ACOG patient education: Your Pregnancy and Childbirth: Month to Month, and pregnancy FAQs (American College of Obstetricians and Gynecologists)",
    "ACOG Committee Opinion No. 804: Physical Activity and Exercise During Pregnancy and the Postpartum Period (American College of Obstetricians and Gynecologists, 2020)",
    "ACOG Committee Opinion No. 462: Moderate Caffeine Consumption During Pregnancy (American College of Obstetricians and Gynecologists, 2010)",
    "NHS: Your pregnancy and baby guide (National Health Service, UK)",
    "NICE guideline NG201: Antenatal care (National Institute for Health and Care Excellence, 2021)",
    "NICE guideline CG192: Antenatal and postnatal mental health (National Institute for Health and Care Excellence, 2014)",
    "WHO and UNICEF: Implementation guidance on protecting, promoting and supporting breastfeeding in facilities providing maternity and newborn services, the revised Baby-friendly Hospital Initiative (2018)",
    "Bộ Y tế Việt Nam: Hướng dẫn quốc gia về các dịch vụ chăm sóc sức khỏe sinh sản"
  ],
  "topics": [
    {
      "id": "nutrition",
      "name": {
        "en": "Nutrition",
        "vi": "Dinh dưỡng"
      },
      "symbol": "fork.knife"
    },
    {
      "id": "movement",
      "name": {
        "en": "Movement",
        "vi": "Vận động"
      },
      "symbol": "figure.walk"
    },
    {
      "id": "sleep",
      "name": {
        "en": "Sleep & rest",
        "vi": "Giấc ngủ & nghỉ ngơi"
      },
      "symbol": "moon.zzz"
    },
    {
      "id": "feelings",
      "name": {
        "en": "Feelings",
        "vi": "Cảm xúc"
      },
      "symbol": "heart"
    },
    {
      "id": "checkups",
      "name": {
        "en": "Check-ups & tests",
        "vi": "Khám thai & xét nghiệm"
      },
      "symbol": "stethoscope"
    },
    {
      "id": "birth",
      "name": {
        "en": "Getting ready for birth",
        "vi": "Chuẩn bị sinh"
      },
      "symbol": "figure.and.child.holdinghands"
    }
  ],
  "articles": []
}
```

Run: `scripts/test-core.sh --filter "KnowledgeChecksTests|BundledKnowledgeTests"`
Expected: PASS, 18 tests (15 + 3).

- [ ] **Step 10: Add the content script**

`scripts/set-knowledge-articles.py` (whole file):
```python
#!/usr/bin/env python3
"""Adds or replaces articles in knowledge-content.json, keeping the file
formatted exactly as committed (2-space indent, UTF-8, trailing newline) and
the articles in the order of spec 2026-10-07 §3.1.

    scripts/set-knowledge-articles.py <<'JSON'
    {"safe-exercise": {"topic": "movement", "trimesters": [1, 2, 3], "reviewed": false,
                       "title": {"en": "...", "vi": "..."},
                       "summary": {"en": "...", "vi": "..."},
                       "sections": [{"heading": {"en": "...", "vi": "..."},
                                     "paragraphs": {"en": ["..."], "vi": ["..."]}}],
                       "sources": [1, 3, 5]}}
    JSON

Prints the counts the content checks use (KickCore KnowledgeChecks): the summary
(en <= 35, vi <= 45), the article (summary + headings + paragraphs, 300-500) and
the sections (2-4). The full checks run in
`scripts/test-core.sh --filter BundledKnowledgeTests`.
"""
import json
import os
import sys

PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Packages", "KickCore",
                    "Sources", "KickCore", "Resources", "knowledge-content.json")
# Spec §3.1, in file order: id -> (topic, trimesters).
CATALOGUE = {
    "nutrition-first-trimester": ("nutrition", [1]),
    "food-safety": ("nutrition", [1, 2, 3]),
    "iron-calcium-balanced-meals": ("nutrition", [2, 3]),
    "safe-exercise": ("movement", [1, 2, 3]),
    "gentle-exercise-second-trimester": ("movement", [2]),
    "pelvic-floor-posture": ("movement", [2, 3]),
    "first-trimester-tiredness": ("sleep", [1]),
    "sleep-positions": ("sleep", [2, 3]),
    "sleeping-well-late-pregnancy": ("sleep", [3]),
    "early-pregnancy-worries": ("feelings", [1]),
    "changing-body-feelings": ("feelings", [2]),
    "preparing-for-motherhood": ("feelings", [3]),
    "antenatal-checkup-milestones": ("checkups", [1, 2, 3]),
    "first-trimester-screening": ("checkups", [1]),
    "anomaly-scan-glucose-test": ("checkups", [2]),
    "signs-of-labour": ("birth", [3]),
    "hospital-bag": ("birth", [3]),
    "birth-plan-breastfeeding": ("birth", [3]),
}
KEYS = ["topic", "trimesters", "reviewed", "title", "summary", "sections", "sources"]
LANGUAGES = ["en", "vi"]


def words(text):
    return len(text.split())


def text_pair(article_id, name, value):
    if not isinstance(value, dict) or sorted(value) != LANGUAGES or \
            not all(isinstance(value[l], str) and value[l].strip() for l in LANGUAGES):
        sys.exit(f"{article_id}: {name} needs non-empty en and vi strings")


def check(article_id, article, source_count):
    if article_id not in CATALOGUE:
        sys.exit(f"unknown article id: {article_id}")
    if list(article) != KEYS:
        sys.exit(f"{article_id}: keys must be {KEYS}, in this order")
    topic, trimesters = CATALOGUE[article_id]
    if article["topic"] != topic or article["trimesters"] != trimesters:
        sys.exit(f"{article_id}: topic must be {topic!r} and trimesters {trimesters}")
    if article["reviewed"] is not False:
        sys.exit(f"{article_id}: reviewed must be false (only the doctor's sign-off changes it)")
    text_pair(article_id, "title", article["title"])
    text_pair(article_id, "summary", article["summary"])
    sections = article["sections"]
    if not isinstance(sections, list) or not sections:
        sys.exit(f"{article_id}: sections must be a non-empty list")
    for number, section in enumerate(sections, start=1):
        if list(section) != ["heading", "paragraphs"]:
            sys.exit(f"{article_id}: section {number} keys must be ['heading', 'paragraphs']")
        text_pair(article_id, f"section {number} heading", section["heading"])
        paragraphs = section["paragraphs"]
        if sorted(paragraphs) != LANGUAGES:
            sys.exit(f"{article_id}: section {number} paragraphs need exactly en and vi")
        for l in LANGUAGES:
            if not paragraphs[l] or not all(isinstance(p, str) and p.strip() for p in paragraphs[l]):
                sys.exit(f"{article_id}: section {number} paragraphs.{l} need non-empty strings")
    sources = article["sources"]
    if not sources or not all(isinstance(i, int) and 0 <= i < source_count for i in sources):
        sys.exit(f"{article_id}: sources must be indices 0..{source_count - 1}")


def main():
    articles = json.load(sys.stdin)
    with open(PATH, encoding="utf-8") as f:
        content = json.load(f)
    by_id = {a["id"]: a for a in content["articles"]}
    for article_id, article in articles.items():
        check(article_id, article, len(content["sources"]))
        by_id[article_id] = {"id": article_id, **article}
        for l in LANGUAGES:
            summary = words(article["summary"][l])
            total = summary + sum(words(s["heading"][l]) + sum(words(p) for p in s["paragraphs"][l])
                                  for s in article["sections"])
            print(f"{article_id} {l}: summary {summary}, words {total}, sections {len(article['sections'])}")
    order = list(CATALOGUE)
    content["articles"] = sorted(by_id.values(), key=lambda a: order.index(a["id"]))
    with open(PATH, "w", encoding="utf-8") as f:
        json.dump(content, f, ensure_ascii=False, indent=2)
        f.write("\n")


if __name__ == "__main__":
    main()
```
Then: `chmod +x scripts/set-knowledge-articles.py`

Check it does not reformat the file (an empty object must change nothing):
```bash
git add Packages/KickCore/Sources/KickCore/Resources/knowledge-content.json
echo '{}' | scripts/set-knowledge-articles.py
git diff --stat -- Packages/KickCore/Sources/KickCore/Resources/knowledge-content.json
```
Expected: no output from the script and an empty `git diff --stat`.

- [ ] **Step 11: Write the failing drag-state test**

`Packages/KickCore/Tests/KickCoreTests/SheetDragStateTests.swift` (whole file):
```swift
import Testing
@testable import KickCore

/// Phase 7 plan Task 1: a cancelled sheet drag must not leave the sheet stuck.
struct SheetDragStateTests {
    @Test func startsIdle() {
        let drag = SheetDragState()
        #expect(!drag.isDragging)
        #expect(drag.translation == nil)
        #expect(drag.handoffStart == nil)
    }

    @Test func movingFollowsTheFinger() {
        var drag = SheetDragState()
        drag.move(by: -120)
        #expect(drag.isDragging)
        #expect(drag.translation == -120)
    }

    @Test func endingReportsWhetherTheSheetMovedAndClearsEverything() {
        var drag = SheetDragState()
        drag.beginHandoff(at: 30)
        drag.move(by: 80)
        let moved = drag.end()
        #expect(moved)
        #expect(drag == SheetDragState())
        let movedAgain = drag.end() // the cancel clean-up after onEnded is a no-op
        #expect(!movedAgain)
    }

    @Test func aHandoffAloneIsNotAMove() {
        var drag = SheetDragState()
        drag.beginHandoff(at: 30)
        #expect(!drag.isDragging)
        #expect(drag.handoffStart == 30)
        let moved = drag.end()
        #expect(!moved)
        #expect(drag.handoffStart == nil)
    }
}
```

Run: `scripts/test-core.sh --filter SheetDragStateTests`
Expected: build FAILS with `cannot find 'SheetDragState' in scope`.

- [ ] **Step 12: Implement `SheetDragState`**

`Packages/KickCore/Sources/KickCore/SheetDragState.swift` (whole file):
```swift
import Foundation

/// The in-flight drag of `ArticleSheet` (phase 7 plan, Task 1). SwiftUI calls a
/// drag gesture's `onEnded` only when the finger lifts; a cancelled gesture (a
/// system alert, the app leaving the foreground, another gesture winning) skips
/// it. Keeping the whole drag in one value lets the sheet clear it in one place
/// when its `@GestureState` reports that no drag is live any more.
public struct SheetDragState: Sendable, Equatable {
    /// The finger's vertical translation the sheet follows; nil while the sheet is not moving.
    public private(set) var translation: Double?
    /// The finger's translation when a drag on the expanded body was handed to the sheet.
    public private(set) var handoffStart: Double?

    public init() {}

    public var isDragging: Bool { translation != nil }

    public mutating func move(by translation: Double) {
        self.translation = translation
    }

    public mutating func beginHandoff(at translation: Double) {
        handoffStart = translation
    }

    /// Clears the drag. Returns true when the sheet had moved, so it must settle on a detent.
    @discardableResult
    public mutating func end() -> Bool {
        let moved = isDragging
        self = SheetDragState()
        return moved
    }
}
```

Run: `scripts/test-core.sh --filter SheetDragStateTests`
Expected: PASS, 4 tests.

- [ ] **Step 13: Use it in `ArticleSheet` so a cancelled drag cannot stick**

`onEnded` never runs for a cancelled gesture (a system alert, the app leaving the foreground, another gesture winning), which left `isDragging`, `dragTranslation` and `headerDragActive` set. The drag now lives in `SheetDragState`; two `@GestureState` flags reset by themselves on cancel, and when neither is live the sheet clears what `onEnded` did not. A normal release is unchanged: `onEnded` settles first, and the clean-up that runs one main-queue turn later finds nothing to do.

In `App/DesignSystem/ArticleSheet.swift`, replace:
```swift
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDragging = false
    @State private var dragTranslation: CGFloat = 0
    /// The finger's translation when an expanded body drag was handed to the sheet.
    @State private var handoffStart: CGFloat?
    @State private var scrollOffset: CGFloat = 0
```
with:
```swift
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The drag moving the sheet, if any (`SheetDragState`).
    @State private var drag = SheetDragState()
    /// True while a header / body drag gesture is live. Unlike `drag`, these reset
    /// on their own when a gesture is cancelled without `onEnded`.
    @GestureState private var headerGestureLive = false
    @GestureState private var bodyGestureLive = false
    @State private var scrollOffset: CGFloat = 0
```

In the same file, replace:
```swift
    /// The sheet's top edge now.
    private var top: CGFloat {
        CGFloat(isDragging
            ? resolver.dragOffset(from: detent, translation: Double(dragTranslation))
            : resolver.offset(for: detent))
    }
```
with:
```swift
    /// The sheet's top edge now.
    private var top: CGFloat {
        CGFloat(drag.translation.map { resolver.dragOffset(from: detent, translation: $0) }
            ?? resolver.offset(for: detent))
    }

    private var gestureLive: Bool { headerGestureLive || bodyGestureLive }
```

In the same file, replace:
```swift
                .scrollDisabled(detent == .peek || handoffStart != nil)
```
with:
```swift
                .scrollDisabled(detent == .peek || drag.handoffStart != nil)
```

In the same file, replace:
```swift
        .onAppear { progress = resolver.progress(for: detent) }
        .onChange(of: peekTop) {
            if !isDragging { progress = resolver.progress(for: detent) }
        }
        .onChange(of: expandedTop) {
            if !isDragging { progress = resolver.progress(for: detent) }
        }
        .onChange(of: containerHeight) {
            if !isDragging { progress = resolver.progress(for: detent) }
        }
        .onChange(of: detent) {
            if !isDragging { progress = resolver.progress(for: detent) }
        }
    }
```
with:
```swift
        .onAppear { progress = resolver.progress(for: detent) }
        .onChange(of: peekTop) {
            if !drag.isDragging { progress = resolver.progress(for: detent) }
        }
        .onChange(of: expandedTop) {
            if !drag.isDragging { progress = resolver.progress(for: detent) }
        }
        .onChange(of: containerHeight) {
            if !drag.isDragging { progress = resolver.progress(for: detent) }
        }
        .onChange(of: detent) {
            if !drag.isDragging { progress = resolver.progress(for: detent) }
        }
        .onChange(of: gestureLive) { _, live in
            guard !live else { return }
            // A normal release has already run `onEnded` by the next main-queue
            // turn; a cancelled gesture never does, so clear what it left behind.
            DispatchQueue.main.async { clearCancelledDrag() }
        }
    }
```

In the same file, replace:
```swift
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .onChanged { value in
                headerDragActive = true
```
with:
```swift
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .updating($headerGestureLive) { _, live, _ in live = true }
            .onChanged { value in
                headerDragActive = true
```

In the same file, replace:
```swift
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
```
with:
```swift
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .updating($bodyGestureLive) { _, live, _ in live = true }
            .onChanged { value in
                let translation = value.translation.height
                switch detent {
                case .peek:
                    move(by: translation)
                case .expanded:
                    if drag.handoffStart == nil {
                        // Only a downward pull while the article is at its top.
                        guard scrollOffset >= -1, translation > 0 else { return }
                        drag.beginHandoff(at: Double(translation))
                    }
                    move(by: max(0, translation - CGFloat(drag.handoffStart ?? Double(translation))))
                }
            }
            .onEnded { value in
                guard drag.isDragging else {
                    drag.end()
                    return
                }
                settle(velocity: value.velocity.height)
            }
    }

    private func move(by translation: CGFloat) {
        drag.move(by: Double(translation))
        progress = resolver.progress(atOffset: Double(top))
    }

    private func settle(velocity: CGFloat) {
        let target = resolver.release(at: Double(top), velocity: Double(velocity))
        withAnimation(LunaMotion.sheet(reduceMotion: reduceMotion)) {
            detent = target
            drag.end()
            progress = resolver.progress(for: target)
        }
    }

    /// After a cancelled drag (no `onEnded`): the sheet goes back to its detent
    /// and nothing stays marked as dragging. A no-op after a normal release, and
    /// skipped if a new drag has already begun.
    private func clearCancelledDrag() {
        guard !gestureLive else { return }
        headerDragActive = false
        guard drag != SheetDragState() else { return }
        withAnimation(LunaMotion.sheet(reduceMotion: reduceMotion)) {
            drag.end()
            progress = resolver.progress(for: detent)
        }
    }
```

Check nothing still uses the old state: `grep -n "isDragging\b\|dragTranslation\|handoffStart" App/DesignSystem/ArticleSheet.swift` prints only lines that go through `drag.` (`drag.isDragging`, `drag.handoffStart`).

- [ ] **Step 14: Run the whole KickCore suite and build the app**

```bash
scripts/test-core.sh
xcodegen generate --quiet
xcodebuild -project KickCounter.xcodeproj -scheme KickCounter \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO -quiet build-for-testing
```
Expected: `Test run with 472 tests` passed (431 + 41: `KnowledgeContentTests` 3, `KnowledgeSuggesterTests` 8, `KnowledgeLibraryTests` 8, `KnowledgeChecksTests` 15, `BundledKnowledgeTests` 3, `SheetDragStateTests` 4); `xcodebuild` exits 0 with no `.swift:…: error:` lines.

- [ ] **Step 15: Commit, push, verify CI**

`ArticleSheet` changed, so CI runs the week detail's sheet tests and Today.
```bash
git add Packages/KickCore scripts/set-knowledge-articles.py App/DesignSystem/ArticleSheet.swift
git commit -F - <<'MSG'
feat(core): knowledge articles model, suggester and checks

knowledge-content.json (version 1) holds six topics and their sources;
KnowledgeLibrary loads it or returns nil, filters unreviewed articles in
release builds and groups articles by topic per trimester.
KnowledgeSuggester picks three stable, rotating, topic-spread articles
for a week, and KnowledgeChecks validates every written article against
the spec's catalogue. set-knowledge-articles.py writes articles and
prints their word counts. ArticleSheet now clears a cancelled drag
instead of staying half-dragged.

CI-Only-Testing: WeekArticleSheetUITests, PregnancyTodayUITests
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`; the log has `==> UI tests: scoped to WeekArticleSheetUITests PregnancyTodayUITests`, and every `WeekArticleSheetUITests` test is green, including Phase 6's drag tests.

---
### Task 2: Today card, library and reading screen (with `safe-exercise`)

Extracts the shared reading pieces (spec §4.3), adds the strings, the environment value, the Today card (§4.1), the library (§4.2) and the reading screen (§4.3), plus `safe-exercise`, the first written article, which every UI test and screenshot uses. It is also the example article for Tasks 3–5.

**Files:**
- Create: `App/DesignSystem/ArticleText.swift`, `App/Knowledge/KnowledgeRows.swift`, `App/Knowledge/KnowledgeCard.swift`, `App/Knowledge/KnowledgeLibraryView.swift`, `App/Knowledge/KnowledgeArticleView.swift`, `UITests/KnowledgeUITests.swift`, `UITests/KnowledgeScreenshotTests.swift`
- Modify: `App/Pregnancy/WeekArticleView.swift`, `App/Pregnancy/WeekDetailView.swift`, `App/Pregnancy/PregnancyTodayView.swift`, `App/ContentEnvironment.swift`, `App/AppEnvironment.swift`, `App/KickCounterApp.swift`, `Shared/L10n.swift`, `Shared/Localizable.xcstrings` (via script), `Packages/KickCore/Sources/KickCore/Resources/knowledge-content.json` (via script), `Packages/KickCore/Tests/KickCoreTests/BundledKnowledgeTests.swift`

**Interfaces:**
- Consumes (Task 1): `KnowledgeLibrary` (`loadBundled()`, `topics`, `topic(id:)`, `article(id:)`, `sections(trimester:visibility:)`, `suggestions(forWeek:visibility:)`, `references(for:)`), `KnowledgeArticle`, `KnowledgeTopic`, `KnowledgeTopicSection`, `KnowledgeArtworkName.asset(articleID:)`, `SheetDetent`, `scripts/set-knowledge-articles.py`.
- Consumes (existing): `ArticleSheet(detent:progress:peekTop:expandedTop:containerHeight:bottomInset:resetKey:initialAnchor:handleIdentifier:scrollIdentifier:handleLabel:headerDragActive:header:content:)` (`headerDragActive` defaults to `.constant(false)`), `ChipScroller(values:selection:title:identifier:accessibilityTitle:selectedFill:selectedText:idleText:)`, `LunaDivider`, `.lunaCard(padding:)`, `.lunaStatusBarBackdrop()`, `.pill(.soft(_:_:), fullWidth:height:)`, `BuildFlags.contentVisibility`, `PregnancyTimeline` (`week.weeks`, `trimester`), `Trimester(rawValue:)`, `L10n.pregnancyTrimester(_:)`, `L10n.weekArticleExpand`, `L10n.weekArticleCollapse`, `L10n.weekArticleReferences`, `L10n.weekReviewer`, `L10n.weekReviewed`, `L10n.weekPendingReview`, `L10n.commonClose`, UI helpers `XCUIApplication.launchPinned(language:dark:dueDate:seedCycles:largestText:)`, `scrollUntilHittable(_:maxSwipes:)`, `attachScreenshot(_:_:)`, `waitForLabel(_:containing:)`, `UITestDates.dueAtWeek24`.
- Produces: `ArticleHeading(_:)`, `ArticleParagraphs(_:)`, `ArticleReferences(sources:identifier:)`, `ArticleReviewerRow(pendingReview:reviewedText:identifier:)`, `ArticleCloseButton(identifier:action:)`; `EnvironmentValues.knowledgeLibrary: KnowledgeLibrary?`; `AppEnvironment.knowledge`; `KnowledgeSelection(id:)`; `KnowledgeRows(articles:topics:language:identifierPrefix:onSelect:)`; `KnowledgeCard(trimester:suggestions:topics:language:onSeeMore:)`; `KnowledgeLibraryView(initialTrimester:)`; `KnowledgeArticleView(articleID:)` with `static artworkHeight(containerHeight:)`, `static peekTop(containerHeight:)`; `KnowledgeArtwork(articleID:symbol:)` with `static image(_:) -> Image?`; `PregnancyRoute.knowledge(trimester: Int)`; `L10n.knowledgeCardTitle(_:)`, `knowledgeSeeMore`, `knowledgeTitle`, `knowledgeReviewed`; the identifiers in Global Constraints; screenshot names `knowledge-*` (Task 6 lists them).

- [ ] **Step 1: Require `safe-exercise` (failing test first)**

In `Packages/KickCore/Tests/KickCoreTests/BundledKnowledgeTests.swift`, replace:
```swift
    static let requiredArticleIDs: Set<String> = []
```
with:
```swift
    static let requiredArticleIDs: Set<String> = ["safe-exercise"]
```
Run: `scripts/test-core.sh --filter BundledKnowledgeTests`
Expected: FAIL in `everyWrittenArticlePassesTheChecks` with `[KickCore.KnowledgeIssue.missingArticle(id: "safe-exercise")]`.

- [ ] **Step 2: Write `safe-exercise`**

Original text (facts from WHO 2020 physical-activity guidelines, ACOG Committee Opinion 804 and the NHS guide: sources 1, 3, 5). It follows every rule of the writing guide in Task 3.
```bash
scripts/set-knowledge-articles.py <<'JSON'
{
  "safe-exercise": {
    "topic": "movement",
    "trimesters": [1, 2, 3],
    "reviewed": false,
    "title": {
      "en": "Staying active safely in pregnancy",
      "vi": "Vận động an toàn khi mang thai"
    },
    "summary": {
      "en": "For most pregnancies, regular moderate activity is safe and good for you, as long as your doctor or midwife agrees and you adjust it as your body changes.",
      "vi": "Với phần lớn thai kỳ, vận động vừa sức đều đặn là an toàn và có lợi, miễn là bác sĩ hoặc nữ hộ sinh đồng ý và mẹ điều chỉnh khi cơ thể thay đổi."
    },
    "sections": [
      {
        "heading": {
          "en": "Why moving helps",
          "vi": "Vì sao vận động có ích"
        },
        "paragraphs": {
          "en": [
            "Staying active during pregnancy can lift your mood, help you sleep and ease some common discomforts, such as backache and constipation. It can also help keep your weight gain in a healthy range and build stamina for labour.",
            "The World Health Organization and other guidelines suggest about 150 minutes of moderate activity a week, spread over several days. Short sessions of about 10 minutes count too. If you were not active before, start with a few minutes a day and build up slowly."
          ],
          "vi": [
            "Vận động đều đặn khi mang thai có thể giúp mẹ vui vẻ hơn, ngủ ngon hơn và đỡ một số khó chịu thường gặp như đau lưng hay táo bón. Vận động cũng giúp mẹ tăng cân trong mức hợp lý và có thêm sức bền cho lúc chuyển dạ.",
            "Tổ chức Y tế Thế giới và nhiều hướng dẫn khác gợi ý mẹ vận động vừa sức khoảng 150 phút mỗi tuần, chia ra nhiều ngày. Những lần tập ngắn khoảng 10 phút cũng được tính. Nếu trước đây ít vận động, mẹ hãy bắt đầu với vài phút mỗi ngày rồi tăng dần."
          ]
        }
      },
      {
        "heading": {
          "en": "Choosing what to do",
          "vi": "Chọn cách vận động phù hợp"
        },
        "paragraphs": {
          "en": [
            "Brisk walking, swimming, water aerobics, an exercise bike and pregnancy yoga or pilates classes suit most people. If you were already active before pregnancy, you can usually carry on, easing off as your bump grows.",
            "Avoid contact sports, activities with a high chance of falling, such as horse riding or skiing, and scuba diving. Once your bump is growing, avoid exercises that keep you lying flat on your back for a long time; lie on your side or sit propped up instead.",
            "If you have a health condition, or a complication in this pregnancy, ask your doctor or midwife which kinds of activity suit you."
          ],
          "vi": [
            "Đi bộ nhanh, bơi, thể dục dưới nước, đạp xe tại chỗ và các lớp yoga hay pilates cho bà bầu hợp với phần lớn các mẹ. Nếu trước đây mẹ đã quen tập luyện, mẹ thường có thể tiếp tục và giảm dần cường độ khi bụng lớn lên.",
            "Mẹ nên tránh các môn thể thao đối kháng, các hoạt động dễ ngã như cưỡi ngựa hay trượt tuyết, và lặn có bình dưỡng khí. Khi bụng đã lớn dần, mẹ tránh những bài tập phải nằm ngửa lâu; thay vào đó, mẹ nằm nghiêng hoặc ngồi tựa lưng.",
            "Nếu mẹ có bệnh lý sẵn có hoặc có biến chứng trong lần mang thai này, mẹ hãy hỏi bác sĩ hoặc nữ hộ sinh xem cách vận động nào phù hợp với mình."
          ]
        }
      },
      {
        "heading": {
          "en": "Listening to your body",
          "vi": "Lắng nghe cơ thể"
        },
        "paragraphs": {
          "en": [
            "At a moderate pace, you can still speak in full sentences. Drink water before, during and after exercise, and avoid getting very hot, especially on humid days. Your joints are looser in pregnancy, so warm up gently and avoid jerky movements.",
            "Stop and rest if you feel dizzy or unusually tired, or more out of breath than the effort explains, and tell your doctor or midwife before you exercise again. If you faint, or the dizziness does not pass when you sit down, see your doctor. Pain and swelling in one calf needs a doctor straight away.",
            "Some signs need care straight away. If you have bleeding from your vagina, regular painful tightenings, or fluid leaking from your vagina, contact your maternity unit straight away, whatever the colour of the fluid. If your baby moves less than usual, call your maternity unit straight away, day or night. For chest pain, or trouble breathing that does not ease with rest, call an emergency ambulance (115) straight away."
          ],
          "vi": [
            "Khi tập ở mức vừa phải, mẹ vẫn nói được trọn câu. Mẹ uống nước trước, trong và sau khi tập, và tránh để người quá nóng, nhất là vào hôm trời oi bức. Khi mang thai, các khớp lỏng hơn, nên mẹ khởi động nhẹ nhàng và tránh động tác giật mạnh.",
            "Mẹ hãy dừng lại nghỉ nếu thấy chóng mặt, mệt bất thường hoặc hụt hơi nhiều hơn mức gắng sức, và báo bác sĩ hoặc nữ hộ sinh trước khi tập lại. Nếu ngất, hoặc chóng mặt không đỡ khi đã ngồi xuống, mẹ hãy đi khám. Nếu một bên bắp chân đau và sưng, mẹ cần gặp bác sĩ ngay.",
            "Một số dấu hiệu cần được chăm sóc ngay. Nếu ra máu âm đạo, bụng gò đều và đau, hoặc ra nước âm đạo, mẹ hãy liên hệ khoa sản ngay, dù nước có màu gì. Nếu bé cử động ít hơn mọi ngày, mẹ hãy gọi ngay cho khoa sản, dù ngày hay đêm. Nếu đau ngực, hoặc khó thở mà nghỉ ngơi không đỡ, mẹ hãy gọi cấp cứu 115 ngay."
          ]
        }
      }
    ],
    "sources": [1, 3, 5]
  }
}
JSON
```
Expected output:
```
safe-exercise en: summary 28, words 393, sections 3
safe-exercise vi: summary 36, words 479, sections 3
```
Run: `scripts/test-core.sh`
Expected: PASS, `Test run with 472 tests`.

- [ ] **Step 3: Strings**

```bash
scripts/add-strings.py <<'JSON'
{
  "knowledge.card.title": ["Suggested for trimester %ld", "Gợi ý cho tam cá nguyệt %ld"],
  "knowledge.seeMore": ["See more", "Xem thêm"],
  "knowledge.title": ["Knowledge", "Kiến thức"],
  "knowledge.reviewed": ["An obstetrician has reviewed this article", "Bác sĩ sản khoa đã duyệt bài viết này"]
}
JSON
```
Expected: `441 strings`.

In `Shared/L10n.swift`, replace:
```swift
    static var weekArticleSizeWeightFormat: String { t("weekArticle.size.weight") }
```
with:
```swift
    static var weekArticleSizeWeightFormat: String { t("weekArticle.size.weight") }

    // MARK: - Phase 7: knowledge

    /// "Suggested for trimester 2".
    static func knowledgeCardTitle(_ trimester: Int) -> String { String(format: t("knowledge.card.title"), trimester) }
    static var knowledgeSeeMore: String { t("knowledge.seeMore") }
    static var knowledgeTitle: String { t("knowledge.title") }
    static var knowledgeReviewed: String { t("knowledge.reviewed") }
```

- [ ] **Step 4: Load the library and put it in the environment**

In `App/ContentEnvironment.swift`, replace:
```swift
private struct ContentLibraryKey: EnvironmentKey {
    static let defaultValue: WeeklyContentLibrary? = nil
}
```
with:
```swift
private struct ContentLibraryKey: EnvironmentKey {
    static let defaultValue: WeeklyContentLibrary? = nil
}

private struct KnowledgeLibraryKey: EnvironmentKey {
    static let defaultValue: KnowledgeLibrary? = nil
}
```
and replace:
```swift
        set { self[ContentLibraryKey.self] = newValue }
    }
```
with:
```swift
        set { self[ContentLibraryKey.self] = newValue }
    }

    /// The bundled knowledge articles; nil if they failed to load (card and library hidden).
    var knowledgeLibrary: KnowledgeLibrary? {
        get { self[KnowledgeLibraryKey.self] }
        set { self[KnowledgeLibraryKey.self] = newValue }
    }
```

In `App/AppEnvironment.swift`, replace:
```swift
    let content: WeeklyContentLibrary?
```
with:
```swift
    let content: WeeklyContentLibrary?
    let knowledge: KnowledgeLibrary?
```
and replace:
```swift
            content: WeeklyContentLibrary.loadBundled()
```
with:
```swift
            content: WeeklyContentLibrary.loadBundled(),
            knowledge: KnowledgeLibrary.loadBundled()
```

In `App/KickCounterApp.swift`, replace:
```swift
                    .environment(\.contentLibrary, env.content)
```
with:
```swift
                    .environment(\.contentLibrary, env.content)
                    .environment(\.knowledgeLibrary, env.knowledge)
```

- [ ] **Step 5: Extract the shared reading pieces**

`App/DesignSystem/ArticleText.swift` (whole file):
```swift
import KickCore
import SwiftUI

// The reading pieces shared by the week article (phase 6) and the knowledge
// articles (phase 7 spec §4.3), so both use the same typography.

/// A section heading (headline style, header trait).
struct ArticleHeading: View {
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

/// Body paragraphs, line spacing 4.
struct ArticleParagraphs: View {
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

/// "References", collapsed until tapped; nothing when `sources` is empty.
struct ArticleReferences: View {
    let sources: [String]
    let identifier: String

    var body: some View {
        if !sources.isEmpty {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(sources, id: \.self) { source in
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
            .accessibilityIdentifier(identifier)
        }
    }
}

/// "Reviewed by" with "Content pending doctor review" or `reviewedText`, under a
/// sheet title. No doctor's name yet (phase 6 spec §4.6).
struct ArticleReviewerRow: View {
    let pendingReview: Bool
    let reviewedText: String
    let identifier: String

    var body: some View {
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
                Text(pendingReview ? L10n.weekPendingReview : reviewedText)
                    .font(.luna(.label))
                    .foregroundStyle(.luna(.textPrimary))
            }
        }
        .padding(.top, 10)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}

/// The ✕ of a full-screen reading cover, at the top left over the background
/// and the expanded sheet. Opaque `card` with a hairline border: a translucent
/// fill let the sheet's top edge show through once expanded. VoiceOver reaches
/// it before the background or the sheet.
struct ArticleCloseButton: View {
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.luna(.textPrimary))
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(.luna(.card))
                        .overlay(Circle().strokeBorder(.luna(.divider), lineWidth: 1))
                )
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.commonClose)
        .accessibilityIdentifier(identifier)
        .accessibilitySortPriority(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }
}
```

In `App/Pregnancy/WeekArticleView.swift`, replace:
```swift
            switch tab {
            case .baby: babyTab
            case .mom: momTab
            }
            references
        }
```
with:
```swift
            switch tab {
            case .baby: babyTab
            case .mom: momTab
            }
            ArticleReferences(sources: referenceList, identifier: "weekReferences")
        }
```
and replace everything from the end of `referenceList` to the end of the private `ArticleParagraphs` struct:
```swift
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
```
with:
```swift
        return article.sources.compactMap { sources.indices.contains($0) ? sources[$0] : nil }
    }
}
```
(`WeekSection` and `WarningSection` stay private in `WeekArticleView.swift`.)

In `App/Pregnancy/WeekDetailView.swift`, replace:
```swift
    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.luna(.textPrimary))
                .frame(width: 40, height: 40)
                // Opaque, not translucent: a translucent fill let the sheet's
                // top edge show faintly through once expanded. Opaque `card`
                // plus a hairline border reads the same, and intentionally,
                // over the hero gradient (peek) and the sheet (expanded).
                .background(
                    Circle()
                        .fill(.luna(.card))
                        .overlay(Circle().strokeBorder(.luna(.divider), lineWidth: 1))
                )
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.commonClose)
        .accessibilityIdentifier("weekDetailClose")
        // VoiceOver reaches the ✕ before the fetus/chips or the sheet.
        .accessibilitySortPriority(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }
```
with:
```swift
    private var closeButton: some View {
        ArticleCloseButton(identifier: "weekDetailClose") { dismiss() }
    }
```
replace:
```swift
            if case .content(_, let pendingReview)? = display {
                reviewer(pendingReview: pendingReview)
```
with:
```swift
            if case .content(_, let pendingReview)? = display {
                ArticleReviewerRow(pendingReview: pendingReview, reviewedText: L10n.weekReviewed, identifier: "weekReviewer")
```
and delete the now unused function (including the blank line after it):
```swift
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

```

Build checkpoint (the week screens must compile unchanged):
```bash
xcodegen generate --quiet
xcodebuild -project KickCounter.xcodeproj -scheme KickCounter \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO -quiet build-for-testing
```
Expected: exit 0, no `.swift:…: error:` lines.

- [ ] **Step 6: The knowledge views**

`App/Knowledge/KnowledgeRows.swift` (whole file):
```swift
import KickCore
import SwiftUI

/// The article a row opened (`fullScreenCover(item:)`).
struct KnowledgeSelection: Identifiable, Equatable {
    let id: String
}

/// Article rows on a card, separated by hairlines (phase 7 spec §4.1–4.2): the
/// topic symbol in a tinted circle, the title and a two-line summary. Each row
/// is a button with the identifier `<identifierPrefix>-<article id>`.
struct KnowledgeRows: View {
    let articles: [KnowledgeArticle]
    let topics: [KnowledgeTopic]
    let language: ContentLanguage
    /// "knowledgeSuggestion" on Today, "knowledgeArticle" in the library.
    let identifierPrefix: String
    let onSelect: (KnowledgeArticle) -> Void

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(articles.enumerated()), id: \.element.id) { index, article in
                if index > 0 { LunaDivider() }
                Button { onSelect(article) } label: {
                    KnowledgeRowLabel(article: article, symbol: symbol(for: article), language: language)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("\(identifierPrefix)-\(article.id)")
            }
        }
    }

    private func symbol(for article: KnowledgeArticle) -> String {
        topics.first { $0.id == article.topic }?.symbol ?? "book"
    }
}

private struct KnowledgeRowLabel: View {
    let article: KnowledgeArticle
    let symbol: String
    let language: ContentLanguage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.luna(.pregOnSoft))
                .frame(width: 40, height: 40)
                .background(Circle().fill(.luna(.pregSoft)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(article.title.text(language))
                    .font(.luna(.cardTitleSmall))
                    .foregroundStyle(.luna(.textPrimary))
                    .fixedSize(horizontal: false, vertical: true)
                Text(article.summary.text(language))
                    .font(.luna(.caption))
                    .foregroundStyle(.luna(.textSecondary))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.luna(.chevron))
                .padding(.top, 12)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
```

`App/Knowledge/KnowledgeCard.swift` (whole file):
```swift
import KickCore
import SwiftUI

/// "Suggested for trimester N" on pregnancy Today (phase 7 spec §4.1): up to
/// three article rows and a "See more" pill that opens the library. A row opens
/// the reading screen, which this card presents itself.
struct KnowledgeCard: View {
    let trimester: Int
    let suggestions: [KnowledgeArticle]
    let topics: [KnowledgeTopic]
    let language: ContentLanguage
    let onSeeMore: () -> Void

    @State private var reading: KnowledgeSelection?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.knowledgeCardTitle(trimester))
                .font(.luna(.cardTitle))
                .foregroundStyle(.luna(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            KnowledgeRows(
                articles: suggestions,
                topics: topics,
                language: language,
                identifierPrefix: "knowledgeSuggestion"
            ) { reading = KnowledgeSelection(id: $0.id) }
            Button(L10n.knowledgeSeeMore, action: onSeeMore)
                .buttonStyle(.pill(.soft(.pregSoft, .pregOnSoft), fullWidth: false, height: 40))
                .accessibilityIdentifier("knowledgeSeeMore")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .lunaCard(padding: 16)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("knowledgeCard")
        .fullScreenCover(item: $reading) { selection in
            KnowledgeArticleView(articleID: selection.id)
        }
    }
}
```

`App/Knowledge/KnowledgeLibraryView.swift` (whole file):
```swift
import KickCore
import SwiftUI

/// "Kiến thức" (phase 7 spec §4.2): trimester chips, then the chosen trimester's
/// articles grouped by topic in display order. A row opens the reading screen.
struct KnowledgeLibraryView: View {
    @Environment(\.knowledgeLibrary) private var library
    @State private var trimester: Int
    @State private var reading: KnowledgeSelection?
    private let language = ContentLanguage.current
    private let visibility = BuildFlags.contentVisibility

    /// `initialTrimester`: the current trimester, or nil without a due date (→ 1).
    init(initialTrimester: Int?) {
        _trimester = State(initialValue: min(max(initialTrimester ?? 1, 1), 3))
    }

    private var sections: [KnowledgeTopicSection] {
        guard let library, let value = Trimester(rawValue: trimester) else { return [] }
        return library.sections(trimester: value, visibility: visibility)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ChipScroller(
                    values: Trimester.allCases.map(\.rawValue),
                    selection: $trimester,
                    title: { L10n.pregnancyTrimester($0) },
                    identifier: { "knowledgeTrimester-\($0)" },
                    accessibilityTitle: nil,
                    selectedFill: .pregSoft,
                    selectedText: .pregOnSoft,
                    idleText: .textSecondary
                )
                .padding(.top, 8)
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(section.topic.name.text(language))
                            .font(.luna(.cardTitle))
                            .foregroundStyle(.luna(.textPrimary))
                            .accessibilityAddTraits(.isHeader)
                        KnowledgeRows(
                            articles: section.articles,
                            topics: library?.topics ?? [],
                            language: language,
                            identifierPrefix: "knowledgeArticle"
                        ) { reading = KnowledgeSelection(id: $0.id) }
                        .lunaCard(padding: 16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
                }
            }
            .padding(.bottom, 24)
        }
        // Content scrolled up stays out from under the status bar.
        .lunaStatusBarBackdrop()
        .background(.luna(.background))
        .navigationTitle(L10n.knowledgeTitle)
        .fullScreenCover(item: $reading) { selection in
            KnowledgeArticleView(articleID: selection.id)
        }
    }
}
```

`App/Knowledge/KnowledgeArticleView.swift` (whole file):
```swift
import KickCore
import SwiftUI
import UIKit

/// The article's artwork (phase 7 spec §4.3): the asset `Knowledge-<id>` when it
/// exists, otherwise the topic's SF Symbol at 96 pt in `pregOnSoft` on a soft circle.
struct KnowledgeArtwork: View {
    let articleID: String
    let symbol: String

    static func image(_ articleID: String) -> Image? {
        let name = KnowledgeArtworkName.asset(articleID: articleID)
        return UIImage(named: name) == nil ? nil : Image(name)
    }

    var body: some View {
        if let image = Self.image(articleID) {
            image.resizable().scaledToFit().padding(28)
        } else {
            Circle()
                .fill(.luna(.pregSoft))
                .overlay(
                    Image(systemName: symbol)
                        .font(.system(size: 96, weight: .light))
                        .foregroundStyle(.luna(.pregOnSoft))
                )
                .aspectRatio(1, contentMode: .fit)
                .padding(24)
        }
    }
}

/// The reading screen, presented full screen (phase 7 spec §4.3). It follows
/// `WeekDetailView`: the artwork on the hero gradient with the ✕ above it, and
/// `ArticleSheet` on top. The sheet header holds only the title and the review
/// row: nothing in it is a Button, because a header Button moves with a dragged
/// sheet and would fire its tap on release (phase 6 lesson). The body holds the
/// bold summary, the sections and the collapsed references.
struct KnowledgeArticleView: View {
    let articleID: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.knowledgeLibrary) private var library
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var detent = SheetDetent.peek
    @State private var progress = 0.0
    private let language = ContentLanguage.current

    /// The sheet's top edge when expanded: 8 pt below the top safe area.
    private static let expandedTop: CGFloat = 8
    /// Room for the ✕ button above the artwork.
    private static let closeRowHeight: CGFloat = 52

    static func artworkHeight(containerHeight: CGFloat) -> CGFloat {
        min(containerHeight * 0.36, 320)
    }

    /// 12 pt below the artwork; never so low that the handle, title and review row leave the screen.
    static func peekTop(containerHeight: CGFloat) -> CGFloat {
        min(closeRowHeight + artworkHeight(containerHeight: containerHeight) + 12, containerHeight - 220)
    }

    private var article: KnowledgeArticle? { library?.article(id: articleID) }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                if let article {
                    backgroundLayer(article, height: proxy.size.height)
                    ArticleSheet(
                        detent: $detent,
                        progress: $progress,
                        peekTop: Self.peekTop(containerHeight: proxy.size.height),
                        expandedTop: Self.expandedTop,
                        containerHeight: proxy.size.height,
                        bottomInset: proxy.safeAreaInsets.bottom,
                        resetKey: article.id,
                        initialAnchor: nil,
                        handleIdentifier: "knowledgeSheetHandle",
                        scrollIdentifier: "knowledgeArticleScroll",
                        handleLabel: { $0 == .peek ? L10n.weekArticleExpand : L10n.weekArticleCollapse }
                    ) {
                        sheetHeader(article)
                    } content: {
                        sheetContent(article)
                    }
                }
                ArticleCloseButton(identifier: "knowledgeClose") { dismiss() }
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
            // Accessibility text sizes and VoiceOver open expanded (phase 6 rule):
            // at peek the body does not scroll, so VoiceOver could not reach it.
            if dynamicTypeSize.isAccessibilitySize || voiceOverEnabled {
                detent = .expanded
                progress = 1
            }
        }
    }

    /// Decorative: hidden from VoiceOver.
    private func backgroundLayer(_ article: KnowledgeArticle, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: Self.closeRowHeight)
            KnowledgeArtwork(articleID: article.id, symbol: library?.topic(id: article.topic)?.symbol ?? "book")
                .frame(height: Self.artworkHeight(containerHeight: height))
                .frame(maxWidth: .infinity)
                .opacity(1 - progress)
                .scaleEffect(reduceMotion ? 1 : 1 - 0.1 * progress)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityHidden(true)
    }

    private func sheetHeader(_ article: KnowledgeArticle) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(article.title.text(language))
                .font(.luna(.sheetTitle))
                .foregroundStyle(.luna(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("knowledgeTitle")
            ArticleReviewerRow(
                pendingReview: !article.reviewed,
                reviewedText: L10n.knowledgeReviewed,
                identifier: "knowledgeReviewer"
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.bottom, 14)
    }

    private func sheetContent(_ article: KnowledgeArticle) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(article.summary.text(language))
                .font(.luna(.cardTitle))
                .foregroundStyle(.luna(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("knowledgeSummary")
            ForEach(Array(article.sections.enumerated()), id: \.offset) { _, section in
                ArticleHeading(section.heading.text(language))
                ArticleParagraphs(section.paragraphs.paragraphs(language))
            }
            ArticleReferences(sources: library?.references(for: article) ?? [], identifier: "knowledgeReferences")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```
`project.yml` lists `App` as a source folder, so `xcodegen generate` picks up `App/Knowledge/` without edits.

- [ ] **Step 7: The Today card**

In `App/Pregnancy/PregnancyTodayView.swift`, replace:
```swift
enum PregnancyRoute: Hashable {
    case symptoms
    case weight
}
```
with:
```swift
enum PregnancyRoute: Hashable {
    case symptoms
    case weight
    /// The knowledge library, opened on this trimester (phase 7 spec §4.2).
    case knowledge(trimester: Int)
}
```
replace:
```swift
/// movements, the baby this week, tips and the next check-up.
```
with:
```swift
/// movements, the baby this week, tips, the next check-up and the knowledge
/// suggestions (phase 7).
```
replace:
```swift
    @Environment(\.contentLibrary) private var library
```
with:
```swift
    @Environment(\.contentLibrary) private var library
    @Environment(\.knowledgeLibrary) private var knowledge
```
replace:
```swift
                case .symptoms: PregnancySymptomsView()
                case .weight: WeightView()
                }
```
with:
```swift
                case .symptoms: PregnancySymptomsView()
                case .weight: WeightView()
                case .knowledge(let trimester): KnowledgeLibraryView(initialTrimester: trimester)
                }
```
and replace:
```swift
            .buttonStyle(.plain)
            .accessibilityIdentifier("nextAppointmentCard")
        }
        .padding(.horizontal, 20)
    }
```
with:
```swift
            .buttonStyle(.plain)
            .accessibilityIdentifier("nextAppointmentCard")
            knowledgeCard(for: timeline)
        }
        .padding(.horizontal, 20)
    }

    /// "Suggested for trimester N" (phase 7 spec §4.1); hidden when the library
    /// failed to load or nothing is visible (release builds until reviewed).
    @ViewBuilder
    private func knowledgeCard(for timeline: PregnancyTimeline) -> some View {
        if let knowledge {
            let suggestions = knowledge.suggestions(forWeek: timeline.week.weeks, visibility: visibility)
            if !suggestions.isEmpty {
                KnowledgeCard(
                    trimester: timeline.trimester.rawValue,
                    suggestions: suggestions,
                    topics: knowledge.topics,
                    language: language
                ) { route = .knowledge(trimester: timeline.trimester.rawValue) }
            }
        }
    }
```
The card only exists inside `cards(for:)`, which runs only with a valid due date; `CycleTodayView` (trying to conceive) is untouched.

- [ ] **Step 8: UI tests and screenshots**

`UITests/KnowledgeUITests.swift` (whole file):
```swift
import XCTest

/// Phase 7 spec §4 and §5: the Today card, the library and the reading screen,
/// seeded at week 24 (trimester 2) with every article visible (`-uiTesting`).
final class KnowledgeUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Today at 24w3d, scrolled down to the knowledge card.
    @MainActor
    private func launchAtWeek24(largestText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24, largestText: largestText)
        XCTAssertTrue(app.buttons["fetusHeroButton"].waitForExistence(timeout: 10))
        let seeMore = app.buttons["knowledgeSeeMore"]
        app.scrollUntilHittable(seeMore, maxSwipes: largestText ? 20 : 8)
        XCTAssertTrue(seeMore.isHittable)
        return app
    }

    @MainActor
    private func suggestions(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "knowledgeSuggestion-"))
    }

    /// §4.1: the card's title names the trimester; its rows are the suggestions.
    @MainActor
    func testTodayShowsTheCardWithSuggestions() {
        let app = launchAtWeek24()
        XCTAssertTrue(app.descendants(matching: .any)["knowledgeCard"].exists)
        XCTAssertTrue(app.staticTexts["Suggested for trimester 2"].exists)
        // Task 2: safe-exercise is the only article written so far (Task 3 makes it 3).
        XCTAssertEqual(suggestions(app).count, 1)
        XCTAssertTrue(app.buttons["knowledgeSuggestion-safe-exercise"].exists)
    }

    /// §4.3: a suggestion opens the reading screen at peek; the handle expands it; ✕ closes it.
    @MainActor
    func testSuggestionOpensTheReadingScreen() {
        let app = launchAtWeek24()
        suggestions(app).firstMatch.tap()
        let handle = app.buttons["knowledgeSheetHandle"]
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        XCTAssertEqual(handle.label, "Expand article")
        XCTAssertTrue(app.staticTexts["knowledgeTitle"].exists)
        XCTAssertTrue(app.staticTexts["knowledgeSummary"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["knowledgeReviewer"].exists)
        handle.tap()
        waitForLabel(handle, containing: "Collapse article")
        app.buttons["knowledgeClose"].tap()
        XCTAssertTrue(app.buttons["knowledgeSeeMore"].waitForExistence(timeout: 5))
        XCTAssertFalse(handle.exists)
    }

    /// §4.2: "See more" opens the library on the current trimester; chips switch it.
    @MainActor
    func testSeeMoreOpensTheLibraryOnTheCurrentTrimester() {
        let app = launchAtWeek24()
        app.buttons["knowledgeSeeMore"].tap()
        let second = app.buttons["knowledgeTrimester-2"]
        XCTAssertTrue(second.waitForExistence(timeout: 5))
        XCTAssertTrue(second.isSelected)
        XCTAssertTrue(app.navigationBars.staticTexts["Knowledge"].exists)

        let third = app.buttons["knowledgeTrimester-3"]
        XCTAssertFalse(third.isSelected)
        third.tap()
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: third)
        XCTAssertEqual(XCTWaiter().wait(for: [selected], timeout: 5), .completed)
        XCTAssertFalse(second.isSelected)
        // Task 5 checks signs-of-labour here; until then safe-exercise is the trimester-3 article.
        let row = app.buttons["knowledgeArticle-safe-exercise"]
        app.scrollUntilHittable(row)
        XCTAssertTrue(row.isHittable)
        row.tap()
        XCTAssertTrue(app.buttons["knowledgeSheetHandle"].waitForExistence(timeout: 5))
        app.buttons["knowledgeClose"].tap()
        XCTAssertTrue(third.waitForExistence(timeout: 5))
    }

    /// §4.3: accessibility text sizes open the sheet expanded.
    @MainActor
    func testLargestTextOpensExpanded() {
        let app = launchAtWeek24(largestText: true)
        let first = suggestions(app).firstMatch
        app.scrollUntilHittable(first)
        first.tap()
        let handle = app.buttons["knowledgeSheetHandle"]
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        waitForLabel(handle, containing: "Collapse article")
    }

    /// §2: trying-to-conceive mode shows nothing new.
    @MainActor
    func testTryingToConceiveHasNoKnowledgeCard() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "period")
        XCTAssertTrue(app.descendants(matching: .any)["cycleStatusCard"].waitForExistence(timeout: 10))
        for _ in 0..<4 { app.swipeUp() }
        XCTAssertFalse(app.descendants(matching: .any)["knowledgeCard"].exists)
        XCTAssertFalse(app.buttons["knowledgeSeeMore"].exists)
    }
}
```

`UITests/KnowledgeScreenshotTests.swift` (whole file):
```swift
import XCTest

/// Phase 7 spec §5: screenshots of the knowledge card, library and reading
/// screen (week 24, pinned clock). The reading screen shows safe-exercise.
final class KnowledgeScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launchAtWeek24(language: String, dark: Bool = false, largestText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication.launchPinned(language: language, dark: dark, dueDate: UITestDates.dueAtWeek24, largestText: largestText)
        XCTAssertTrue(app.buttons["fetusHeroButton"].waitForExistence(timeout: 10))
        app.scrollUntilHittable(app.buttons["knowledgeSeeMore"], maxSwipes: largestText ? 20 : 8)
        return app
    }

    /// Today → "See more" → the library on trimester 2.
    @MainActor
    private func openLibrary(_ app: XCUIApplication) {
        app.buttons["knowledgeSeeMore"].tap()
        XCTAssertTrue(app.buttons["knowledgeTrimester-2"].waitForExistence(timeout: 5))
    }

    /// Library → safe-exercise.
    @MainActor
    private func openSafeExercise(_ app: XCUIApplication) -> XCUIElement {
        let row = app.buttons["knowledgeArticle-safe-exercise"]
        app.scrollUntilHittable(row)
        row.tap()
        let handle = app.buttons["knowledgeSheetHandle"]
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        return handle
    }

    @MainActor
    func testVietnameseLight() {
        let app = launchAtWeek24(language: "vi")
        attachScreenshot(app, "knowledge-card-vi-light")
        openLibrary(app)
        attachScreenshot(app, "knowledge-library-vi-light")
        let handle = openSafeExercise(app)
        attachScreenshot(app, "knowledge-reading-peek-vi-light")
        handle.tap()
        waitForLabel(handle, containing: "Thu gọn bài viết")
        attachScreenshot(app, "knowledge-reading-expanded-vi-light")
        app.swipeUp()
        app.swipeUp()
        attachScreenshot(app, "knowledge-reading-expanded-vi-light-scrolled")
    }

    @MainActor
    func testEnglishDark() {
        let app = launchAtWeek24(language: "en", dark: true)
        attachScreenshot(app, "knowledge-card-en-dark")
        openLibrary(app)
        attachScreenshot(app, "knowledge-library-en-dark")
        let handle = openSafeExercise(app)
        attachScreenshot(app, "knowledge-reading-peek-en-dark")
        handle.tap()
        waitForLabel(handle, containing: "Collapse article")
        attachScreenshot(app, "knowledge-reading-expanded-en-dark")
    }

    /// AX5: the library wraps, and the reading screen opens expanded.
    @MainActor
    func testLargestText() {
        let app = launchAtWeek24(language: "vi", largestText: true)
        attachScreenshot(app, "knowledge-card-vi-ax5")
        openLibrary(app)
        attachScreenshot(app, "knowledge-library-vi-ax5")
        let handle = openSafeExercise(app)
        waitForLabel(handle, containing: "Thu gọn bài viết")
        attachScreenshot(app, "knowledge-reading-vi-ax5")
    }
}
```

- [ ] **Step 9: Build**

```bash
scripts/test-core.sh
xcodegen generate --quiet
xcodebuild -project KickCounter.xcodeproj -scheme KickCounter \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO -quiet build-for-testing
```
Expected: `Test run with 472 tests` passed; `xcodebuild` exits 0 with no `.swift:…: error:` lines. `grep -n "private struct ArticleHeading\|private struct ArticleParagraphs\|private func reviewer" App/Pregnancy/*.swift` prints nothing.

- [ ] **Step 10: Commit, push, verify CI**

```bash
git add App Shared UITests Packages/KickCore
git commit -F - <<'MSG'
feat(pregnancy): knowledge card, library and reading screen

Pregnancy Today ends with "Suggested for trimester N": three articles
and a See more pill that opens the library, where trimester chips list
the articles by topic. An article opens full screen with its artwork
and the two-detent article sheet. The reading pieces, the reviewer row
and the close button are now shared with the week detail, which looks
the same as before. safe-exercise is the first written article.

CI-Only-Testing: KnowledgeUITests, KnowledgeScreenshotTests, PregnancyTodayUITests, PregnancyScreenshotTests, WeekArticleSheetUITests, WeekArticleScreenshotTests
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED` with all 5 `KnowledgeUITests` and 3 `KnowledgeScreenshotTests`; every `WeekArticleSheetUITests` and `PregnancyTodayUITests` test still green.

- [ ] **Step 11: Visual check**

Open each PNG in `ci-artifacts/screenshots/` with the Read tool:
- `knowledge-card-vi-light`: below the "Lịch khám sắp tới" card, a white card "Gợi ý cho tam cá nguyệt 2" (16/600); one row: a `figure.walk` symbol in a peach (`pregSoft`) circle, "Vận động an toàn khi mang thai" (15/600), a grey summary cut to two lines, a light chevron; under it a small peach "Xem thêm" pill (not full width).
- `knowledge-library-vi-light`: navigation title "Kiến thức"; chips "Tam cá nguyệt 1 / 2 / 3" with 2 selected (peach fill, dark-orange text), the others grey text; heading "Vận động" with one card holding the safe-exercise row.
- `knowledge-reading-peek-vi-light`: hero gradient; ✕ in an opaque white circle with a hairline border at top left; a large `figure.walk` (96 pt, `pregOnSoft`) in a peach circle; the white sheet starts below the artwork with 24 pt top corners; grey handle; title "Vận động an toàn khi mang thai" (22/700); stethoscope row "Người xem xét / Nội dung đang chờ bác sĩ duyệt"; the bold summary visible.
- `knowledge-reading-expanded-vi-light`: sheet top 8 pt under the status bar; the ✕ sits over the sheet's top-left corner and covers neither the handle nor the title; artwork gone; summary, then "Vì sao vận động có ích" with two paragraphs (line spacing as the week article).
- `knowledge-reading-expanded-vi-light-scrolled`: "Lắng nghe cơ thể" paragraphs; "Tài liệu tham khảo" collapsed with a chevron; handle and title still fixed at the top.
- `knowledge-card-en-dark`, `knowledge-library-en-dark`, `knowledge-reading-*-en-dark`: dark background and card `#262019`; "Suggested for trimester 2", "See more", "Knowledge", "Trimester 2"; peach circle dark (`#45281A`) with a light peach symbol; every text readable.
- `knowledge-card-vi-ax5`, `knowledge-library-vi-ax5`, `knowledge-reading-vi-ax5`: huge text wraps without cutting (the summary may stop at two lines with "…"); chips scroll sideways; the reading screen opened expanded; the ✕ does not cover the title.
- Unchanged from Phase 6 (extraction): `week-article-expanded-baby-vi-light-scrolled` (references group), `week-article-peek-baby-vi-light` (reviewer row, ✕) look exactly as in the last Phase 6 run.

---
### Task 3: Content — nutrition and movement (and a second look at `safe-exercise`)

Write original vi + en articles for the `nutrition` topic and the two other `movement` articles, re-review `safe-exercise` beside them, and require all six. This task writes prose; its only code change is one assertion in `KnowledgeUITests`.

**Files:**
- Modify: `Packages/KickCore/Sources/KickCore/Resources/knowledge-content.json` (via `scripts/set-knowledge-articles.py` only), `Packages/KickCore/Tests/KickCoreTests/BundledKnowledgeTests.swift` (`requiredArticleIDs`), `UITests/KnowledgeUITests.swift` (one assertion)

**Interfaces:**
- Consumes: `scripts/set-knowledge-articles.py`, `KnowledgeChecks` (incl. `doseAllowList`), `BundledKnowledgeTests` (Task 1); `safe-exercise` (Task 2); the week articles in `pregnancy-content.json` (read-only, for consistency).
- Produces: articles `nutrition-first-trimester`, `food-safety`, `iron-calcium-balanced-meals`, `gentle-exercise-second-trimester`, `pelvic-floor-posture`; `requiredArticleIDs` = those + `safe-exercise`; `testTodayShowsTheCardWithSuggestions` expects 3 suggestions.

**Writing guide (Phase 6 spec 2026-10-06 §4.4, verbatim; for Knowledge, "the sources listed in `PregnancyContent.sources`" means `KnowledgeContent.sources`, and the Length and Accuracy bullets are replaced by the differences below):**

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

**Knowledge writing guide (spec 2026-10-07 §3.4, verbatim):**

The Phase 6 guide applies (spec 2026-10-06 §4.4):
- original text only;
- hedged and warm in tone;
- Vietnamese written natively, in northern usage;
- metric units only;
- no diagnosis;
- no medicine names with doses;
- the doctor or midwife is "bác sĩ hoặc nữ hộ sinh" / "your doctor or midwife".

The Phase 6 batch-review lessons also apply:
- no promises about the reader's own baby;
- any symptom that is also a warning sign gets one calm sentence pointing to the doctor or midwife;
- vi and en say the same thing;
- no close paraphrase of NHS or any other site.

Differences for Knowledge articles:
- **Length:** each article is 300–500 words per language. The count covers summary, headings and paragraphs, with words split on whitespace. Each article has 2–4 sections, and each section has 1–4 paragraphs.
- **Guideline figures:** public-health figures are allowed. Examples are "about 150 minutes of activity a week" (WHO) and a daily caffeine limit (NHS/WHO). Every such figure is listed for the doctor.
- **Feelings articles:** these always include a gentle line to seek help if low mood or worry lasts most days for two weeks or more. They also name who to tell: the doctor or midwife, or family.
- **The `signs-of-labour` article** must match the week warnings:
  - if the waters break, call the maternity unit straight away, whatever the colour;
  - if the baby moves less, call straight away, day or night.

**Review rules (enforced in the Phase 6 review rounds; the review step checks every one):**

1. **Completed-week counting.** Week numbers are completed weeks, as the app shows them: "tuần 24" / "week 24" is 24 weeks and 0–6 days ("24 weeks, 3 days" on Today). Never "tuần thứ 24" / "the 24th week" (that is 23 completed weeks). Trimesters follow the app: 1 = up to week 13, 2 = weeks 14–27, 3 = from week 28. Ranges use the app's milestones ("tuần 24 đến 28" / "weeks 24 to 28").
2. **No promises about the reader's baby.** Never "your baby will be fine", "bé sẽ khỏe mạnh", or "this is nothing to worry about" about a symptom. Use "usually", "many", "may" / "thường", "nhiều", "có thể".
3. **A pointer for every symptom that is also a warning.** Any symptom that appears in a week's "When to get care right away" list (vaginal bleeding; belly pain that does not go away; sharp pain on one side or at the shoulder tip; vomiting so often that fluids do not stay down; severe headache, blurred vision or sudden swelling of the face, hands or feet; fits or trouble breathing; fluid leaking from the vagina; regular tightenings before 37 weeks; fever of 38°C or more; intense itching on the palms and soles; a painful, red or swollen area in one leg; fainting; reduced movements) gets one calm sentence saying who to contact and how soon, matching that list. Do not reassure about it in the same sentence.
4. **vi and en say the same thing:** the same facts, figures, pointers and order. A fact in one language only is a defect.
5. **Northern Vietnamese:** tất (not vớ), ngô (not bắp), lợi (not nướu), trượt ngã (not té ngã), vừng (not mè), lạc (not đậu phộng), dứa (not thơm/khóm), quả (not trái), ốm = sick (never "thin"), bỉm or tã for nappies.
6. **Exact pointer wording, where one is used:** "bác sĩ hoặc nữ hộ sinh" / "your doctor or midwife"; "khoa sản" / "your maternity unit"; "gọi cấp cứu 115" / "call an emergency ambulance (115)"; "ngay" / "straight away"; "dù ngày hay đêm" / "day or night". A pointer to the week page's list uses exactly: "mục “Khi nào cần đi khám ngay” ở trang tuần" / "“When to get care right away” on your week page". Knowledge articles have no warning list of their own: never write "the warning signs below".
7. **No close NHS paraphrase** (or of any other site): do not follow a source's sentence order, examples and wording; write from the facts.
8. **Waters breaking or reduced movements mean calling straight away.** Fluid leaking from the vagina → contact the maternity unit straight away, whatever the colour ("dù nước ối trong, xanh hay nâu" / "whether the fluid is clear, green or brown", or "dù nước có màu gì" / "whatever the colour"). The baby moving less than usual, or a change in the pattern → contact the maternity unit straight away, day or night. Never "wait", "count again later", "lie down and drink something cold" or "see in the morning".

**Plan rules (in addition to the guide; see "Spec clarifications" 5, 15, 16):**
- `summary`: one sentence, ≤ 35 words (en) / ≤ 45 (vi). Article (summary + headings + paragraphs) 300–500 words per language; aim for en 330–420 and vi 400–480 so edits stay in range. 2–4 sections, 1–4 paragraphs each (aim for 2–3 sections of 2–3 paragraphs). The title is short (about 8 words or fewer in English) and is not counted.
- Keys in this order: `topic`, `trimesters`, `reviewed` (`false`), `title`, `summary`, `sections`, `sources`; each section has `heading` then `paragraphs`. `topic` and `trimesters` must be the catalogue's (the fact checklist repeats them); the script refuses anything else.
- `sources`: indices into `knowledge-content.json`'s `sources`, only the ones you used: 0 = WHO antenatal care 2016, 1 = WHO physical activity 2020, 2 = ACOG patient education, 3 = ACOG CO 804 (exercise), 4 = ACOG CO 462 (caffeine), 5 = NHS, 6 = NICE NG201 (antenatal care), 7 = NICE CG192 (mental health), 8 = WHO/UNICEF breastfeeding 2018, 9 = Bộ Y tế. Use the fact checklist's list unless you drop one you did not use.
- Medicine: folic acid / axit folic and iron / sắt may be named **without** a dose, "as your doctor or midwife advises" / "theo hướng dẫn của bác sĩ hoặc nữ hộ sinh". Vaccines are named by disease ("uốn ván, ho gà"). No other medicine, supplement or product names; no doses (`mg`, `mcg`, `µg`, `IU` fail the checks except in the caffeine sentence of `food-safety`).
- Every guideline figure you use is in the fact checklist; if you use another one, put it in the commit's "Added beyond the checklist" block so Task 6 lists it for the doctor.
- Do not contradict the week articles or the milestones; do not repeat a week article's sentences word for word.
- Every Vietnamese text (title, summary, headings, paragraphs) has diacritics; keep `"reviewed": false`.

**JSON shape** (one object per article id; the script writes `id` itself and keeps catalogue order):
```json
{
  "<article id>": {
    "topic": "<topic id>",
    "trimesters": [2, 3],
    "reviewed": false,
    "title": {"en": "<title>", "vi": "<tiêu đề>"},
    "summary": {"en": "<one sentence>", "vi": "<một câu>"},
    "sections": [
      {"heading": {"en": "<heading>", "vi": "<tiêu đề mục>"}, "paragraphs": {"en": ["<p1>", "<p2>"], "vi": ["<đ1>", "<đ2>"]}},
      {"heading": {"en": "<heading>", "vi": "<tiêu đề mục>"}, "paragraphs": {"en": ["<p1>"], "vi": ["<đ1>"]}}
    ],
    "sources": [2, 5]
  }
}
```

**Example — `safe-exercise`, already in the file since Task 2** (the bar for quality, tone, pointers and length; do not reuse its sentences):
```json
{
  "safe-exercise": {
    "topic": "movement",
    "trimesters": [1, 2, 3],
    "reviewed": false,
    "title": {
      "en": "Staying active safely in pregnancy",
      "vi": "Vận động an toàn khi mang thai"
    },
    "summary": {
      "en": "For most pregnancies, regular moderate activity is safe and good for you, as long as your doctor or midwife agrees and you adjust it as your body changes.",
      "vi": "Với phần lớn thai kỳ, vận động vừa sức đều đặn là an toàn và có lợi, miễn là bác sĩ hoặc nữ hộ sinh đồng ý và mẹ điều chỉnh khi cơ thể thay đổi."
    },
    "sections": [
      {
        "heading": {
          "en": "Why moving helps",
          "vi": "Vì sao vận động có ích"
        },
        "paragraphs": {
          "en": [
            "Staying active during pregnancy can lift your mood, help you sleep and ease some common discomforts, such as backache and constipation. It can also help keep your weight gain in a healthy range and build stamina for labour.",
            "The World Health Organization and other guidelines suggest about 150 minutes of moderate activity a week, spread over several days. Short sessions of about 10 minutes count too. If you were not active before, start with a few minutes a day and build up slowly."
          ],
          "vi": [
            "Vận động đều đặn khi mang thai có thể giúp mẹ vui vẻ hơn, ngủ ngon hơn và đỡ một số khó chịu thường gặp như đau lưng hay táo bón. Vận động cũng giúp mẹ tăng cân trong mức hợp lý và có thêm sức bền cho lúc chuyển dạ.",
            "Tổ chức Y tế Thế giới và nhiều hướng dẫn khác gợi ý mẹ vận động vừa sức khoảng 150 phút mỗi tuần, chia ra nhiều ngày. Những lần tập ngắn khoảng 10 phút cũng được tính. Nếu trước đây ít vận động, mẹ hãy bắt đầu với vài phút mỗi ngày rồi tăng dần."
          ]
        }
      },
      {
        "heading": {
          "en": "Choosing what to do",
          "vi": "Chọn cách vận động phù hợp"
        },
        "paragraphs": {
          "en": [
            "Brisk walking, swimming, water aerobics, an exercise bike and pregnancy yoga or pilates classes suit most people. If you were already active before pregnancy, you can usually carry on, easing off as your bump grows.",
            "Avoid contact sports, activities with a high chance of falling, such as horse riding or skiing, and scuba diving. Once your bump is growing, avoid exercises that keep you lying flat on your back for a long time; lie on your side or sit propped up instead.",
            "If you have a health condition, or a complication in this pregnancy, ask your doctor or midwife which kinds of activity suit you."
          ],
          "vi": [
            "Đi bộ nhanh, bơi, thể dục dưới nước, đạp xe tại chỗ và các lớp yoga hay pilates cho bà bầu hợp với phần lớn các mẹ. Nếu trước đây mẹ đã quen tập luyện, mẹ thường có thể tiếp tục và giảm dần cường độ khi bụng lớn lên.",
            "Mẹ nên tránh các môn thể thao đối kháng, các hoạt động dễ ngã như cưỡi ngựa hay trượt tuyết, và lặn có bình dưỡng khí. Khi bụng đã lớn dần, mẹ tránh những bài tập phải nằm ngửa lâu; thay vào đó, mẹ nằm nghiêng hoặc ngồi tựa lưng.",
            "Nếu mẹ có bệnh lý sẵn có hoặc có biến chứng trong lần mang thai này, mẹ hãy hỏi bác sĩ hoặc nữ hộ sinh xem cách vận động nào phù hợp với mình."
          ]
        }
      },
      {
        "heading": {
          "en": "Listening to your body",
          "vi": "Lắng nghe cơ thể"
        },
        "paragraphs": {
          "en": [
            "At a moderate pace, you can still speak in full sentences. Drink water before, during and after exercise, and avoid getting very hot, especially on humid days. Your joints are looser in pregnancy, so warm up gently and avoid jerky movements.",
            "Stop and rest if you feel dizzy or unusually tired, or more out of breath than the effort explains, and tell your doctor or midwife before you exercise again. If you faint, or the dizziness does not pass when you sit down, see your doctor. Pain and swelling in one calf needs a doctor straight away.",
            "Some signs need care straight away. If you have bleeding from your vagina, regular painful tightenings, or fluid leaking from your vagina, contact your maternity unit straight away, whatever the colour of the fluid. If your baby moves less than usual, call your maternity unit straight away, day or night. For chest pain, or trouble breathing that does not ease with rest, call an emergency ambulance (115) straight away."
          ],
          "vi": [
            "Khi tập ở mức vừa phải, mẹ vẫn nói được trọn câu. Mẹ uống nước trước, trong và sau khi tập, và tránh để người quá nóng, nhất là vào hôm trời oi bức. Khi mang thai, các khớp lỏng hơn, nên mẹ khởi động nhẹ nhàng và tránh động tác giật mạnh.",
            "Mẹ hãy dừng lại nghỉ nếu thấy chóng mặt, mệt bất thường hoặc hụt hơi nhiều hơn mức gắng sức, và báo bác sĩ hoặc nữ hộ sinh trước khi tập lại. Nếu ngất, hoặc chóng mặt không đỡ khi đã ngồi xuống, mẹ hãy đi khám. Nếu một bên bắp chân đau và sưng, mẹ cần gặp bác sĩ ngay.",
            "Một số dấu hiệu cần được chăm sóc ngay. Nếu ra máu âm đạo, bụng gò đều và đau, hoặc ra nước âm đạo, mẹ hãy liên hệ khoa sản ngay, dù nước có màu gì. Nếu bé cử động ít hơn mọi ngày, mẹ hãy gọi ngay cho khoa sản, dù ngày hay đêm. Nếu đau ngực, hoặc khó thở mà nghỉ ngơi không đỡ, mẹ hãy gọi cấp cứu 115 ngay."
          ]
        }
      }
    ],
    "sources": [1, 3, 5]
  }
}
```
Its counts: en summary 28, words 393, 3 sections; vi summary 36, words 479, 3 sections. Note how it handles rules 3, 6 and 8: dizziness, fainting and calf pain each get a pointer matching the week warnings; bleeding, fluid leaking and regular painful tightenings go to the maternity unit straight away, whatever the colour; fewer movements go to the maternity unit straight away, day or night; chest pain or trouble breathing go to 115.

**Fact checklist — nutrition and movement** (cover every listed fact; add nothing that contradicts it; any extra fact goes in the commit's "Added beyond the checklist" block):

- **`nutrition-first-trimester`** (trimester 1) — Sources `[0, 2, 5, 9]`. Suggested sections: "Ăn thế nào trong những tuần đầu" / "Eating in the first weeks"; "Khi buồn nôn" / "When you feel sick"; "Những chất cần chú ý" / "Nutrients to think about".
  - Facts: no need to "eat for two" — the first trimester needs little or no extra food, so focus on variety, not amount; a balanced plate: vegetables and fruit, whole grains, protein (fish, eggs, beans, tofu, lean meat), and milk or other dairy; drink water through the day; folic acid as the doctor or midwife advises (named, no dose), usually from before pregnancy and through the first weeks; small, frequent, plain meals and ginger as a food for nausea; nausea can come at any time of day and often eases in the second trimester.
  - Pointer (also a warning): vomiting so often that fluids do not stay down, or with dizziness or very dark urine → see the doctor the same day.
  - Avoid: calorie numbers, supplement doses, "morning sickness means a healthy baby".
- **`food-safety`** (trimesters 1–3) — Sources `[0, 2, 4, 5, 9]`. Suggested sections: "Thực phẩm nên tránh" / "Foods to avoid"; "Caffeine và rượu bia" / "Caffeine and alcohol"; "Chế biến và bảo quản an toàn" / "Preparing and storing food safely".
  - Facts: avoid raw or undercooked meat and eggs (cook eggs until the white and yolk are firm), raw fish and shellfish (gỏi cá, sushi), tiết canh, nem chua and other raw fermented meat; unpasteurised milk and cheeses made from it; liver and liver products in large amounts (too much vitamin A); fish high in mercury (shark, swordfish, king mackerel), while other cooked fish is a good food; no amount of alcohol is known to be safe, so avoid it altogether; caffeine: use **exactly** `KnowledgeChecks.doseAllowList` — en "Most guidelines suggest keeping caffeine below 200 mg a day in total, counting coffee, tea, cola, energy drinks and chocolate." / vi "Phần lớn các hướng dẫn khuyên mẹ giữ tổng lượng caffeine dưới 200 mg mỗi ngày, tính cả cà phê, trà, nước cola, nước tăng lực và sô-cô-la."; wash hands, fruit, vegetables and herbs (rau sống) well; keep raw and cooked food apart; reheat leftovers until steaming hot; ask the doctor or midwife before herbal or traditional remedies.
  - Guideline figure (listed for the doctor): caffeine below 200 mg a day (ACOG CO 462, NHS).
  - Avoid: any other mg figure (the check rejects it), a listeria or toxoplasma risk number, brand names.
- **`iron-calcium-balanced-meals`** (trimesters 2–3) — Sources `[0, 2, 5, 9]`. Suggested sections: "Vì sao cần thêm sắt" / "Why you need more iron"; "Canxi cho xương" / "Calcium for bones"; "Một bữa ăn cân đối" / "A balanced meal".
  - Facts: blood volume rises, so iron needs rise; iron-rich foods: lean red meat, eggs, beans, tofu, dark green leafy vegetables (rau ngót, rau dền, rau muống); vitamin C foods (oranges, guava, tomatoes) help absorb iron; tea and coffee with a meal reduce absorption, so drink them between meals; iron (named, no dose) as the doctor or midwife advises; calcium from milk, yoghurt, pasteurised cheese, tofu, small fish eaten with their bones (cá cơm, tép) and green vegetables; if you do not eat dairy, ask the doctor or midwife how to get enough calcium; later pregnancy needs only a little more food, not double portions.
  - Pointer: unusual tiredness, feeling breathless or looking pale → tell the doctor or midwife (a blood test can check for anaemia).
  - Avoid: milligram or calorie figures, "iron prevents …" promises.
- **`gentle-exercise-second-trimester`** (trimester 2) — Sources `[1, 3, 5]`. Suggested sections: "Tam cá nguyệt hai thường dễ chịu hơn" / "The second trimester often feels easier"; "Một buổi tập nhẹ nhàng" / "A gentle session"; "Điều chỉnh khi bụng lớn dần" / "Adjusting as your bump grows".
  - Facts: energy often returns, a good time to build a routine; a session = gentle warm-up, 20–30 minutes of walking, swimming, cycling on an exercise bike or a pregnancy class, then a cool-down and stretches; the talk test; balance changes as the bump grows (flat, non-slip shoes, care on stairs); avoid lying flat on the back for long; a supportive bra; drink water, stay cool; it still counts towards the weekly amount in `safe-exercise` (refer to it in words, no link).
  - Pointers: the stop signs of `safe-exercise` in one sentence (dizziness, chest pain, calf pain and swelling → doctor); bleeding, fluid leaking, regular painful tightenings → maternity unit straight away; reduced movements (once felt) → maternity unit straight away, day or night.
  - Guideline figure: about 150 minutes a week (WHO 2020, ACOG CO 804), if repeated.
- **`pelvic-floor-posture`** (trimesters 2–3) — Sources `[2, 5, 6]`. Suggested sections: "Cơ sàn chậu là gì" / "What the pelvic floor does"; "Cách tập" / "How to do the exercises"; "Tư thế hằng ngày" / "Everyday posture".
  - Facts: the pelvic floor muscles support the bladder, bowel and womb; pregnancy hormones and the baby's weight strain them, so leaking a little urine when coughing, laughing or sneezing is common; NICE recommends pelvic floor exercises in pregnancy; how: squeeze and lift as if holding in wind and urine, hold a few seconds, relax fully; then a few quick squeezes; repeat a few times every day, sitting, lying or standing; breathe normally; do not practise by stopping your urine flow; posture: stand tall, support your lower back when sitting, bend your knees to lift and avoid heavy lifting, turn your whole body rather than twisting.
  - Pointers: pain at the front or back of the pelvis that makes walking or turning in bed hard → tell the doctor or midwife; if you are not sure whether a leak is urine or fluid from the vagina (waters), contact the maternity unit straight away, whatever the colour.
  - Avoid: NHS's "10 squeezes, 3 times a day" wording (no close paraphrase); counts of seconds or sets beyond "a few".
- **`safe-exercise`** (already in the file since Task 2) — reread it beside `gentle-exercise-second-trimester`: no sentence repeated word for word, no contradiction. Change it only if the review finds a problem; if you do, rerun the script with the whole article and keep sources `[1, 3, 5]`.

- [ ] **Step 1: Read for consistency.** Read the week articles that cover the same ground (they must not be contradicted): weeks 5, 6, 8, 16, 29 (food, iron, calcium) and 14, 17, 35 (exercise, shoes, pelvic floor):
```bash
python3 -c "import json;w=json.load(open('Packages/KickCore/Sources/KickCore/Resources/pregnancy-content.json'))['weeks'];a=[x for x in w if x['week']==16][0]['article'];print(json.dumps({k:a[k] for k in ('body','todo')},ensure_ascii=False,indent=1))"
```
(change `16`). Note anything the new articles must agree with.

- [ ] **Step 2: Write the three nutrition articles**

Write one JSON object with keys `"nutrition-first-trimester"`, `"food-safety"`, `"iron-calcium-balanced-meals"` in the shape above, then run:
```bash
scripts/set-knowledge-articles.py <<'JSON'
{ "nutrition-first-trimester": { … }, "food-safety": { … }, "iron-calcium-balanced-meals": { … } }
JSON
```
(Replace each `{ … }` with the full article; the script refuses anything incomplete.)
Expected: six lines `<id> en|vi: summary S, words W, sections N` with every `S` ≤ 35 (en) / ≤ 45 (vi), every `W` between 300 and 500 and every `N` between 2 and 4. If a number is out of range, edit that article and run the script again with only that article.

- [ ] **Step 3: Write the two movement articles** (`"gentle-exercise-second-trimester"`, `"pelvic-floor-posture"`), the same way. Expected: four count lines, all in range.

- [ ] **Step 4: Require the six articles and run the checks**

In `Packages/KickCore/Tests/KickCoreTests/BundledKnowledgeTests.swift`, replace:
```swift
    static let requiredArticleIDs: Set<String> = ["safe-exercise"]
```
with:
```swift
    static let requiredArticleIDs: Set<String> = [
        "nutrition-first-trimester", "food-safety", "iron-calcium-balanced-meals",
        "safe-exercise", "gentle-exercise-second-trimester", "pelvic-floor-posture",
    ]
```
Run: `scripts/test-core.sh --filter "BundledKnowledgeTests|KnowledgeChecksTests"`
Expected: PASS. Any failure names the article, field and language; fix the text, rerun the script for that article, rerun the tests.

- [ ] **Step 5: Three suggestions on Today**

Trimester 2 now has five articles in two topics, so the card shows three. In `UITests/KnowledgeUITests.swift`, replace:
```swift
        // Task 2: safe-exercise is the only article written so far (Task 3 makes it 3).
        XCTAssertEqual(suggestions(app).count, 1)
        XCTAssertTrue(app.buttons["knowledgeSuggestion-safe-exercise"].exists)
```
with:
```swift
        // Three suggestions (spec §3.3); which ones changes with the content.
        XCTAssertEqual(suggestions(app).count, 3)
```

- [ ] **Step 6: Accuracy and tone review**

Reread all six articles against the fact checklist, the writing guide and the review rules, one article at a time:
- Every listed fact is covered; nothing contradicts the week articles read in Step 1.
- No sentence copied or closely paraphrased from NHS or any other site; Vietnamese reads as native northern writing; en and vi say exactly the same things (same facts, same pointers, same order).
- Every symptom that is also a week warning has its one calm pointer, with the exact wording; waters and reduced movements say "straight away" (and "day or night" for movements).
- No promises about the reader's baby; hedged wording; no doses except the allow-listed caffeine sentence; supplements named only as allowed.
- Week numbers are completed weeks.
Fix anything that fails with the script and rerun Step 4.

- [ ] **Step 7: Commit, push, verify CI**

List the facts you added beyond the checklist (one line each, vi or en) in the `Added beyond the checklist:` block; write `Added beyond the checklist: none` if there are none.
```bash
scripts/test-core.sh
git add Packages/KickCore UITests/KnowledgeUITests.swift
git commit -F - <<'MSG'
content: knowledge articles on nutrition and movement

Original Vietnamese and English articles on eating in the first
trimester, food safety, iron and calcium, gentle second-trimester
exercise and the pelvic floor, with safe-exercise reread beside them.
Every article stays unreviewed until the obstetrician signs off. The
bundle test now requires these six articles, and Today shows three
suggestions.

Added beyond the checklist:
- <one fact per line, with its article id>

CI-Only-Testing: KnowledgeUITests, KnowledgeScreenshotTests
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `Test run with 472 tests` locally; `CI PASSED`.

- [ ] **Step 8: Visual check**

- `knowledge-card-vi-light`, `knowledge-card-en-dark`: three rows, each with a different topic symbol or, at most, two sharing one; titles readable; summaries cut at two lines; hairlines between rows.
- `knowledge-library-vi-light`: "Dinh dưỡng" (food safety, iron and calcium) then "Vận động" (safe exercise, gentle exercise, pelvic floor: file order); the screenshot may cut the list, which is fine.

---
### Task 4: Content — sleep and feelings

Write original vi + en articles for the `sleep` and `feelings` topics and require them. This task writes prose, not code.

**Files:**
- Modify: `Packages/KickCore/Sources/KickCore/Resources/knowledge-content.json` (via `scripts/set-knowledge-articles.py` only), `Packages/KickCore/Tests/KickCoreTests/BundledKnowledgeTests.swift` (`requiredArticleIDs`)

**Interfaces:**
- Consumes: `scripts/set-knowledge-articles.py`, `KnowledgeChecks`, `BundledKnowledgeTests` (Task 1); the six articles of Tasks 2–3; the week articles (read-only).
- Produces: articles `first-trimester-tiredness`, `sleep-positions`, `sleeping-well-late-pregnancy`, `early-pregnancy-worries`, `changing-body-feelings`, `preparing-for-motherhood`; `requiredArticleIDs` = the twelve written so far.

**Writing guide (Phase 6 spec 2026-10-06 §4.4, verbatim; for Knowledge, "the sources listed in `PregnancyContent.sources`" means `KnowledgeContent.sources`, and the Length and Accuracy bullets are replaced by the differences below):**

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

**Knowledge writing guide (spec 2026-10-07 §3.4, verbatim):**

The Phase 6 guide applies (spec 2026-10-06 §4.4):
- original text only;
- hedged and warm in tone;
- Vietnamese written natively, in northern usage;
- metric units only;
- no diagnosis;
- no medicine names with doses;
- the doctor or midwife is "bác sĩ hoặc nữ hộ sinh" / "your doctor or midwife".

The Phase 6 batch-review lessons also apply:
- no promises about the reader's own baby;
- any symptom that is also a warning sign gets one calm sentence pointing to the doctor or midwife;
- vi and en say the same thing;
- no close paraphrase of NHS or any other site.

Differences for Knowledge articles:
- **Length:** each article is 300–500 words per language. The count covers summary, headings and paragraphs, with words split on whitespace. Each article has 2–4 sections, and each section has 1–4 paragraphs.
- **Guideline figures:** public-health figures are allowed. Examples are "about 150 minutes of activity a week" (WHO) and a daily caffeine limit (NHS/WHO). Every such figure is listed for the doctor.
- **Feelings articles:** these always include a gentle line to seek help if low mood or worry lasts most days for two weeks or more. They also name who to tell: the doctor or midwife, or family.
- **The `signs-of-labour` article** must match the week warnings:
  - if the waters break, call the maternity unit straight away, whatever the colour;
  - if the baby moves less, call straight away, day or night.

**Review rules (enforced in the Phase 6 review rounds; the review step checks every one):**

1. **Completed-week counting.** Week numbers are completed weeks, as the app shows them: "tuần 24" / "week 24" is 24 weeks and 0–6 days ("24 weeks, 3 days" on Today). Never "tuần thứ 24" / "the 24th week" (that is 23 completed weeks). Trimesters follow the app: 1 = up to week 13, 2 = weeks 14–27, 3 = from week 28. Ranges use the app's milestones ("tuần 24 đến 28" / "weeks 24 to 28").
2. **No promises about the reader's baby.** Never "your baby will be fine", "bé sẽ khỏe mạnh", or "this is nothing to worry about" about a symptom. Use "usually", "many", "may" / "thường", "nhiều", "có thể".
3. **A pointer for every symptom that is also a warning.** Any symptom that appears in a week's "When to get care right away" list (vaginal bleeding; belly pain that does not go away; sharp pain on one side or at the shoulder tip; vomiting so often that fluids do not stay down; severe headache, blurred vision or sudden swelling of the face, hands or feet; fits or trouble breathing; fluid leaking from the vagina; regular tightenings before 37 weeks; fever of 38°C or more; intense itching on the palms and soles; a painful, red or swollen area in one leg; fainting; reduced movements) gets one calm sentence saying who to contact and how soon, matching that list. Do not reassure about it in the same sentence.
4. **vi and en say the same thing:** the same facts, figures, pointers and order. A fact in one language only is a defect.
5. **Northern Vietnamese:** tất (not vớ), ngô (not bắp), lợi (not nướu), trượt ngã (not té ngã), vừng (not mè), lạc (not đậu phộng), dứa (not thơm/khóm), quả (not trái), ốm = sick (never "thin"), bỉm or tã for nappies.
6. **Exact pointer wording, where one is used:** "bác sĩ hoặc nữ hộ sinh" / "your doctor or midwife"; "khoa sản" / "your maternity unit"; "gọi cấp cứu 115" / "call an emergency ambulance (115)"; "ngay" / "straight away"; "dù ngày hay đêm" / "day or night". A pointer to the week page's list uses exactly: "mục “Khi nào cần đi khám ngay” ở trang tuần" / "“When to get care right away” on your week page". Knowledge articles have no warning list of their own: never write "the warning signs below".
7. **No close NHS paraphrase** (or of any other site): do not follow a source's sentence order, examples and wording; write from the facts.
8. **Waters breaking or reduced movements mean calling straight away.** Fluid leaking from the vagina → contact the maternity unit straight away, whatever the colour ("dù nước ối trong, xanh hay nâu" / "whether the fluid is clear, green or brown", or "dù nước có màu gì" / "whatever the colour"). The baby moving less than usual, or a change in the pattern → contact the maternity unit straight away, day or night. Never "wait", "count again later", "lie down and drink something cold" or "see in the morning".

**Plan rules (in addition to the guide; see "Spec clarifications" 5, 15, 16):**
- `summary`: one sentence, ≤ 35 words (en) / ≤ 45 (vi). Article (summary + headings + paragraphs) 300–500 words per language; aim for en 330–420 and vi 400–480 so edits stay in range. 2–4 sections, 1–4 paragraphs each (aim for 2–3 sections of 2–3 paragraphs). The title is short (about 8 words or fewer in English) and is not counted.
- Keys in this order: `topic`, `trimesters`, `reviewed` (`false`), `title`, `summary`, `sections`, `sources`; each section has `heading` then `paragraphs`. `topic` and `trimesters` must be the catalogue's (the fact checklist repeats them); the script refuses anything else.
- `sources`: indices into `knowledge-content.json`'s `sources`, only the ones you used: 0 = WHO antenatal care 2016, 1 = WHO physical activity 2020, 2 = ACOG patient education, 3 = ACOG CO 804 (exercise), 4 = ACOG CO 462 (caffeine), 5 = NHS, 6 = NICE NG201 (antenatal care), 7 = NICE CG192 (mental health), 8 = WHO/UNICEF breastfeeding 2018, 9 = Bộ Y tế. Use the fact checklist's list unless you drop one you did not use.
- Medicine: folic acid / axit folic and iron / sắt may be named **without** a dose, "as your doctor or midwife advises" / "theo hướng dẫn của bác sĩ hoặc nữ hộ sinh". Vaccines are named by disease ("uốn ván, ho gà"). No other medicine, supplement or product names; no doses (`mg`, `mcg`, `µg`, `IU` fail the checks except in the caffeine sentence of `food-safety`).
- Every guideline figure you use is in the fact checklist; if you use another one, put it in the commit's "Added beyond the checklist" block so Task 6 lists it for the doctor.
- Do not contradict the week articles or the milestones; do not repeat a week article's sentences word for word.
- Every Vietnamese text (title, summary, headings, paragraphs) has diacritics; keep `"reviewed": false`.

**JSON shape** (one object per article id; the script writes `id` itself and keeps catalogue order):
```json
{
  "<article id>": {
    "topic": "<topic id>",
    "trimesters": [2, 3],
    "reviewed": false,
    "title": {"en": "<title>", "vi": "<tiêu đề>"},
    "summary": {"en": "<one sentence>", "vi": "<một câu>"},
    "sections": [
      {"heading": {"en": "<heading>", "vi": "<tiêu đề mục>"}, "paragraphs": {"en": ["<p1>", "<p2>"], "vi": ["<đ1>", "<đ2>"]}},
      {"heading": {"en": "<heading>", "vi": "<tiêu đề mục>"}, "paragraphs": {"en": ["<p1>"], "vi": ["<đ1>"]}}
    ],
    "sources": [2, 5]
  }
}
```

**Example — `safe-exercise`, already in the file since Task 2** (the bar for quality, tone, pointers and length; do not reuse its sentences):
```json
{
  "safe-exercise": {
    "topic": "movement",
    "trimesters": [1, 2, 3],
    "reviewed": false,
    "title": {
      "en": "Staying active safely in pregnancy",
      "vi": "Vận động an toàn khi mang thai"
    },
    "summary": {
      "en": "For most pregnancies, regular moderate activity is safe and good for you, as long as your doctor or midwife agrees and you adjust it as your body changes.",
      "vi": "Với phần lớn thai kỳ, vận động vừa sức đều đặn là an toàn và có lợi, miễn là bác sĩ hoặc nữ hộ sinh đồng ý và mẹ điều chỉnh khi cơ thể thay đổi."
    },
    "sections": [
      {
        "heading": {
          "en": "Why moving helps",
          "vi": "Vì sao vận động có ích"
        },
        "paragraphs": {
          "en": [
            "Staying active during pregnancy can lift your mood, help you sleep and ease some common discomforts, such as backache and constipation. It can also help keep your weight gain in a healthy range and build stamina for labour.",
            "The World Health Organization and other guidelines suggest about 150 minutes of moderate activity a week, spread over several days. Short sessions of about 10 minutes count too. If you were not active before, start with a few minutes a day and build up slowly."
          ],
          "vi": [
            "Vận động đều đặn khi mang thai có thể giúp mẹ vui vẻ hơn, ngủ ngon hơn và đỡ một số khó chịu thường gặp như đau lưng hay táo bón. Vận động cũng giúp mẹ tăng cân trong mức hợp lý và có thêm sức bền cho lúc chuyển dạ.",
            "Tổ chức Y tế Thế giới và nhiều hướng dẫn khác gợi ý mẹ vận động vừa sức khoảng 150 phút mỗi tuần, chia ra nhiều ngày. Những lần tập ngắn khoảng 10 phút cũng được tính. Nếu trước đây ít vận động, mẹ hãy bắt đầu với vài phút mỗi ngày rồi tăng dần."
          ]
        }
      },
      {
        "heading": {
          "en": "Choosing what to do",
          "vi": "Chọn cách vận động phù hợp"
        },
        "paragraphs": {
          "en": [
            "Brisk walking, swimming, water aerobics, an exercise bike and pregnancy yoga or pilates classes suit most people. If you were already active before pregnancy, you can usually carry on, easing off as your bump grows.",
            "Avoid contact sports, activities with a high chance of falling, such as horse riding or skiing, and scuba diving. Once your bump is growing, avoid exercises that keep you lying flat on your back for a long time; lie on your side or sit propped up instead.",
            "If you have a health condition, or a complication in this pregnancy, ask your doctor or midwife which kinds of activity suit you."
          ],
          "vi": [
            "Đi bộ nhanh, bơi, thể dục dưới nước, đạp xe tại chỗ và các lớp yoga hay pilates cho bà bầu hợp với phần lớn các mẹ. Nếu trước đây mẹ đã quen tập luyện, mẹ thường có thể tiếp tục và giảm dần cường độ khi bụng lớn lên.",
            "Mẹ nên tránh các môn thể thao đối kháng, các hoạt động dễ ngã như cưỡi ngựa hay trượt tuyết, và lặn có bình dưỡng khí. Khi bụng đã lớn dần, mẹ tránh những bài tập phải nằm ngửa lâu; thay vào đó, mẹ nằm nghiêng hoặc ngồi tựa lưng.",
            "Nếu mẹ có bệnh lý sẵn có hoặc có biến chứng trong lần mang thai này, mẹ hãy hỏi bác sĩ hoặc nữ hộ sinh xem cách vận động nào phù hợp với mình."
          ]
        }
      },
      {
        "heading": {
          "en": "Listening to your body",
          "vi": "Lắng nghe cơ thể"
        },
        "paragraphs": {
          "en": [
            "At a moderate pace, you can still speak in full sentences. Drink water before, during and after exercise, and avoid getting very hot, especially on humid days. Your joints are looser in pregnancy, so warm up gently and avoid jerky movements.",
            "Stop and rest if you feel dizzy or unusually tired, or more out of breath than the effort explains, and tell your doctor or midwife before you exercise again. If you faint, or the dizziness does not pass when you sit down, see your doctor. Pain and swelling in one calf needs a doctor straight away.",
            "Some signs need care straight away. If you have bleeding from your vagina, regular painful tightenings, or fluid leaking from your vagina, contact your maternity unit straight away, whatever the colour of the fluid. If your baby moves less than usual, call your maternity unit straight away, day or night. For chest pain, or trouble breathing that does not ease with rest, call an emergency ambulance (115) straight away."
          ],
          "vi": [
            "Khi tập ở mức vừa phải, mẹ vẫn nói được trọn câu. Mẹ uống nước trước, trong và sau khi tập, và tránh để người quá nóng, nhất là vào hôm trời oi bức. Khi mang thai, các khớp lỏng hơn, nên mẹ khởi động nhẹ nhàng và tránh động tác giật mạnh.",
            "Mẹ hãy dừng lại nghỉ nếu thấy chóng mặt, mệt bất thường hoặc hụt hơi nhiều hơn mức gắng sức, và báo bác sĩ hoặc nữ hộ sinh trước khi tập lại. Nếu ngất, hoặc chóng mặt không đỡ khi đã ngồi xuống, mẹ hãy đi khám. Nếu một bên bắp chân đau và sưng, mẹ cần gặp bác sĩ ngay.",
            "Một số dấu hiệu cần được chăm sóc ngay. Nếu ra máu âm đạo, bụng gò đều và đau, hoặc ra nước âm đạo, mẹ hãy liên hệ khoa sản ngay, dù nước có màu gì. Nếu bé cử động ít hơn mọi ngày, mẹ hãy gọi ngay cho khoa sản, dù ngày hay đêm. Nếu đau ngực, hoặc khó thở mà nghỉ ngơi không đỡ, mẹ hãy gọi cấp cứu 115 ngay."
          ]
        }
      }
    ],
    "sources": [1, 3, 5]
  }
}
```
Its counts: en summary 28, words 393, 3 sections; vi summary 36, words 479, 3 sections. Note how it handles rules 3, 6 and 8: dizziness, fainting and calf pain each get a pointer matching the week warnings; bleeding, fluid leaking and regular painful tightenings go to the maternity unit straight away, whatever the colour; fewer movements go to the maternity unit straight away, day or night; chest pain or trouble breathing go to 115.

**Fact checklist — sleep and feelings:**

- **`first-trimester-tiredness`** (trimester 1) — Sources `[0, 2, 5]`. Suggested sections: "Vì sao mẹ mệt" / "Why you feel so tired"; "Nghỉ ngơi thế nào cho đủ" / "Getting enough rest"; "Khi nào nên hỏi bác sĩ" / "When to ask your doctor or midwife".
  - Facts: hormone changes and the work of building the placenta make tiredness very common in the first weeks; nausea and broken sleep add to it; it usually eases in the second trimester; early nights, short daytime rests, light activity such as a walk, regular meals with iron-rich foods and water; ask family to share chores; take care driving when drowsy.
  - Pointers: tiredness with breathlessness, a racing heart or a pale look → tell the doctor or midwife (anaemia can be checked); feeling low or worried most days → the line in the feelings articles (say it in one sentence here too: two weeks or more → tell the doctor or midwife, or family).
- **`sleep-positions`** (trimesters 2–3) — Sources `[2, 5, 6]`. Suggested sections: "Nằm nghiêng khi đi ngủ" / "Going to sleep on your side"; "Gối và tư thế dễ chịu" / "Pillows and comfort"; "Nếu thức dậy thấy mình nằm ngửa" / "If you wake on your back".
  - Facts: from about 28 weeks, guidelines advise going to sleep on your side, for night sleep and daytime naps; either side is fine; earlier in the second trimester side sleeping simply tends to be more comfortable, and lying flat on the back can make some people dizzy as the womb presses on a large vein; a pillow under the bump, one between the knees, one behind the back; waking on your back is common: simply roll onto your side (must match the week 26 and 28 articles).
  - Avoid: risk figures or frightening wording about stillbirth; "you must never lie on your back".
  - Guideline timing (listed for the doctor): side sleeping from about 28 weeks (NICE NG201, NHS).
- **`sleeping-well-late-pregnancy`** (trimester 3) — Sources `[2, 5, 7]`. Suggested sections: "Vì sao khó ngủ" / "Why sleep gets harder"; "Những điều có thể giúp" / "Things that may help"; "Những điều cần báo bác sĩ" / "What to tell your doctor or midwife".
  - Facts: the bump, needing to pee at night, heartburn, leg cramps, restless legs, the baby's movements and worries can all break sleep; a regular wind-down routine, a cool and dark room, screens off earlier, most fluids earlier in the day, a small early evening meal and raising the head of the bed for heartburn, calf stretches before bed, slow breathing, daytime rest when possible.
  - Pointers (also warnings): intense itching, especially on the palms and soles → tell the doctor promptly; restless legs that disturb sleep most nights → tell the doctor or midwife; the baby moving less than usual, or a change in the pattern → contact the maternity unit straight away, day or night (never "wait until morning"); worry or low mood most days for two weeks or more → tell the doctor or midwife, or family.
- **`early-pregnancy-worries`** (trimester 1) — Sources `[0, 5, 7]`. Suggested sections: "Lo lắng là chuyện thường gặp" / "Worry is common"; "Những cách có thể giúp" / "Things that may help"; "Khi nào cần tìm hỗ trợ" / "When to get support".
  - Facts: many people feel a mix of joy and worry early on: about the pregnancy continuing, tests, money, work, their body; mood can swing with hormones and tiredness; talk with your partner, family or a friend; write questions down for check-ups; choose reliable information and limit late-night searching; rest, gentle activity and regular meals help mood.
  - Pointers: any bleeding, or belly pain that does not go away → contact the doctor straight away (a week 4–13 warning); **mandatory line:** if low mood or worry lasts most days for two weeks or more, tell your doctor or midwife, or someone in your family; if you ever have thoughts of harming yourself, tell someone you trust and get help straight away: call 115 or go to the nearest hospital.
  - Avoid: miscarriage percentages; "everything will be fine".
- **`changing-body-feelings`** (trimester 2) — Sources `[2, 5, 7]`. Suggested sections: "Cơ thể thay đổi, cảm xúc cũng đổi thay" / "A changing body, changing feelings"; "Chuyện vợ chồng" / "You and your partner"; "Chăm sóc tinh thần" / "Looking after your mind".
  - Facts: a growing bump, stretch marks, skin and hair changes can bring pride, surprise or unease; others' comments about size can hurt, and every bump is different; for most pregnancies sex is safe unless the doctor or midwife advises otherwise, and wanting it more or less is normal; share how you feel with your partner; small pleasures, rest and time outdoors help; the mandatory two-week line with who to tell.
  - Pointer: bleeding or pain after sex → contact the maternity unit straight away; fluid leaking → straight away, whatever the colour.
- **`preparing-for-motherhood`** (trimester 3) — Sources `[2, 5, 7, 9]`. Suggested sections: "Cảm xúc trước ngày sinh" / "Feelings before the birth"; "Chuẩn bị chỗ dựa" / "Lining up support"; "Sau khi sinh" / "After the birth".
  - Facts: excitement, impatience and fear of the birth are all common; antenatal classes and talking the birth through with the doctor or midwife can ease fear; plan who will help in the first weeks (meals, chores, night feeds, rest); share tasks with the partner; "baby blues" (tearful, up and down) in the first days after birth is common and usually passes within about two weeks; feelings that last longer, or are severe, can be postnatal depression, which is treatable; the mandatory two-week line with who to tell.
  - Guideline figure (listed for the doctor): baby blues usually pass within about two weeks (NICE CG192, NHS).
  - Avoid: the word "failure"; promises that the birth will go a certain way.

- [ ] **Step 1: Read for consistency.** Read the week articles that cover the same ground: weeks 6, 8, 10 (tiredness, emotions), 26, 28, 33 (sleep), 37, 38 (late feelings) with the command from Task 3 Step 1, and the three movement articles (for wording of pointers).

- [ ] **Step 2: Write the three sleep articles** (`"first-trimester-tiredness"`, `"sleep-positions"`, `"sleeping-well-late-pregnancy"`):
```bash
scripts/set-knowledge-articles.py <<'JSON'
{ "first-trimester-tiredness": { … }, "sleep-positions": { … }, "sleeping-well-late-pregnancy": { … } }
JSON
```
(Replace each `{ … }` with the full article.) Expected: six count lines, every summary ≤ 35 (en) / ≤ 45 (vi), every article 300–500 words, 2–4 sections.

- [ ] **Step 3: Write the three feelings articles** (`"early-pregnancy-worries"`, `"changing-body-feelings"`, `"preparing-for-motherhood"`), the same way. Expected: six count lines, all in range. Each feelings article contains the two-week line and names who to tell.

- [ ] **Step 4: Require the twelve articles and run the checks**

In `Packages/KickCore/Tests/KickCoreTests/BundledKnowledgeTests.swift`, replace:
```swift
    static let requiredArticleIDs: Set<String> = [
        "nutrition-first-trimester", "food-safety", "iron-calcium-balanced-meals",
        "safe-exercise", "gentle-exercise-second-trimester", "pelvic-floor-posture",
    ]
```
with:
```swift
    static let requiredArticleIDs: Set<String> = [
        "nutrition-first-trimester", "food-safety", "iron-calcium-balanced-meals",
        "safe-exercise", "gentle-exercise-second-trimester", "pelvic-floor-posture",
        "first-trimester-tiredness", "sleep-positions", "sleeping-well-late-pregnancy",
        "early-pregnancy-worries", "changing-body-feelings", "preparing-for-motherhood",
    ]
```
Run: `scripts/test-core.sh --filter "BundledKnowledgeTests|KnowledgeChecksTests"`
Expected: PASS.

- [ ] **Step 5: Accuracy and tone review**

As Task 3 Step 6, for the six new articles, plus:
- Each feelings article has the two-week line ("most days for two weeks or more" / "gần như mỗi ngày, kéo dài từ hai tuần trở lên") and names the doctor or midwife and family.
- `sleep-positions` agrees with weeks 26 and 28 ("waking on your back is common; simply roll onto your side").
- `sleeping-well-late-pregnancy` sends reduced movements straight to the maternity unit, day or night.
Fix and rerun Step 4.

- [ ] **Step 6: Commit, push, verify CI**

```bash
scripts/test-core.sh
git add Packages/KickCore
git commit -F - <<'MSG'
content: knowledge articles on sleep and feelings

Original Vietnamese and English articles on first-trimester tiredness,
sleep positions, sleeping in late pregnancy, early worries, a changing
body and getting ready for motherhood. Each feelings article says when
to seek help and who to tell. Every article stays unreviewed; the
bundle test now requires these twelve articles.

Added beyond the checklist:
- <one fact per line, with its article id>

CI-Only-Testing: KnowledgeUITests, KnowledgeScreenshotTests
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `Test run with 472 tests` locally; `CI PASSED`.

- [ ] **Step 7: Visual check**

- `knowledge-card-vi-light`: three rows from three different topics.
- `knowledge-library-vi-light`, `knowledge-library-en-dark`: topics in order (Dinh dưỡng, Vận động, Giấc ngủ & nghỉ ngơi, Cảm xúc), each heading above its own card; long Vietnamese titles wrap cleanly.

---
### Task 5: Content — check-ups and birth; all 18 articles required

Write original vi + en articles for the `checkups` and `birth` topics, require every catalogue article (spec §3.5 fully enforced, including trimester coverage), and point the library UI test at `signs-of-labour`. This task writes prose; its only code changes are the required set and one UI test line.

**Files:**
- Modify: `Packages/KickCore/Sources/KickCore/Resources/knowledge-content.json` (via `scripts/set-knowledge-articles.py` only), `Packages/KickCore/Tests/KickCoreTests/BundledKnowledgeTests.swift` (`requiredArticleIDs`), `UITests/KnowledgeUITests.swift` (one row)

**Interfaces:**
- Consumes: `scripts/set-knowledge-articles.py`, `KnowledgeChecks.articleIDs`, `BundledKnowledgeTests` (Task 1); the twelve articles of Tasks 2–4; the milestones and week warnings in `pregnancy-content.json` (read-only).
- Produces: articles `antenatal-checkup-milestones`, `first-trimester-screening`, `anomaly-scan-glucose-test`, `signs-of-labour`, `hospital-bag`, `birth-plan-breastfeeding`; `requiredArticleIDs == KnowledgeChecks.articleIDs`; the library test opens `signs-of-labour`.

**Writing guide (Phase 6 spec 2026-10-06 §4.4, verbatim; for Knowledge, "the sources listed in `PregnancyContent.sources`" means `KnowledgeContent.sources`, and the Length and Accuracy bullets are replaced by the differences below):**

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

**Knowledge writing guide (spec 2026-10-07 §3.4, verbatim):**

The Phase 6 guide applies (spec 2026-10-06 §4.4):
- original text only;
- hedged and warm in tone;
- Vietnamese written natively, in northern usage;
- metric units only;
- no diagnosis;
- no medicine names with doses;
- the doctor or midwife is "bác sĩ hoặc nữ hộ sinh" / "your doctor or midwife".

The Phase 6 batch-review lessons also apply:
- no promises about the reader's own baby;
- any symptom that is also a warning sign gets one calm sentence pointing to the doctor or midwife;
- vi and en say the same thing;
- no close paraphrase of NHS or any other site.

Differences for Knowledge articles:
- **Length:** each article is 300–500 words per language. The count covers summary, headings and paragraphs, with words split on whitespace. Each article has 2–4 sections, and each section has 1–4 paragraphs.
- **Guideline figures:** public-health figures are allowed. Examples are "about 150 minutes of activity a week" (WHO) and a daily caffeine limit (NHS/WHO). Every such figure is listed for the doctor.
- **Feelings articles:** these always include a gentle line to seek help if low mood or worry lasts most days for two weeks or more. They also name who to tell: the doctor or midwife, or family.
- **The `signs-of-labour` article** must match the week warnings:
  - if the waters break, call the maternity unit straight away, whatever the colour;
  - if the baby moves less, call straight away, day or night.

**Review rules (enforced in the Phase 6 review rounds; the review step checks every one):**

1. **Completed-week counting.** Week numbers are completed weeks, as the app shows them: "tuần 24" / "week 24" is 24 weeks and 0–6 days ("24 weeks, 3 days" on Today). Never "tuần thứ 24" / "the 24th week" (that is 23 completed weeks). Trimesters follow the app: 1 = up to week 13, 2 = weeks 14–27, 3 = from week 28. Ranges use the app's milestones ("tuần 24 đến 28" / "weeks 24 to 28").
2. **No promises about the reader's baby.** Never "your baby will be fine", "bé sẽ khỏe mạnh", or "this is nothing to worry about" about a symptom. Use "usually", "many", "may" / "thường", "nhiều", "có thể".
3. **A pointer for every symptom that is also a warning.** Any symptom that appears in a week's "When to get care right away" list (vaginal bleeding; belly pain that does not go away; sharp pain on one side or at the shoulder tip; vomiting so often that fluids do not stay down; severe headache, blurred vision or sudden swelling of the face, hands or feet; fits or trouble breathing; fluid leaking from the vagina; regular tightenings before 37 weeks; fever of 38°C or more; intense itching on the palms and soles; a painful, red or swollen area in one leg; fainting; reduced movements) gets one calm sentence saying who to contact and how soon, matching that list. Do not reassure about it in the same sentence.
4. **vi and en say the same thing:** the same facts, figures, pointers and order. A fact in one language only is a defect.
5. **Northern Vietnamese:** tất (not vớ), ngô (not bắp), lợi (not nướu), trượt ngã (not té ngã), vừng (not mè), lạc (not đậu phộng), dứa (not thơm/khóm), quả (not trái), ốm = sick (never "thin"), bỉm or tã for nappies.
6. **Exact pointer wording, where one is used:** "bác sĩ hoặc nữ hộ sinh" / "your doctor or midwife"; "khoa sản" / "your maternity unit"; "gọi cấp cứu 115" / "call an emergency ambulance (115)"; "ngay" / "straight away"; "dù ngày hay đêm" / "day or night". A pointer to the week page's list uses exactly: "mục “Khi nào cần đi khám ngay” ở trang tuần" / "“When to get care right away” on your week page". Knowledge articles have no warning list of their own: never write "the warning signs below".
7. **No close NHS paraphrase** (or of any other site): do not follow a source's sentence order, examples and wording; write from the facts.
8. **Waters breaking or reduced movements mean calling straight away.** Fluid leaking from the vagina → contact the maternity unit straight away, whatever the colour ("dù nước ối trong, xanh hay nâu" / "whether the fluid is clear, green or brown", or "dù nước có màu gì" / "whatever the colour"). The baby moving less than usual, or a change in the pattern → contact the maternity unit straight away, day or night. Never "wait", "count again later", "lie down and drink something cold" or "see in the morning".

**Plan rules (in addition to the guide; see "Spec clarifications" 5, 15, 16):**
- `summary`: one sentence, ≤ 35 words (en) / ≤ 45 (vi). Article (summary + headings + paragraphs) 300–500 words per language; aim for en 330–420 and vi 400–480 so edits stay in range. 2–4 sections, 1–4 paragraphs each (aim for 2–3 sections of 2–3 paragraphs). The title is short (about 8 words or fewer in English) and is not counted.
- Keys in this order: `topic`, `trimesters`, `reviewed` (`false`), `title`, `summary`, `sections`, `sources`; each section has `heading` then `paragraphs`. `topic` and `trimesters` must be the catalogue's (the fact checklist repeats them); the script refuses anything else.
- `sources`: indices into `knowledge-content.json`'s `sources`, only the ones you used: 0 = WHO antenatal care 2016, 1 = WHO physical activity 2020, 2 = ACOG patient education, 3 = ACOG CO 804 (exercise), 4 = ACOG CO 462 (caffeine), 5 = NHS, 6 = NICE NG201 (antenatal care), 7 = NICE CG192 (mental health), 8 = WHO/UNICEF breastfeeding 2018, 9 = Bộ Y tế. Use the fact checklist's list unless you drop one you did not use.
- Medicine: folic acid / axit folic and iron / sắt may be named **without** a dose, "as your doctor or midwife advises" / "theo hướng dẫn của bác sĩ hoặc nữ hộ sinh". Vaccines are named by disease ("uốn ván, ho gà"). No other medicine, supplement or product names; no doses (`mg`, `mcg`, `µg`, `IU` fail the checks except in the caffeine sentence of `food-safety`).
- Every guideline figure you use is in the fact checklist; if you use another one, put it in the commit's "Added beyond the checklist" block so Task 6 lists it for the doctor.
- Do not contradict the week articles or the milestones; do not repeat a week article's sentences word for word.
- Every Vietnamese text (title, summary, headings, paragraphs) has diacritics; keep `"reviewed": false`.

**JSON shape** (one object per article id; the script writes `id` itself and keeps catalogue order):
```json
{
  "<article id>": {
    "topic": "<topic id>",
    "trimesters": [2, 3],
    "reviewed": false,
    "title": {"en": "<title>", "vi": "<tiêu đề>"},
    "summary": {"en": "<one sentence>", "vi": "<một câu>"},
    "sections": [
      {"heading": {"en": "<heading>", "vi": "<tiêu đề mục>"}, "paragraphs": {"en": ["<p1>", "<p2>"], "vi": ["<đ1>", "<đ2>"]}},
      {"heading": {"en": "<heading>", "vi": "<tiêu đề mục>"}, "paragraphs": {"en": ["<p1>"], "vi": ["<đ1>"]}}
    ],
    "sources": [2, 5]
  }
}
```

**Example — `safe-exercise`, already in the file since Task 2** (the bar for quality, tone, pointers and length; do not reuse its sentences):
```json
{
  "safe-exercise": {
    "topic": "movement",
    "trimesters": [1, 2, 3],
    "reviewed": false,
    "title": {
      "en": "Staying active safely in pregnancy",
      "vi": "Vận động an toàn khi mang thai"
    },
    "summary": {
      "en": "For most pregnancies, regular moderate activity is safe and good for you, as long as your doctor or midwife agrees and you adjust it as your body changes.",
      "vi": "Với phần lớn thai kỳ, vận động vừa sức đều đặn là an toàn và có lợi, miễn là bác sĩ hoặc nữ hộ sinh đồng ý và mẹ điều chỉnh khi cơ thể thay đổi."
    },
    "sections": [
      {
        "heading": {
          "en": "Why moving helps",
          "vi": "Vì sao vận động có ích"
        },
        "paragraphs": {
          "en": [
            "Staying active during pregnancy can lift your mood, help you sleep and ease some common discomforts, such as backache and constipation. It can also help keep your weight gain in a healthy range and build stamina for labour.",
            "The World Health Organization and other guidelines suggest about 150 minutes of moderate activity a week, spread over several days. Short sessions of about 10 minutes count too. If you were not active before, start with a few minutes a day and build up slowly."
          ],
          "vi": [
            "Vận động đều đặn khi mang thai có thể giúp mẹ vui vẻ hơn, ngủ ngon hơn và đỡ một số khó chịu thường gặp như đau lưng hay táo bón. Vận động cũng giúp mẹ tăng cân trong mức hợp lý và có thêm sức bền cho lúc chuyển dạ.",
            "Tổ chức Y tế Thế giới và nhiều hướng dẫn khác gợi ý mẹ vận động vừa sức khoảng 150 phút mỗi tuần, chia ra nhiều ngày. Những lần tập ngắn khoảng 10 phút cũng được tính. Nếu trước đây ít vận động, mẹ hãy bắt đầu với vài phút mỗi ngày rồi tăng dần."
          ]
        }
      },
      {
        "heading": {
          "en": "Choosing what to do",
          "vi": "Chọn cách vận động phù hợp"
        },
        "paragraphs": {
          "en": [
            "Brisk walking, swimming, water aerobics, an exercise bike and pregnancy yoga or pilates classes suit most people. If you were already active before pregnancy, you can usually carry on, easing off as your bump grows.",
            "Avoid contact sports, activities with a high chance of falling, such as horse riding or skiing, and scuba diving. Once your bump is growing, avoid exercises that keep you lying flat on your back for a long time; lie on your side or sit propped up instead.",
            "If you have a health condition, or a complication in this pregnancy, ask your doctor or midwife which kinds of activity suit you."
          ],
          "vi": [
            "Đi bộ nhanh, bơi, thể dục dưới nước, đạp xe tại chỗ và các lớp yoga hay pilates cho bà bầu hợp với phần lớn các mẹ. Nếu trước đây mẹ đã quen tập luyện, mẹ thường có thể tiếp tục và giảm dần cường độ khi bụng lớn lên.",
            "Mẹ nên tránh các môn thể thao đối kháng, các hoạt động dễ ngã như cưỡi ngựa hay trượt tuyết, và lặn có bình dưỡng khí. Khi bụng đã lớn dần, mẹ tránh những bài tập phải nằm ngửa lâu; thay vào đó, mẹ nằm nghiêng hoặc ngồi tựa lưng.",
            "Nếu mẹ có bệnh lý sẵn có hoặc có biến chứng trong lần mang thai này, mẹ hãy hỏi bác sĩ hoặc nữ hộ sinh xem cách vận động nào phù hợp với mình."
          ]
        }
      },
      {
        "heading": {
          "en": "Listening to your body",
          "vi": "Lắng nghe cơ thể"
        },
        "paragraphs": {
          "en": [
            "At a moderate pace, you can still speak in full sentences. Drink water before, during and after exercise, and avoid getting very hot, especially on humid days. Your joints are looser in pregnancy, so warm up gently and avoid jerky movements.",
            "Stop and rest if you feel dizzy or unusually tired, or more out of breath than the effort explains, and tell your doctor or midwife before you exercise again. If you faint, or the dizziness does not pass when you sit down, see your doctor. Pain and swelling in one calf needs a doctor straight away.",
            "Some signs need care straight away. If you have bleeding from your vagina, regular painful tightenings, or fluid leaking from your vagina, contact your maternity unit straight away, whatever the colour of the fluid. If your baby moves less than usual, call your maternity unit straight away, day or night. For chest pain, or trouble breathing that does not ease with rest, call an emergency ambulance (115) straight away."
          ],
          "vi": [
            "Khi tập ở mức vừa phải, mẹ vẫn nói được trọn câu. Mẹ uống nước trước, trong và sau khi tập, và tránh để người quá nóng, nhất là vào hôm trời oi bức. Khi mang thai, các khớp lỏng hơn, nên mẹ khởi động nhẹ nhàng và tránh động tác giật mạnh.",
            "Mẹ hãy dừng lại nghỉ nếu thấy chóng mặt, mệt bất thường hoặc hụt hơi nhiều hơn mức gắng sức, và báo bác sĩ hoặc nữ hộ sinh trước khi tập lại. Nếu ngất, hoặc chóng mặt không đỡ khi đã ngồi xuống, mẹ hãy đi khám. Nếu một bên bắp chân đau và sưng, mẹ cần gặp bác sĩ ngay.",
            "Một số dấu hiệu cần được chăm sóc ngay. Nếu ra máu âm đạo, bụng gò đều và đau, hoặc ra nước âm đạo, mẹ hãy liên hệ khoa sản ngay, dù nước có màu gì. Nếu bé cử động ít hơn mọi ngày, mẹ hãy gọi ngay cho khoa sản, dù ngày hay đêm. Nếu đau ngực, hoặc khó thở mà nghỉ ngơi không đỡ, mẹ hãy gọi cấp cứu 115 ngay."
          ]
        }
      }
    ],
    "sources": [1, 3, 5]
  }
}
```
Its counts: en summary 28, words 393, 3 sections; vi summary 36, words 479, 3 sections. Note how it handles rules 3, 6 and 8: dizziness, fainting and calf pain each get a pointer matching the week warnings; bleeding, fluid leaking and regular painful tightenings go to the maternity unit straight away, whatever the colour; fewer movements go to the maternity unit straight away, day or night; chest pain or trouble breathing go to 115.

**Fact checklist — check-ups and birth** (dates must match the app's milestones: first check-up 6–8, nuchal scan and double test 11–14, triple test 15–18, anomaly scan 18–22, diabetes test 24–28, tetanus and whooping cough 27–36, growth scan 30–32, group B strep 35–37, weekly check-ups 37–40, care after the due date 40–42):

- **`antenatal-checkup-milestones`** (trimesters 1–3) — Sources `[0, 6, 9]`. Suggested sections: "Vì sao khám thai đều đặn" / "Why regular check-ups matter"; "Các mốc khám chính" / "The main milestones"; "Mỗi lần khám thường có gì" / "What usually happens at a visit".
  - Facts: WHO recommends at least eight antenatal contacts; clinics in Vietnam set their own schedule, so follow yours; the milestones listed above in words, by trimester; most visits check blood pressure, urine, weight, the height of the womb and, later, the baby's heartbeat; bring the pregnancy record book (sổ khám thai) and results; write questions down; the app's check-up list can hold the dates (say "the check-up list in the app" / "danh sách lịch khám trong ứng dụng").
  - Guideline figure: at least eight contacts (WHO 2016).
  - Avoid: a Vietnamese minimum number of visits (it varies; not confirmed).
- **`first-trimester-screening`** (trimester 1) — Sources `[0, 2, 6, 9]`. Suggested sections: "Xét nghiệm ở lần khám đầu" / "Tests at the first visit"; "Siêu âm độ mờ da gáy và double test" / "The nuchal scan and double test"; "Hiểu kết quả sàng lọc" / "Understanding screening results".
  - Facts: first-visit blood tests usually include blood group and Rh, anaemia, and infections such as hepatitis B, HIV and syphilis, plus a urine test; an early scan confirms the pregnancy and dates it; between weeks 11 and 14 a nuchal translucency scan with the double test can screen for some chromosomal conditions; screening gives a chance (higher or lower), not a diagnosis; a higher-chance result leads to a talk about further tests, and every choice is yours to make with the doctor; screening is optional.
  - Avoid: percentages or "1 in N" figures; naming specific conditions beyond "some chromosomal conditions" (e.g. Down syndrome may be named once as an example — mark it in the commit's added facts if used).
- **`anomaly-scan-glucose-test`** (trimester 2) — Sources `[0, 2, 6, 9]`. Suggested sections: "Siêu âm hình thái" / "The anomaly scan"; "Xét nghiệm tiểu đường thai kỳ" / "The gestational diabetes test"; "Khi cần theo dõi thêm" / "If more checks are needed".
  - Facts: anomaly scan around weeks 18–22 looks at the baby's organs, growth, the placenta's position and the fluid; a scan cannot find everything; the doctor explains any finding and the next step; the diabetes test around weeks 24–28: usually fasting, a sweet drink, and blood tests over about two hours, as the clinic explains; gestational diabetes is common, usually managed with food changes and activity, sometimes medicine (no names); it usually goes after birth, and a check afterwards is advised.
  - Avoid: the baby's sex; glucose gram figures; diagnostic thresholds.
- **`signs-of-labour`** (trimester 3) — Sources `[2, 5, 6]`. Suggested sections: "Dấu hiệu chuyển dạ" / "Signs that labour is starting"; "Cơn gò tập hay cơn gò thật" / "Practice or real contractions"; "Khi nào gọi khoa sản" / "When to call the maternity unit".
  - Facts: contractions that come regularly and become longer, stronger and closer together; a show (sticky mucus, which may be pink or streaked with blood); backache or period-like cramps; the waters breaking as a gush or a trickle; practice contractions are irregular and ease with rest or a change of position; your maternity unit tells you when to come in; keep its number and transport ready at any hour.
  - **Must match the week warnings exactly:** if your waters break, call the maternity unit straight away, whatever the colour of the fluid (vi: "dù nước ối trong, xanh hay nâu"); if the baby moves less than usual or the pattern changes, call straight away, day or night; any signs of labour before 37 weeks → go to the maternity unit straight away; heavy or bright red bleeding, or constant belly pain → go to hospital straight away.
  - Avoid: a contraction-timing rule such as "5-1-1" (units differ); "go to sleep and see".
- **`hospital-bag`** (trimester 3) — Sources `[2, 5, 9]`. Suggested sections: "Khi nào chuẩn bị" / "When to pack"; "Đồ cho mẹ" / "For you"; "Đồ cho bé và giấy tờ" / "For your baby, and documents".
  - Facts: start around week 33 and have the bag ready by about week 36 (matches weeks 33 and 36); documents: căn cước, thẻ bảo hiểm y tế, sổ khám thai, test results; for the mother: loose clothes, front-opening tops or nursing bras, maternity pads, underwear, slippers, toiletries, a phone charger, snacks and water for labour; for the baby: clothes, a hat, tất (socks), bỉm or tã (nappies), a swaddling cloth, a car seat if travelling by car; keep the maternity unit's number and a transport plan.
  - Avoid: brand names; medicines.
- **`birth-plan-breastfeeding`** (trimester 3) — Sources `[0, 2, 8]`. Suggested sections: "Kế hoạch sinh" / "Your birth plan"; "Những giờ đầu sau sinh" / "The first hours after birth"; "Bắt đầu cho con bú" / "Starting to breastfeed".
  - Facts: a birth plan lists your wishes: who will be with you, positions, ways to cope with pain to discuss with the doctor (no drug names), skin-to-skin, waiting at least a minute before clamping the cord when possible; plans can change, and the care team explains why; WHO advises starting breastfeeding within the first hour, feeding often, and breast milk alone for the first 6 months; colostrum is the first milk; ask the midwife for help with positioning and latch; if breastfeeding is hard or not possible, support is there and the baby can still be fed well.
  - Guideline figures (listed for the doctor): breastfeeding within the first hour; exclusive breastfeeding for 6 months; cord clamping after at least 1 minute (WHO).
  - Avoid: guilt or pressure wording; formula brand names.

- [ ] **Step 1: Read for consistency.** Read the milestones (`python3 -c "import json;[print(m['id'],m['fromWeek'],m['toWeek'],m['title']['vi']) for m in json.load(open('Packages/KickCore/Sources/KickCore/Resources/pregnancy-content.json'))['milestones']]"`) and the week articles for weeks 11, 18, 24, 33, 34, 36, 37, 39 with the command from Task 3 Step 1, and week 37's `warnings`.

- [ ] **Step 2: Write the three check-up articles** (`"antenatal-checkup-milestones"`, `"first-trimester-screening"`, `"anomaly-scan-glucose-test"`):
```bash
scripts/set-knowledge-articles.py <<'JSON'
{ "antenatal-checkup-milestones": { … }, "first-trimester-screening": { … }, "anomaly-scan-glucose-test": { … } }
JSON
```
(Replace each `{ … }` with the full article.) Expected: six count lines, all in range.

- [ ] **Step 3: Write the three birth articles** (`"signs-of-labour"`, `"hospital-bag"`, `"birth-plan-breastfeeding"`), the same way. Expected: six count lines, all in range.

- [ ] **Step 4: Require every article and run the checks**

In `Packages/KickCore/Tests/KickCoreTests/BundledKnowledgeTests.swift`, replace:
```swift
    /// Articles that must already be written. Each task widens it:
    /// [] (Task 1) → safe-exercise (Task 2) → + nutrition and movement (Task 3)
    /// → + sleep and feelings (Task 4) → KnowledgeChecks.articleIDs (Task 5).
    static let requiredArticleIDs: Set<String> = [
        "nutrition-first-trimester", "food-safety", "iron-calcium-balanced-meals",
        "safe-exercise", "gentle-exercise-second-trimester", "pelvic-floor-posture",
        "first-trimester-tiredness", "sleep-positions", "sleeping-well-late-pregnancy",
        "early-pregnancy-worries", "changing-body-feelings", "preparing-for-motherhood",
    ]
```
with:
```swift
    /// Every article of spec §3.1 must be written (spec §3.5); trimester coverage is checked too.
    static let requiredArticleIDs: Set<String> = KnowledgeChecks.articleIDs
```
Run: `scripts/test-core.sh`
Expected: PASS, `Test run with 472 tests`. Then confirm all 18 are there, in order, and none is reviewed:
```bash
python3 -c "import json;d=json.load(open('Packages/KickCore/Sources/KickCore/Resources/knowledge-content.json'));print(len(d['articles']),[a['id'] for a in d['articles'] if a['reviewed']])"
```
Expected: `18 []`.

- [ ] **Step 5: The library test opens `signs-of-labour`**

In `UITests/KnowledgeUITests.swift`, replace:
```swift
        // Task 5 checks signs-of-labour here; until then safe-exercise is the trimester-3 article.
        let row = app.buttons["knowledgeArticle-safe-exercise"]
```
with:
```swift
        let row = app.buttons["knowledgeArticle-signs-of-labour"]
```

- [ ] **Step 6: Accuracy and tone review**

As Task 3 Step 6, for the six new articles, plus:
- Every date matches the milestones listed above; the hospital-bag timing matches weeks 33 and 36.
- `signs-of-labour` says, in both languages: waters → maternity unit straight away whatever the colour; fewer movements → straight away, day or night; signs before 37 weeks → maternity unit straight away; heavy bleeding or constant pain → hospital straight away.
- Screening is described as a chance, never a diagnosis; no percentages.
Then skim all 18 summaries in order (`python3 -c "import json;[print(a['id'],'|',a['summary']['vi']) for a in json.load(open('Packages/KickCore/Sources/KickCore/Resources/knowledge-content.json'))['articles']]"`): no two summaries in a topic start the same way. Fix and rerun Step 4.

- [ ] **Step 7: Commit, push, verify CI**

```bash
scripts/test-core.sh
git add Packages/KickCore UITests/KnowledgeUITests.swift
git commit -F - <<'MSG'
content: knowledge articles on check-ups and birth

Original Vietnamese and English articles on antenatal check-ups,
first-trimester screening, the anomaly scan and diabetes test, signs of
labour, the hospital bag and the birth plan with breastfeeding. The
signs of labour match the week warnings: waters breaking or fewer
movements mean calling straight away. All 18 articles are now required
and every trimester has at least three; all stay unreviewed.

Added beyond the checklist:
- <one fact per line, with its article id>

CI-Only-Testing: KnowledgeUITests, KnowledgeScreenshotTests
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`, including `testSeeMoreOpensTheLibraryOnTheCurrentTrimester` opening `signs-of-labour`.

- [ ] **Step 8: Visual check**

- `knowledge-card-vi-light`, `knowledge-card-en-dark`: three rows from three topics (at week 24: feelings, check-ups, nutrition).
- `knowledge-library-vi-light`: trimester 2 lists Dinh dưỡng, Vận động, Giấc ngủ & nghỉ ngơi, Cảm xúc, Khám thai & xét nghiệm (no "Chuẩn bị sinh": no birth article is in trimester 2).
- `knowledge-reading-*`: unchanged (still safe-exercise).

---
### Task 6: Docs — doctor review §10, README, release checklist; full CI

Records the 18 articles for the obstetrician (spec §6), documents the new code and script, and adds the phase to the release checklist (no CloudKit change: content is bundled). The commit has **no** `CI-Only-Testing:` line, so CI runs every UI test class.

**Files:**
- Modify: `docs/content-review-for-doctor.md` (new §10 at the end), `README.md` (new section at the end), `docs/release-checklist.md` (screenshot line; new phase 7 section at the end)

**Interfaces:**
- Consumes: the strings and identifiers of Task 2, the script of Task 1, the screenshot names of Task 2, the articles and commit bodies of Tasks 2–5.
- Produces: documentation only.

- [ ] **Step 1: Collect the added facts**

```bash
git log --format='%h %s%n%b' main..HEAD -- Packages/KickCore/Sources/KickCore/Resources/knowledge-content.json | sed -n '/^[0-9a-f]\{7,\} content:/,/^CI-Only-Testing:/p'
```
Copy every line of the `Added beyond the checklist:` blocks (skip `none`). Translate each into Vietnamese for the doctor, grouped by article.

- [ ] **Step 2: Doctor review §10**

Append at the end of `docs/content-review-for-doctor.md` (replace the two `<…>` lines with the facts from Step 1, one sub-checkbox per fact, under the right article; delete an article's line if it has none):
```markdown

## 10. Bài viết chuyên sâu theo tam cá nguyệt (giai đoạn 7)

Mục "Kiến thức" gồm 18 bài viết chuyên sâu trong 6 chủ đề, gắn với tam cá nguyệt. Màn Hôm nay (chế độ mang thai)
có thẻ "Gợi ý cho tam cá nguyệt N" với 3 bài và nút "Xem thêm" mở thư viện. Bài viết mới hoàn toàn, song ngữ
vi/en, nằm trong `Packages/KickCore/Sources/KickCore/Resources/knowledge-content.json`; mọi bài vẫn
`"reviewed": false`, nên bản App Store chưa hiện thẻ lẫn thư viện. Xem trên ảnh chụp `knowledge-*` trong
`ci-artifacts/screenshots/` của lần CI gần nhất, hoặc trong bản TestFlight (thư viện hiện tất cả bài).

**Nguyên tắc viết** (như mục 9, thêm):
- Mỗi bài 300–500 chữ mỗi ngôn ngữ (tóm tắt + tiêu đề mục + đoạn văn), 2–4 mục; câu tóm tắt tối đa 35 từ (en) /
  45 âm tiết (vi). Kiểm tra tự động, cùng việc không có đơn vị inch/pound/ounce và không có liều thuốc.
- Được nêu con số theo hướng dẫn y tế công cộng (danh sách ở mục 41).
- Bài về cảm xúc luôn có câu: nếu buồn chán hoặc lo âu gần như mỗi ngày, kéo dài từ hai tuần trở lên, mẹ hãy nói
  với bác sĩ hoặc nữ hộ sinh, hoặc người thân.
- Bài "Dấu hiệu chuyển dạ" khớp mục cảnh báo của từng tuần: vỡ ối thì gọi khoa sản ngay, dù nước ối màu gì; bé cử
  động ít đi thì gọi ngay, dù ngày hay đêm.
- Tuần luôn tính theo số tuần tròn đã qua (như màn Hôm nay); tiếng Việt dùng từ miền Bắc.

40. [ ] **Duyệt từng bài** (đúng dữ kiện, đúng tam cá nguyệt, giọng văn, khớp với bài viết theo tuần):
    - [ ] Dinh dưỡng — `nutrition-first-trimester`: Ăn uống trong tam cá nguyệt đầu
    - [ ] Dinh dưỡng — `food-safety`: An toàn thực phẩm
    - [ ] Dinh dưỡng — `iron-calcium-balanced-meals`: Sắt, canxi và bữa ăn cân đối
    - [ ] Vận động — `safe-exercise`: Vận động an toàn khi mang thai
    - [ ] Vận động — `gentle-exercise-second-trimester`: Tập nhẹ nhàng ở tam cá nguyệt hai
    - [ ] Vận động — `pelvic-floor-posture`: Cơ sàn chậu và tư thế
    - [ ] Giấc ngủ — `first-trimester-tiredness`: Mệt mỏi ở tam cá nguyệt đầu
    - [ ] Giấc ngủ — `sleep-positions`: Tư thế ngủ
    - [ ] Giấc ngủ — `sleeping-well-late-pregnancy`: Ngủ ngon những tháng cuối
    - [ ] Cảm xúc — `early-pregnancy-worries`: Lo lắng những tuần đầu
    - [ ] Cảm xúc — `changing-body-feelings`: Cơ thể thay đổi và cảm xúc
    - [ ] Cảm xúc — `preparing-for-motherhood`: Chuẩn bị làm mẹ
    - [ ] Khám thai — `antenatal-checkup-milestones`: Các mốc khám thai
    - [ ] Khám thai — `first-trimester-screening`: Sàng lọc tam cá nguyệt đầu
    - [ ] Khám thai — `anomaly-scan-glucose-test`: Siêu âm hình thái và xét nghiệm tiểu đường thai kỳ
    - [ ] Chuẩn bị sinh — `signs-of-labour`: Dấu hiệu chuyển dạ
    - [ ] Chuẩn bị sinh — `hospital-bag`: Túi đồ đi sinh
    - [ ] Chuẩn bị sinh — `birth-plan-breastfeeding`: Kế hoạch sinh và cho con bú
41. [ ] **Con số theo hướng dẫn** — xác nhận từng con số và nguồn:
    - [ ] Vận động vừa sức khoảng 150 phút mỗi tuần; những lần tập ngắn khoảng 10 phút cũng được tính (WHO 2020,
          ACOG CO 804) — `safe-exercise`, `gentle-exercise-second-trimester`.
    - [ ] Caffeine dưới 200 mg mỗi ngày (ACOG CO 462, NHS) — câu cố định trong `food-safety`: "Phần lớn các hướng
          dẫn khuyên mẹ giữ tổng lượng caffeine dưới 200 mg mỗi ngày, tính cả cà phê, trà, nước cola, nước tăng lực
          và sô-cô-la." Đây là câu duy nhất được phép có đơn vị mg.
    - [ ] Nằm nghiêng khi đi ngủ từ khoảng tuần 28 (NICE NG201, NHS) — `sleep-positions`.
    - [ ] "Baby blues" thường hết trong khoảng hai tuần (NICE CG192, NHS) — `preparing-for-motherhood`.
    - [ ] Buồn chán hoặc lo âu gần như mỗi ngày từ hai tuần trở lên thì nói với bác sĩ hoặc nữ hộ sinh — các bài
          cảm xúc.
    - [ ] Ít nhất 8 lần tiếp xúc chăm sóc trước sinh (WHO 2016) — `antenatal-checkup-milestones`.
    - [ ] Các mốc: đo độ mờ da gáy và double test tuần 11–14; siêu âm hình thái tuần 18–22; xét nghiệm tiểu đường
          thai kỳ tuần 24–28 (khớp lịch khám gợi ý ở mục 4).
    - [ ] Chuẩn bị túi đồ đi sinh từ khoảng tuần 33, xong trước khoảng tuần 36.
    - [ ] Cho con bú trong giờ đầu sau sinh; chỉ bú mẹ hoàn toàn trong 6 tháng đầu; kẹp dây rốn sau ít nhất 1 phút
          khi có thể (WHO, WHO/UNICEF 2018) — `birth-plan-breastfeeding`.
42. [ ] **Câu hỏi:** bài `early-pregnancy-worries` có câu "nếu có ý nghĩ làm hại bản thân, hãy nói với người mẹ tin
        tưởng và tìm trợ giúp ngay: gọi 115 hoặc đến bệnh viện gần nhất". Bác sĩ có muốn thêm một đường dây hỗ trợ
        tâm lý cụ thể ở Việt Nam không?
43. [ ] **Câu hỏi:** bài `antenatal-checkup-milestones` nêu khuyến cáo "ít nhất 8 lần" của WHO và viết "lịch khám do
        cơ sở y tế của mẹ đặt". Có cần nêu số lần khám tối thiểu theo hướng dẫn của Bộ Y tế không?
44. [ ] **Danh sách nguồn** (`sources` trong `knowledge-content.json`, 10 mục: WHO 2016, WHO 2020, ACOG, ACOG CO 804,
        ACOG CO 462, NHS, NICE NG201, NICE CG192, WHO/UNICEF 2018, Bộ Y tế) — xác nhận phù hợp.
45. [ ] **Dữ kiện tác giả thêm ngoài danh sách kiểm** (từ các commit nội dung của giai đoạn 7) — xin bác sĩ xác nhận:
    - [ ] <mã bài>: <dữ kiện>
    - [ ] <mã bài>: <dữ kiện>
- [ ] Khi bác sĩ duyệt xong một bài: đổi `"reviewed": true` cho bài đó trong `knowledge-content.json` và xóa kiểm tra
      `reviewed` trong `KnowledgeChecks` (hoặc chỉ cho phép các bài đã duyệt). Bài đã duyệt sẽ hiện ở bản App Store;
      thẻ ở Hôm nay hiện khi có ít nhất một bài đã duyệt cho tam cá nguyệt đó.
```
Check that the article titles in item 40 match the actual vi titles in the JSON (`python3 -c "import json;[print(a['id'],'|',a['title']['vi']) for a in json.load(open('Packages/KickCore/Sources/KickCore/Resources/knowledge-content.json'))['articles']]"`); copy the real titles where they differ. Add any guideline figure from Step 1 that item 41 does not list yet. Make sure no `<…>` placeholder is left: `grep -n "<mã bài>\|<dữ kiện>" docs/content-review-for-doctor.md` prints nothing.

- [ ] **Step 3: README**

Append at the end of `README.md`:
```markdown

## Kiến thức chuyên sâu (giai đoạn 7)
- 18 bài viết trong 6 chủ đề, gắn tam cá nguyệt: `Packages/KickCore/Sources/KickCore/Resources/knowledge-content.json`
  (phiên bản 1; mô hình `KickCore/KnowledgeContent.swift`, nạp bằng `KnowledgeLibrary`, lỗi thì ẩn thẻ và thư viện).
- Hôm nay (mang thai): thẻ "Gợi ý cho tam cá nguyệt N" (`App/Knowledge/KnowledgeCard.swift`), 3 bài chọn bởi
  `KickCore/KnowledgeSuggester.swift` (cùng tuần cùng kết quả, tuần sau đổi bài đầu, ưu tiên mỗi chủ đề một bài).
- Thư viện "Kiến thức" (`KnowledgeLibraryView`) và màn đọc (`KnowledgeArticleView`, dùng `ArticleSheet` hai nấc).
  Phần chữ dùng chung với Chi tiết tuần: `App/DesignSystem/ArticleText.swift`.
- Thêm hoặc sửa bài: `scripts/set-knowledge-articles.py` (JSON qua stdin, xem đầu file; in số chữ). Kiểm tra tự
  động: `scripts/test-core.sh --filter "BundledKnowledgeTests|KnowledgeChecksTests"`.
- Ảnh riêng từng bài (chưa có): thêm asset `Knowledge-<id>` (ví dụ `Knowledge-safe-exercise`) vào
  `App/Images.xcassets`; khi thiếu, app vẽ biểu tượng SF Symbol của chủ đề.
- Nội dung chờ bác sĩ duyệt: `docs/content-review-for-doctor.md` mục 10. Bản App Store chỉ hiện bài đã duyệt.
```

- [ ] **Step 4: Release checklist**

In `docs/release-checklist.md`, replace:
```markdown
- [ ] Ảnh chụp App Store mới cho tab Thai kỳ (vi + en): `ci-artifacts/screenshots/pregnancy-home-24-*`, `week-article-*` (thay `week-24-*` từ giai đoạn 6), `appointments-*`.
```
with:
```markdown
- [ ] Ảnh chụp App Store mới cho tab Thai kỳ (vi + en): `ci-artifacts/screenshots/pregnancy-home-24-*`, `week-article-*` (thay `week-24-*` từ giai đoạn 6), `knowledge-*` (giai đoạn 7, khi đã có bài được duyệt), `appointments-*`.
```

Append at the end of the file:
```markdown

## Giai đoạn 7 — Kiến thức chuyên sâu

### Trước khi gửi App Store
- [ ] Không thay đổi CloudKit: bài viết nằm trong `knowledge-content.json` đóng gói cùng app (phiên bản 1).
- [ ] Bác sĩ đã duyệt các bài — mục 10 của [`docs/content-review-for-doctor.md`](content-review-for-doctor.md).
      Bài chưa duyệt bị ẩn ở bản App Store; khi chưa có bài nào được duyệt, thẻ ở Hôm nay và thư viện không hiện.
- [ ] Đủ 18 bài và chưa bài nào tự đánh dấu duyệt — lệnh sau in ra `18`:
      `python3 -c "import json;print(len(json.load(open('Packages/KickCore/Sources/KickCore/Resources/knowledge-content.json'))['articles']))"`
- [ ] Ảnh chụp App Store (khi có bài được duyệt): `knowledge-card-vi-light`, `knowledge-library-vi-light`,
      `knowledge-reading-peek-vi-light`, `knowledge-*-en-dark`.
- [ ] Ghi chú phát hành: mục Kiến thức mới — bài viết chuyên sâu theo tam cá nguyệt, gợi ý ngay ở màn Hôm nay.

### Kiểm thử thủ công trên iPhone qua TestFlight (vi và en)
- [ ] Hôm nay (mang thai, có ngày dự sinh): cuối màn có thẻ "Gợi ý cho tam cá nguyệt N" với 3 bài; ngày hôm sau
      vẫn 3 bài đó, tuần sau bài đầu tiên đổi.
- [ ] Chạm một bài: màn đọc mở ở nấc thấp, thấy ảnh/biểu tượng chủ đề, tiêu đề, dòng "Người xem xét" và câu tóm tắt;
      kéo tay nắm lên/xuống như Chi tiết tuần; ✕ đóng màn đọc.
- [ ] "Xem thêm": thư viện "Kiến thức" mở đúng tam cá nguyệt hiện tại; đổi chip 1/2/3 thì danh sách đổi theo chủ đề.
- [ ] Đang kéo sheet thì vuốt về màn hình chính hoặc có cuộc gọi đến: mở lại app, sheet nằm đúng một nấc, không
      treo lưng chừng (sửa lỗi kéo bị hủy).
- [ ] Chế độ Mong con: không có thẻ Kiến thức.
- [ ] VoiceOver: màn đọc mở thẳng nấc cao; ✕ được đọc trước; tiêu đề mục đọc là "tiêu đề".
- [ ] Dynamic Type lớn nhất: thẻ, thư viện và màn đọc không cắt chữ (tóm tắt ở thẻ tối đa 2 dòng); màn đọc mở nấc cao.
- [ ] Reduce Motion bật: sheet chuyển nấc tức thì; ảnh nền chỉ mờ đi.
```

- [ ] **Step 5: Final local checks, commit, push, full CI**

```bash
scripts/test-core.sh
xcodegen generate --quiet
xcodebuild -project KickCounter.xcodeproj -scheme KickCounter \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO -quiet build-for-testing
git add README.md docs/content-review-for-doctor.md docs/release-checklist.md
git commit -F - <<'MSG'
docs: knowledge articles for the doctor review, README and release checklist

Section 10 of the doctor review lists the 18 knowledge articles, the
public-health figures they quote, the facts added beyond the brief and
two open questions. The README explains the card, the library, the
reading screen and set-knowledge-articles.py; the release checklist
adds the phase 7 checks.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `Test run with 472 tests`; `xcodebuild` exits 0; CI log shows `==> UI tests: full suite`; `CI PASSED`, including classes no task scoped (`KickCounterUITests`, `ScreenshotTests`, `HistoryUITests`, `KicksUITests`, `OnboardingUITests`, `NavigationUITests`, `CycleUITests`, `CycleTodayUITests`, `WeightUITests`, `PregnancySymptomsUITests`, …).

- [ ] **Step 6: Final visual pass and hand-off**

Open every `knowledge-*`, `week-article-*` and `pregnancy-home-*` PNG from this run with the Read tool and recheck the Task 2 list (now with three suggestions and every topic in the library). Do not trigger TestFlight; tell the user they can run `gh workflow run testflight.yml --ref feat/knowledge` and follow "Giai đoạn 7" in the release checklist. Then use `superpowers:finishing-a-development-branch` to open the PR `feat/knowledge` → `main` (run `scripts/test-core.sh` before pushing, as the pre-push hook does).

---
## Self-review

**Spec coverage** (spec section → task):
- §1 goal, three entry points → Task 2 (card, library, reading screen); §2 decisions: placement (card last on Today, tab bar untouched), pregnancy only (`testTryingToConceiveHasNoKnowledgeCard`), 18 articles in 6 topics (catalogue, Tasks 2–5), approach A (artwork + `ArticleSheet`), out-of-scope items not built.
- §3.1 topics, ids, trimesters, 7/9/11 → `KnowledgeChecks.catalogue` + `catalogueMatchesTheSpec` (Task 1), content Tasks 2–5.
- §3.2 model, loader nil path, visibility → `KnowledgeContent.swift`, `KnowledgeLibrary.swift`, `KnowledgeLibraryTests` (Task 1); environment + hiding (Task 2).
- §3.3 suggester rules and edge cases → `KnowledgeSuggester` + 8 tests (Task 1).
- §3.4 writing guide and differences → the guide block in Tasks 3–5, `safe-exercise` (Task 2), checks (Task 1).
- §3.5 content checks, widening completeness → `KnowledgeChecks`, `KnowledgeChecksTests`, `BundledKnowledgeTests.requiredArticleIDs` ([] → 1 → 6 → 12 → 18).
- §4.1 card (title, rows, identifiers, pill, placement, hidden cases) → Task 2 Steps 6–7.
- §4.2 library (title, chips, default trimester, sections, row identifiers) → `KnowledgeLibraryView`, Task 2.
- §4.3 reading screen (cover, gradient, ✕ treatment, artwork fallback, header, body, detents, AX/VoiceOver, Reduce Motion, `-uiTesting`, `ArticleText` extraction) → Task 2 Steps 5–6.
- §5 KickCore tests → Task 1; UI tests → `KnowledgeUITests` (Task 2, tightened in Tasks 3 and 5); screenshots → `KnowledgeScreenshotTests` (card; library vi light + en dark; reading peek + expanded; library and reading at AX5); scoped trailers per task, full suite in Task 6.
- §6 delivery 1–6 → Tasks 1–6 one to one (`safe-exercise` in Task 2; second look in Task 3; all required in Task 5; docs + full CI in Task 6).
- Phase 6 lessons: header Buttons (none in the reading header; Global Constraints), cancelled drags (Task 1 Steps 11–13), ✕ treatment and expanded-at-AX/VoiceOver (`ArticleCloseButton`, `onAppear`), review-round content rules (guide block), CI-only UI tests with trailers, `scrollUntilHittable` and `.combine`/`.contain` before identifiers (tests and views).

**Placeholder scan:** the only `{ … }` and `<…>` markers are the prose the content tasks write (each with a full example and a script that rejects incomplete input) and the commit-body fact lines, each with an explicit instruction and a `grep` that proves none is left in the docs.

**Type consistency:** `KnowledgeLibrary.suggestions(forWeek:visibility:count:)`, `sections(trimester:visibility:)`, `references(for:)`, `KnowledgeTopicSection.topic/articles`, `KnowledgeSelection(id:)`, `KnowledgeRows(articles:topics:language:identifierPrefix:onSelect:)`, `KnowledgeCard(trimester:suggestions:topics:language:onSeeMore:)`, `KnowledgeLibraryView(initialTrimester:)`, `KnowledgeArticleView(articleID:)`, `ArticleReferences(sources:identifier:)`, `ArticleReviewerRow(pendingReview:reviewedText:identifier:)`, `ArticleCloseButton(identifier:action:)`, `PregnancyRoute.knowledge(trimester:)` and `BundledKnowledgeTests.requiredArticleIDs: Set<String>` are spelled the same in every task. Every Swift file in this plan was compiled in a scratch copy of the repository: `scripts/test-core.sh` passed with 472 tests and `xcodebuild build-for-testing` exited 0 after Task 1 and after Task 2. The UI tests compiled; they run only on CI.
