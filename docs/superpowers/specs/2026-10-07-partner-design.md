# Partner sharing ("Bạn đời") via iCloud (Phase 8)

Date: 2026-10-07 · Status: approved in conversation · Branch: `feat/partner`

## 1. Goal

A mother in pregnancy mode can invite her partner through an iCloud share link. The partner installs Luna Mom, accepts the invite, and the app switches to a read-only **Partner mode**. That mode shows:
- the pregnancy week and the countdown to the due date;
- the baby's size;
- upcoming appointments;
- a summary of kick counts.

The data updates automatically through iCloud, and the mother can stop sharing at any time.

## 2. Decisions made with the user

| Topic | Decision |
|---|---|
| How | The partner installs the app and accepts an iCloud (CloudKit) share invitation |
| Rights | Read-only, curated data only. No symptoms, weight or notes. Mother can stop sharing |
| Architecture | Approach A: a separate shared custom zone holding one curated **snapshot** record. The existing SwiftData store and its private CloudKit sync are untouched |
| Out of scope | Push notifications to the partner, partner edits, more than one partner, sharing in trying-to-conceive mode |

## 3. Data

### 3.1 `PartnerSnapshot` (KickCore, pure)

```swift
public struct PartnerSnapshot: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    public var version: Int                       // decoding tolerates unknown future fields
    public var updatedAt: Date
    public var displayName: String                // what the partner sees, default "Mẹ" / "Mom" (localized at build time)
    public var dueDate: Date                      // start of day, the mother's calendar
    public var appointments: [PartnerAppointment] // upcoming only, ascending, ≤ 5
    public var kicks: PartnerKickSummary
}
public struct PartnerAppointment: Codable, Equatable, Sendable {
    public var title: String
    public var date: Date
    public var location: String?                  // never notes
}
public struct PartnerKickSummary: Codable, Equatable, Sendable {
    public var lastSession: PartnerKickSession?   // most recent completed session
    public var sessionsLast7Days: Int
    public var averageMinutesLast7Days: Double?   // nil when there are no sessions
}
public struct PartnerKickSession: Codable, Equatable, Sendable {
    public var startedAt: Date
    public var kicks: Int
    public var durationMinutes: Double
}
```

**Encoding.** JSON with ISO-8601 dates.

**Decoding.**
- A snapshot whose `version` is greater than `currentVersion` still decodes the fields it knows.
- A snapshot that cannot be decoded at all counts as "unavailable"; the partner screen shows the error state and does not crash.

### 3.2 `PartnerSnapshotBuilder` (KickCore, pure)

`PartnerSnapshotBuilder.make(dueDate:appointments:sessions:displayName:now:calendar:) -> PartnerSnapshot` takes plain value inputs, i.e. the existing KickCore record types for appointments and kick sessions.

- **Appointments:**
  - keep only those with `date >= now`;
  - sort ascending and keep the first 5;
  - copy only title, date and location. Notes are never read.
- **Kicks:**
  - consider only completed sessions;
  - `lastSession` is the latest of them;
  - the 7-day window is `now - 7 days ... now`. It gives the count and the mean duration in minutes.
- **Never used:** symptoms, weight, cycle data and notes are not parameters of the builder, so leaking them is structurally impossible.

### 3.3 Change coalescing

`PartnerPublishScheduler` is a pure value with the current time injected. It records changes and returns "publish now" once 5 s have passed since the last change. A burst of edits therefore results in a single upload.

## 4. iCloud layer

The protocol, the fake and their tests live in **KickCore**, which is pure Swift and does not import CloudKit. That way they run under `scripts/test-core.sh` and the CI scripts do not need to change. The CloudKit implementation lives in the **App target** (`App/Partner/CloudPartnerSharing.swift`). It is a thin adapter and is tested by hand (§6).

### 4.1 Protocol

