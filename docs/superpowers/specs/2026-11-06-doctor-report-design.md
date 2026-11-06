# Report for the doctor (PDF): short design

Date: 2026-11-06 · Status: approved by owner in chat · Branch: `feat/doctor-report`

## Intent
A mother brings her own records to a check-up, on paper or sent over Zalo,
without an account and without anything leaving the phone until she shares
the file herself. Competitors are praised for "sharing with the doctor"; Luna
Mom has no way to do this today.

## Design (approved)

**Entry and choices**
- **Entry:** Profile → **"Xuất báo cáo cho bác sĩ"** / "Report for your
  doctor", available in pregnancy and in cycle mode.
- **Range:** 2 weeks, 4 weeks, or the whole pregnancy. In cycle mode the
  choices are the last 3 cycles or the last 6 cycles.
- **Sections:** toggles, all on by default.
  - **Pregnancy:** kicks (sessions per day with duration), contractions
    (episodes with count and averages, plus the water-broke mark if
    `feat/contraction-edit` lands first; otherwise leave a hook), weight,
    symptoms, appointments (with notes).
  - **Cycle:** periods (start and length), cycle lengths, symptoms and moods,
    BBT and LH if logged.

**The document**
- **Header:**
  - the app name, the generated date and the range;
  - in pregnancy, the current week and the due date;
  - in cycle mode, the average cycle and period length;
  - an optional name typed at export time. The name is **never stored**.
- **Body:** numbers and tables only. No interpretation, no advice and no
  alert wording.
- **Footer:** one line: "Do người dùng tự ghi trong Luna Mom. Không phải chẩn
  đoán y khoa." / "Recorded by the user in Luna Mom. Not a medical diagnosis."
- **Language and format:** the app language. Generated on the device with
  `UIGraphicsPDFRenderer` (or SwiftUI `ImageRenderer` into a PDF context), in
  A4, light theme, Be Vietnam Pro.
- **Sharing:** the share sheet. The file is written to a temp directory and
  deleted after sharing or cancelling. Its name is
  `LunaMom-BaoCao-YYYY-MM-DD.pdf` (vi) or `LunaMom-Report-…` (en).

**Code**
- The data assembly is a pure KickCore `DoctorReport.make(...)`, a value
  type of sections and rows, and it is tested.
- The layout is in the app.

## Approaches
- **On-device PDF** (chosen).
- **Image only:** worse for printing and multi-page.
- **CSV:** not readable by doctors.

## Constraints
- Strings go through `scripts/add-strings.py`.
- Never run UI tests locally; use CI with a `CI-Only-Testing` trailer.
- Nothing is sent anywhere automatically.

## Tests
- **KickCore:** range filtering at the edges, each section's rows, empty
  sections omitted, cycle and pregnancy headers.
- **UI:** the screen opens, the toggles work, export presents the share
  sheet, and a DEBUG flag writes the PDF to a known path so that a test can
  assert the page count is 1 or more.
- **Screenshots:** the export screen (vi light/dark, AX5). Render the PDF's
  first page to a PNG in the render test for visual review.
