# Better backup Implementation Plan

> Spec `docs/superpowers/specs/2026-11-05-backup-plus-design.md` is binding. Security-relevant: password-based encryption of health data.

**Global constraints:** branch `feat/backup-plus`; KickCore must not import SwiftUI/UIKit/SwiftData/CloudKit (CryptoKit/CommonCrypto OK); strings via `scripts/add-strings.py` (vi northern + en); Luna tokens only; never "bất thường"/"abnormal"; verify `scripts/test-core.sh`, KickData `swift test` if touched, `xcodegen generate --quiet`, build-for-testing on 'iPhone 18 Pro'; never run UI tests locally; trailer `CI-Only-Testing: <classes>` + `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; push, `scripts/ci-wait.sh`, read screenshots (`sips -Z 900`). Prove tests have teeth with mutation runs (flip a check, see red, revert) for the crypto and reminder policy.

## Task 1 (TDD): `BackupEncryption` in KickCore — seal(json, password) / open(data, password) / isEncrypted(data); error enum; tests listed in spec.
## Task 2 (TDD): `BackupReminderPolicy` + keys (ownedKeys, excluded from backup settings table).
## Task 3: App — export password step (BackupCenter / Profile data section), restore password prompt (RestoreBackupPresenter), reminder card, "Chuyển sang iPhone mới" guide, strings; UI tests (`BackupUITests` extended: export with password toggle visible; restore of an encrypted DEBUG fixture asks for the password; wrong password message; reminder card via a DEBUG seed for last-backup date) + screenshots vi light/dark, AX5.
## Task 4: Docs — privacy page source in `site/` (do not publish gh-pages; note it in the PR), in-app privacy text if present, README, release checklist.
