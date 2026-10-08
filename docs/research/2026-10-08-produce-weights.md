# Produce weights for the Hadlock size comparisons (weeks 10–42)

Date: 2026-10-08 · Branch: `feat/week-sizes` · Spec: `docs/superpowers/specs/2026-10-08-week-sizes-design.md` (§2, §3, §6 step 1)
Machine-readable copy: `docs/research/2026-10-08-produce-weights.json`

## 1. Method

- **Reference.** `weeks[].weightG` in `pregnancy-content.json` (Hadlock 1991 50th-percentile estimated fetal weight). Weeks 41–42 use the week-40 value (3619 g).
- **Tolerance.** `|typicalGrams − weightG| / weightG ≤ 0.25`. Every row below passes (checked by script; the largest deviations are week 12 at +20.7 % and week 33 at +15.6 %).
- **What "typical weight" means.** The whole item as bought, including peel, rind, husk, stone and core.
- **USDA rows (weeks 10–32).** These use USDA FoodData Central, SR Legacy (= USDA National Nutrient Database for Standard Reference, Release 28). SR household-measure weights are **edible portion**. The SR28 documentation (*Weights and Measures*) says: weights are for edible material without refuse. So each as-purchased weight is derived as

  `as purchased = edible-portion gram weight / (1 − refuse % / 100)`

  The refuse % and its description come from the same release: the `Refuse` / `Ref_desc` fields of `FOOD_DES` in the SR28 ASCII file. The FDC web page does not display refuse. Every note below shows both numbers, so the derivation can be checked. No weight is estimated by eye.
- **Vietnamese rows (weeks 33–42).** USDA has no whole-item weight in the 2–4 kg band that fits a familiar Vietnamese item. Its watermelon portion (15″ melon) is far heavier, and wax gourd is 5.7 kg *edible*. These rows therefore use Vietnamese agricultural sources: VAAS variety sheets and the Ninh Bình provincial crop-protection sub-department. Each of these states an average-weight **range** for whole fruit, and `typicalGrams` is the **midpoint** of that range.
- **Choice rules applied.**
  - Prefer a familiar Vietnamese item.
  - Use one whole item per week, with no "pair of" or "bunch of".
  - No item runs for more than two consecutive weeks. Two pairs of rows (bí đỏ, dưa hấu) reappear after a gap; see §4.
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
| 33 | 2162 | a winter melon | một quả bí xanh | 🥒 | 2500 | +15.6 | `vaas-bi-xanh-so-1` | "quả già khối lượng 2,0 – 3,0 kg" | no wax-gourd emoji; cucumber is closest |
| 34 | 2377 | a winter melon | một quả bí xanh | 🥒 | 2500 | +5.2 | `vaas-bi-xanh-so-1` | "quả già khối lượng 2,0 – 3,0 kg" | no wax-gourd emoji; cucumber is closest |
| 35 | 2595 | a small watermelon | một quả dưa hấu nhỏ | 🍉 | 2500 | -3.7 | `ninhbinh-dua-hau-vo-vang` | "khối lượng trung bình quả 2 - 3 kg" |  |
| 36 | 2813 | a small watermelon | một quả dưa hấu nhỏ | 🍉 | 2500 | -11.1 | `ninhbinh-dua-hau-vo-vang` | "khối lượng trung bình quả 2 - 3 kg" |  |
| 37 | 3028 | a pumpkin | một quả bí đỏ | 🎃 | 3150 | +4.0 | `vaas-bi-do-mat-sao-2` | "khối lượng quả trung bình 3,0-3,3 kg" |  |
| 38 | 3236 | a pumpkin | một quả bí đỏ | 🎃 | 3150 | -2.7 | `vaas-bi-do-mat-sao-2` | "khối lượng quả trung bình 3,0-3,3 kg" |  |
| 39 | 3435 | a watermelon | một quả dưa hấu | 🍉 | 3500 | +1.9 | `ninhbinh-dua-hau-hac-my-nhan` | "khối lượng quả trung bình 3 - 4 kg" |  |
| 40 | 3619 | a watermelon | một quả dưa hấu | 🍉 | 3500 | -3.3 | `ninhbinh-dua-hau-hac-my-nhan` | "khối lượng quả trung bình 3 - 4 kg" |  |
| 41 | 3619 | a pumpkin | một quả bí đỏ | 🎃 | 3150 | -13.0 | `vaas-bi-do-mat-sao-2` | "khối lượng quả trung bình 3,0-3,3 kg" |  |
| 42 | 3619 | a watermelon | một quả dưa hấu | 🍉 | 3500 | -3.3 | `ninhbinh-dua-hau-hac-my-nhan` | "khối lượng quả trung bình 3 - 4 kg" |  |

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
- **`vaas-bi-xanh-so-1`** — Viện Khoa học Nông nghiệp Việt Nam (VAAS) – Viện Cây lương thực và Cây thực phẩm: Giống bí xanh số 1. <https://vaas.vn/vi/giong/giong-bi-xanh-so-1>. Portion used: "quả già khối lượng 2,0 – 3,0 kg". Whole fruit as harvested (mature fruit). Typical = midpoint of the stated 2.0-3.0 kg range = 2500 g.
- **`ninhbinh-dua-hau-vo-vang`** — Chi cục Trồng trọt và BVTV Ninh Bình (Vũ Thị Hương, 05/09/2022): Một số giống dưa hấu trồng phổ biến ở Việt Nam – Giống dưa hấu vỏ vàng, ruột đỏ. <https://chicucttbvtv.ninhbinh.gov.vn/giong-cay-trong/mot-so-giong-dua-hau-trong-pho-bien-o-viet-nam-110.html>. Portion used: "khối lượng trung bình quả 2 - 3 kg". Whole fruit. Typical = midpoint of the stated 2-3 kg average = 2500 g.
- **`vaas-bi-do-mat-sao-2`** — Viện Khoa học Nông nghiệp Việt Nam (VAAS): Giống bí đỏ Mật Sao 2. <https://vaas.vn/vi/giong/giong-bi-do-mat-sao-2>. Portion used: "khối lượng quả trung bình 3,0-3,3 kg". Whole fruit. Typical = midpoint of the stated 3.0-3.3 kg average = 3150 g.
- **`ninhbinh-dua-hau-hac-my-nhan`** — Chi cục Trồng trọt và BVTV Ninh Bình (Vũ Thị Hương, 05/09/2022): Một số giống dưa hấu trồng phổ biến ở Việt Nam – Giống Hắc Mỹ Nhân. <https://chicucttbvtv.ninhbinh.gov.vn/giong-cay-trong/mot-so-giong-dua-hau-trong-pho-bien-o-viet-nam-110.html>. Portion used: "khối lượng quả trung bình 3 - 4 kg". Whole fruit. Typical = midpoint of the stated 3-4 kg average = 3500 g.

