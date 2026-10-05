# Bàn giao: Mầm – Theo dõi kinh nguyệt & thai kỳ

## Tổng quan
Mầm là ứng dụng di động song ngữ (Tiếng Việt / English) cho phụ nữ, có 2 chế độ:
- **Chu kỳ**: vòng tròn ngày chu kỳ, lịch có dự đoán kỳ kinh/rụng trứng, ghi triệu chứng.
- **Thai kỳ**: tuần thai, kích thước bé (so sánh trái cây), chi tiết tuần 4–40, đếm cử động thai theo phương pháp Cardiff, cân nặng mẹ, bài viết, chia sẻ với bạn đời.

## Về các file thiết kế
Các file trong gói này là **bản tham chiếu thiết kế viết bằng HTML**: prototype thể hiện giao diện và hành vi mong muốn, **không phải code production để copy nguyên**. Nhiệm vụ là **dựng lại thiết kế trong môi trường của codebase đích** (React Native, Flutter, SwiftUI…) theo pattern và thư viện sẵn có. Nếu chưa có codebase, đề xuất: **React Native (Expo) + TypeScript**, Reanimated cho animation, i18n bằng `i18next`, lưu trữ local bằng MMKV/AsyncStorage.

Mở `Mam App.dc.html` trực tiếp trong trình duyệt để xem prototype (cần `support.js` cùng thư mục). Thanh bên trái có lối tắt tới mọi màn hình. Toàn bộ copy song ngữ, dữ liệu tuần thai, bài viết và logic nằm trong khối `<script data-dc-script>` cuối file (các hằng `T`, `FR`, `WK`, `ART`, `OPTS`, class `Component`).

## Độ trung thực
**High-fidelity.** Màu, typography, khoảng cách, bo góc, animation là bản cuối. Dựng lại pixel-perfect. Riêng các ô sọc chéo có chữ monospace (ảnh bài viết, ảnh trái cây, ảnh 3D tuần thai, avatar bác sĩ) là **placeholder ảnh**, cần thay bằng ảnh thật.

## Khung thiết bị
- Viewport thiết kế: **390 × 844** (iPhone 14/15). Status bar 50px, tab bar 82px.
- Nền app: `#FBF6F1`. Vùng nội dung cuộn giữa status bar và tab bar.
- Font: **Be Vietnam Pro** (300/400/500/600/700) cho mọi chữ.

---

## Màn hình

### 1. Onboarding (3 bước, phủ toàn màn, nền `#F4F1EC`)
Bố cục chung: ảnh tràn từ mép trên (absolute, top 0), mờ dần xuống nền kem bằng gradient `rgba(244,241,236,0) 0% → rgba(244,241,236,.85) 60% → #F4F1EC 100%` ở 45% dưới của ảnh. Mép dưới ảnh có **dải sóng** (SVG, cao 64px, màu `#F4F1EC`). Nội dung đặt ở đáy, padding ngang 24px, đáy 34px.
- **Thanh trên** (top 58px, trái/phải 24px): pill chấm tiến trình (nền `rgba(255,255,255,.7)`, padding 8×10, gap 6). Chấm cao 6px, bo 3px. Chấm hiện tại rộng 22px, chấm khác 6px. Đã qua/hiện tại màu `#141110`, chưa tới `rgba(20,17,16,.2)`. Bên phải là pill "Bỏ qua" (13px/500, padding 7×14).
- **Nút chính**: cao 60px, full width, bo 99px, nền `#0F0D0C`, chữ trắng 16px/400. Khi active thì scale .98. Bị vô hiệu (opacity .35) ở bước 2 nếu chưa chọn mục tiêu. Nhãn "Tiếp tục", bước cuối là "Bắt đầu".
- Tiêu đề: 34px/400, line-height 1.15, letter-spacing −.02em, `#141110`, text-wrap balance.

| Bước | Ảnh (chiều cao) | Nội dung |
|---|---|---|
| 0 Chào mừng | `assets/onb-baby-beige.jpg`, 78%, object-position 50% 30% | Tiêu đề + mô tả 14px/1.55 `#6B6460` (max 300px) + segmented Tiếng Việt/English (nền `rgba(20,17,16,.06)`, mục chọn nền trắng) |
| 1 Mục tiêu | `assets/onb-baby-pink.jpg`, 58%, 50% 35% | 2 thẻ lựa chọn: nền trắng, bo 20, padding 16×18, viền 1.5px (chọn: `#141110`, chưa chọn: trong suốt). Chấm 12px `#E0566B` (chu kỳ) / `#C9673E` (thai kỳ) |
| 2a Kỳ kinh gần nhất (nếu chọn chu kỳ) | **chưa có ảnh**, 46% | Lưới 7 cột 14 ngày gần nhất (chip chọn nền `#E0566B`) + bộ chỉnh độ dài chu kỳ 21–40 |
| 2b Ngày dự sinh (nếu chọn thai kỳ) | `assets/onb-baby-basket.jpg`, 62%, 50% 40% | Bộ chỉnh ngày ±7 ngày (nút tròn 42px nền `#F4F1EC`, ngày 22px/500) + pill tuần thai (`#F7E3D7` / `#9C4823`) |

