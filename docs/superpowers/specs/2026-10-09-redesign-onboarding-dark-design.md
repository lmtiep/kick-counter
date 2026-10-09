# New onboarding and new dark mode (Phase 18)

Date: 2026-10-09 · Status: owner's design handoff, to build as specified · Branch: `feat/redesign-2026-10`

The source of truth is the owner's handoff, copied to `docs/design/handoff-2026-10-09/`. Its `README.md` gives exact values: colours, sizes, copy and animation. Open the `.dc.html` files in a browser, with `support.js` beside them, to see the designs. This spec only records how they map onto the codebase, and the decisions the handoff leaves open.

## 1. Onboarding (light only)

- **Light only.** The whole onboarding cover is always light: `.preferredColorScheme(.light)` on the cover, including the language segment and sheets shown from it, such as the restore sheet when it is presented over onboarding.
- **Frame for every step**, as in handoff §1:
  - cream background `#FFFAF2`;
  - top bar: progress dots in a pill; a back button and "Bỏ qua" from step 2 on; on step 1, the VI/EN segment instead of the back button;
  - the illustration area **fully visible, never cropped** (`scaledToFit`, top-aligned), with a 16 % bottom fade and the drifting wave band;
  - the text block at the bottom, and the primary button `#B4583A`;
  - the animations reveal, kenBurns, waveRise, waveDrift and contentUp. With Reduce Motion (and `LunaMotion.isEnabled == false` in UI tests), drift and Ken Burns are off and only the fades remain.
- **Step 1 (welcome)** follows handoff §1, "Màn 1":
  - the new copy: welcome, welcomeSub, the privacy line with a lock icon, the medical line with "!";
  - "Bắt đầu";
  - the "Khôi phục từ bản sao lưu" link (Phase 15), restyled as specified;
  - image `luna-goal-s` (mother holding her baby).
- **Step 2 (goal)** follows handoff §1, "Màn 2":
  - three cards with the given colours and radio style;
  - "Tiếp tục" disabled until a goal is chosen, which matches the current flow's behaviour;
  - image `luna-due-s` (woman with a book).
- **Steps 3–8** use the same frame and the handoff's card and input style: white cards with radius 18, text `#3A2A24` / `#7A6B64`, and buttons in `#B4583A` instead of the old black. They keep each step's current content, logic and accessibility identifiers. Illustrations by step:
  - cycle steps: `OnboardingTrack` / `OnboardingConceive`, as in Phase 9 / PR #26;
  - due-date steps: the existing `OnboardingDue` photo, until its illustration arrives. Show it with the same frame.
- **Images.** Images are now shown uncropped, so the illustrations should not carry the extra top padding added in PR #26. Re-export:
  - `OnboardingWelcome` and `OnboardingGoal` from the handoff's high-resolution PNGs, at about 1170 px wide, pngquant'd, transparent background kept;
  - `OnboardingTrack` and `OnboardingConceive` with their original illustration crop, without the 300 px top pad.
- **Copy.** Use the handoff's vi and en strings for these keys: welcome, welcomeSub, privacy, medical, start, restore, goalQ, the goal titles and subtitles, continue and skip. Change them through `scripts/add-strings.py`. Remove keys that become unused.
- **Doctor doc.** Add the changed medical line ("Không thay thế bác sĩ. Bé cử động ít bất thường? Gọi bác sĩ ngay.") as a new item to confirm.

## 2. Main screens: the new dark mode

- **Light mode is unchanged.**
- **Dark mode values** move to handoff §3 for every Luna token, using the mapping table: `bg`, `surface`, `surfaceSunken`, `divider`, text levels, `accent` / `accentText` / `accentSoft`, alert, fertile and ovulation, ring track, avatar and toggle. The pregnancy colours in dark mode follow the same approach: soft, light accents on indigo glass. Keep the pregnancy hue family (warm peach/terracotta, lightened for dark), and check every pair in the contrast tests.
- **Background.** Dark mode uses the indigo gradient `linear-gradient(165deg, #5E6392 0%, #4E5481 45%, #474C72 100%)` with the optional soft glows on Today. Build it as a reusable `LunaBackground` view or modifier, used wherever `.luna(.background)` fills a screen today, in both modes: light stays the flat colour.
- **Surfaces.** Glass cards: white at 9 %, a 1 px white border at 14 %, radius 24 in dark mode. Light keeps its 20 radius. A backdrop blur on cards is optional; skip it if it costs performance.
- **Tab bar** (dark, required): a floating pill with `.ultraThinMaterial` tinted indigo `rgba(58,62,98,.72)`, a white 16 % border and a shadow. The selected tab is `rgba(247,166,180,.22)` with `#FFC4CE` at weight 600; the others `#DCDDF0`. Light mode keeps the current tab bar.
- **Contrast.** `LunaContrast.usages` / `ContrastTests` must pass with the new dark values: at least 4.5:1 for body text and 3:1 for large text. Against the gradient, evaluate the lightest stop `#5E6392` and the darkest `#474C72`. Translucent surfaces are composited over the gradient for the check.
- **Widgets and Live Activity.** They follow the same dark tokens wherever they read Luna tokens. A gradient is not required in widgets.
- **Scope.** Every main screen, sheet and overlay follows the tokens: Today (cycle and pregnancy), Calendar, History, Kicks, Weight, Knowledge, Profile, every sheet, alerts and toasts. No hard-coded colours.

## 3. Testing

- **KickCore:** `ContrastTests` updated, plus tests for any new tokens.
- **UI:** the existing suites still pass, and the onboarding identifiers are kept.
- **Screenshots:**
  - the new onboarding steps 1–8 in vi and en, light only, with one AX5 run;
  - a dark-mode screenshot set of the main screens, re-read by eye against `Mam Dark Mode.dc.html`.
- **Snapshots of the handoff:** render the three `.dc.html` files with headless Chrome into `docs/design/handoff-2026-10-09/renders/`, to compare side by side.

## 4. Delivery

1. Onboarding: the frame, steps 1–2, steps 3–8 restyle, images, copy, animations and light-only. With UI tests and screenshots.
2. Dark mode: tokens, background, surfaces, tab bar, contrast tests, every screen. With screenshots.
3. Docs: README, release checklist and doctor item. The PR runs the full suite.
