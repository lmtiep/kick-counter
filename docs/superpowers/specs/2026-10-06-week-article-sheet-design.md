# Week detail: article sheet and rewritten weekly content (Phase 6)

Date: 2026-10-06 · Status: approved in conversation · Branch: `feat/week-article-sheet`

## 1. Goal

The current Week detail (`App/Pregnancy/WeekDetailView.swift`) puts everything on one scroll page:
- the fetus image,
- the week chips,
- one panel holding about six short bullet lists.

Two things change:

1. **Layout.** The fetus image and week chips become a fixed background. A draggable **article sheet** sits on top. It has two detents (peek and expanded), with a spring animation, and Reduce Motion is respected.
2. **Writing.** Each week (4–42) gets a short article in natural prose, written fresh in Vietnamese and English. It is split into two tabs, **Bé** and **Mẹ**, with clear headings and references.

The reference for the interaction and the writing style is the Flo app; the user shared screenshots. We do **not** copy any Flo text, images or reviewer names. All content is original, based on ACOG, NHS, WHO, Bộ Y tế and Hadlock, and is marked unreviewed until the doctor reviews it.

## 2. Decisions made with the user

| Topic | Decision |
|---|---|
| Scope | Both the layout and the content rewrite |
| Images | Add slots for per-week fetus and fruit images. Until artwork arrives, fall back to the shared `Fetus` image and a large emoji |
| Structure | Two tabs inside the sheet, **Bé / Mẹ**. Warning signs live in the Mẹ tab |
| Sheet | Built as a custom in-view sheet (approach A), not a native `.sheet` |
| Out of scope | Bookmark/save, a "Reviewed by" doctor line, artwork itself, the "Thông tin chuyên sâu"/trimester articles (Knowledge phase), changes to Today |

## 3. Layout and interaction

### 3.1 Entry points (unchanged)

Week detail opens as a full-screen cover from the same places as today:
- the Today fetus image and its cards;
- the "Chi tiết" shortcut;
- the symptoms safety card ("Xem dấu hiệu cần đi khám", opened with `scrollToWarnings: true`).

### 3.2 Background layer

- The current hero gradient, with the ✕ button at the top left (`commonClose`). The VoiceOver escape gesture still closes the cover.
- **Large fetus image** in roughly the top half of the screen, from `WeekArtwork.fetus(week)`:
  - asset `Fetus-W%02d` (for example `Fetus-W31`);
  - if that asset is missing, the existing `Fetus` asset.
- The week `ChipScroller` (4…42) sits below the image, with identifiers unchanged (`weekChip-N`).
- A horizontal swipe on the background changes the week. This is the same rule as today: |dx| > 2·|dy| and at least 30 pt.

### 3.3 Article sheet

The sheet has rounded top corners (24 pt) and uses the card colour token. From top to bottom it contains:
1. **Grab handle**: 36×5 pt capsule inside a hit area of at least 44 pt.
   - It is an accessibility button, `weekSheetHandle`.
   - Its label is "Mở rộng bài viết" / "Expand article" when the sheet is at peek, and "Thu gọn bài viết" / "Collapse article" when expanded.
   - Tapping it toggles the detent.
2. **Title**: `weekTitle(N)`, then the existing pending-review row (`weekPendingReview`), unchanged.
3. **Tabs**: a `SegmentedPill` with **Bé | Mẹ**, identifiers `weekTab-baby` and `weekTab-mom`.
4. **Article body** for the selected tab (§4). It scrolls inside the sheet.

### 3.4 Detents

- **Peek**: the sheet's top edge sits just below the chip row, at the measured `maxY` of the chips plus 12 pt. At peek, the handle, title, tabs and the lead sentence are visible.
- **Expanded**: the top edge sits 8 pt below the top safe area.
- **Progress `p`**: 0 at peek and 1 at expanded, interpolated from the sheet offset. It drives the background:
  - fetus image opacity = 1 − p, scale = 1 − 0.1·p;
  - chip row opacity = 1 − p.
- **Initial detent:**
  - peek by default;
  - expanded when opened with `scrollToWarnings`;
  - expanded when `dynamicTypeSize >= .accessibility1`.

### 3.5 Gestures

The release decision lives in a pure function, `SheetDetentResolver`, in KickCore so it can be unit-tested.
- **Dragging** the handle or header area moves the sheet with the finger. It is clamped between the two detents, with a little rubber-banding past them.
- **On release:**
  - If the predicted end velocity is greater than 600 pt/s, the sheet goes to the detent in the direction of travel.
  - Otherwise it goes to the nearest detent.
