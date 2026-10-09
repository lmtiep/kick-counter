# Checklist trước khi phát hành

## Cấu hình (một lần)
- [ ] Task 0 đã xong: identifiers, app record, API key (Admin), secrets trên GitHub.
- [ ] CloudKit Console (icloud.developer.apple.com) — bản TestFlight/App Store dùng CloudKit
      **Production**, môi trường này không tự tạo record type; không có Xcode trên máy này nên
      không có bản build ký development để tạo record type trực tiếp. Cách làm:
      - Trên một Mac có Xcode: chạy một bản build ký development trên thiết bị thật, tạo một
        lượt đếm cử động (kick session) và một lịch hẹn (appointment) để SwiftData tự sinh đúng các
        record type (`CD_KickSession`, `CD_Kick`, `CD_Appointment`) trong Development, kiểm tra trong
        CloudKit Console, rồi **Deploy Schema Changes** từ Development lên Production.
      - **Không** tự tạo record type bằng tay: cách NSPersistentCloudKitContainer/SwiftData lưu quan
        hệ và các field hệ thống (vd. `CD_entityName`) dễ bị đoán sai, mà field đã deploy lên
        Production thì không xóa hay đổi kiểu được — một field sai sẽ làm hỏng đồng bộ vĩnh viễn.
        Nếu buộc phải làm tay, đối chiếu tài liệu Apple "Reading CloudKit Records for Core Data"
        trước khi deploy.
      Cho tới khi schema được deploy lên Production, bộ test thủ công đồng bộ hai máy (v1 và
      Giai đoạn 2, bên dưới) **sẽ thất bại như dự kiến**.
- [ ] Icon 1024×1024 trong `App/Assets.xcassets/AppIcon.appiconset` (không trong suốt, không bo góc) —
      hiện là icon tạm (trái tim trắng trên nền san hô), cần thay bằng icon thiết kế thật trước khi phát hành App Store.

## Kiểm thử thủ công trên iPhone thật qua TestFlight (ngôn ngữ vi và en)
- [ ] Onboarding hiện lần đầu, không hiện lại sau khi đồng ý.
- [ ] Chạm lần đầu → hỏi quyền thông báo; Live Activity xuất hiện trên màn hình khóa.
- [ ] Khóa máy, bấm "+1" trên màn hình khóa 3 lần → số đếm tăng; mở app thấy đúng số.
- [ ] Dynamic Island (iPhone 14 Pro trở lên): compact hiện "n/10"; nhấn giữ hiện nút "+1".
- [ ] Đủ 10 lần từ màn hình khóa → Live Activity hiện "Xong!" và tự biến mất sau ~15 phút; mở app thấy lượt trong Lịch sử.
- [ ] Bắt đầu một lượt và để quá 2 giờ → nhận thông báo cảnh báo; banner hiện trong app; Live Activity hiện dòng cảnh báo.
- [ ] Nhắc hằng ngày: đặt giờ sau 2 phút → nhận thông báo.
- [ ] Từ chối quyền thông báo → app vẫn đếm được; Cài đặt hiện mục Quyền.
- [ ] Tắt Live Activities trong Settings → app vẫn đếm; Cài đặt hiện dòng nhắc.
- [ ] Buộc tắt app khi đang đếm → mở lại thấy lượt đang đếm còn nguyên.
- [ ] Hai máy cùng Apple ID: lượt hoàn thành trên máy A hiện trong Lịch sử máy B.
      (Dự kiến thất bại cho tới khi schema CloudKit được deploy lên Production — xem mục "Cấu hình".)
- [ ] Bắt đầu một lượt rồi bỏ đó; mở lại app sau hơn 8 giờ → không có Live Activity mới; sau hơn 12 giờ → lượt cũ hiện "Đã hủy", bấm tiếp bắt đầu lượt mới.
- [ ] Đủ 10 lần rồi mở app ngay (trong 15 phút) → Live Activity "Xong!" vẫn còn trên màn hình khóa.
- [ ] Chế độ tối, Dynamic Type lớn nhất, VoiceOver đọc "Ghi nhận cử động, đã có n trên 10 cử động".

## App Store Connect
- [ ] Danh mục: Health & Fitness.
- [ ] App Privacy: "Data Not Collected".
- [ ] Mô tả có câu miễn trừ y tế (dùng nội dung `medical.body`).
- [ ] Ảnh chụp màn hình vi + en: lấy từ `ci-artifacts/screenshots/` hoặc chụp trên máy thật.
- [ ] Ghi chú cho reviewer: cách thử Live Activity (chạm một lần trong app rồi khóa máy).

## Giai đoạn 2 — Hành trình thai kỳ

### Trước khi gửi App Store
- [ ] Bác sĩ sản khoa đã duyệt `Packages/KickCore/Sources/KickCore/Resources/pregnancy-content.json`;
      mỗi tuần/mốc đã duyệt được đổi `reviewed` thành `true` (commit riêng, ghi tên người duyệt và ngày duyệt trong commit message).
      `scripts/test-core.sh` xanh sau khi đổi.
- [ ] Checklist chi tiết cho bác sĩ (14 điểm cần quyết định y khoa, cách duyệt nội dung): [`docs/content-review-for-doctor.md`](content-review-for-doctor.md).
- [ ] Không còn mục chưa duyệt — lệnh sau in ra `[] []`:
      `python3 -c "import json;d=json.load(open('Packages/KickCore/Sources/KickCore/Resources/pregnancy-content.json'));print([w['week'] for w in d['weeks'] if not w['reviewed']],[m['id'] for m in d['milestones'] if not m['reviewed']])"`
- [ ] Bản build gửi App Store Review **không** bật `CONTENT_PREVIEW` — kiểm tra bằng
      `LunaContentPreview = NO` trong Info.plist của bản build / trong App Store Connect build
      metadata. Chạy TestFlight với `content_preview=true` (workflow_dispatch input, mặc định
      `false`) **chỉ** để thử nội bộ/cho bác sĩ: `gh workflow run testflight.yml -f content_preview=true`.
      Bản gửi lên App Store Review phải được tải lên với `content_preview=false` (giá trị mặc định).
- [ ] CloudKit Console: record type `CD_Appointment` có trong Development (sinh tự động theo cách
      ở mục "Cấu hình" phía trên, sau khi một lịch hẹn đã được lưu từ bản build ký development), rồi
      **Deploy Schema Changes** lên Production — làm cùng lần với bước deploy schema của v1.
