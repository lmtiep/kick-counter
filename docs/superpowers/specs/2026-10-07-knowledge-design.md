# Knowledge: in-depth articles by trimester (Phase 7)

Date: 2026-10-07 · Status: approved in conversation · Branch: `feat/knowledge`

## 1. Goal

Pregnancy mode gets a small library of in-depth articles, grouped by topic and tagged by trimester. It has three entry points:
- a suggestion card on Today;
- a library screen;
- a reading screen that reuses Phase 6's `ArticleSheet`.

The articles are original and bilingual (vi and en). They stay unreviewed until the doctor signs them off.

## 2. Decisions made with the user

| Topic | Decision |
|---|---|
| Placement | A card on Today ("Gợi ý cho tam cá nguyệt N", 3 articles, "Xem thêm") plus a library screen. The tab bar is unchanged |
| Mode | Pregnancy only. Trying-to-conceive mode shows nothing new |
| Size | 18 articles in 6 topics, 3 per topic |
| Reading screen | Approach A: the topic artwork as background, with the two-detent `ArticleSheet` on top |
| Out of scope | Read/unread state, bookmarks, search, trying-to-conceive content, artwork itself |

## 3. Content

### 3.1 Topics and articles

Each article has a stable `id` (kebab-case) and the trimesters it applies to.

| Topic `id` | vi / en name | Articles (trimesters) |
|---|---|---|
| `nutrition` | Dinh dưỡng / Nutrition | `nutrition-first-trimester` (1) · `food-safety` (1,2,3) · `iron-calcium-balanced-meals` (2,3) |
| `movement` | Vận động / Movement | `safe-exercise` (1,2,3) · `gentle-exercise-second-trimester` (2) · `pelvic-floor-posture` (2,3) |
| `sleep` | Giấc ngủ & nghỉ ngơi / Sleep & rest | `first-trimester-tiredness` (1) · `sleep-positions` (2,3) · `sleeping-well-late-pregnancy` (3) |
| `feelings` | Cảm xúc / Feelings | `early-pregnancy-worries` (1) · `changing-body-feelings` (2) · `preparing-for-motherhood` (3) |
| `checkups` | Khám thai & xét nghiệm / Check-ups & tests | `antenatal-checkup-milestones` (1,2,3) · `first-trimester-screening` (1) · `anomaly-scan-glucose-test` (2) |
| `birth` | Chuẩn bị sinh / Getting ready for birth | `signs-of-labour` (3) · `hospital-bag` (3) · `birth-plan-breastfeeding` (3) |

This gives 7 articles that apply in trimester 1, 9 in trimester 2 and 11 in trimester 3.

### 3.2 Data model (KickCore, bundled `knowledge-content.json`, version 1)

```swift
public struct KnowledgeContent: Codable, Equatable, Sendable {
    public var version: Int
    public var sources: [String]              // full citations; articles refer by index
    public var topics: [KnowledgeTopic]       // display order
    public var articles: [KnowledgeArticle]
}
public struct KnowledgeTopic: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: LocalizedText
    public var symbol: String                 // SF Symbol name, the artwork fallback
}
public struct KnowledgeArticle: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var topic: String                  // KnowledgeTopic.id
    public var trimesters: [Int]              // subset of 1...3, non-empty, ascending
    public var reviewed: Bool                 // false until the doctor signs off
    public var title: LocalizedText
    public var summary: LocalizedText         // one sentence: the card subtitle and the bold lead
    public var sections: [KnowledgeSection]   // 2–4
    public var sources: [Int]                 // ≥ 1, valid indices
}
public struct KnowledgeSection: Codable, Equatable, Sendable {
    public var heading: LocalizedText
    public var paragraphs: LocalizedParagraphs   // reuses Phase 6's type
}
```

**Loader.** `KnowledgeLibrary` loads the bundle in the same way as `WeeklyContentLibrary+Bundle`. If the file is missing or invalid, it logs the problem and returns nil, and the card and library are hidden. The app does not crash.

**Visibility.** `KnowledgeLibrary.articles(visibility:)` drops unreviewed articles when the visibility is `.reviewedOnly`. It uses the existing `ContentVisibility` and `BuildFlags.contentVisibility`. In current release builds no article is reviewed yet, so release builds show neither the card nor the library.

### 3.3 Suggestions

`KnowledgeSuggester.suggestions(for week: Int, from: [KnowledgeArticle], count: 3) -> [KnowledgeArticle]` is a pure KickCore function:
- **Filter:** keep only articles whose `trimesters` contain `Trimester(week:)`. Weeks below 4 and above 42 are clamped first, using the existing `Trimester` rules.
- **Group:** group the eligible articles by topic. Topics are in display order (unknown topics last); the articles inside a topic are sorted by id.
- **Rotate:** rotate the topic list left by `week % topicCount`, so each week starts one topic later.
- **Pick:** take one article from each of the first 3 topics. Inside a topic, take the article at index `(week / topicCount) % articlesInTopic`, so each topic cycles through its articles every `topicCount` weeks. If fewer than 3 topics are eligible, fill the remaining slots with each topic's next article (index + 1, then + 2, …), topics in rotated order.
- **Fairness:** every eligible article is suggested in some week of its trimester, and no article appears in more than 65% of its trimester's weeks. Three of five topics are picked each week in trimesters 1 and 2, so a topic with a single article is suggested in about 60% of those weeks; that is the floor. `BundledKnowledgeSuggestionTests` checks this on the shipped content.
- **Result:** the same week always gives the same 3 articles, and the next week gives a different first article. The clamped week drives both the trimester filter and the rotation. If fewer than 3 articles are eligible, return all of them. If none are, return an empty list and the card is hidden.

