# Phase 4 — Redesign theo bản thiết kế "Mầm" (giao diện trước, tính năng sau)

Ngày: 2026-10-04 · Trạng thái: chờ duyệt

## 1. Mục tiêu và phạm vi

Làm lại **giao diện mọi màn hình đang có** của Luna Mom theo bản bàn giao thiết kế "Mầm"
(`docs/design/mam-handoff/README.md` + `prototype.html`, bản gốc ở
`~/Downloads/design_handoff_mam_app`). Giữ nguyên dữ liệu, logic và hành vi đã có.

**Quyết định của người dùng**
- Tên app vẫn là **Luna Mom** (mọi chữ "Mầm" trong thiết kế đổi thành "Luna Mom").
- **Giao diện trước, tính năng sau**: giai đoạn này chỉ làm lại các màn đã có.
- Thanh tab 3 mục: **Mong con** Hôm nay · Lịch · Cá nhân; **Mang thai** Hôm nay · Cử động · Cá nhân.
  Lịch sử cử động nằm trong màn Cử động; avatar ở đầu trang cũng mở Cá nhân.
- **Đổi ngôn ngữ ngay trong app** (Theo máy / Tiếng Việt / English), áp dụng tức thì.
- **Giữ chế độ tối**, bảng màu tối do mình suy ra từ thiết kế (§3).
- Đếm cử động: chỉ thêm **rung khi chạm** (bật/tắt). Không gộp 5 phút, không đổi mục tiêu
  (giữ 10 theo Cardiff), chạm đầu tiên vẫn vừa mở phiên vừa tính 1 cử động (giữ Live Activity).
- Font **Be Vietnam Pro** (OFL), 5 độ đậm 300/400/500/600/700, nhúng vào app.

**Ngoài phạm vi (giai đoạn sau)**: ghi triệu chứng/tâm trạng/lượng kinh, cân nặng mẹ, Kiến thức/bài
viết, Bạn đời, gộp 5 phút, mục tiêu 5–20, mục "Dành cho bạn", lối tắt Triệu chứng/Cân nặng, thẻ
cân nặng mẹ, tên/ảnh bác sĩ.

**Giữ nguyên**: SwiftData + iCloud, mọi coordinator (`KickCoordinator`, `AppointmentCoordinator`,
`CycleCoordinator`), `CyclePredictor` (LH/BBT, độ tin cậy, trễ kinh), số liệu Hadlock (cân nặng
P50 + P10–P90, CRL tuần 7–13), nội dung tuần thai, nhắc nhở, widget + Live Activity, VoiceOver,
Dynamic Type, mọi id accessibility mà test đang dùng (đổi id chỉ khi bắt buộc, cập nhật test cùng lúc).

## 2. Kiến trúc

### 2.1 `App/DesignSystem/`
- `LunaColor.swift`: token màu dạng `Color` thích ứng sáng/tối (tạo từ cặp hex qua
  `UIColor(dynamicProvider:)`), đặt tên theo vai trò (§3). Giá trị hex nằm ở KickCore `LunaPalette`
  (để test độ tương phản chạy local); App chỉ bọc thành `Color`. Không dùng màu hex rải rác trong view.
- `LunaFont.swift`: đăng ký font (Info.plist `UIAppFonts`), API `Font.luna(_ style:)` với các kiểu
  của thiết kế (ringNumber 52/700, onboardingTitle 34/400, display 32/700, screenTitle 28/700,
  sheetTitle 22/700, cardTitle 16/600, body 14/400, caption 13/400, label 11–12/600 uppercase).
  Mọi kiểu co giãn theo Dynamic Type (`Font.custom(_:size:relativeTo:)`).
- Thành phần dùng chung (mỗi cái một file, có preview):
  `LunaCard` (nền thẻ, bo 20, padding 16–18, lề 20), `PillButton` (chính/phụ/đen, cao 52–60, bo 99,
  scale .98 khi nhấn), `SegmentedPill`, `DayCircle` (ô ngày tròn 40, các trạng thái kinh/dự đoán/
  thụ thai/rụng trứng/hôm nay/đang chọn), `LunaSheet` (nền mờ, sheet bo trên 28, tay nắm 40×5 —
  dựng trên `.sheet` + `presentationDetents` + `presentationBackground`), `Toast` (pill tối, tự ẩn
  1,9 s, VoiceOver đọc qua announcement), `ScreenHeader` (avatar 38 + tiêu đề + nút phải),
  `ChipScroller` (dải chip cuộn ngang, tự cuộn tới mục chọn).
