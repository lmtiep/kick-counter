# App Store readiness (Phase 12)

Date: 2026-10-08 · Status: approved in conversation · Branch: `feat/app-store-readiness`

## 1. Goal

Remove the blockers that `docs/app-store-compliance.md` found before the first App Store submission. The most important is App Review Guideline 5.1.3(ii): apps "may not store personal health information in iCloud".

## 2. Decisions made with the user

| Topic | Decision |
|---|---|
| iCloud | **Version 1.0 keeps all data on the device.** No SwiftData/CloudKit mirroring, and the partner mode is hidden. The code stays, behind one switch, so a later version can bring it back |
| Login | None. There are no accounts, so neither Sign in with Apple nor account deletion is needed |
| Privacy policy and support pages | Static bilingual (vi/en) pages on **GitHub Pages**, published from a `gh-pages` branch that holds only those pages. The contact address is lmtiep@gmail.com |
| Other blockers | Doctor review of the medical content and the final app icon remain the owner's tasks before submission. They are not part of this phase |

## 3. Behaviour

### 3.1 The cloud switch

- `KickCore`: `public enum AppFeatures { public static let cloudSync = false }`. It is a single compile-time constant, documented as the 5.1.3(ii) decision.
- `KickPersistence.makeContainer`: uses `cloudKitDatabase: AppFeatures.cloudSync ? .automatic : .none`.
  - The on-device store, its App Group path and its schema are unchanged, so existing data on the device stays.
  - Data already in iCloud is neither deleted nor read.
- `AppEnvironment.makeSharing()`: when `cloudSync` is false, returns a `DisabledPartnerSharing`. It never touches CloudKit and reports `.iCloudUnavailable` / `.notShared`. `CloudPartnerSharing` is not created.
- `PartnerAppDelegate`:
  - share acceptance and registration for remote notifications only run when `cloudSync` is true;
  - an incoming share link is ignored.

### 3.2 Partner mode is hidden

- Profile:
  - the pregnancy "Chia sẻ với bố bé" card is not shown;
  - in the mode picker, every entry that leads into the partner mode or its explanation is hidden.
- **Stored mode `partner`.** At launch, a stored mode `.partner` with `cloudSync` false is treated as "not onboarded": `hasCompletedOnboarding` is reset, so onboarding asks for a goal. This is the case of the owner's partner, who is a TestFlight user. No other data is touched.
- **Onboarding** has no partner entry today, which is confirmed by test.

### 3.3 Info.plist and entitlements (owner approval needed)

When `cloudSync` is false, the app must not declare capabilities it no longer uses (guideline 2.5.4: background modes must be used for their purpose). These are removed:
- `UIBackgroundModes: [remote-notification]`;
- `CKSharingSupported`;
- the `aps-environment`, `icloud-container-identifiers` and `icloud-services` entitlements.

The App Group entitlement is kept.

These are entitlement and `project.yml` changes, so the owner approves them explicitly. Approval was given as part of this spec. The release checklist records how to restore them together with `cloudSync = true`.

### 3.4 Delete all data

- **Where.** Profile → a new row at the bottom, "Xoá toàn bộ dữ liệu" (destructive style).
- **Confirmation.** It opens a confirmation dialog:
  - title "Xoá toàn bộ dữ liệu?";
  - message "Mọi lượt đếm cử động, kỳ kinh, ghi chép, cân nặng, lịch khám và cài đặt trên iPhone này sẽ bị xoá vĩnh viễn. Không thể hoàn tác.";
  - buttons "Xoá" (destructive) and "Huỷ".
- **What it deletes:**
  - every model in the SwiftData store (`KickSession`, `Kick`, `Appointment`, `PeriodEntry`, `CycleLog`, `WeightEntry`);
  - every App Group defaults key the app owns (modes, settings, preferences, onboarding, language, partner state);
  - all pending and delivered local notifications;
  - any running Live Activity.

  Then the app returns to onboarding.
