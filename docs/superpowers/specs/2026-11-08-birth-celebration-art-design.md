# Birth celebration: the designed version — design

Builds on `2026-11-08-birth-celebration-design.md` (#56). The logic stays: when it
shows, holding/releasing the cover, replay from a memory. This replaces the look
and the paging with the Claude Design handoff
(`~/Downloads/design_handoff_birth_celebration`, README + `.dc.html`, high fidelity),
and adds the baby's details the handoff's cards need.

## Why

The owner wants the moment of birth to feel like a celebration made for her, not
a list of numbers: a Stories-style sequence with real illustration, gentle motion
and a summary she can save and share.

## Goals

- The 8-page Stories sequence exactly as the handoff specifies: colours (light and
  dark), type, spacing, motion curves and timings, Reduce Motion, Dynamic Type.
- An optional "Thông tin bé" step on the birth branch: name, time of birth, birth
  weight, length. Shown on page 1 and page 8, kept in the memory for replay.
- "Lưu ảnh" on page 8 renders the summary as an image.

## Non-goals

- No change to the loss branch, the Today card, the Profile card or the hold/release flow.
- No Lottie, no new dependencies.

## Anti-goals

- Asking for the baby's details must never block ending: every field is optional
  and the step has a skip.
- No page showing a zero or made-up number. No "40 tuần" when it was 38.
- Auto-advance must not run away from a VoiceOver user.
- No Photos permission prompt.

## Approaches considered

- **Baby details: a step in the ending sheet (chosen by the owner)** vs. dropping
  the info card. The owner picked asking, all optional, kept in the memory.
- **Saving the summary:** share sheet with the rendered image (chosen: it has
  "Save Image", needs no permission) vs. writing to Photos (needs
  `NSPhotoLibraryAddUsageDescription` and a prompt).

## Design

### 1. Data (KickCore, pure, tested)

- `BirthDetails: Codable, Equatable, Sendable` — `name: String?`,
  `time: Date?` (the birth day at the chosen hour and minute),
  `weightKg: Double?`, `lengthCm: Double?`. `isEmpty` when all are nil. Names are
  trimmed; empty becomes nil.
- `PregnancyMemoryContent.baby: BirthDetails?`, additive: older JSON decodes with
  nil, `version` stays 1. Only set for `.birth`.
- `PregnancyRecap` gains `baby: BirthDetails?` and a final `.summary` page after
  `.thanks`. Stat pages still appear only when their number is above zero (weight:
  when there is a change); the summary shows the same set of cells.
- The journey strip becomes the handoff's milestones: weeks 8, 16, 24, 32 that are
  below the final week, then the final week (`weeks`, clamped 4…42). Art is the
  nearest of the five handoff images (`week-08…week-40`); the final week always
  uses `week-40`. Labels show the real weeks.

### 2. Ending sheet

On the birth branch, after the date step and before "keep": a "Thông tin bé" step
with a name field, a time row (opens a wheel time picker, unset until touched), a
weight field (kg, decimal, 0,5…7) and a length field (cm, 25…65). Out-of-range or
unparsable numbers are left out, not errors. "Tiếp" and "Bỏ qua" both continue;
"Bỏ qua" clears the fields. `PregnancyEnding.end(…, baby:)` puts them into the
content (and so into the memory when kept) and the recap.

### 3. The celebration (`BirthCelebrationView`, rewritten)

As the handoff README, with these calls of ours:

- Pages: celebration → journey → kicks → contractions → appointments → weight →
  thanks → summary, skipping stat pages without data. The progress bar has one
  segment per present page.
- The info card shows only the fields she filled; with none, no card. The title is
  "Chào mừng bé yêu! 🎉"; with a name, page 8's line is "Mẹ và bé {name}", else
  "Mẹ và bé".
- Thanks copy uses the real weeks; without weeks, a version without the number.
- Auto-advance (6 s, pages 1–7) is off while VoiceOver runs and in UI tests; then
  "Tiếp" shows on every page but the last. Tap halves and long-press pause as the
  handoff says; buttons don't count as navigation taps.
- "Lưu ảnh" renders the summary with `ImageRenderer` at 3× (fixed light scheme,
  no buttons, no progress bar) and shares it through `ShareLink`.
- Confetti rewritten to the handoff: 22 particles, its palettes, 100 % on pages
  1, 7, 8 and 30 % on the others, cross-fading 800 ms; none under Reduce Motion.
- Replay from a memory shows the same sequence (no haptic), with the stored details.
- Assets go into `App/Images.xcassets/Celebration/` as `@2x`/`@3x` image sets.
  Colours are local to the view (the handoff's own tokens, light and dark).

### 4. Strings

All copy from the handoff in Vietnamese, plus English, through
`scripts/add-strings.py`. The old celebration-only strings that no longer show are
removed.

## Testing

- KickCore: `BirthDetails` trimming and emptiness; content round-trip with and
  without `baby` (old JSON still decodes); recap pages including `.summary`;
  milestone weeks for 38, 40, 30, 12 and 4; art mapping.
- UI tests: the birth flow fills a name and weight, walks to the summary with
  "Tiếp" (auto-advance is off in tests) and sees the name; skip leaves no card;
  close from page 1 still works; replay from Kỷ niệm shows the name.

## Left to the builder

Layout details the handoff doesn't fix, within its measurements; how the text
fields are validated while typing; the exact English copy.

## Note for the owner

The handoff says the illustrations were generated with Gemini: check their
commercial use rights before release.
