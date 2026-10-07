# Kiểm thử thủ công: chia sẻ với bố bé qua iCloud (giai đoạn 8)

Chia sẻ thật qua iCloud không chạy được trên CI (simulator của CI không đăng nhập iCloud), nên phải thử bằng tay
trên hai iPhone thật với **hai Apple ID khác nhau**, cài bản TestFlight. Làm lại toàn bộ trước mỗi lần phát hành có
đụng tới `App/Partner/` hoặc `KickCore/Partner*`.

## Chuẩn bị
- [ ] Schema CloudKit đã có record type `Snapshot` trong **Production** (xem "Giai đoạn 8" trong
      [`release-checklist.md`](release-checklist.md)). Nếu chưa, bước 2 sẽ không có dữ liệu và bước 3 báo lỗi.
- [ ] **Máy A (mẹ):** Apple ID thứ nhất, đã đăng nhập iCloud, iCloud Drive bật, cài Luna Mom từ TestFlight, chế độ
      Mang thai, đã có ngày dự sinh, ít nhất một lịch khám trong tương lai và một lượt đếm cử động đã xong.
- [ ] **Máy B (bố bé):** Apple ID thứ hai (khác máy A), đã đăng nhập iCloud, có Tin nhắn (iMessage) với máy A,
      đã được mời vào TestFlight của Luna Mom nhưng **chưa** cài app (để thử luồng cài mới).
- [ ] Ghi lại: phiên bản và build TestFlight, model iPhone và iOS của hai máy, ngôn ngữ app (làm một lần vi, một lần en).

## 1. Mời qua Tin nhắn (máy A)
1. [ ] Cá nhân → thẻ "Chia sẻ với bố bé": dòng phụ đầu tiên là "Đang kiểm tra iCloud…" rồi "Mời bố bé xem hành
       trình"; dưới thẻ là đoạn "Chia sẻ qua iCloud, chỉ xem: …".
2. [ ] Chạm thẻ: bảng chia sẻ iCloud của hệ thống mở ra, tên mục là "Luna Mom". Trong "Tùy chọn chia sẻ" chỉ có
       "Chỉ những người bạn mời" và quyền "Chỉ xem" (không có "Có thể thay đổi", không có "Bất kỳ ai có liên kết").
3. [ ] Chọn Tin nhắn, gửi cho Apple ID của máy B. Đóng bảng: dòng phụ đổi thành "Đã chia sẻ" và có thêm
       "Ngừng chia sẻ".
4. [ ] Chờ ít nhất 10 giây (ứng dụng đợi 5 giây sau thay đổi cuối rồi mới tải lên).

## 2. Nhận lời mời trên máy thứ hai (máy B)
1. [ ] Mở tin nhắn, chạm đường dẫn: hệ thống mời cài Luna Mom (TestFlight). Cài xong, chạm lại đường dẫn.
       App mở thẳng chế độ Bạn đời, **không** qua phần giới thiệu.
2. [ ] Tab bar: "Hôm nay · Kiến thức · Cá nhân". Không có tab "Cử động", không có nút đếm cử động ở đâu cả.
3. [ ] Hôm nay: "Hành trình của Mẹ"; đúng tuần + ngày và số ngày còn lại như máy A; thẻ kích thước bé (chạm mở Chi tiết
       tuần, đóng bằng ✕); "Lịch khám sắp tới" có đúng các lịch khám tương lai của máy A (tên và giờ, **không** có ghi
       chú); "Đếm cử động" có lượt gần nhất và số lượt trong 7 ngày; "Cập nhật … trước".
4. [ ] Kiến thức: thư viện mở đúng tam cá nguyệt. Cá nhân: "Chế độ Bạn đời", "Những gì được chia sẻ", "Thoát chế
       độ Bạn đời".
5. [ ] Máy A: mở lại app (hoặc chuyển tab rồi quay lại Cá nhân): dòng phụ là "Bố bé đang xem".
6. [ ] Đường nhận khi app đang chạy: ở lần mời lại của mục 4.3, mở app máy B (để ở nền) **trước** khi chạm đường
       dẫn. Lời mời vẫn được nhận và app vào chế độ Bạn đời (bước 2.1 đã thử đường app khởi động từ đường dẫn).

