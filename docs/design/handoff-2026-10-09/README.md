# Bàn giao: Luna Mom: Onboarding mới + Dark mode mới

## Tổng quan
Luna Mom là app iOS song ngữ (Tiếng Việt / English) theo dõi chu kỳ kinh và thai kỳ. Gói này gồm:
1. **Onboarding mới**: chỉ có light mode (onboarding **không có dark mode**, kể cả khi máy đang bật dark).
2. **Các màn chính** (Hôm nay, Lịch, Cá nhân…): **light mode** giữ như hiện tại, **dark mode** đổi sang bảng màu mới (nền indigo sáng, thẻ kính trong mờ, nhấn hồng).

## Về các file thiết kế
Các file `.dc.html` là **bản tham chiếu thiết kế viết bằng HTML**, không phải code production. Nhiệm vụ là **dựng lại trong codebase hiện có của app** (SwiftUI/React Native…) theo pattern sẵn có. Mở file trực tiếp trong trình duyệt (cần `support.js` cùng thư mục) để xem.

## Độ trung thực
**High-fidelity.** Màu, chữ, khoảng cách, bo góc, animation là bản cuối. Icon trong bản HTML (☀ ▦ ●, ổ khoá vẽ bằng div) chỉ là tạm. Dùng SF Symbols / bộ icon sẵn có của app.

## Quy tắc theme
| Khu vực | Light | Dark |
|---|---|---|
| Onboarding | ✅ | ❌ luôn dùng light (`.preferredColorScheme(.light)` hoặc tương đương) |
| Màn chính (tab Hôm nay, Lịch, Cá nhân, sheet, overlay) | Bảng màu hiện tại (xem `Mam App.dc.html` + phần Token Light) | Bảng màu mới (xem `Mam Dark Mode.dc.html` + phần Token Dark) |

Mọi màu nên đi qua token ngữ nghĩa (`bg`, `surface`, `textPrimary`, `accent`…) có giá trị light/dark, không hard-code.

---

## 1. Onboarding (light only): `Luna Mom Onboarding.dc.html`

Viewport 390 × 844. Font **Be Vietnam Pro**. Nền màn `#FFFAF2` (kem, trùng màu nền ảnh minh hoạ). Padding màn: ngang 24px, đáy 34px. Bố cục cột: ảnh (absolute) → khoảng trống co giãn → khối chữ → nút.

### Thanh trên (absolute, top 56px, trái/phải 24px)
- **Chấm tiến trình**: pill nền `rgba(255,255,255,.85)`, padding 8×10, gap 5. 8 chấm cao 6px bo 3px. Chấm hiện tại rộng 20px màu `#B4583A`, chấm khác 6px màu `#E3D6CC`.
- Màn 1: bên phải là segmented **VI / EN** (pill nền `rgba(255,255,255,.85)`, padding 3; mục 12px/600, padding 6×11; mục chọn nền `#B4583A` chữ trắng, mục khác chữ `#3A2A24`).
- Màn 2 trở đi: trái là nút back tròn 40px (nền `rgba(255,255,255,.85)`, "‹" 22px), giữa là chấm, phải là "Bỏ qua" (13px/500, padding 9×14, pill cùng nền).

### Vùng ảnh
- Ảnh hiển thị **trọn vẹn, không crop**: `object-fit: contain`, `object-position: 50% 0%`.
- Màn 1: top 96px, cao 340px, ảnh `assets/luna-goal-s.png` (mẹ bế bé trên thảm).
- Màn 2: top 100px, cao 320px, ảnh `assets/luna-due-s.png` (mẹ với quyển sách).
- 16% dưới của vùng ảnh có gradient `rgba(255,250,242,0) → #FFFAF2`.
- Mép dưới có **dải sóng** cao 56px màu `#FFFAF2` (SVG viewBox 800×64, `preserveAspectRatio=none`, rộng 200%). Path: `M0 34 C100 4 300 4 400 34 C500 64 700 64 800 34 L800 64 L0 64 Z`.

### Màn 1: Chào mừng
- Khối chữ: gap 14, padding-bottom 20.
  - Tiêu đề 32px/400, line-height 1.15, letter-spacing −.02em, `#3A2A24`, text-wrap balance.
  - Mô tả 15px/1.5 `#7A6B64`.
  - 2 dòng cam kết (gap 8; mỗi dòng: icon tròn 24px + chữ 13px/1.4 `#5E504A`, gap 10):
    - Quyền riêng tư: icon ổ khoá màu `#5E7A5A` trên nền `#E6EDE3`.
    - Lưu ý y khoa: "!" 12px/700 `#B4583A` trên nền `#F7E3D7`.