- **When expanded:** the article scrolls normally. Pulling down while the scroll is at the top (offset ≤ 0) hands the drag to the sheet, and the release rule above then decides the detent.
- **When at peek:** the article does not scroll, and an upward drag on the body moves the sheet.
- **Changing week** (chip or horizontal swipe):
  - the sheet keeps its detent;
  - the selected tab is kept;
  - the article scroll resets to the top;
  - the content cross-fades over 0.2 s, or instantly under Reduce Motion.
- **Animation:**
  - `.spring(response: 0.35, dampingFraction: 0.85)`;
  - no animation when `LunaMotion.isEnabled` is false, which covers Reduce Motion and `-uiTesting`;
  - under Reduce Motion the background does not scale (only the opacity changes).

### 3.6 Opening from the safety card

When the cover is opened from the safety card:
1. The sheet opens expanded.
2. The tab is set to **Mẹ**.
3. The article scrolls to the `weekWarnings` anchor.

The anchor id is unchanged, so the existing phase 5 tests keep their meaning.

## 4. Content

### 4.1 Data model (KickCore, `pregnancy-content.json` version 3)

`WeekContent` keeps every existing field, because Today's cards still use the short `baby`/`mom`/`tips` bullets and `warnings`. It gains one optional field:

```swift
public struct WeekArticle: Codable, Equatable, Sendable {
    public var lead: LocalizedText            // Bé tab, bold opening, ≤ 30 words (en) / ≤ 40 words (vi)
    public var sizeNote: LocalizedParagraphs   // "Bé lớn cỡ nào?" written paragraph(s) after the generated line
    public var development: LocalizedParagraphs // "Bé phát triển ra sao" — 2–3 paragraphs
    public var body: LocalizedParagraphs       // Mẹ tab: "Cơ thể mẹ tuần này" — 1–3 paragraphs
    public var todo: LocalizedParagraphs       // Mẹ tab: "Mẹ nên làm gì" — 1–2 paragraphs
    public var sources: [Int]                  // indices into PregnancyContent.sources, ≥ 1
}

public struct LocalizedParagraphs: Codable, Equatable, Sendable {
    public var en: [String]
    public var vi: [String]
    public func paragraphs(_ language: ContentLanguage) -> [String]
}

// WeekContent
public var article: WeekArticle?   // decodes from a version-2 file (field absent) as nil
```

`PregnancyContent.sources` remains `[String]`. New sources may be appended but never reordered, because the articles refer to them by index.

### 4.2 "Bé lớn cỡ nào?": generated size line

`WeekSizeLine.make(for:language:)` in KickCore builds a sentence from the data, so the numbers always match the reviewed Hadlock tables:

| Weeks | Line (vi) |
|---|---|
| 4–6 (no figures) | none; only `sizeNote` is shown |
| 7–9 (`crlMm` only) | "Bé dài khoảng {CRL} (từ đầu đến mông), cỡ {fruit}." |
| 10–13 (`crlMm` + weight) | "Bé dài khoảng {CRL} (từ đầu đến mông) và nặng khoảng {weight}, cỡ {fruit}." |
| 14–40 (weight + range) | "Bé nặng khoảng {weight} (thường từ {p10} đến {p90}), cỡ {fruit}." |
| 41–42 | the week-40 line, plus the existing `pregnancyBabyStandardEnds` note |

Rules for the line:
- English has matching sentences.
- Numbers use the existing `Formatting.crownRumpLength` and `Formatting.weight`/`weightRange`, so Vietnamese gets a decimal comma.
- It is localized through `L10n` keys (`weekArticle.size.*`), not stored in JSON.
- The existing estimate note (`pregnancyBabyEstimateNote`) stays as a small footnote below.
- The figure tiles in the current panel are removed, because the size line replaces them.
- The VoiceOver reading of the line uses the spoken formatters, as the tiles did.

### 4.3 Tab content and order

**Bé tab:**
1. Bold `lead`.
2. A row with the fetus and fruit images:
   - `WeekArtwork.fruit(week)` uses asset `Fruit-W%02d`;
   - if that is missing, `size.emoji` at 64 pt inside a 120 pt circle;
   - the row is accessibility-hidden.
3. Heading "Bé lớn cỡ nào?", the generated line, `sizeNote`, and the footnote.
4. Heading "Bé phát triển ra sao" and the `development` paragraphs.
5. "Tài liệu tham khảo": a collapsed `DisclosureGroup` listing `sources` with their full source strings (`weekReferences`).

**Mẹ tab:**
1. Heading "Cơ thể mẹ tuần này" and the `body` paragraphs.
2. Heading "Mẹ nên làm gì" and the `todo` paragraphs.
3. The existing `WarningSection` ("Khi nào cần đi khám ngay"), with anchor `weekWarnings`.
4. "Tài liệu tham khảo", as on the Bé tab.

**Fallback:** if `article` is nil for a week, the tabs show the existing bullet lists instead:
- Bé tab: `baby`;
- Mẹ tab: `mom`, `tips` and `warnings`.