**Animation onboarding** (chạy mỗi khi vào một bước, mô phỏng video tham chiếu):
- `reveal` – lớp chứa ảnh: clip-path `circle(0% at 105% 38%) → circle(150% at 105% 38%)`, 1.1s, `cubic-bezier(.65,0,.35,1)`. Ảnh lộ ra như khối tròn quét từ phải sang.
- `kenBurns` – chính ảnh: `scale(1.18) translateX(6%) → none`, 1.8s, `cubic-bezier(.2,.8,.2,1)`.
- `waveRise` – dải sóng: `translateY(70px) → 0`, 1s, trễ .25s, `cubic-bezier(.2,.8,.2,1)`.
- `waveDrift` – SVG sóng rộng 200%: `translateX(0 → -50%)`, 9s, linear, lặp vô hạn. Path: `M0 34 C100 4 300 4 400 34 C500 64 700 64 800 34 L800 64 L0 64 Z` (viewBox 800×64, preserveAspectRatio none).
- `contentUp` – khối chữ/điều khiển: `translateY(28px), opacity 0 → none, 1`, .8s, trễ .45s, `cubic-bezier(.2,.8,.2,1)`.
- Chấm tiến trình: transition width/màu .5s `cubic-bezier(.65,0,.35,1)`.
- Tôn trọng `prefers-reduced-motion`: tắt drift/ken burns, chỉ giữ fade.

### 2. Trang chủ – chế độ Chu kỳ
- **Header** (padding 6×20): avatar 38px tròn `#F2C9B5`/chữ `#8A3F1F` (mở trang Cá nhân), ngày hôm nay 16px/600 ở giữa, icon lịch bên phải.
- **Dải 7 ngày** (6 ngày trước + hôm nay): thứ 11px/600 `#9A8A82`. Số trong ô tròn 40px. Ngày kinh nền `#FBE3E6` chữ `#C2384F`. Rụng trứng nền `#CBEAE6` chữ `#1F6E67`. Dễ thụ thai chữ `#2F8C84`. Hôm nay nền trắng, đậm 700, đổ bóng `0 4px 14px rgba(150,80,50,.18)`, nhãn "NAY".
- **Vòng chu kỳ** 264px: conic-gradient theo chu kỳ: kinh `#E0566B` (ngày 1–5), nền `#F3E6E0`, cửa sổ thụ thai `#8CCFC7` (ngày rụng −5 → ngày rụng). Lõi inset 14px nền `#FBF6F1`. Nhãn trên 12px/600 uppercase. Số lớn 52px/700 `#C2384F` ("N ngày" tới kỳ kế, hoặc "Ngày N" khi đang kinh). Nút "Kỳ kinh bắt đầu" (`#E0566B`, bo 99, 14px/600), bấm lại thì Hoàn tác. Marker 22px trắng viền 3px `#2B201C` đặt trên vòng bán kính 125 theo góc ngày hiện tại.
- Pill pha chu kỳ ("Ngày 12 · Pha nang trứng"): màu theo pha.
- Thẻ "Hôm nay bạn thấy thế nào?": mở sheet ghi triệu chứng.
- Thẻ "Dự đoán sắp tới": kỳ kinh tiếp theo, rụng trứng, 3 số liệu (độ dài chu kỳ, kỳ kinh 5 ngày, "Đều").
- Thẻ "Có thể bạn đang mang thai?" (`#F7E3D7`): mở sheet chuyển chế độ.
- "Dành cho bạn": cuộn ngang thẻ bài viết 200px.

Thẻ chuẩn toàn app: nền `#fff`, bo 20px, padding 16–18px, margin ngang 20px, cách nhau 12px.

