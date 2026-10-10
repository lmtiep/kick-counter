# Daily pill reminder (Phase 17)

Date: 2026-10-09 · Status: approved in conversation · Branch: `feat/pill-reminder`

## 1. Goal

Women who chose "Thuốc tránh thai hằng ngày" (`Contraception.pill`) can get a daily reminder at a time they pick. They can mark "Đã uống" from the notification or from Today, and see where they are in the pack.

## 2. Decisions made with the user

| Topic | Decision |
|---|---|
| Pack types | **21 + 7 break**: 21 pills, then 7 days without pills and without reminders. **28**: a pill every day, which covers 21 + 7 placebo, 24 + 4, and progestin-only pills. The user picks the first day of the current pack |
| Follow-up | The notification has a **"Đã uống"** action. If the pill is not marked, **one follow-up 2 hours later**. Nothing more |
| Missed pills | **No clinical instructions.** Only: "Nếu quên uống, hãy làm theo tờ hướng dẫn trong hộp thuốc hoặc hỏi bác sĩ, dược sĩ." |
| Who sees it | Cycle mode with `Contraception.pill`. The setting is hidden for other contraception choices and in pregnancy mode. If the user leaves the pill option, the reminders are cancelled and the settings are kept |

## 3. Data

### 3.1 Settings (App Group, KickCore)

New keys, all added to `AppDataReset.ownedKeys` and to the backup settings table, so delete-all and backup cover them:

| Key | Type | Meaning |
|---|---|---|
| `pillReminderEnabled` | Bool | Reminder on or off |
| `pillPackType` | String | `"21+7"` or `"28"` |
| `pillPackStart` | epoch Double | First day of the current pack, at start of day |
| `pillReminderHour` | Int | Default 21 |
| `pillReminderMinute` | Int | Default 0 |

### 3.2 Doses (SwiftData, KickData)

New model `PillDose { id: UUID, day: Date (start of day), takenAt: Date }`, at most one per day.
- It joins `KickPersistence.schema`. This is a lightweight addition; there is no CloudKit since Phase 12.
- `DataReset` deletes it.
- The backup gains an optional `pillDoses` array. The format stays version 1, because a missing array means empty, older files still load, and older apps ignore the extra field.

### 3.3 Pure logic (KickCore, tested)

`PillPack` is built from the type, the start date and the calendar. It answers:
- `dayInPack(on:)` → 1…28, repeating every 28 days from the start;
- `isPillDay(on:)` → false on days 22–28 of a `21+7` pack;
- `pillNumber(on:)` → n of 21 or n of 28;
- `nextPackStart(after:)`;
- `upcomingReminderDates(from:count:hour:minute:)` → the next pill days at the chosen time.

## 4. Behaviour

### 4.1 Setup (Profile → Chu kỳ, under "Biện pháp tránh thai", only when it is `.pill`)

- A row "Nhắc uống thuốc" opens a sheet.
- The sheet has:
  - a toggle;
  - the pack type, as a segmented control: "21 viên + 7 ngày nghỉ" / "28 viên";
  - "Ngày bắt đầu vỉ này", a date picker limited to the last 60 days and up to today;
  - the reminder time;
  - a footnote with the missed-pill sentence (§2).
- Turning the toggle on asks for notification permission, in context.

### 4.2 Notifications

- **Schedule.** Reminders are scheduled for the next 14 pill days. There is a main notification at the chosen time and a follow-up 2 hours later. The follow-up is removed as soon as that day is marked.
  - Ids: `pill-YYYYMMDD` and `pill-YYYYMMDD-followup`.
  - The schedule is rebuilt on launch, on foreground, on every settings change and after every mark.
  - At most 28 pending requests, which is under iOS's limit of 64 together with the existing reminders. Check the budget.
- **Content.**
  - Title "Đến giờ uống thuốc" and body "Viên 12/21 hôm nay.";
  - follow-up: title "Bạn đã uống thuốc hôm nay chưa?";
  - category `PILL_REMINDER` with the action "Đã uống" (`PILL_TAKEN`, no foreground launch needed).
- **The action.** It writes the `PillDose` for that day through the app's notification delegate, which the app installs at launch with `UNUserNotificationCenter.current().delegate`. Check whether `PartnerAppDelegate` or another delegate is already set and compose with it. It then cancels the follow-up.
- **Break week.** In the 7-day break of a `21+7` pack nothing is scheduled. The day before a new pack starts, the evening reminder still fires on the first pill day as usual.

### 4.3 Today (cycle mode, `.pill`, reminder on)

- A card "Thuốc tránh thai" shows "Viên 12/21" and the reminder time, with a button:
  - "Đã uống hôm nay" (`pillTakeToday`) before marking;
  - "✓ Đã uống lúc 21:04" afterwards, with a small "Bỏ đánh dấu" (`pillUndo`).
- In the break week the card reads "Tuần nghỉ · vỉ mới bắt đầu ngày 18 thg 10".
- When the reminder is off, the card is hidden.

### 4.4 Wording and doctor review

- All strings are in vi + en. The hormonal wording ("ra máu") stays as it is.
- The doctor doc gets new items for:
  - the missed-pill sentence;
  - the 2-hour follow-up;
  - the break-week behaviour;
  - whether progestin-only pills (a 3-hour window) need a different follow-up.

## 5. Testing

- **KickCore:**
  - `PillPack` for both types: day numbers, breaks, wrap to the next pack, month and DST boundaries, and the upcoming dates (break days skipped);
  - the reminder planner (ids, follow-up timing, removing the follow-up once marked, the 28-request budget);
  - settings load and save;
  - the backup settings table includes the new keys;
  - `ownedKeys` coverage (the existing test).
- **KickData:** one dose per day; delete-all; a backup round trip with `pillDoses`.
- **UI tests:**
  - set up a pack in Profile;
  - the Today card shows "Viên n/21";
  - marking from Today; undo;
  - break-week text, through a seeded start date;
  - the setting is hidden when the contraception is not the pill.
  - A DEBUG seed `-seedPill "21+7:<offsetDays>"`.
- **Screenshots:** the setup sheet and the Today card in vi light/dark and AX5.

## 6. Delivery

1. KickCore: settings, `PillPack`, the planner. KickData: `PillDose` and the store, plus the backup and reset additions. All with tests.
2. App:
   - the Profile row and sheet;
   - notifications (category, action, delegate, scheduling triggers);
   - the Today card;
   - strings;
   - UI tests and screenshots.
3. Docs: the doctor items, README, release checklist (a device test of the notification action and the break week), and one line in the review notes.
