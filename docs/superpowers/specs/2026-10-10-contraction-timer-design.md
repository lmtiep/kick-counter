# Contraction timer (Phase 20)

Date: 2026-10-10 · Status: approved in conversation · Branch: `feat/contraction-timer`

## 1. Goal

In the last weeks of pregnancy the user times contractions with one button. The
app shows each contraction's length and the interval between contractions, and
says when it is time to call the doctor or go to hospital, using thresholds the
doctor will confirm. The timer also runs from the Lock Screen through a Live
Activity.

## 2. Decisions made with the user

| Topic | Decision |
|---|---|
| Entry | A **"Cơn gò"** shortcut on pregnancy Today **from week 28**. Before week 28, a row "Đếm cơn gò" in the Kicks tab opens the same screen |
| Alerts | **5-1-1 from week 37**. **Before week 37**, regular contractions (≥ 4 in the last hour) show an urgent card. A safety line is always shown. Everything goes to the doctor doc |
| Live Activity | **Yes.** Lock Screen and Dynamic Island, with a Start/Stop button that works without opening the app |

## 3. Data

### 3.1 Model (SwiftData, KickData)
- New model `Contraction { id: UUID, startedAt: Date, endedAt: Date? }`. At most
  one has `endedAt == nil`: the one in progress.
- It joins `KickPersistence.schema`, with no CloudKit.
- `DataReset` deletes it.
- The backup gains an optional `contractions` array. The format stays version
  1, as `pillDoses` did in Phase 17: a missing array means empty, and older
  apps ignore it.

### 3.2 Pure logic (KickCore, tested): `ContractionStats`
- Built from the contractions, `now` and the gestational week (or `nil` when it
  is unknown).
- Per contraction:
  - `duration` = end − start (for one in progress, `now` − start);
  - `interval` = its start − the previous contraction's start, or nil for the
    first in an episode.
- **Episode.** Consecutive contractions belong to the same episode while the
  gap between starts is at most **2 hours** (`ContractionRules.episodeGap`).
  The screen shows the current episode. History shows past episodes grouped by
  day.
- **Last hour.** Over the completed contractions that start within the last 60
  minutes, it gives the count, the average duration and the average interval.
- **Alert** (`ContractionAlert`: `.none`, `.fiveOneOne`, `.pretermRegular`):
  - **`.pretermRegular`:** the week is below 37 and **≥ 4** completed
    contractions started within the last 60 minutes. This applies in any week
    before 37, including before 28.
  - **`.fiveOneOne`:** the week is 37 or later, or unknown. It needs **all** of
    the following:
    - the completed contractions of the current episode span **≥ 60 minutes**,
      from the first start to the last start;
    - over the contractions that start in the last 60 minutes, the **average
      interval is ≤ 5 min 30 s** and the **average duration is ≥ 45 s**;
    - at least **6** contractions are in that hour.
  - **Constants.** All thresholds are named constants in
    `ContractionRules`, with a comment pointing to the doctor doc items.
- **Validation.** A contraction may not start in the future. If one is longer
  than **5 minutes** (`maxDuration`), it is closed automatically at start + 5
  min when the app or intent next sees it, as a forgotten stop. Contractions
  under 3 seconds (`minDuration`) are dropped as mis-taps.

### 3.3 Coordinator (KickCore): `ContractionCoordinator`
- It is `@Observable` and follows the `KickCoordinator` pattern.
- It provides `toggle()` (start or stop), `undoLast()`, `delete(id:)` and
  `endEpisode()`. `endEpisode()` stops any running contraction and ends the
  Live Activity.
- It is the single entry point for the UI and for the Live Activity intent.
- It drives the Live Activity through a protocol in KickCore. The app supplies
  the implementation, next to `SystemLiveActivityManager`, and a test double.

## 4. Behaviour

### 4.1 Entry
- **Today.** Pregnancy Today, from week 28, adds a round shortcut **"Cơn gò"**
  (`shortcutContractions`) to the existing row: Kick counter, Symptoms, Weight,
  This week. The row keeps the existing rule of two per row at accessibility
  text sizes. With five items it wraps without clipping.
- **Kicks tab.** A row **"Đếm cơn gò"** (`kicksContractionsLink`) opens the
  same screen in any week.
- **Presentation.** The screen is a full-height sheet or a pushed view,
  matching how Kicks or Weight open.

### 4.2 Timer screen
- **The big round button** (`contractionToggle`):
  - "Bắt đầu cơn gò" while resting;
  - "Hết cơn gò" while a contraction is running, with a live mm:ss timer;
  - a haptic on each tap;
  - `LunaMotion` respected.
- **Stats row** for the last hour: the count, the average duration ("Dài TB")
  and the average interval ("Cách nhau TB"), shown as m:ss.