### 3. Lịch (Chu kỳ)
Tiêu đề 28px/700 + điều hướng tháng (nút tròn 34px trắng). Lưới tháng bắt đầu từ thứ Hai, ô 44px, vòng 40px. Kỳ kinh đã qua nền `#E0566B`/trắng. Kỳ kinh dự đoán (tương lai) viền 1.5px dashed `#E0566B`. Ngày dễ thụ thai `#E3F2F0`. Rụng trứng `#CBEAE6` viền `#2F8C84`. Ngày đang chọn ring 2px `#2B201C`, hôm nay ring 2px `#E8CFC4`. Dưới lưới là chú thích, rồi thẻ ngày đã chọn kèm nút "Ghi chú".

### 4. Trang chủ – chế độ Thai kỳ
- **Vòng thai nhi** 270px: `radial-gradient(circle,#FCEBDD 0%,#F6D7C2 60%,#FBF6F1 71%)`. Trong đó là `assets/fetus.png` (PNG nền trong suốt) cao 230px, drop-shadow `0 10px 18px rgba(140,60,25,.18)`, animation **float**: `translateY(0) rotate(-2deg) → translateY(-8px) rotate(2deg)`, 5s ease-in-out, lặp vô hạn. Bấm vào thì mở Chi tiết tuần. *(Hiện dùng một ảnh cho mọi tuần. Nên chuẩn bị ảnh theo giai đoạn.)*
- "N tuần, D ngày" 32px/700 `#B8572F`. Dưới là "Tam cá nguyệt X · còn N ngày".
- Thanh tiến trình 8px `#F1E2D8`, fill `#C9673E` = ngày/280. Vạch chia tam cá nguyệt tại 32.5% và 67.5%.
- 4 lối tắt tròn 58px: Đếm cử động (`#C9673E`), Triệu chứng, Cân nặng, Tuần thai.
- Thẻ "Cử động hôm nay" (CTA "Đếm ngay"/"Xem"), thẻ kích thước bé (trái cây + chiều dài + cân nặng), thẻ cân nặng mẹ kèm trạng thái (Trong khoảng `#E3F2F0`/`#1F6E67`, ngoài khoảng `#FDE8E4`/`#A3301F`).
- Dữ liệu kích thước: bảng `FR` (tuần 4–40: tên VI, tên EN, cm, g).

### 5. Chi tiết tuần (overlay, trượt lên)
Nền `linear-gradient(180deg,#EBB394 0%,#F7DCC9 38%,#FBF6F1 60%)`. Nút ✕ tròn 40px. Ảnh 3D tuần thai (placeholder) 170px. Dải chip tuần 4–40 cuộn ngang (chip chọn trắng/`#2B201C`, chip khác `rgba(255,255,255,.35)`/`#6B3A22`), tự cuộn tới tuần hiện tại. Bảng trắng bo trên 28px: tiêu đề 26px/700, "Người xem xét: BS…", 2 ảnh vuông (bé / trái cây), câu kích thước, 2 ô số liệu, 3 mục nội dung theo tam cá nguyệt (bảng `WK`).

### 6. Đếm cử động (Cardiff)
- Tiêu đề + phụ đề "Tuần N · đếm đến 10 cử động". Nút "Cài đặt". Pill nhắc nhở và gộp 5 phút.
- **Vùng chạm** 268px nền `#F7E3D7`: các chấm tiến trình (10 chấm 14px trên bán kính 120, đã đạt `#B8572F`, chưa đạt `rgba(184,87,47,.18)`). Lõi inset 30px: nghỉ `#C9673E`, đang đếm `#B8572F`, xong `#2F8C84`, bóng `0 14px 30px -12px rgba(160,70,30,.55)`, active scale .95.
  - Nghỉ: "Bắt đầu". Chạm lần đầu thì bắt đầu phiên (chưa tính cử động).
  - Đang đếm: số 72px/700 (animation `pop` .3s: scale 1→1.2→1), "/ 10 cử động", đồng hồ mm:ss (h:mm:ss nếu quá 1 giờ) chữ số tabular.
  - Mỗi lần chạm: vòng **ripple** (viền 3px trắng, scale 1→1.35, opacity .6→0, .6s ease-out), rung 30ms nếu bật.
  - Đạt mục tiêu thì tự hoàn thành và lưu phiên.
- Khi đang đếm: gợi ý, nút "Hoàn tác" (trắng) / "Kết thúc" (`#2B201C`), chip giờ từng cử động.
- **Cảnh báo ít cử động**: nếu đang đếm, quá 2 giờ và chưa đủ mục tiêu thì hiện thẻ `#FDE8E4` viền `#F3C2B8`, tiêu đề `#A3301F`, nút "Gọi bác sĩ" `#C23A26`. Bản production cần thêm **thông báo đẩy** tại mốc 2 giờ.
- Biểu đồ mini 7 ngày (mở Lịch sử), thẻ giải thích phương pháp Cardiff.

