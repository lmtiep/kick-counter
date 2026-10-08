# App Review notes (ready to paste into App Store Connect)

Written in English for the "Notes for Review" field. Updated for version 1.0 (phase 12, App Store readiness).

---

**What the app does**

Luna Mom is a free app for pregnant women and women trying to conceive. It has three modes, chosen during onboarding:
- Cycle tracking (period and fertility window, with optional ovulation test / basal body temperature logging);
- Pregnancy (week-by-week content, a fetal kick counter with a Live Activity on the Lock Screen, appointment reminders, weight tracking);
- "Trying to conceive" is the same cycle-tracking mode with a different framing.

There is a short pregnancy-journey switch in Profile to move between "trying to conceive" and "pregnant" at any time.

**No login, no accounts**

The app has no sign-in of any kind and no server-side account. It can be used fully offline, immediately after onboarding. There is nothing to test with a demo account because none exists.

**All data stays on the device (no iCloud) — Guideline 5.1.3(ii)**

In this version, all user data (kick counts, periods, cycle logs, weight entries, appointments, settings) is stored only in the app's local App Group container on the device, using SwiftData with CloudKit syncing turned off (`AppFeatures.cloudSync = false`). No data is mirrored to iCloud and no data leaves the device. This also means the previous "share with partner" mode (which depended on CloudKit sharing) is not available in this version; the mode picker and onboarding do not offer it, and any UI that referenced it has been removed or hidden.

The app's "App Privacy" declaration is "Data Not Collected": there is no server, no analytics SDK, no advertising SDK, and no third party receiving any data.

**Deleting data**

Profile has a "Delete all data" row (destructive, with a confirmation dialog) that permanently removes every kick count, period, cycle log, weight entry, appointment and setting on the device, cancels all pending/delivered local notifications, ends any running Live Activity, and returns the app to onboarding. Deleting the app also removes all of its data.

**Medical content — sources and disclaimers**

Pregnancy and cycle content (weekly articles, fetal size estimates using the Hadlock formula, due-date and ovulation estimates, maternal weight guidance using IOM 2009 ranges) is for general information only, not diagnosis or medical advice. This disclaimer appears in onboarding and in the in-app "Medical information" screen, and weekly content and the "Trying to conceive" screens repeat that predictions are estimates, not a method of contraception. Sources are listed in the in-app "Medical information → Sources" screen. Medical content for this release has been reviewed as described in `docs/content-review-for-doctor.md`; content not yet reviewed is hidden from the App Store build.

**How to reach each mode / onboarding choices**

On first launch, onboarding asks whether the user wants to track their cycle, is trying to conceive, or is already pregnant, and sets up the corresponding mode. The mode (and the underlying goal, for cycle tracking) can be changed later from Profile → "Goal". There is no partner/"share with dad" entry anywhere in onboarding or the mode picker in this version.

**Notifications**

All notifications are local (scheduled on-device), not push notifications: a daily kick-count reminder, a warning if a kick session runs past two hours, period/ovulation reminders for cycle tracking, and appointment reminders one day ahead. Notification permission is requested contextually (first kick-count tap, first period entry, or when the user turns on a reminder), not at first launch. Declining notifications never blocks any app feature.

**Live Activity**

Starting a kick-counting session shows a Live Activity on the Lock Screen / Dynamic Island with a "+1" button and a running count out of 10. To test it: open the app, start counting kicks, then lock the phone — the Live Activity should appear and let you add kicks from the Lock Screen. It automatically ends shortly after 10 kicks are reached, or is marked as abandoned after about 12 hours of inactivity.

**Background modes / capabilities**

The app declares only the App Group entitlement, used to share data between the app and its widget extension. No background modes, CloudKit entitlements or remote-notification capability are declared in this version, since none of them are used while `cloudSync` is off.

**Age rating**

The medical/treatment-information questionnaire answer should reflect that pregnancy, fertility and weekly medical content appears frequently throughout the app (not infrequently), consistent with a 16+ outcome. There is no user-generated content, chat, advertising or web view.

**Privacy policy and support**

Privacy Policy: https://lmtiep.github.io/kick-counter/privacy.html
Support: https://lmtiep.github.io/kick-counter/support.html

Both pages are also linked in-app, from Profile → "Information".
