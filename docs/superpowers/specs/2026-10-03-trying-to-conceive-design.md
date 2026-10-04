# Thiết kế: Giai đoạn 3 — Chế độ "Mong con" (theo dõi chu kỳ, rụng trứng)

- **Ngày:** 2026-10-03
- **Trạng thái:** Đã duyệt hướng thiết kế, chờ review spec
- **Nền:** spec v1 (đếm cử động) và giai đoạn 2 (hành trình thai kỳ). Giữ mọi ràng buộc cũ: iOS 17+, Swift 6, không server, không SDK bên thứ ba, song ngữ vi/en qua `L10n` + String Catalog, KickCore không import SwiftData, máy dev không có Xcode (xác minh qua CI GitHub Actions trên repo `lmtiep/kick-counter`).

## 1. Mục tiêu

Giúp người phụ nữ đang mong có con theo dõi kỳ kinh, biết cửa sổ dễ thụ thai và ngày rụng trứng ước tính, ghi dấu hiệu cơ thể để dự đoán chính xác hơn, và chuyển mượt sang chế độ mang thai khi có thai.

**Tiêu chí thành công:**
- Ghi ngày bắt đầu/kết thúc kỳ kinh; app dự đoán kỳ kinh tiếp theo, ngày rụng trứng và cửa sổ thụ thai.
- Que thử LH dương tính và nhiệt độ cơ thể (BBT) điều chỉnh/xác nhận dự đoán.
- Lịch tháng tô màu rõ ràng; nhắc trước cửa sổ thụ thai, trước kỳ kinh, khi trễ kinh.
- Bấm "Tôi đã có thai" → chế độ mang thai với ngày dự sinh tính từ kỳ kinh cuối đã ghi.

**Ngoài phạm vi:** HealthKit (để bản sau), chia sẻ với bạn đời, ghi quan hệ tình dục, nhắc uống vitamin, biểu đồ BBT chi tiết, dự đoán bằng máy học, dùng như biện pháp tránh thai.

## 2. Quyết định chính

| Hạng mục | Quyết định |
|---|---|
| Lưu trữ | SwiftData + iCloud riêng của người dùng (như lượt đếm, lịch hẹn) |
| Chế độ | `AppMode`: `tryingToConceive` \| `pregnant`; onboarding hỏi; nút "Tôi đã có thai"; đổi trong Cài đặt |
| Tab chế độ Mong con | **Chu kỳ** · **Lịch** · **Cài đặt** (ẩn Thai kỳ, Đếm, Lịch sử) |
| Tab chế độ Mang thai | Như giai đoạn 2 (Thai kỳ · Đếm · Lịch sử · Cài đặt) |
| Dự đoán | Theo lịch + điều chỉnh bởi LH/BBT; độ tin cậy thấp khi chu kỳ không đều |
| Nhắc | 9:00: 2 ngày trước cửa sổ thụ thai; 1 ngày trước kỳ kinh dự kiến; trễ kinh 3 ngày |

## 3. Dữ liệu

### 3.1 Cài đặt (App Group `UserDefaults`)
- `appMode` (`"pregnant"` mặc định cho người dùng cũ đã có ngày dự sinh hoặc đã qua onboarding; người dùng mới chọn ở onboarding).
- `typicalCycleLength` (21–45, mặc định 28), `typicalPeriodLength` (2–10, mặc định 5).
- `cycleRemindersEnabled` (mặc định bật sau khi được cấp quyền thông báo).

### 3.2 SwiftData (`KickData`, CloudKit-compatible)
```swift
@Model final class PeriodEntry {
    var id: UUID = UUID()
    var startDate: Date = Date()   // đầu ngày theo lịch
    var endDate: Date?             // nil = đang hành kinh
}
@Model final class CycleLog {
    var id: UUID = UUID()
    var day: Date = Date()          // đầu ngày; tối đa một bản ghi mỗi ngày (bất biến do store đảm bảo)
    var lhRaw: String?              // "positive" | "negative"
    var bbtCelsius: Double?         // 35.0–38.5
    var mucusRaw: String?           // "dry" | "sticky" | "creamy" | "eggWhite"
    var note: String = ""
}
```
Thêm vào schema (thay đổi bổ sung). Store đảm bảo không trùng ngày/khoảng kỳ kinh chồng nhau (gộp khi đồng bộ iCloud tạo trùng, như bất biến "một session active" của v1).

## 4. Logic (KickCore, test local)