### 7. Lịch sử cử động
Segmented 7 ngày / 4 tuần. Thời gian trung bình để đủ 10 cử động (30px/700). Biểu đồ cột cao 170px (cột hôm nay/tuần này `#B8572F`, khác `#E3A584`, không có dữ liệu `#EFE6DF`), đường tham chiếu 30′ dashed `#E0A08A`, thang tối đa 60 phút. Danh sách phiên: ô đếm 38px, ngày, giờ bắt đầu–kết thúc, thời lượng. Thẻ "Khi nào cần gặp bác sĩ".

### 8. Cân nặng mẹ
Mức tăng so với trước mang thai (`PRE_KG` = 52). Biểu đồ SVG 310×170: dải khuyến nghị `#F7E3D7` (hàm `band(w)`: ≤13 tuần tăng 0.5–2 kg tuyến tính, sau đó +0.42–0.52 kg/tuần), đường người dùng `#B8572F` 2.5px. Bộ nhập ±0.1 kg, nút Lưu `#C9673E`, danh sách theo tuần.

### 9. Kiến thức / Bài viết
Chip lọc Tất cả / Chu kỳ / Thai kỳ. Thẻ ngang có ảnh 86px. Bài viết mở dạng overlay: ảnh 300px, danh mục, tiêu đề 26px/700, người xem xét, đoạn văn 15px/1.7 `#544640`. Nội dung ở `ART`.

### 10. Bạn đời
Trạng thái: chưa có → đã mời (mã `MAM-4821`, nút Sao chép) → đã kết nối. Các công tắc chia sẻ (thai kỳ: tuần thai, cử động, triệu chứng; chu kỳ: chu kỳ, triệu chứng). Thẻ tối `#2B201C` xem trước những gì bạn đời thấy, cập nhật theo công tắc.

### 11. Cá nhân
Avatar 60px, tên, chế độ. Chọn ngôn ngữ. Các dòng: chuyển/kết thúc chế độ thai kỳ, nhắc đếm cử động, xem lại phần giới thiệu.

### Bottom sheet (nền mờ `rgba(43,32,28,.38)`, sheet `#FBF6F1` bo trên 28px, tay nắm 40×5)
- **Ghi triệu chứng**: lượng kinh (chỉ chế độ chu kỳ, chọn 1), tâm trạng (nhiều), triệu chứng (nhiều, danh sách khác theo chế độ, xem `OPTS`).
- **Chuyển sang mang thai**: segmented theo ngày dự sinh / kỳ kinh cuối (dự sinh = kỳ kinh cuối + 280 ngày), chỉnh ±1 ngày, pill kết quả tuần thai.
- **Kết thúc thai kỳ**: xác nhận và quay về chế độ chu kỳ, dữ liệu vẫn giữ.
- **Cài đặt đếm cử động**: nhắc hằng ngày (giờ: 09:00/14:00/20:00/21:30), gộp cử động trong 5 phút, rung khi chạm, mục tiêu 10.

### Tab bar (82px, nền `rgba(251,246,241,.96)`, viền trên `rgba(43,32,28,.07)`)
- Chu kỳ: Hôm nay · Lịch · Kiến thức · Bạn đời.
- Thai kỳ: Hôm nay · Cử động · Kiến thức · Bạn đời.
- Tab active `#C2384F` (chu kỳ) / `#B8572F` (thai kỳ), inactive `#A89890`. Icon trong prototype là hình khối đơn giản, nên thay bằng bộ icon của codebase.

### Toast
Pill `#2B201C` chữ trắng 13px/500, top 60px, tự ẩn sau 1.9s.

---

## Tương tác & logic
- **Chu kỳ**: `cd = ((ngày từ periodStart) mod L) + 1`. Kinh: ngày 1–5. Rụng trứng: ngày `L − 14`. Cửa sổ thụ thai: ngày rụng −5 → ngày rụng. Kỳ kế = periodStart + bội số L.
- **Thai kỳ**: LMP = dự sinh − 280 ngày. Tuần = floor(ngày/7). Tam cá nguyệt: <14 → 1, <28 → 2, còn lại → 3.
- **Gộp cử động**: nếu bật, chạm trong vòng 5 phút kể từ cử động trước thì không tính thêm, có toast "Đã gộp vào cử động trước".
- **Hoàn tác** bỏ cử động cuối. **Kết thúc** lưu phiên nếu có ≥1 cử động.
- Overlay (Chi tiết tuần, Bài viết) trượt lên: `translateY(40px), opacity 0 → 1`, .28s ease. Sheet .25s.
- Đổi màn thì cuộn về đầu.
- Mọi chữ đều song ngữ. Đổi ngôn ngữ áp dụng ngay. Định dạng ngày VI "4 tháng 10", EN "Oct 4". Số thập phân VI dùng dấu phẩy.