- Nút chính "Bắt đầu": cao 58px, full width, bo 99, nền `#B4583A`, chữ `#FFFAF2` 16px/500. Nhấn: scale .98.
- Link "Khôi phục từ bản sao lưu": căn giữa, cách nút 14px, 13px/500 `#8E5A43`, không gạch chân.

### Màn 2: Mục tiêu
- Tiêu đề 26px/400 (cùng style màn 1), một dòng.
- 3 thẻ lựa chọn, gap 8: padding 9×14, bo 18, gap 12, transition .25s.
  - Icon tròn 36px nền nhạt + chấm 12px màu chính.
  - Tiêu đề 16px/500, phụ đề 13px/1.4 `#7A6B64`.
  - Radio 22px: chưa chọn viền 1.5px `#DCCFC6`; đã chọn viền 7px màu chính.
  - Chưa chọn: nền `rgba(255,255,255,.6)`, viền trong suốt. Đã chọn: nền `#fff`, viền 1.5px màu chính.

| Lựa chọn | Màu chính | Nền nhạt |
|---|---|---|
| Theo dõi chu kỳ | `#E0566B` | `#FBE3E6` |
| Mong con | `#4FA79E` | `#DDF0EC` |
| Đang mang thai | `#D9824F` | `#F7E3D7` |

- Nút "Tiếp tục": chưa chọn thì nền `#EFE4DA` chữ `#B5A69E` (disabled); đã chọn thì nền `#B4583A` chữ `#FFFAF2`. Transition .3s.

### Copy (song ngữ, giữ nguyên)
| Key | VI | EN |
|---|---|---|
| welcome | Chào mừng đến với Luna Mom | Welcome to Luna Mom |
| welcomeSub | Theo dõi chu kỳ và đồng hành cùng bạn qua từng tuần thai kỳ. | Track your cycle and get week-by-week support through pregnancy. |
| privacy | Dữ liệu chỉ lưu trên iPhone. Không tài khoản, không quảng cáo. | Data stays on this iPhone. No account, no ads. |
| medical | Không thay thế bác sĩ. Bé cử động ít bất thường? Gọi bác sĩ ngay. | Not a substitute for a doctor. Fewer kicks than usual? Call your doctor. |
| start / restore | Bắt đầu / Khôi phục từ bản sao lưu | Get started / Restore from backup |
| goalQ | Bạn muốn theo dõi điều gì? | What would you like to track? |
| goals | Theo dõi chu kỳ: Dự đoán kỳ kinh, hiểu cơ thể mình · Mong con: Biết ngày rụng trứng và ngày dễ thụ thai · Đang mang thai: Theo dõi từng tuần và cử động của bé | Track my cycle: Predict periods, understand your body · Trying to conceive: Know your ovulation and fertile days · Pregnant: Follow each week and baby’s movements |
| continue / skip | Tiếp tục / Bỏ qua | Continue / Skip |

### Animation (chạy mỗi khi vào một bước)
- **reveal** (lớp chứa ảnh): clip-path `circle(0% at 105% 38%) → circle(150% at 105% 38%)`, 1.1s, `cubic-bezier(.65,0,.35,1)`.
- **kenBurns** (ảnh): `scale(1.18) translateX(6%) → identity`, 1.8s, `cubic-bezier(.2,.8,.2,1)`.
- **waveRise** (dải sóng): `translateY(70px) → 0`, 1s, trễ .25s.
- **waveDrift** (SVG sóng): `translateX(0 → −50%)`, 9s linear, lặp vô hạn.
- **contentUp** (khối chữ): `translateY(28px) + opacity 0 → 0, 1`, .8s, trễ .45s. Nút trễ .6s, link trễ .7s.
- Bật Reduce Motion thì tắt drift và Ken Burns, chỉ giữ fade.

