# Backup and restore by file (Phase 15)

Date: 2026-10-09 · Status: approved in conversation · Branch: `feat/backup`

## 1. Goal

Version 1.0 keeps everything on the device, with no iCloud (Phase 12). A user who changes iPhone, or wants a safety copy, can therefore export all her data to one file, put it where she likes (Files, iCloud Drive, AirDrop, Zalo…), and restore it later on any iPhone with Luna Mom.

## 2. Decisions made with the user

| Topic | Decision |
|---|---|
| Restore | **Replace everything.** Show a summary of the file, ask for confirmation, then replace all data on the phone with the file's contents. If anything fails, the phone keeps its old data |
| File type | **Luna Mom's own type.** The extension is `.lunamom`, with UTType `com.lmtiep.kickcounter.backup` conforming to `public.json`. Tapping the file in Files, AirDrop or a chat app opens Luna Mom on the restore screen. Inside is versioned JSON |
| Encryption | None in 1.0. The export screen says plainly that the file holds health data and should only be stored or shared somewhere the user trusts |
| iCloud | The app never writes to iCloud itself. The user chooses where the file goes, through the system share sheet or document picker. This fits the Phase 12 position on 5.1.3(ii), and the privacy policy gains one sentence about it |

## 3. Data format (KickCore, pure, tested)

`BackupDocument`, `Codable` and versioned:

```json
{
  "format": "luna-mom-backup",
  "version": 1,
  "createdAt": "2026-10-09T09:41:00Z",
  "appVersion": "1.0 (21)",
  "sessions":     [ { "id": "...", "start": "...", "end": "...", "kicks": ["...", "..."], "...": "..." } ],
  "appointments": [ ... ],
  "periods":      [ ... ],
  "cycleLogs":    [ ... ],
  "weights":      [ ... ],
  "settings":     { "<SettingsKey>": <JSON value>, ... }
}
```

- **Records.**
  - These records are written: `SessionRecord` (with its kicks), `AppointmentRecord`, `PeriodRecord`, `CycleLogRecord` (including the unknown raw mood and symptom values, so nothing is lost) and `WeightRecord`.
  - Each gets a `Codable` DTO in KickCore. The DTO is not the record itself, so storage types can change without breaking old files.
  - Dates use ISO 8601 with fractional seconds.
- **Settings.** `settings` holds every key in `AppDataReset.ownedKeys`, **except**:
  - the partner keys (`partnerSkippedOnboarding`, `partnerPublishedSnapshot`, `partnerCachedSnapshot`, `partnerPendingZoneDeletion`);
  - `hasCompletedOnboarding`, which restore sets to true.

  Values are stored as JSON scalars or ISO dates by key type. There is an explicit table per key; the `UserDefaults` types are never guessed.
- **`BackupCodec.encode(_:) -> Data`** writes pretty-printed JSON with sorted keys.
- **`BackupCodec.decode(_:) throws -> BackupDocument`** throws:
  - `.notABackup` (wrong `format`);
  - `.newerVersion(Int)` (version greater than 1);
  - `.corrupt` (JSON or required fields).

  Unknown extra fields are ignored, so newer minor versions still open.
- **`BackupDocument.summary`** gives:
  - counts per kind;
  - `createdAt`;
  - the mode;
  - the date range of the data.
- **Validation before replacing.** Every record goes through the existing rules: periods use `CycleRules.validate` against each other, and logs, weights and appointments use their validators, with `today = now`. Future-dated or invalid records are skipped and counted; they never cause a crash. Overlapping periods are kept as in the file, with no merging.

## 4. Behaviour

### 4.1 Export

- **Where:** Profile, in a new "Dữ liệu" section above "Xoá toàn bộ dữ liệu".
- **"Sao lưu ra file"** (`profileBackupExport`) builds the document from the stores and the defaults, writes `LunaMom-YYYY-MM-DD.lunamom` to a temporary directory and presents `ShareLink` or `UIActivityViewController`. That covers Files, AirDrop and other apps.
- **Footnote under the row:** "File chứa dữ liệu sức khoẻ của bạn. Hãy lưu ở nơi bạn tin tưởng."
- **Last backup:** after a successful share, "Lần sao lưu gần nhất: 9 thg 10" is recorded in a new owned key, `lastBackupAt`. It is shown under the row and cleared by delete-all.
- **Empty data:** with no data the row is still enabled, and the file holds settings only.

