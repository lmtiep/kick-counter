# When a pregnancy ends: loss and birth (1.1, item 4)

Date: 2026-11-05 · Status: owner decisions in; awaiting approval of the doc · Branch: `feat/pregnancy-ending`

## 1. Intent

When a pregnancy ends, through loss or birth, Luna Mom becomes a gentle
companion. It does not act as a medical tool. In the owner's words, a woman at
this moment "cần cảm xúc và cần được yêu thương vỗ về" (needs feeling, love and
comfort).

The app should:
- stop everything about the pregnancy at once;
- let her keep the journey as a keepsake;
- take her back to normal cycle tracking at her own pace;
- check in on her from time to time.

All of this is app wording only and needs no doctor review. That works only
because nothing here gives medical advice.

## 2. Goals, non-goals and anti-goals

**Goals**
- One gentle way to say the pregnancy has ended, with two branches: *"Bé đã
  chào đời"* (birth) and *"Thai kỳ đã dừng lại"* (loss).
- A **Memory** (Kỷ niệm) that keeps the journey and can be opened later.
- Return to cycle mode in a **postpartum / after-loss state**: predictions are
  paused until the first period is logged.
- Optional **check-ins**: "Hôm nay bạn thế nào?" plus small mood tips, starting
  a few weeks after the event.

**Non-goals**
- No baby tracking: feeding, sleep, diapers, growth. The owner decided this
  after reviewing the medical and legal risk; it may become a separate app
  later.
- No postpartum depression screening (EPDS). No breastfeeding-as-contraception
  wording. No medical thresholds of any kind.

**Anti-goals** (failures even if everything technically works)
- Any pregnancy content, week, fruit, kick reminder, appointment reminder or
  Live Activity reaches her after she has said it ended.
- A notification or Lock Screen text about the loss appears unexpectedly.
- Cheerful birth wording reaches someone on the loss branch, or the other way
  round.
- The app nudges her to "try again" or pushes trying-to-conceive.
- Data she chose to keep is lost.

## 3. Approach (owner chose A)

| | Approach | Trade-off |
|---|---|---|
| **A, chosen** | **Package into a Memory record.** On ending, build one `PregnancyMemory` holding a frozen summary and details. The raw pregnancy rows are then kept hidden or deleted, as she chooses. | A new SwiftData model (lightweight migration) and a new optional backup array. It is clean, supports several pregnancies, and cycle screens never mix in old data. |
| B | Tag every existing record with a pregnancy ID and filter. | Touches every model, query and screen. High risk. |
| C | Export a PDF or image, then delete. | No schema change, but nothing can be revisited in the app, and the file may surface in Photos unexpectedly. |

## 4. Behaviour

### 4.1 Entry
- **Where:** in Profile, the existing *"Kết thúc theo dõi thai kỳ"* row
  (`EndPregnancySheet`) is replaced by **"Thai kỳ của tôi đã kết thúc"**. It is
  discreet; it never appears on Today.
- **The sheet:** one warm line, then two equal choices: *"Bé đã chào đời"* and
  *"Thai kỳ đã dừng lại"*. Neither is the default and neither is highlighted.
- **Date:** optional, defaulting to today, with no other questions. Loss copy:
  *"Mình rất tiếc. Bạn không cần giải thích gì cả. Luna Mom sẽ ở đây, theo
  nhịp của bạn."* Birth copy: a warm congratulation with no exclamation-heavy
  hype.
- **Cancel:** possible at every step until the final confirm. Nothing changes
  before that.

### 4.2 Immediately on confirm, both branches
- Cancel every pregnancy notification: kick reminder, appointment reminders,
  week content, contraction alerts.
- End every kick and contraction Live Activity.
- Stop partner sharing where it exists. The `#if CLOUD_SYNC` code stays
  compiled out.
- Switch to cycle mode, keeping her previous cycle goal. If she never had one,
  use **"Theo dõi chu kỳ"** (tracking), never trying-to-conceive.
- Clear the pregnancy dates (`PregnancyProfile.clear`).
- Store a **pregnancy-ended state** in App Group defaults: the branch, the end
  date, check-in preferences and the last check-in shown. The widget reads the
  mode, so it shows the cycle state on its next reload.

### 4.3 Memory
- **Prompt:** *"Bạn có muốn giữ lại hành trình này như một kỷ niệm không?"*
  - **Có (Yes):** create a `PregnancyMemory`.
  - **Không (No):** no memory. Then a second gentle choice about the raw
    pregnancy data: keep it hidden (default) or delete it.