- **Where the logic lives.** `DataReset` in `KickData` holds the store part, with a test that uses an in-memory container. The defaults part is a `KickCore` function, `AppDataReset.clearDefaults(_:)`, tested with a suite-named `UserDefaults`. The app wires the two together.

### 3.5 Privacy policy and support

- **In-app links.** Profile, "Thông tin" section, gets two rows that open in Safari (`Link`):
  - "Chính sách quyền riêng tư" → `https://lmtiep.github.io/kick-counter/privacy.html`;
  - "Hỗ trợ" → `https://lmtiep.github.io/kick-counter/support.html`.

  The URLs live in one place (`AppLinks`).
- **Pages.** `site/index.html`, `site/privacy.html` and `site/support.html` are kept in the repo under `site/`. They are plain HTML with inline CSS, the Luna palette, light and dark, and no scripts or trackers.
  - Each page has vi and en sections, with a language switch by anchor link.
  - The privacy policy says:
    - Data Not Collected, with no server, analytics, ads or tracking;
    - all data stays on the device (App Group) and in the user's iPhone backup;
    - notifications are local;
    - how to delete data (the in-app button, or deleting the app);
    - the app is for information, not diagnosis;
    - contact details and an effective date.
  - Support has the contact email, an FAQ (no account needed, data on device, deleting data, notifications) and the medical disclaimer.
- **Publishing.** The contents of `site/` are pushed to a `gh-pages` branch. The owner enables GitHub Pages (Settings → Pages → branch `gh-pages`, root), or Claude enables it through the API if the owner allows it.

### 3.6 Widget privacy manifest

Add `Widgets/PrivacyInfo.xcprivacy` with the following, and include it in the widget target's resources in `project.yml`:
- `NSPrivacyTracking` false;
- no collected data types;
- `NSPrivacyAccessedAPICategoryUserDefaults` with reason `1C8F.1` (the App Group).

### 3.7 Review notes and documents

- `docs/app-review-notes.md` holds ready-to-paste text in English for App Store Connect:
  - what the app does;
  - that there is no login;
  - that all data stays on the device (no iCloud, per 5.1.3(ii));
  - the sources for the medical content and the in-app disclaimers;
  - how to reach each mode (onboarding choices);
  - notifications;
  - the Live Activity.
- `docs/app-store-compliance.md`, the audit, is committed and updated with what this phase fixes.
- `docs/release-checklist.md` gets a "Giai đoạn 12" block covering:
  - Pages enabled and both URLs live;
  - URLs entered in App Store Connect;
  - App Privacy set to "Data Not Collected";
  - the age-rating questionnaire;
  - the EU trader status;
  - the review notes;
  - what to restore to bring iCloud back.

## 4. Testing

- **KickCore:**
  - `AppFeatures.cloudSync == false` (a guard test, so turning it on is a deliberate change);
  - `AppDataReset.clearDefaults` clears every owned key and leaves foreign keys.
- **KickData:** `DataReset` empties every model type.
- **UI tests:**
  - Profile shows no partner card in pregnancy mode;
  - the mode picker has no partner entry;
  - a launch with stored mode `partner` lands in onboarding;
  - "Xoá toàn bộ dữ liệu" with seeded data → confirm → onboarding, and after finishing onboarding no data is left;
  - the privacy and support rows exist with the right URLs.
- **Screenshots:** the Profile "Thông tin" rows and the delete dialog, in vi light/dark and AX5.
- **Manual (on the owner's device, release checklist):**
  - install over the TestFlight build and check that existing data is still there;
  - no iCloud prompt appears;
  - the pages open.

## 5. Delivery

1. KickCore/KickData: the switch, the persistence change, the data reset, and tests.
2. App: hide the partner mode, sharing disabled, the delete-all flow, the privacy and support links, the plist/entitlement/project changes, the widget manifest, UI tests and screenshots.
3. Site and docs: the pages, the `gh-pages` publish, the review notes, the compliance doc, the release checklist and README. The final PR runs the full suite (sharded).
