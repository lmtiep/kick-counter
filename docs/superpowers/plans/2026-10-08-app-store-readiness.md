# App Store readiness (Phase 12) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax. Task 2 also applies `ui-ux-pro-max` for the new Profile rows and dialog.

**Goal:**
- Version 1.0 keeps all data on the device. iCloud mirroring and partner sharing go behind `AppFeatures.cloudSync = false`, and the partner mode is hidden.
- The app gains "Xoá toàn bộ dữ liệu" and links to a privacy policy and a support page.
- The widget gets a privacy manifest, and the unused iCloud capabilities are removed.

**Architecture:**
- **KickCore (pure):** `AppFeatures` and `AppDataReset.clearDefaults`.
- **KickData:** `KickPersistence` reads the switch, and `DataReset` empties the store.
- **App:** gates every CloudKit path on the switch, wires the reset, and adds the links. The static pages live in `site/` and are published on a `gh-pages` branch.

**Spec:** `docs/superpowers/specs/2026-10-08-app-store-readiness-design.md` (binding). Audit: `docs/app-store-compliance.md`.

## Global Constraints

- **Branch.** Work on `feat/app-store-readiness`, which is already checked out in `/Users/macos/Documents/kick-counter`. Never change the `gh` account.
- **Approved edits.**
  - The owner approved, for this phase only, these edits:
    - `App/KickCounter.entitlements` and the `entitlements:` of `project.yml`: remove `aps-environment`, `com.apple.developer.icloud-container-identifiers` and `com.apple.developer.icloud-services`; keep `com.apple.security.application-groups`;
    - `project.yml` Info properties: remove `UIBackgroundModes: [remote-notification]` and `CKSharingSupported`;
    - the widget target's resources in `project.yml`, to add its privacy manifest.
  - No edits to `.github/workflows/*`, `scripts/ci.sh` or `scripts/test-core.sh`.
- **KickCore imports.** `KickCore` must not import SwiftUI, UIKit, SwiftData or CloudKit.
- **Strings.** Only through `scripts/add-strings.py` (en + vi, northern Vietnamese). Never `Text("literal")`.
- **Tokens.**
  - Colours: Luna tokens only. Destructive text uses the existing destructive/warning token that `LunaContrast.usages` already lists for text on `card`. Find it with `grep -n "warning\|destructive" Packages/KickCore/Sources/KickCore/LunaPalette.swift`.
  - Fonts: `Font.luna(_:)` only.
- **Local verification.**
  - Run `scripts/test-core.sh`, KickData `swift test` (in `Packages/KickData`, the same way `scripts/ci.sh` runs it), `xcodegen generate --quiet`, and `xcodebuild … -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO -quiet build-for-testing` on 'iPhone 18 Pro'.
  - Never run UI tests locally. Never open Xcode.
- **Commits.**
  - Message, blank line, then a `CI-Only-Testing: ClassA,ClassB` line (comma-separated), immediately followed by `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  - After that: `git push`, then `scripts/ci-wait.sh`.
  - Task 3 has **no** final full run of its own: the PR runs the sharded full suite.
- **Do not push while a CI run for this branch is in progress.** A new push cancels it.

## Task 1: Switch, persistence, data reset (KickCore + KickData)

**Files:**
- Create `Packages/KickCore/Sources/KickCore/AppFeatures.swift`.
- Create `Packages/KickCore/Sources/KickCore/AppDataReset.swift`.
- Create `Packages/KickCore/Tests/KickCoreTests/AppFeaturesTests.swift` and `AppDataResetTests.swift`.
- Modify `Packages/KickData/Sources/KickData/KickPersistence.swift`.
- Create `Packages/KickData/Sources/KickData/DataReset.swift` and a test in `Packages/KickData/Tests/…`; match the existing KickData test layout and style.

**Produces:**
- `public enum AppFeatures { public static let cloudSync = false }`, with a doc comment on App Review 5.1.3(ii) and what to restore when it is turned on (spec §3.3).
- `public enum AppDataReset { public static let ownedKeys: [String]; public static func clearDefaults(_ defaults: UserDefaults) }`.
  - `ownedKeys` is every `SettingsKey` constant: read `Settings.swift` and the other files that define defaults keys with `grep -rn "static let .* = \"" Packages/KickCore/Sources`. Include the keys used by `CyclePreferences`, `AppLanguage`, partner state and the reminders.
  - `clearDefaults` removes exactly those keys.
- `public enum DataReset { @MainActor public static func deleteAll(in container: ModelContainer) throws }`. It deletes every instance of each model in `KickPersistence.schema` and saves.

**Steps (TDD):**
- [ ] Write the tests first:
  - `cloudSyncIsOffForVersion1`: `#expect(AppFeatures.cloudSync == false)`.
  - `clearDefaultsRemovesOwnedKeysOnly`: use a `UserDefaults(suiteName: "test-\(UUID())")`. Set every owned key plus a foreign key, call `clearDefaults`, and check every owned key is nil and the foreign key is intact.
  - `ownedKeysCoverEverySettingsKey`: use reflection or a maintained list. **Simplest:** parse `Settings.swift` (`#filePath` relative), collect the string values of `public static let … = "…"` in `enum SettingsKey`, and check they are a subset of `ownedKeys`.
  - KickData `deleteAllEmptiesEveryModel`: use an in-memory container (`KickPersistence.makeContainer(inMemory: true)`). Insert one of each model, call `deleteAll`, and check every fetch count is 0.
