# Nội dung cần bác sĩ sản khoa duyệt trước khi phát hành App Store

Tài liệu này dành cho bác sĩ sản khoa duyệt nội dung ứng dụng Luna Mom (tab "Thai kỳ")
trước khi phát hành lên App Store. Mỗi dòng dưới đây là một việc cần làm hoặc một điểm
cần bác sĩ quyết định. Tích vào ô vuông khi đã xong.

## 1. Cách duyệt nội dung

- Toàn bộ nội dung (tuần 4–42 + 10 mốc khám gợi ý, song ngữ en/vi) nằm trong một file:
  `Packages/KickCore/Sources/KickCore/Resources/pregnancy-content.json`.
- Mỗi tuần và mỗi mốc có một trường `"reviewed": false` / `"reviewed": true`.
- **Trong bản TestFlight (bản thử nghiệm)**: hiện **tất cả** nội dung, kể cả mục chưa
  duyệt — mục chưa duyệt có thêm nhãn "Nội dung đang chờ bác sĩ duyệt" để dễ nhận ra khi
  đọc và góp ý.
- **Trong bản chính thức trên App Store**: chỉ hiện những tuần/mốc đã có `"reviewed": true`.
  Mục chưa duyệt sẽ bị ẩn hoàn toàn với người dùng thật.
- Cách duyệt một mục: sau khi bác sĩ xác nhận nội dung đúng, lập trình viên đổi
  `"reviewed": false` thành `"reviewed": true` cho tuần/mốc đó, ghi tên người duyệt và
  ngày duyệt vào commit, rồi chạy lại bộ kiểm thử (`scripts/test-core.sh`).
- [ ] Bác sĩ đã đọc hiểu quy trình này.

## 2. 14 điểm bác sĩ cần quyết định (từ tác giả nội dung, `task-5-report.md`)

1. [ ] **Liều axit folic / vitamin**: hiện tại app không ghi liều cụ thể, chỉ viết
       "theo chỉ định của bác sĩ". Quyết định: có nên ghi liều chuẩn (WHO/NHS 400 µg;
       Bộ Y tế còn khuyến nghị thêm sắt) hay giữ nguyên "hỏi bác sĩ"?
2. [ ] **Tuần 5 "tim bắt đầu đập khoảng thời gian này"**: mốc này là ước lượng (hoạt
       động tim thường thấy rõ trên siêu âm đầu dò âm đạo từ khoảng tuần 6). Tuần 6 viết
       "siêu âm có thể thấy tim thai đập nhấp nháy". Xác nhận cách diễn đạt này có ổn không.
3. [ ] **Các mốc phát triển của thai** (cảm nhận ánh sáng ở tuần 15, cử động mắt tuần 16,
       nghe được âm thanh tuần 18, cảm nhận vị tuần 21, surfactant tuần 24, mở mắt tuần 26,
       đủ 5 giác quan tuần 31, thận hoàn thiện tuần 35): các nguồn khác nhau lệch nhau
       khoảng ±1 tuần. Xác nhận các mốc này phù hợp thực hành tại Việt Nam.
4. [ ] **Thai máy (quickening)**: app viết "đa số cảm nhận được vào khoảng tuần 20".
       Với người mang thai lần đầu có thể muộn hơn, khoảng 20–22 tuần — xác nhận cách viết.
5. [ ] **Cảnh báo giảm cử động thai**: bắt đầu từ tuần 24 ("nếu cử động chậm lại hoặc
       thay đổi"). Xác nhận tuần 24 (không phải tuần 28) đúng với thực hành tại Việt Nam.
6. [ ] **Xét nghiệm GBS (liên cầu khuẩn nhóm B)**: app ghi khoảng tuần 35–37.
       ACOG hiện khuyến nghị 36+0 đến 37+6; NHS (Anh) không sàng lọc thường quy.
       Xác nhận khoảng tuần theo thực hành của Bộ Y tế.
7. [ ] **Triple test (tuần 15–18) và đo độ mờ da gáy/double test (tuần 11–14)**: app viết
       theo hướng "hỏi bác sĩ xem có cần làm không". Xác nhận cách diễn đạt này.
8. [ ] **Tiêm uốn ván / ho gà**: lịch tiêm uốn ván (TT/VAT) theo chương trình tiêm chủng
       Việt Nam khác với lịch Tdap 27–36 tuần của ACOG. App chỉ viết "theo lịch của cơ sở
       y tế đang khám". Xác nhận cách viết này là đủ.
9. [ ] **Nhóm máu Rh âm (đề cập ở tuần 28)**: app viết chung "hỏi bác sĩ cần chăm sóc
       thêm gì", không nói cụ thể về globulin miễn dịch anti-D. Xác nhận có cần nói rõ hơn.
10. [ ] **Ngưỡng sốt ở tuần 9**: app dùng mốc 38°C — xác nhận ngưỡng này.
11. [ ] **"Đủ tháng sớm" (tuần 37) và "đủ tháng" (tuần 39)**: theo định nghĩa của ACOG.
        Xác nhận có khác với cách phân loại hay dùng tại Việt Nam không.
12. [ ] **Tuần 41–42 về khởi phát chuyển dạ**: tuần 41 viết bác sĩ "có thể sẽ trao đổi về
        khởi phát chuyển dạ"; tuần 42 viết "thường sẽ được khuyến nghị khởi phát chuyển dạ".
        Xác nhận có đúng với thực hành tại cơ sở y tế trong nước.
13. [ ] **Thuật ngữ tiếng Việt**: "máu báo" (ra máu khi phôi làm ổ), "bé máy" (thai máy),
        "cơn gò sinh lý" (Braxton Hicks), "chất gây" (vernix), "ra nhầy hồng" (dấu hiệu sắp
        sinh). Tên các loại quả so sánh kích thước thai dùng từ miền Bắc (vừng, dưa chuột,
        dứa, ngô) — độc giả miền Nam có thể quen với mè, dưa leo, thơm, bắp hơn.
        Xác nhận thuật ngữ và xem thêm mục 4 bên dưới về tên món ăn/trái cây.
14. [ ] **So sánh kích thước sau tuần 34**: một số so sánh mang tính minh họa và dựa theo
        cân nặng ("hai quả dừa", "một bắp cải lớn", "một quả bí đỏ lớn"). Có thể đổi sang
        loại quả khác nếu bác sĩ/nhóm sản phẩm thấy chưa phù hợp.

## 3. Điểm phát sinh thêm từ các vòng rà soát nội dung (xem `progress.md`)

15. [ ] **Phân loại mức độ cấp cứu khi ra máu ở tuần 4–12**: hiện tại viết "ra máu âm đạo
        hoặc đau bụng dữ dội → đến gặp bác sĩ ngay" (không bắt buộc đi cấp cứu, trừ khi kèm
        đau/ngất — đó là dấu hiệu nghi thai ngoài tử cung, mục riêng). Xác nhận cách phân
        loại bác sĩ thường / cấp cứu này đã đúng, hay cần đi cấp cứu ngay trong mọi trường
        hợp ra máu ở giai đoạn này.
16. [ ] **Mục ra máu ở tuần 37–42** hiện viết "ra máu nhiều hoặc màu đỏ tươi → đến bệnh
        viện ngay". Có khả năng bỏ sót các trường hợp ra máu ít hơn hoặc màu sẫm hơn nhưng
        vẫn cần được khám. Xác nhận ngưỡng mô tả này đủ an toàn hay cần viết lại.
17. [ ] **Mục nghi thai ngoài tử cung (tuần 4–12)** hiện viết: "đau nhói một bên, đau ở
        đầu vai, hoặc cảm thấy choáng/ngất → đến khoa cấp cứu ngay". Có nên bổ sung thêm
        "gọi 115 nếu không tự di chuyển được" không?
18. [ ] **Số điện thoại cấp cứu trong bản tiếng Anh**: hiện bản tiếng Anh cũng ghi số
        **115** (số cấp cứu Việt Nam). Quyết định cùng bác sĩ/nhóm sản phẩm: giữ số 115
        trong bản tiếng Anh, hay đổi thành cách viết chung "gọi số cấp cứu tại nơi bạn ở"
        (local emergency number) để phù hợp người dùng ở nước khác?
19. [ ] **Emoji 🎃 (bí ngô Halloween) dùng để minh họa "quả bí đỏ"** ở tuần 35, 38 và 41.
        Về mặt hình ảnh đây là quả bí ngô kiểu Halloween, có thể gây cảm giác không phù hợp
        hoặc hài hước không đúng lúc trong nội dung y tế. Xác nhận có cần đổi minh họa khác
        cho "bí đỏ" (ví dụ chỉ dùng mô tả bằng chữ, không emoji) hay giữ nguyên.
        *Cập nhật:* đã bỏ "bí đỏ" và 🎃; các tuần này nay dùng dưa lê / dưa hấu / chuối (mục 21).
20. [ ] **Tên gọi món ăn/trái cây theo miền**: nội dung hiện dùng từ ngữ miền Bắc (vừng,
        dưa chuột, dứa, ngô — xem thêm mục 13). Xác nhận giữ nguyên (và có thể ghi chú từ
        đồng nghĩa miền Nam trong mô tả) hay đổi sang từ trung lập/phổ biến hơn cho cả nước.

21. [ ] **Cân nặng và chiều dài thai theo Hadlock** (thay bảng số liệu cũ không rõ nguồn;
        chi tiết và nguồn: `docs/research/2026-10-03-hadlock-fetal-growth.md`):
        - Tuần 10–40: cân nặng ước tính bách phân vị 50 kèm khoảng bách phân vị 10–90 theo
          Hadlock 1991 (Bảng 1), hiển thị "Khoảng 331 g (thường 275–387 g)", kèm dòng
          "Cân nặng ước tính qua siêu âm có thể chênh lệch khoảng 10–15%."
        - Tuần 41–42: dùng lại số liệu tuần 40, kèm dòng "Số liệu chuẩn Hadlock chỉ đến tuần 40."
        - Tuần 7–13: chiều dài đầu–mông (mm) tính từ phương trình hồi quy của Hadlock 1992 (bài
          báo không in bảng các giá trị này): 9,6 / 16,0 / 23,1 / 31,3 / 41,2 / 53,5 / 67,2 mm,
          hiển thị "Khoảng 53,5 mm". Từ tuần 14 không hiển thị chiều dài.
        - Đổi so sánh kích thước cho hợp cân nặng mới và để emoji đúng với vật được so sánh:
          tuần 10 củ gừng 🫚, 11 củ tỏi 🧄, 28 quả dứa nhỏ 🍍, 35 quả dưa lê 🍈, 38 quả dưa hấu
          nhỏ 🍉, 40 quả dưa hấu vừa 🍉, 41 hai nải chuối 🍌, 42 quả dưa hấu to 🍉 (bỏ "bí đỏ"
          vì không có emoji bí đỏ phù hợp — xem mục 19).
        Xin bác sĩ xác nhận các con số này và cách diễn đạt khoảng "thường A–B".

