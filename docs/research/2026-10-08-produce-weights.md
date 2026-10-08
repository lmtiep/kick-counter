# Produce weights for the Hadlock size comparisons (weeks 10–42)

Date: 2026-10-08 · Branch: `feat/week-sizes` · Spec: `docs/superpowers/specs/2026-10-08-week-sizes-design.md` (§2, §3, §6 step 1)
Machine-readable copy: `docs/research/2026-10-08-produce-weights.json`

## 1. Method

- **Reference.** `weeks[].weightG` in `pregnancy-content.json` (Hadlock 1991 50th-percentile estimated fetal weight). Weeks 41–42 use the week-40 value (3619 g).
- **Tolerance.** `|typicalGrams − weightG| / weightG ≤ 0.25`. Every row below passes (checked by script; the largest deviation is week 12 at +20.7 %).
- **What "typical weight" means.** The whole item as bought, including peel, rind, husk, stone and core.
- **USDA rows (weeks 10–32).** These use USDA FoodData Central, SR Legacy (= USDA National Nutrient Database for Standard Reference, Release 28). SR household-measure weights are **edible portion**. The SR28 documentation (*Weights and Measures*) says: weights are for edible material without refuse. So each as-purchased weight is derived as

  `as purchased = edible-portion gram weight / (1 − refuse % / 100)`

  The refuse % and its description come from the same release: the `Refuse` / `Ref_desc` fields of `FOOD_DES` in the SR28 ASCII file. The FDC web page does not display refuse. Every note below shows both numbers, so the derivation can be checked. No weight is estimated by eye.