```swift
public protocol PartnerSharing: Sendable {
    // Mother
    func shareStatus() async throws -> PartnerShareStatus     // .notShared / .invited / .joined(participantCount)
    func prepareShare() async throws -> PartnerShareHandle     // creates zone + share if needed; handle feeds UICloudSharingController
    func publish(_ snapshot: PartnerSnapshot) async throws
    func stopSharing() async throws                            // deletes the zone (and with it the share)
    // Partner
    func accept(_ metadata: PartnerInvitation) async throws
    func fetchSharedSnapshot() async throws -> PartnerSnapshot? // nil = share gone / not accepted
    func registerForChanges() async throws                     // silent CKDatabaseSubscription on the shared DB
}
```

### 4.2 CloudKit implementation `CloudPartnerSharing`

- **Container:** `iCloud.com.lmtiep.kickcounter`.
- **Mother side:**
  - **Zone.** The mother's private database gets the custom zone `PartnerShare`. It holds one `Snapshot` record (`recordName: "current"`) with a `payload` field containing the snapshot JSON as `Data`, plus `version`.
  - **Share.** It is a zone-wide `CKShare` with `publicPermission = .none`. The participant permission is set to read-only through the sharing controller's available permissions (`.allowReadOnly`, `.allowPrivate`). The share title is "Luna Mom".
  - **`publish`.** Upserts the record with `.changedKeys` save policy and retries once on `serverRecordChanged`.
  - **`stopSharing`.** Deletes the zone.
- **Partner side:**
  - **Reading.** The partner reads the shared database by fetching the zones, then the `current` record in the zone shared by the owner.
  - **Invitation.** Info.plist gets `CKSharingSupported = YES`. A `UIApplicationDelegateAdaptor` with a scene delegate implements `windowScene(_:userDidAcceptCloudKitShareWith:)` and forwards the metadata to the app.
- **Errors:**
  - `.notAuthenticated` → status `iCloudUnavailable`.
  - `.zoneNotFound` / `.unknownItem` → "not shared" for the mother, `nil` for the partner.
  - Network errors are surfaced as retryable.
  - Nothing blocks the mother's UI.

### 4.3 Fake `FakePartnerSharing`

`FakePartnerSharing` is an in-memory store used by the KickCore tests and by UI tests through launch arguments:
- `-uiTestingSharing <state>`: the mother side, with state `notShared`, `invited` or `joined`.
- `-uiTestingPartner <state>`: the partner side, with state `snapshot`, `stopped` or `error`. The `snapshot` state seeds a fixed snapshot at week 24 with 2 appointments and a recent kick session.

## 5. App

### 5.1 Mother: "Chia sẻ với bố bé"

This is a new row in Profile, shown in pregnancy mode only. Its identifier is `partnerShareRow`. It shows the share status:

| Status | Row subtitle | Tap |
|---|---|---|
| not shared | "Mời bố bé xem hành trình" | opens the share sheet (`UICloudSharingController`) |
| invited / joined | "Đã chia sẻ" / "Bố bé đang xem" | opens the same controller, where the mother can manage the participant or stop sharing; also a "Ngừng chia sẻ" button with confirmation |
| no due date | "Hãy đặt ngày dự sinh trước" | disabled |
| iCloud unavailable | "Đăng nhập iCloud để chia sẻ" | disabled |

- **Stopping.** Stopping sharing deletes the zone and resets the row.
- **Publishing.** While sharing is active, `PartnerPublisher` listens for changes and publishes a fresh snapshot after the 5 s coalescing window. The changes it reacts to are:
  - an appointment added, edited or deleted;
  - a kick session completed or deleted;
  - the due date changed;
  - the app becoming active, at most once every 6 hours.

  Failures are logged and retried on the next trigger.

### 5.2 Partner mode