### Các bước onboarding còn lại (bước 3–8)
Mới chốt 2 màn trên. Các bước sau dùng **cùng khung**: thanh trên, ảnh minh hoạ cùng phong cách, sóng, khối chữ ở đáy, nút `#B4583A`. Thẻ/ô nhập nền trắng bo 18, chữ `#3A2A24`/`#7A6B64`. Nội dung từng bước lấy theo flow hiện tại của app. Tham khảo thêm phần Onboarding trong `Mam App.dc.html` (chọn kỳ kinh gần nhất, độ dài chu kỳ, ngày dự sinh), nhưng **áp style mới ở trên** thay cho nền/nút đen cũ.

---

## 2. Màn chính: Light mode: `Mam App.dc.html`
Giữ đúng giao diện light hiện tại. File prototype đầy đủ (Hôm nay chu kỳ/thai kỳ, Lịch, Chi tiết tuần, Đếm cử động, Lịch sử, Cân nặng, Kiến thức, Bạn đời, Cá nhân, các sheet) để tham chiếu bố cục, logic và token light. Logic, dữ liệu và copy nằm trong `<script data-dc-script>` cuối file.

**Token Light chính**: nền `#FBF6F1`, thẻ `#FFFFFF` bo 20, chữ `#2B201C` / phụ `#7A6B64` / mờ `#9A8A82`, kỳ kinh `#E0566B` (đậm `#C2384F`, nhạt `#FBE3E6`), thụ thai `#8CCFC7` / `#E3F2F0` / `#CBEAE6`, teal chữ `#1F6E67`, thai kỳ `#C9673E` / `#B8572F` / `#F7E3D7`.

---

## 3. Màn chính: Dark mode mới: `Mam Dark Mode.dc.html`
Thay toàn bộ dark mode cũ (nền gần đen `#1B1614`, thẻ nâu). Bố cục mọi màn **giữ nguyên như light**, chỉ đổi màu và vật liệu. File mẫu có 3 màn Hôm nay, Lịch, Cá nhân. Các màn khác (sheet, overlay, Cử động, Kiến thức…) áp cùng bảng mapping dưới đây.

### Nền màn hình
- `linear-gradient(165deg, #5E6392 0%, #4E5481 45%, #474C72 100%)`.
- 1–2 quầng sáng trang trí (không bắt buộc): vòng tròn 300–320px `radial-gradient(circle, rgba(247,166,180,.22–.28), transparent 70%)` ở góc trên. Màn Hôm nay có thêm một quầng `rgba(161,230,232,.16)` ở góc dưới trái.
- Phương án thay thế (Tweaks trong file): Lavender `#7176A6 → #62679A → #585D87` (sáng hơn), Dusk `#5A5E8C → #4B4F7A → #3E4266` (trầm hơn). **Mặc định: Indigo.**

### Bảng mapping Light → Dark
| Token | Light | Dark mới |
|---|---|---|
| bg | `#FBF6F1` | gradient Indigo ở trên |
| surface (thẻ) | `#FFFFFF` | `rgba(255,255,255,.09)` + viền 1px `rgba(255,255,255,.14)`, bo 24 |
| surfaceSunken (segmented, stepper, track) | `#F4ECE5` | `rgba(20,22,48,.28)` |
| divider | `rgba(43,32,28,.07)` | `rgba(255,255,255,.10)` |
| textPrimary | `#2B201C` | `#F5F4FB` |
| textSecondary | `#7A6B64` | `#C9CBE3` |
| textTertiary / inactive | `#9A8A82` / `#A89890` | `#DCDDF0` (icon/nhãn tab chưa chọn) |
| accent (nút chính, toggle bật, ngày kinh, mục segmented đã chọn) | `#E0566B` | `#F49CAB`, chữ trên nút `#3A2340` |
| accentText (chữ hồng trên nền tối) | `#C2384F` | `#F7A6B4` (số lớn, link) / `#FFC4CE` (chip, tab đang chọn) |
| accentSoft (chip pha, nút phụ, tab đang chọn) | `#FBE3E6` | `rgba(247,166,180,.18–.22)` + viền `rgba(247,166,180,.30–.35)` |
| alert card | `#FBE3E6` | `linear-gradient(135deg, rgba(247,166,180,.26), rgba(247,166,180,.12))` + viền `rgba(247,166,180,.32)`, tiêu đề `#FFC4CE` |
| fertile / ovulation | `#8CCFC7` / `#CBEAE6` | `#A1E6E8`; nền ngày thụ thai `rgba(161,230,232,.3)`; rụng trứng viền 2px `#A1E6E8` |
| ring track | `#F3E6E0` | `rgba(255,255,255,.12)` |
| avatar | `#F2C9B5` / `#8A3F1F` | nền `rgba(247,166,180,.22)`, viền `rgba(247,166,180,.35)`, chữ `#FFD3DA` |
| toggle tắt | (hệ thống) | track `rgba(20,22,48,.35)`, núm `#DCDDF0` |