- **Weeks 33–42 (revised 2026-10-08 after the owner's review).** Each of these ten weeks uses a **different** produce item. None of them repeats an item from weeks 4–32, and a size variant counts as the same item. Two rows use USDA SR, computed as above: cauliflower (week 34) and honeydew (week 38). The other eight use:
  - Vietnamese institute or variety sources: VAAS bí xanh and bí đỏ, VNUF gấc, and the Vietaseeds cải thảo variety sheet;
  - provincial agriculture or science departments: Ninh Bình dưa hấu, Bến Tre dừa;
  - the Ministry of Agriculture newspaper (mãng cầu xiêm);
  - UF/IFAS Extension (jackfruit).

  Where a source gives a range, `typicalGrams` is the midpoint. §4 lists every row whose range ends fall outside ±25 %.
- **Choice rules applied.**
  - Prefer a familiar Vietnamese item.
  - Use one whole item per week, with no "pair of" or "bunch of".
  - No item runs for more than two consecutive weeks in weeks 10–32. In weeks 33–42 every item is distinct and new.
  - Vietnamese names are northern usage with a classifier.
- **Methodology sources.**
  - SR28 documentation: <https://www.ars.usda.gov/ARSUserFiles/80400535/DATA/SR/sr28/sr28_doc.pdf>, p. "Weights and Measures".
  - SR28 ASCII data (FOOD_DES refuse fields): <https://www.ars.usda.gov/ARSUserFiles/80400535/DATA/SR/sr28/dnload/sr28asc.zip>.
  - FDC SR Legacy CSV (portion text and FDC IDs): <https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_sr_legacy_food_csv_2018-04.zip>.

## 2. Table

| Week | Hadlock g | Produce (en) | vi | Emoji | Typical g | Deviation % | sourceKey | Portion used | Emoji note |
|---|---|---|---|---|---|---|---|---|---|
| 10 | 35 | a passion fruit | một quả chanh leo | 🟣 | 35 | +0.0 | `usda-passionfruit` | 1 fruit without refuse | no passion-fruit emoji; purple circle |
| 11 | 45 | an apricot | một quả mơ | 🍑 | 38 | -15.6 | `usda-apricot` | 1 apricot | no apricot emoji; peach is closest |
| 12 | 58 | a plum | một quả mận | 🍑 | 70 | +20.7 | `usda-plum` | 1 fruit (2-1/8" dia) | no plum emoji; peach is closest |
| 13 | 73 | a lime | một quả chanh không hạt | 🍋‍🟩 | 80 | +9.6 | `usda-lime` | 1 fruit (2" dia) | lime emoji needs iOS 17.4+ |
| 14 | 93 | a star fruit | một quả khế | ⭐ | 94 | +1.1 | `usda-carambola` | 1 medium (3-5/8" long) | no star-fruit emoji; star |
| 15 | 117 | a tangerine | một quả quýt | 🍊 | 119 | +1.7 | `usda-tangerine` | 1 medium (2-1/2" dia) |  |
| 16 | 146 | a tomato | một quả cà chua | 🍅 | 135 | -7.5 | `usda-tomato` | 1 medium whole (2-3/5" dia) |  |
| 17 | 181 | an orange | một quả cam | 🍊 | 179 | -1.1 | `usda-orange` | 1 fruit (2-5/8" dia) |  |
| 18 | 223 | an apple | một quả táo | 🍎 | 202 | -9.4 | `usda-apple` | 1 medium (3" dia) |  |
| 19 | 273 | an avocado | một quả bơ | 🥑 | 272 | -0.4 | `usda-avocado` | 1 avocado, NS as to Florida or California |  |
| 20 | 331 | an Asian pear | một quả lê Hàn Quốc | 🍐 | 302 | -8.8 | `usda-asian-pear` | 1 fruit 3-3/8" high x 3" diameter |  |
| 21 | 399 | a large ear of corn | một bắp ngô to | 🌽 | 397 | -0.5 | `usda-corn` | 1 ear, large (7-3/4" to 9" long) yields |  |
| 22 | 478 | a mango | một quả xoài | 🥭 | 473 | -1.0 | `usda-mango` | 1 fruit without refuse |  |
| 23 | 568 | a pomegranate | một quả lựu | 🍎 | 504 | -11.3 | `usda-pomegranate` | 1 pomegranate (4" dia) | no pomegranate emoji; red apple is closest |
| 24 | 670 | a jicama | một củ đậu | 🥔 | 716 | +6.9 | `usda-jicama` | 1 medium | no jicama emoji; potato is closest |
| 25 | 785 | a small cantaloupe | một quả dưa lưới nhỏ | 🍈 | 865 | +10.2 | `usda-cantaloupe` | 1 melon, small (about 4-1/4" dia) |  |
| 26 | 913 | a red cabbage | một bắp cải tím | 🥬 | 1049 | +14.9 | `usda-red-cabbage` | 1 head, medium (about 5" dia) | leafy-green emoji, not red |
| 27 | 1055 | a pomelo | một quả bưởi | 🍈 | 1088 | +3.1 | `usda-pummelo` | 1 fruit without refuse | no pomelo emoji; melon is closest |
| 28 | 1210 | a bottle gourd | một quả bầu | 🥒 | 1101 | -9.0 | `usda-calabash` | 1 gourd | no gourd emoji; cucumber is closest |
| 29 | 1379 | a large papaya | một quả đu đủ to | 🥭 | 1260 | -8.6 | `usda-papaya` | 1 fruit, large | no papaya emoji; mango is closest |
| 30 | 1559 | a large cabbage | một bắp cải to | 🥬 | 1560 | +0.1 | `usda-cabbage` | 1 head, large (about 7" dia) |  |
| 31 | 1751 | a pineapple | một quả dứa | 🍍 | 1775 | +1.4 | `usda-pineapple` | 1 fruit |  |
| 32 | 1953 | a durian | một quả sầu riêng | 🍈 | 1881 | -3.7 | `usda-durian` | 1 fruit | no durian emoji; melon is closest |
| 33 | 2162 | a coconut | một quả dừa | 🥥 | 1800 | -16.7 | `bentre-dua-ta` | "Trọng lượng trái từ 1,6-2,0 kg/trái khô" |  |
| 34 | 2377 | a large cauliflower | một cây súp lơ trắng to | 🥦 | 2154 | -9.4 | `usda-cauliflower` | 1 head large (6-7" dia.) | no cauliflower emoji; broccoli is closest |
| 35 | 2595 | a napa cabbage | một cây cải thảo | 🥬 | 2250 | -13.3 | `vietaseeds-cai-thao-va304` | "trọng lượng bao TB từ 1,5-3kg" |  |
| 36 | 2813 | a winter melon | một quả bí xanh | 🥒 | 2500 | -11.1 | `vaas-bi-xanh-so-1` | "quả già khối lượng 2,0 – 3,0 kg" | no wax-gourd emoji; cucumber is closest |
| 37 | 3028 | a gac fruit | một quả gấc | 🟠 | 2850 | -5.9 | `vnuf-gac-19` | "quả to (2,85 ± 0,95 kg)" (accession GAC-19) | no gac emoji; orange circle |
| 38 | 3236 | a honeydew melon | một quả dưa mật | 🍈 | 2783 | -14.0 | `usda-honeydew` | 1 melon (6" - 7" dia) |  |
| 39 | 3435 | a small jackfruit | một quả mít nhỏ | 🟢 | 2948 | -14.2 | `ufifas-jackfruit-hs882` | "A few cultivars are small fruited, weighing 3 to 10 pounds (1.4-4.5 kg) each." | no jackfruit emoji; green circle |
| 40 | 3619 | a watermelon | một quả dưa hấu | 🍉 | 3500 | -3.3 | `ninhbinh-dua-hau-hac-my-nhan` | "khối lượng quả trung bình 3 - 4 kg" |  |
| 41 | 3619 | a pumpkin | một quả bí đỏ | 🎃 | 3150 | -13.0 | `vaas-bi-do-mat-sao-2` | "khối lượng quả trung bình 3,0-3,3 kg" |  |
| 42 | 3619 | a soursop | một quả mãng cầu xiêm | 🍈 | 3000 | -17.1 | `nnmt-mang-cau-xiem` | "trái sai và to, nặng trung bình từ 2 - 4 kg/trái" | no soursop emoji; melon is closest |

**33 of 33 rows are within ±25 %.**

## 3. Sources (keyed by sourceKey)

- **`usda-passionfruit`** — USDA FoodData Central, SR Legacy: Passion-fruit, (granadilla), purple, raw (FDC ID 169108). <https://fdc.nal.usda.gov/food-details/169108/nutrients>. Portion used: "1 fruit without refuse". Portion "1 fruit without refuse" = 18 g edible portion (SR weights exclude refuse). SR28 refuse 48% (Shell). As purchased = 18 / (1 - 0.48) = 35 g.
- **`usda-apricot`** — USDA FoodData Central, SR Legacy: Apricots, raw (FDC ID 171697). <https://fdc.nal.usda.gov/food-details/171697/nutrients>. Portion used: "1 apricot". Portion "1 apricot" = 35 g edible portion (SR weights exclude refuse). SR28 refuse 7% (Pits). As purchased = 35 / (1 - 0.07) = 38 g.
- **`usda-plum`** — USDA FoodData Central, SR Legacy: Plums, raw (FDC ID 169949). <https://fdc.nal.usda.gov/food-details/169949/nutrients>. Portion used: "1 fruit (2-1/8" dia)". Portion "1 fruit (2-1/8" dia)" = 66 g edible portion (SR weights exclude refuse). SR28 refuse 6% (Pits). As purchased = 66 / (1 - 0.06) = 70 g.
- **`usda-lime`** — USDA FoodData Central, SR Legacy: Limes, raw (FDC ID 168155). <https://fdc.nal.usda.gov/food-details/168155/nutrients>. Portion used: "1 fruit (2" dia)". Portion "1 fruit (2" dia)" = 67 g edible portion (SR weights exclude refuse). SR28 refuse 16% (Peel and seeds). As purchased = 67 / (1 - 0.16) = 80 g.
- **`usda-carambola`** — USDA FoodData Central, SR Legacy: Carambola, (starfruit), raw (FDC ID 171715). <https://fdc.nal.usda.gov/food-details/171715/nutrients>. Portion used: "1 medium (3-5/8" long)". Portion "1 medium (3-5/8" long)" = 91 g edible portion (SR weights exclude refuse). SR28 refuse 3% (Seeds and stem end). As purchased = 91 / (1 - 0.03) = 94 g.
- **`usda-tangerine`** — USDA FoodData Central, SR Legacy: Tangerines, (mandarin oranges), raw (FDC ID 169105). <https://fdc.nal.usda.gov/food-details/169105/nutrients>. Portion used: "1 medium (2-1/2" dia)". Portion "1 medium (2-1/2" dia)" = 88 g edible portion (SR weights exclude refuse). SR28 refuse 26% (Peel and seeds). As purchased = 88 / (1 - 0.26) = 119 g.
- **`usda-tomato`** — USDA FoodData Central, SR Legacy: Tomatoes, red, ripe, raw, year round average (FDC ID 170457). <https://fdc.nal.usda.gov/food-details/170457/nutrients>. Portion used: "1 medium whole (2-3/5" dia)". Portion "1 medium whole (2-3/5" dia)" = 123 g edible portion (SR weights exclude refuse). SR28 refuse 9% (Core and stem ends). As purchased = 123 / (1 - 0.09) = 135 g.
- **`usda-orange`** — USDA FoodData Central, SR Legacy: Oranges, raw, all commercial varieties (FDC ID 169097). <https://fdc.nal.usda.gov/food-details/169097/nutrients>. Portion used: "1 fruit (2-5/8" dia)". Portion "1 fruit (2-5/8" dia)" = 131 g edible portion (SR weights exclude refuse). SR28 refuse 27% (Peel and seeds). As purchased = 131 / (1 - 0.27) = 179 g.
- **`usda-apple`** — USDA FoodData Central, SR Legacy: Apples, raw, with skin (FDC ID 171688). <https://fdc.nal.usda.gov/food-details/171688/nutrients>. Portion used: "1 medium (3" dia)". Portion "1 medium (3" dia)" = 182 g edible portion (SR weights exclude refuse). SR28 refuse 10% (Core and stem). As purchased = 182 / (1 - 0.10) = 202 g.
- **`usda-avocado`** — USDA FoodData Central, SR Legacy: Avocados, raw, all commercial varieties (FDC ID 171705). <https://fdc.nal.usda.gov/food-details/171705/nutrients>. Portion used: "1 avocado, NS as to Florida or California". Portion "1 avocado, NS as to Florida or California" = 201 g edible portion (SR weights exclude refuse). SR28 refuse 26% (Seed and skin). As purchased = 201 / (1 - 0.26) = 272 g.
- **`usda-asian-pear`** — USDA FoodData Central, SR Legacy: Pears, asian, raw (FDC ID 168177). <https://fdc.nal.usda.gov/food-details/168177/nutrients>. Portion used: "1 fruit 3-3/8" high x 3" diameter". Portion "1 fruit 3-3/8" high x 3" diameter" = 275 g edible portion (SR weights exclude refuse). SR28 refuse 9% (Core and stem). As purchased = 275 / (1 - 0.09) = 302 g.
- **`usda-corn`** — USDA FoodData Central, SR Legacy: Corn, sweet, yellow, raw (FDC ID 169998). <https://fdc.nal.usda.gov/food-details/169998/nutrients>. Portion used: "1 ear, large (7-3/4" to 9" long) yields". Portion "1 ear, large (7-3/4" to 9" long) yields" = 143 g edible portion (SR weights exclude refuse). SR28 refuse 64% (35% husk, silk, trimmings; 29% cob). As purchased = 143 / (1 - 0.64) = 397 g.
- **`usda-mango`** — USDA FoodData Central, SR Legacy: Mangos, raw (FDC ID 169910). <https://fdc.nal.usda.gov/food-details/169910/nutrients>. Portion used: "1 fruit without refuse". Portion "1 fruit without refuse" = 336 g edible portion (SR weights exclude refuse). SR28 refuse 29% (Seeds and skin). As purchased = 336 / (1 - 0.29) = 473 g.
- **`usda-pomegranate`** — USDA FoodData Central, SR Legacy: Pomegranates, raw (FDC ID 169134). <https://fdc.nal.usda.gov/food-details/169134/nutrients>. Portion used: "1 pomegranate (4" dia)". Portion "1 pomegranate (4" dia)" = 282 g edible portion (SR weights exclude refuse). SR28 refuse 44% (Skin and membrane). As purchased = 282 / (1 - 0.44) = 504 g.
- **`usda-jicama`** — USDA FoodData Central, SR Legacy: Yambean (jicama), raw (FDC ID 170073). <https://fdc.nal.usda.gov/food-details/170073/nutrients>. Portion used: "1 medium". Portion "1 medium" = 659 g edible portion (SR weights exclude refuse). SR28 refuse 8% (Ends and skin). As purchased = 659 / (1 - 0.08) = 716 g.
- **`usda-cantaloupe`** — USDA FoodData Central, SR Legacy: Melons, cantaloupe, raw (FDC ID 169092). <https://fdc.nal.usda.gov/food-details/169092/nutrients>. Portion used: "1 melon, small (about 4-1/4" dia)". Portion "1 melon, small (about 4-1/4" dia)" = 441 g edible portion (SR weights exclude refuse). SR28 refuse 49% (9% cavity contents, 1% cutting loss, 39% rind). As purchased = 441 / (1 - 0.49) = 865 g.
- **`usda-red-cabbage`** — USDA FoodData Central, SR Legacy: Cabbage, red, raw (FDC ID 169977). <https://fdc.nal.usda.gov/food-details/169977/nutrients>. Portion used: "1 head, medium (about 5" dia)". Portion "1 head, medium (about 5" dia)" = 839 g edible portion (SR weights exclude refuse). SR28 refuse 20% (Outer leaves and core). As purchased = 839 / (1 - 0.20) = 1049 g.
- **`usda-pummelo`** — USDA FoodData Central, SR Legacy: Pummelo, raw (FDC ID 167754). <https://fdc.nal.usda.gov/food-details/167754/nutrients>. Portion used: "1 fruit without refuse". Portion "1 fruit without refuse" = 609 g edible portion (SR weights exclude refuse). SR28 refuse 44% (Seeds, skin, and membrane). As purchased = 609 / (1 - 0.44) = 1088 g.
- **`usda-calabash`** — USDA FoodData Central, SR Legacy: Gourd, white-flowered (calabash), raw (FDC ID 169232). <https://fdc.nal.usda.gov/food-details/169232/nutrients>. Portion used: "1 gourd". Portion "1 gourd" = 771 g edible portion (SR weights exclude refuse). SR28 refuse 30% (Ends, skin, and seeds). As purchased = 771 / (1 - 0.30) = 1101 g.
- **`usda-papaya`** — USDA FoodData Central, SR Legacy: Papayas, raw (FDC ID 169926). <https://fdc.nal.usda.gov/food-details/169926/nutrients>. Portion used: "1 fruit, large". Portion "1 fruit, large" = 781 g edible portion (SR weights exclude refuse). SR28 refuse 38% (Seeds and skin). As purchased = 781 / (1 - 0.38) = 1260 g.
- **`usda-cabbage`** — USDA FoodData Central, SR Legacy: Cabbage, raw (FDC ID 169975). <https://fdc.nal.usda.gov/food-details/169975/nutrients>. Portion used: "1 head, large (about 7" dia)". Portion "1 head, large (about 7" dia)" = 1248 g edible portion (SR weights exclude refuse). SR28 refuse 20% (Outer leaves and core). As purchased = 1248 / (1 - 0.20) = 1560 g.
- **`usda-pineapple`** — USDA FoodData Central, SR Legacy: Pineapple, raw, all varieties (FDC ID 169124). <https://fdc.nal.usda.gov/food-details/169124/nutrients>. Portion used: "1 fruit". Portion "1 fruit" = 905 g edible portion (SR weights exclude refuse). SR28 refuse 49% (8% core, 16% crown, 26% parings). As purchased = 905 / (1 - 0.49) = 1775 g.
- **`usda-durian`** — USDA FoodData Central, SR Legacy: Durian, raw or frozen (FDC ID 168192). <https://fdc.nal.usda.gov/food-details/168192/nutrients>. Portion used: "1 fruit". Portion "1 fruit" = 602 g edible portion (SR weights exclude refuse). SR28 refuse 68% (Shell and seeds (for raw fruit)). As purchased = 602 / (1 - 0.68) = 1881 g.
- **`bentre-dua-ta`** — Sở Khoa học và Công nghệ Bến Tre (dost-bentre.gov.vn, 23-03-2009): Giống Dừa và kỹ thuật chọn giống Dừa – Dừa Ta. <https://web.archive.org/web/20241213211412/http://dost-bentre.gov.vn/tin-tuc/931/giong-dua-va-ky-thuat-chon-giong-dua> (Internet Archive copy; live page http://dost-bentre.gov.vn/tin-tuc/931/giong-dua-va-ky-thuat-chon-giong-dua did not resolve on 2026-10-08). Portion used: "Trọng lượng trái từ 1,6-2,0 kg/trái khô". Mature (dry) coconut in husk, as sold. Typical = midpoint of 1.6-2.0 kg = 1800 g. The live site did not resolve on 2026-10-08; the text was read from the Internet Archive copy https://web.archive.org/web/20241213211412/http://dost-bentre.gov.vn/tin-tuc/931/giong-dua-va-ky-thuat-chon-giong-dua
- **`usda-cauliflower`** — USDA FoodData Central, SR Legacy: Cauliflower, raw (FDC ID 169986). <https://fdc.nal.usda.gov/food-details/169986/nutrients>. Portion used: "1 head large (6-7" dia.)". Portion "1 head large (6-7" dia.)" = 840 g edible portion (SR weights exclude refuse). SR28 refuse 61% (Leaf stalks, cores and trimmings). As purchased = 840 / (1 - 0.61) = 2154 g.
- **`vietaseeds-cai-thao-va304`** — Công ty TNHH Phát triển nông nghiệp Việt Á (Vietaseeds): Hạt giống Cải Thảo lai F1 VA.304 – variety sheet. <https://vietaseeds.com/san-pham/hat-giong-cai-thao-f1-va-304-1gram>. Portion used: "trọng lượng bao TB từ 1,5-3kg". Whole head as harvested. Typical = midpoint of 1.5-3 kg = 2250 g. Seed-company variety sheet (no institute source found).
- **`vaas-bi-xanh-so-1`** — Viện Khoa học Nông nghiệp Việt Nam (VAAS) – Viện Cây lương thực và Cây thực phẩm: Giống bí xanh số 1. <https://vaas.vn/vi/giong/giong-bi-xanh-so-1>. Portion used: "quả già khối lượng 2,0 – 3,0 kg". Whole fruit as harvested (mature fruit). Typical = midpoint of the stated 2.0-3.0 kg range = 2500 g.
- **`vnuf-gac-19`** — Nguyễn Thị Lan Hoa, Đặng Minh Tú, Đào Việt Quốc et al. (2026). Đặc điểm nông sinh học của hai mẫu giống gấc địa phương triển vọng làm dược liệu trồng tại Bắc Ninh. Tạp chí Khoa học và Công nghệ Lâm nghiệp (VNUF). <https://journal.vnuf.edu.vn/vi/article/view/2048>. Portion used: "quả to (2,85 ± 0,95 kg)" (accession GAC-19). Whole fruit, measured mean of a local northern accession (GAC-19). The other accession, GAC-46, averaged 1.861 ± 0.23 kg.
- **`usda-honeydew`** — USDA FoodData Central, SR Legacy: Melons, honeydew, raw (FDC ID 169911). <https://fdc.nal.usda.gov/food-details/169911/nutrients>. Portion used: "1 melon (6" - 7" dia)". Portion "1 melon (6" - 7" dia)" = 1280 g edible portion (SR weights exclude refuse). SR28 refuse 54% (5% cavity contents, rind 49%). As purchased = 1280 / (1 - 0.54) = 2783 g.
- **`ufifas-jackfruit-hs882`** — Crane, Balerdi & Campbell. HS-882 The Jackfruit (Artocarpus heterophyllus Lam.) in Florida. UF/IFAS Extension (EDIS). <https://journals.flvc.org/edis/article/download/108125/103418/149645>. Portion used: "A few cultivars are small fruited, weighing 3 to 10 pounds (1.4-4.5 kg) each.". Whole fruit of small-fruited cultivars. Typical = midpoint of 3-10 lb = 6.5 lb = 2948 g.
- **`ninhbinh-dua-hau-hac-my-nhan`** — Chi cục Trồng trọt và BVTV Ninh Bình (Vũ Thị Hương, 05/09/2022): Một số giống dưa hấu trồng phổ biến ở Việt Nam – Giống Hắc Mỹ Nhân. <https://chicucttbvtv.ninhbinh.gov.vn/giong-cay-trong/mot-so-giong-dua-hau-trong-pho-bien-o-viet-nam-110.html>. Portion used: "khối lượng quả trung bình 3 - 4 kg". Whole fruit. Typical = midpoint of the stated 3-4 kg average = 3500 g.
- **`vaas-bi-do-mat-sao-2`** — Viện Khoa học Nông nghiệp Việt Nam (VAAS): Giống bí đỏ Mật Sao 2. <https://vaas.vn/vi/giong/giong-bi-do-mat-sao-2>. Portion used: "khối lượng quả trung bình 3,0-3,3 kg". Whole fruit. Typical = midpoint of the stated 3.0-3.3 kg average = 3150 g.
- **`nnmt-mang-cau-xiem`** — Báo Nông nghiệp và Môi trường (14/05/2015): Trồng mãng cầu xiêm thu nhập cao (Ngã Bảy, Hậu Giang). <https://nongnghiepmoitruong.vn/trong-mang-cau-xiem-thu-nhap-cao-d142790.html>. Portion used: "trái sai và to, nặng trung bình từ 2 - 4 kg/trái". Whole fruit. Typical = midpoint of 2-4 kg = 3000 g. Grower statement reported by the Ministry of Agriculture newspaper.

## 4. Flagged rows (need a human decision)

1. **Weeks 33–42: source strength and range ends.** All ten midpoints are within ±25 %. The weaker rows are:
   - **Week 33, dừa (1800 g, −16.7 %).** Bến Tre DOST, dừa ta "trái khô", i.e. a mature coconut in its husk. The 1.6 kg end is −26.0 %. The live site is down, so the text was read from the Internet Archive copy (URL in the note). A green drinking coconut (dừa xiêm, 1.2–1.5 kg, same page) would be too light.
   - **Week 35, cải thảo (2250 g, −13.3 %).** The only source is a seed-company variety sheet, and the range 1.5–3 kg is wide: −42.2 % / −16.7 %. Market heads are often 1.5–2 kg.
   - **Week 36, bí xanh (2500 g).** The 2.0 kg end is −28.9 %.
   - **Week 37, gấc (2850 g, −5.9 %).** This is the measured mean of one promising northern accession (GAC-19, ± 0.95 kg). Everyday gấc nếp is usually lighter; the other accession in the paper, GAC-46, averaged 1.861 kg.
   - **Week 39, mít nhỏ (2948 g, −14.2 %).** UF/IFAS gives a range for *small-fruited cultivars* (3–10 lb), and it is wide: −60 % / +32 %. Common Vietnamese jackfruit is far heavier: RTTC Nông Lâm University cites a 6.75 kg average. The vi name therefore says "mít nhỏ".
   - **Week 42, mãng cầu xiêm (3000 g, −17.1 %).** This is a grower's statement in the ministry newspaper, with a range of 2–4 kg (−44.7 % / +10.5 %). It conflicts with USDA soursop: FDC 167761, "1 fruit (7″ x 5-1/4″ dia)" = 625 g edible, 33 % refuse → 933 g, a US-market fruit. A Ministry of Industry and Trade page (sanphamvungmien.vn, 2018) says 1–3 kg for Hậu Giang.
     - Alternative: **casaba melon**, USDA FDC 169093, "1 melon" = 1640 g edible, 40 % refuse → 2733 g, −24.5 %. It is unfamiliar in Vietnam and close to the limit.
2. **Week 38, the vi name for honeydew.** Honeydew has no settled Vietnamese name. "Dưa mật" is the usual translation; shops also say "dưa lưới ruột xanh" or just "honeydew". Honeydew is *Cucumis melo*, the same species as week 25's cantaloupe (dưa lưới), but it is a different cultivar group with a smooth pale rind, not a size variant. Please confirm the name.
   - If the owner counts it as the same item as cantaloupe, the only sourced fill for weeks 34–39 is casaba (above).
3. **Week 32 durian.** The derived whole weight (1881 g) depends on a large refuse factor (68 %), so it is the least certain USDA row. Alternative: **pineapple, traditional varieties**, FDC 168193, "1 fruit" = 1002 g edible, refuse 42 % → 1728 g, −11.5 %. This would mean pineapple in weeks 31–32.
4. **Week 10 chanh leo.** The USDA value is for purple passion fruit (35 g whole). Some Vietnamese commercial hybrids are larger. Alternatives:
   - **apricot / quả mơ**, 38 g, +8.6 % (but it is used in week 11);
   - **fig, small**, FDC 173021, "1 small (1-1/2″ dia)" = 40 g edible, refuse 1 % → 40 g, +15.4 % ("một quả sung Mỹ", less familiar).
5. **Week 13 lime.** USDA "Limes, raw" is the Persian/Tahiti lime, so the vi name is "chanh không hạt" (the Persian lime sold in Vietnam). The northern *chanh ta* is smaller and has no sourced weight. Alternative: **fig, large**, FDC 173021, "1 large (2-1/2″ dia)" = 64 g edible → 65 g, −11.0 %.
6. **Week 21 corn.** The as-purchased weight includes husk and cob (refuse 64 %). That is fair for "a whole ear as bought", but a husked ear is about 250 g. The vi name says "to" (large).
7. **Week 26 red cabbage.** Repeats the cabbage family with week 30 (green, large). They are distinct sourced items, so this is noted only.
8. **Emoji mismatches** (the emoji is only a fallback):
   - 10 🟣 passion fruit;
   - 11 and 12 🍑 for apricot and plum;
   - 14 ⭐ star fruit;
   - 23 🍎 pomegranate;
   - 24 🥔 jicama;
   - 26 🥬 red cabbage;
   - 27 🍈 pomelo;
   - 28 and 36 🥒 for bottle gourd and winter melon;
   - 34 🥦 cauliflower;
   - 37 🟠 gấc;
   - 39 🟢 jackfruit;
   - 42 🍈 soursop;
   - 29 🥭 papaya;
   - 32 🍈 durian.

   Week 13 🍋‍🟩 needs iOS 17.4 or later. Use 🍋 if the deployment target is lower.

## 5. Notes on vi names

All vi names use northern usage:
- *dứa* (not *thơm*), *bắp cải*, *ngô* (not *bắp*), *bí xanh* (= bí đao), *bí đỏ*, *củ đậu*, *quả bầu*;
- *dưa lưới* for cantaloupe, *lê Hàn Quốc* for Asian pear.

Classifiers: *một quả* for fruit, *một củ* for jicama, *một bắp* for corn and cabbage, *một cây* for súp lơ and cải thảo (as in the original week-27 copy, "một cây cải thảo").
