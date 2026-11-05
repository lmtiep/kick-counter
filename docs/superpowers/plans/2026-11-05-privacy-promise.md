# Privacy promise messaging Implementation Plan

> For agentic workers: implement task by task; spec `docs/superpowers/specs/2026-11-05-privacy-promise-design.md` is binding.

**Global constraints:** branch `feat/privacy-promise`; strings only via `scripts/add-strings.py` (vi northern + en); Luna tokens / `Font.luna` / `OnboardingPalette` only; never "bất thường"/"abnormal"; verify with `scripts/test-core.sh`, `xcodegen generate --quiet`, build-for-testing on 'iPhone 18 Pro'; never run UI tests locally; commit trailer `CI-Only-Testing: <touched UI test classes>` + `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; push, `scripts/ci-wait.sh`, read the downloaded screenshots (`sips -Z 900`).

## Task 1: Onboarding four promise lines
- Files: `App/Onboarding/OnboardingView.swift` (welcome step, `commitment(...)` around line 308), strings, `UITests/OnboardingUITests.swift` (+ screenshot tests that cover the welcome step).
- Replace `onboarding.privacy` row with four rows (identifiers in spec); remove the now-unused key with `add-strings.py --remove`.
- Check AX5 and en/vi screenshots for clipping.

## Task 2: Profile "Your privacy" screen
- Files: new `App/Settings/PrivacyPromiseView.swift`, `App/Profile/ProfileView.swift` (`aboutCard`), strings, a UI test asserting `profilePrivacyPromise` opens the screen and shows the four points.
- Link at the bottom to `AppLinks` privacy policy URL.

## Task 3: Docs
- README line; `docs/app-store-listing.md` Promotional Text vi/en leading with the four points (≤170 chars each; give char counts); release checklist line.
