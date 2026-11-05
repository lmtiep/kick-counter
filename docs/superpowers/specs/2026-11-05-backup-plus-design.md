# Better backup: password, reminder, move to a new iPhone (1.1, item 2)

Date: 2026-11-05 · Status: approved in conversation · Branch: `feat/backup-plus`

## Why
Luna Mom keeps everything on the phone; losing or replacing the phone without a backup
loses everything (a top complaint about competitors is data loss when changing phones).
Owner: users usually send the backup file to themselves by **email or Zalo**, so the file
needs optional password protection; the user decides.

## Design
### Export
- Profile → Data → "Sao lưu ra file" first shows a step "Bảo vệ file bằng mật khẩu":
  toggle **on by default**, with "File chứa dữ liệu sức khoẻ. Nên đặt mật khẩu nếu bạn gửi
  qua email hoặc Zalo." The user may turn it off.
- On: password + confirm (min 6 characters, show/hide), and a clear warning: "Quên mật khẩu
  sẽ không mở lại được file — Luna Mom không lưu mật khẩu ở đâu cả." Then the share sheet.
- The password is never stored, logged or kept in memory longer than the export.
- File keeps the `.lunamom` extension and UTType.

### Encrypted format (KickCore pure logic + tests; crypto via Apple frameworks only)
- Envelope: magic `LUNAENC1` (8 bytes) · version byte · KDF params (PBKDF2-HMAC-SHA256,
  iterations as UInt32, default 600 000) · 16-byte random salt · AES-GCM 12-byte nonce ·
  ciphertext+tag of the existing JSON backup bytes.
- Key derivation with CommonCrypto `CCKeyDerivationPBKDF` (in the app layer or a small
  wrapper; KickCore must stay free of SwiftUI/UIKit/SwiftData/CloudKit — CryptoKit and
  CommonCrypto are allowed). AES-GCM via CryptoKit `AES.GCM`.
- Plain (unencrypted) files are unchanged; detection by the magic header.
- Tests: round trip; wrong password → `.wrongPassword` (GCM auth failure), no partial data;
  tampered byte → failure; truncated file; unknown version; plain file still restores;
  iteration count read from the file (future-proof).

### Restore
- Opening an encrypted file asks for the password (secure field). Wrong password →
  "Mật khẩu không đúng", retry, nothing changed. Decrypted bytes then go through the
  existing validation and "Thay thế toàn bộ" flow unchanged.

### Reminder (in-app only, no notification)
- A card "Đã lâu chưa sao lưu" in Profile (top of the Data section) with "Sao lưu ngay"
  and "Để sau": shown when the last backup is ≥ 30 days old, or, if never backed up,
  once the app has been used for ≥ 14 days (first-use date). "Để sau" hides it for 14 days.
- Pure policy in KickCore (`BackupReminderPolicy`), tested at the boundaries. Keys in
  `AppDataReset.ownedKeys`, excluded from backups.

### "Chuyển sang iPhone mới"
- Profile → Data → "Chuyển sang iPhone mới": a 3-step guide (back up & send the file to
  yourself; install Luna Mom on the new iPhone; open the file there and tap Restore),
  with a button for step 1 that starts the export above.

## Approaches
Chosen: password-encrypted `.lunamom` (PBKDF2 + AES-GCM). Rejected: storing the password
in iCloud Keychain (contradicts "data only on your phone"); password-protected zip (not
native on iOS, weak legacy crypto).

## Privacy / docs
Update the privacy page + in-app "Your privacy" text: backups can be password-protected;
Luna Mom never sees or stores the password. README + release checklist (encrypted file
sent via Zalo restores on a second phone; wrong password; old plain file still restores).