- `Motion.swift`: các animation của thiết kế (reveal, kenBurns, waveRise, waveDrift, contentUp,
  float, ripple, pop) gói thành modifier; tất cả đọc `accessibilityReduceMotion` và rút về fade.

### 2.2 Ngôn ngữ trong app
- `AppLanguage` (KickCore): `system | vi | en`, lưu `AppGroup.defaults` khóa `appLanguage`.
  `resolved(preferred: [String]) -> Locale` (system → ngôn ngữ đầu tiên của máy nếu là vi/en, ngược lại en).
- `L10n.t` tra chuỗi trong bundle `.lproj` của ngôn ngữ đã chọn (fallback en). Widget/Live Activity
  dùng cùng giá trị qua App Group.
- Gốc app đặt `.environment(\.locale, …)` để `Date.formatted`, số, DatePicker theo ngôn ngữ đã chọn.
  `Formatting` nhận locale từ `AppLanguage.current` (vi "4 tháng 10", "36,5"; en "Oct 4", "36.5").
- Đổi ngôn ngữ → `RootView` dựng lại (id theo ngôn ngữ) và **đặt lại mọi nhắc đã hẹn** với chữ mới
  (nhắc đếm hằng ngày, nhắc chu kỳ, nhắc lịch khám, cảnh báo 2 giờ của phiên đang chạy) qua API sẵn có
  của từng coordinator.

### 2.3 Điều hướng
- `RootView`: `TabView` với thanh tab tùy biến theo thiết kế (82pt, nền `tabBar`, viền trên,
  màu active theo chế độ: `cycleStrong` / `pregStrong`, inactive `tabInactive`), icon SF Symbols.
- Mong con: `.today` (CycleTodayView) · `.calendar` · `.profile`.
  Mang thai: `.today` (PregnancyTodayView) · `.kicks` (KicksView, có lối vào Lịch sử) · `.profile`.
- Avatar ở `ScreenHeader` → `.profile`. Lịch khám mở từ thẻ trên Hôm nay (Mang thai) và từ Cá nhân.
- Đổi chế độ vẫn theo `@AppStorage(appMode)` như phase 3.

## 3. Bảng màu

| Token | Sáng (thiết kế) | Tối (suy ra) |
|---|---|---|
| `background` | `#FBF6F1` | `#1A1412` |
| `onboardingBackground` | `#F4F1EC` | `#1A1412` |
| `card` | `#FFFFFF` | `#262019` |
| `surface` (nền phụ) | `#F4ECE5` | `#2F2722` |
| `surfaceAlt` | `#F1E7DF` | `#342B26` |
| `textPrimary` | `#2B201C` | `#F4ECE5` |
| `textOnboarding` | `#141110` | `#F4ECE5` |
| `textSecondary` | `#7A6B64` | `#B5A69E` |
| `textMuted` | `#9A8A82` | `#9A8A82` |
| `chevron` | `#B5A69E` | `#7A6B64` |
| `articleText` | `#544640` | `#D8CCC4` |
| `cycle` | `#E0566B` | `#EE7A8C` |
| `cycleStrong` | `#C2384F` | `#F59AA8` |
| `cycleSoft` | `#FBE3E6` | `#4A2128` |
| `fertile` | `#8CCFC7` | `#6FBFB6` |
| `fertileSoft` | `#E3F2F0` | `#1E3A37` |
| `ovulation` | `#CBEAE6` | `#24524D` |
| `teal` | `#2F8C84` | `#7FD3C9` |
| `tealStrong` | `#1F6E67` | `#A6E3DB` |
| `preg` | `#C9673E` | `#E08A5F` |
| `pregStrong` | `#B8572F` | `#F0A07A` |
| `pregSoft` | `#F7E3D7` | `#45281A` |
| `pregOnSoft` | `#9C4823` | `#F4C2A6` |
| `pregBar` | `#E3A584` | `#8A4E33` |
| `track` | `#F1E2D8` | `#3A2E28` |
| `ringTrack` | `#F3E6E0` | `#3A2E28` |
| `warningBackground` | `#FDE8E4` | `#4A1E18` |
| `warningBorder` | `#F3C2B8` | `#7A3328` |
| `warningText` | `#A3301F` | `#FF9C8A` |
| `warningButton` | `#C23A26` | `#E0563F` |
| `buttonDark` | `#2B201C` | `#F4ECE5` (chữ `#1A1412`) |
| `buttonOnboarding` | `#0F0D0C` | `#F4ECE5` (chữ `#141110`) |
| `tabBar` | `rgba(251,246,241,.96)` | `rgba(26,20,18,.96)` |
| `tabInactive` | `#A89890` | `#7A6B64` |
| `avatar` / `avatarText` | `#F2C9B5` / `#8A3F1F` | `#5A3424` / `#F2C9B5` |