## 4. Lịch khám gợi ý — xác nhận theo thực hành hiện hành của Bộ Y tế

Mười mốc khám gợi ý dưới đây (id và khoảng tuần) hiện có trong `pregnancy-content.json`.
Xin bác sĩ xác nhận từng mốc còn đúng với phác đồ/khuyến cáo hiện hành:

| id | Khoảng tuần | Tên (vi) |
|---|---|---|
| `confirm-pregnancy` | 6–8 | Khám thai lần đầu |
| `nt-scan` | 11–14 | Siêu âm đo độ mờ da gáy |
| `triple-test` | 15–18 | Xét nghiệm triple test |
| `anomaly-scan` | 18–22 | Siêu âm hình thái |
| `gdm-screening` | 24–28 | Tầm soát tiểu đường thai kỳ |
| `tetanus-pertussis` | 27–36 | Tiêm phòng uốn ván, ho gà |
| `growth-scan` | 30–32 | Siêu âm đánh giá tăng trưởng |
| `gbs-test` | 35–37 | Cấy liên cầu khuẩn nhóm B |
| `weekly-checks` | 37–40 | Khám thai hằng tuần |
| `post-dates` | 40–42 | Theo dõi khi quá ngày dự sinh |

- [ ] Bác sĩ đã xác nhận cả 10 mốc trên (id, khoảng tuần, và nội dung mô tả trong file JSON)
      phù hợp với thực hành sản khoa hiện hành tại Việt Nam.

## 5. Sau khi duyệt xong

- [ ] Tất cả tuần (4–42) và tất cả mốc (10 mốc) đã có `"reviewed": true`.
- [ ] Lệnh kiểm tra sau in ra `[] []` (không còn mục nào chưa duyệt):
      `python3 -c "import json;d=json.load(open('Packages/KickCore/Sources/KickCore/Resources/pregnancy-content.json'));print([w['week'] for w in d['weeks'] if not w['reviewed']],[m['id'] for m in d['milestones'] if not m['reviewed']])"`
- [ ] `scripts/test-core.sh` chạy xanh sau khi đổi `reviewed`.

## 6. Chế độ "Mong con" (giai đoạn 3) — chuỗi y tế và quy tắc dự đoán

Các chuỗi dưới đây nằm trong `Shared/Localizable.xcstrings` (không có cờ `reviewed` như nội dung
thai kỳ, nên **phải được duyệt trước khi gửi App Store**). Xem câu chữ thật trên ảnh chụp
`medical-ttc-vi`, `cycle-home-*`, `day-log-*` trong `ci-artifacts/screenshots/` của lần CI gần nhất.

| Khóa | Nội dung (vi) cần duyệt |
|---|---|
| `medical.ttc.body` | Không dùng để tránh thai; dự đoán chỉ là ước tính; khi nào nên gặp bác sĩ (12 tháng, 6 tháng nếu ≥ 35 tuổi; chu kỳ < 21 hoặc > 45 ngày hay rất không đều; ra máu bất thường giữa kỳ) |
| `cycle.irregular.title`, `cycle.irregular.body` | Cảnh báo chu kỳ bất thường → gợi ý gặp bác sĩ |
| `cycle.late.title`, `cycle.late.body`, `cycle.reminder.late.*` | Gợi ý thử thai khi trễ kinh từ ngày thứ 3 |
| `cycle.longPeriod.title`, `cycle.longPeriod.body` | Kỳ kinh chưa kết thúc > 10 ngày → ghi ngày kết thúc / đi khám nếu ra máu kéo dài |
| `cycle.disclaimer`, `cycle.lowConfidence.*` | Dự đoán chỉ là ước tính; độ tin cậy thấp khi chu kỳ chưa đều hoặc chưa đủ dữ liệu |
| `cycle.status.*`, `cycle.reminder.fertile.*`, `cycle.reminder.period.*` | Cách gọi "khả năng thụ thai cao/cao nhất/thấp", nhắc trước cửa sổ thụ thai và kỳ kinh |
| `lastPeriod.hint`, `dayLog.bbt.hint`, `dayLog.lh.*`, `dayLog.mucus.*` | Hướng dẫn: ngày đầu ra máu (không tính lấm tấm); đo BBT ngay khi thức dậy; tên các loại dịch nhầy (khô, dính, như kem, như lòng trắng trứng) |

22. [ ] Bác sĩ đã duyệt (hoặc sửa) toàn bộ các khóa trong bảng trên, cả bản vi lẫn en.
23. [ ] **Quy tắc dự đoán** (theo spec §4.1, `Packages/KickCore/Sources/KickCore/CyclePredictor.swift`):
        pha hoàng thể cố định 14 ngày (rụng trứng = kỳ kinh dự kiến − 14); cửa sổ thụ thai = 5 ngày trước
        đến 1 ngày sau rụng trứng; LH dương tính → rụng trứng ngày hôm sau; BBT: 3 ngày liền cao hơn mức
        cao nhất của 6 lần đo trước ≥ 0,2 °C; chỉ tính chu kỳ 21–45 ngày, trung bình 6 chu kỳ gần nhất;
        độ tin cậy thấp khi độ lệch chuẩn > 4 ngày hoặc chênh > 7 ngày (nới cửa sổ tối đa 3 ngày mỗi bên).
        Xác nhận các ngưỡng này phù hợp để hiển thị cho người dùng (không dùng cho tránh thai).
24. [ ] **Khoảng nhiệt độ BBT hợp lệ 35,0–38,5 °C** và ngưỡng "kỳ kinh kéo dài" 10 ngày: xác nhận.
25. [ ] **Thời điểm gợi ý thử thai**: từ ngày trễ thứ 3 (thẻ + một thông báo). Xác nhận hay đổi.

## 7. Giao diện mới (giai đoạn 4) — chuỗi y tế mới

Chuỗi trong `Shared/Localizable.xcstrings`, lấy từ bản thiết kế "Mầm" (nội dung mẫu, README thiết kế ghi rõ
cần chuyên gia duyệt). Xem câu chữ thật trên ảnh `kicks-bottom-*`, `history-bottom-*`, `kicks-overdue-*`
trong `ci-artifacts/screenshots/`.

| Khóa | Nội dung (vi) cần duyệt |
|---|---|
| `kicks.cardiff.title`, `kicks.cardiff.body` | Phương pháp Cardiff: đếm tới 10, cùng khung giờ mỗi ngày, quá 2 giờ hoặc ít hơn mọi ngày → gọi bác sĩ |
| `history.guide.title`, `history.guide.body` | Khi nào cần gặp bác sĩ: quá 2 giờ chưa đủ 10, cử động yếu hơn/khác thường, hoặc lo lắng — không chờ hôm sau |
| `counter.call115` | Nút "Gọi cấp cứu 115" trên thẻ cảnh báo 2 giờ (chỉ tiếng Việt; tiếng Anh không có số chung nên chỉ có chữ) |
| `kickSettings.reminder.detail` | "Đếm cùng một khung giờ mỗi ngày, khi bé thường hoạt động" |
| `common.underOneMinute` | "<1 phút" — chữ hiển thị khi một lượt đếm hoàn thành dưới một phút (biểu đồ lịch sử, thẻ lượt đếm) |
| `week.sizeLine`, `week.about`, `week.typicalRange` | *Đã bỏ ở giai đoạn 6* — thay bằng câu kích thước tự sinh `weekArticle.size.*` (mục 9). |
| `week.reviewed`, `week.reviewer` | "Bác sĩ sản khoa đã duyệt nội dung tuần này" / "Người xem xét" — dòng trạng thái duyệt hiển thị cho người dùng, không nêu tên bác sĩ |
| `cycle.maybePregnant.title`, `cycle.maybePregnant.body` | "Có thể bạn đang mang thai?" / "Chuyển sang chế độ thai kỳ để theo dõi từng tuần" — thẻ gợi ý khi trễ kinh (nội dung y tế đầy đủ vẫn ở `cycle.late.*` đã duyệt giai đoạn 3) |

26. [ ] Bác sĩ đã duyệt (hoặc sửa) các khóa trên, cả vi lẫn en.
27. [ ] Xác nhận hiển thị nút gọi 115 ở thẻ cảnh báo 2 giờ (tiếng Việt) là phù hợp, hay nên gọi số của
        cơ sở sản khoa của mẹ.
28. [ ] Thẻ cảnh báo 2 giờ, thông báo đẩy 2 giờ và "Thông tin y tế" giữ nội dung đã duyệt ở giai đoạn 1
        (`overdue.*`, `medical.body`) — chỉ đổi giao diện.

## 8. Ghi triệu chứng & cân nặng mẹ (giai đoạn 5)

Chuỗi trong `Shared/Localizable.xcstrings`; xem câu chữ thật trên ảnh `weight-*`, `pregnancy-home-weight-*`,
`symptoms-sheet-*`, `symptoms-safety-en`, `week-warnings-en`, `day-log-*` trong `ci-artifacts/screenshots/`.
Ngưỡng nằm trong `Packages/KickCore/Sources/KickCore/WeightGuidance.swift` (có test `WeightGuidanceTests`).

**Ngưỡng tăng cân (IOM 2009, thai đơn) theo BMI trước mang thai** — BMI = kg / m², làm tròn 1 chữ số thập phân:

| Nhóm (`BMICategory`) | BMI | Tổng tăng tới tuần 40 |
|---|---|---|
| Thiếu cân (`under`) | < 18,5 | 12,5–18 kg |
| Bình thường (`normal`) | 18,5–24,9 | 11,5–16 kg |
| Thừa cân (`over`) | 25,0–29,9 | 7–11,5 kg |
| Béo phì (`obese`) | ≥ 30,0 | 5–9 kg |