- [ ] Ảnh chụp App Store mới cho tab Thai kỳ (vi + en): `ci-artifacts/screenshots/pregnancy-home-24-*`, `week-article-*` (thay `week-24-*` từ giai đoạn 6), `knowledge-*` (giai đoạn 7, khi đã có bài được duyệt), `appointments-*`.
- [ ] Ghi chú phát hành: tab Thai kỳ; nội dung bé + mẹ tuần 4–42; lịch khám có nhắc trước 1 ngày; nhập ngày dự sinh hoặc ngày đầu kỳ kinh cuối.

### Kiểm thử thủ công trên iPhone qua TestFlight (vi và en)
- [ ] TestFlight hiện build number bằng số run của workflow TestFlight (không còn "1").
- [ ] Chạy bản TestFlight này với `content_preview=true`: tuần chưa duyệt hiện nhãn "Nội dung đang
      chờ bác sĩ duyệt" (chứng tỏ `CONTENT_PREVIEW` có hiệu lực trên bản Release) và
      `LunaContentPreview = YES` trong Info.plist của bản build.
- [ ] Cài mới: onboarding bước 4 nhập kỳ kinh cuối → tab Thai kỳ hiện đúng tuần + ngày, tam cá nguyệt, số ngày còn lại; "Để sau" → màn mời nhập ngày.
- [ ] Người dùng v1 đã có ngày dự sinh: cập nhật app → tab Thai kỳ hiện đúng tuần, không phải nhập lại.
- [ ] Cài đặt → Thai kỳ: đổi giữa ngày dự sinh/kỳ kinh cuối; "Xóa thông tin thai kỳ" → tab Thai kỳ về màn mời nhập, tab Đếm mất dòng tuần.
- [ ] Chi tiết tuần: vuốt trái/phải từ tuần 4 đến 42; mục "Khi nào cần đi khám ngay" màu cam.
- [ ] Thêm lịch hẹn cho ngày kia → 9:00 sáng mai nhận thông báo "Ngày mai mẹ có lịch khám" kèm tên lịch hẹn.
- [ ] Lịch hẹn trong quá khứ lưu được, nằm trong "Đã qua", không có thông báo.
- [ ] Đánh dấu đã khám hoặc xóa một lịch hẹn có nhắc → không còn nhận thông báo của nó.
- [ ] Từ chối quyền thông báo → vẫn lưu lịch hẹn; màn Lịch khám hiện dòng nhắc bật thông báo.
- [ ] Hai máy cùng Apple ID: lịch hẹn thêm trên máy A hiện trên máy B sau khi mở app, và máy B cũng nhắc.
      (Dự kiến thất bại cho tới khi schema CloudKit được deploy lên Production — xem mục "Cấu hình".)
- [ ] Từ tuần 28: thẻ "Đếm cử động thai hôm nay" chuyển sang tab Đếm.
- [ ] Dynamic Type lớn nhất: thẻ không bị cắt chữ; VoiceOver đọc mỗi thẻ thành một câu (tên loại quả chỉ đọc một lần, qua dòng tiêu đề; emoji được ẩn).
- [ ] Thông tin y tế → "Nguồn tham khảo" liệt kê đủ nguồn.

## Giai đoạn 3 — Chế độ "Mong con"

### Trước khi gửi App Store
- [ ] CloudKit Console: record type `CD_PeriodEntry` và `CD_CycleLog` có trong Development. Cách sinh
      (như mục "Cấu hình"): trên một Mac có Xcode, chạy bản build **ký development** trên thiết bị thật
      đăng nhập iCloud, chọn chế độ Mong con, ghi một kỳ kinh và một log ngày (có LH, BBT, dịch nhầy,
      ghi chú) để SwiftData tự sinh đủ field (`CD_id`, `CD_startDate`, `CD_endDate`, `CD_day`,
      `CD_lhRaw`, `CD_bbtCelsius`, `CD_mucusRaw`, `CD_note`); kiểm tra trong CloudKit Console rồi
      **Deploy Schema Changes** lên Production — cùng lần với `CD_KickSession`, `CD_Kick`,
      `CD_Appointment` nếu chưa deploy. **Không** tạo record type bằng tay.
- [ ] Bác sĩ sản khoa đã duyệt các chuỗi y tế mới — mục 6 của
      [`docs/content-review-for-doctor.md`](content-review-for-doctor.md); sửa chuỗi bằng
      `scripts/add-strings.py --remove <khóa>` rồi thêm lại bản đã duyệt.
- [ ] Ảnh chụp App Store cho chế độ Mong con (vi + en): `ci-artifacts/screenshots/cycle-home-fertile-*`,
      `calendar-fertile-*`, `day-log-*`, `onboarding-mode-*`.
- [ ] Mô tả App Store có câu: dự đoán chỉ là ước tính, không dùng để tránh thai (nội dung `medical.ttc.body`).
- [ ] Ghi chú phát hành: chế độ Mong con (theo dõi kỳ kinh, dự đoán rụng trứng và cửa sổ thụ thai,
      que thử LH và nhiệt độ BBT, lịch tháng, nhắc lúc 9:00, nút "Tôi đã có thai"); đổi chế độ trong Cài đặt.

### Kiểm thử thủ công trên iPhone qua TestFlight (vi và en)
- [ ] Cài mới: onboarding → "Mong con" → nhập ngày đầu kỳ kinh → tab Chu kỳ hiện đúng "Ngày N của chu kỳ";
      chỉ có 3 tab Chu kỳ · Lịch · Cài đặt. "Để sau" → màn mời nhập kỳ kinh.
- [ ] Người dùng giai đoạn 2 cập nhật app: vẫn ở chế độ mang thai với 4 tab, không phải chọn lại.
- [ ] Ghi kỳ kinh lần đầu → hỏi quyền thông báo một lần; mở lại app không hỏi lại.
- [ ] Ghi que thử LH dương tính hôm nay → ngày rụng trứng trên thẻ đổi thành ngày mai.
- [ ] Ghi BBT 9 ngày liền theo quy tắc 3-trên-6 → nhãn "Đã xác nhận rụng trứng qua nhiệt độ".
- [ ] Nhập BBT 34 hoặc 39 → báo lỗi, không lưu; nhập "36,5" (dấu phẩy) → lưu được.
- [ ] Ghi kỳ kinh trùng/chồng lên kỳ đã có hoặc ở ngày tương lai → bị chặn có thông báo.
- [ ] Đặt độ dài chu kỳ để nhắc rơi vào ngày mai → 9:00 nhận "2 ngày nữa vào cửa sổ thụ thai" / "Ngày mai có thể đến kỳ kinh";
      để trễ 3 ngày → nhận "Kỳ kinh đã trễ 3 ngày" một lần.