- **Mode.** `AppMode.partner` is a new case, stored in App Group defaults. It is set when an invitation is accepted. Onboarding is skipped. The previous mode is remembered, so leaving partner mode restores it.
- **Tabs:** Today (partner) · Knowledge (the Phase 7 library) · Profile (language, about, "Thoát chế độ Bạn đời").
- **Partner Today (`PartnerTodayView`, identifier `partnerToday`):**
  - **Header:** "Hành trình của {displayName}".
  - **Week:** the week and day, with the countdown to the due date. These are computed with the existing KickCore timeline from `dueDate`.
  - **Baby size:** the size card, from `WeeklyContentLibrary`, with the same visibility rules as everywhere else. It is tappable and opens the week detail, read-only.
  - **Appointments:** up to 5 upcoming. If there are none, it shows "Chưa có lịch khám sắp tới".
  - **Kicks:** the last session ("{n} cử động trong {m} phút, {relative time}") and the 7-day count and average. If there are none, it shows "Chưa có lượt đếm nào".
  - **Freshness:** "Cập nhật {relative time}".
  - **Refresh:** on appear, on pull to refresh, and on a silent CloudKit notification.
- **States:**
  - loading;
  - "Mẹ đã ngừng chia sẻ", shown when the snapshot is `nil` after acceptance, with a button to leave partner mode;
  - error, with a retry button;
  - iCloud unavailable.
- **Not shown:** partner mode never shows kick counting, appointments editing, symptoms, weight or cycle screens.

### 5.3 Privacy

- The partner receives only `PartnerSnapshot`.
- In-app "Giới thiệu", `docs/release-checklist.md` and the App Store privacy notes list exactly what is shared.
- The partner's local cache is a single snapshot in App Group defaults. It is cleared when the share is gone or when the partner leaves partner mode.

## 6. Testing

- **KickCore:**
  - builder rules: future-only, at most 5 and sorted appointments; notes excluded; completed sessions only; the 7-day window and mean;
  - snapshot JSON round-trip and future-version tolerance;
  - the scheduler's coalescing.
- **KickCore, sharing flow with the fake:** status transitions; publish then fetch; stop sharing then fetch returns `nil`; a corrupt payload yields `nil` / an error state.
- **UI tests** (`PartnerUITests`, using the fake):
  - the mother row in each state;
  - partner Today with a seeded snapshot (week 24 text, 2 appointments, the kick summary);
  - the stopped state and leaving partner mode;
  - the partner tabs contain no kick counter.
- **Screenshots** (`PartnerScreenshotTests`): partner Today in vi light, en dark and AX5; the mother row; the stopped state.
- **Manual test** (`docs/partner-sharing-manual-test.md`): step by step, with two Apple IDs on TestFlight. The steps are invite, accept, update, stop and reinstall. Real CloudKit sharing cannot run on CI.

## 7. Release

- **CloudKit schema.** The development schema gets the `Snapshot` record type in custom zones. The schema must be deployed to Production before release. Add this to the release checklist.
- **Info.plist.** Add `CKSharingSupported`.
- **Entitlements.** Unchanged: the CloudKit container and push (`aps-environment`) already exist.

## 8. Delivery (branch `feat/partner`)

1. **KickCore:** `PartnerSnapshot`, `PartnerSnapshotBuilder`, `PartnerPublishScheduler`, and `AppMode.partner` (with the previous mode remembered).
2. **Sharing layer:** the `PartnerSharing` protocol and `FakePartnerSharing` (KickCore, with tests); `CloudPartnerSharing` (App target); the invitation acceptance plumbing (app delegate / scene delegate); and `CKSharingSupported`. No changes to the CI scripts.
3. **Mother side:** the Profile row, the sharing controller bridge, stop sharing, `PartnerPublisher` wiring, UI tests and screenshots.
4. **Partner side:** partner mode routing and tabs, `PartnerTodayView` and its states, leaving partner mode, UI tests and screenshots.
5. **Docs:** the manual two-account test, release checklist (CloudKit deploy, privacy), README. This step runs the full CI suite.
