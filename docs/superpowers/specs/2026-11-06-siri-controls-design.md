# Siri, Action Button and Control Center: short design

Date: 2026-11-06 · Status: approved by owner in chat · Branch: `feat/siri-controls`

## Intent
Starting a kick count or tapping a contraction **without unlocking or opening
the app, one-handed, while in pain**. This deepens the Live Activity strength
that is already there. Competitors advertise Lock Screen and Control Center
control.

## Design (approved)

**Intents** (App Intents, run in the background through the existing bridges
`KickIntentBridge` and the contraction bridge, like
`AddKickIntent`/`ToggleContractionIntent`)
1. **"Bắt đầu đếm cử động" / "Start counting kicks".** It starts a session,
   or adds a kick if a session is running (decide by what reads best; state
   it in the report). The Live Activity appears.
2. **"Bấm cơn gò" / "Time a contraction".** It toggles: start, or end the
   running contraction.
3. **"Kết thúc theo dõi cơn gò" / "Stop timing contractions".** It ends the
   episode.

**Where they are available**
- `AppShortcutsProvider` with vi and en phrases, so they work from Siri,
  Spotlight and Shortcuts with no setup. The phrases contain the app name
  ("…trong Luna Mom").
- **Controls (iOS 18+ only):** `ControlWidgetButton`s for intents 1 and 2 in
  the widget extension, behind `@available(iOS 18, *)`. On iOS 17 the app
  still runs and these are simply missing. The **Action Button** can then
  run a control or shortcut; this needs no extra code beyond the
  controls/shortcuts.

**Behaviour**
- **Outside pregnancy mode:** the intent returns a short spoken/dialog result
  and opens the app on Today. It never starts anything.
- **Results:** intents give a short dialog result, for example "Đã bắt đầu
  đếm. Chạm vào thẻ trên màn hình khoá để thêm cử động." or "Cơn gò đang
  tính giờ.". **No medical wording.**
- **Privacy:** results must not read out health numbers on a locked device
  beyond what the Live Activity already shows. Keep them generic.

## Constraints
- The strings for the phrases live in `AppShortcuts.xcstrings` if needed
  (App Shortcut phrases require it). The other strings go through
  `add-strings.py`.
- Swift 6 concurrency.
- Never run UI tests locally.
- Device-only parts (Siri voice, Action Button, Control Center) go into the
  release checklist.

## Tests
- **KickCore:** the intent decision logic, as a pure function: mode and state
  in, action out.
- **App/UI:** run each intent's `perform()` through a test seam, or launch
  with a DEBUG argument that invokes it, and assert the coordinator state.
- **Build:** for an iOS 17 simulator destination as well, so the
  availability gates compile.