- [ ] Tắt "Nhắc chu kỳ" → không còn thông báo chu kỳ; bật lại → có lại.
- [ ] Từ chối quyền thông báo → vẫn ghi được; tab Chu kỳ và Cài đặt hiện dòng nhắc bật thông báo.
- [ ] Trễ kinh ≥ 3 ngày → thẻ gợi ý thử thai + "Tôi đã có thai" → sheet điền sẵn kỳ kinh cuối → Lưu →
      4 tab, tab Thai kỳ đúng tuần; không còn thông báo chu kỳ; Cài đặt → "Mong con" → dữ liệu chu kỳ còn nguyên.
- [ ] Cài đặt: Mang thai → Mong con giữ ngày dự sinh, lịch hẹn và nhắc lịch hẹn.
- [ ] Hai máy cùng Apple ID: kỳ kinh và log ghi trên máy A hiện trên máy B; ghi cùng một ngày trên hai máy
      khi offline rồi bật mạng → chỉ còn một kỳ kinh / một log mỗi ngày.
      (Dự kiến thất bại cho tới khi schema CloudKit được deploy lên Production.)
- [ ] Tab Lịch: vuốt trái/phải đổi tháng; thứ đầu tuần theo ngôn ngữ (vi: thứ Hai, en: Chủ nhật);
      VoiceOver đọc từng ô ("12 tháng 10, cửa sổ thụ thai, đã ghi que thử dương tính").
- [ ] Chế độ tối, Dynamic Type lớn nhất: thẻ chu kỳ và ô lịch không bị cắt chữ.

## Giai đoạn 4 — Giao diện "Mầm" (Luna Mom)

### Lệch chuẩn nền tảng iOS 26 (so với bản thiết kế)
- [ ] Thanh tab là khối kính nổi (floating glass capsule) của hệ thống, không phải thanh nền kem đặc
      như bản thiết kế — `TabView` hệ thống trên iOS 26 không cho vẽ nền đặc tùy biến.
- [ ] Nhãn tab không chọn dùng màu nhãn hệ thống (system label color), không phải token màu riêng —
      Apple không cho tùy biến màu nhãn tab không chọn trên iOS 26.
- [ ] Tab đang chọn dùng màu theo chế độ (Mong con / Mang thai) như thiết kế.

### Trước khi gửi App Store
- [ ] Quyền dùng ảnh: `onb-baby-beige`, `onb-baby-pink`, `onb-baby-basket`, `fetus.png` (ảnh tạo bằng AI do
      người dùng cung cấp) — xác nhận được phép dùng thương mại trước khi phát hành.
- [ ] Giấy phép font: `App/Fonts/OFL.txt` có trong app (Cá nhân → "Phông chữ: Be Vietnam Pro").
- [ ] Bác sĩ đã duyệt các chuỗi y tế mới — mục 7 của
      [`docs/content-review-for-doctor.md`](content-review-for-doctor.md).
- [ ] Ảnh chụp App Store mới (vi + en, sáng): `onboarding-welcome-*`, `cycle-home-fertile-*`,
      `pregnancy-home-24-*`, `kicks-running-*`, `history-week-*`.
- [ ] Ghi chú phát hành: giao diện mới, đổi ngôn ngữ ngay trong app, rung khi đếm cử động, 3 tab mỗi chế độ
      (Lịch sử nằm trong Cử động, Cài đặt thành Cá nhân).

### Ảnh còn thiếu (giai đoạn sau)
- [ ] Ảnh onboarding "Kỳ kinh gần nhất" (hiện là gradient hồng).
- [ ] Ảnh thai nhi theo giai đoạn (hiện một ảnh cho mọi tuần).
- [ ] Ảnh / icon trái cây theo tuần (hiện emoji).
- [ ] App icon mới (nếu đổi).
- [ ] Ảnh bài viết, ảnh bác sĩ (khi có Kiến thức / người duyệt có tên).

### Kiểm thử thủ công trên iPhone qua TestFlight (vi và en; CI chỉ có ảnh tĩnh)
- [ ] Onboarding: ảnh lộ ra theo vòng tròn từ phải, Ken Burns, dải sóng dâng lên rồi trôi chậm, chữ trượt lên;
      chấm tiến trình đổi độ dài mượt. Bật Reduce Motion → chỉ còn mờ dần.
- [ ] Đổi Tiếng Việt / English ở bước 1 → chữ đổi ngay; chọn mục tiêu → "Tiếp tục" sáng lên; "Bỏ qua" → bước cuối.
- [ ] Thai nhi ở Hôm nay lơ lửng nhẹ; tắt khi Reduce Motion.
- [ ] Đếm cử động: mỗi lần chạm có số nảy, vòng gợn và rung nhẹ; tắt "Rung khi chạm" → hết rung.
- [ ] Đổi ngôn ngữ trong Cá nhân → mọi tab, ngày ("4 tháng 10" / "Oct 4"), số ("36,5" / "36.5"), lịch
      (thứ Hai / Chủ nhật đầu tuần) đổi ngay; Live Activity và widget đổi theo; nhắc đã hẹn (đếm hằng ngày,
      chu kỳ, lịch khám, cảnh báo 2 giờ của lượt đang đếm) đến bằng ngôn ngữ mới.
- [ ] Hộp quyền hệ thống vẫn theo ngôn ngữ máy (chấp nhận, spec §8).
- [ ] VoiceOver: thanh tab đọc tên tab và trạng thái chọn; dải 7 ngày đọc từng ngày; vòng chu kỳ đọc thành chữ;
      vùng chạm đếm là một nút "Ghi nhận cử động, đã có N trên 10"; chấm onboarding đọc "Bước 2 trên 3".
- [ ] Dynamic Type lớn nhất: Hôm nay (2 chế độ) và Cử động không cắt chữ.
- [ ] Chế độ tối: mọi màn đọc rõ (bảng màu tối suy ra, spec §3).
- [ ] Cảnh báo 2 giờ (đặt giờ máy hoặc để lượt đếm chạy): ở tiếng Việt nút "Gọi cấp cứu 115" mở cuộc gọi 115;
      ở tiếng Anh không có nút; thông báo đẩy 2 giờ vẫn đến.
- [ ] Cá nhân → "Kết thúc theo dõi thai kỳ" → về Mong con, dữ liệu thai kỳ và lịch khám còn; "Xem lại phần giới
      thiệu" không xóa gì.

## Giai đoạn 5 — Ghi triệu chứng & Cân nặng mẹ