- [ ] See them fail. Implement.
- [ ] Change `KickPersistence.makeContainer` to `cloudKitDatabase: AppFeatures.cloudSync ? .automatic : .none` for the on-device store, and update its doc comment.
- [ ] Run local verification, then commit with `CI-Only-Testing: KickCounterUITests`, push and ci-wait.

## Task 2: App, the partner mode hidden, sharing off, delete all, links, capabilities, widget manifest

**Files to modify:**
- `App/AppEnvironment.swift` (`makeSharing`).
- `App/Partner/PartnerAppDelegate.swift`.
- `App/RootView.swift`.
- `App/Profile/ProfileView.swift`.
- `App/KickCounter.entitlements`.
- `project.yml`.
- `Shared/L10n.swift` and `Shared/Localizable.xcstrings`.

**Files to create:**
- `App/Partner/DisabledPartnerSharing.swift`.
- `App/AppLinks.swift`.
- `Widgets/PrivacyInfo.xcprivacy`.
- UI tests `UITests/AppStoreReadinessUITests.swift` and screenshots in `UITests/ScreenshotTests.swift` or a new `AppStoreReadinessScreenshotTests.swift`.

**Steps:**
- [ ] **`DisabledPartnerSharing`** conforms to `PartnerSharing`. Each method throws `PartnerSharingError.iCloudUnavailable`, except `shareStatus`, which returns `.notShared`, and `fetchSharedSnapshot`, which returns nil. Mirror the protocol exactly: read `Packages/KickCore/Sources/KickCore/PartnerSharing.swift`. `makeSharing()` returns it when `!AppFeatures.cloudSync`, outside UI tests. UI tests keep their fake.
- [ ] **`PartnerAppDelegate`.**
  - Call `registerForRemoteNotifications` only when `AppFeatures.cloudSync`.
  - The scene delegate's share-metadata handling becomes a no-op (logged) when it is false.
  - Remote-notification handling stays harmless.
- [ ] **Stored partner mode** (spec §3.2). In `RootView` (or wherever the launch reads the mode, likely `.task`/`init`), when `AppMode.load == .partner && !AppFeatures.cloudSync`:
  - set `hasCompletedOnboarding = false`;
  - store a non-partner mode (`.pregnant` default, or whatever onboarding expects);
  - show onboarding.

  Add a UI-test launch argument that seeds the stored mode `partner` without the fake partner sharing, if none exists. Reuse `-seedAppMode` if present: `grep -n "seed" App/AppClock*.swift App/AppEnvironment.swift`.
- [ ] **Profile.**
  - Hide the pregnancy partner-sharing card and every partner entry in the mode picker when `!AppFeatures.cloudSync`. Find them with `grep -n -i partner App/Profile/*.swift`.
  - Add to the "Thông tin" section, near `MedicalInfoView`, two `Link` rows: "Chính sách quyền riêng tư" (`profilePrivacyPolicy`) and "Hỗ trợ" (`profileSupport`). Their URLs come from `AppLinks.privacyPolicy` and `AppLinks.support`, using the spec URLs. Add an `arrow.up.right` accessory and a hint that the link opens in Safari.
  - Add the last section: a destructive button "Xoá toàn bộ dữ liệu" (`profileDeleteAllData`). It opens `.confirmationDialog` or `.alert` with the spec texts and the buttons "Xoá" (`deleteAllConfirm`, destructive) and "Huỷ".
  - On confirm:
    1. `DataReset.deleteAll(in:)` on the app's container;
    2. `AppDataReset.clearDefaults(AppGroup.defaults)`;
    3. `UNUserNotificationCenter` removes all pending and delivered notifications;
    4. end any Live Activities (`Activity<…>.activities`);
    5. reload the coordinators;
    6. show onboarding (whatever `hasCompletedOnboarding == false` triggers).

    On failure, show an alert and leave the data as it is.