Cách chia theo tuần (mọi nhóm): tuần 0–13 tăng tuyến tính từ 0 tới 0,5–2,0 kg; tuần 13–40 tuyến tính từ
0,5 / 2,0 kg tới cận dưới / cận trên của nhóm; sau tuần 40 giữ giá trị tuần 40. Ví dụ BMI bình thường ở tuần 24:
4,98–7,70 kg. Trạng thái: "Trong khoảng" khi mức tăng nằm trong dải của tuần đó, ngoài ra "Thấp hơn khoảng" /
"Cao hơn khoảng" (màu trung tính, không đỏ) kèm "Trao đổi với bác sĩ ở lần khám tới". Không có chiều cao → không
hiện nhóm, dải hay trạng thái.

| Khóa | Nội dung (vi) cần duyệt |
|---|---|
| `weight.status.inRange`, `weight.status.below`, `weight.status.above` | "Trong khoảng" / "Thấp hơn khoảng" / "Cao hơn khoảng" |
| `weight.status.talk` | "Trao đổi với bác sĩ ở lần khám tới" (chỉ khi ngoài khoảng) |
| `weight.setup.body`, `weight.noHeight` | Giải thích dải IOM 2009 và việc chiều cao không bắt buộc |
| `weight.category.*` | "Thiếu cân / Bình thường / Thừa cân / Béo phì" (tên nhóm BMI hiển thị cho mẹ) |
| `symptom.safety.title` | "Khi nào cần đi khám ngay" (cùng câu với `week.warnings` đã có) |
| `symptom.safety.contractions` | "Đi khám ngay nếu cơn gò đều đặn hoặc đau trước tuần 37, hoặc ra nước, ra máu." |
| `symptom.safety.swelling` | "Đi khám ngay nếu mặt hoặc tay phù đột ngột kèm đau đầu, nhìn mờ hoặc đau vùng thượng vị." |
| `symptom.safety.note`, `symptom.safety.action` | "Luna Mom không chẩn đoán. Khi không chắc, hãy gọi bác sĩ." / "Xem dấu hiệu cần đi khám" (mở Chi tiết tuần tại mục cảnh báo, trong bản chính thức chỉ khi tuần đó đã duyệt — xem mục 33) |
| `symptom.flow.*` | Lượng kinh: Không / Ít / Vừa / Nhiều |
| `symptom.mood.*` | Tâm trạng: Vui vẻ / Bình thường / Nhạy cảm / Lo âu / Mệt mỏi |
| `symptom.kind.*` | Mong con: Đau bụng / Đau đầu / Căng ngực / Nổi mụn / Đầy hơi / Thèm ăn. Mang thai: Buồn nôn / Ợ nóng / Phù chân / Đau lưng / Chuột rút / Khó ngủ / Cơn gò |

29. [ ] **Ngưỡng BMI cho người châu Á:** app đang dùng ngưỡng chuẩn WHO/IOM (thừa cân ≥ 25, béo phì ≥ 30). WHO
        (2004) gợi ý cho người châu Á mức hành động thấp hơn (thừa cân ≥ 23, béo phì ≥ 27,5). Bác sĩ chọn: giữ ngưỡng
        chuẩn, hay đổi sang ngưỡng châu Á (và khi đó dùng dải IOM của nhóm nào)? Đổi chỉ là sửa hằng số trong
        `BMICategory.init(bmi:)` + test, **không** đổi dữ liệu đã lưu (BMI tính lại từ cân nặng và chiều cao).
30. [ ] Xác nhận dải IOM 2009 và cách chia theo tuần ở trên (đặc biệt 0,5–2,0 kg ở tuần 13 cho mọi nhóm), và việc
        không áp dụng cho song thai.
31. [ ] Duyệt (hoặc sửa) câu chữ thẻ an toàn "Cơn gò" / "Phù chân" và việc thẻ chỉ nhắc đi khám, không chẩn đoán,
        không đếm cơn gò. **Câu hỏi:** câu "Đi khám ngay nếu cơn gò đều đặn hoặc đau trước tuần 37, hoặc ra nước,
        ra máu" có thể đọc thành cơn gò đều đặn hoặc đau *từ* tuần 37 trở đi thì không cần đi khám — xin bác sĩ xác
        nhận cách diễn đạt này đúng ý hay cần sửa lại (không tự đổi câu chữ trong app).
32. [ ] Duyệt (hoặc sửa) tên lượng kinh, tâm trạng, triệu chứng (vi + en) và các câu trạng thái cân nặng.
33. [ ] **Câu hỏi sản phẩm — thẻ an toàn và tuần chưa duyệt:** ở bản chính thức, tuần nội dung chưa duyệt bị ẩn
        hoàn toàn (mục 1). Để nút "Xem dấu hiệu cần đi khám" (`symptom.safety.action`) không mở ra một Chi tiết tuần
        trống, app hiện **ẩn nút này** khi tuần hiện tại chưa duyệt; câu "đi khám ngay" trên thẻ an toàn vẫn luôn hiện.
        Bác sĩ/nhóm sản phẩm xác nhận cách này chấp nhận được, hay muốn luôn hiện mục cảnh báo (`week.warnings`)
        ngay cả với tuần chưa duyệt để nút luôn có?
34. [ ] **Làm tròn BMI ở biên:** theo quyết định đã ghi trong plan (bảng "Quyết định làm rõ spec" §2.4), BMI được
        làm tròn 1 chữ số thập phân **trước khi** xếp nhóm, để số hiển thị và nhóm khớp nhau. Hệ quả: BMI thật
        24,95–24,99 làm tròn thành 25,0 và bị xếp vào nhóm Thừa cân (`over`), chứ không phải Bình thường
        (`normal`) theo ngưỡng BMI thật < 25,0. Xác nhận cách làm tròn rồi mới xếp nhóm này là phù hợp ở biên, hay
        nên xếp nhóm theo BMI thật (chưa làm tròn).

## 9. Bài viết theo tuần (giai đoạn 6)

Chi tiết tuần nay là một bài viết ngắn cho mỗi tuần 4–42, chia hai thẻ **Bé** và **Mẹ**, viết mới bằng
tiếng Việt và tiếng Anh (không dịch máy, không chép từ ứng dụng hay trang web khác). Nội dung nằm trong
trường `article` của từng tuần trong `pregnancy-content.json`; mọi tuần vẫn `"reviewed": false`. Xem trên
ảnh chụp `week-article-*` trong `ci-artifacts/screenshots/` của lần CI gần nhất, hoặc trong bản TestFlight.

Cấu trúc mỗi bài:
- **Thẻ Bé:** câu mở đầu in đậm; "Bé lớn cỡ nào?" (câu kích thước tự sinh + đoạn mô tả); "Bé phát triển ra sao".
- **Thẻ Mẹ:** "Cơ thể mẹ tuần này"; "Mẹ nên làm gì"; rồi mục "Khi nào cần đi khám ngay" (giữ nguyên như cũ).
- "Tài liệu tham khảo": các nguồn bài viết dùng (WHO, ACOG, NHS, Bộ Y tế, Hadlock).

**Câu kích thước** không viết tay: app tự ghép từ số liệu Hadlock đã có (mục 21), nên con số luôn khớp bảng
chuẩn. Mẫu câu (cần duyệt câu chữ, không cần duyệt lại số):

| Khóa | Nội dung (vi) |
|---|---|
| `weekArticle.size.length` (tuần 7–9) | "Bé dài khoảng 16 mm (từ đầu đến mông), cỡ một quả anh đào." |
| `weekArticle.size.lengthWeight` (tuần 10–13) | "Bé dài khoảng 53,5 mm (từ đầu đến mông) và nặng khoảng 58 g, tương đương một quả mận." (đổi ở giai đoạn 11, xem phần 13) |
| `weekArticle.size.weight` (tuần 14–42) | "Bé nặng khoảng 670 g (thường từ 556 đến 784 g), tương đương một củ đậu." (đổi ở giai đoạn 11, xem phần 13) Tuần 41–42 dùng số của tuần 40 kèm dòng "Số liệu chuẩn Hadlock chỉ đến tuần 40." |
| `weekArticle.heading.*`, `weekArticle.tab.*` | "Bé lớn cỡ nào?", "Bé phát triển ra sao", "Cơ thể mẹ tuần này", "Mẹ nên làm gì"; thẻ "Bé" / "Mẹ" |

Tuần 4–6 không có số đo, chỉ có đoạn mô tả bằng lời.

**Nguyên tắc viết** (tác giả đã áp dụng; bác sĩ kiểm tra theo):
- Chỉ viết mới; không câu nào chép hoặc diễn đạt lại sát từ Flo hay bất kỳ trang web nào.
- Dữ kiện lấy từ các nguồn trong danh sách nguồn; mỗi ý về sự phát triển của bé phải đúng với tuần đó
  (đối chiếu tài liệu theo tuần của ACOG và NHS).
- Tiếng Việt viết trực tiếp, không dịch; bản tiếng Anh viết song song, nói cùng nội dung.
- Xưng "mẹ" và "bé"; giọng ấm áp, bình tĩnh; câu ngắn (khoảng 25 từ trở xuống).
- Dùng từ rào đón ("thường", "khoảng", "có thể"); không chẩn đoán, không gây sợ hãi, không hứa hẹn về
  từng em bé; không nêu giới tính hay tỉ lệ phần trăm rủi ro.
- Chỉ dùng đơn vị mét (g, kg, mm, cm).
- Không nêu tên thuốc hay liều. Ngoại lệ: axit folic và sắt được nhắc tên (không liều), "theo hướng dẫn của
  bác sĩ hoặc nữ hộ sinh", như các gạch đầu dòng đã có. Vắc-xin chỉ gọi theo bệnh (uốn ván, ho gà). Mọi việc
  liên quan y tế đều hướng tới "bác sĩ hoặc nữ hộ sinh".
- Mỗi thẻ, mỗi ngôn ngữ dài 150–300 chữ (tiếng Việt đếm theo âm tiết); câu mở đầu tối đa 30 từ (en) / 40 âm
  tiết (vi). Các giới hạn này và việc không có inch/pound/ounce được kiểm tra tự động (`scripts/test-core.sh`).

