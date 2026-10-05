# Phase 5 — Ghi triệu chứng & Cân nặng mẹ

Ngày: 2026-10-05 · Trạng thái: chờ duyệt

## 1. Mục tiêu và phạm vi

Thêm hai tính năng từ bản thiết kế "Mầm" (`docs/design/mam-handoff/README.md` §4, §8, "Bottom sheet –
Ghi triệu chứng", hằng `OPTS` trong `prototype.html`), dựng bằng hệ thống thiết kế phase 4
(`App/DesignSystem/`, token `LunaPalette`, `L10n`, `AppLocale`).

1. **Ghi triệu chứng**: lượng kinh (chế độ Mong con), tâm trạng, triệu chứng — cho cả hai chế độ.
2. **Cân nặng mẹ** (chế độ Mang thai): ghi theo ngày, mức tăng so với trước mang thai, dải khuyến nghị
   IOM 2009 theo BMI trước mang thai.

**Quyết định của người dùng**
- Thứ tự: Triệu chứng + Cân nặng trước; Kiến thức, Bạn đời là giai đoạn sau.
- Dải cân nặng theo **BMI trước mang thai** (IOM 2009, 4 nhóm); không có chiều cao → không hiện dải.
- Chế độ Mang thai có **màn "Triệu chứng"** xem lại theo tuần thai.
- Ghi "Cơn gò" hoặc "Phù chân" → **thẻ nhắc nhẹ** về dấu hiệu cần đi khám (không chẩn đoán).

**Ngoài phạm vi**: Kiến thức/bài viết, Bạn đời, gộp cử động 5 phút, mục tiêu đếm 5–20, biểu đồ nhiệt độ.

**Giữ nguyên**: mọi hành vi phase 3/4 (dự đoán chu kỳ, LH/BBT/dịch nhầy, Cardiff, Hadlock, nhắc nhở,
widget/Live Activity), các id accessibility đang được test dùng.

## 2. Dữ liệu

### 2.1 `CycleLog` mở rộng (KickData, CloudKit — chỉ thêm trường)
Thêm: `flowRaw: String?`, `moodsRaw: String?`, `symptomsRaw: String?` (danh sách phân tách bằng dấu
phẩy, giá trị raw ổn định tiếng Anh). `CycleLogRecord` (KickCore) thêm:
- `flow: MenstrualFlow?` — `none | light | medium | heavy`.
- `moods: [Mood]` — `happy | calm | sensitive | anxious | tired`.
- `symptoms: [Symptom]` — chế độ Mong con: `cramps | headache | tenderBreasts | acne | bloating | cravings`;
  chế độ Mang thai: `nausea | heartburn | swollenFeet | backPain | legCramps | insomnia | contractions`.
  `Symptom.mode` cho biết thuộc chế độ nào; UI chỉ hiện mục của chế độ hiện tại, dữ liệu mục kia vẫn giữ.
- `unknownMoodsRaw` / `unknownSymptomsRaw` / flow raw lạ: **giữ nguyên** khi ghi lại (như LH/dịch nhầy).

Quy tắc:
- Log “rỗng” (không trường nào) = xóa log ngày đó (giữ quy tắc phase 3).
- Gộp bản trùng cùng ngày (`CycleRules.mergingDuplicates`): moods/symptoms = hợp (giữ thứ tự enum),
  flow = mức nặng hơn, các trường cũ giữ quy tắc phase 3.
- Lượng kinh **không** tự tạo kỳ kinh.
- Ghi ở chế độ Mang thai dùng chung `CycleRepository`/`CycleStore` (không ảnh hưởng dự đoán chu kỳ:
  `CyclePredictor` chỉ đọc LH/BBT).

### 2.2 `WeightEntry` mới (KickData, CloudKit)
`@Model WeightEntry { id: UUID = UUID(), day: Date = Date(), kg: Double = 0 }`, thêm vào schema.
KickCore: `WeightRecord { id, day, kg }`, `@MainActor protocol WeightRepository { entries(), save(_:), delete(id:) }`,
`WeightRules`: ngày chuẩn hóa đầu ngày, không ngày tương lai, kg trong 30,0–200,0 (làm tròn 0,1),
một bản ghi mỗi ngày (ghi cùng ngày = cập nhật bản ghi đó), gộp trùng khi đọc: giữ bản có `id`
sắp xếp trước (`uuidString`) cùng `kg` của chính bản đó, xóa các bản còn lại (quy tắc xác định giống
`CycleRules`).

### 2.3 Hồ sơ cân nặng (UserDefaults App Group, không đồng bộ — như `PregnancyProfile`)
`MaternalProfile { preWeightKg: Double?, heightCm: Double? }` — khóa `maternalPreWeightKg`,
`maternalHeightCm`; cân trước mang thai 30–200 kg, chiều cao 120–220 cm.

### 2.4 Dải khuyến nghị (KickCore `WeightGuidance`)
- BMI = kg / (m²), nhóm IOM: `under` < 18,5; `normal` 18,5–24,9; `over` 25,0–29,9; `obese` ≥ 30,0.
- Tổng mức tăng tuần 40 (thai đơn): under 12,5–18; normal 11,5–16; over 7–11,5; obese 5–9 kg.
- Tam cá nguyệt 1 (tuần 0–13): tăng tuyến tính từ 0 tới 0,5–2,0 kg ở tuần 13 (mọi nhóm).
- Từ tuần 13 tới 40: tuyến tính từ (0,5 / 2,0) tới tổng tuần 40 của nhóm (cận dưới/cận trên tương ứng).
- Sau tuần 40: giữ giá trị tuần 40.
- `status(gain:week:category:) -> .inRange | .below | .above`.
- Không có `heightCm` hoặc `preWeightKg` → không có nhóm/dải/trạng thái (chỉ biểu đồ cân nặng thô nếu
  có cân trước; không có cân trước → chỉ danh sách kg).

## 3. Màn hình

### 3.1 Bảng ghi ngày — Mong con (`CycleDayLogSheet`, giữ id hiện có)
Thứ tự: Lượng kinh (chip chọn 1, chọn lại để bỏ) · Tâm trạng (chip nhiều) · Triệu chứng (chip nhiều,
danh sách Mong con) · "Dấu hiệu rụng trứng" (LH, BBT, dịch nhầy hiện có) · Ghi chú · nút Lưu.
Chip dùng kiểu phase 4 (`cycleStrong` chọn / `surface` chưa chọn), mỗi chip có trait `.isSelected`.
Thẻ "Hôm nay bạn thấy thế nào?" và thẻ ngày chọn ở Lịch hiển thị tóm tắt: lượng kinh · tâm trạng ·
triệu chứng · nhiệt độ (tối đa 1 dòng, cắt bằng "…" + nhãn VoiceOver đầy đủ).

### 3.2 Màn "Triệu chứng" — Mang thai (`PregnancySymptomsView`)
Mở từ lối tắt "Triệu chứng" trên Hôm nay (Mang thai). Gồm: thẻ hôm nay (tóm tắt + "Ghi hôm nay"/"Sửa"),
danh sách ngày đã ghi nhóm theo tuần thai (`PregnancyTimeline`), chạm để sửa, vuốt để xóa (xác nhận).
Bảng ghi (`PregnancySymptomSheet`): Tâm trạng · Triệu chứng (danh sách Mang thai) · Ghi chú · Lưu.
**Thẻ nhắc an toàn**: khi `contractions` hoặc `swollenFeet` được chọn, ngay dưới nhóm chip hiện thẻ
`warningBackground` với câu chữ cố định (khóa `symptom.safety.*`): đi khám ngay nếu cơn gò đều đặn hoặc
đau trước tuần 37, ra nước/ra máu; phù đột ngột ở mặt/tay kèm đau đầu, nhìn mờ, đau vùng thượng vị;
nút "Xem dấu hiệu cần đi khám" mở Chi tiết tuần hiện tại tới mục cảnh báo. Dòng ngày đó trong danh sách
có biểu tượng cảnh báo + nhãn VoiceOver. Không chẩn đoán, không đếm cơn gò.

### 3.3 Màn "Cân nặng" (`WeightView`)
Mở từ lối tắt "Cân nặng". Thứ tự:
- Chưa có cân trước mang thai → thẻ thiết lập (cân trước mang thai, chiều cao — chiều cao có thể bỏ qua),
  nút Lưu. Sửa sau trong Cá nhân.
- Thẻ tóm tắt: "Đã tăng X kg" (32/700 `pregStrong`) "so với trước khi mang thai"; nhóm BMI ("BMI 21,3 ·
  Bình thường"); pill trạng thái tuần hiện tại.
- Biểu đồ 170 pt (Swift Charts): trục x tuần thai 0–40, dải khuyến nghị (`AreaMark` `pregSoft`), đường
  người dùng (`LineMark` + điểm, `pregStrong` 2,5 pt). VoiceOver: từng điểm "Tuần N: tăng X kg, trong
  khoảng/ngoài khoảng".
- Bộ nhập: ngày (mặc định hôm nay, DatePicker không quá hôm nay, không trước LMP), kg ±0,1 (nút tròn 42)
  và ô gõ (chấp nhận "56,2" và "56.2"), nút "Lưu" `preg`.
- Danh sách theo tuần thai (mới nhất trên), vuốt để xóa (xác nhận).
- Chưa có ngày thai kỳ → trạng thái trống mời nhập ngày thai kỳ.

### 3.4 Hôm nay — Mang thai
- 4 lối tắt: Đếm cử động · Triệu chứng · Cân nặng · Tuần thai (kích thước/style phase 4, AX5 không cắt).
- Thẻ "Cân nặng của mẹ" (sau thẻ kích thước bé): kg mới nhất · "+X kg" · pill `Trong khoảng`
  (`fertileSoft`/`tealStrong`) / `Thấp hơn khoảng` / `Cao hơn khoảng` (`pregSoft`/`pregOnSoft`, không đỏ)
  + dòng phụ "Trao đổi với bác sĩ ở lần khám tới" khi ngoài khoảng. Chưa có dữ liệu → "Ghi cân nặng".

### 3.5 Cá nhân
Mục Thai kỳ thêm dòng "Cân nặng trước mang thai · Chiều cao" (`profileMaternal`) mở sheet sửa.

## 4. Kiến trúc
- KickCore: `SymptomKinds.swift` (enum + raw/parse), mở rộng `CycleRecords.swift`/`CycleRules`,
  `WeightRecords.swift` (record, repository, rules), `WeightGuidance.swift`, `MaternalProfile.swift`,
  `WeightCoordinator.swift` (`@MainActor @Observable`, mẫu phase 3: `load()` dùng chung task, báo lỗi,
  re-check sau await), `WeightStats` (mức tăng theo tuần, điểm biểu đồ).
- KickData: `CycleLog` thêm trường + `apply`/`record`; `WeightEntry` + `WeightStore` (seam `saveContext`,
  rollback), schema thêm `WeightEntry.self`.
- App: `App/Symptoms/` (chip group, sheet Mang thai, màn Mang thai, thẻ an toàn), `App/Weight/`
  (màn, biểu đồ, thẻ thiết lập, thẻ Hôm nay), sửa `CycleDayLogSheet`, `CycleTodayView`, `CycleCalendarView`,
  `PregnancyTodayView`, `ProfileView`, `AppEnvironment` (WeightCoordinator + seed).
- Test-only: `-seedWeights` (chỉ `#if DEBUG` + `-uiTesting`): cân trước 52 kg, cao 160 cm, các tuần như
  `SEED_W` của prototype (12: 53,1 · 16: 54,6 · 20: 56,2 · 24: 58,0 · 27: 59,4 · 30: 60,9) quy đổi theo
  `-fixedNow` + ngày thai kỳ seed; `-seedCycles` mở rộng có moods/symptoms trong log mẫu.

## 5. Xử lý lỗi, trợ năng
- Lỗi lưu/đọc: alert như hiện tại; lưu lỗi → rollback, giữ trạng thái cũ.
- Nhập ngoài khoảng: báo ngay dưới ô (không lưu) + announcement VoiceOver.
- Dynamic Type AX5 không cắt chữ (chip xuống dòng — dùng flow layout), VoiceOver: chip có trait chọn,
  biểu đồ có nhãn từng điểm, thẻ an toàn đọc trước danh sách chip tiếp theo.
- Mọi animation tôn trọng Reduce Motion + `LunaMotion.isEnabled`. Màu chỉ qua token, cặp chữ/nền khai báo
  trong `LunaContrast.usages`.

## 6. Kiểm thử
- KickCore (local): parse/serialize raw (kể cả giá trị lạ), merge trùng (hợp/tăng mức), log rỗng = xóa;
  `WeightRules` (khoảng, ngày, làm tròn, một bản ghi/ngày, gộp trùng); `WeightGuidance` (BMI biên 18,5 /
  25,0 / 30,0; dải tuần 0, 13, 14, 40, 42 cho 4 nhóm; status); `MaternalProfile` (lưu/đọc/khoảng);
  `WeightCoordinator` (load không prompt, lưu, xóa, lỗi, re-check); điều kiện thẻ an toàn.
- KickData (CI): `CycleLog` trường mới + giữ raw lạ + gộp; `WeightStore` CRUD, rollback, gộp trùng.
- UI (CI): Mong con ghi tâm trạng + triệu chứng → tóm tắt trên thẻ Hôm nay và thẻ ngày ở Lịch; Mang thai
  ghi "Cơn gò" → thẻ an toàn → mở Chi tiết tuần; thiết lập cân (52 kg, 160 cm) → ghi 58,0 ở tuần 24 →
  "Trong khoảng"; bỏ qua chiều cao → không có dải/pill; 4 lối tắt mở đúng màn.
- Ảnh chụp: mọi màn mới vi/en × sáng/tối + AX5 cho màn Cân nặng và màn Triệu chứng.

## 7. Nội dung cần bác sĩ duyệt (thêm mục 8 vào `docs/content-review-for-doctor.md`)
- Ngưỡng IOM 2009 theo nhóm BMI, cách chia theo tuần, và việc dùng ngưỡng BMI chuẩn (không phải ngưỡng
  châu Á của WHO: thừa cân ≥ 23).
- Câu chữ "Trong khoảng / Thấp hơn / Cao hơn khoảng" và "Trao đổi với bác sĩ ở lần khám tới".
- Câu chữ thẻ an toàn "Cơn gò" / "Phù chân".
- Tên triệu chứng/tâm trạng/lượng kinh (vi + en).

## 8. Rủi ro
- Ngưỡng BMI cho người châu Á — chờ bác sĩ quyết định (có thể đổi bằng hằng số, không đổi dữ liệu).
- Schema CloudKit thêm trường `CD_CycleLog` (`CD_flowRaw`, `CD_moodsRaw`, `CD_symptomsRaw`) và record type
  `CD_WeightEntry` — cần deploy Production qua bản build ký development (release checklist).
- Dữ liệu sức khỏe nhạy cảm (cân nặng, triệu chứng): chỉ lưu trên máy + iCloud riêng của người dùng,
  không gửi đi đâu — cập nhật `PrivacyInfo.xcprivacy`/nhãn quyền riêng tư App Store nếu cần.
