# Edit period days on the calendar (Phase 19)

Date: 2026-10-10 · Status: approved in conversation · Branch: `feat/calendar-period-edit`

## 1. Goal

From the cycle calendar, users can tick the days they bled in the past and save
them all at once. This adds history without opening "Ghi chú" day by day, as in
Flo or Clue. The existing day-log buttons ("Kỳ kinh bắt đầu" and the others)
stay as they are.

## 2. Behaviour

### 2.1 Entering edit mode
- **The button.** The cycle calendar gets a button **"Sửa kỳ kinh"**
  (`calendarEditPeriods`) next to the month row. When
  `policy.predictedBleedLabel == .withdrawalBleed`, it reads "Sửa ngày ra máu".
- **What the grid shows.** Edit mode replaces the normal grid look:
  - each day from the window start up to today has a tick circle under its
    number;
  - days that are part of a stored period are ticked to begin with, using
    `CycleRules.dayRange` (so an open period covers up to today, at most 10
    days);
  - future days are dimmed and cannot be tapped;
  - predicted, fertile and ovulation styling is hidden.
- **The window.** It is the past two years up to today, the same as
  `AddPastPeriodSheet.startRange`. Days before the window cannot be tapped. A
  period that starts before the window is shown ticked and is never changed.
- **Changing month** works as usual. Ticks are kept across months until Save
  or Cancel.
- **Top bar.** It shows **Huỷ** (`periodEditCancel`) and **Lưu**
  (`periodEditSave`). Save is disabled until something has changed.
- **Cancelling.** Cancel with changes asks "Bỏ các thay đổi?" (discard /
  keep editing). Cancel with no changes just leaves.
- **Hidden in edit mode:** the selected-day card and the legend. A one-line
  hint takes their place: "Chạm vào những ngày bạn có kinh."

### 2.2 Saving
The pure function `PeriodEditPlan.make(initial:ticked:periods:now:typicalPeriodLength:calendar:)`
(KickCore) turns the edit into writes. The rule is **only what the user
touched changes**.

- **Toggled days.** `initial` is the ticked set the edit started from (the
  stored periods' days), `ticked` the set now. Added days are `ticked − initial`,
  removed days `initial − ticked`; both are kept only inside the window, up to
  today (as of `now` at Save) and outside periods that start before the window.
  No toggled day gives an empty plan.
- **Touched periods.** A stored period (the list at Save time) is touched when
  a toggled day is one of its days (`CycleRules.dayRange`) or the day right
  before or after it. This repeats: a run built from touched days that meets or
  overlaps another stored period touches it too, so ticking the gap day between
  two periods merges them.
- **Untouched periods are left alone.** They are never written, deleted or
  length-checked, and their days are not part of any run. So adjacent periods,
  overlapping duplicates and a stored period longer than 10 days stay as they
  are while another month is edited, and a period started or deleted elsewhere
  while edit mode is open is neither deleted nor re-added.
- **Runs.** The touched periods' days, plus added days, minus removed days,
  form runs of consecutive days. A gap of one day makes two runs.
- **Keeping ids.** Each run keeps the id of the earliest touched period it
  overlaps, and updates its start and end. Other touched periods that overlap
  the same run are deleted, as a merge. A run that overlaps no stored period is
  added as a new record. A touched period that overlaps no run is deleted.
- **End date.** A run whose last day is today is stored open (`endDate == nil`),
  like starting a period today. Any other run is closed on its last day.
- **Unchanged periods.** A touched period whose days are unchanged is not
  written.
- **Never two open periods.** When the plan stores an open run, any other open
  period that has run past `CycleRules.longPeriodDays` (including one that
  starts before the window) is closed at the typical period length, through
  `CycleRules.closingStale`, the same helper `CycleCoordinator` uses when a
  period is started.
- **Periods outside the window**, which start before it, are never touched by
  the user's ticks; only the rule above can close one.
- **While editing.** When the stored periods change, the app returns to the
  foreground or the day changes, the edit is rebased: its start becomes the
  current periods' days and the user's added and removed days are applied on
  top; the window moves to today.
- **Length limit.** A run longer than `CycleRules.longPeriodDays` (10) makes
  the plan fail with `.periodTooLong`, shown inline above the buttons in vi and
  en: "Mỗi kỳ kinh tối đa 10 ngày. Hãy bỏ bớt ngày." Nothing is saved, and edit
  mode stays open.
- **Atomic save.** `CycleCoordinator.applyPeriodEdits(_ plan:)` applies the
  deletes, updates and adds in **one save**. It uses a new
  `CycleRepository.applyPeriodChanges(deletes:updates:adds:today:)`, which
  checks each record against the *final* set with `CycleRules.validate`. On any
  error nothing is written. It then refreshes, so the forecast and reminders
  are recomputed as after any period change.
- **Day logs are untouched.**
- **After a successful save**, edit mode closes and VoiceOver announces
  "Đã lưu kỳ kinh".

### 2.3 Accessibility and look
- **Day cells in edit mode** are toggle buttons. The label is the spoken date
  plus "ngày có kinh" when ticked. They have the `isSelected` trait when
  ticked, and the identifier `periodEditDay-yyyymmdd`.
- **The tick circle** fills with `.cycle`, using `.onAccent` for the check
  mark when ticked. When unticked it is an outline with `.cardBorder` /
  `.textSecondary`. It works in light, in the new dark mode and at AX5. At
  large type the hint wraps.
- **Strings** are added only through `scripts/add-strings.py`, in vi and en.

## 3. Testing

- **KickCore** (`PeriodEditPlanTests`):
  - no change gives an empty plan;
  - adding a new run;
  - extending and shortening at either end;
  - splitting one period into two (the first keeps the id);
  - merging two periods (the earliest keeps the id, the other is deleted);
  - removing everything;
  - an open period kept open or closed;
  - a run ending today;
  - a period before the window left alone;
  - only touched periods change: a period added or deleted underneath, an
    edit across midnight with an open period, adjacent periods, a long stored
    period, overlapping duplicates, ticking the gap between two periods;
  - a stale open period closes at the typical length, also before the window;
  - a run longer than 10 days fails;
  - DST and month boundaries, including a change at midnight (America/Santiago).
- **KickCore** coordinator tests: one save; a failure leaves the periods
  unchanged; the forecast refreshes.
- **KickData:** `applyPeriodChanges` writes everything or nothing, and is
  validated against the final set, so a shrink followed by an add next to it
  passes.
- **UI** (`CalendarPeriodEditUITests`):
  - enter edit mode, tick two runs in an earlier month, save, then check that
    History lists both;
  - untick one day of a seeded period to split it;
  - cancel with changes asks to confirm;
  - future days cannot be tapped.
- **Screenshots:** edit mode in vi light and dark, and AX5.

## 4. Delivery

1. KickCore: `PeriodEditPlan` and the coordinator. KickData: the store method.
   All with tests.
2. App: the button, edit mode in the grid, the hint, error, cancel dialog,
   strings, UI tests and screenshots.
3. Docs: the README line, and a release checklist "Giai đoạn 19" device check.
