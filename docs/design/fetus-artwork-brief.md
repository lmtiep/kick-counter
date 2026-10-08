# Fetus artwork brief (Bản mô tả yêu cầu tranh minh họa thai nhi)

For: an illustrator commissioned to draw the set, or whoever is evaluating a licensed stock-illustration set as a substitute. Written from phase 11 of the week-sizes design (`docs/superpowers/specs/2026-10-08-week-sizes-design.md` §5).

Scope: 39 images, one per pregnancy week 4–42. Nothing here is medical advice; every clinical claim is for the illustrator's reference only and is subject to the doctor checklist in §5.

---

## 1. Purpose and placement (Mục đích và vị trí hiển thị)

The app ("Mầm" / Luna Mom) is a bilingual (Vietnamese/English) cycle- and pregnancy-tracker. These images are the fetus illustration shown at two places, always next to the week's text content, never alone:

1. **Week article card** (`App/Pregnancy/WeekArticleView.swift`, `artworkRow`). A small square thumbnail, side by side with the week's fruit-size illustration. The square is roughly half the card's width (about 150–180 pt on a typical iPhone, depending on screen width and Dynamic Type), with the image inset 16 pt from the square's edge (`scaledToFit().padding(16)`), on a rounded-rectangle (18 pt corner) filled with the `pregSoft` token — a soft peach card in light mode, a dark plum card in dark mode.
2. **Week detail hero** (`App/Pregnancy/WeekDetailView.swift`, `backgroundLayer`). A large hero image, up to 320 pt tall, full width, inset 28 pt (`scaledToFit().padding(28)`), floating over a soft circular glow (the `card` token at 70%→0% opacity, radius 150 pt) on top of a peach-to-cream gradient background. Tapping it (or swiping) changes week. This is the most prominent, closest-to-full-size placement.

Both placements render the same asset; there is no separate "hero" artwork. The image must therefore look good both very small (peek thumbnail, ~150 pt) and large (hero, ~300 pt), and on both of its backgrounds (see §2).

Until a week's image exists, the app falls back to a generic `Fetus` placeholder image (same slot mechanism), so a missing week degrades gracefully but should be filled in before release.

## 2. Delivery spec (Thông số giao file)

Exactly as agreed in the design spec (§5), repeated here for the illustrator:

