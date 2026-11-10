# Luna Mom 1.2: richer cycle logging, insights, app lock — design

## Why

After 1.1 (pregnancy ending, birth celebration) the owner wants to turn back to
cycle tracking and close the gap with Flo. Compared with Flo, Luna Mom predicts
and reminds well but logs little and tells her nothing back from what she logs.
1.2 adds more to log, turns the logs into plain observations about her own body,
and lets her lock the app, since a cycle diary (now with sex) is private.

The owner delegated the decisions ("em tự quyết") and approves this document.

## Goals

1. **Logging:** spotting, sex (protected / unprotected), sex drive, pregnancy
   test, more cycle symptoms and moods.
2. **Insights:** a cycle-length chart, a regularity verdict, and symptom/mood
   patterns by cycle day, on the Cycle history page; one pattern line on Today
   when today falls in a pattern's window.
3. **App lock:** Face ID / Touch ID with the device passcode as fallback.

## Non-goals

- No change to prediction (`CyclePredictor`): new logs do not move forecasts.
- No Apple Health sync, no cycle articles, no Apple Watch, no doctor-report changes.
- No hiding of notification content or widgets: iOS already shows notification
  previews only when unlocked by default; widgets stay as they are (both noted in
  the lock's footer text).
- Pregnancy mode logging (Symptoms tab) unchanged apart from shared enum plumbing.

## Anti-goals

- An insight must never read as a diagnosis. Observations only ("bạn hay…"), no
  "bạn bị…", no disease names. Regularity uses the same FIGO wording the app already
  uses ("trông có vẻ…"), and points to a doctor only where the app already does.
- Spotting must never count as a period day or change a forecast.
- The lock must never lock her out: device passcode always works; no app PIN.
- Nothing leaves the phone. All insights are computed on device.

## Constraints

- Swift 6, SwiftUI iOS 17; logic in KickCore with Swift Testing; strings only via
  `scripts/add-strings.py`; vi and en.
- SwiftData schema is unversioned; new `CycleLog` attributes must be optional with
  defaults (lightweight migration). Applied to a real 1.1 store before shipping.
- Backup format: new optional keys, `decodeIfPresent`; an older build ignores them.
  Unknown raw values round-trip like moods/symptoms do today.
- MARKETING_VERSION → 1.2.0.

## Approaches considered

**Where insights live**
- A. **History page section + one Today line (chosen).** History already has the
  averages and per-cycle rows; insights extend it. Today gets at most one line, only
  when relevant, so Today does not grow a dashboard.
- B. A new "Nhận xét" tab: more visible, but a fourth tab for content that is thin
  until she has 3+ cycles.
- C. History only: cheapest, but she would rarely see a pattern at the moment it matters.

**How new logs are stored**
- A. **New optional columns on `CycleLog` (chosen):** typed, queryable, clear in backups.
- B. Encode as extra entries in `symptomsRaw`: no schema change, but mixes kinds and
  makes "protected vs unprotected" a symptom.

**Lock**
- A. **Overlay in the root scene + privacy cover (chosen):** `LAContext`
  `.deviceOwnerAuthentication`; cover shown when the scene goes inactive so the app
  switcher snapshot is blank.
- B. A separate UIWindow: survives sheets better but more UIKit; the overlay above
  every presentation is handled by a full-screen cover window level is not needed
  if the cover is attached at the WindowGroup root (builder: verify sheets are
  covered; fall back to a window if not).

## Design

### 1. Logging (Cycle day log sheet)

Sections, in order (new ones marked ★):

1. Kỳ kinh / Lượng kinh (unchanged) + ★ **Ra máu lấm tấm** toggle chip. Spotting is
   `CycleLog.spotting: Bool` (default false). It is not a flow level. On the calendar
   a spotting day without a period shows a small dot in the period colour at 40 %.
2. Tâm trạng — adds ★ `irritable` (Cáu gắt), `sad` (Buồn), `energetic` (Tràn đầy năng lượng).
3. Triệu chứng — cycle mode list becomes: cramps, headache, tenderBreasts, acne,
   bloating, cravings, ★ backPain, ★ insomnia, ★ nausea,
   ★ diarrhea (Tiêu chảy), ★ constipation (Táo bón), ★ dizziness (Chóng mặt).
   `Symptom.mode` becomes `modes: Set<AppMode>`; backPain, insomnia, nausea are in
   both. Display order per mode is an explicit list. No "fatigue" symptom: the
   existing mood `tired` covers it (no duplicate chip or pattern).
4. ★ **Quan hệ**: single choice chips "Không bảo vệ" / "Có bảo vệ", tap again to
   clear → `CycleLog.sexRaw: String?` (`SexLog`: unprotected, protected).
   ★ **Ham muốn**: Thấp / Bình thường / Cao → `sexDriveRaw` (`SexDrive`).
   Shown for every goal. On hormonal contraception the section is the same.
5. Dịch nhầy, LH, BBT (unchanged rules).
6. ★ **Que thử thai**: Âm tính / Dương tính → `pregnancyTestRaw` (`PregnancyTestResult`).
   Saving a day whose test changed to positive (cycle mode only) shows a prompt on the sheet's dismissal:
   "Chúc mừng! Bạn muốn chuyển sang theo dõi thai kỳ?" → opens the existing
   `ImPregnantSheet`; "Để sau" closes. Never switches mode by itself.
7. Ghi chú (unchanged).

`CycleLogRecord.isEmpty` / `hasContent` include the new fields (spotting, sex, sex
drive, test count as content). The spotting dot shows only on a day that is not a
logged or predicted period day. The day summary on
Today/calendar lists them with the existing chip style; sex shows as a heart glyph
only (no words) in the calendar day summary.

### 2. Insights (KickCore `CycleInsights`, pure, tested)

Input: periods, logs, forecast, today, calendar. Output:

- **Lengths chart:** last up to 12 completed cycles (oldest → newest), each with
  length and whether it counts toward the average. History draws a bar chart
  (Swift Charts) with a shaded 24–38-day band (the app's FIGO normal range) and the
  average as a rule. Needs ≥2 completed cycles; otherwise the existing "need more"
  text.
- **Regularity:** among the last up to 6 counted cycles (≥3 needed): spread =
  longest − shortest. ≤7 days → "Chu kỳ của bạn khá đều" (lengths vary by N days);
  8–9 → "Hơi dao động"; ≥10 → "Chu kỳ của bạn dao động khá nhiều" + the existing
  irregular-cycle advice line. (FIGO 2018: ≤7–9 days variation is normal.)
- **Patterns:** for each mood and symptom (and spotting), look at completed cycles
  among the last 6 that have at least one log. An item is a pattern when it appears
  in ≥3 of them and in ≥50 % of them. Its window uses the tighter of two anchors:
  days since period start ("ngày 1–2 của kỳ kinh") or days before the next period
  ("2–4 ngày trước kỳ kinh"). Window = the range covering ≥75 % of occurrences, at
  most 5 days wide; no window that wide → not a pattern. Up to 5 patterns, most
  consistent first. Copy: "Bạn hay {đau bụng} vào {ngày 1–2 của kỳ kinh}
  (3/4 chu kỳ gần đây)."
- **Today line:** if today (by the current cycle day, or days before the predicted
  next period when the forecast is not low-confidence) falls in a pattern's window,
  Today shows one line under the cycle card: "Mấy chu kỳ gần đây, bạn hay {đau đầu}
  vào khoảng thời gian này." The first such pattern only; hidden while paused,
  in pregnancy, or with no completed cycles.

History page order: averages (existing) → ★ chart → ★ regularity → ★ "Điều bạn hay
gặp" patterns (or an empty state "Ghi lại triệu chứng vài chu kỳ, Luna sẽ chỉ ra điều
bạn hay gặp") → cycle rows (existing). A footnote: "Đây là quan sát từ ghi chép của
bạn, không phải chẩn đoán."

### 2b. Insights — rulings (builder check)

- **Which cycles:** chart, regularity and patterns use `CycleHistory.cycles` only —
  no new filtering, no change to `CyclePredictor`. Chart: completed cycles, last ≤12,
  bar coloured by `countsTowardAverage`. Regularity: the same lengths the average uses
  (`countsTowardAverage`, last 6). Patterns: completed cycles with
  `countsTowardAverage`, last 6 — a pregnancy gap is far beyond 45 days, so it is
  never one of them. Only cycle-mode items count (`Symptom.modes` contains the cycle
  mode, all moods, spotting).
- **Denominator:** those cycles with at least one day log of any kind. A cycle with
  logs but not the item counts in the denominator.
- **Occurrence per cycle:** the item's first logged day in that cycle, as
  `startDay` (1 = period start) and `daysBefore` (cycle length − startDay + 1, so the
  last day of the cycle is 1).
- **Window per anchor:** the narrowest day range covering ⌈75 %⌉ of the occurrences.
  An anchor qualifies when that width ≤ 5 days. Both qualify → the narrower; tie →
  the nearer end of the cycle (`daysBefore` when its window starts lower, else
  `startDay`), so a late symptom never reads "day 26 of your period". A `startDay`
  window starting past day 7 is worded as a day of the cycle (CI-found). Neither → not a pattern. The chosen anchor is stored with the pattern
  and is the one the Today line tests.
- **Ranking:** ratio (cycles with item / denominator) desc, then window width asc,
  then the item's display order. Max 5.
- **Worked example:** 4 counted cycles with logs, lengths 28, 30, 27, 29. Headache on
  day 26 (c1), 28 (c2), 25 (c3), none (c4) → 3/4 = 75 % ≥ 50 %, ≥3 ✓. startDay
  {26,28,25} → ⌈2.25⌉=3 occurrences → window 25–28 (width 4). daysBefore {3,3,3} →
  window 3–3 (width 1) → chosen: "3 ngày trước kỳ kinh", "(3/4 chu kỳ gần đây)".
- **Today line:** needs a forecast. `startDay` patterns test `forecast.cycleDay`.
  `daysBefore` patterns test the days until `nextPeriodStart` (the last cycle day is 1), and only when the
  forecast is not low-confidence and not late (`daysLate == 0`). First matching
  pattern in ranking order. None while paused, in pregnancy or with no forecast.

### 3. App lock

- Profile → "Quyền riêng tư" → ★ **Khoá bằng Face ID** (Touch ID / "mật mã" by
  device). Shown only when `LAContext.canEvaluatePolicy(.deviceOwnerAuthentication)`.
  Turning it on authenticates first; failure leaves it off. Stored in app defaults
  (`SettingsKey.appLockEnabled`), not in backups.
- Lock moments: cold launch, and returning to foreground after ≥60 s in background,
  measured from `.background` (not `.inactive`: the Face ID prompt itself makes the
  scene inactive, which must never re-lock).
- If the toggle is on but the device can no longer evaluate the policy (passcode
  removed), the app opens unlocked and the toggle shows off — never a lockout.
  While the scene is inactive/background a plain cover (app icon on the background
  colour) hides content for the app switcher.
- Lock screen: icon, "Luna Mom đã khoá", button "Mở khoá"; auth runs automatically on
  appear. Cancel leaves the lock screen up.
- Covers everything including sheets and the birth celebration.
- Info.plist: `NSFaceIDUsageDescription` (vi/en via InfoPlist.xcstrings).
- Footer copy: "Widget và thông báo vẫn hiện như cài đặt của iPhone."
- UI tests (`-uiTesting`) never lock.

## Data & migration

`CycleLog` gains `spotting: Bool = false`, `sexRaw`, `sexDriveRaw`,
`pregnancyTestRaw: String?`. `CycleLogRecord`, `CycleLogDTO` mirror them (unknown raw
values kept as raw strings). Verify by opening a real 1.1 store (TestFlight build 37
data) with the new build before release.

## Testing

- KickCore: `CycleInsights` (chart, regularity bands, pattern thresholds, anchors,
  window width, today line), new raw enums, backup round trip incl. unknown values,
  `Symptom.cases(for:)` order per mode, `isEmpty` with new fields.
- UI: log spotting + sex + positive test → prompt appears; history shows chart and a
  pattern from a seeded `-uiTesting` dataset; lock is skipped in UI tests.
- Device check by the owner: Face ID lock, app switcher cover, migration of real data.

## Left to the builder

Chip glyphs, exact chart styling within the existing design system, the seed data
for UI tests, and where the lock overlay attaches if sheets are not covered (see
Approaches, Lock B).