## State (gợi ý store)
`lang`, `mode` ('period'|'preg'), `onbDone`, `onbStep`, `goalPick`, `periodStart`, `cycleLen`, `due`, `logs` (theo ngày: flow, mood[], sym[], mode), `sessions` ({start, end, count}[]), phiên đang đếm `k` ({status idle|run|done, start, taps[], end}), `remOn`, `remTime`, `mergeOn`, `hapticOn`, `weights` ({w, kg}[]), `partner` ('none'|'invited'|'connected'), `share` ({cycle, preg, kicks, sym}), cộng các state UI (screen, sheet, overlay, selWeek, calM, sel, learnF, histMode). Prototype lưu toàn bộ vào localStorage key `mam-app-v1`. Production cần lưu bền vững và đồng bộ với bạn đời ở backend.

Cấu hình: mục tiêu cử động mặc định 10 (cho phép 5–20).

## Design tokens
**Màu**
- Nền: app `#FBF6F1`, onboarding `#F4F1EC`, thẻ `#FFFFFF`, nền phụ `#F4ECE5` / `#F1E7DF`.
- Chữ: chính `#2B201C`, onboarding `#141110`, phụ `#7A6B64`, mờ `#9A8A82`, chevron `#B5A69E`, nội dung bài `#544640`.
- Chu kỳ: chính `#E0566B`, đậm `#C2384F`, nhạt `#FBE3E6`. Thụ thai `#8CCFC7` / `#E3F2F0` / `#CBEAE6`, teal `#2F8C84` / `#1F6E67`.
- Thai kỳ: chính `#C9673E`, đậm `#B8572F`, nhạt `#F7E3D7`, chữ trên nền nhạt `#9C4823`, cột phụ `#E3A584`.
- Cảnh báo: nền `#FDE8E4`, viền `#F3C2B8`, chữ `#A3301F`, nút `#C23A26`.
- Nút đen: `#0F0D0C` (onboarding), `#2B201C` (trong app).

**Typography** (Be Vietnam Pro): 52/700 (số vòng chu kỳ), 34/400 (tiêu đề onboarding), 32/700, 28/700 (tiêu đề màn), 26/700, 22/700 (tiêu đề sheet), 16–15/600 (tiêu đề thẻ), 14 (body), 13 (phụ), 12–11/600 (nhãn, uppercase letter-spacing .06–.1em).

**Bo góc**: 99px (pill/nút), 28px (sheet), 20–22px (thẻ), 18px, 14px, 12px, 50% (tròn).

**Khoảng cách**: lề màn 20px (onboarding 24px), khoảng cách thẻ 12px, padding thẻ 16–18px, khoảng cách section 22–26px.

**Bóng**: hôm nay `0 4px 14px rgba(150,80,50,.18)`, nút đếm `0 14px 30px -12px rgba(160,70,30,.55)`, toast `0 8px 20px rgba(0,0,0,.2)`.

## Assets
- `assets/onb-baby-beige.jpg`: onboarding bước 0 (ảnh do người dùng cung cấp, tạo bằng AI).
- `assets/onb-baby-pink.jpg`: onboarding bước 1.
- `assets/onb-baby-basket.jpg`: onboarding bước 2, ngày dự sinh.
- `assets/fetus.png`: thai nhi nền trong suốt, trang chủ thai kỳ.
- **Còn thiếu**: ảnh onboarding "kỳ kinh gần nhất", ảnh 3D thai nhi theo tuần, ảnh/icon trái cây theo tuần, ảnh bài viết, ảnh bác sĩ.
- Lưu ý: ảnh tạo bằng AI cần kiểm tra quyền sử dụng trước khi phát hành.

## Lưu ý y khoa
Toàn bộ nội dung y khoa (ngưỡng Cardiff 10 cử động/2 giờ, dải tăng cân, nội dung tuần thai, bài viết) và tên bác sĩ "BS. Nguyễn Thu Hà" là **nội dung mẫu**. Cần chuyên gia y tế duyệt trước khi ra mắt.

## Files
- `Mam App.dc.html`: prototype đầy đủ (giao diện + logic + dữ liệu + copy song ngữ).
- `support.js`: runtime để mở prototype trong trình duyệt (không cần port).
- `image-slot.js`: component placeholder ảnh của prototype (không cần port).
- `assets/`: ảnh dùng trong thiết kế.
