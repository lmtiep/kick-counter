# Birth celebration and a findable "baby is born" entry — design

Status: approved approach A by the owner on 2026-11-08 ("ok chọn A, em làm đi").
Builds on 1.1 item 4, pregnancy ending (`2026-11-05-pregnancy-ending-design.md`).

## Why

The owner tested 1.1 (build 35) and found two gaps:

1. **No moment of joy.** After confirming "Bé đã chào đời", the sheet closes and the app is quietly back in cycle tracking. The only congratulation is a sentence on the date step, which is easy to miss. The owner wants a full-screen, playful 2D-animated celebration of mother and baby. Tapping on then walks through the numbers and pictures of the pregnancy that just ended.
2. **The entry is hard to find.** "Thai kỳ của tôi đã kết thúc" is a plain row inside Profile's mode card. The owner could not find it.

## Goals

- A celebration screen shown once, right after a **birth** ending is confirmed. The animation is joyful and in the app's own art and palette.
- A recap story that follows the celebration. It is paged by taps, one fact per page, with the per-week artwork the app already ships.
- Approach **A**, chosen by the owner:
  - a card on Today asking "Bé đã chào đời chưa?", shown only from week 37;
  - the Profile entry becomes a clearly visible card.
- The same recap can be watched again later from a kept birth memory.

## Non-goals

- No celebration, confetti or recap on the **loss** branch. The loss flow is unchanged.
- No baby tracking (decided earlier for 1.1).
- No new third-party dependency such as Lottie. Everything is SwiftUI.
- No sharing or exporting of the recap. This can come later.

## Anti-goals

These would count as failures:

- The Today card showing before week 37. A pregnant user should not be shown an "it's over" prompt every day.
- Anything celebratory reaching a user who chose "Thai kỳ đã dừng lại".
- The celebration blocking the user. A close button must always be reachable, and the ending is already saved before the cover appears.
- Motion that ignores Reduce Motion.

## Approaches considered

- **A. Today card from week 37, plus a stronger Profile card.** Chosen by the owner. It is visible exactly when a birth is near and never during the rest of the pregnancy.
- **B. A prominent card in Profile for the whole pregnancy.** Simpler, but the user still has to open Profile.

For the animation:

- **SwiftUI-native** (`Canvas` + `TimelineView` particles, `phaseAnimator` / `keyframeAnimator` for the hero art). This is my call: no dependency, it honours Reduce Motion easily, and it uses the app's assets.
- **Lottie.** Rejected: it adds a dependency and a JSON animation to design, for little gain.

## Design

### 1. Today card (`BirthPromptCard`)

- **Rule (KickCore, pure, tested):** `BirthPromptRules.showsTodayCard(week:) -> Bool`, true for `week >= 37`. This follows `BagRules.showsTodayCard`.
- **Placement:** in `PregnancyTodayView.cards(for:)`, directly after `WeekProgressCard`, so it is visible without scrolling.
- **Copy (EN / VI):**
  - title: "Has your baby arrived?" / "Bé đã chào đời chưa?"
  - body: "When your baby is born, tell Luna Mom here to celebrate and keep your pregnancy journey." / "Khi bé chào đời, hãy báo cho Luna Mom ở đây để cùng chúc mừng và lưu lại hành trình mang thai."
  - button: "My baby is born 🎉" / "Bé đã chào đời 🎉"