## 3. Cập nhật lịch khám và thấy trên máy bố bé
1. [ ] Máy A: thêm một lịch khám mới ngày mai, có ghi chú "riêng tư". Sửa tên một lịch khám cũ. Chờ 10 giây.
2. [ ] Máy B: để app mở ở Hôm nay (app ở tiền cảnh, **không** kéo làm mới). Trong vòng khoảng 2 phút (đẩy thầm
       của iCloud) lịch mới và tên mới phải tự hiện ra; chữ "riêng tư" **không** xuất hiện ở đâu. Nếu sau khoảng 2
       phút danh sách vẫn chưa đổi: ghi **FAIL** cho bước này (đẩy thầm không hoạt động). Chỉ sau khi đã ghi kết quả
       mới kéo xuống để làm mới, coi như bước chẩn đoán: dữ liệu hiện ra sau khi kéo nghĩa là tải lên đúng nhưng
       đẩy thầm hỏng; vẫn không hiện nghĩa là máy A chưa tải lên.
3. [ ] Máy A: đếm xong một lượt 10 cử động. Máy B (kéo để làm mới): lượt gần nhất là lượt vừa đếm.
4. [ ] Máy A: xóa một lượt trong Lịch sử, đổi ngày dự sinh rồi đổi lại. Máy B: số lượt 7 ngày và tuần thai đúng
       theo máy A sau khi làm mới.
5. [ ] Máy A: thêm năm lịch khám liên tiếp thật nhanh. Máy B chỉ thấy 5 lịch gần nhất.
6. [ ] Bật chế độ máy bay trên máy B, kéo để làm mới: vẫn thấy dữ liệu cũ (không màn lỗi). Tắt chế độ máy bay,
       làm mới: dữ liệu mới.
7. [ ] Máy A: để app ở nền hơn 6 giờ (hoặc tới hôm sau), mở lại, không sửa gì, chờ 10 giây. Máy B (kéo để làm
       mới): "Cập nhật … trước" chỉ còn vài giây/phút.

## 4. Ngừng chia sẻ (máy A)
1. [ ] Cá nhân → "Ngừng chia sẻ" → hộp xác nhận "Ngừng chia sẻ với bố bé? …" → "Ngừng chia sẻ".
2. [ ] Dòng phụ về lại "Mời bố bé xem hành trình"; không còn "Ngừng chia sẻ".
3. [ ] (Lần thử thứ hai) Mời lại như mục 1, máy B nhận lại như mục 2; lần này ngừng từ **bên trong** bảng chia sẻ
       của hệ thống ("Ngừng chia sẻ" trong bảng). Kết quả giống bước 4.2.