- **What a `PregnancyMemory` holds**, frozen at creation:
  - the branch, the start (LMP or due date − 280 d) and end dates, and the
    furthest week reached;
  - kick sessions per day, as a count and duration summary;
  - appointments with their notes;
  - the pregnancy weight series;
  - symptom notes from the pregnancy period, if they are distinguishable;
  - contraction episode summaries.
- **Where it lives:** a **"Kỷ niệm"** row in Profile, shown only when at least
  one memory exists. It opens a calm timeline page. The page has no week fruit
  art on the loss branch; the builder decides the art for the birth branch,
  keeping it soft.
- **Optional title:** she can give the memory a title, for example a baby's
  name.
- **Delete:** she can delete a memory at any time, with confirmation.
- **Raw rows:** after a memory is made, the raw pregnancy rows are deleted.
  This is the builder's call and the default, so cycle screens stay clean; the
  memory is the keepsake. The memory must be fully written before any delete,
  in one transaction. If the save fails, nothing is deleted.
- **Backup:** gains an optional `pregnancyMemories` array with no version bump,
  following the `pillDoses` / `contractions` precedent. **Delete-all** removes
  memories too.

### 4.4 Postpartum / after-loss cycle state
- **Pause predictions.** Until she logs the first period that starts after the
  end date, the cycle screens:
  - show no prediction, fertile window or "late" state;
  - show one gentle line instead. Birth: *"Sau sinh, kỳ kinh có thể quay lại
    sau vài tuần hoặc vài tháng, nhất là khi cho con bú."* Loss: *"Kỳ kinh có
    thể cần một thời gian để quay lại. Khi nào có, bạn chỉ cần ghi lại."*
  - These are factual and give no advice, and they never mention contraception.
- **Resume.** Logging a period resumes normal predictions. Cycles that started
  before the end date are ignored when computing averages, so pregnancy-length
  gaps don't skew them.
- **Notifications and widget.** Cycle reminders that depend on predictions stay
  silent while paused. The widget shows the same paused line in short form.

### 4.5 Check-ins
- **Start.** The first check-in comes **21 days** after the end date. After
  that, at most **once a week**, for about **12 weeks**, then they stop on
  their own.
- **Form.** A small card on cycle Today: *"Hôm nay bạn thế nào?"* with 4–5
  feeling choices (emoji or soft icons) and a "Bỏ qua" (skip) option.
- **After a tap:** one short warm reply and **one small mood tip** from a local
  list, for example a walk, a warm drink, calling someone close, writing a few
  lines, or resting without guilt. The tips are content strings with no
  medical claims. Branch-appropriate wording is used where it differs.
- **Repeated low feelings.** If she picks a low feeling on two check-ins in a
  row, add one line: *"Nếu nỗi buồn cứ kéo dài, hãy chia sẻ với người thân
  hoặc một người bạn tin cậy."* There are no hotline numbers or medical
  referral (owner decision: app-only).
- **Stopping.** *"Cảm ơn, mình ổn rồi"* ends check-ins permanently. They can
  also be switched off in Profile.
- **No notifications by default.** An optional toggle allows one local
  notification per check-in. Its text is neutral, for example "Luna Mom gửi
  bạn một lời hỏi thăm", and never mentions loss or pregnancy. It is
  `.privacySensitive` in spirit: no detail on the Lock Screen.
- **Privacy.** The feeling answers are stored on the device only, in defaults
  or a small model. They are never sent anywhere and excluded from the feedback
  email.