### Trước khi gửi App Store
- [ ] CloudKit Console: field mới của `CD_CycleLog` — `CD_flowRaw`, `CD_moodsRaw`, `CD_symptomsRaw` — và record
      type mới `CD_WeightEntry` (`CD_id`, `CD_day`, `CD_kg`) có trong Development. Cách sinh (như mục "Cấu hình"):
      trên một Mac có Xcode, chạy bản build **ký development** trên thiết bị thật đăng nhập iCloud; ở chế độ Mong con
      ghi một ngày có lượng kinh, tâm trạng và triệu chứng; chuyển sang Mang thai, nhập cân trước mang thai và ghi
      một cân nặng. Kiểm tra trong CloudKit Console rồi **Deploy Schema Changes** lên Production. **Không** tạo
      field/record type bằng tay.
- [ ] Bác sĩ sản khoa đã duyệt mục 8 của [`docs/content-review-for-doctor.md`](content-review-for-doctor.md)
      (gồm quyết định ngưỡng BMI châu Á).
- [ ] Quyền riêng tư: cân nặng, chiều cao, triệu chứng, tâm trạng chỉ lưu trên máy (cân trước mang thai và chiều
      cao trong App Group, không đồng bộ) và trong iCloud riêng của người dùng (log ngày, cân nặng); app không gửi
      đi đâu. `App/PrivacyInfo.xcprivacy` giữ `NSPrivacyCollectedDataTypes` rỗng và nhãn App Store "Data Not
      Collected" vẫn đúng (dữ liệu không đến máy chủ của nhà phát triển). Thêm vào mô tả / chính sách quyền riêng
      tư: "Cân nặng và triệu chứng chỉ lưu trên máy và iCloud của bạn." Nếu sau này có Bạn đời hay máy chủ, phải
      khai báo lại (Health & Fitness).
- [ ] Ảnh chụp App Store (vi + en, sáng): `weight-*-light`, `pregnancy-home-weight-*-light`, `symptoms-list-*-light`,
      `day-log-*-light`.
- [ ] Ghi chú phát hành: ghi lượng kinh / tâm trạng / triệu chứng ở cả hai chế độ, màn "Triệu chứng" theo tuần thai
      và thẻ nhắc khi có cơn gò hoặc phù chân, màn "Cân nặng" với khoảng tăng cân khuyến nghị theo BMI.

### Kiểm thử thủ công trên iPhone qua TestFlight (vi và en)
- [ ] Mong con: Hôm nay → "Hôm nay bạn thấy thế nào?" → chọn "Ít", chạm lại để bỏ; chọn 2 tâm trạng, 2 triệu chứng
      → Lưu → thẻ hiện một dòng có "…"; VoiceOver đọc đủ cả dòng; thẻ ngày ở Lịch giống vậy.
- [ ] Ghi "Nhiều" ở một ngày không có kỳ kinh → **không** tạo kỳ kinh, dự đoán không đổi.
- [ ] Bỏ hết lựa chọn của một ngày chỉ có lượng kinh → ngày đó hết log.
- [ ] Mang thai: lối tắt "Triệu chứng" → "Ghi hôm nay" → chọn "Cơn gò" → thẻ an toàn hiện (VoiceOver đọc thẻ trước
      ô Ghi chú) → "Xem dấu hiệu cần đi khám" → Chi tiết tuần hiện tại mở ở mục cảnh báo. Dòng ngày có ⚠ và VoiceOver
      đọc "Có triệu chứng cần lưu ý". Vuốt xóa → hỏi xác nhận.
- [ ] Chuyển Mang thai → Mong con → mở lại ngày đã ghi ở Mang thai: triệu chứng thai kỳ không hiện nhưng vẫn còn khi
      quay lại chế độ Mang thai.
- [ ] Cân nặng: thiết lập 52 kg / 160 cm → ghi 58,0 ở tuần 24 → "Trong khoảng"; nhập "56,2" (dấu phẩy) lưu được;
      nhập 250 → báo lỗi dưới ô, VoiceOver đọc lỗi; ghi hai lần cùng ngày → chỉ còn một dòng.
- [ ] Bỏ chiều cao (Cá nhân → "Cân nặng trước mang thai · Chiều cao") → không còn dải, nhóm BMI, pill.
- [ ] Hai máy cùng Apple ID: cân nặng và log ngày ghi trên máy A hiện trên máy B; ghi cùng ngày trên hai máy khi
      offline rồi bật mạng → còn một bản ghi mỗi ngày. (Dự kiến thất bại cho tới khi schema được deploy Production.)
- [ ] Dynamic Type lớn nhất: sheet ghi ngày (2 chế độ), màn Triệu chứng, màn Cân nặng, 4 lối tắt không cắt chữ.
- [ ] Reduce Motion bật: thẻ an toàn chỉ mờ dần.

## Giai đoạn 6 — Bài viết theo tuần

### Trước khi gửi App Store
- [ ] Không thay đổi CloudKit: bài viết nằm trong `pregnancy-content.json` đóng gói cùng app (phiên bản 3).
- [ ] Bác sĩ đã duyệt bài viết từng tuần — mục 9 của [`docs/content-review-for-doctor.md`](content-review-for-doctor.md).
      Tuần chưa duyệt vẫn bị ẩn ở bản App Store (không đổi so với giai đoạn 2).
- [ ] Mọi tuần 4–42 có bài viết — lệnh sau in ra `[]`:
      `python3 -c "import json;d=json.load(open('Packages/KickCore/Sources/KickCore/Resources/pregnancy-content.json'));print([w['week'] for w in d['weeks'] if 'article' not in w])"`
- [ ] Ảnh chụp App Store cho Chi tiết tuần: `week-article-peek-baby-vi-light`, `week-article-expanded-baby-vi-light`,
      `week-article-expanded-mom-vi-light`, `week-article-*-en-dark`.
- [ ] Ghi chú phát hành: Chi tiết tuần mới — bài viết theo tuần, chia thẻ Bé / Mẹ, kéo lên để đọc toàn bài.

### Kiểm thử thủ công trên iPhone qua TestFlight (vi và en)
- [ ] Mở Chi tiết tuần từ ảnh thai nhi ở Hôm nay: sheet ở nấc thấp, thấy tiêu đề, thẻ Bé / Mẹ và câu mở đầu.
- [ ] Kéo tay nắm lên/xuống: sheet theo tay, thả chậm về nấc gần nhất, vuốt nhanh về nấc theo hướng vuốt;
      ảnh thai nhi và hàng chip mờ dần khi kéo lên.
