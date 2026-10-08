# Past periods and the Today size wording (Phase 13)

Date: 2026-10-08 · Status: approved in conversation · Branch: `feat/past-periods`

## 1. Goal

Users should be able to add older periods quickly, so that the 6-cycle average, and with it the next-period prediction, rests on more data. Logging a past period must never leave it "ongoing" by mistake.

Separately, the pregnancy Today card's comparison should match the weight-based wording from Phase 11.

## 2. Decisions made with the user

- **Both mechanisms ("Cả hai").**
  - A period started on a past day is closed automatically at the typical period length.
  - The cycle history gets an "add a past period" sheet.
- **Today card wording.** It follows Phase 11's weight comparison, from week 10 on.

## 3. Behaviour

### 3.1 Auto-close when starting a period on a past day (KickCore)

`CycleCoordinator.startPeriodReturningID(on:)` keeps its signature. The new record depends on when it starts:
- **Already over by today.** When `start + typicalPeriodLength − 1 < today`, the record is `CycleRules.assumedPeriod(startingOn:typicalLength:today:)`, the same rule as onboarding's "last period". It is closed with the typical length.
- **Otherwise** (today, or recent enough that it could still be going on), it stays open, as before.

The stale-open-period closing (`staleOpenPeriod`) is unchanged. Today's "Undo" keeps working, because it deletes by id.

The calendar day sheet still lets the user end the period on another day (`endPeriod`). The "Kết thúc" button already shows on later days of an open period. For a closed period, the existing delete-and-redo is enough. The info line under the button already shows the range.

### 3.2 "Thêm kỳ kinh trước đây" (add a past period)

**Entry points.** The history page (`CycleHistoryView`) gets a button at the top, below the summary card: "Thêm kỳ kinh trước đây" (`cycleHistoryAddPast`). The empty state ("Chưa có kỳ kinh nào được ghi.") gets the same button.

**The sheet** (`AddPastPeriodSheet`, using the app's `LunaSheet` style):
- **Fields:**
  - "Ngày bắt đầu": a graphical `DatePicker` limited to dates on or before today. It defaults to one typical cycle before the oldest logged period, or 28 days before today when nothing is logged.
  - "Số ngày hành kinh": a stepper from 2 to 10. It defaults to `typicalPeriodLength` and has a live line under it, "Từ 3 thg 9 đến 7 thg 9".
- **Save** calls `CycleCoordinator.addPastPeriod(start:length:)`:
  - If the end falls after today, the period is stored as open (ongoing). Otherwise it is closed at `start + length − 1`.
  - The existing validation applies, and its errors show inline in the sheet: "Trùng với một kỳ kinh đã ghi" for an overlap, and "Không chọn được ngày trong tương lai" for a future date. Nothing is saved.
  - On success the sheet closes and a toast says "Đã thêm kỳ kinh". The history updates by itself.
- **Hormonal wording.** When `predictedBleedLabel == .withdrawalBleed`, the period words become "ra máu": "Thêm lần ra máu trước đây", "Số ngày ra máu".
- **Accessibility:**
  - identifiers `addPastStart`, `addPastLength`, `addPastSave`, `addPastError`;
  - the stepper reads "5 ngày";
  - the page works at AX5, with no fixed heights.

### 3.3 Today size wording (pregnancy)

The pregnancy Today card (`PregnancyCards.swift`, `pregnancy.baby.size`) depends on the week:
- **From week 10, when the week has a weight,** it reads "Bé nặng tương đương %@" / "Your baby weighs about as much as %@". This is a new key, `pregnancy.baby.sizeWeight`.
- **Weeks 4–9** keep "Bé to bằng %@".

The partner Today card (`PartnerTodayView`, hidden in 1.0) gets the same rule, so it is right when it comes back.

## 4. Testing

- **KickCore:**
  - Starting on a day 20 days ago creates a closed period of typical length.
  - Starting today, or 2 days ago with a typical length of 5, stays open.
  - `addPastPeriod`:
    - a closed range;
    - an open period when the end is after today;
    - an overlap error;
    - a future error;
    - the average from `CycleHistory` grows as periods are added.
- **UI tests:**
  - From the history page, add a past period: the row count goes up and the summary average appears.
  - The overlap error shows inline.
  - The calendar path: start a period on an old day, and the history row shows "hành kinh 5 ngày", not 10.
  - The Today card says "nặng tương đương" at week 24 and "to bằng" at week 8.
- **Screenshots:** the sheet in vi light/dark and AX5, and the history page with its new button.

## 5. Delivery

1. KickCore: the auto-close and `addPastPeriod`, with tests.
2. App: the sheet, the history button and the empty state, strings, the Today wording, UI tests and screenshots.
3. Docs: the doctor review (the wording of the "ra máu" variant and the assumed length), README, release checklist. The PR runs the full sharded suite.
