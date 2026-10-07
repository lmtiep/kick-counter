# Cycle tracking goal and a new onboarding (Phase 9)

Date: 2026-10-08 · Status: approved in conversation · Branch: `feat/cycle-tracking`

## 1. Goal

Users who are not trying to conceive get a plain period-tracking experience. It reuses the cycle mode's calendar, predictions and logging, but puts "when is my next period" first and handles contraception honestly.

Onboarding gains a three-way goal question, the user's period and cycle lengths, regularity, contraception (tracking only), an early "next period around …" payoff, and a notification opt-in.

The input was a review of Flo's onboarding, 64 screenshots summarised in the session notes. We adopt these ideas:
- a single early goal fork;
- "I don't remember" / "Not sure" escape hatches;
- short "why we ask" notes;
- an early prediction payoff.

We avoid these:
- a 50-screen flow;
- bundled ad-tracking consent;
- "x% of users say…" persuasion;
- a commitment ritual.

No Flo copy or artwork is reused.

## 2. Decisions made with the user

| Topic | Decision |
|---|---|
| Relation to TTC | **One cycle mode with a goal setting** (approach A): `tracking` or `conceiving`. The same data, calendar and predictions; the goal only changes presentation. `AppMode` keeps `tryingToConceive`, `pregnant` and `partner`, and the cycle mode's goal lives in `CycleGoal` |
| Tracking presentation | "Next period in N days" first. The fertile window stays but is labelled "high chance of pregnancy" with a "not contraception" note. LH/BBT logging is hidden (it can be turned back on in Profile). Hormonal contraception hides the fertile window and ovulation |
| Onboarding length | Compact: 8 screens on the tracking branch, 7 on conceiving, 3–4 on pregnancy. Every question is skippable |
| Out of scope | Birth year, gynaecological conditions, sleep/skin/sex-life questions, Apple Health, user name, social-proof stats, commitment ritual, partner and knowledge features in the cycle mode |

## 3. Data (KickCore, App Group defaults; not synced, like `CycleSettings`)

```swift
public enum CycleGoal: String, Sendable, CaseIterable { case tracking, conceiving }
public enum Contraception: String, Sendable, CaseIterable {
    case none, condom, pill, implantOrInjection, hormonalIUD, copperIUD, fertilityAwarenessOrWithdrawal, otherOrPrivate
    public var isHormonal: Bool   // pill, implantOrInjection, hormonalIUD
}
public enum CycleRegularity: String, Sendable, CaseIterable { case regular, irregular, unknown }
```

- **Storage.** The values are stored next to `CycleSettings` under new `SettingsKey`s, and each loads with a default.
- **Default goal.** When nothing is stored, the goal is `conceiving`. Existing cycle-mode users therefore keep today's behaviour.
- **Contraception.** It defaults to `nil` (not asked) and is treated like `.none`.
- **Regularity.** It defaults to `.unknown`.
- **Lengths.** Typical cycle and period lengths keep using `CycleSettings` (ranges 21…45 and 2…10, defaults 28 and 5).

### 3.1 `CycleDisplayPolicy` (pure)

`CycleDisplayPolicy(goal:contraception:)` exposes the following:

| Property | conceiving | tracking, non-hormonal or none | tracking, hormonal |
|---|---|---|---|
| `showsFertileWindow` / `showsOvulation` | true | true | false |
| `fertileLabel` | `.fertileWindow` ("Cửa sổ thụ thai") | `.highPregnancyChance` ("Khả năng thụ thai cao") | n/a |
| `showsNotContraceptionNote` | false | true | false |
| `showsLHAndBBT` (daily log, unless the Profile override is on) | true | false | false |
| `predictedBleedLabel` | `.predictedPeriod` | `.predictedPeriod` | `.withdrawalBleed` ("Chảy máu dự kiến") |
| `headline` (Today) | existing TTC headline | `.nextPeriod` ("Kỳ kinh tới sau N ngày" / "Ngày thứ X của kỳ kinh" / "Trễ N ngày") | same as the column to its left |
| `reminderKinds` | existing (period soon, fertile window, …) | `[.periodSoon, .periodLate]` | `[.periodSoon, .periodLate]` |

`showsLHAndBBT` also has a Profile override, "Hiện que thử rụng trứng & nhiệt độ", which is stored and off by default for tracking.

### 3.2 Onboarding coordinator (pure)

`OnboardingFlow` holds the answers and returns the ordered steps for the chosen goal:

- **tracking:** `welcome, goal, lastPeriod, periodLength, cycleLength, regularity, contraception, result`
- **conceiving:** `welcome, goal, lastPeriod, periodLength, cycleLength, regularity, result`
- **pregnant:** `welcome, goal, dueDate, result` (the existing due-date step, with LMP inside it)