- **Tap:** opens `PregnancyEndingSheet` already on the birth branch's date step (`.opener(.birth)`). This needs a new `initialBranch: PregnancyEndBranch?` parameter, defaulting to nil, which starts at `.choose`. Cancel still closes it.
- No dismiss or snooze control. The card goes away when the pregnancy ends.
- Hidden wherever the Profile ending row is hidden (for example a partner's read-only view, if Today is shown there).

### 2. Profile card

- The ending row moves out of the mode card into its own `lunaCard` directly under it, shown while `mode == .pregnant`.
- The card has a leading icon (SF Symbol `heart.circle.fill`, accent tint), the title "Thai kỳ của tôi đã kết thúc" and a chevron.
- It adds a secondary line: "Ghi lại khi bé chào đời hoặc khi thai kỳ dừng lại." / "Record your baby's birth, or a pregnancy that has ended."
- It keeps the accessibility identifier `profilePregnancyEnded`, so the existing UI tests still find it.

### 3. Recap data (KickCore, pure, tested)

`PregnancyRecap.make(content: PregnancyMemoryContent, calendar:) -> PregnancyRecap`. The struct holds:

| Field | Meaning |
|---|---|
| `birthDate: Date` | `content.end` |
| `weeks: Int?`, `days: Int?` | `furthestWeek`, and whole days from `start` to `end` (nil without a start) |
| `artworkWeek: Int?` | `furthestWeek` clamped to 4…42, used for the hero `Fetus-Wxx` and `Fruit-Wxx` art |
| `journeyWeeks: [Int]` | the weeks to show as a growth strip: 4…artworkWeek, sampled to at most 8 evenly spaced weeks including the first and last |
| `totalKicks: Int` | sum over `kickDays` |
| `kickSessions: Int` | sum over `kickDays` |
| `contractions: Int` | sum of `contractionEpisodes.count` |
| `appointments: Int` | `appointments.count` |
| `weightChangeKg: Double?` | last minus first weight when there are at least 2 entries, else nil |
| `pages: [PregnancyRecap.Page]` | the ordered pages, built from the fields above |

The pages, in order:

1. `.celebration`
2. `.journey`, only when `weeks != nil`
3. `.kicks`, only when `totalKicks > 0`
4. `.contractions`, only when `contractions > 0`
5. `.appointments`, only when `appointments > 0`
6. `.weight`, only when `weightChangeKg != nil`
7. `.thanks`

Calendar math uses the injected calendar, matching the rest of KickCore.

### 4. Getting the recap at the moment of ending

`PregnancyEnding.end(...)` returns `PregnancyRecap?`. It is non-nil only for `.birth`.

- `archive` already builds `PregnancyMemoryContent` when the user keeps a memory. For a birth it now always builds the content (cheap and in memory), and saves it only when `keep` is `.memory`. Nothing changes about what is stored or deleted.
- `PregnancyEndingSheet.confirm` passes the recap through `onEnded`. `onEnded` becomes `(PregnancyRecap?) -> Void`; Profile and the Today card forward it.
- The cover is presented from **RootView**, not from the sheet or Profile, because the mode switch rebuilds the pregnancy screens underneath. Use an `@Observable` holder on `PregnancyEnding` (`pendingCelebration: PregnancyRecap?`) that RootView binds a `fullScreenCover(item:)` to. It is set after `end` succeeds, and cleared when the cover closes.

### 5. Celebration and recap screen (`BirthCelebrationView`)

- **Full screen**, on a soft pink-to-cream gradient from the Luna palette. It has a close (✕) button top-right on every page (identifier `birthCelebrationClose`).
- **Navigation:**
  - tapping anywhere outside the close button advances;
  - a "Tiếp" / "Next" pill (identifier `birthCelebrationNext`) is there for clarity and VoiceOver;
  - a small page dots row sits at the bottom;
  - the last page's button reads "Xong" / "Done" (identifier `birthCelebrationDone`) and closes.
  - Swipe back to the previous page is a nice-to-have, left to the builder.
- **Page `.celebration`:**
  - confetti and floating hearts and stars rain down, drawn with `Canvas` + `TimelineView` in the palette colours;
  - the `Fetus-W40` art (or `artworkWeek`) sits in a glowing circle with a gentle bounce-in, then a slow breathing scale;
  - title "Chào mừng bé yêu! 🎉" / "Welcome, little one! 🎉";
  - body "Chúc mừng mẹ và bé. Luna Mom mong hai mẹ con thật nhiều bình yên." (reuse `pregnancyEnd.birth.opener`), then the birth date "Ngày chào đời: 8 tháng 11, 2026";
  - one `.success` haptic when it appears.
- **Page `.journey`:**
  - big number "40 tuần" (count-up), subtitle "…cùng 280 ngày bên bé";
  - a horizontal strip of the `journeyWeeks` fruit images, appearing one after another (staggered), each labelled with its week ("Tuần 8"), ending on the hero's fruit.
- **Pages `.kicks` / `.contractions` / `.appointments` / `.weight`:**
  - one big animated number, a short warm line and an SF Symbol or the matching art;
  - examples: "1.284 cử động thai đã được đếm, trong 96 lượt" / "38 cơn gò đã được ghi lại" / "12 lần đi khám" / "Tăng 11,5 kg";
  - the weight line reads neutrally: "Thay đổi cân nặng: +11,5 kg", no judgement.
- **Page `.thanks`:**
  - "Cảm ơn bạn đã để Luna Mom đồng hành suốt thai kỳ.";
  - when the memory was kept, add "Hành trình đã được lưu trong Cá nhân → Kỷ niệm.";
  - then the Done button.
- **Numbers:** formatted with the app locale (`Formatting`), so Vietnamese uses "1.284" and "11,5".
- **Reduce Motion:** no particles moving and no count-up. Confetti is drawn as a still scatter, and pages cross-fade instead of sliding.
- **Accessibility:** each page is one combined VoiceOver element with the full sentence, and "Next" and "Close" are reachable. It works at AX5 sizes: text scrolls inside a page if needed, and art shrinks first.
- **Dark mode:** it uses the palette tokens, so the gradient has a dark variant.

### 6. Watching it again

In `MemoryDetailView`, for a memory whose `branch == .birth`, add a "Xem lại hành trình" / "Replay the journey" button. It presents the same `BirthCelebrationView` from `PregnancyRecap.make(content:)`, without the haptic and without the "saved in Kỷ niệm" line.

### 7. Strings

All new strings go through `scripts/add-strings.py`, in English and Vietnamese. Vietnamese is primary; no machine-awkward phrasing.

## Testing

- **KickCore:**
  - `BirthPromptRulesTests`: weeks 36 / 37 / 42;
  - `PregnancyRecapTests`:
    - pages skipped when data is empty;
    - kick and contraction sums;
    - weight change needs 2 or more entries;
    - `journeyWeeks` sampling: first is 4, last is `artworkWeek`, at most 8, ascending, no duplicates, short pregnancies such as week 6 still work;
    - nil start gives nil days.
- **App logic:** `PregnancyEnding.end` returns a recap for birth with every `keep` choice, and nil for loss. Use the existing PregnancyEnding test seams.
- **UI tests** (CI only):
  - week-38 seed: Today shows `birthPromptCard`. Tap, confirm birth, keep memory; `birthCelebrationNext` steps through, Done closes, and the app is in cycle mode;
  - week-30 seed: no card;
  - loss from Profile: no celebration cover.
- **Screenshots:** the celebration page at default and AX5 sizes.
- **Mutation:** flip the week-37 threshold and drop the loss guard; each must turn a test red.

## Left to the builder

- Exact particle count, colours and timing, within "joyful, not frantic". Aim for 60 fps on an iPhone 12.
- The exact layout of the growth strip on small screens.
- Swipe-back between pages.
- Where the recap types live: KickCore for the pure parts, App for the views.