- [ ] Ở nấc cao: bài viết cuộn bình thường; cuộn lên đầu bài rồi kéo xuống → sheet thu về nấc thấp.
- [ ] Đổi tuần bằng chip hoặc vuốt ngang trên nền: giữ nguyên nấc và thẻ đang chọn, bài viết về đầu.
- [ ] Triệu chứng → "Cơn gò" → "Xem dấu hiệu cần đi khám": sheet mở ở nấc cao, thẻ Mẹ, đúng mục cảnh báo.
- [ ] VoiceOver: tay nắm đọc "Mở rộng bài viết" / "Thu gọn bài viết" và chạm hai lần để đổi nấc; câu kích thước
      đọc đơn vị đầy đủ ("gam", "milimét"); ở nấc cao không chạm tới chip tuần phía sau.
- [ ] Reduce Motion bật: sheet chuyển nấc tức thì, ảnh nền chỉ mờ đi chứ không thu nhỏ.
- [ ] Dynamic Type lớn nhất: Chi tiết tuần mở thẳng nấc cao, chữ không bị cắt.
- [ ] Tuần 4–6 không có câu số đo; tuần 41–42 có dòng "Số liệu chuẩn Hadlock chỉ đến tuần 40."

## Giai đoạn 7 — Kiến thức chuyên sâu

### Trước khi gửi App Store
- [ ] Không thay đổi CloudKit: bài viết nằm trong `knowledge-content.json` đóng gói cùng app (phiên bản 1).
- [ ] Bác sĩ đã duyệt các bài — mục 10 của [`docs/content-review-for-doctor.md`](content-review-for-doctor.md).
      Bài chưa duyệt bị ẩn ở bản App Store; khi chưa có bài nào được duyệt, thẻ ở Hôm nay và thư viện không hiện.
- [ ] Đủ 18 bài và chưa bài nào tự đánh dấu duyệt — lệnh sau in ra `18`:
      `python3 -c "import json;print(len(json.load(open('Packages/KickCore/Sources/KickCore/Resources/knowledge-content.json'))['articles']))"`
- [ ] Ảnh chụp App Store (khi có bài được duyệt): `knowledge-card-vi-light`, `knowledge-library-vi-light`,
      `knowledge-reading-peek-vi-light`, `knowledge-*-en-dark`.
- [ ] Ghi chú phát hành: mục Kiến thức mới — bài viết chuyên sâu theo tam cá nguyệt, gợi ý ngay ở màn Hôm nay.

### Kiểm thử thủ công trên iPhone qua TestFlight (vi và en)
- [ ] Hôm nay (mang thai, có ngày dự sinh): cuối màn có thẻ "Gợi ý cho tam cá nguyệt N" với 3 bài; ngày hôm sau
      vẫn 3 bài đó, tuần sau bài đầu tiên đổi.
- [ ] Chạm một bài: màn đọc mở ở nấc thấp, thấy ảnh/biểu tượng chủ đề, tiêu đề, dòng "Người xem xét" và câu tóm tắt;
      kéo tay nắm lên/xuống như Chi tiết tuần; ✕ đóng màn đọc.
- [ ] "Xem thêm": thư viện "Kiến thức" mở đúng tam cá nguyệt hiện tại; đổi chip 1/2/3 thì danh sách đổi theo chủ đề.
- [ ] Đang kéo sheet thì vuốt về màn hình chính hoặc có cuộc gọi đến: mở lại app, sheet nằm đúng một nấc, không
      treo lưng chừng (sửa lỗi kéo bị hủy).
- [ ] Chế độ Mong con: không có thẻ Kiến thức.
- [ ] VoiceOver: màn đọc mở thẳng nấc cao; ✕ được đọc trước; tiêu đề mục đọc là "tiêu đề".
- [ ] Dynamic Type lớn nhất: thẻ, thư viện và màn đọc không cắt chữ (tóm tắt ở thẻ tối đa 2 dòng); màn đọc mở nấc cao.
- [ ] Reduce Motion bật: sheet chuyển nấc tức thì; ảnh nền chỉ mờ đi.

## Giai đoạn 8 — Chia sẻ với bố bé qua iCloud

### Trước khi gửi App Store
- [ ] **CloudKit schema — record type `Snapshot`.** Bản TestFlight/App Store dùng môi trường **Production**, nơi
      CloudKit không tự tạo record type; nếu thiếu, việc chia sẻ vẫn tạo được nhưng tải dữ liệu lên báo lỗi và máy
      bố bé không thấy gì. Làm một trong hai cách, trên CloudKit Console (icloud.developer.apple.com), container
      `iCloud.com.lmtiep.kickcounter`, môi trường **Development**:
      - Chạy một bản build ký development trên iPhone thật (Xcode), bật chia sẻ với bố bé một lần: record type
        `Snapshot` tự sinh trong Development; hoặc
      - Tạo tay record type `Snapshot` với hai field: `payload` kiểu **Bytes** và `version` kiểu **Int(64)**.
        Khác với các record `CD_*` của SwiftData (mục "Cấu hình"), record này do app tự ghi bằng CloudKit nên tạo tay
        là an toàn; không cần index (app chỉ đọc record theo ID, không truy vấn).
      Rồi **Deploy Schema Changes** lên Production (cùng lần với các record type `CD_*` nếu chưa deploy).
      Zone `PartnerShare` và bản ghi `CKShare` là của hệ thống, không cần khai báo.
- [ ] `CKSharingSupported = YES` có trong Info.plist của bản build (sinh từ `project.yml`):
      `/usr/libexec/PlistBuddy -c "Print :CKSharingSupported" <đường dẫn>/KickCounter.app/Info.plist` in ra `true`.
- [ ] Entitlement của bản TestFlight có `aps-environment = production` và container
      `iCloud.com.lmtiep.kickcounter` (`codesign -d --entitlements :- <app>`): đẩy thầm báo dữ liệu mới cho máy bố bé
      cần push. Entitlements trong repo không đổi ở giai đoạn này.
- [ ] Kiểm thử thủ công hai Apple ID: [`docs/partner-sharing-manual-test.md`](partner-sharing-manual-test.md), đủ
      các mục 1–8, một lần tiếng Việt và một lần tiếng Anh.
- [ ] **Quyền riêng tư.** Chỉ chia sẻ đúng những gì app ghi trong `PartnerSnapshot`: tuần thai / ngày dự sinh,
      tối đa 5 lịch khám sắp tới (tên và giờ), tóm tắt lượt đếm cử động (lượt gần nhất, số lượt và thời gian trung
      bình 7 ngày) và tên hiển thị "Mẹ"/"Mom". Không bao giờ: ghi chú, triệu chứng, cân nặng, dữ liệu chu kỳ. Dữ liệu
      nằm trong iCloud của mẹ và chỉ người được mời xem được; nhà phát triển không nhận dữ liệu nào, nên App Privacy
      vẫn là "Data Not Collected". Ghi chú cho reviewer: tính năng chia sẻ chỉ xem qua iCloud, cần hai Apple ID để
      thử; mô tả câu trên.
