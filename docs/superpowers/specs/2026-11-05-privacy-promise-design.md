# Privacy promise messaging (1.1, item 1)

Date: 2026-11-05 · Status: approved in conversation · Branch: `feat/privacy-promise`

## Why
Competitor reviews (`~/Downloads/Luna Mom - phan tich review doi thu.xlsx`) show that
paywalls, auto-renew charges, ads and fear of data being sold are top complaints.
Luna Mom has none of these, but says so in only one small onboarding line.

## Design
- **Onboarding step 1 (welcome):** replace the single privacy line
  (`onboarding.privacy`, `onboardingPrivacyNote`) with four short lines, each with an
  icon, in the existing `commitment(...)` style: Free · No ads · No account needed ·
  Your data stays on your iPhone. Keep the medical line. Identifiers
  `onboardingPromiseFree`, `onboardingPromiseNoAds`, `onboardingPromiseNoAccount`,
  `onboardingPromiseOnDevice`. Must fit at AX5 and in en/vi without clipping the
  layout (the illustration can shrink, as today).
- **Profile:** in the about card, a new row "Quyền riêng tư của bạn" / "Your privacy"
  (`profilePrivacyPromise`) above the external privacy-policy link, opening a short
  screen with the same four points plus: notifications are created on the phone only;
  a backup leaves the phone only when you share the file yourself; deleting all data
  erases everything on the phone. A link at the bottom opens the full privacy policy.
- **App Store:** Promotional Text (vi + en) leads with the four points; no review
  needed. The owner applies it, or Claude does when App Store Connect is signed in.
- **Wording rules:** nothing beyond what the app does and the "Data Not Collected"
  label says; no "100 % secure" claims; no "bất thường"/"abnormal".

## Approaches
One sensible way: reuse the onboarding `commitment` rows and a plain Profile screen.
A separate onboarding page was rejected (adds a step; competitors are criticised for
long onboarding).

## Testing
OnboardingUITests and a ProfileUITests check for the identifiers; onboarding and
profile screenshots (vi/en light, AX5) re-read for clipping.
