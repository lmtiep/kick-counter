# Hospital bag checklist and questions for the doctor: short design

Date: 2026-11-06 · Status: approved by owner in chat · Branch: `feat/bag-and-questions`

## Intent
Two practical lists that every major competitor has and that fit Vietnamese
practice:
- what to bring to the hospital;
- what to ask at the next check-up, written down as questions come up.

## Design (approved)

### Hospital bag
- **Groups:**
  1. **Giấy tờ:** CCCD, sổ khám thai and the latest test results, thẻ BHYT,
     giấy chuyển viện if any, some cash.
  2. **Đồ cho mẹ.**
  3. **Đồ cho bé.**
  4. **Người đi cùng.**
- **Content:** about 25–35 built-in items in vi and en. Practical items only,
  **no medicines and no medical items** (so no doctor review is needed).
- **Editing:** she can tick an item, add her own item to a group, delete or
  hide a built-in item, and reset ticks.
- **Entry:**
  - a card on pregnancy Today **from week 32** ("Đồ đi sinh · 12/30");
  - an "Đồ đi sinh" row in the pregnancy area of Profile or Kicks (decide the
    best fit), available in any week.

### Questions for the doctor
- Each appointment gets a **questions** list: add, tick as asked, and delete.
- **Quick add:** "Ghi câu hỏi cho bác sĩ" on pregnancy Today. The question
  attaches to the next upcoming appointment. If there is none, it goes to an
  "unassigned" list that the next appointment created shows and adopts.
- The appointment editor and detail show the questions. The doctor report
  (`feat/doctor-report`) may list them later; that is not needed here.

## Data
- **Model:** a new SwiftData `ChecklistItem` with `id`, `list` ("bag" or
  "question"), `group` (the bag group or nil), `builtInID` (nil for custom),
  `text` (empty for built-ins, which are localised by `builtInID`), `isDone`,
  `isHidden`, `order`, `appointmentID: UUID?` and `createdAt`.
- **Defaults:** every property defaulted, no relationships (the
  `PillDose`/`Contraction` precedent).
- **Built-ins:** not stored until touched. A pure merge in KickCore combines
  the static built-in list with the stored overrides.
- **Backup:** an optional array (the `contractions` precedent). Delete-all
  removes it.
- **Appointment deleted:** its questions are deleted too. Unanswered
  questions could alternatively be moved to unassigned; ask the controller if
  this is unclear. The default is to delete them together with the
  appointment, after confirmation that mentions them.
- **Merge note:** `feat/pregnancy-ending` and `feat/contraction-edit` also add
  models. Whoever lands later rebases and keeps all of them in
  `KickPersistence.schema`, `DataReset`, `BackupStore` and `DataResetTests`.
- **After an ending:** if `feat/pregnancy-ending` lands, bag items and
  questions count as pregnancy data. Not required in this branch; leave a
  note.

## Tests
- **KickCore:**
  - the built-in and override merge (hide, tick, custom order);
  - the progress count;
  - quick-add routing (the next appointment, or unassigned and then adopted);
  - the week-32 card rule.
- **KickData:** the store, delete-all, the backup round trip, opening an
  older store, and an appointment delete cascading to its questions.
- **UI:** tick and add an item; hide a built-in; reset; quick-add a question
  and see it on the next appointment; tick it.
- **Screenshots:** the bag list, the Today card at week 33, and the
  appointment with questions (vi light/dark, AX5).