- [ ] **Strings** (add with the script). Keys: `settings.privacyPolicy`, `settings.support`, `settings.opensInSafari`, `settings.deleteAll`, `settings.deleteAll.title`, `settings.deleteAll.message`, `settings.deleteAll.confirm`, `settings.deleteAll.failed`. Use the vi text from the spec; for en:
  - "Privacy policy";
  - "Support";
  - "Opens in Safari";
  - "Delete all data";
  - "Delete all data?";
  - "All kick counts, periods, logs, weights, appointments and settings on this iPhone will be permanently deleted. This can't be undone.";
  - "Delete";
  - "Couldn't delete the data. Please try again."

  The vi for `failed` is "Không xoá được dữ liệu. Bạn thử lại nhé."
- [ ] **Capabilities.** Make the approved entitlement and `project.yml` edits (Global Constraints). Then:
  - `xcodegen generate --quiet`;
  - check the generated entitlements have only the App Group;
  - `grep -rn "CKSharingSupported\|remote-notification" App/Info.plist project.yml` prints nothing.
- [ ] **Widget manifest.** Create `Widgets/PrivacyInfo.xcprivacy` (spec §3.6), copying the structure of `App/PrivacyInfo.xcprivacy`, and add it to the widget target's resources in `project.yml`.
- [ ] **UI tests.**
  - `testPregnancyProfileHasNoPartnerSharing`.
  - `testModePickerHasNoPartnerEntry`.
  - `testStoredPartnerModeShowsOnboarding`.
  - `testDeleteAllDataReturnsToOnboarding`: seed cycles, open Profile, delete, confirm. Expect the onboarding welcome. Finish onboarding into the cycle mode and expect no logged periods (empty state).
  - `testPrivacyAndSupportLinks`: the rows exist. If the URL is exposed through `accessibilityValue`/identifier, assert it; otherwise only that they exist and are buttons or links.

  Screenshots: `profile-info-links-vi-light`, `profile-info-links-vi-dark`, `profile-delete-dialog-vi-light`, `ax5-profile-delete-vi-light`.
- [ ] **Existing UI tests.** Partner tests (`PartnerUITests`, `PartnerShareUITests`, `PartnerScreenshotTests`) assume the partner UI. In UI-test builds, keep the partner paths reachable when a test explicitly launches with the partner fakes. Gate the hiding on `!AppFeatures.cloudSync && !launchOptions.forcesPartnerUI`, adding a DEBUG-only `-uiTestingPartnerUI` flag passed by those tests' launch helper. Explain this in the commit. The alternative, deleting those tests, loses coverage for when the switch comes back. Run them in this task's CI scope.
- [ ] Run local verification. Commit with `CI-Only-Testing: AppStoreReadinessUITests,AppStoreReadinessScreenshotTests,PartnerUITests,PartnerShareUITests,ProfileUITests,ProfileGoalUITests,OnboardingUITests` (adjust to the real class names you create). Push, ci-wait, and Read the screenshots.

## Task 3: Site, publish, docs

- [ ] **Pages.** `site/index.html`, `site/privacy.html` and `site/support.html` follow spec §3.5:
  - static and self-contained, with inline CSS;
  - Luna palette from `LunaPalette.swift`, with `prefers-color-scheme` dark;
  - vi first, then en, each with an anchor;
  - effective date 2026-10-08;
  - contact lmtiep@gmail.com;
  - `site/.nojekyll`.

  The privacy text must match the app as it is: no collection, on-device only, iPhone backup, local notifications, deleting data, a disclaimer, and a statement that there are no children's accounts. Mention that a future iCloud option would be opt-in and the policy would be updated first.
- [ ] **Publish.** Do this only after the owner allows it; the controller handles it, and the implementer does not publish. The controller creates an orphan `gh-pages` branch containing only the `site/` files and pushes it.
- [ ] **`docs/app-review-notes.md`:** spec §3.7, in English, ready to paste.
- [ ] **`docs/app-store-compliance.md`:** mark the items this phase resolves and leave the owner's items open.
- [ ] **`docs/release-checklist.md`:** add a "Giai đoạn 12" block covering:
  - Pages enabled and URLs live;
  - App Store Connect fields: Privacy Policy URL, Support URL, App Privacy "Data Not Collected", age rating, EU trader status, review notes;
  - the manual on-device check (spec §4);
  - how to restore iCloud: `cloudSync = true`, the entitlements and Info keys back, the CloudKit Production schema, and an updated privacy policy.
- [ ] **README:** add a "Sẵn sàng lên App Store (giai đoạn 12)" section.
- [ ] Commit with `CI-Only-Testing: AppStoreReadinessUITests`, push and ci-wait.