35. [ ] **Duyệt từng tuần** (đúng dữ kiện, đúng tuần, giọng văn, không mâu thuẫn với các thẻ ở màn Hôm nay):
    - [ ] Tuần 4
    - [ ] Tuần 5
    - [ ] Tuần 6
    - [ ] Tuần 7
    - [ ] Tuần 8
    - [ ] Tuần 9
    - [ ] Tuần 10
    - [ ] Tuần 11
    - [ ] Tuần 12
    - [ ] Tuần 13
    - [ ] Tuần 14
    - [ ] Tuần 15
    - [ ] Tuần 16
    - [ ] Tuần 17
    - [ ] Tuần 18
    - [ ] Tuần 19
    - [ ] Tuần 20
    - [ ] Tuần 21
    - [ ] Tuần 22
    - [ ] Tuần 23
    - [ ] Tuần 24
    - [ ] Tuần 25
    - [ ] Tuần 26
    - [ ] Tuần 27
    - [ ] Tuần 28
    - [ ] Tuần 29
    - [ ] Tuần 30
    - [ ] Tuần 31
    - [ ] Tuần 32
    - [ ] Tuần 33
    - [ ] Tuần 34
    - [ ] Tuần 35
    - [ ] Tuần 36
    - [ ] Tuần 37
    - [ ] Tuần 38
    - [ ] Tuần 39
    - [ ] Tuần 40
    - [ ] Tuần 41
    - [ ] Tuần 42
36. [ ] Duyệt câu chữ câu kích thước tự sinh và các tiêu đề (bảng trên).
37. [ ] **Câu hỏi:** cho phép nhắc tên axit folic và sắt (không liều) trong bài viết như các gạch đầu dòng cũ,
        hay bỏ hẳn tên?
38. [ ] **Câu hỏi:** dòng "Người xem xét" hiện chỉ ghi "Nội dung đang chờ bác sĩ duyệt", không có tên. Sau khi
        duyệt, bác sĩ có đồng ý hiện tên mình trên từng tuần không? (Chưa làm ở giai đoạn này.)
39. [ ] **Dữ kiện tác giả thêm ngoài danh sách kiểm** (lấy từ báo cáo task-4, task-5, task-6; mỗi dữ kiện đã
        viết song ngữ, rào đón theo nguyên tắc viết ở trên) — xin bác sĩ xác nhận đúng với từng tuần dưới đây,
        hoặc góp ý sửa:
    - [ ] Tuần 5: ba lá phôi (ngoại bì, trung bì, nội bì) và các cơ quan mỗi lá hình thành.
    - [ ] Tuần 6: axit folic giúp ống thần kinh khép lại.
    - [ ] Tuần 7: túi noãn hoàng (yolk sac) vẫn giúp nuôi dưỡng bé giai đoạn này. **Câu hỏi:** vai trò này còn
          có tranh luận trong y văn — xin bác sĩ quyết định giữ câu này hay bỏ.
    - [ ] Tuần 8: tim thai đập nhanh hơn nhiều so với tim mẹ.
    - [ ] Tuần 9: gan bé đang tạo máu; mí mắt đang khép dần che mắt.
    - [ ] Tuần 10: tim đã hình thành đủ bốn ngăn; sụn bắt đầu hóa xương.
    - [ ] Tuần 11: mí mắt đã khép và thường đóng kín đến sau; bé bắt đầu nuốt nước ối; tai đang di chuyển lên
          vị trí.
    - [ ] Tuần 12: phần ruột thoát vị sinh lý qua dây rốn nay quay trở lại bụng.
    - [ ] Tuần 13: mắt bé đã dịch về phía trước mặt; siêu âm tam cá nguyệt hai đo vòng đầu và xương đùi.
    - [ ] Tuần 14: thân bé lớn nhanh hơn đầu; lông tơ (lanugo) thường rụng trước hoặc ngay sau sinh; tử cung
          nhô cao hơn khung chậu, bụng có thể lộ sớm hơn ở lần mang thai sau; gợi ý tập theo "phép thử nói
          chuyện" (vẫn nói được khi tập), bơi, yoga bầu.
    - [ ] Tuần 15: thể tích máu mẹ tăng khiến niêm mạc mũi phồng lên; cách xử trí chảy máu mũi (bóp phần mềm
          mũi, cúi người ra trước); canxi đang lắng vào xương bé; tai bé đang di chuyển về vị trí cuối; bé có
          thể nắm tay.
    - [ ] Tuần 16: tăng trưởng giai đoạn này chủ yếu vào cơ và xương, mỡ tích sau; tim thai đập nhanh hơn
          nhiều so với tim mẹ; vị trí bánh nhau có thể làm mẹ khó cảm nhận cử động sớm; vitamin C có thể giúp
          hấp thu sắt tốt hơn.
    - [ ] Tuần 17: mỡ giúp trẻ sơ sinh giữ ấm và dự trữ năng lượng; sụn tiếp tục hóa xương đến hết tuổi thiếu
          niên; lớp gel Wharton bảo vệ mạch máu trong dây rốn; tuyến mồ hôi đang hình thành; bánh nhau lớn
          cùng bé.
    - [ ] Tuần 18: các xương tai giữa của bé đang cứng lại; myelin bắt đầu hình thành; huyết áp mẹ thường
          thấp hơn vào giữa thai kỳ; siêu âm hình thái đo đầu, bụng và xương đùi.
    - [ ] Tuần 19: mầm răng vĩnh viễn đang hình thành; có thể xuất hiện vết sạm da ở mặt mẹ (má, trán, môi
          trên); móng tay mẹ có thể mọc nhanh hơn và dễ gãy hơn.
    - [ ] Tuần 20: từ tuần này chiều dài bé được đo từ đầu đến gót; thận thai nhi tạo nước tiểu quay lại nước
          ối; phân su gồm tế bào bong, dịch và dịch mật; lượng nước ối tăng dần; nước tiểu mẹ được kiểm tra
          mỗi lần khám, có nêu tiền sản giật.
    - [ ] Tuần 21: **câu kiểm tra lại cách viết tủy xương** (đã sửa ở vòng rà soát 1) — vi: "tủy xương ngày
          càng đảm nhận nhiều hơn việc tạo máu, cùng với gan và lá lách. Trong những tháng tới, tủy xương dần
          trở thành nơi tạo máu chính." Xin xác nhận câu này, cùng các dữ kiện khác của tuần 21: bé có thể
          hoạt động nhiều hơn khi mẹ nghỉ ngơi; nghiên cứu về việc bé "nếm" sớm và ảnh hưởng tới thói quen ăn
          uống sau này (viết ở dạng còn đang nghiên cứu); tất y khoa viết theo hướng "hỏi bác sĩ hoặc nữ hộ
          sinh".
    - [ ] Tuần 22: tóc đầu bé chưa có nhiều màu; môi rõ nét hơn; phản xạ nắm là phản xạ sớm, trẻ sơ sinh vẫn
          còn; móng tay bé đang mọc dài.
    - [ ] Tuần 23: mắt bé chuyển động nhanh (REM) khi ngủ; có cử động tập thở; huyết áp cao đôi khi không có
          triệu chứng ban đầu.
    - [ ] Tuần 25: lỗ mũi bé đang bắt đầu mở; các đường chỉ tay xuất hiện ở lòng bàn tay; chèn ép dây thần
          kinh cổ tay (hội chứng ống cổ tay) gây tê tay mẹ; mẹ rụng tóc nhiều hơn bình thường trong vài tháng
          sau sinh.
    - [ ] Tuần 26: màu mắt bé có thể còn thay đổi trong nhiều tháng sau sinh; phản xạ giật mình (Moro); cơn
          gò sinh lý "có thể là một cách tử cung tập luyện trước khi chuyển dạ"; câu đã sửa ở vòng rà soát 1:
          "Thức dậy thấy mình nằm ngửa là chuyện thường gặp, mẹ chỉ cần nghiêng người lại." — xin xác nhận câu
          này có mâu thuẫn với khuyến cáo nằm nghiêng từ tuần 28 không.
    - [ ] Tuần 27: bề mặt não bé bắt đầu có nếp gấp; bé thường hoạt động nhiều hơn vào buổi tối; nấc cụt
          thường vô hại; bé tập mút và nuốt; một số triệu chứng đầu thai kỳ (đi tiểu nhiều hơn) có thể quay
          lại.
    - [ ] Tuần 28: phổi bé chưa đủ sẵn sàng để tự hoạt động; da bé bắt đầu bớt nhăn khi mỡ tích dần; khi khám
          có thể đo huyết áp, nước tiểu và bề cao tử cung mẹ; nằm nghiêng cũng áp dụng cho giấc ngủ ngắn ban
          ngày.
    - [ ] Tuần 29: tử cung chèn lên cơ hoành và phổi mẹ; ngồi thẳng và chậm lại giúp giảm khó thở; xương bé
          nhận canxi từ mẹ qua bánh nhau; mẹ có thể thấy bụng chuyển động từ ngoài; nấc cụt của bé cảm nhận
          như những cú giật nhẹ đều đều; cách giảm ợ nóng (ăn bữa nhỏ, không nằm ngay sau ăn, mặc đồ rộng
          quanh eo); nếu mẹ không ăn sữa/chế phẩm sữa, hỏi bác sĩ hoặc nữ hộ sinh cách bổ sung đủ canxi.
    - [ ] Tuần 30: gan và lá lách từng tạo máu trước đây, tủy xương giờ là nơi chính tạo hồng cầu, hồng cầu
          mang oxy (khớp với câu ở tuần 21); lông tơ giúp giữ ấm, một số bé còn ít lông tơ lúc sinh, thường ở
          vai và lưng; não bé tiếp tục phát triển lâu sau sinh; bé mở mắt khi thức và nhắm khi ngủ; trọng tâm
          cơ thể mẹ thay đổi và khớp lỏng hơn do hormone, nên đi giày đế bằng chống trượt; siêu âm tăng trưởng
          kiểm tra sự phát triển, vị trí và nước ối, và bác sĩ sẽ giải thích kết quả cùng hướng theo dõi tiếp.
    - [ ] Tuần 31: ví dụ về các giác quan của bé (cảm nhận bằng mặt và tay, nếm nước ối, nghe âm thanh bên
          ngoài; thị giác còn hạn chế trong bóng tối tử cung); bé có thể phản ứng với giọng mẹ hoặc âm nhạc
          bằng cử động; sữa non được tả là đặc, màu hơi vàng, một số mẹ không thấy tiết sữa non và cả hai đều
          bình thường, có thể dùng miếng lót thấm sữa; chuẩn bị cho con bú: cách bế, cách ngậm bắt vú, và nơi
          tìm hỗ trợ.
    - [ ] Tuần 32: cử động tập thở đẩy dịch ra vào phổi bé; oxy vẫn qua bánh nhau đến khi sinh; da bé mềm và
          bớt trong hơn; chưa cần lo nếu bé chưa quay đầu ở tuần này; đỉnh tử cung mẹ đã cao hẳn trên rốn; nên
          lên kế hoạch di chuyển và lưu số liên hệ của khoa sản.
    - [ ] Tuần 33: phần lớn kháng thể truyền từ mẹ sang bé diễn ra ở giai đoạn cuối thai kỳ, và kháng thể còn
          giúp bảo vệ bé trong những tháng đầu sau sinh (đã sửa ở vòng rà soát 1); sưng chân mẹ nặng hơn khi
          nóng hoặc đứng lâu, gác chân cao và tập cổ chân giúp giảm; đồ chuẩn bị đi sinh nên có giấy tờ tùy
          thân và thẻ bảo hiểm y tế, ngoài sổ khám thai.
    - [ ] Tuần 34: phổi bé tiến triển thêm nhưng những tuần cuối vẫn quan trọng; hệ thần kinh nối não với cơ
          nên cử động bé phối hợp hơn; mỡ giúp bé giữ ấm sau sinh; đau vùng bẹn khi mẹ đi lại — báo bác sĩ
          hoặc nữ hộ sinh nếu đau khung chậu khiến khó đi lại hoặc khó xoay người khi ngủ, nên đi bước ngắn;
          các dấu hiệu chuyển dạ (cơn gò đều và mạnh hơn, vỡ ối, ra nhầy hồng) — nên lưu số khoa sản và có kế
          hoạch di chuyển vào bất kỳ giờ nào.
    - [ ] Tuần 35: thận bé tạo nước tiểu, trở thành một phần nước ối; mẹ có thể rỉ ít nước tiểu khi ho, cười
          hoặc hắt hơi — tập cơ sàn chậu, không nên uống ít nước để đỡ phải đi tiểu (đã sửa ở vòng rà soát 1);
          liên cầu khuẩn nhóm B (GBS) được tả là "vi khuẩn thường gặp", xét nghiệm bằng cách phết dịch để kíp
          đỡ sinh có cách bảo vệ bé lúc sinh.
    - [ ] Tuần 36: tụt đầu (dropping/engaging) — ở lần mang thai đầu thường xảy ra vài tuần trước sinh, ở lần
          sau có thể chỉ xảy ra khi chuyển dạ; chất gây (vernix) vẫn còn và một phần có thể còn lúc sinh;
          lông tơ và chất gây bé nuốt vào trở thành một phần phân su; hầu hết bé đã quay đầu lúc này — nếu bé
          ngôi mông hoặc ngôi ngang, bác sĩ/nữ hộ sinh sẽ trao đổi hướng xử lý; sau khi tụt đầu, ợ nóng có thể
          giảm và ăn được bữa đầy đủ hơn, mẹ có thể có cảm giác nhói nhẹ phía dưới; đồ chuẩn bị đi sinh nên có
          tã, đồ mặc, đồ ăn nhẹ và nước uống cho lúc chuyển dạ.
    - [ ] Tuần 37: bé có thể mút tay hoặc ngón tay trong bụng mẹ; một số bé sinh trong vài tuần tới, số khác
          sau ngày dự sinh; "ra nhầy hồng" là nút nhầy, có thể hồng hoặc lẫn máu, xuất hiện vài ngày trước
          hoặc khi bắt đầu chuyển dạ; khám hằng tuần gồm đo huyết áp, nghe tim thai và kiểm tra ngôi thai; khi
          có dấu hiệu chuyển dạ, gọi khoa sản để được hướng dẫn khi nào cần đến viện; nếu vỡ ối, gọi ngay cho
          khoa sản dù màu nước ối ra sao (đã sửa ở vòng rà soát 1).
    - [ ] Tuần 38: trong bụng mẹ bé có thể nắm dây rốn hoặc tay mình — đây là phản xạ nắm còn lại sau sinh;
          phân su thường ra trong những ngày đầu sau sinh; bé đang ở thế cuộn tròn; cơn gò sinh lý có thể đến
          gần nhau hơn, còn cơn gò chuyển dạ đều, dài và mạnh hơn; nên ăn nhẹ, đủ nước và đi bộ nhẹ nhàng.
          **Dữ kiện thêm ở vòng rà soát 1:** câu "bụng mẹ có thể thấy căng và nặng khi bé đã chiếm gần hết
          chỗ" — xin bác sĩ xác nhận tất cả các điểm trên.
    - [ ] Tuần 39: não bé tiếp tục phát triển nhanh trong những năm đầu đời; da tiếp da giúp giữ ấm cho bé;
          surfactant giúp phổi bé hoạt động khi bắt đầu thở không khí; nhầy hồng, cơn gò sinh lý và cảm giác
          tức nặng có thể là dấu hiệu sắp sinh, nhưng chuyển dạ vẫn có thể còn vài ngày hoặc vài tuần nữa.
    - [ ] Tuần 40: phản xạ bú của bé (quay đầu theo hướng chạm vào má và bú); đầu bé có thể hơi dài hoặc nhọn
          vài ngày đầu sau sinh; nhiều bé sinh trong khoảng một hai tuần trước hoặc sau ngày dự sinh, ngày dự
          sinh chỉ là ước tính; chờ lâu hơn dự sinh thường gặp hơn ở lần mang thai đầu; sau ngày dự sinh bác
          sĩ/nữ hộ sinh có thể nghe tim thai thường xuyên hơn.
    - [ ] Tuần 41: phần lớn chất gây đã mất nên da bé có thể khô hoặc bong, thường tự hết trong vài tuần đầu;
          hỏi nữ hộ sinh cách cắt móng tay cho bé sau sinh; theo dõi quá ngày dự sinh có thể gồm đo huyết áp
          và kiểm tra tim thai.
    - [ ] Tuần 42: da bé có thể khô, nứt hoặc bong, đặc biệt ở tay và chân, thường tự lành; bé vẫn nhận oxy
          và dưỡng chất qua bánh nhau, việc kiểm tra tim thai và nước ối cho biết bé đang thích nghi ra sao;
          các lần kiểm tra này có thể lặp lại nhiều lần trong tuần để giúp quyết định thời điểm sinh phù hợp.