- **Names.** `Fetus-W04`, `Fetus-W05`, … `Fetus-W42` — one file per integer week, 39 total. Two-digit, zero-padded week number, no gaps.
- **Format.** Vector PDF or SVG preferred (scales losslessly from the 150 pt thumbnail to larger future uses). PNG is acceptable at **1024×1024 px**, transparent background, if vector is not available.
- **Canvas and padding.** Subject centred, **8% padding** on all sides of the canvas (i.e. the artwork's bounding box occupies the central ~84% of the square canvas). This matches how both call sites apply their own additional inset — don't rely on the app's padding to also center the subject.
- **Transparency.** Full alpha transparency outside the subject. No background fill, no canvas-edge vignette.
- **Both-background legibility.** The app shows this image on two different warm, mid-light backgrounds (peach-ish, see hex values below) in light mode and on dark plum/brown backgrounds in dark mode. One single artwork variant must read clearly on all of them — light and dark variants are **optional**, not required. In practice this means: never use pure white or very pale fills that would vanish on the light peach card, and keep enough dark/mid-tone in every shape (an outline or shading edge) that the silhouette still reads on the dark card. If the illustrator does choose to deliver light/dark variants, name them `Fetus-W##` (default/light) and `Fetus-W##-Dark`; the drop-in step in §6 covers both cases.
- **Style.** Matches the "Mầm" handoff (`docs/design/mam-handoff/README.md`): flat, warm, gently rounded illustration — not photorealistic, not clinical/diagram-style, not cartoonish-cute either. Soft shadows as flat shapes (no blurred filters), 2–4 tones per form, consistent soft outline. Palette, drawn from the handoff's design tokens:
  - Primary warm accent (skin/body base tone, used sparingly and never as literal skin colour — see §4): `#C9673E` / darker `#B8572F`.
  - Soft background/glow tones the art should harmonise with: `#F7E3D7` (light card), `#FCEBDD` → `#F6D7C2` (hero glow), `#EBB394` / `#F7DCC9` (hero gradient).
  - Outline / shade tone: `#2B201C` (the app's near-black text colour) at low opacity, or a darker mix of the body tone — use this for the defining edge-line, not pure black.
  - Dark-mode equivalents the art must still survive against: card `#262019`, hero gradient `#5A3424` / `#3A2A22`, glow `#4A2E22` / `#3A2A22`.
  - Do not introduce new brand colours; everything should look like it belongs next to the fruit illustrations and the rest of the app.
- **Licence.** Perpetual, worldwide, for commercial in-app use (the app is sold / distributed commercially). No attribution requirement in the shipped app. If evaluating a licensed stock set instead of commissioning original art, confirm its licence meets this bar in writing before buying.

## 3. Per-week table (Bảng theo từng tuần)

Guidance per week: what feature(s) that week's "Bé" (baby) content is actually about (so the illustration matches the text, not generic stock anatomy), an **approximate** head-to-body proportion as a drawing guide only, pose guidance, and what must not appear at that stage. Head:body ratios are rough illustrator guides, not measured biometry — every one is marked **doctor to confirm**. Anything stated as fact beyond what the app's own week content says is marked **(verify)**.

Weeks 4–8 are embryonic, not yet fetal. Keep these **gentle, non-graphic, and stylised** — a soft abstract form, not a miniature detailed human. Do not render visible organs, raw tissue, or clinical/diagram realism at any week.

| Wk | Features to show (from that week's content) | Head:body (approx., doctor to confirm) | Pose | Must NOT appear |
|---|---|---|---|---|
| 4 | Just-implanted, dividing cluster of cells; no body plan yet | n/a — no figure yet | Abstract soft dot/cluster shape, not a figure | Any face, limbs, or recognisable baby form |
| 5 | Neural tube and earliest heart forming | n/a — pre-figurative | Simple curved bud/comma shape | Face, eyes, limbs, fingers |
| 6 | First flickering heartbeat (on scan); tiny limb buds; earliest dark eye spots | Head dominates almost the whole form (verify) | Curled comma/C shape with small bumps for limb buds | Detailed face, open eyes, hands, feet |
| 7 | Brain growing fast, head visibly large for body; arm buds flattening into paddle shapes | Head ~ as large as rest of body (verify) | Curled "C", paddle-shaped arm stubs, no legs detail yet | Fingers, visible eyes, facial features, legs |
| 8 | Fingers/toes just beginning, still webbed; faint tiny movements | Head still clearly dominant (verify) | Curled "C", paddle hands/feet with faint webbing lines | Separated fingers/toes, open eyes, hair |
| 9 | All main organs begun; muscles developing; limbs now bend at the elbow | Head large but body lengthening (verify) | Curled, elbows slightly bent, knees tucked | Visible organs, detailed face, hair, nails |
| 10 | Now called a fetus; major organs in place; tiny nails just starting | Head roughly half the total length (verify) | Curled fetal "C" pose, limbs tucked | Open eyes, visible nails detail, hair |
| 11 | Bones starting to harden; head about half the body length; kicks/stretches/hiccups | Head ≈ half of body length (per content) | Relaxed curl with one limb mid-stretch/kick | Open eyes, visible genitalia, hair |
| 12 | Reflexes developing — opens/closes fingers; kidneys starting to make urine | Head still proportionally large (verify) | Curled, one hand slightly open/closing | Open eyes, detailed face, visible genitalia |
| 13 | Vocal cords forming; intestines settled in the belly; fingerprints just starting | Head slightly smaller relative to body than wk 11–12 (verify) | Curled "C", hands near face | Open mouth/vocalising cue, visible genitalia, fine fingerprint detail |
| 14 | First facial expressions (squint, frown); fine lanugo hair starts covering the skin | Head:body easing toward ~1:3 (verify) | Gently curled, relaxed face | Open eyes, visible lanugo texture detail (keep it implied, not textured) |
| 15 | Skeleton keeps hardening; senses light even with eyelids closed | ~1:3 (verify) | Curled, calm, eyelids closed | Open eyes, detailed bone/skeleton rendering |
| 16 | Eyes move slowly behind closed lids; heart pumping a large blood volume | ~1:3 (verify) | Relaxed curl, closed eyes | Open eyes, visible heart/internal anatomy |
| 17 | Fat just starting under the skin; cartilage turning to bone; cord growing stronger | ~1:3 (verify) | Curled, slightly fuller limbs | Visible fat/chub texture, detailed cord anatomy if cord is shown (see §4) |
| 18 | Ears now in final position, may start to hear; yawns, stretches, sucks thumb | ~1:3 (verify) | One hand near mouth (thumb-suck cue), relaxed curl | Open eyes, detailed ear anatomy |
| 19 | Protective vernix coating forming; hearing/taste/smell/touch developing | ~1:3 (verify) | Relaxed curl, smooth skin (vernix implied by soft sheen, not texture) | Visible skin texture/coating detail, open eyes |
| 20 | Halfway point; now measured head-to-heel; swallows amniotic fluid | ~1:3 to 1:3.5 (verify) | Relaxed curl, slightly more extended than earlier weeks | Open eyes, visible internal swallowing cue |
| 21 | Movements stronger and more frequent; taste buds working | ~1:3.5 (verify) | Mid-motion curl (one limb extended as if kicking) | Open eyes, visible tongue/taste detail |
| 22 | Eyebrows and eyelashes growing; can grip, may hold the cord | ~1:3.5 (verify) | Relaxed curl, one hand gently closed as if gripping | Open eyes, detailed cord-gripping anatomy |
| 23 | Can hear loud outside sounds; lungs developing airway branches | ~1:3.5 (verify) | Relaxed curl | Visible internal lung/airway detail |
| 24 | Lungs starting to mature; regular sleep/wake pattern | ~1:3.5 (verify) | Calm, "sleeping" curl | Open eyes, visible lung anatomy |
| 25 | May respond to mother's voice with movement; hands now fully formed, explores by touch | ~1:3.5 (verify) | Relaxed curl, hand near face/body as if touching | Open eyes, exaggerated motion |
| 26 | Eyes beginning to open; may startle at loud noise | ~1:3.5–1:4 (verify) | Relaxed curl, eyes just slightly open or still closed (illustrator's call; keep subtle) | Fully wide-open eyes, startled/dramatic expression |
| 27 | Brain very active; clear sleep/wake cycles; rhythmic hiccup jolts | ~1:4 (verify) | Calm curl | Visible brain anatomy, dramatic motion |
| 28 | Can now open/close eyes and blink; brain growing fast | ~1:4 (verify) | Relaxed curl, eyes gently open or closed | Wide staring eyes, visible brain detail |
| 29 | Muscles and lungs maturing; strong, easy-to-feel kicks and jabs | ~1:4 (verify) | Mid-motion curl, one limb extended (kick) | Visible muscle definition, internal lung detail |
| 30 | Bone marrow now making red blood cells; lanugo starting to disappear | ~1:4 (verify) | Relaxed curl, smoother skin (less lanugo cue than wk 14–20) | Visible blood/marrow anatomy |
| 31 | All five senses working; turns head side to side | ~1:4 (verify) | Relaxed curl, head turned slightly | Exaggerated sensory cues (no visible "listening" ears, etc.) |
| 32 | Practises breathing movements; finger/toe nails now fully grown in | ~1:4 (verify) | Calm curl, chest subtly implied as "breathing" (static image — a gentle pose is enough) | Visible nail detail beyond a soft rounded tip |
| 33 | Bones hardening but skull staying soft; antibodies passing from mother | ~1:4 (verify) | Relaxed curl, head slightly rounded/soft-looking | Visible skull/bone anatomy |
| 34 | Nervous system and lungs maturing; a fat layer filling out the body | ~1:4, body visibly rounder (verify) | Relaxed curl, fuller limbs/body | Visible internal anatomy |
| 35 | Kidneys now fully developed; less room to move, still active daily | ~1:4 (verify) | Curled, tucked (less room implied by tighter curl) | Visible kidney/internal anatomy |
| 36 | May drop lower in the pelvis (especially a first pregnancy); most lanugo now gone | ~1:4, close to newborn proportion (verify) | Head-down curl is a reasonable cue, but not required | Visible lanugo texture, exaggerated head-down "falling" pose |
| 37 | Early term; practises sucking, blinking, breathing | ~1:4 (verify) | Calm curl, relaxed face | Open mouth mid-"suck", wide eyes |
| 38 | Grasp is now firm; organs ready to work outside the womb | ~1:4 (verify) | Relaxed curl, hand gently closed | Visible internal organ readiness cues (keep it a calm pose, not anatomical) |
| 39 | Full term; fat layer helps keep baby warm after birth | ~1:4, rounded full-term body (verify) | Relaxed, full-bodied curl | Newborn-only cues (umbilical clamp, crying face, eyes open and alert) |
| 40 | Ready to be born; most babies don't arrive exactly on this day | ~1:4, full-term newborn-like proportions (verify) | Relaxed, full-bodied curl, calm | Birth/delivery imagery, open eyes, crying expression |
| 41 | Still growing; skin may be slightly dry; nails may extend past fingertips | Same as wk 40 (verify) | Same relaxed full-term curl as wk 40 | Visible dry-skin texture, exaggeratedly long nails |
| 42 | Post-term; care team monitoring closely; may have less lanugo and vernix at birth | Same as wk 40 (verify) | Same relaxed full-term curl as wk 40 | Any monitoring/medical equipment, distressed expression |

General rules that apply across all weeks (see §4 for the full consistency list): never show genitalia at any week, never show an open mouth as if crying, never show a visible clamp/cut cord, and keep facial detail minimal and neutral throughout — the point is a developmental cue, not a portrait.

## 4. Consistency rules across weeks (Quy tắc nhất quán giữa các tuần)

So the 39 images read as one set, not 39 unrelated drawings:

1. **Same viewpoint.** Three-quarter or side view of the curled fetal pose throughout (matches the handoff's existing placeholder `assets/fetus.png` framing). Don't switch to a frontal "floating baby" view partway through the set.
2. **Same line weight and shading approach** across every week: one consistent outline thickness, the same flat-shadow-as-shape technique, the same number of tonal layers (2–4).
3. **Cord and placenta: pick one treatment and use it everywhere, or omit everywhere.** Recommendation: omit both entirely (the app never explains them elsewhere), to keep the set simple and avoid 39 separate judgment calls about cord position. If the illustrator prefers to include a faint cord for realism from whichever week it would first be visible, it must then appear, consistently drawn, in every week from that point to week 42 — never appearing and disappearing.
4. **Skin tone: neutral and stylised**, not tied to any one real-world skin colour — a single warm, muted, illustration-native tone (drawn from the palette in §2) used across all 39 weeks, not varied week to week.
5. **No gendered features, ever.** No visible genitalia at any week, no gendered hair, clothing, or accessories (none of these exist yet in utero anyway, but the point is zero gender signalling in the artwork, matching how the app refers to "Bé" / "baby" without gendered language).
6. **No text, numbers, or scale bars baked into the artwork.** The app places the week number and size elsewhere (chip, size line); the image is pure illustration.
7. **Progression should feel continuous.** Looking at the 39 images in sequence (e.g. the review sheet in §6) should show one baby gradually growing and uncurling, not 39 disconnected poses.

## 5. Medical-accuracy checklist (Danh sách kiểm tra y khoa cho bác sĩ)

For the reviewing doctor, per finished image (or per batch, if reviewing in groups):

- [ ] The developmental stage shown (embryonic weeks 4–8 vs. fetal weeks 9+) is appropriate for that week and not graphic/clinical.
- [ ] The head-to-body proportion is a reasonable approximation for that week (table in §3 is an illustrator's guide only, not sourced from biometric data — doctor's judgement governs).
- [ ] Eyes are not shown open before the week they plausibly first open (table suggests ~week 26; confirm or adjust).
- [ ] No fine hair/lanugo texture is rendered before the week it starts to appear (table suggests ~week 14; confirm or adjust).
- [ ] No ear, fingernail, or other fine anatomical detail appears earlier than that feature's week in the app's own content.
- [ ] No pose, expression, or detail in any week could be read as medically concerning (e.g. implying distress, abnormal position, or a visible complication).
- [ ] Weeks 4–8 are suitably gentle/non-graphic and do not imply a fully formed miniature human before that is accurate.
- [ ] The cord/placenta treatment (shown consistently, or omitted entirely — see §4.3) is medically reasonable for every week it appears in, if the illustrator chose to show it.
- [ ] Nothing in the set could be mistaken for clinical/diagnostic imagery (e.g. ultrasound-style, cross-section, or diagram realism).
- [ ] Final sign-off: the full 39-image set is approved for release, or specific weeks are flagged with required changes.

## 6. Drop-in steps for the developer (Các bước tích hợp cho lập trình viên)

Once artwork files arrive:

1. **Create the imageset.** For each week, create `App/Images.xcassets/Fetus-W##.imageset/` (e.g. `Fetus-W04.imageset`, matching `WeekArtworkName.fetus(week:)`'s naming) containing the artwork file(s) and a `Contents.json`.

   For an **SVG** (preferred — enable "Preserve Vector Data" so it stays crisp at both the ~150 pt thumbnail and the ~300 pt hero size):
   ```json
   {
     "images" : [
       {
         "filename" : "Fetus-W04.svg",
         "idiom" : "universal"
       }
     ],
     "properties" : {
       "preserves-vector-representation" : true
     },
     "info" : {
       "author" : "xcode",
       "version" : 1
     }
   }
   ```

   For a **PNG** (1024×1024, transparent, single universal scale — same pattern already used by `Fetus.imageset`):
   ```json
   {
     "images" : [
       {
         "filename" : "Fetus-W04.png",
         "idiom" : "universal",
         "scale" : "3x"
       }
     ],
     "info" : {
       "author" : "xcode",
       "version" : 1
     }
   }
   ```

   If the illustrator delivered separate light/dark variants (optional per §2), add an `"appearances"` entry per image (`"appearance": "luminosity", "value": "dark"`) instead of relying on one universal image — follow the same two-image pattern Xcode generates for any other asset with a dark variant in this catalog.

   `WeekArtwork.fetus(_:)` already falls back to the shared `Fetus` placeholder when a week's asset is missing, so imagesets can be added incrementally; nothing else in the Swift code needs to change.

2. **Run the week-article screenshot tests.** `UITests/WeekArticleScreenshotTests.swift` is the relevant suite (also see `UITests/PregnancyScreenshotTests.swift` for the Today-tab hero, which uses the same `WeekArtwork.fetus`). Run at least:
   - `WeekArticleScreenshotTests.testVietnameseLightPeekAndExpanded` — light mode, Vietnamese, both sheet detents, plus week 25 via the chip.
   - `WeekArticleScreenshotTests.testEnglishDark` — dark mode, English.
   - `WeekArticleScreenshotTests.testLargestText` — accessibility text size (AX5), checks nothing is cut off.
   - `WeekArticleScreenshotTests.testFromTheSafetyCard` — opened via the symptoms safety-card path.

   These exercise week 24 (and 25); they confirm the new artwork renders at the correct size, on both card backgrounds, in both themes, and under Dynamic Type — not just that the file loads. Re-run (or add) equivalents for a spot-check of a few other weeks across the embryonic/fetal boundary (e.g. week 8, week 14, week 40) before considering the set done.

3. **Check the screenshots.** Pull the attached screenshots from the test run (Xcode's test report, or wherever CI uploads attachments) and visually confirm: the image is centred and not cropped at either size, it reads clearly against both the light peach card and the dark card, and it matches the week's expected stage per §3.

---

**Open questions for the app owner / doctor**, not resolved by this brief:
- Whether to include a faint umbilical cord from the week it would first be visible (recommended: omit entirely for simplicity — see §4.3), or to commission every week with one consistent cord treatment.
- The exact week eyes are shown opening (table above assumes ~26 as a gentle illustrator cue; the doctor may prefer a different week or a fully-closed-until-term approach).
- Whether commissioning original art or buying a licensed set is preferred — this brief supports evaluating either (the delivery spec in §2 doubles as acceptance criteria for a licensed set).
