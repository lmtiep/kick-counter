# Editing contractions during labour: short design

Date: 2026-11-06 · Status: approved by owner in chat · Branch: `feat/contraction-edit`

## Intent
During labour a mis-tap or a missed contraction ruins the numbers. Today the
only tools are delete and undo. Apps that let you **fix** entries get 5★
("sửa được"). There are 8 UX complaints in the competitor review sample.

## Design (approved)

**Edit**
- Tapping a contraction row (current episode and history) opens a sheet to
  edit the **start** and **end** times.
- The same rules as live timing apply:
  - no time in the future;
  - the end is after the start;
  - the duration is between `ContractionRules.minDuration` (3 s) and
    `maxDuration` (5 min);
  - no overlap with a neighbouring contraction.
- Invalid input shows an inline message, and Save is disabled.

**Add a missed contraction**
- A **"Thêm cơn gò bị sót"** button takes the start time (default: now minus
  1 minute) and a duration (default 60 s, in 5-second steps).
- The same validation applies. The new contraction joins the correct episode
  by time.

**"Vỡ ối" (water broke)**
- A button on the timer screen records the time. It is pre-filled with now
  and can be edited.
- It is stored as a new marker.
  - **Choice:** an optional `waterBrokeAt: Date?` saved per episode in a small
    new `LabourMarker` SwiftData model (`id`, `kind` = "waterBroke", `at`),
    which is extensible.
  - It is backed up as an optional array, following the `contractions`
    precedent, and deleted by delete-all.
- After saving, the screen shows the existing, doctor-reviewed safety line
  ("Vỡ ối, ra máu… đến bệnh viện ngay") as an emphasised card. **No new
  medical wording.**
- The marker appears in the episode list and in history. It can be edited or
  deleted.

**After any edit, add or delete**
- `ContractionStats` (last hour and the 5-1-1 or preterm alert) is
  recomputed.
- The Live Activity content is updated.
- `contractionAlertNotified` dedupe still works. An edit that newly crosses a
  threshold may notify once; one that falls below a threshold never notifies.

**Code**
- **KickCore:** `ContractionCoordinator.update(id:start:end:)`,
  `addMissed(start:duration:)`, `markWaterBroke(at:)`, `deleteMarker(id:)`.
- **Validation:** a pure `ContractionEditRules.validate(...)` returning a
  typed error. Both are tested.

## Constraints
- Strings go through `add-strings.py`.
- Never run UI tests locally.
- The schema change follows the `PillDose`/`Contraction` precedent: every
  property defaulted, no relationships.
- `feat/pregnancy-ending` also adds a model. Whichever lands second rebases;
  both must be in `KickPersistence.schema`, `DataReset`, `BackupStore` and
  `DataResetTests`.

## Tests
- **KickCore:**
  - each validation case;
  - an overlap at both edges;
  - an edit that moves a contraction into another episode;
  - stats after an edit;
  - an alert crossing up and down;
  - backup with and without markers.
- **KickData:** the marker store, delete-all, and opening a store from before
  this change.
- **UI:** edit a row, add a missed contraction, mark water broke and see the
  safety card, delete a marker.
- **Screenshots:** the edit sheet, the add-missed sheet and the water-broke
  card (vi light/dark, AX5).