- [ ] Khi bác sĩ duyệt xong một tuần: đổi `"reviewed": true` cho tuần đó như mục 1 — cờ này áp dụng cho cả
      các gạch đầu dòng lẫn bài viết của tuần.

## 10. Bài viết chuyên sâu theo tam cá nguyệt (giai đoạn 7)

Mục "Kiến thức" gồm 18 bài viết chuyên sâu trong 6 chủ đề, gắn với tam cá nguyệt. Màn Hôm nay (chế độ mang thai)
có thẻ "Gợi ý cho tam cá nguyệt N" với 3 bài và nút "Xem thêm" mở thư viện. Bài viết mới hoàn toàn, song ngữ
vi/en, nằm trong `Packages/KickCore/Sources/KickCore/Resources/knowledge-content.json`; mọi bài vẫn
`"reviewed": false`, nên bản App Store chưa hiện thẻ lẫn thư viện. Xem trên ảnh chụp `knowledge-*` trong
`ci-artifacts/screenshots/` của lần CI gần nhất, hoặc trong bản TestFlight (thư viện hiện tất cả bài).

**Nguyên tắc viết** (như mục 9, thêm):
- Mỗi bài 300–500 chữ mỗi ngôn ngữ (tóm tắt + tiêu đề mục + đoạn văn), 2–4 mục; câu tóm tắt tối đa 35 từ (en) /
  45 âm tiết (vi). Kiểm tra tự động, cùng việc không có đơn vị inch/pound/ounce và không có liều thuốc.
- Được nêu con số theo hướng dẫn y tế công cộng (danh sách ở mục 41).
- Bài về cảm xúc luôn có câu: nếu buồn chán hoặc lo âu gần như mỗi ngày, kéo dài từ hai tuần trở lên, mẹ hãy nói
  với bác sĩ hoặc nữ hộ sinh, hoặc người thân.
- Bài "Dấu hiệu chuyển dạ" khớp mục cảnh báo của từng tuần: vỡ ối thì gọi khoa sản ngay, dù nước ối màu gì; bé cử
  động ít đi thì gọi ngay, dù ngày hay đêm.
- Tuần luôn tính theo số tuần tròn đã qua (như màn Hôm nay); tiếng Việt dùng từ miền Bắc.

40. [ ] **Duyệt từng bài** (đúng dữ kiện, đúng tam cá nguyệt, giọng văn, khớp với bài viết theo tuần):
    - [ ] Dinh dưỡng — `nutrition-first-trimester`: Ăn uống trong tam cá nguyệt đầu
    - [ ] Dinh dưỡng — `food-safety`: An toàn thực phẩm khi mang thai
    - [ ] Dinh dưỡng — `iron-calcium-balanced-meals`: Sắt, canxi và bữa ăn cân đối
    - [ ] Vận động — `safe-exercise`: Vận động an toàn khi mang thai
    - [ ] Vận động — `gentle-exercise-second-trimester`: Vận động nhẹ nhàng ở tam cá nguyệt thứ hai
    - [ ] Vận động — `pelvic-floor-posture`: Cơ sàn chậu và tư thế hằng ngày
    - [ ] Giấc ngủ — `first-trimester-tiredness`: Mệt mỏi trong tam cá nguyệt đầu
    - [ ] Giấc ngủ — `sleep-positions`: Tư thế ngủ khi mang thai
    - [ ] Giấc ngủ — `sleeping-well-late-pregnancy`: Ngủ ngon hơn ở những tháng cuối
    - [ ] Cảm xúc — `early-pregnancy-worries`: Lo lắng khi mới mang thai
    - [ ] Cảm xúc — `changing-body-feelings`: Cơ thể thay đổi và cảm xúc của mẹ
    - [ ] Cảm xúc — `preparing-for-motherhood`: Chuẩn bị làm mẹ
    - [ ] Khám thai — `antenatal-checkup-milestones`: Lịch khám thai qua từng giai đoạn
    - [ ] Khám thai — `first-trimester-screening`: Xét nghiệm và sàng lọc đầu thai kỳ
    - [ ] Khám thai — `anomaly-scan-glucose-test`: Siêu âm hình thái và xét nghiệm tiểu đường
    - [ ] Chuẩn bị sinh — `signs-of-labour`: Nhận biết dấu hiệu chuyển dạ
    - [ ] Chuẩn bị sinh — `hospital-bag`: Chuẩn bị túi đồ đi sinh
    - [ ] Chuẩn bị sinh — `birth-plan-breastfeeding`: Kế hoạch sinh và những cữ bú đầu