How skipped or "don't know" answers are handled:
- A skipped length keeps the default.
- "I don't remember" on the last period sets no period, so the result screen shows no date.
- A skipped contraception answer stays `nil`.

`finish()` returns the values to persist:
- `AppMode`
- `CycleGoal`
- `CycleSettings`
- the optional first period start
- `CycleRegularity`
- `Contraception?`
- the due date

The view saves these with the existing stores. The cycle branch's first period goes through `CycleCoordinator`, as it does today.

## 4. Screens

### 4.1 Onboarding

Shared across steps:
- The existing "Mầm" onboarding visuals.
- A progress bar showing the step index out of the branch's step count.
- A back button.
- A "Bỏ qua" / "Không chắc" button on every question step.
- Identifiers `onboarding<Step>` and `onboardingSkip`.

Steps:
1. **Welcome.** The existing screen, plus a one-line privacy note: "Dữ liệu chỉ nằm trên máy và iCloud của bạn. Không quảng cáo, không bán dữ liệu."
2. **Goal.** Three large cards (`onboardingGoal-tracking`, `-conceiving`, `-pregnant`):
   - "Theo dõi chu kỳ", subtitle "Hiểu cơ thể, biết trước kỳ kinh"
   - "Mong con"
   - "Đang mang thai"
3. **Last period.** The existing calendar, plus "Không nhớ".
4. **Period length.** A wheel picker from 2 to 10, default 5.
5. **Cycle length.** A wheel picker from 21 to 45, default 28, with a one-line explanation.
6. **Regularity.** Three choices. "Không đều" reveals a reassurance line.
7. **Contraception.** Eight choices, tracking only, with a "Vì sao hỏi" line.
8. **Result.**
   - With a last period: "Kỳ kinh tới dự kiến khoảng {date}", computed with `CyclePredictor` from the answers.
   - Without one: "Ghi ngày bắt đầu kỳ kinh tới để Luna Mom dự đoán cho bạn."
   - Below that: "Bật nhắc nhở" (asks for notification permission, then finishes) and "Để sau".
   - The pregnancy branch shows its existing ending with the same two buttons.

### 4.2 Cycle mode by goal

All of these read `CycleDisplayPolicy`:
- **Today:** the headline, fertile-window labels, and the not-contraception note.
- **Calendar:** fertile and ovulation markers, and the predicted-bleed wording in the legend.
- **Day-log sheet:** LH/BBT rows.
- **Reminders:** which kinds are scheduled.

Nothing else changes.

### 4.3 Profile

The cycle mode shows a **"Mục tiêu"** row (tracking / conceiving) and a **"Biện pháp tránh thai"** row (tracking only). The LH/BBT override toggle appears for tracking.

The mode picker offers three choices, "Theo dõi chu kỳ · Mong con · Mang thai":
- the first two set `tryingToConceive` with the matching goal;
- the third sets `pregnant`;
- partner mode is unaffected.

## 5. Testing

- **KickCore:**
  - `CycleDisplayPolicy` across every goal × contraception combination;
  - load and save of each setting, including the legacy default (`conceiving`);
  - `OnboardingFlow` step order per branch, skip defaults, "don't remember", and the values from `finish()`;
  - the reminder kinds per goal.
- **UI tests:**
  - complete each branch;
  - tracking with the pill → Today shows no fertile window;
  - switching the goal in Profile updates Today;
  - a legacy TTC user is not re-onboarded;
  - the result screen shows the predicted date.
- **Screenshots:**
  - the new onboarding steps;
  - Today in tracking (with and without hormonal contraception);
  - Profile rows;
  - all of these in vi/en, light/dark and AX5.
- Scoped CI per task. The docs task runs the full suite.

## 6. Delivery (branch `feat/cycle-tracking`)

1. **KickCore:** `CycleGoal`, `Contraception`, `CycleRegularity` and their persistence; `CycleDisplayPolicy`; reminder kinds per goal; `OnboardingFlow`.
2. **Onboarding:** the goal step with 3 choices; steps 3–8; the notification opt-in; UI tests and screenshots.
3. **Cycle screens:** Today, Calendar, day log and reminders applying the policy; UI tests and screenshots.
4. **Profile:** the goal and contraception rows, the LH/BBT override, the 3-choice mode picker; UI tests.
5. **Docs:**
   - `content-review-for-doctor.md` §11 (contraception wording, "not contraception" note, the hormonal-contraception behaviour, regularity copy);
   - README;
   - the release checklist (no CloudKit change).

   This step runs the full CI suite.