Quy tắc: mọi cặp chữ/nền dùng thật trong UI đạt WCAG AA (4,5:1 chữ thường, 3:1 chữ ≥ 18pt hoặc
≥ 14pt đậm) ở cả hai chế độ — có unit test (KickCore `ContrastTests`) tính tỉ lệ cho danh sách
cặp được khai báo. Cặp nào của thiết kế gốc không đạt (vd. chữ trắng trên `#E0566B`) thì dùng
biến thể đậm hơn và ghi lại trong test.

## 4. Màn hình

Số đo, khoảng cách, bo góc, màu lấy theo `docs/design/mam-handoff/README.md` (pixel-perfect ở
khổ 390×844); đây chỉ ghi phần ánh xạ và khác biệt.

### 4.1 Onboarding (thay `OnboardingView`)
- 3 bước, nền `onboardingBackground`, ảnh tràn từ trên + gradient + dải sóng, chấm tiến trình +
  "Bỏ qua", nút chính cao 60 bo 99 `buttonOnboarding`, tiêu đề 34/400.
- Bước 0 Chào mừng (`onb-baby-beige`): tiêu đề "Chào mừng đến với Luna Mom", mô tả, segmented
  Theo máy… → **Tiếng Việt / English** (đổi ngay). Câu y tế của onboarding cũ ("không thay thế bác sĩ…",
  khóa hiện có) hiển thị dưới mô tả, cỡ 13.
- Bước 1 Mục tiêu (`onb-baby-pink`): 2 thẻ (Chu kỳ kinh nguyệt / Tôi đang mang thai), nút Tiếp tục
  vô hiệu tới khi chọn.
- Bước 2a Kỳ kinh gần nhất (chưa có ảnh → gradient `cycleSoft`→nền, cùng dải sóng): lưới 7 cột
  14 ngày gần nhất (hôm nay ở cuối) + nút "Ngày khác" mở `LastPeriodPicker` hiện có cho ngày xa hơn;
  bộ chỉnh độ dài chu kỳ 21–45 (giữ phạm vi `CycleSettings`, thiết kế ghi 21–40); "Để sau" giữ như cũ.
  Lưu qua `CycleCoordinator` y như phase 3.
- Bước 2b Ngày dự sinh (`onb-baby-basket`): nút tròn −/+ đổi 1 tuần (7 ngày), chạm vào ngày (22/500)
  mở DatePicker để chỉnh chính xác, pill tuần thai (giới hạn theo `PregnancyDateInput`); link "Tính theo kỳ kinh cuối" mở `PregnancyDateForm` hiện có. "Để sau" giữ.
- "Bỏ qua" ở bước 0–1 = nhảy tới bước 2 của mục tiêu đã chọn (hoặc Mang thai nếu chưa chọn — giữ
  mặc định người dùng cũ). Không cho bỏ qua câu y tế: câu đó nằm trên bước 0 luôn hiển thị.
- Animation: reveal/kenBurns/waveRise/waveDrift/contentUp như README; Reduce Motion → fade.
- Ảnh: nén JPEG @3x ≤ 400 KB mỗi ảnh vào `Assets.xcassets` (`OnboardingWelcome`, `OnboardingGoal`,
  `OnboardingDue`), `fetus.png` → `Fetus`.