41. [ ] **Con số theo hướng dẫn** — xác nhận từng con số và nguồn:
    - [ ] Vận động vừa sức khoảng 150 phút mỗi tuần; những lần tập ngắn cũng được tính (WHO 2020,
          ACOG CO 804) — `safe-exercise`, `gentle-exercise-second-trimester`.
    - [ ] Caffeine dưới 200 mg mỗi ngày (ACOG CO 462, NHS) — câu cố định trong `food-safety`: "Phần lớn các hướng
          dẫn khuyên mẹ giữ tổng lượng caffeine dưới 200 mg mỗi ngày, tính cả cà phê, trà, nước cola, nước tăng lực
          và sô-cô-la." Đây là câu duy nhất được phép có đơn vị mg.
    - [ ] Nằm nghiêng khi đi ngủ từ khoảng tuần 28 (NICE NG201, NHS) — `sleep-positions`.
    - [ ] "Baby blues" thường hết trong khoảng hai tuần (NICE CG192, NHS) — `preparing-for-motherhood`.
    - [ ] Buồn chán hoặc lo âu gần như mỗi ngày từ hai tuần trở lên thì nói với bác sĩ hoặc nữ hộ sinh — các bài
          cảm xúc.
    - [ ] Ít nhất 8 lần tiếp xúc chăm sóc trước sinh (WHO 2016) — `antenatal-checkup-milestones`.
    - [ ] Các mốc: đo độ mờ da gáy và double test tuần 11–14; siêu âm hình thái tuần 18–22; xét nghiệm tiểu đường
          thai kỳ tuần 24–28 (khớp lịch khám gợi ý ở mục 4).
    - [ ] Chuẩn bị túi đồ đi sinh từ khoảng tuần 33, xong trước khoảng tuần 36.
    - [ ] Cho con bú trong giờ đầu sau sinh; chỉ bú mẹ hoàn toàn trong 6 tháng đầu; kẹp dây rốn sau ít nhất 1 phút
          khi có thể (WHO, WHO/UNICEF 2018) — `birth-plan-breastfeeding`.
    - [ ] Nấu ăn bằng muối i-ốt giúp đủ i-ốt, chất cơ thể cần nhiều hơn khi mang thai (WHO, Bộ Y tế) — không kèm
          liều lượng — `iron-calcium-balanced-meals`.
42. [ ] **Câu hỏi:** bài `early-pregnancy-worries` có câu "nếu có ý nghĩ làm hại bản thân, hãy nói với người mẹ tin
        tưởng và tìm trợ giúp ngay: gọi 115 hoặc đến bệnh viện gần nhất". Câu này cũng lặp lại ở `changing-body-feelings`
        và `preparing-for-motherhood`. Bác sĩ có muốn thêm một đường dây hỗ trợ tâm lý cụ thể ở Việt Nam không?
43. [ ] **Câu hỏi:** bài `antenatal-checkup-milestones` nêu khuyến cáo "ít nhất 8 lần" của WHO và viết "lịch khám do
        cơ sở y tế của mẹ đặt". Có cần nêu số lần khám tối thiểu theo hướng dẫn của Bộ Y tế không?
44. [ ] **Danh sách nguồn** (`sources` trong `knowledge-content.json`, 10 mục: WHO 2016, WHO 2020, ACOG, ACOG CO 804,
        ACOG CO 462, NHS, NICE NG201, NICE CG192, WHO/UNICEF 2018, Bộ Y tế) — xác nhận phù hợp.
45. [ ] **Dữ kiện tác giả thêm ngoài danh sách kiểm** (từ các commit nội dung của giai đoạn 7) — xin bác sĩ xác nhận:
    - [ ] `nutrition-first-trimester`: axit folic quan trọng nhất trong giai đoạn não và cột sống bé hình thành;
          rau lá xanh, các loại đậu và cam có folate.
    - [ ] `nutrition-first-trimester`: uống đủ nước giúp đỡ táo bón; nói với bác sĩ hoặc nữ hộ sinh về chế độ ăn
          ở lần khám đầu; không tự dùng thêm thực phẩm bổ sung hay thuốc nam khi chưa hỏi.
    - [ ] `food-safety`: pa-tê là sản phẩm từ gan; rượu gạo tự nấu cũng tính là rượu; một cốc cà phê đậm có thể
          dùng gần hết lượng caffeine cho phép trong ngày, nên chọn cốc nhạt hơn, nhỏ hơn hoặc đã khử caffeine.
    - [ ] `food-safety`: dùng thớt và dao riêng cho thịt sống; cho thức ăn còn lại vào tủ lạnh sớm sau khi ăn.
    - [ ] `iron-calcium-balanced-meals`: canxi giúp xây xương và răng cho bé; mẹ có thể thấy ăn ngon hơn ở tam cá
          nguyệt hai; gợi ý món ăn nhẹ (trái cây, sữa chua, các loại hạt, trứng luộc) thay cho bánh kẹo và nước
          ngọt.
    - [ ] `iron-calcium-balanced-meals`: nấu ăn bằng muối i-ốt có thể giúp mẹ có đủ i-ốt, chất cơ thể cần nhiều
          hơn khi mang thai (WHO, Bộ Y tế).
    - [ ] `gentle-exercise-second-trimester`: ví dụ khởi động (đi bộ chậm, xoay vai); nên chọn thời điểm trời mát
          hoặc phòng thoáng khí.
    - [ ] `pelvic-floor-posture`: cơ sàn chậu giúp kiểm soát việc đi tiểu và xì hơi; gợi ý gắn bài tập với một
          việc làm hằng ngày; đau vùng chậu khiến cả việc đi cầu thang, đi lại và xoay người khi ngủ khó khăn hơn.
    - [ ] `safe-exercise`: tránh yoga nóng, thể dục dụng cụ, đi xe đạp địa hình và quyền anh (ACOG CO 804); ngừng
          tập nếu đau đầu hoặc yếu cơ ảnh hưởng đến thăng bằng (ACOG CO 804); đau đầu dữ dội, hoặc kèm nhìn mờ hay
          phù đột ngột → liên hệ khoa sản ngay.
    - [ ] `first-trimester-tiredness`: năng lượng thường trở lại từ khoảng tuần 14 (đầu tam cá nguyệt hai).
    - [ ] `first-trimester-tiredness`: cảm giác choáng váng muốn ngất → đến khoa cấp cứu ngay (cảnh báo tuần 4–12).
    - [ ] `sleep-positions`: ngất xỉu, hoặc chóng mặt không hết sau khi ngồi dậy → đến bác sĩ hoặc nữ hộ sinh ngay
          (như bài `safe-exercise`).
    - [ ] `sleep-positions`: nằm nghiêng giúp giảm áp lực của tử cung lên tĩnh mạch lớn, máu đến bé dễ dàng hơn.
    - [ ] `sleep-positions`: hơi gập đầu gối có thể giảm mỏi lưng và hông; nên kê gối ngồi dựa thay vì nằm thẳng
          khi đọc sách hay nghỉ ngơi.
    - [ ] `sleeping-well-late-pregnancy`: nâng cao đầu giường, ví dụ kê gối dưới nệm.
    - [ ] `sleeping-well-late-pregnancy`: chuột rút thường hết trong vài phút; nếu một vùng ở chân sưng, đỏ và
          đau → đến bác sĩ ngay.
    - [ ] `early-pregnancy-worries`: nhờ bác sĩ hoặc nữ hộ sinh giải thích một kết quả xét nghiệm hay siêu âm
          khiến mẹ lo lắng.
    - [ ] `changing-body-feelings`: đường sậm màu giữa bụng, vài vùng da mặt sậm hơn, tóc dày và óng hơn; phần
          lớn mờ dần sau sinh, vết rạn da cũng nhạt màu dần.
    - [ ] `changing-body-feelings`: kích thước bụng phụ thuộc chiều cao và vóc người mẹ; bác sĩ hoặc nữ hộ sinh
          theo dõi sự phát triển của bé qua các lần khám.
    - [ ] `changing-body-feelings`: bé được nước ối và các cơ của tử cung đệm bảo vệ.
    - [ ] `preparing-for-motherhood`: lớp học trước sinh giải thích các giai đoạn chuyển dạ và cách giảm đau
          (không nêu tên thuốc).
    - [ ] `preparing-for-motherhood`: trầm cảm sau sinh khá phổ biến và có thể điều trị; câu mốc hai tuần áp dụng
          cho cả trước và sau khi sinh.
    - [ ] `first-trimester-screening`: hội chứng Down được nêu một lần làm ví dụ về bất thường nhiễm sắc thể.
    - [ ] `anomaly-scan-glucose-test`: nên xét nghiệm đường huyết vài tuần sau sinh, vì nguy cơ tiểu đường về
          sau cao hơn.
    - [ ] `birth-plan-breastfeeding`: WHO khuyên da tiếp da và kẹp dây rốn muộn cho bé khỏe mạnh.
    - [ ] `signs-of-labour`: đau đầu dữ dội, mờ mắt hoặc sưng phù bất thường → đến khoa sản ngay; co giật hoặc
          khó thở → gọi 115 (theo cảnh báo tuần 20–42).
    - [ ] `hospital-bag`: nhắc cử động thai giảm (gọi ngay, dù ngày hay đêm) và vỡ ối (đến ngay, dù màu nước ối
          ra sao).
46. [ ] **Câu hỏi:** bài `food-safety` khuyên nấu chín phô mai mềm mốc trắng (kiểu brie/camembert). Với loại đã
        tiệt trùng (pasteurised), bác sĩ có cho vẫn cần nấu chín, hay có thể ăn sống nếu nhãn ghi rõ đã tiệt
        trùng không?
47. [ ] **Câu hỏi:** bài `food-safety` xếp gan và pa-tê vào cùng mức khuyến cáo. Bác sĩ muốn dùng "hạn chế" hay
        "tránh hẳn"? Pa-tê rất phổ biến trong bánh mì ở Việt Nam, nên cần câu chữ rõ ràng.
48. [ ] **Câu hỏi:** về điểm đến khi ngất xỉu — `safe-exercise` và `sleep-positions` viết "đến bác sĩ hoặc nữ hộ
        sinh ngay", còn `first-trimester-tiredness` viết "đến khoa cấp cứu ngay" (kèm bối cảnh thai ngoài tử
        cung ở tuần 4–12). Bác sĩ có muốn thống nhất một điểm đến cho cả ba bài, hay giữ khác nhau theo bối cảnh
        từng bài?