- **The current episode's list**, newest first. Each row shows the start time,
  the duration and the interval. Swipe or a menu deletes a row
  (`contractionDelete`). After each tap, "Hoàn tác" (`contractionUndo`) is
  available for 5 seconds.
- **"Kết thúc theo dõi"** (`contractionEndEpisode`) ends the episode.
- **History** (`contractionHistory`): past episodes grouped by day. Each shows
  the count, the time span and the averages, and can be deleted with
  confirmation.

### 4.3 Alert cards
- **`.fiveOneOne`** shows a card: "Cơn gò đều khoảng 5 phút một lần, mỗi cơn
  khoảng 1 phút, trong 1 giờ: đến lúc gọi bác sĩ hoặc đến bệnh viện." It has a
  call button. Reuse the call button style and number logic from the kick
  2-hour alert (`KicksView`, `tel:115` in vi).
- **`.pretermRegular`** shows an urgent card, styled like the kick alert: "Bạn
  đang có cơn gò đều trước tuần 37. Hãy gọi bác sĩ hoặc đến bệnh viện ngay."
  It has the same call button.
- **The safety line is always visible:** "Vỡ ối, ra máu, đau dữ dội liên tục
  hoặc thai cử động ít đi: đến bệnh viện ngay."
- **No diagnosis wording.** Never write "bất thường" or "abnormal".

### 4.4 Live Activity
- **Attributes.** `ContractionActivityAttributes` lives in Shared, next to
  `KickActivityAttributes`.
  - Static: `episodeID` and `startedAt`.
  - `ContentState`: `runningSince: Date?`, `count: Int`, `lastInterval:
    TimeInterval?`, `lastDuration: TimeInterval?`.
- **When it runs.** It starts on the first contraction of an episode and
  updates on every toggle.
- **When it ends.** It ends on "Kết thúc theo dõi", on delete-all, and when 2
  hours pass with no new contraction. The app checks this on foreground and
  launch. Set `staleDate` and the dismissal policy so the system removes it.
- **Lock Screen and expanded Dynamic Island:**
  - "Đang gò" with `Text(timerInterval:)`, or "Đang nghỉ";
  - the count and the last interval;
  - a button driven by `ToggleContractionIntent` (`LiveActivityIntent`, through
    a bridge like `KickIntentBridge`).
- **Compact and minimal Dynamic Island:** an icon plus the running timer or the
  count.
- **Together with the kick Live Activity.** It can run alongside it.
- **Tokens.** The widget uses the Luna tokens it already reads, in light and
  dark.

### 4.5 Strings, docs, doctor
- **Strings.** Everything goes through `scripts/add-strings.py`, in vi and en.
- **Doctor doc.** A new section §18 adds items **96–100**:
  1. the 5-1-1 thresholds and their tolerances (5:30, 45 s, 6 contractions,
     60 min);
  2. the preterm rule (≥ 4 in 1 hour before 37 weeks);
  3. the alert and safety wording;
  4. the 5-minute auto-close and 3-second minimum;
  5. whether first and later pregnancies, or distance from hospital, should
     change the advice. The app gives one rule for everyone.
- **Other docs.** Add the section to `Luna Mom - doi chieu y khoa.xlsx`, a
  README section, the release checklist "Giai đoạn 20" and one line in
  `docs/app-review-notes.md`. The checklist covers the Lock Screen button on a
  device, the Dynamic Island and the auto-end after 2 hours.

## 5. Testing

- **KickCore:**
  - `ContractionStats`: durations; intervals; episode splitting at 2 h; the
    last-hour window edges; 5-1-1 true and false cases at each threshold;
    preterm at 36+6 vs 37+0; an unknown week; the auto-close and minimum
    duration; a contraction across midnight; a time zone change;
  - the coordinator: toggle, undo, delete, end episode, and the Live Activity
    calls through a fake;
  - backup round trip of the DTO.
- **KickData:** the store; delete-all; backup with and without `contractions`.
- **UI tests** (`ContractionTimerUITests`):
  - week 30 shows the shortcut, and week 20 does not but the Kicks row does;
  - time 3 contractions and check the count;
  - delete one;
  - undo;
  - a DEBUG seed `-seedContractions "511"` shows the 5-1-1 card, and
    `"preterm"` at week 33 shows the urgent card.
- **Screenshots** (`ContractionTimerScreenshotTests`): the screen resting and
  running, both cards, and history, in vi light and dark, plus AX5. The Live
  Activity is checked on a device; it is in the checklist.

## 6. Delivery

1. KickCore: the rules, stats, coordinator and DTO. KickData: the model, store,
   reset and backup. All with tests.
2. App: the screen, entries, cards, history, strings, UI tests and screenshots.
3. Live Activity: the attributes, intent, widget UI and the manager wiring.
4. Docs: the doctor section and xlsx, README, checklist and review notes.