### 4.2 Restore

- **Entry points:**
  - Profile → "Khôi phục từ file" (`profileBackupImport`) opens `.fileImporter` for the `.lunamom` type and plain `.json`;
  - opening a `.lunamom` file from outside the app (`onOpenURL`, with the `CFBundleDocumentTypes` / `UTExportedTypeDeclarations` declaration in `project.yml`; `LSSupportsOpeningDocumentsInPlace = NO`, so iOS copies the file).
- **Restore sheet** (`RestoreBackupSheet`):
  - a summary: "Sao lưu ngày 9/10/2026", the counts ("12 lượt đếm cử động, 8 kỳ kinh, 40 ngày ghi chép, 5 lần cân, 3 lịch khám") and the mode;
  - a warning: "Toàn bộ dữ liệu hiện có trên iPhone này sẽ được thay bằng dữ liệu trong file.";
  - buttons "Khôi phục" (destructive) and "Huỷ".
- **Decode errors** show a friendly message and nothing is touched:
  - `.notABackup`: "File này không phải bản sao lưu của Luna Mom.";
  - `.newerVersion`: "File được tạo bởi phiên bản Luna Mom mới hơn. Hãy cập nhật app.";
  - `.corrupt`: "Không đọc được file."
- **Restore is atomic:**
  1. In one SwiftData transaction, delete all models and insert the file's records, then save. If the save fails, roll back and show "Không khôi phục được. Dữ liệu cũ vẫn giữ nguyên."
  2. Only after a successful save, replace the owned defaults: clear them, write the file's settings, and set `hasCompletedOnboarding = true`.
  3. Cancel all notifications and Live Activities, then reload the coordinators (`resetAfterDataDeletion` where it exists, then `load`). The coordinators reschedule reminders as usual.
  4. Close the sheet and switch to the Today tab for the restored mode. A toast says "Đã khôi phục dữ liệu".
- **A running kick session.** If a kick session is running on the phone, the sheet warns: "Lượt đếm đang chạy sẽ bị dừng." The restored data may contain a session without an end. It is restored as-is if it started less than 12 hours ago, and is otherwise closed at its last kick, following the existing abandoned-session rule; reuse it.
- **During onboarding.** Restore can also be offered from onboarding's welcome step: a small "Khôi phục từ bản sao lưu" link (`onboardingRestore`). A fresh install on a new phone is exactly when this is needed.

## 5. Privacy and docs

- `site/privacy.html` and the in-repo copy get a sentence in vi and en: export creates a file the user controls; the app does not upload it anywhere; the file is not encrypted. This means re-publishing `gh-pages`, with the owner's approval at PR time.
- Release checklist: export on device A, AirDrop the file, open it on device B, restore, and check that the counts match.
- README.

## 6. Testing

- **KickCore:**
  - round trip (encode → decode gives equal records and settings, unknown raw values included);
  - version handling (`.newerVersion`, `.notABackup`, `.corrupt`);
  - extra unknown fields are ignored;
  - the settings table covers every exported key (a test against `AppDataReset.ownedKeys` minus the exclusions);
  - invalid records are skipped and counted;
  - the summary counts.
- **KickData:** atomic replace on an in-memory container. A replace that fails on purpose leaves the old data.
- **UI tests:**
  - export shows the share sheet; assert that its presence is enough;
  - restore through a seeded `.lunamom` fixture, passed with a DEBUG launch argument `-uiTestingRestoreFile <path>` that opens the restore sheet, the same way an opened file would. Check the summary, restore, then check the data on Today and in the history;
  - an invalid file shows the error;
  - the onboarding restore link exists.
- **Screenshots:** the Profile "Dữ liệu" section and the restore sheet in vi light/dark and AX5.

## 7. Delivery

1. KickCore: `BackupDocument`, the DTOs, `BackupCodec`, the settings table, validation and the summary, with tests. KickData: `BackupStore.export` and `replaceAll` (atomic), with tests.
2. App: the Profile section, export and share, the importer, the open-URL handling, `RestoreBackupSheet`, the onboarding link, the document type in `project.yml`, strings, UI tests and screenshots.
3. Docs and site: the privacy sentence, README and checklist. The PR runs the full sharded suite.