The app therefore never shows an empty sheet.

Typography uses `Font.luna`: paragraphs in body style with line spacing 4; headings in headline style with the `.isHeader` trait. All colours come from existing tokens, and ContrastTests stay green.

### 4.4 Writing guide (for the content tasks and the reviewers)

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

### 4.5 Content checks (KickCore tests on the bundled JSON)

- Every week 4–42 has an `article`, and every paragraph list is non-empty in both languages.
- The `lead` and per-tab word counts are within the limits in §4.4.
- `sources` indices are valid and non-empty.
- No text matches `/\b(inch|inches|pound|pounds|lb|lbs|ounce|ounces|oz)\b/i`, and nothing contains "″".
- Version is 3, and the file still decodes with every existing field intact.
- `WeekSizeLine` produces the expected strings at weeks 5, 8, 12, 31, 40 and 42 in vi and en.

### 4.6 Review and release

- All weeks keep `"reviewed": false`. Release builds keep hiding unreviewed weeks (`BuildFlags.contentVisibility`); this logic is unchanged.
- `docs/content-review-for-doctor.md` gains **§9 Bài viết theo tuần**:
  - a checklist with one item per week;
  - the writing guide;
  - a note that the size line comes from the Hadlock data already in §2.
- No "Người xem xét" line is shown until a real doctor has signed off.

## 5. Components and files

| Unit | Location | Responsibility |
|---|---|---|
| `WeekArticle`, `LocalizedParagraphs` | KickCore `PregnancyContent.swift` | data |
| `WeekSizeLine` | KickCore | the generated size sentence; the localized templates are passed in so KickCore stays free of L10n |
| `SheetDetentResolver` | KickCore | pure release/detent logic |
| `WeekArtwork` | App/Pregnancy | resolves `Fetus-W##` and `Fruit-W##` assets with fallbacks |
| `ArticleSheet` | App/DesignSystem | generic two-detent draggable sheet: handle, progress binding, hand-off from the inner scroll |
| `WeekArticleView` | App/Pregnancy | Bé/Mẹ tab content, references, fallback to bullets |
| `WeekDetailView` | App/Pregnancy | rebuilt as background (hero, chips) plus `ArticleSheet` |
| Content | `pregnancy-content.json` | `article` for weeks 4–42, version 3 |
| Strings | `Localizable.xcstrings` via `scripts/add-strings.py` | tab names, headings, handle labels, references title, size-line templates |

## 6. Testing

- **KickCore:**
  - decoding (version 2 without articles, and version 3);
  - `WeekSizeLine` cases;
  - `SheetDetentResolver` cases: nearest detent, fast flick up/down, rubber-band clamp;
  - the content checks in §4.5.
- **UI tests** (`WeekArticleSheetUITests`, plus updates to the existing week-detail tests):
  - opening shows the sheet at peek, and the handle label says "expand";
  - tapping the handle expands the sheet and the label changes; tapping again collapses it;
  - switching Bé → Mẹ shows `weekWarnings`;
  - changing week via a chip keeps the Mẹ tab;
  - from the symptoms safety card, the sheet is expanded, on Mẹ, with `weekWarnings` hittable.
- **Screenshots** (`WeekArticleScreenshotTests`), each a pair:
  - peek and expanded × Bé and Mẹ, vi light;
  - en dark;
  - AX5 (expanded at open);
  - opened from the safety card.
- **Scoped CI:** each task's commit carries the `CI-Only-Testing:` trailer for its UI test classes. The final review runs the full suite.

## 7. Delivery

The work is one branch, `feat/week-article-sheet`, with these tasks:
1. Data model, `WeekSizeLine`, `SheetDetentResolver`, and the content checks for structure only (the content tests start in a pending state).
2. `ArticleSheet` component.
3. `WeekArticleView`, the `WeekDetailView` rebuild, strings, UI tests and screenshots, using placeholder articles for a few weeks.
4. Content for weeks 4–13 (vi + en), with its own accuracy and tone review.
5. Content for weeks 14–27.
6. Content for weeks 28–42. After this the content checks are fully enforced.
7. Doctor review §9, README, and a check of the release checklist (no CloudKit change: content is bundled).

## 8. Risks

- **The detent drag conflicts with the ScrollView.** Mitigation: the hand-off happens only at scroll offset ≤ 0. The offset is read through a `GeometryReader` preference in a named coordinate space, because the deployment target is iOS 17 and `onScrollGeometryChange` needs iOS 18. The rule is covered by both a UI test and resolver unit tests.
- **Content volume** (about 40,000 words). Mitigation: three batches, a writing guide and automated checks, with human (doctor) review before release.
- **Accessibility sizes.** Mitigation: the sheet opens expanded, and the AX5 screenshot is reviewed.