### 4.1 `CyclePredictor` (thuần, nhận `now` + `Calendar`)
Đầu vào: các kỳ kinh (start, end?), các log ngày, cài đặt. Đầu ra `CycleForecast`:
- `cycleDay` (ngày 1 = ngày đầu kỳ kinh gần nhất), `currentPeriodStart`.
- `averageCycleLength`: trung bình tối đa **6** chu kỳ hoàn chỉnh gần nhất **có độ dài 21–45 ngày**; nếu chưa có chu kỳ hợp lệ → `typicalCycleLength`.
- `nextPeriodStart` = đầu kỳ hiện tại + `averageCycleLength`.
- `ovulationDate` = `nextPeriodStart − 14 ngày`; **nếu chu kỳ hiện tại có LH dương tính** → ngày LH dương đầu tiên + 1 (ghi đè).
- `fertileWindow` = `ovulationDate − 5` … `ovulationDate + 1`.
- `confidence`: `.low` nếu có ≥ 3 chu kỳ hợp lệ và (độ lệch chuẩn > 4 ngày hoặc chênh lớn nhất − nhỏ nhất > 7 ngày), hoặc chưa đủ 2 chu kỳ đã ghi; khi `.low` nới cửa sổ thêm `min(3, (max−min)/2)` ngày mỗi bên (trước khi có LH).
- `ovulationConfirmed`: BBT — 3 ngày liên tiếp đều cao hơn **mức cao nhất của 6 ngày trước đó** ít nhất 0,2 °C trong chu kỳ hiện tại → `true` và ghi ngày rụng trứng xác nhận = ngày trước nhiệt độ tăng.
- `dayStatus(for date)`: `.period` (đã ghi hoặc dự đoán), `.fertile`, `.peak` (ngày rụng trứng và ngày trước đó), `.low`.
- `daysLate`: số ngày quá `nextPeriodStart` khi chưa ghi kỳ kinh mới.
- `irregularWarning`: chu kỳ hoàn chỉnh gần nhất < 21 hoặc > 45 ngày, hoặc ≥ 3 chu kỳ có chênh > 7 ngày.

### 4.2 `CycleCoordinator` (`@MainActor @Observable`, cùng mẫu `AppointmentCoordinator`)
- Ghi/xóa kỳ kinh và log qua `CycleRepository` (protocol trong KickCore; `CycleStore` trong KickData).
- Sau mỗi thay đổi: tính lại forecast, đặt lại 3 loại nhắc (id `cycle-fertile`, `cycle-period`, `cycle-late`), hủy khi tắt nhắc hoặc khi chuyển sang chế độ mang thai.
- `load()` không xin quyền; re-check sau mỗi `await` (bài học từ giai đoạn 1–2).

### 4.3 Chuyển chế độ
- "Tôi đã có thai": sheet xác nhận với ngày đầu kỳ kinh cuối = `currentPeriodStart` (sửa được bằng `PregnancyDateForm` ở chế độ LMP) → `PregnancyProfile.saveLMP` → `appMode = pregnant` → hủy nhắc chu kỳ. Dữ liệu chu kỳ được giữ lại.
- Đổi từ Cài đặt sang "Mong con": giữ nguyên dữ liệu thai kỳ, lịch hẹn và nhắc lịch hẹn; chỉ đổi tab hiển thị và bật lại nhắc chu kỳ (nếu đã bật).

## 5. Giao diện

