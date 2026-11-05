# Home widgets Implementation Plan
> Spec `docs/superpowers/specs/2026-11-05-home-widgets-design.md` is binding.

**Global constraints:** branch `feat/home-widgets`; KickCore pure (no SwiftUI/UIKit/SwiftData/CloudKit/WidgetKit); strings via `scripts/add-strings.py`; Luna tokens only; verify `scripts/test-core.sh`, `xcodegen generate --quiet`, build-for-testing on 'iPhone 18 Pro'; never run UI tests locally; trailer `CI-Only-Testing: <classes>` + `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; push + `scripts/ci-wait.sh`.

## Task 1 (TDD): KickCore `WidgetSnapshot` (inputs: mode, goal, settings, periods/logs or forecast, due date, today's kick count, now, calendar → display model + next refresh date).
## Task 2: Widget extension — `LunaWidget` (families per spec), data loading from App Group (read-only SwiftData + defaults; check how the widget target links KickData/SwiftData and the store URL), `.privacySensitive()` on accessory, deep links handled in the app (`onOpenURL`), register in `KickCounterWidgetsBundle`.
## Task 3: App — `WidgetCenter.shared.reloadAllTimelines()` at the change points in the spec (small helper, called from coordinators' App-side wrappers, not from KickCore).
## Task 4: Render previews (vi/en, light/dark, small/medium/accessory) to PNGs for review (e.g. a DEBUG-only snapshot test or ImageRenderer in a unit test target); README, release checklist.