- [ ] Ảnh chụp App Store (nếu dùng): `partner-today-vi-light`, `partner-today-en-dark`,
      `partner-share-row-notShared-vi-light`.
- [ ] Ghi chú phát hành: "Chia sẻ với bố bé" — mời bố bé xem tuần thai, lịch khám và lượt đếm cử động qua iCloud,
      chỉ xem, ngừng chia sẻ bất cứ lúc nào.

## Giai đoạn 9 — Mục tiêu "Theo dõi chu kỳ" và phần giới thiệu mới

### Trước khi gửi App Store
- [ ] **Không đổi CloudKit.** Mục tiêu, biện pháp tránh thai, độ đều của chu kỳ và công tắc "Hiện que thử rụng trứng &
      nhiệt độ" nằm trong App Group (`cycleGoal`, `contraception`, `cycleRegularity`, `cycleShowsFertilityTests`), không
      đồng bộ, như `CycleSettings`. Không cần deploy schema; entitlements và `project.yml` không đổi.
- [ ] **Người dùng cũ không phải xem lại phần giới thiệu.** Cài bản TestFlight đè lên bản trước trên một máy đang ở chế
      độ Mong con có dữ liệu: mở app → vào thẳng Hôm nay, vẫn "Cửa sổ thụ thai", vẫn có que thử LH và nhiệt độ trong phần
      ghi, Cá nhân → "Mục tiêu" đang chọn "Mong con". Làm lại với một máy ở chế độ Mang thai: không đổi gì.
- [ ] **Bác sĩ đã duyệt mục 11** của [`content-review-for-doctor.md`](content-review-for-doctor.md) (các lựa chọn tránh
      thai, ghi chú "không phải biện pháp tránh thai", ghi chú nội tiết, lời trấn an chu kỳ không đều).