## 4.6 Settled after the builder check
Items marked *(controller's call)* are the controller's own decisions and
should be checked by the owner while reading.

**Raw data split.** CycleLog and WeightEntry carry no pregnancy tag, and
CycleLog rows also hold cycle data.
- **Pregnancy range:** the LMP (or due date − 280 d) through the end date.
  When there are no dates, the range starts at the earliest Kick, Contraction
  or Appointment date.
- **Copied into the memory:** kick sessions, contractions, appointments in
  range, weights in range, and logs in range that pass
  `SymptomTimeline.showsInPregnancy`. Only the pregnancy-relevant fields of
  those logs (moods, pregnancy symptoms, note) are copied.
- **Deleted after the memory is saved, in one transaction** *(controller's
  call: "reset để quay về trạng thái bình thường")*: KickSession, Kick,
  Contraction, the in-range Appointments and the in-range WeightEntries.
- **Never deleted:** CycleLog rows, because they can hold flow, BBT or LH data.
- **No memory:** the raw rows are kept by default and the sheet offers
  "Xoá dữ liệu thai kỳ" as an option. Nothing ever offers a hidden view. This
  replaces the "hidden" wording in §4.3.

**Notifications and activities** *(controller's call: targeted, not blanket)*
- Cancel the kick daily reminder, overdue alerts, each pregnancy appointment
  reminder, and any pending contraction alert.
- Cancel a running kick session and contraction.
- End both Live Activities **including the completed "Done!" kick activity**,
  through a new `endAll(force: true)`.
- Cycle and pill reminders are left alone, then re-synced.
- There is no week-content notification in the code, so nothing to cancel
  there.
- **Orchestrator:** a new `PregnancyEnding` orchestrator in the app layer owns
  the kick, contraction, appointment and cycle coordinators.

**Goal.**
- If `SettingsKey.cycleGoal` is absent, save `.tracking` before switching.
  `CyclePreferences.load` would otherwise fall back to `.conceiving`.
- The switch never prompts for notification permission (`mayPrompt: false`).

**Prediction pause.**
- The pause lasts while the ended state exists and no period has been
  *confirmed* as the first after the end.
- When she logs a period dated after the end date, a gentle question asks:
  *"Đây có phải kỳ kinh đầu tiên sau [khi sinh / thai kỳ] không?"* Yes resumes
  predictions; No keeps the pause and keeps the entry.
- *(Controller's call: no time threshold, so no medical rule about postpartum
  bleeding.)*
- Periods starting before the end date are excluded from averages.
- **Implementation:** `forecast` is nil while paused, which also silences
  cycle reminders.

**Check-ins.**
- Answers and state live in App Group defaults, never in a model.
- These keys are excluded from backup and cleared by delete-all; both key
  lists are updated.
- The card shows in cycle mode only.
- **Optional notification:** a single pending request with ID `care-checkin`,
  rescheduled after each check-in. It is cancelled on "mình ổn rồi", on the
  toggle off, on delete-all and on re-entering pregnancy.

**Backup.**
- Memories go into the backup like other data *(controller's call)*.
- The export screen already offers a password and has it on by default.

**Loss-branch memory content (owner decision).** The same content as the birth
branch, kicks and contractions included: she chose to keep it. The loss page is
softer: it opens with the dates and her own words or title, not with numbers,
and it has no fruit art.

**Pregnant again.** `ImPregnantSheet` clears the ended state, the pause and
the check-ins. Memories stay, listed newest first, with no cap.

**Upgrade path.** The end flow works when no due date is stored; see the range
fallback above. Lightweight migration follows the `PillDose` / `Contraction`
precedent: every property defaulted, complex fields as JSON `Data`, and no
relationships.

## 5. Constraints
- Swift 6, iOS 17, SwiftData with no CloudKit. KickCore stays pure; the
  policies (check-in schedule, prediction pause, memory building) live there
  and are tested.
- Strings only go through `scripts/add-strings.py`, in vi and en. Use Luna
  tokens and `Font.luna`, in light and dark, at AX5.
- Never use "bất thường", diagnosis words, or "thử lại / mong con lại" nudges.
- The schema change triggers the owner's rule: a **full whole-branch review on
  the top tier** before merge.

## 6. Testing
- **KickCore:**
  - the check-in schedule (day 20 vs 21, weekly spacing, stop after 12 weeks,
    "I'm fine" stops it, the two-low-in-a-row line);
  - the prediction pause and resume, with pre-end cycles excluded;
  - memory building from fixtures, for both branches;
  - the backup DTO round trip with and without `pregnancyMemories`.
- **KickData:**
  - memory creation and raw-row deletion are atomic (save fails → nothing
    deleted);
  - delete-all;
  - a migration from the 1.0 store with existing data.
- **UI tests:**
  - both branches end-to-end;
  - cancel at each step;
  - no pregnancy UI remains;
  - the memory row and page, and deleting a memory;
  - the check-in card with a DEBUG seed `-seedPregnancyEndedDaysAgo`;
  - "I'm fine" stops it.
- **Screenshots:** vi light/dark and AX5 for the sheet, the memory page, the
  paused cycle Today and the check-in card.
- **Mutation:** one run on the pause rule and one on the atomic delete.

## 7. Left to the builder
- Exact visual layout of the memory timeline and the check-in card, within
  Luna design.
- Final tip list (8–12 items, vi/en), kept short and non-medical.
- Whether the memory stores symptom notes, depending on whether pregnancy-
  period logs are distinguishable.
