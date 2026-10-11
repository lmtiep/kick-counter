# App Review notes (ready to paste into App Store Connect)

Paste the text between the lines into App Store Connect → App Review Information → Notes. It matches the sheet "Khác",
row "Notes", of `Luna Mom - huong dan App Store Connect.xlsx` (11/10/2026): 3166 bytes UTF-8, limit 4000.

Before pasting, handle the `[OWNER: …]` sentence: add the obstetrician's name and review date only if the review is
really done, otherwise delete the bracket.

---

Luna Mom is a free, offline app for women who track their cycle, are trying to conceive, or are pregnant. There is no sign-in, no account, no server, no ads, no analytics and no third-party SDK. All data is stored only on the device (SwiftData in the app's App Group container; CloudKit/iCloud sync is off, so no health data is stored in iCloud - Guideline 5.1.3(ii)). App Privacy: Data Not Collected.

HOW TO TEST
1. First launch: choose "Track my cycle", "Trying to conceive" or "Pregnant". Switch at any time in Profile > Goal.
2. Pregnancy: choose "Pregnant" and enter a due date about 10 weeks from today (about week 30) to see every pregnancy feature: Today (week, baby size, weekly article), Knowledge, Weight, Appointments.
3. Kick counter (Kicks tab): tap to count, then lock the phone. A Live Activity on the Lock Screen / Dynamic Island has a "+1" button. It ends after 10 kicks or after about 12 hours without activity.
4. Contraction timer (Today shortcut from week 28, or Kicks tab > "Time contractions"): one Start/Stop button. A second Live Activity has a Start/Stop button that works from the Lock Screen without opening the app and ends 2 hours after the last contraction. When contractions match the common 5-1-1 guidance (week 37+), or occur before week 37, the app only advises contacting a doctor or hospital and shows a "Call 115" button (115 is the emergency ambulance number in Vietnam) that opens the system dialer. It never diagnoses labor.
5. Cycle tracking: Calendar > "Edit period" to tick period days. Today shows predictions, labelled as estimates and not contraception.
6. Pill reminder: Profile > Contraception = "The pill", then Profile > "Pill reminder". A local notification has a "Taken" action. The app gives no missed-pill medical instructions; it says to follow the pack leaflet or ask a doctor or pharmacist.
7. Data: Profile > Data > "Back up to a file" exports a .lunamom file through the system share sheet (the user chooses where it goes; the app uploads nothing) and "Restore from a file" imports one after confirmation. Profile > "Delete all data" erases everything on the device, cancels notifications and ends Live Activities.

NOTIFICATIONS: all local, none are push. Permission is requested in context (first kick count, first period, or turning on a reminder), never at launch; declining never blocks a feature. No background modes; the only entitlement is the App Group shared with the widget extension.

MEDICAL CONTENT: general information only, not diagnosis. A disclaimer appears in onboarding and in Profile > Medical information, which lists the sources (WHO, ACOG, NHS, Vietnam Ministry of Health, Hadlock fetal weight formula, IOM 2009 weight ranges). Due date = 280 days from the last period; all predictions are labelled as estimates. The app is not a medical device. [OWNER: add one sentence here naming the obstetrician who reviewed the content and the date - only if true - then delete this bracket.]

Privacy policy: https://lmtiep.github.io/kick-counter/privacy.html
Support: https://lmtiep.github.io/kick-counter/support.html
Both are also linked in the app: Profile, under "Medical information".

---
