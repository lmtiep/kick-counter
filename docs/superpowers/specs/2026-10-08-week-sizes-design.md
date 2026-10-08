# Week size comparisons by Hadlock weight, fruit artwork and a fetus artwork brief (Phase 11)

Date: 2026-10-08 · Status: approved in conversation · Branch: `feat/week-sizes` (worktree `../kick-counter-week-sizes`, runs in parallel with Phase 10)

## 1. Goal

The "Bé to bằng …" comparison should agree with the numbers the app shows. From week 10 the app shows the Hadlock 1991 estimated fetal weight, but many comparisons were chosen by crown–heel *length* (the usual consumer charts). The result is mismatches such as 331 g compared with a ~120 g banana at week 20, or 399 g with a ~70 g carrot at week 21.

Every week also gets its own fruit illustration, and the app owner gets a precise brief for the 39 fetus illustrations.

## 2. Decisions made with the user

| Topic | Decision |
|---|---|
| Comparison basis | **Weight**, matched to the Hadlock 1991 50th percentile for weeks 10–40. Weeks 41–42 compare with the week-40 value. Weeks 4–9 keep size comparisons by length (crown–rump), because the app shows no weight there |
| Tolerance | The produce's typical weight must be within **±25 %** of the week's Hadlock 50th-percentile weight |
| Produce choice | Prefer produce familiar in Vietnam. Each typical weight must cite a source (USDA FoodData Central portion weights first; otherwise a national food-composition table or a produce-standard document). Weights are never guessed |
| Fruit artwork | Claude draws 39 flat vector illustrations in the app's "Mầm" style, `Fruit-W04` … `Fruit-W42`. They are original and copy no other app |
| Fetus artwork | Out of scope to draw. Claude writes a brief for an illustrator or a licensed set. The files are dropped into the existing `Fetus-W##` slots later |

## 3. Data

### 3.1 Schema

`pregnancy-content.json` `weeks[].size` gains two fields:
- `typicalGrams`: an integer, required for weeks 10–42 and absent for weeks 4–9;
- `sourceKey`: a string naming an entry in a new top-level `produceSources` object.

Each `produceSources` entry has `title` and `url`, plus a `note` saying which portion was used.

The content `version` goes from 3 to 4, and `ContentValidator.supportedVersion` follows. `WeekSize` in `PregnancyContent.swift` gains `typicalGrams: Int?` and `sourceKey: String?`.

### 3.2 Validator rules (`ContentValidator`)

1. **`missingTypicalWeight`.** Weeks 10–42 must have `typicalGrams` and `sourceKey`. For weeks 4–9 they are absent; if present, raise `unexpectedMeasurement`.
2. **`unknownProduceSource`.** `sourceKey` must exist in `produceSources`.
3. **`comparisonOutOfTolerance`.** `|typicalGrams − reference| / reference ≤ 0.25`, where `reference` is the week's `weightG` (the Hadlock 50th percentile). For weeks 41–42 that `weightG` is the week-40 value.

### 3.3 The table

A research step (§6, step 1) produces the 33 rows for weeks 10–42. Each row gives:
- the produce in en and vi;
- the emoji;
- the typical grams;
- the source and the exact portion name.

The research must also check that the vi name is natural northern Vietnamese, for example "quả chanh ta", "quả quýt", "quả ổi".

Repeats are allowed when weights are close: the same produce may appear in at most two weeks in a row. The research may change the emoji when no emoji matches. The emoji stays only as the fallback when an image is missing.

Weeks 4–9 keep their current comparisons and get no new fields.

## 4. Fruit artwork

- **Assets.** 39 SVG files, one per week, in `App/Images.xcassets/Fruit-W##.imageset`, with "Preserve Vector Data" and a single universal scale. If any file is a repeat, it is still its own imageset, because `WeekArtwork` looks up by week.
- **Style.** Flat shapes, 2–4 tones per object, and soft shadows drawn as shapes (no filters).
- **Canvas and palette.**
  - The canvas is 240×240 with transparent padding of at least 16.
  - Colours come from the Mầm handoff palette (`docs/design/mam-handoff`) plus natural produce colours.
- **Legibility.**
  - Every object has a darker outline-tone edge, so it reads on both the light and the dark card background (`card`, `background` tokens).
  - The object is recognisable at 120 pt.
- **Scale.** Objects are not drawn to relative scale. Each fills the canvas, and the text gives the size.
- **Review gate.** All 39 are shown on one review page, in light and dark, at 120 pt and 60 pt. The user approves them before they are committed to the asset catalog.
- **App behaviour.** None changes. `WeekArtwork.fruit(week)` already prefers the asset over the emoji. A new KickCore-independent UI check confirms the image is present: the screenshot tests for the week article (weeks 12, 24, 38) must show the image, not the emoji.

## 5. Fetus artwork brief

The brief is `docs/design/fetus-artwork-brief.md`, in English with Vietnamese headings. It contains:

- **Delivery spec.**
  - Names `Fetus-W04` … `Fetus-W42`.
  - Vector PDF or SVG, or PNG at 1024×1024 with a transparent background.
  - The subject is centred with 8 % padding.
  - Light and dark variants are optional; one variant must read on both the `card` colours.
  - Style matches the "Mầm" handoff.
  - Licence: perpetual, worldwide, for commercial in-app use.
- **One row per week.** Each row gives:
  - the developmental features to show (taken from that week's "Bé" content and limited to it);
  - the approximate proportions (head-to-body ratio);
  - the pose, with the cord and placenta shown or omitted consistently;
  - what must **not** appear (for example, no open eyes before week 26 or so; no hair detail before week 20 or so).

  Everything is phrased for the illustrator and marked for doctor review.
- **Medical-accuracy checklist** for the doctor.
- **Drop-in steps** for Claude once the files arrive: add imagesets, run the week-article screenshots, read them.

## 6. Delivery (branch `feat/week-sizes`)

1. **Research.** Builds the produce table with cited weights and writes it to `docs/research/2026-10-08-produce-weights.md`, with every source URL. Done when every week from 10 to 42 has a row inside ±25 %, or a row flagged for a decision.
2. **Content and validator.**
   - Schema v4, validator rules and tests (TDD in KickCore).
   - JSON update and fixture update.
   - `content-review-for-doctor.md`: a new section listing the new comparisons.
   - Full CI.
3. **Fruit artwork.** 39 SVGs, the review page for the user's approval, then the asset catalog and screenshots.
4. **Fetus brief.** The document, and a link to it from the README.