4. [ ] (Lần thử thứ ba) Mời lại như mục 1, máy B nhận lại như mục 2. Lần này **không** chạm "Ngừng chia sẻ": máy A
       Cá nhân → "Kết thúc theo dõi thai kỳ" → "Quay về theo dõi chu kỳ". Máy B (mở app hoặc kéo để làm mới): màn
       "Mẹ đã ngừng chia sẻ", không còn dữ liệu cũ. Trên CloudKit Console (như ở mục 8, "Ngừng chia sẻ từ bên trong
       bảng chia sẻ hệ thống"): zone `PartnerShare` của máy A **không còn tồn tại**. Làm lại một lần bằng bộ chọn chế
       độ ở Cá nhân ("Mong con" thay vì "Kết thúc theo dõi thai kỳ"): kết quả giống hệt.
5. [ ] (Lần thử thứ tư, ngoại tuyến) Mời lại, máy B nhận lại. Bật chế độ máy bay trên máy A **rồi mới** kết thúc
       theo dõi thai kỳ. Tắt chế độ máy bay, đưa app máy A về nền rồi mở lại (đang ở chế độ Mong con): việc ngừng
       chia sẻ dang dở được làm nốt. Máy B hiện "Mẹ đã ngừng chia sẻ"; zone `PartnerShare` của máy A không còn.

## 5. Bố bé thấy trạng thái đã ngừng (máy B)
1. [ ] Mở app hoặc kéo để làm mới: màn "Mẹ đã ngừng chia sẻ" với nút "Thoát chế độ Bạn đời". Không còn dữ liệu cũ.
2. [ ] Buộc tắt app rồi mở lại: vẫn "Mẹ đã ngừng chia sẻ" (dữ liệu lưu trên máy đã bị xóa).
3. [ ] Chạm "Thoát chế độ Bạn đời": vì máy B cài mới khi nhận lời mời, phần giới thiệu hiện ra; chọn "Đang mang thai"
       hoặc "Mong con" như người dùng mới.

## 6. Cài lại
1. [ ] Máy A mời lại; máy B nhận và vào chế độ Bạn đời (mục 2).
2. [ ] Máy B: xóa app, cài lại từ TestFlight, mở app thường (không qua đường dẫn): phần giới thiệu hiện như người mới
       (lời mời đã nhận vẫn nằm trong iCloud của máy B nhưng app không tự vào chế độ Bạn đời). Chạm lại đường dẫn
       trong Tin nhắn: app vào chế độ Bạn đời, thấy hành trình ngay.
3. [ ] Máy A: xóa app, cài lại, mở app: dữ liệu mẹ đồng bộ về từ iCloud (như trước giai đoạn 8); Cá nhân → thẻ
       chia sẻ hiện đúng "Bố bé đang xem" (trạng thái đọc từ iCloud, không lưu trên máy). Thêm một lịch khám: máy B
       thấy sau khi làm mới.
4. [ ] Máy A tự mở đường dẫn lời mời của chính mình: không có gì thay đổi (app không vào chế độ Bạn đời).

## 7. Các trường hợp khác
- [ ] Máy A đăng xuất iCloud: thẻ hiện "Đăng nhập iCloud để chia sẻ" và không chạm được; app vẫn dùng bình thường.
- [ ] Máy A ở chế độ Mong con: không có thẻ chia sẻ.
- [ ] Máy A xóa ngày dự sinh khi chưa chia sẻ: "Hãy đặt ngày dự sinh trước", không chạm được.
- [ ] Máy B đăng xuất iCloud trong chế độ Bạn đời: màn "Đăng nhập iCloud" với "Thử lại".
- [ ] Đồng bộ dữ liệu của mẹ giữa hai máy cùng Apple ID (kiểm thử của v1 và giai đoạn 2) vẫn chạy: thêm app delegate
      cho lời mời không được làm hỏng đồng bộ SwiftData. Trên máy A thứ hai (cùng Apple ID với máy A), cài bản
      TestFlight này, mở app: dữ liệu mang thai, lịch khám, lượt đếm cử động và cân nặng của mẹ đồng bộ về như
      trước giai đoạn 8 (không liên quan tới chia sẻ với bố bé).
- [ ] VoiceOver trên máy B: mỗi thẻ ở Hôm nay đọc thành một câu; thẻ chia sẻ trên máy A đọc tên và trạng thái.

## 8. Các trường hợp chỉ thử được trên máy thật (phát hiện ở lần soát xét trước)
- [ ] **Chấp nhận lời mời thất bại khi cài mới.** Trên máy B, xóa hẳn app (hoặc dùng máy thứ ba chưa cài), đăng
      xuất iCloud (hoặc bật chế độ máy bay) **trước khi** cài. Cài xong, chạm đường dẫn lời mời trong Tin nhắn khi
      máy vẫn đang đăng xuất/offline. Hộp báo lỗi chấp nhận lời mời phải hiện **đè lên phần giới thiệu** (không bị
      hộp giới thiệu che mất hoặc hộp lỗi hiện ở màn trống phía sau). Đăng nhập lại iCloud (hoặc tắt chế độ máy
      bay), chạm lại đường dẫn: lần này vào chế độ Bạn đời bình thường.
- [ ] **Cập nhật bản TestFlight rồi mới mở lời mời.** Trên máy B, cài bản TestFlight *trước* bản đang thử (ví dụ
      bản trước giai đoạn 8 hoặc bản giai đoạn 8 cũ hơn), mở app ít nhất một lần để có một scene session đang chạy
      (không tắt app, chỉ đưa về nền). Cập nhật lên bản TestFlight hiện tại qua TestFlight (không xóa app). Sau khi
      cập nhật, mà **không** buộc tắt app, chạm đường dẫn lời mời trong Tin nhắn: lời mời vẫn phải được nhận và
      app vào chế độ Bạn đời — xác nhận scene session có từ bản cũ cũng dùng scene delegate mới sau khi cập nhật,
      không phải chỉ app khởi động từ đầu mới nhận lời mời.
- [ ] **Chấp nhận trước khi mẹ có dữ liệu đầu tiên.** Mẹ mời bố bé ở máy A **ngay sau khi vừa tạo hồ sơ mang thai**,
      trước khi `PartnerPublisher` kịp tải bản ghi `Snapshot` đầu tiên lên (chạm đường dẫn trên máy B trong vài giây
      đầu, trước khi đợi 10 giây ở mục 1.4). Máy B phải hiện màn đang tải ("Đang tải hành trình…" hoặc tương tự),
      **không** hiện "Mẹ đã ngừng chia sẻ" (đó là trạng thái dữ liệu bị xóa, khác với trạng thái chưa từng có dữ
      liệu). Chờ máy A tải lên xong, kéo máy B để làm mới: hành trình hiện ra bình thường.
- [ ] **Đẩy thầm khi máy bố bé đang ở nền.** Đưa app máy B về nền (nhấn nút Home / vuốt lên, không buộc tắt). Trên
      máy A, thêm một lịch khám mới. Trong khoảng một phút, mở lại app máy B **không kéo làm mới**: lịch khám mới
      đã có sẵn (xác nhận đẩy thầm `partner-shared-database` hoạt động, không chỉ làm mới khi mở app). Đồng thời
      kiểm tra bản TestFlight dùng đúng môi trường push sản xuất:
      `codesign -d --entitlements :- <đường dẫn>/KickCounter.app` in ra `aps-environment` là `production`
      (không phải `development`).
- [ ] **Ngừng chia sẻ từ bên trong bảng chia sẻ hệ thống, kiểm tra trên CloudKit Console.** Lặp lại mục 4.3 (ngừng
      từ bảng chia sẻ của hệ thống, không phải nút "Ngừng chia sẻ" trong app). Sau khi máy B hiện "Mẹ đã ngừng chia
      sẻ" (mục 5.1), mở CloudKit Console (icloud.developer.apple.com), container `iCloud.com.lmtiep.kickcounter`,
      cơ sở dữ liệu riêng của máy A, môi trường Production: zone `PartnerShare` của máy A phải **không còn tồn
      tại** (app đã xóa zone khi ngừng chia sẻ, kể cả khi ngừng từ bảng hệ thống).
- [ ] **Chế độ Bạn đời trên máy từng ở chế độ Mang thai.** Dùng một máy B **đã cài Luna Mom từ trước và đang ở chế
      độ Mang thai** (có lịch đếm cử động, có thể đã lên lịch thông báo "đếm cử động hôm nay" hoặc có Live Activity
      đang đếm), không xóa app. Chạm đường dẫn lời mời của máy A: app chuyển sang chế độ Bạn đời ngay (không qua
      giới thiệu vì máy đã dùng app). Kiểm tra: không còn thông báo nhắc "đếm cử động" nào được lên lịch mới, không
      còn Live Activity đếm cử động nào đang chạy hoặc có thể bắt đầu. Lưu ý: thông báo nhắc lịch khám đã lên trước
      đó trên máy (của chế độ Mang thai cũ) vẫn có thể còn và vẫn nổ ra đúng giờ — đây là hạn chế đã biết, không
      phải lỗi cần sửa ở giai đoạn này.
- [ ] **Thoát chế độ Bạn đời trên máy từng ở chế độ khác (không phải cài mới).** Tiếp theo trường hợp trên (máy B
      từng ở chế độ Mang thai trước khi vào chế độ Bạn đời), chạm "Thoát chế độ Bạn đời": app phải quay lại đúng
      chế độ Mang thai với dữ liệu cũ của máy B (không phải phần giới thiệu, vì máy này không phải cài mới nhận
      lời mời). Nhắc đếm cử động (thông báo và/hoặc Live Activity) hoạt động lại như trước khi vào chế độ Bạn đời.
- [ ] **(Tùy chọn, nếu thử được) iCloud đầy ở máy mẹ.** Nếu có tài khoản thử với dung lượng iCloud đầy (hoặc lấp
      đầy iCloud Drive của tài khoản thử): lỗi khi tải `Snapshot` lên chỉ được ghi log, thẻ **không** tự đổi, nên
      đừng chờ thông báo sau một lần tải lên thất bại. Thay vào đó, khi chưa chia sẻ, chạm thẻ "Chia sẻ với bố bé" ở
      Cá nhân (app kiểm tra lại và chuẩn bị chia sẻ): thẻ phải hiện thông báo hết dung lượng iCloud thay vì lỗi
      chung hoặc im lặng; chạm lại thẻ thì kiểm tra lại lần nữa. Bỏ qua mục này nếu không có tài khoản thử phù hợp.

## Ghi kết quả
Ghi ngày, build, hai model iPhone, ngôn ngữ và mọi bước thất bại (ảnh chụp + mô tả) vào PR hoặc issue của giai đoạn 8.
