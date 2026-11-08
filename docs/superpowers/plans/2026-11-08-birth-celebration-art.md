# Birth Celebration (designed version) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the birth celebration as the handoff's 8-page Stories sequence, and ask for the baby's details on the birth branch.

**Architecture:** KickCore gains `BirthDetails`, stored optionally in `PregnancyMemoryContent` and carried by `PregnancyRecap` (plus a `.summary` page and the handoff's milestone weeks). The ending sheet gets a birth-only "Thông tin bé" step feeding `PregnancyEnding.end(…, baby:)`. `BirthCelebrationView` is rewritten against the handoff with its own colour tokens and PNG assets; `ConfettiView` is rewritten to the handoff's particle spec.

**Tech Stack:** Swift 6, SwiftUI iOS 17, KickCore (Swift Testing), XCUITest, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-11-08-birth-celebration-art-design.md` and the handoff `~/Downloads/design_handoff_birth_celebration/README.md` (values: colours, sizes, timings).

## Global Constraints

- No Lottie, no new dependencies; no Photos permission (share sheet only).
- Strings only via `scripts/add-strings.py` (en + vi). Numbers formatted with `Formatting.locale`.
- `PregnancyMemoryContent.version` stays 1; `baby` is additive and optional.
- Motion off when `!LunaMotion.isEnabled` (UI tests) or Reduce Motion, as the handoff's "Giảm chuyển động" section says.
- Never run UI tests locally; KickCore via `scripts/test-core.sh`; app compile via `xcodebuild build` for the simulator.

## Review Focus

1. A birth before week 8 or with no dates: journey strip must not show weeks above the final one, and no journey page without weeks — covered in Task 1 tests (`milestones` for 4 and nil).
2. Weight typed as "3,2" (Vietnamese comma) vs "3.2": both parse — Task 2 `BirthDetails.parseDecimal` test.
3. Old memory JSON (no `baby` key) still decodes and replays — Task 1 round-trip test.
4. VoiceOver/UI tests: no auto-advance, "Tiếp" on every page but the last — Task 5 UI test walks with "Tiếp".
5. Huge Dynamic Type: big numbers scale only 40 %, pages scroll — manual check on device (noted in the PR).

---

### Task 1: KickCore — BirthDetails, content, recap

**Files:**
- Create: `Packages/KickCore/Sources/KickCore/BirthDetails.swift`
- Modify: `Packages/KickCore/Sources/KickCore/PregnancyMemoryContent.swift`, `Packages/KickCore/Sources/KickCore/PregnancyRecap.swift`
- Test: `Packages/KickCore/Tests/KickCoreTests/BirthDetailsTests.swift`, `PregnancyRecapTests.swift`, `PregnancyMemoryBuilderTests.swift`

**Interfaces — Produces:**
- `public struct BirthDetails: Codable, Equatable, Sendable { name: String?; time: Date?; weightKg: Double?; lengthCm: Double?; init(name:time:weightKg:lengthCm:) (trims name, empty → nil; drops weight outside 0.5...7 and length outside 25...65); var isEmpty: Bool; static func parseDecimal(_ text: String) -> Double? }` (accepts "," or ".").
- `PregnancyMemoryContent.baby: BirthDetails?` (init param `baby: BirthDetails? = nil`); `PregnancyMemoryBuilder.make(…, baby: BirthDetails? = nil)` sets it only for `.birth` and only when not empty.
- `PregnancyRecap.baby: BirthDetails?`; `Page.summary` appended after `.thanks`; `journeyWeeks` = `PregnancyRecap.milestones(to:)`: `[8,16,24,32].filter { $0 < final } + [final]`; `static func milestoneArt(_ week: Int, isFinal: Bool) -> Int` returns one of 8/16/24/32/40 (final → 40, else nearest).

- [ ] Tests: `BirthDetailsTests` (trim/empty name, ranges, `parseDecimal("3,2") == 3.2`, `"3.2"`, `"abc" == nil`, `isEmpty`); recap: pages end `[.thanks, .summary]`; `milestones(to: 38) == [8,16,24,32,38]`, `40 → [8,16,24,32,40]`, `30 → [8,16,24,30]`, `12 → [8,12]`, `4 → [4]`; `milestoneArt(30, isFinal: false) == 32`, `milestoneArt(12, isFinal: false) == 8` (tie → lower), `milestoneArt(38, isFinal: true) == 40`; recap carries `baby`; content JSON without `baby` decodes with nil; round-trip with `baby` keeps it; builder drops `baby` for `.loss` and for empty details. Update existing recap tests for `.summary` and new journey weeks.
- [ ] Run `scripts/test-core.sh` → fail, implement, → pass.
- [ ] Commit `feat(core): birth details and the designed recap pages`.

### Task 2: Ending flow — "Thông tin bé" step

**Files:** Modify `App/PregnancyEnding/PregnancyEnding.swift`, `App/PregnancyEnding/PregnancyEndingSheet.swift`, `Shared/L10n.swift`, `Shared/Localizable.xcstrings` (via script).

**Interfaces:** `PregnancyEnding.end(branch:endDate:keep:baby: BirthDetails? = nil) async throws -> PregnancyRecap?` passes `baby` into `makeContent`. Sheet: `Step.baby` between `.opener(.birth)` and `.keep(.birth)`; fields name (TextField), time (row opening a wheel `DatePicker(.hourAndMinute)`, unset until touched), weight kg and length cm (`.decimalPad`). "Tiếp" builds `BirthDetails(name:time:weightKg:lengthCm:)` with time = `endDate`'s day at the chosen hour/minute; "Bỏ qua" clears the fields and continues. Identifiers: `birthDetailsName`, `birthDetailsTime`, `birthDetailsWeight`, `birthDetailsLength`, `birthDetailsContinue`, `birthDetailsSkip`.

- [ ] Add strings (`birthDetails.title` "Thông tin bé", `.hint` "Không bắt buộc — Luna Mom chỉ dùng để chúc mừng và lưu trong Kỷ niệm.", `.name` "Tên bé", `.time` "Giờ sinh", `.weight` "Cân nặng (kg)", `.length` "Chiều dài (cm)", `.continue` "Tiếp", `.skip` "Bỏ qua", `.timeUnset` "Chưa chọn").
- [ ] Implement; build the app for the simulator → succeeds.
- [ ] Commit `feat: ask for the baby's details on the birth branch`.

### Task 3: Assets, palette, confetti

**Files:** Create `App/Images.xcassets/Celebration/` (folder `Contents.json` + one `.imageset` per handoff image, `@2x`/`@3x` from `-2x`/`-3x`), `App/PregnancyEnding/CelebrationPalette.swift`; rewrite `App/PregnancyEnding/ConfettiView.swift`.

**Interfaces:** `enum CelebrationPalette` with `static func color(_ token: Token, _ scheme: ColorScheme) -> Color` for tokens `bg` (gradient: `static func background(_ scheme) -> LinearGradient`), `disc, moon, ink, ink2, accent, onAccent, num, card, line, track, statDisc` and `confetti(_ scheme) -> [Color]`, exact hex/rgba from the handoff "Màu" table. `Image("Celebration/cel-hero")` etc. (image set names: `cel-hero`, `cel-thanks`, `week-08…week-40`, `stat-kicks`, `stat-contractions`, `stat-visits`, `stat-weight`; catalog folder without namespace so plain names work). `ConfettiView(intensity: Double, isStill: Bool)` — 22 particles (50 % rect 6–11×9–15 r2, 30 % heart 12–20, 20 % star), 9–14 s linear fall from y −30, x drift ±60, spin ±360°, fade in first 8 %/out last 15 %, seeded; `isStill` draws nothing (handoff: no confetti under Reduce Motion).

- [ ] Copy assets with a script; build → succeeds. Commit `feat(ui): celebration artwork, palette and confetti`.

### Task 4: BirthCelebrationView rewrite

**Files:** Rewrite `App/PregnancyEnding/BirthCelebrationView.swift` (split pages into `App/PregnancyEnding/CelebrationPages.swift` if over ~400 lines); strings via script; remove unused old keys.

**Behaviour (handoff README is the source of values):** progress bar (one segment per page, 6 s linear, pause on hold ≥ 250 ms), ✕ (`birthCelebrationClose`), tap halves, auto-advance pages 1…n-1 unless `UIAccessibility.isVoiceOverRunning` or `!LunaMotion.isEnabled`; in that case "Tiếp" (`birthCelebrationNext`) on every page but the last, otherwise only on celebration and thanks. Pages: celebration (hero + 3 sparkles, title, wish, info card with filled fields only), journey (milestone strip with dashed line), stat pages (label "HÀNH TRÌNH CỦA MẸ", 140pt disc `#F9D6DE`, number 88pt scaled `88 × (1 + (scale−1) × 0.4)`, count-up 1.4 s easeOutCubic), thanks (`birthCelebrationThanks`, real weeks), summary (header, grid, birth-details row only with data, "Lưu ảnh" `birthCelebrationSave` → `ShareLink` of `ImageRenderer` image at scale 3 rendered in light scheme without buttons, "Xong" `birthCelebrationDone`). Page transition 520 ms `timingCurve(0.22,1,0.36,1)` ±28pt + scale 0.98; Reduce Motion cross-fade 240 ms. Haptic only when `playsHaptic`. VoiceOver `screenChanged` on page change.

**Strings:** `birth.celebration.title` "Chào mừng bé yêu! 🎉", `birth.celebration.wish`, `birth.bornOn` "Chào đời ngày %@", `birth.time/weight/length` labels, `birth.eyebrow` "HÀNH TRÌNH CỦA MẸ", `birth.weeksTogether` "tuần bên nhau", `birth.daysWithBaby` "%@ ngày bên bé", `birth.kicks.label`, `birth.contractions.label`, `birth.appointments.label`, `birth.weightChange`, `birth.thanks.title` "Cảm ơn mẹ", `birth.thanks.body.weeks` (%d), `birth.thanks.body`, `birth.summary.eyebrow`, `birth.summary.title` "Mẹ và bé %@" / `.titleNoName` "Mẹ và bé", `birth.summary.weightAtBirth`, `birth.save` "Lưu ảnh". Keep `birth.thanks.saved` (memory note) on the thanks page.

- [ ] Build → succeeds. Run `scripts/test-core.sh` → pass. Commit `feat(ui): the designed birth celebration`.

### Task 5: UI tests

**Files:** `UITests/PregnancyEndingUITests.swift`, `UITests/UITestSupport.swift` (if needed), memory replay test file.

- [ ] Birth-from-Today test: after Continue, fill `birthDetailsName` "Minh An" and `birthDetailsWeight` "3,2", tap `birthDetailsContinue`; walk with `birthCelebrationNext` until `birthCelebrationDone`; assert a static text containing "Minh An" exists on the summary; assert thanks was seen on the way (`birthCelebrationThanks`) with "saved in Profile".
- [ ] Close-from-first-page test taps `birthDetailsSkip`; any other test passing through the birth branch taps skip.
- [ ] Commit `test(ui): the designed celebration and baby details`. CI runs them (never locally).

### Finish

Full `scripts/test-core.sh` + app build; push (pre-push hook); PR; whole-branch review on top tier if > 15 files / 400 lines (owner rule 3); CI green.