49. [ ] **Câu hỏi:** bài `sleeping-well-late-pregnancy` hiện chỉ nói về ợ nóng. Có nên thêm câu: đau nặng ngay
        dưới sườn, kèm đau đầu hoặc thay đổi thị lực, nên đến khoa sản ngay (dấu hiệu tiền sản giật) không?
50. [ ] **Câu hỏi:** câu muối i-ốt ở mục 41 chỉ là lời khuyên bằng chữ, không kèm liều lượng cụ thể (mg hay đơn
        vị khác). Bác sĩ xác nhận cách viết không nêu liều là đủ, hay cần nêu con số.
51. [ ] **Câu hỏi:** các cảnh báo theo tuần trong `pregnancy-content.json` dùng en "maternity unit" / vi
        "bệnh viện", còn các bài viết chuyên sâu ở mục này dùng "khoa sản". Bác sĩ muốn dùng từ tiếng Việt nào
        thống nhất — "khoa sản" hay "bệnh viện"?
52. [ ] **Ghi chú:** bài `sleep-positions` dẫn sang bài khác bằng tên bài: "Sleeping well in late pregnancy" /
        "Ngủ ngon hơn ở những tháng cuối". Nếu đổi tên bài `sleeping-well-late-pregnancy`, cần sửa câu dẫn này
        theo cho khớp.

## 11. Mục tiêu "Theo dõi chu kỳ" và phần giới thiệu mới (giai đoạn 9)

Người dùng không mong con giờ có thể chọn "Theo dõi chu kỳ". Dữ liệu và dự đoán giống hệt chế độ "Mong con"
(quy tắc ở mục 6 không đổi); chỉ cách trình bày khác. Các chuỗi dưới đây nằm trong `Shared/Localizable.xcstrings`
(không có cờ `reviewed`), nên **phải được duyệt trước khi gửi App Store**. Xem câu chữ thật trên ảnh chụp
`onboarding-regularity-*`, `onboarding-contraception-*`, `onboarding-cycle-length-*`, `cycle-tracking-coming-up-*`,
`cycle-pill-*` và `profile-tracking-rows-*` trong `ci-artifacts/screenshots/` của lần CI gần nhất.

| Khóa | Nội dung (vi) cần duyệt |
|---|---|
| `contraception.none`, `.condom`, `.pill`, `.implantOrInjection`, `.hormonalIUD`, `.copperIUD`, `.fertilityAwarenessOrWithdrawal`, `.otherOrPrivate` | Tám lựa chọn: Không dùng · Bao cao su · Thuốc tránh thai hằng ngày · Que cấy hoặc thuốc tiêm tránh thai · Vòng tránh thai có nội tiết · Vòng tránh thai chữ T bằng đồng · Tính ngày hoặc xuất tinh ngoài · Cách khác hoặc không muốn nói |
| `onboarding.contraception.why` | "Vì sao hỏi: một số biện pháp như thuốc tránh thai thường làm ngừng rụng trứng, nên Luna Mom sẽ không hiện những ngày dễ thụ thai có thể không đúng với bạn. Thông tin này chỉ dùng để chọn nội dung hiển thị." |
| `cycle.notContraception` | Ghi chú dưới "Khả năng thụ thai cao" khi theo dõi chu kỳ: "Đây là những ngày dễ có thai nhất. Dự đoán chỉ là ước tính, không phải biện pháp tránh thai. Nếu không muốn có thai, hãy luôn dùng một biện pháp tránh thai đáng tin cậy." |
| `cycle.highPregnancyChance` | Tên cửa sổ thụ thai khi theo dõi chu kỳ: "Khả năng thụ thai cao" (chế độ Mong con vẫn gọi "Cửa sổ thụ thai") |
| `cycle.hormonalNote` | Khi dùng thuốc, que cấy/thuốc tiêm hoặc vòng nội tiết: "Khi dùng biện pháp tránh thai bằng nội tiết tố, dự đoán ngày dễ thụ thai không còn chính xác (thuốc tránh thai, que cấy và thuốc tiêm thường làm ngừng rụng trứng), nên Luna Mom không hiển thị những ngày này. Ngày ra máu chỉ mang tính ước tính." |
| `cycle.withdrawalBleed` | Nhãn "Ra máu dự kiến" thay cho "Kỳ kinh tiếp theo" / "Kỳ kinh dự đoán" khi dùng biện pháp có nội tiết |
| `onboarding.regularity.irregularNote` | Hiện khi chọn "Không đều": "Chu kỳ dao động một chút là chuyện thường gặp, nhất là sau sinh, khi đang cho con bú hoặc lúc căng thẳng. Bạn ghi càng nhiều kỳ kinh, dự đoán thường càng sát hơn. Nếu chu kỳ hay ngắn hơn 21 ngày hoặc dài hơn 35 ngày, hoặc mất kinh 3 tháng liền, bạn nên trao đổi với bác sĩ." |
| `onboarding.cycleLength.hint` | "Tính từ ngày đầu của một kỳ kinh đến hết ngày trước kỳ kinh sau. Nhiều người có chu kỳ từ 21 đến 35 ngày, của bạn có thể khác." |
| `onboarding.privacy` | Câu chào mừng: "Dữ liệu được lưu trên iPhone và iCloud của bạn. Bạn tự chọn chia sẻ những gì. Không quảng cáo, không bán dữ liệu." |
| `onboarding.regularity.*`, `onboarding.result.late`, `profile.showFertilityTests(.hint)` | Đều / Không đều / Không rõ và mô tả; "Theo ngày bạn nhập, kỳ kinh có thể đã trễ khoảng %@."; "Hiện que thử rụng trứng & nhiệt độ" |
| `settings.cycleReminders.hint.tracking` | Chú thích dưới công tắc "Nhắc chu kỳ" trong Hồ sơ khi theo dõi chu kỳ (không nhắc trước cửa sổ thụ thai, xem mục 56): "Nhắc lúc 9:00: 1 ngày trước kỳ kinh dự kiến và một lần khi trễ kinh 3 ngày." (chế độ Mong con vẫn dùng `settings.cycle.remindersHint`, có nhắc 2 ngày trước cửa sổ thụ thai) |

53. [ ] Bác sĩ đã duyệt (hoặc sửa) toàn bộ các khóa trong bảng trên, cả bản vi lẫn en.
54. [ ] **Nhóm "có nội tiết"** (`Contraception.isHormonal` trong `Packages/KickCore/Sources/KickCore/CycleGoal.swift`):
        thuốc tránh thai hằng ngày, que cấy hoặc thuốc tiêm, vòng có nội tiết. Với nhóm này app **ẩn** cửa sổ thụ thai và
        ngày rụng trứng, gọi lần ra máu là "Ra máu dự kiến" và không đổi cách tính ngày. Vòng chữ T bằng đồng, bao cao
        su, tính ngày/xuất tinh ngoài vẫn **hiện** "Khả năng thụ thai cao" kèm ghi chú "không phải biện pháp tránh thai".
        **Câu hỏi:** cách chia này có đúng không — thuốc chỉ có progestin (progestin-only pill), que cấy và vòng nội
        tiết không phải lúc nào cũng ngừng rụng trứng. Có nên vẫn ẩn cửa sổ thụ thai, hay hiện kèm ghi chú? (Hiện tại:
        ẩn.)
55. [ ] **Khi theo dõi chu kỳ, ngày thường không có nhãn "Khả năng thụ thai thấp"** (chỉ "Ngày 13 của chu kỳ"), để
        không ai hiểu nhầm là ngày "an toàn". Xác nhận cách làm này.
56. [ ] **Nhắc nhở khi theo dõi chu kỳ**: chỉ còn hai loại, "Ngày mai có thể đến kỳ kinh" (`cycle.reminder.period.*`)
        và "Kỳ kinh đã trễ 3 ngày / Bạn có thể thử thai" (`cycle.reminder.late.*`); không nhắc trước cửa sổ thụ thai.
        **Câu hỏi:** cả hai câu nhắc hiện đều nói "kỳ kinh" (period) dù người dùng đang dùng biện pháp tránh thai nội
        tiết, mà lần ra máu khi đó có thể là ra máu do thuốc chứ không phải kỳ kinh tự nhiên. Với người dùng nhóm
        "có nội tiết" (mục 54), thông báo nên vẫn nói "kỳ kinh", hay đổi sang "ra máu" cho đúng hơn?
57. [ ] **Ngưỡng chu kỳ:** lời giải thích độ dài chu kỳ (`onboarding.cycleLength.hint`) nói "từ 21 đến 35 ngày", và
        lời trấn an chu kỳ không đều (`onboarding.regularity.irregularNote`) nói nên trao đổi với bác sĩ nếu chu kỳ
        "ngắn hơn 21 ngày hoặc dài hơn 35 ngày, hoặc mất kinh 3 tháng liền". **Câu hỏi:** các ngưỡng 21/35 ngày và
        mốc "mất kinh 3 tháng" có đúng với người lớn không, hay cần điều chỉnh?
58. [ ] **Thuốc tránh thai chỉ có progestin (progestin-only pill, "thuốc tránh thai đơn thuần")** hiện không có lựa chọn
        riêng: người dùng sẽ chọn "Thuốc tránh thai hằng ngày" (`contraception.pill`), và app xử lý như thuốc phối hợp
        (ẩn cửa sổ thụ thai và ngày rụng trứng, gọi lần ra máu là "Ra máu dự kiến"). **Câu hỏi:** thuốc chỉ có
        progestin có nên gộp chung vào "Thuốc tránh thai hằng ngày" không, hay cần một lựa chọn riêng với cách hiển thị
        riêng (ví dụ vẫn hiện cửa sổ thụ thai kèm ghi chú, vì loại thuốc này không phải lúc nào cũng ngừng rụng trứng)?
        (Câu hỏi này tách riêng khỏi mục 54, vốn hỏi về cả nhóm "có nội tiết".)


## 13. So sánh kích thước theo cân nặng (giai đoạn 11)