- **Tab Chu kỳ:** vòng chu kỳ (các ngày tô màu theo `dayStatus`, đánh dấu hôm nay), dòng trạng thái ("Ngày 12 của chu kỳ · Khả năng thụ thai cao"), thẻ "Kỳ kinh tiếp theo: dd/MM (còn N ngày)", thẻ cửa sổ thụ thai + ngày rụng trứng (nhãn "đã xác nhận" khi BBT xác nhận), nhãn "Độ tin cậy thấp — chu kỳ chưa đều" khi `.low`; nút ghi nhanh: **Bắt đầu/Kết thúc kỳ kinh**, **Ghi hôm nay** (LH, BBT, dịch nhầy, ghi chú). Thẻ trễ kinh (≥ 3 ngày): gợi ý thử thai + nút **"Tôi đã có thai"**. Thẻ cảnh báo chu kỳ bất thường → gợi ý gặp bác sĩ.
- **Tab Lịch:** lịch tháng (vuốt đổi tháng), ô ngày tô màu: kỳ kinh đã ghi (đậm), dự đoán (nhạt/viền), cửa sổ thụ thai, ngày rụng trứng; chấm nhỏ cho ngày có log; chạm ngày → sheet ghi/sửa log ngày đó và bắt đầu/kết thúc kỳ kinh. Chú thích màu.
- **Onboarding:** sau "Tôi đã hiểu": bước chọn chế độ. Mong con → nhập ngày đầu kỳ kinh gần nhất (bắt buộc hoặc "Để sau"), độ dài chu kỳ, số ngày hành kinh.
- **Cài đặt:** mục "Chế độ" (Mong con / Đang mang thai); mục "Chu kỳ" (độ dài chu kỳ, số ngày hành kinh, bật/tắt nhắc) — chỉ hiện ở chế độ Mong con; mục Thai kỳ chỉ hiện ở chế độ mang thai.
- **Thông tin y tế:** thêm đoạn: không dùng để tránh thai; dự đoán chỉ là ước tính; nên gặp bác sĩ nếu đã cố gắng 12 tháng (6 tháng nếu ≥ 35 tuổi) chưa có thai, chu kỳ < 21 hoặc > 45 ngày, hoặc rất không đều, ra máu bất thường giữa kỳ.
- Màu: dùng AccentColor (hồng) cho kỳ kinh, xanh lá dịu cho cửa sổ thụ thai, tím cho ngày rụng trứng; đủ tương phản sáng/tối; không chỉ dựa vào màu (có ký hiệu/nhãn VoiceOver).

## 6. Xử lý lỗi & trường hợp biên
| Tình huống | Hành vi |
|---|---|
| Chưa có kỳ kinh nào | Tab Chu kỳ hiện màn mời nhập ngày đầu kỳ kinh gần nhất |
| Chỉ 1 kỳ kinh | Dự đoán theo `typicalCycleLength`, `confidence = .low` |
| Kỳ kinh chưa kết thúc > 10 ngày | Gợi ý ghi ngày kết thúc / gặp bác sĩ nếu ra máu kéo dài |
| Ghi kỳ kinh trong tương lai / chồng nhau | Không cho phép (UI chặn, store kiểm tra) |
| BBT ngoài 35,0–38,5 °C | Không lưu, báo nhập lại |
| Trễ kinh | Thẻ gợi ý thử thai từ ngày trễ thứ 3; nhắc một lần |
| Từ chối quyền thông báo | Vẫn hoạt động; dòng nhắc bật thông báo trong Cài đặt |
| Đồng bộ tạo bản ghi trùng | Store gộp (một log mỗi ngày, kỳ kinh không chồng nhau) |

## 7. Bản địa hóa, trợ năng
Mọi chuỗi mới qua `L10n` (en + vi). Lịch tháng theo `Calendar`/locale (thứ đầu tuần theo locale). Dynamic Type; VoiceOver đọc từng ô ngày ("12 tháng 10, cửa sổ thụ thai, đã ghi que thử dương tính"). Chế độ tối.

## 8. Kiểm thử
- **Unit (KickCore, local):** `CyclePredictor` — chu kỳ đều 28, ngắn 24, dài 35, không đều (độ tin cậy thấp + nới cửa sổ), bỏ chu kỳ ngoài 21–45, LH ghi đè, BBT xác nhận (đúng và sai quy tắc 3-trên-6), trễ kinh, chưa có dữ liệu, ranh giới đầu/cuối tháng và DST; `CycleCoordinator` (nhắc đặt/hủy, chuyển chế độ, re-entrancy, lỗi lưu).
- **KickData (CI):** `CycleStore` CRUD, chặn chồng nhau, gộp trùng, rollback.
- **UI test (CI):** onboarding chọn Mong con → nhập kỳ kinh → tab Chu kỳ đúng ngày chu kỳ; ghi LH dương → ngày rụng trứng đổi; "Tôi đã có thai" → tab Thai kỳ đúng tuần.
- **Ảnh chụp (CI):** tab Chu kỳ (ngày kinh, cửa sổ thụ thai, trễ kinh, độ tin cậy thấp), tab Lịch, sheet ghi ngày, onboarding chọn chế độ, Cài đặt — sáng/tối, vi/en, ngày cố định qua `-fixedNow`, dữ liệu mẫu qua launch argument mới `-seedCycles` (chỉ `-uiTesting`, `#if DEBUG`).

## 9. Phát hành
- Bổ sung tài liệu cho bác sĩ: các chuỗi y tế mới (thông tin y tế, cảnh báo chu kỳ bất thường, gợi ý thử thai).
- CloudKit: thêm `CD_PeriodEntry`, `CD_CycleLog` vào bước deploy schema (bản build ký development).
- Ghi chú phát hành + ảnh chụp App Store cho chế độ Mong con.