### Chi tiết từng màn mẫu
- **Hôm nay**: dải 7 ngày (ô 40px; hôm nay nền `#F49CAB` chữ `#3A2340`). Vòng chu kỳ 300px, nét 16px bo tròn đầu (track, đoạn kinh `#F49CAB`, cửa sổ thụ thai `#A1E6E8` opacity .85). Lõi vòng inset 26px nền `rgba(255,255,255,.07)` viền `.12`. Nhãn "KỲ KINH" 12px/600 tracking .14em `#C9CBE3`. "Ngày 1" 60px/700 `#F7A6B4`. Ngày 15px `#DCDDF0`. Nút "Kỳ kinh kết thúc" padding 12×26 nền `#F49CAB` chữ `#3A2340` 16px/600, bóng `0 10px 24px -8px rgba(244,156,171,.6)`. Thẻ "Hôm nay bạn thấy thế nào?" có nút + tròn 44px nền `#F49CAB`.
- **Lịch**: tiêu đề 32px/700. Nút tháng tròn 36px nền `rgba(255,255,255,.1)`. Lưới trong thẻ kính bo 28. Hôm nay/kỳ kinh nền `#F49CAB` chữ `#3A2340` + ring `0 0 0 3px rgba(255,255,255,.5)`. Dự đoán: viền 1.5px dashed `#F7A6B4`, chữ `#FFC4CE`. Nút "Ghi chú" dạng accentSoft.
- **Cá nhân**: avatar 60px. Segmented (Ngôn ngữ, Mục tiêu): track surfaceSunken, mục chọn nền `#F49CAB` chữ `#3A2340` 14px/600. Stepper −/+ 44×34. Toggle 50×30. Giá trị chọn ("Bao cao su") `#F7A6B4`.

### Tab bar (dark)
Pill nổi, căn giữa, cách đáy 26px, padding 6, gap 4. Nền `rgba(58,62,98,.72)` + **background blur 20** (iOS: `.ultraThinMaterial` phủ tint indigo), viền `rgba(255,255,255,.16)`, bóng `0 16px 32px -12px rgba(10,10,30,.5)`. Mỗi tab rộng 88, padding 8, nhãn 11px. Tab chọn: nền `rgba(247,166,180,.22)`, màu `#FFC4CE`, 600. Tab khác: `#DCDDF0`, 500.

### Vật liệu kính
Nếu hiệu năng cho phép, thẻ có thể thêm `backdrop blur ~20` để giống mẫu tham chiếu. Không bắt buộc, vì nền gradient đã đủ hiệu ứng trong mờ. Tab bar thì **bắt buộc** blur vì nội dung cuộn bên dưới.

### Độ tương phản
`#F5F4FB` và `#C9CBE3` trên nền `#474C72`–`#5E6392` đạt ≥ 4.5:1. Không dùng chữ có alpha thấp hơn mức này.

---

## Typography
**Be Vietnam Pro** 400/500/600/700 cho mọi chữ (cả hai theme). Thang chữ giữ như bản light hiện tại.

## Assets
- `assets/luna-goal-s.png`: onboarding màn 1 (bản tối ưu kích thước). Bản gốc độ phân giải cao là `assets/luna-goal.png`.
- `assets/luna-due-s.png`: onboarding màn 2 (gốc: `assets/luna-due.png`).
- `assets/fetus.png`, `onb-baby-*.jpg`: dùng trong `Mam App.dc.html` (tham chiếu cũ).
- Ảnh do người dùng cung cấp. Kiểm tra quyền sử dụng trước khi phát hành.

## Files
- `Luna Mom Onboarding.dc.html`: onboarding mới (light only), 2 màn đã chốt.
- `Mam Dark Mode.dc.html`: dark mode mới: Hôm nay, Lịch, Cá nhân + bảng màu.
- `Mam App.dc.html`: prototype đầy đủ các màn chính ở light mode (bố cục, logic, copy).
- `support.js`, `image-slot.js`: runtime để mở file HTML (không cần port).