Từ tuần 10, vật được so sánh ("tương đương một quả …") được chọn theo **cân nặng thường gặp** của cả quả/củ khi mua
(gồm vỏ, hạt, lõi), có nguồn, và chênh không quá ±25 % so với cân nặng Hadlock 1991 (bách phân vị 50) mà app hiển
thị. Tuần 41–42 so với cân nặng tuần 40 (3619 g). Tuần 4–9 giữ nguyên so sánh cũ. Từ tuần 33 đến 42 mỗi tuần một vật
khác nhau (theo yêu cầu của chủ sản phẩm). Số liệu nằm ở `size.typicalGrams` / `size.sourceKey` và `produceSources`
trong `pregnancy-content.json` (phiên bản 4); test tự động kiểm tra mức ±25 % (`ContentValidator`). Nghiên cứu đầy
đủ (cách tính, nguồn, đoạn trích): `docs/research/2026-10-08-produce-weights.md`.

| Tuần | Hadlock (g) | So sánh (vi) | Cân nặng thường gặp (g) | Chênh lệch | Nguồn (`sourceKey`) |
|---|---|---|---|---|---|
| 10 | 35 | một quả chanh leo 🟣 | 35 | +0,0 % | `usda-passionfruit` |
| 11 | 45 | một quả mơ 🍑 | 38 | −15,6 % | `usda-apricot` |
| 12 | 58 | một quả mận 🍑 | 70 | +20,7 % | `usda-plum` |
| 13 | 73 | một quả chanh không hạt 🍋 | 80 | +9,6 % | `usda-lime` |
| 14 | 93 | một quả khế ⭐ | 94 | +1,1 % | `usda-carambola` |
| 15 | 117 | một quả quýt 🍊 | 119 | +1,7 % | `usda-tangerine` |
| 16 | 146 | một quả cà chua 🍅 | 135 | −7,5 % | `usda-tomato` |
| 17 | 181 | một quả cam 🍊 | 179 | −1,1 % | `usda-orange` |
| 18 | 223 | một quả táo 🍎 | 202 | −9,4 % | `usda-apple` |
| 19 | 273 | một quả bơ 🥑 | 272 | −0,4 % | `usda-avocado` |
| 20 | 331 | một quả lê Hàn Quốc 🍐 | 302 | −8,8 % | `usda-asian-pear` |
| 21 | 399 | một bắp ngô to 🌽 | 397 | −0,5 % | `usda-corn` |
| 22 | 478 | một quả xoài 🥭 | 473 | −1,0 % | `usda-mango` |
| 23 | 568 | một quả lựu 🍎 | 504 | −11,3 % | `usda-pomegranate` |
| 24 | 670 | một củ đậu 🥔 | 716 | +6,9 % | `usda-jicama` |
| 25 | 785 | một quả dưa lưới nhỏ 🍈 | 865 | +10,2 % | `usda-cantaloupe` |
| 26 | 913 | một bắp cải tím 🥬 | 1049 | +14,9 % | `usda-red-cabbage` |
| 27 | 1055 | một quả bưởi 🍈 | 1088 | +3,1 % | `usda-pummelo` |
| 28 | 1210 | một quả bầu 🥒 | 1101 | −9,0 % | `usda-calabash` |
| 29 | 1379 | một quả đu đủ to 🥭 | 1260 | −8,6 % | `usda-papaya` |
| 30 | 1559 | một bắp cải to 🥬 | 1560 | +0,1 % | `usda-cabbage` |
| 31 | 1751 | một quả dứa 🍍 | 1775 | +1,4 % | `usda-pineapple` |
| 32 | 1953 | một quả sầu riêng 🍈 | 1881 | −3,7 % | `usda-durian` |
| 33 | 2162 | một quả dừa 🥥 | 1800 | −16,7 % | `bentre-dua-ta` |
| 34 | 2377 | một cây súp lơ trắng to 🥦 | 2154 | −9,4 % | `usda-cauliflower` |
| 35 | 2595 | một cây cải thảo 🥬 | 2250 | −13,3 % | `vietaseeds-cai-thao-va304` |
| 36 | 2813 | một quả bí xanh 🥒 | 2500 | −11,1 % | `vaas-bi-xanh-so-1` |
| 37 | 3028 | một quả gấc 🟠 | 2850 | −5,9 % | `vnuf-gac-19` |
| 38 | 3236 | một quả dưa mật 🍈 | 2783 | −14,0 % | `usda-honeydew` |
| 39 | 3435 | một quả mít nhỏ 🟢 | 2948 | −14,2 % | `ufifas-jackfruit-hs882` |
| 40 | 3619 | một quả dưa hấu 🍉 | 3500 | −3,3 % | `ninhbinh-dua-hau-hac-my-nhan` |
| 41 | 3619 | một quả bí đỏ 🍈 | 3150 | −13,0 % | `vaas-bi-do-mat-sao-2` |
| 42 | 3619 | một quả mãng cầu xiêm 🍈 | 3000 | −17,1 % | `nnmt-mang-cau-xiem` |

Chênh lệch = (cân nặng thường gặp − Hadlock) / Hadlock. Các dòng USDA FoodData Central (SR Legacy: tuần 10–32, súp
lơ tuần 34, dưa mật tuần 38) quy từ phần ăn được ra cả quả theo tỉ lệ bỏ đi của SR28. Các dòng còn lại của tuần 33–42
lấy từ nguồn Việt Nam hoặc UF/IFAS; khi nguồn cho một khoảng, "cân nặng thường gặp" là **điểm giữa** của khoảng đó.
Emoji chỉ dùng khi chưa có tranh minh họa của tuần.

**Lưu ý về đầu mút khoảng:** test chỉ kiểm tra điểm giữa (con số app dùng). Ở một số tuần, đầu mút của khoảng trong
nguồn nằm ngoài ±25 %: tuần 33 (dừa 1,6 kg: −26,0 %), 35 (cải thảo 1,5–3 kg: −42,2 % / +15,6 %), 36 (bí xanh 2,0 kg:
−28,9 %), 39 (mít nhỏ 3–10 lb: −60 % / +32 %), 42 (mãng cầu xiêm 2–4 kg: −44,7 % / +10,5 %). Một quả mua ngoài chợ
có thể nặng hoặc nhẹ hơn khá nhiều so với bé. Câu chữ dùng "tương đương" (so sánh gần đúng về cân nặng), không khẳng
định bằng nhau tuyệt đối; **câu hỏi:** với khoảng rộng như trên, "tương đương" có quá mạnh không, hay nên dùng "cỡ"?

**Câu chữ mới** (`weekArticle.size.lengthWeight` và `weekArticle.size.weight`; tuần 7–9 vẫn là "cỡ …"):
- Tuần 12: "Bé dài khoảng 53,5 mm (từ đầu đến mông) và nặng khoảng 58 g, tương đương một quả mận." / "Your baby is about
  53.5 mm long from head to bottom and weighs about 58 g, about as heavy as a plum."
- Tuần 24: "Bé nặng khoảng 670 g (thường từ 556 đến 784 g), tương đương một củ đậu." / "Your baby weighs about 670 g
  (typically 556 to 784 g), about as heavy as a jicama."

62. [ ] Bác sĩ đã duyệt (hoặc sửa) bảng trên: tên vi tự nhiên (tiếng Bắc), vật so sánh phù hợp với từng tuần.
63. [ ] Duyệt câu chữ mới "tương đương …" / "about as heavy as …" (hai câu mẫu ở trên), cả vi lẫn en.
64. [ ] **Các điểm nghiên cứu đã nêu và đã chấp nhận** (xem `docs/research/2026-10-08-produce-weights.md` §4) — xin
        bác sĩ xác nhận hoặc đề nghị đổi:
    - [ ] Tuần 26 (bắp cải tím) và tuần 30 (bắp cải to) cùng họ bắp cải; hai vật khác nhau, có nguồn riêng.
    - [ ] Tuần 33, quả dừa (dừa ta "trái khô", còn vỏ): trang của Sở KH&CN Bến Tre không còn truy cập được, nội
          dung được đọc từ bản lưu trên Internet Archive (đường dẫn trong `produceSources`).
    - [ ] Tuần 35, cây cải thảo: nguồn duy nhất là phiếu giống của một công ty hạt giống, khoảng 1,5–3 kg khá rộng;
          cải thảo ngoài chợ thường 1,5–2 kg.
    - [ ] Tuần 37, quả gấc: 2850 g là trung bình đo được của một dòng gấc (GAC-19) trong một nghiên cứu; gấc nếp
          thông thường thường nhẹ hơn (dòng GAC-46 trong cùng bài trung bình 1,861 kg).
    - [ ] Tuần 38, "quả dưa mật" (honeydew): tên tiếng Việt chưa thống nhất (cửa hàng còn gọi "dưa lưới ruột xanh");
          cùng loài *Cucumis melo* với dưa lưới tuần 25 nhưng là nhóm giống khác, vỏ trơn màu nhạt. Xin xác nhận tên.
    - [ ] Tuần 39, "quả mít nhỏ": số liệu UF/IFAS cho các giống mít quả nhỏ (3–10 lb); mít phổ biến ở Việt Nam nặng
          hơn nhiều (khoảng 6,75 kg), nên tên ghi rõ "mít nhỏ".
    - [ ] Tuần 42, quả mãng cầu xiêm: lời một nhà vườn trên báo của Bộ (2–4 kg), khác với số liệu USDA (933 g, quả
          bán ở Mỹ); một trang của Bộ Công Thương ghi 1–3 kg cho Hậu Giang.
    - [ ] Đầu mút khoảng nằm ngoài ±25 % ở các tuần 33, 35, 36, 39, 42 (xem lưu ý trên bảng).
    - [ ] Tuần 41 (quả bí đỏ) và 42 so với cân nặng tuần 40, vì chuẩn Hadlock chỉ đến tuần 40.
    - [ ] Tuần 32 là quả sầu riêng: cân nặng cả quả (1881 g) suy ra từ tỉ lệ bỏ đi lớn (68 %), nên là dòng USDA kém
          chắc chắn nhất.
    - [ ] Tuần 10 là quả chanh leo (số liệu USDA cho chanh leo tím, 35 g); một số giống lai ở Việt Nam to hơn.
    - [ ] Tuần 13 là "quả chanh không hạt" (USDA "Limes, raw" là chanh Tahiti); chanh ta nhỏ hơn và chưa có số liệu.
    - [ ] Tuần 21 là bắp ngô to tính cả vỏ và lõi (397 g); bắp ngô đã bóc vỏ chỉ khoảng 250 g.
65. [ ] Tranh thai nhi theo tuần: duyệt theo danh sách kiểm tra y khoa ở `docs/design/fetus-artwork-brief.md` §5
        (giai đoạn thai, tỉ lệ đầu–thân, mắt, lông tơ, không gây hiểu nhầm là hình ảnh chẩn đoán).