### 3.4 Writing guide

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

### 3.5 Content checks (KickCore tests on the bundled JSON)

- There are exactly the 6 topics and 18 article ids from §3.1. Every `topic` reference is valid.
- `trimesters` is non-empty, within 1...3, and ascending. Each trimester has at least 3 articles.
- Every article has 2–4 sections and 300–500 words per language. Every `summary` is at most 35 words (en) or 45 (vi). No text is blank.
- Source indices are valid and non-empty.
- No imperial units, using the same regex as `WeekArticleChecks`. No medicine dose units (`mg`, `mcg`, `µg`, `IU`) except inside a sentence on the allow-list for caffeine.
- Every vi string contains Vietnamese diacritics.
- Every `reviewed` is false.

While the content tasks are under way, the completeness requirement widens step by step (see §6). Every article that exists is always checked in full.

## 4. Screens

### 4.1 Today card (pregnancy Today only)

- **Title:** `knowledge.card.title(N)` = "Gợi ý cho tam cá nguyệt N" / "Suggested for trimester N".
- **Rows:** 3 rows. Each row shows the topic symbol in a tinted circle (Luna tokens), the title, and a summary limited to 2 lines. Each row is a button with identifier `knowledgeSuggestion-<id>`.
- **Button:** a "Xem thêm" / "See more" pill (`knowledgeSeeMore`) that pushes the library.
- **Placement:** the card goes below the existing pregnancy cards. Its identifier is `knowledgeCard`.
- **Hidden** when there are no suggestions, no due date is set, or the library failed to load.

### 4.2 Library

- **Navigation title:** "Kiến thức" / "Knowledge".
- **Trimester chips:** a `ChipScroller` with 1 / 2 / 3. The default is the current trimester, or 1 when there is no due date. Identifiers are `knowledgeTrimester-1…3`.
- **List:** sections by topic in display order, showing only topics that have articles for the selected trimester. The rows look the same as on the card. Identifiers are `knowledgeArticle-<id>`.

### 4.3 Reading screen

The reading screen opens as a full-screen cover. It follows the Phase 6 `WeekDetailView` structure:
- **Background:** the hero gradient. The ✕ button (`knowledgeClose`) uses the Phase 6 treatment: opaque card circle, hairline border, sort priority 1. The artwork comes from `KnowledgeArtwork.image(articleID)`: the asset `Knowledge-<id>` if it exists, otherwise the topic SF Symbol at 96 pt in `pregOnSoft` on a soft circle. There are no week chips.
- **Sheet:** `ArticleSheet`. Its header holds the handle, the title (`knowledgeTitle`) and the existing pending-review row. Its body holds the bold summary (`knowledgeSummary`), the sections with `.isHeader` headings, and a collapsed references group (`knowledgeReferences`).
- **Detents:** the sheet opens at peek. It opens expanded when the Dynamic Type size is accessibility1 or larger, or when VoiceOver is on (Phase 6 rules). Reduce Motion and `-uiTesting` gating are inherited.

Shared reading pieces are extracted from `WeekArticleView` into a small `ArticleText` set: paragraph, heading and references views. Both screens then use the same typography, and `WeekArticleView` keeps its exact output.

## 5. Testing

- **KickCore:**
  - decoding;
  - the loader's failure path;
  - visibility filtering;
  - `KnowledgeSuggester` cases: trimester filter, the same 3 for the same week, rotation between weeks, topic spread, each topic cycling through its articles, fewer than 3 eligible, none eligible, and fairness on the shipped content (every article suggested, none in more than 65% of its trimester's weeks);
  - the content checks in §3.5.
- **UI tests** (`KnowledgeUITests`), seeded at week 24 (pinned due date) with `-uiTesting` (content visibility `.all`):
  - Today shows the card with 3 suggestions;
  - tapping one opens the reading screen at peek; the handle expands it; ✕ closes it;
  - "See more" opens the library with the trimester-2 chip selected; tapping trimester 3 shows `signs-of-labour`;
  - in trying-to-conceive mode there is no `knowledgeCard`.
- **Screenshots** (`KnowledgeScreenshotTests`):
  - the card;
  - the library in vi light and en dark;
  - the reading screen at peek and expanded;
  - the library and the reading screen at AX5.
- **Scoped CI trailers per task.** The docs task runs the full suite.

## 6. Delivery

1. **KickCore:** the model, loader, visibility, suggester, checks with widening completeness (`requiredArticleIDs` starts empty), and `scripts/set-knowledge-articles.py`, which writes articles and prints word counts. The JSON starts with the 6 topics, the sources and no articles.
2. **UI:** the `ArticleText` extraction, the Today card, the library, the reading screen, strings, UI tests and screenshots. It includes one fully written article, `safe-exercise`, so the UI has real content.
3. **Content:** the `nutrition` and `movement` articles, including a second look at `safe-exercise`.
4. **Content:** the `sleep` and `feelings` articles.
5. **Content:** the `checkups` and `birth` articles. All 18 become required.
6. **Docs:**
   - `content-review-for-doctor.md` §10: a per-article checklist, the guideline figures, and the facts added beyond the brief, to be confirmed;
   - README;
   - the release checklist. Content is bundled, so there is no CloudKit change.

   This task runs the full CI suite.
