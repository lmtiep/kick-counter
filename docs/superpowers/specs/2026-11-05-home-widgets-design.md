# Home Screen and Lock Screen widgets (1.1, item 3)

Date: 2026-11-05 · Status: approved in conversation · Branch: `feat/home-widgets`

## Why
Keep Luna Mom in view every day without opening it (competitors have widgets; Luna Mom
has only the two Live Activities).

## Design
- **One adaptive widget "Luna Mom"** whose content follows the current mode (AppMode +
  cycle goal); switching mode changes it, never leaves it empty. If onboarding isn't done
  or data is missing: a neutral "Mở Luna Mom để bắt đầu" state.
- **Families:** systemSmall, systemMedium; Lock Screen accessoryRectangular and
  accessoryInline (accessoryCircular optional if it reads well).
  - Cycle tracking — small: days to next period + date ("Kỳ kinh · 5 ngày · 18/11"; during a
    period: "Ngày 2 kỳ kinh"; late: "Trễ 3 ngày"). Medium: plus a cycle ring/progress and
    cycle day.
  - Trying to conceive — small: today's fertility status ("Dễ thụ thai cao" / "Ngày rụng
    trứng dự kiến" / "Ngoài cửa sổ") + cycle day. Medium: plus the fertile-window strip.
  - Pregnant — small: "Tuần 30" + "còn 70 ngày". Medium: plus the week's fruit art and
    "Cử động hôm nay: 6" (tap → Kicks).
  - Partner/other or no data: neutral state.
  - Wording reuses the app's existing strings/logic (CyclePredictor/forecast, PregnancyTimeline,
    kick counts) — same numbers as Today, labelled as estimates where Today does.
- **Taps:** deep links (`widgetURL`/`Link`) open Today, or Kicks for the kick line.
- **Lock Screen privacy:** accessory content uses `.privacySensitive()` so iOS redacts it
  while the phone is locked.
- **Updates:** timeline with an entry at the next local midnight (and the next prediction
  boundary if earlier); the app calls `WidgetCenter.shared.reloadAllTimelines()` after
  period/log changes, kick session changes, mode/goal/settings changes, restore and
  delete-all. Data read on-device from the App Group (defaults + SwiftData store, read-only);
  nothing leaves the device.
- **Look:** Luna tokens and fonts (light and the new dark: pink accents in both modes for
  pregnancy in dark), containerBackground, supports tinted/accented rendering mode
  (`widgetAccentable` on key text) and StandBy.
- Strings via add-strings (vi + en). No "bất thường".

## Approaches
Chosen: one adaptive widget. Rejected: one widget per mode (users add the wrong one; it goes
empty after a mode switch) and an interactive widget with buttons (kick counting already has
the Live Activity; adds complexity).

## Testing
KickCore: a pure `WidgetSnapshot` builder (mode → display model) tested per mode/edge
(no data, period today, late, fertile day, ovulation day, week 4 and week 41+, kicks 0).
Widget previews rendered to PNG for vi/en light/dark/tinted where practical; device checks
in the release checklist (add widget, switch mode, midnight rollover, lock screen redaction).
