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