### 4.2 Hôm nay — Mong con (thay `CycleHomeView`)
- `ScreenHeader`: avatar (chữ cái đầu của "Luna" — chưa có tên người dùng), ngày hôm nay, nút lịch → tab Lịch.
- Dải 7 ngày (6 ngày trước + hôm nay, nhãn "NAY"/"TODAY"), màu theo `forecast.dayStatus`.
- Vòng chu kỳ 264: các đoạn màu theo `CyclePredictor` (kinh đã ghi/dự đoán, cửa sổ thụ thai, rụng
  trứng), marker trên vòng theo ngày hiện tại; nhãn trên + số lớn: "N ngày" tới kỳ kế (đang kinh: "Ngày N"),
  ngày dự kiến bên dưới; trễ kinh: "Trễ N ngày". Nút "Kỳ kinh bắt đầu" = `startPeriod`; ngay sau khi bấm
  nút đổi thành "Hoàn tác" trong phiên màn hình (xóa kỳ vừa tạo bằng `deletePeriod`); đang kinh: "Kỳ kinh kết thúc".
  Kỳ mở quá dài: giữ quy tắc phase 3 (nút là "Kỳ kinh bắt đầu").
- Pill pha: "Ngày N · <trạng thái>" dùng `cycleStatus` hiện có (trễ: "Kỳ kinh đang đến trễ").
- Thẻ "Hôm nay bạn thấy thế nào?" → `CycleDayLogSheet` (làm lại theo `LunaSheet`).
- Thẻ "Dự đoán sắp tới": kỳ kinh tiếp theo, rụng trứng (ẩn khi trễ), 3 số liệu: độ dài chu kỳ TB,
  số ngày kinh điển hình, "Đều"/"Chưa đều" (theo độ tin cậy/irregular). Nhãn độ tin cậy thấp giữ.
- Các thẻ cảnh báo phase 3 (trễ kinh + "Tôi đã có thai", không đều, kinh kéo dài) dạng `LunaCard`
  nền `warningBackground`/`cycleSoft`; thẻ "Có thể bạn đang mang thai?" (`pregSoft`) luôn ở cuối, mở
  `ImPregnantSheet`.
- Câu "không dùng để tránh thai" và dòng thông báo tắt giữ ở cuối.
- Trạng thái trống (chưa có kỳ kinh): thẻ mời nhập như phase 3, kiểu mới.

### 4.3 Lịch — Mong con (thay `CycleCalendarView`)
- Tiêu đề 28/700 + điều hướng tháng (nút tròn 34), lưới bắt đầu theo `firstWeekday` của locale đã chọn
  (vi: thứ Hai), ô 44/vòng 40 theo §3 của README; ngày đang chọn ring 2pt, hôm nay ring `surface`.
- Chú thích (4 mục + chấm "có ghi"), thẻ ngày đang chọn (trạng thái + tóm tắt log) + nút "Ghi chú" mở
  `CycleDayLogSheet`. Ngày tương lai: chọn được để xem, nút Ghi chú vô hiệu.
- Giữ nhãn VoiceOver từng ngày (`CycleAccessibility`) và vuốt đổi tháng.

### 4.4 Hôm nay — Mang thai (thay `PregnancyHomeView`)
- `ScreenHeader` + dải 7 ngày (chỉ số ngày, hôm nay nổi bật).
- Vòng thai nhi 270 gradient, ảnh `Fetus` 230pt lơ lửng (float), chạm → Chi tiết tuần. Chưa có ngày thai
  kỳ: trạng thái trống hiện có (mời nhập ngày), kiểu mới.
- "N tuần, D ngày" 32/700 `pregStrong`; "Tam cá nguyệt X · còn N ngày"; thanh 8pt vạch 32,5%/67,5%
  (giữ cách tính tuần/ngày hiện có, quá ngày dự sinh giữ thông báo hiện có).
- 2 lối tắt tròn 58: Đếm cử động → tab Cử động; Tuần thai → Chi tiết tuần.
- Thẻ "Cử động hôm nay" (số phiên/thời gian gần nhất hôm nay, CTA "Đếm ngay"/"Xem"), thẻ kích thước bé
  (emoji trái cây + so sánh + cân nặng Hadlock "Khoảng X (thường A–B)" hoặc CRL; ghi chú ±10–15 %, nhãn
  "Đang chờ bác sĩ duyệt" giữ), thẻ "Tuần này mẹ nên", thẻ lịch khám sắp tới (mở Lịch khám).