## 4. Flagged rows (need a human decision)

1. **Weeks 41–42: items reappear after a gap.** Bí đỏ is used in weeks 37–38 and again in 41. Dưa hấu (Hắc Mỹ Nhân) is used in 39–40 and again in 42. The "two consecutive weeks" rule holds, but the list repeats. Sourced items in the 2714–4524 g band are only pumpkin, watermelon and USDA honeydew. Alternatives:
   - Week 41 → **honeydew melon** ("một quả dưa lê"/"dưa mật"), USDA FDC 169911, "1 melon (6″ - 7″ dia)" = 1280 g edible, refuse 54 % → 2783 g, −23.1 %. This is close to the limit, and honeydew is less familiar in Vietnam.
   - Accept the repeat. Weeks 40–42 share one reference weight, so the item could also stay "một quả dưa hấu" for 40–42, but that breaks the two-week rule.
2. **Weeks 33–42 use midpoints of variety ranges, not single published values.** The ranges are narrow: bí đỏ 3.0–3.3 kg, dưa hấu 3–4 kg / 2–3 kg, bí xanh 2.0–3.0 kg. Most rows stay inside ±25 % at either end of their range. The exceptions are:
   - week 33 (bí xanh at 3.0 kg = +38.8 %);
   - week 34 (bí xanh at 3.0 kg = +26.2 %);
   - week 36 (dưa hấu vỏ vàng at 2.0 kg = −28.9 %).

   Week 33 alternative: **USDA honeydew, small**, FDC 169911, "1 melon (5-1/4″ dia)" = 1000 g edible, refuse 54 % → 2174 g, +0.6 %.
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
   - 28, 33 and 34 🥒 for bottle gourd and winter melon;
   - 29 🥭 papaya;
   - 32 🍈 durian.

   Week 13 🍋‍🟩 needs iOS 17.4 or later. Use 🍋 if the deployment target is lower.

## 5. Notes on vi names

All vi names use northern usage:
- *dứa* (not *thơm*), *bắp cải*, *ngô* (not *bắp*), *bí xanh* (= bí đao), *bí đỏ*, *củ đậu*, *quả bầu*;
- *dưa lưới* for cantaloupe, *lê Hàn Quốc* for Asian pear.

Classifiers: *một quả* for fruit, *một củ* for jicama, *một bắp* for corn and cabbage.