- [ ] **Quyền riêng tư.** Biện pháp tránh thai là dữ liệu nhạy cảm: chỉ lưu trên máy (App Group), không gửi đi đâu, không
      nằm trong `PartnerSnapshot`; App Privacy vẫn là "Data Not Collected". Câu ở bước chào mừng ("Dữ liệu được lưu trên
      iPhone và iCloud của bạn. Bạn tự chọn chia sẻ những gì. Không quảng cáo, không bán dữ liệu.") phải còn đúng.
- [ ] **Thông báo.** Cài mới, đi hết nhánh Theo dõi chu kỳ, chọn "Để sau": iOS **không** hỏi quyền thông báo. Cài mới
      lần nữa, chọn "Bật nhắc nhở": iOS hỏi một lần. Khi theo dõi chu kỳ chỉ có nhắc kỳ kinh và trễ kinh (Cài đặt → Thông
      báo không cần kiểm tra; xem bằng cách đổi ngày trên máy thử nếu cần).
- [ ] Ảnh chụp App Store (nếu dùng): `onboarding-goal-vi-light`, `onboarding-result-vi-light`,
      `cycle-tracking-today-vi-light`.
- [ ] Ghi chú phát hành: "Theo dõi chu kỳ" — chọn mục tiêu ngay từ đầu: theo dõi kỳ kinh (biết trước kỳ kinh tới, có tính
      đến biện pháp tránh thai), mong con hoặc mang thai; phần giới thiệu ngắn gọn, câu nào cũng có thể bỏ qua.

## Giai đoạn 10 — Lịch sử chu kỳ

### Trước khi gửi App Store
- [ ] **Không đổi CloudKit.** Trang chỉ đọc `PeriodEntry` và `CycleLog` sẵn có; không thêm trường, không cần deploy schema.
- [ ] **Trên máy có dữ liệu thật:** Hôm nay → "Sắp tới" → "Xem lịch sử chu kỳ". **Chỉ khi đã có ít nhất một chu kỳ
      21–45 ngày**, số "Chu kỳ trung bình" trong Lịch sử phải bằng ô độ dài chu kỳ ở thẻ "Sắp tới" — cả hai đều tính từ
      cùng các chu kỳ đã ghi. Nếu chưa có chu kỳ nào trong khoảng 21–45 ngày (ví dụ mới ghi một kỳ kinh), thẻ "Sắp tới"
      vẫn hiện độ dài chu kỳ mặc định lấy từ Cài đặt, còn Lịch sử hiện "Ghi thêm kỳ kinh…" — hai số không khớp trong
      trường hợp này và đó không phải là lỗi. Ô độ dài **kỳ kinh** ("period") ở thẻ "Sắp tới" luôn lấy từ Cài đặt, không
      phải trung bình đã ghi, nên không cần so với "Chu kỳ trung bình kỳ kinh" của Lịch sử. Số dòng bằng số kỳ kinh đã
      ghi; chạm một chu kỳ thấy đúng các ngày đã ghi, sửa một ngày rồi quay lại thấy thay đổi.
- [ ] **Bác sĩ đã duyệt mục 12** của [`content-review-for-doctor.md`](content-review-for-doctor.md).
- [ ] Ghi chú phát hành: "Lịch sử chu kỳ" — xem độ dài trung bình, khoảng dao động và từng chu kỳ cùng những ngày đã ghi.

## Giai đoạn 12 — Sẵn sàng lên App Store

Tham khảo: `docs/app-store-compliance.md` (bảng kiểm), `docs/app-review-notes.md` (ghi chú dán vào ASC),
`docs/superpowers/specs/2026-10-08-app-store-readiness-design.md`.

### Trang web (GitHub Pages)
- [ ] Bật GitHub Pages cho repo: Settings → Pages → Source = nhánh `gh-pages`, thư mục gốc (`/`). Nhánh
      `gh-pages` chỉ chứa nội dung của `site/` (orphan branch, do người vận hành đẩy lên, không phải nhánh code).
- [ ] Sau khi bật, hai URL phải mở được và hiện đúng nội dung song ngữ (vi trước, en sau):
      - https://lmtiep.github.io/kick-counter/privacy.html
      - https://lmtiep.github.io/kick-counter/support.html
      - https://lmtiep.github.io/kick-counter/ (trang chủ, có liên kết tới hai trang trên)
- [ ] Mở thử ở chế độ tối (Dark Mode) trên iPhone/Mac: chữ vẫn đọc rõ (bảng màu suy ra từ `LunaPalette.swift`).

### App Store Connect
- [ ] App Information → **Privacy Policy URL**: `https://lmtiep.github.io/kick-counter/privacy.html`.
- [ ] App Information → **Support URL**: `https://lmtiep.github.io/kick-counter/support.html`.
- [ ] App Privacy (App Privacy Details): chọn **"Data Not Collected"** — đúng với bản 1.0 (không iCloud, không
      server, không analytics, không quảng cáo).
- [ ] Age rating — bộ câu hỏi mới: "Medical or Treatment Information" trả lời **Frequent** (nội dung y tế xuất
      hiện xuyên suốt app, không phải hiếm); dự kiến ra 16+. Không có UGC, chat, quảng cáo, web view.
- [ ] EU Digital Services Act — **trader status**: khai "not a trader" (app cá nhân, miễn phí, không bán hàng),
      trừ khi chủ dự án muốn khai khác (nếu khai trader, địa chỉ/SĐT/email sẽ hiện công khai).
- [ ] Notes for Review: dán nguyên văn `docs/app-review-notes.md`.
- [ ] Kiểm tra bản build không có capability cũ: `grep -rn "CKSharingSupported\|remote-notification" App/Info.plist
      project.yml` không in ra gì; `codesign -d --entitlements - <app>` trên bản release chỉ thấy entitlement
      App Group.

### Kiểm thử thủ công trên máy thật (một lần, trước khi gửi duyệt)
- [ ] Cài bản TestFlight của giai đoạn 12 trên một máy đã có dữ liệu cũ (từ bản trước đó): dữ liệu (lượt đếm, kỳ
      kinh, cân nặng, lịch khám) vẫn còn nguyên sau khi cập nhật.
- [ ] Kiểm tra **ghi** được sau khi cập nhật (store cũ từng mở với CloudKit, nay mở không có CloudKit): thêm một
      lượt đếm cử động → vuốt tắt hẳn app → mở lại: lượt đếm đó vẫn còn. Trong lúc thử, mở Console.app (máy nối với
      Mac, lọc theo `KickCounter`) và xác nhận không có dòng nào chứa "Read Only" / "read-only".
- [ ] Báo cho người thử (TestFlight): bản sao cũ trong iCloud **không** bị xoá — "Xoá toàn bộ dữ liệu" chỉ xoá trên
      máy (cố ý, app không còn chạm vào iCloud). Muốn xoá bản sao cũ: Cài đặt → [tên] → iCloud → Quản lý dung lượng
      (Manage Storage) → Luna Mom → Xoá dữ liệu.
- [ ] Không có hộp thoại hay yêu cầu đăng nhập iCloud nào xuất hiện ở bất kỳ đâu trong app.
- [ ] Nếu máy đang ở chế độ Bạn đời (đã từng dùng chế độ bố bé) hoặc có mode `partner` đã lưu: mở app → vào
      thẳng onboarding (không còn tùy chọn chế độ bố bé).
- [ ] Cuối mục Cá nhân, dưới "Thông tin y tế": hai dòng "Chính sách quyền riêng tư" và "Hỗ trợ" mở đúng hai trang
      trên qua Safari.
- [ ] Cá nhân → "Xoá toàn bộ dữ liệu": xác nhận → quay về onboarding; sau khi hoàn tất onboarding lại, không còn
      dữ liệu cũ nào (Lịch sử/Chu kỳ/Thai kỳ trống).
- [ ] Cài mới (chưa từng cài) trên máy đã đăng xuất iCloud: app chạy đầy đủ, không bị chặn tính năng nào.

### Khôi phục iCloud ở phiên bản sau (khi cần)
Khi muốn bật lại đồng bộ iCloud và chế độ chia sẻ với bố bé ở một phiên bản sau, theo đúng thứ tự:
1. **Bắt buộc trước khi phát hành:** thêm một cài đặt trong app để người dùng tự bật iCloud (opt-in, **mặc định
   tắt**), vì `site/privacy.html` hứa rằng tuỳ chọn iCloud trong tương lai là opt-in. Chỉ đổi công tắc lúc biên dịch
   thì **mọi người** đều bị đồng bộ. Store và chia sẻ chỉ dùng CloudKit khi `AppFeatures.cloudSync` **và** cài đặt
   đó cùng bật. Sau đó mới đổi `AppFeatures.cloudSync` từ `false` thành `true` trong
   `Packages/KickCore/Sources/KickCore/AppFeatures.swift` (và sửa test `cloudSyncIsOffForVersion1`).
2. Thêm lại các entitlement đã gỡ ở giai đoạn 12: `aps-environment`, `com.apple.developer.icloud-container-identifiers`,
   `com.apple.developer.icloud-services` (trong `App/KickCounter.entitlements` và `entitlements:` của `project.yml`).
3. Thêm lại `UIBackgroundModes: [remote-notification]` và `CKSharingSupported: true` trong Info properties của
   `project.yml`.
4. Chạy `xcodegen generate --quiet`, rồi deploy schema CloudKit lên Production (`CD_KickSession`, `CD_Kick`,
   `CD_Appointment`, `CD_PeriodEntry`, `CD_CycleLog`, `CD_WeightEntry`, `Snapshot`) theo đúng cách ở mục "Cấu hình"
   phía trên (không tạo record type bằng tay cho các bảng `CD_*`).
5. Cập nhật chính sách quyền riêng tư (`site/privacy.html`/`site/support.html`) **trước khi** phát hành: nêu rõ
   dữ liệu nào đồng bộ iCloud, chế độ chia sẻ với bố bé hoạt động ra sao, và xác nhận tính năng này mặc định tắt
   (opt-in) nếu đó vẫn là quyết định của chủ dự án. Đẩy lại nhánh `gh-pages`.
6. Rà lại `docs/app-store-compliance.md` dòng 5.1.3(ii) và các dòng "Không áp dụng (giai đoạn 12)" liên quan đến
   CloudKit/entitlement, đổi lại trạng thái cho đúng với phiên bản mới.

## Giai đoạn 13 — Kỳ kinh trước đây và câu so sánh ở Hôm nay

Đặc tả: `docs/superpowers/specs/2026-10-08-past-periods-design.md`.

- [ ] **Không đổi CloudKit.** Chỉ thêm `PeriodEntry` bằng đường lưu sẵn có; không thêm trường.
- [ ] **Trên máy thật:** Lịch sử chu kỳ → "Thêm kỳ kinh trước đây", thêm **3 kỳ kinh cũ** (mỗi kỳ cách nhau khoảng
      một chu kỳ, trước kỳ cũ nhất đã ghi). Mỗi lần lưu thấy thông báo "Đã thêm kỳ kinh" và một dòng mới; "Chu kỳ trung
      bình" và ngày dự đoán kỳ tới ở thẻ "Sắp tới" (Hôm nay) **thay đổi** theo dữ liệu mới. Chọn ngày trùng một kỳ đã
      ghi: hiện "Trùng với một kỳ kinh đã ghi." ngay trong trang, không lưu gì.
- [ ] Lịch → một ngày cách đây vài tháng → "Kỳ kinh bắt đầu": kỳ kinh đó kết thúc sau đúng số ngày thường gặp (không
      còn "đang diễn ra").
- [ ] Mang thai, tuần 10 trở đi: thẻ kích thước ở Hôm nay ghi "Bé nặng tương đương …"; tuần 4–9 vẫn "Bé to bằng …".
- [ ] **Bác sĩ đã duyệt mục 14** của [`content-review-for-doctor.md`](content-review-for-doctor.md).
- [ ] Ghi chú phát hành: "Thêm kỳ kinh trước đây" trong Lịch sử chu kỳ, để dự đoán dựa trên nhiều chu kỳ hơn.

## Giai đoạn 15 — Sao lưu & khôi phục bằng file

Đặc tả: `docs/superpowers/specs/2026-10-09-backup-design.md`.

- [ ] **Hai máy, qua AirDrop.** Máy A có dữ liệu thật (vài lượt đếm, kỳ kinh, ghi chép, cân nặng, lịch khám). Cá nhân
      → "Sao lưu ra file" → AirDrop sang máy B. Ghi lại số mục ở các màn hình của máy A.
- [ ] Máy B (đã cài Luna Mom, mới cài hoặc đang ở onboarding): mở file vừa nhận → Luna Mom mở trang "Khôi phục bản
      sao lưu", tóm tắt có **đúng số** lượt đếm, kỳ kinh, ngày ghi chép, lần cân, lịch khám và ngày sao lưu.
- [ ] Bấm "Khôi phục": về Hôm nay của đúng chế độ, thấy "Đã khôi phục dữ liệu". Lịch sử, Lịch, Cân nặng, Lịch khám,
      cài đặt (độ dài chu kỳ, ngày dự sinh, nhắc nhở, ngôn ngữ) **khớp** máy A. Nhắc lịch khám và nhắc kỳ kinh được
      lên lịch lại (Cài đặt iOS → Thông báo vẫn bật).
- [ ] Trên máy A: "Lần sao lưu gần nhất" hiện dưới hàng sao lưu sau khi chia sẻ xong; huỷ bảng chia sẻ thì không đổi.
- [ ] Mở một file không phải bản sao lưu (đổi tên một file `.json` bất kỳ thành `.lunamom`): hiện "File này không phải
      bản sao lưu của Luna Mom." hoặc "Không đọc được file.", dữ liệu không đổi.
- [ ] Đang đếm cử động rồi mở file: trang khôi phục có dòng "Lượt đếm đang chạy sẽ bị dừng."; sau khi khôi phục,
      Live Activity cũ biến mất.
- [ ] "Xoá toàn bộ dữ liệu" xoá luôn "Lần sao lưu gần nhất".
- [ ] **Trang web:** `site/privacy.html` có đoạn "Sao lưu ra file" / "Backup to a file"; chủ dự án duyệt rồi mới xuất
      bản lại nhánh `gh-pages`.
- [ ] Ghi chú phát hành: "Sao lưu toàn bộ dữ liệu ra file và khôi phục trên iPhone khác (Cá nhân → Dữ liệu)."

## Giai đoạn 17 — Nhắc uống thuốc tránh thai

Đặc tả: `docs/superpowers/specs/2026-10-09-pill-reminder-design.md`. Làm trên **máy thật** (simulator không có nút
hành động trên thông báo khi khoá màn hình).

- [ ] Theo dõi chu kỳ, biện pháp "Thuốc tránh thai hằng ngày" → Cá nhân → "Nhắc uống thuốc": bật, cho phép thông báo,
      vỉ 21 + 7, ngày bắt đầu là hôm nay, giờ nhắc 2–3 phút tới. Hôm nay hiện "Viên 1/21".
- [ ] Khoá máy, đợi thông báo "Đến giờ uống thuốc" — "Viên 1/21 hôm nay.". Nhấn giữ → "Đã uống" (app không mở ra).
      Mở app: thẻ ghi "Đã uống lúc …"; **không** có thông báo "Bạn đã uống thuốc hôm nay chưa?" 2 giờ sau.
- [ ] Hôm sau không đánh dấu: đúng 2 giờ sau giờ nhắc có **một** lần nhắc lại, không có lần thứ ba.
- [ ] Buộc tắt app (vuốt khỏi đa nhiệm) rồi bấm "Đã uống" trên thông báo: mở app, liều vẫn được ghi.
- [ ] **Tuần nghỉ:** chọn ngày bắt đầu vỉ là 22 ngày trước. Hôm nay ghi "Tuần nghỉ · vỉ mới bắt đầu ngày …"; trong
      Cài đặt iOS → Thông báo không có thông báo nào của Luna Mom trong tuần đó; tối ngày đầu vỉ mới có nhắc như
      thường.
- [ ] Đổi biện pháp sang "Bao cao su": hàng "Nhắc uống thuốc" và thẻ ở Hôm nay biến mất, không còn thông báo. Đổi lại
      "Thuốc tránh thai hằng ngày": cài đặt cũ còn nguyên, nhắc nhở quay lại.
- [ ] **Giờ nhắc muộn:** đặt giờ nhắc 23:00, không đánh dấu. Sau nửa đêm (trước 01:00), thẻ ở Hôm nay ghi "Viên n/21
      (hôm qua)"; bấm "Đã uống hôm nay" ghi cho hôm qua, nhắc tối nay vẫn còn.
- [ ] **Đổi múi giờ:** đặt vỉ ở Việt Nam, rồi Cài đặt → Chung → Ngày & Giờ → chọn múi giờ khác (ví dụ New York): mở
      app, cùng một ngày lịch vẫn là cùng một viên; viên đã uống vẫn nằm đúng ngày.
- [ ] **Không mở app 2 tuần:** sau ngày nhắc cuối cùng có một thông báo "Mở Luna Mom để tiếp tục nhắc uống thuốc." vào giờ
      nhắc; mở app thì nhắc nhở được lên lịch lại.
- [ ] Đổi ngôn ngữ sang English: thông báo và nút "Taken" bằng tiếng Anh.
- [ ] Sao lưu ra file rồi khôi phục trên máy khác: cài đặt nhắc và các ngày đã uống còn nguyên. "Xoá toàn bộ dữ liệu"
      xoá cả hai.