### 4.5 Chi tiết tuần (thay `WeekDetailView`)
- Toàn màn trượt lên, nền gradient `#EBB394→#F7DCC9→background` (tối: `#5A3424→#3A2A22→background`),
  nút ✕ 40, ảnh `Fetus` 170, `ChipScroller` tuần 4–42 tự cuộn tới tuần hiện tại, bảng bo trên 28:
  tiêu đề tuần 26/700, dòng "Người xem xét": **"Đang chờ bác sĩ duyệt"** (không có tên bác sĩ), 2 ô
  vuông (emoji bé/trái cây), câu kích thước, 2 ô số liệu (cân nặng Hadlock + khoảng / CRL), các mục
  nội dung tuần hiện có (bé phát triển, cơ thể mẹ, nên làm, dấu hiệu nguy hiểm, nguồn).

### 4.6 Cử động (thay `CounterView`)
- Tiêu đề + "Tuần N · đếm đến 10 cử động", nút "Cài đặt" (sheet: nhắc hằng ngày + giờ, rung khi chạm,
  mục tiêu 10 hiển thị cố định "Phương pháp Cardiff").
- Vùng chạm 268: 10 chấm trên bán kính 120, lõi theo trạng thái (nghỉ `preg` / đang đếm `pregStrong` /
  xong `teal`), số 72/700 + pop, "/ 10 cử động", đồng hồ mm:ss (h:mm:ss quá 1 giờ, số tabular), ripple
  mỗi lần chạm, rung 30 ms nếu bật. Nghỉ: nhãn "Chạm khi bé đạp" (chạm = 1 cử động, như hiện tại).
- Đang đếm: gợi ý, Hoàn tác (trắng) / Kết thúc (`buttonDark`), chip giờ từng cử động.
- Cảnh báo 2 giờ: thẻ `warningBackground` viền `warningBorder`, ở vi nút "Gọi cấp cứu 115" → `tel:115`;
  ở en không có nút gọi (không có số chung), chỉ hướng dẫn chữ; giữ thông báo đẩy hiện có. Chữ cảnh báo
  giữ nội dung y tế hiện có (đã duyệt hướng), chỉ đổi giao diện.
- Hoàn thành (`CompletionView`): kiểu mới, giữ nội dung.
- Biểu đồ mini 7 ngày (mở Lịch sử), thẻ Cardiff.
- Giữ id `kickButton`, `cancelSessionButton`, `undoButton`… và nhãn VoiceOver hiện có.

### 4.7 Lịch sử cử động (thay `HistoryView`, mở từ Cử động)
- `SegmentedPill` 7 ngày / 4 tuần; "Thời gian trung bình để đủ 10 cử động" 30/700; biểu đồ cột
  170pt (Swift Charts): cột hiện tại `pregStrong`, khác `pregBar`, trống `track`, đường mốc 30′ dashed,
  trục tối đa 60′ (cột > 60′ cắt ở đỉnh, ghi số); danh sách phiên (ô đếm 38, ngày, giờ, thời lượng,
  phiên hủy/chưa đủ ghi rõ); thẻ "Khi nào cần gặp bác sĩ". Xóa/sửa phiên giữ như hiện tại.
- `HistoryStats` (KickCore): trung bình thời gian đủ 10 trong 7 ngày/4 tuần, giá trị cột theo ngày/tuần.

### 4.8 Cá nhân (thay `SettingsView`)
- Avatar 60 + "Luna Mom" + chế độ hiện tại. Mục: Ngôn ngữ (3 lựa chọn), Chế độ (Mong con / Mang thai —
  quy tắc phase 3, sang Mang thai qua `ImPregnantSheet`; ở Mang thai có dòng "Kết thúc theo dõi thai kỳ"
  → sheet xác nhận → `activateTryingToConceive`, dữ liệu giữ), Ngày thai kỳ (Mang thai), Chu kỳ (Mong con:
  độ dài, số ngày kinh, nhắc chu kỳ), Nhắc đếm cử động (Mang thai), Lịch khám (Mang thai), Quyền,
  Thông tin y tế, Xem lại phần giới thiệu (mở onboarding, không xóa dữ liệu), Phiên bản.
- Giữ các id `settings…` mà test đang dùng; id mới đặt tiền tố `profile…`.

