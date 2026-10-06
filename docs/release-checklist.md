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
- [ ] Ảnh chụp App Store mới cho tab Thai kỳ (vi + en): `ci-artifacts/screenshots/pregnancy-home-24-*`, `week-article-*` (thay `week-24-*` từ giai đoạn 6), `appointments-*`.
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