### 4.9 Sheet và màn phụ
`CycleDayLogSheet`, `LastPeriodSheet`, `ImPregnantSheet` (segmented "Theo ngày dự sinh / Theo kỳ kinh
cuối", ±1 ngày, pill tuần thai, nút "Bật chế độ mang thai"), `PregnancyDateSheet`, `AppointmentsView`
+ `AppointmentEditorSheet`, `MedicalInfoView`, `StoreErrorView`: làm lại bằng `LunaSheet`/`LunaCard`,
giữ logic và id.

## 5. Xử lý lỗi, trợ năng, chuyển động
- Lỗi lưu/đọc: alert như hiện tại (không dùng toast). Toast chỉ cho xác nhận ngắn.
- Dynamic Type đến AX5: không cắt chữ (thẻ xuống dòng, vòng giữ kích thước tối thiểu và số co lại theo
  `minimumScaleFactor`), kiểm tra bằng ảnh chụp cỡ chữ lớn nhất ở màn Hôm nay (2 chế độ) và Cử động.
- VoiceOver: dải 7 ngày (mỗi ngày một nút với nhãn kiểu `CycleAccessibility`), vòng chu kỳ ẩn + thẻ
  chữ tương ứng, vùng chạm cử động là một nút có nhãn/giá trị hiện có, chấm tiến trình onboarding đọc
  "Bước 2 trên 3".
- Reduce Motion: tắt mọi animation chuyển động, giữ fade ≤ 0,2 s.

## 6. Kiểm thử
- **KickCore (local)**: `AppLanguage` (resolve, lưu), L10n tra theo ngôn ngữ chọn, `ContrastTests`
  (mọi cặp khai báo đạt AA hai chế độ — token hex nằm trong KickCore `LunaPalette` để test được, App
  bọc thành `Color`), `WeekStrip` (7 ngày, nhãn hôm nay), `CycleRingGeometry` (góc marker, đoạn màu),
  `PregnancyProgress` (tỉ lệ ngày/280, tam cá nguyệt), `HistoryStats`, `RecentDaysGrid` (14 ngày onboarding).
- **UI test (CI)**: cập nhật mọi test cũ theo điều hướng mới; thêm: onboarding 2 nhánh (Mong con: chọn
  ngày trong lưới → Hôm nay đúng ngày chu kỳ; Mang thai: ±ngày → đúng tuần), đổi ngôn ngữ trong Cá nhân →
  nhãn tab đổi ngay, "Kỳ kinh bắt đầu" → "Hoàn tác" → trở lại, chạm vòng thai nhi → Chi tiết tuần đúng
  tuần, Lịch sử 7 ngày/4 tuần, Kết thúc thai kỳ → 3 tab Mong con.
- **Ảnh chụp**: mọi màn ở vi/en × sáng/tối với `-fixedNow`, `-seedDueDate`, `-seedCycles`; thêm
  `-seedSessions` (DEBUG + `-uiTesting`) để có lịch sử 7 ngày giống thiết kế; Dynamic Type AX5 cho 3 màn.
  Mỗi task UI: đọc ảnh và so với prototype trước khi xong.

## 7. Tài liệu và tài sản
- `docs/design/mam-handoff/` (README + prototype) là nguồn tham chiếu trong repo.
- Release checklist thêm mục phase 4 (kiểm tra animation và đổi ngôn ngữ trên máy thật qua TestFlight,
  kiểm tra quyền dùng ảnh AI).
- Ảnh còn thiếu (ghi trong checklist): ảnh onboarding "Kỳ kinh gần nhất", ảnh thai nhi theo giai đoạn,
  ảnh/icon trái cây theo tuần, app icon mới (nếu đổi), ảnh bài viết/bác sĩ (giai đoạn sau).
- Giấy phép font OFL kèm theo (`App/Fonts/OFL.txt`) và ghi trong mục "Thông tin" của Cá nhân.

## 8. Rủi ro
- Animation onboarding chỉ thấy qua TestFlight (CI chỉ có ảnh tĩnh).
- Đổi ngôn ngữ trong app: chuỗi hệ thống (alert hệ thống, hộp quyền) vẫn theo ngôn ngữ máy — chấp nhận.
- Thanh tab tùy biến: phải giữ được truy cập VoiceOver (trait `.isTabBar`, nhãn, trạng thái chọn).
- Phase 4 thay gần hết view: chia task theo màn, mỗi task tự giữ CI xanh.
