# Rà soát tuân thủ App Store — Luna Mom

Ngày đọc tài liệu Apple: **2026-10-08**. Trang App Review Guidelines khi đọc không hiện ngày cập nhật.
Đã đối chiếu với repo trên nhánh `feat/fetus-artwork` (commit `6e93122`).
Lời trích từ Apple được giữ ngắn và luôn kèm URL. Tài liệu này **không phải tư vấn pháp lý**.

**Cập nhật giai đoạn 12 (2026-10-08):** phiên bản 1.0 tắt đồng bộ iCloud/CloudKit (`AppFeatures.cloudSync = false`),
ẩn chế độ bố bé, thêm "Xoá toàn bộ dữ liệu", thêm trang chính sách quyền riêng tư và hỗ trợ (liên kết trong app),
thêm manifest quyền riêng tư cho widget, và gỡ các capability không còn dùng (`remote-notification`,
`CKSharingSupported`, các entitlement iCloud). Các dòng bên dưới do giai đoạn này giải quyết được đánh
"Đạt (giai đoạn 12)"; mọi dòng còn "Cần kiểm tra"/"Thiếu" khác (icon thật, bác sĩ duyệt nội dung, age rating,
DSA trader, ảnh chụp, deploy schema CloudKit nếu bật lại…) vẫn là việc của chủ dự án trước khi gửi duyệt.

Nguồn chính:
- [G] App Review Guidelines — https://developer.apple.com/app-store/review/guidelines/
- [P] App Privacy Details — https://developer.apple.com/app-store/app-privacy-details/
- [R] Required reason API — https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
  và mã lý do — https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype
- [A] Age ratings — https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/
  và tin cập nhật — https://developer.apple.com/news/upcoming-requirements/?id=07242025a
- [I] App information (Privacy Policy URL) — https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/
- [V] Platform version information (Support URL) — https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/
- [D] DSA trader — https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/
- [E] ITSAppUsesNonExemptEncryption — https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption
- [N] Xin quyền thông báo — https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications
- [C] Deploy schema CloudKit — https://developer.apple.com/documentation/cloudkit/deploying-an-icloud-container-s-schema
- [VN] Việt Nam — https://developer.apple.com/news/?id=06h4gf33

---

## 1. Bảng kiểm

| Yêu cầu | Nguồn (mục) | Trạng thái app | Việc cần làm |
|---|---|---|---|
| **Không lưu thông tin sức khỏe cá nhân trong iCloud.** Apple viết: "may not store personal health information in iCloud." | [G] 5.1.3(ii) | **Đạt (giai đoạn 12)** | Hướng (a) của mục 2 đã chọn: `AppFeatures.cloudSync = false`, `KickPersistence` dùng `cloudKitDatabase: .none`. Mọi dữ liệu (kick, kỳ kinh, LH/BBT, triệu chứng, cân nặng, lịch khám) chỉ nằm trong App Group trên máy, không đồng bộ iCloud. `AppEnvironment.makeSharing()` trả về `DisabledPartnerSharing`, không còn tạo `CloudPartnerSharing`. Mã CloudKit vẫn còn trong repo, sau switch, để bật lại ở phiên bản sau (xem `docs/release-checklist.md`, "Giai đoạn 12"). |
| Ứng dụng y tế: nêu rõ dữ liệu và phương pháp khi đưa ra con số sức khỏe | [G] 1.4.1 | Đạt | Cân nặng thai theo Hadlock có ghi chú sai số (`pregnancy.baby.estimateNote`, `standardEnds`). Ngày dự sinh ghi rõ "280 ngày". Dự đoán chu kỳ ghi "chỉ là ước tính". Giữ nguyên như vậy. |
| Nhắc người dùng hỏi bác sĩ: "remind users to check with a doctor" | [G] 1.4.1 | Đạt | Có ở `medical.body` (onboarding bước 1, luôn hiện) và `medical.sources.note`. Nên thêm một dòng ngắn "Không thay thế lời khuyên của bác sĩ" ở cuối mỗi bài tuần và bài kiến thức (hiện chỉ có trong Thông tin y tế). |
| Nội dung y khoa chính xác, có nguồn | [G] 1.4.1 | **Thiếu** | Nội dung còn chờ bác sĩ duyệt (`reviewed: false`; xem `docs/content-review-for-doctor.md`). Phải duyệt xong và gửi bản build với `LunaContentPreview = NO`. |
| Không dùng làm biện pháp tránh thai | [G] 1.4 / 1.4.1 | Đạt | Đã có `cycle.disclaimer`, `cycle.notContraception`, `medical.ttc.body`. Đưa câu này vào mô tả App Store (checklist đã ghi). |
| Gửi bản hoàn chỉnh, URL hoạt động, không có nội dung tạm | [G] 2.1(a) | **Thiếu** | Icon vẫn là icon tạm (release-checklist). Nội dung chờ duyệt. Không cần tài khoản demo vì app không có đăng nhập. |
| Ghi rõ tính năng trong Notes for Review, không có tính năng ẩn | [G] 2.3.1(a) | **Đạt (giai đoạn 12)** | `docs/app-review-notes.md` có nội dung sẵn để dán vào ASC: 3 chế độ, Live Activity, dữ liệu chỉ nằm trên máy (không còn iCloud), không có chế độ chia sẻ cho bố bé ở bản này (đã ẩn cùng với `cloudSync = false`). Vẫn cần chủ dự án tự xác nhận cờ `LunaContentPreview` và tham số launch UI test không bật trong bản release trước khi gửi. |
| Ảnh chụp cho thấy app đang dùng; metadata phù hợp 4+ | [G] 2.3.3, 2.3.8 | Cần kiểm tra | Có ảnh vi/en trong `ci-artifacts/screenshots/`. Ảnh thai nhi giữ ở mức minh họa. Không dùng cụm "For Kids". |
| Tên ≤ 30 ký tự, từ khóa đúng nội dung | [G] 2.3.7 | Đạt | "Luna Mom". Không nhồi tên app khác vào từ khóa. |
| Chế độ nền chỉ dùng đúng mục đích | [G] 2.5.4 | **Đạt (giai đoạn 12)** | `UIBackgroundModes: [remote-notification]` và `CKSharingSupported` đã gỡ khỏi `project.yml`/Info.plist, cùng các entitlement `aps-environment`, `com.apple.developer.icloud-container-identifiers`, `com.apple.developer.icloud-services` (chỉ giữ App Group). Bản 1.0 không còn khai báo capability nào không dùng. |
| App tự chứa, không tải code | [G] 2.5.2 | Đạt | Nội dung JSON được đóng gói sẵn trong bundle. |
| Business (miễn phí, không IAP) | [G] 3 | Đạt | Không có IAP hay quảng cáo. |
| Tính năng tối thiểu | [G] 4.2 | Đạt | App có nhiều tính năng gốc (đếm, Live Activity, lịch, chia sẻ). |
| Sign in with Apple / dịch vụ đăng nhập | [G] 4.8 | Không áp dụng | App không có đăng nhập bên thứ ba và không có tài khoản riêng (xem mục 3). |
| **Privacy policy: có link trong ASC và trong app**. Apple viết: "link to their privacy policy in the App Store Connect metadata field and within the app". | [G] 5.1.1(i), [I] | **Đạt (giai đoạn 12)** | Trang `site/privacy.html` (vi + en) có nội dung khớp bản 1.0 (không thu thập, dữ liệu trên máy, cách xóa, không phải lời khuyên y tế). Cá nhân → mục "Thông tin" có dòng "Chính sách quyền riêng tư" mở `https://lmtiep.github.io/kick-counter/privacy.html` qua Safari (`AppLinks`). Còn lại của chủ dự án: bật GitHub Pages cho nhánh `gh-pages` và điền URL vào App Store Connect (xem `docs/release-checklist.md`). |
| Đồng ý và rút lại đồng ý khi thu thập dữ liệu | [G] 5.1.1(ii) | Đạt | Developer không thu thập dữ liệu nào. (Chế độ chia sẻ cho bố bé, vốn do người dùng chủ động bật/tắt, bị ẩn trong bản 1.0 — xem dòng 5.1.3(ii) — nên mục này hiện không áp dụng cho tính năng đó; mã vẫn còn, sẵn để bật lại.) |
| Chỉ xin quyền cần thiết; không ép người dùng cấp quyền | [G] 5.1.1(iii)(iv), 5.1.2(i) | Đạt | Chỉ xin quyền thông báo. Từ chối quyền thì app vẫn chạy (checklist có kiểm thử). |
| Xin quyền thông báo đúng ngữ cảnh, không hỏi ngay lần mở đầu | [N] | Đạt | Hỏi khi chạm đếm lần đầu, khi ghi kỳ kinh đầu tiên, khi bật nhắc lịch hẹn (`requestAuthorizationIfNeeded`). |
| Không bắt đăng nhập; không đòi thông tin cá nhân nếu không cần | [G] 5.1.1(v) | Đạt | Không có đăng nhập. Ngày dự sinh/kỳ kinh cuối có nút "Để sau". |
| Xóa tài khoản trong app | [G] 5.1.1(v) | Không áp dụng | Chỉ bắt buộc khi app cho tạo tài khoản. |
| Cho người dùng xóa toàn bộ dữ liệu | [G] 5.1.1(i) (chính sách phải nêu cách xóa) | **Đạt (giai đoạn 12)** | Cá nhân → "Xoá toàn bộ dữ liệu" (hàng cuối, kiểu destructive) mở hộp xác nhận, rồi gọi `DataReset.deleteAll` (xóa mọi model SwiftData) + `AppDataReset.clearDefaults` (App Group defaults) + hủy mọi thông báo cục bộ + kết thúc Live Activity, và đưa về onboarding. Vì không còn đồng bộ iCloud, không cần xóa zone `PartnerShare`. Privacy policy (`site/privacy.html`) nêu đúng cách này và cách thay thế (xóa app). |
| Chia sẻ dữ liệu cá nhân cần sự cho phép rõ ràng | [G] 5.1.2(i) | Không áp dụng (giai đoạn 12) | Chế độ chia sẻ cho bố bé qua `CKShare` bị ẩn ở bản 1.0 (`DisabledPartnerSharing`, mode picker và onboarding không còn lối vào). Dòng này áp dụng lại nếu bật `cloudSync = true` ở phiên bản sau. |
| Không dùng dữ liệu sức khỏe cho quảng cáo / khai thác dữ liệu | [G] 5.1.3(i) | Đạt | Không có SDK, analytics hay server. |
| Kids | [G] 1.3, 5.1.4 | Không áp dụng | Không chọn Kids Category. |
| App Privacy "Data Not Collected" | [P] | Đạt (theo cách hiểu) | "Collect" là gửi dữ liệu ra khỏi máy để "you and/or your third-party partners" truy cập được. Dữ liệu trong iCloud riêng/`CKShare` thì developer không truy cập được. Apple không có câu nào nói riêng về CloudKit; đây là cách hiểu phổ biến. Privacy policy phải viết nhất quán với nhãn này. |
| Privacy manifest của app | [R] | Đạt | `App/PrivacyInfo.xcprivacy` khai UserDefaults `CA92.1` (dữ liệu chỉ app đọc được) và `1C8F.1` (App Group) — đúng mã. grep không thấy API về timestamp file, boot time, dung lượng đĩa hay bàn phím. |
| **Privacy manifest của widget extension** | [R]: mỗi bundle chứa executable dùng API cần lý do phải có manifest riêng | **Đạt (giai đoạn 12)** | `Widgets/PrivacyInfo.xcprivacy` đã thêm (cùng cấu trúc với `App/PrivacyInfo.xcprivacy`: `NSPrivacyTracking` false, không có collected data types, UserDefaults `1C8F.1`) và đã đưa vào resources của target widget trong `project.yml`. |
| Age rating — bộ câu hỏi mới (2025) | [A] | Cần kiểm tra | Mục "Medical or Treatment Information": Infrequent → 13+, Frequent → 16+; "Health and wellness topics" → 9+. Nội dung tuần, cảnh báo và hướng dẫn đếm cử động gần như chắc là **Frequent → 16+** (hợp với người dùng trưởng thành). Không có UGC, chat, quảng cáo, web view. Trả lời trung thực. Hạn trả lời câu hỏi mới là 31/1/2026 (đã qua), nên app mới bắt buộc trả lời đủ. |
| Mã hóa xuất khẩu | [E] | Đạt | `ITSAppUsesNonExemptEncryption = false`. App chỉ dùng HTTPS/CloudKit của hệ thống, thuộc loại miễn trừ. |
| Privacy Policy URL trong ASC: "Required for iOS and macOS apps" | [I] | **Thiếu** | Xem dòng 5.1.1(i). |
| Support URL (bắt buộc, phải có thông tin liên hệ thật) | [V] | **Thiếu** | Tạo trang hỗ trợ có email liên hệ (có thể dùng chung site với privacy policy). Điền thêm Copyright và liên hệ App Review. |
| DSA trader status (EU) | [D] | Cần kiểm tra | Bắt buộc khai, kể cả khi không bán ở EU. App miễn phí của cá nhân thường khai "not a trader". Nếu khai trader, địa chỉ, SĐT và email sẽ hiện công khai. |
| Deploy schema CloudKit lên Production. Apple viết: "Apps in the App Store can access only the production environment." | [C] | Không áp dụng (giai đoạn 12) | Bản 1.0 không dùng CloudKit (`cloudSync = false`), nên không cần deploy schema để gửi duyệt. Việc này quay lại làm nếu bật `cloudSync = true` ở phiên bản sau — xem `docs/release-checklist.md`, "Giai đoạn 12". |
| `aps-environment` = production trong bản phát hành | [C] (CloudKit push) | Không áp dụng (giai đoạn 12) | Entitlement `aps-environment` đã gỡ khỏi bản 1.0 cùng với các entitlement iCloud khác (không còn dùng push CloudKit). Cần thêm lại khi bật `cloudSync = true`. |
| Quyền dùng hình ảnh (ảnh tạo bằng AI, ảnh thai nhi) | [G] 5.2 (sở hữu trí tuệ) | Cần kiểm tra | Checklist giai đoạn 4 đã ghi: xác nhận được phép dùng thương mại. |
| Yêu cầu riêng cho Việt Nam | [VN], [A] | Không áp dụng / Đạt | Apple chỉ ghi nhận giấy phép **game** (Bộ TT&TT) và ánh xạ rating Việt Nam (00+/12+/16+/18+, tự sinh từ bảng câu hỏi). Không thấy yêu cầu riêng cho app sức khỏe. Luật bảo vệ dữ liệu cá nhân Việt Nam nằm ngoài tài liệu Apple; nên hỏi luật sư nếu cần. |

---

## 2. Việc phải làm trước khi gửi duyệt (theo thứ tự ưu tiên)

1. **Quyết định cách xử lý 5.1.3(ii), vì dữ liệu sức khỏe đang nằm trong iCloud.** Câu chữ của Apple cấm lưu "personal health information in iCloud" mà không giới hạn ở HealthKit ([G] 5.1.3(ii)). Có ba hướng:
   - (a) **An toàn nhất:** bản 1.0 tắt đồng bộ CloudKit (`cloudKitDatabase: .none`) và tạm ẩn chế độ bố bé; dữ liệu chỉ nằm trên máy.
   - (b) Giữ CloudKit nhưng làm thành **lựa chọn bật/tắt rõ ràng** (mặc định tắt, có giải thích), và trong Notes for Review ghi rõ dữ liệu chỉ nằm trong cơ sở dữ liệu riêng iCloud của người dùng, developer không truy cập được. Hướng này vẫn có rủi ro bị từ chối theo đúng câu chữ.
   - (c) Gửi nguyên trạng kèm giải thích. Rủi ro bị từ chối cao nhất.

   Dù chọn hướng nào, privacy policy và nhãn App Privacy phải nói đúng như hướng đã chọn.
2. **Privacy policy (vi + en) đăng công khai**, điền vào ASC và thêm link trong app (Cá nhân → "Chính sách quyền riêng tư"). Chính sách phải nêu: dữ liệu gì, lưu ở đâu (máy + iCloud riêng), chia sẻ với bố bé ra sao, cách xóa, không có bên thứ ba ([G] 5.1.1(i), [I]).
3. **Support URL** có email liên hệ thật ([V]).
4. **Thêm `Widgets/PrivacyInfo.xcprivacy`** khai UserDefaults `1C8F.1`, rồi khai trong `project.yml` cho target widget ([R]).
5. **Bác sĩ duyệt xong toàn bộ nội dung y khoa.** Không còn `reviewed: false`, và build gửi duyệt có `LunaContentPreview = NO` ([G] 1.4.1, 2.1).
6. **Icon thật 1024×1024** thay icon tạm ([G] 2.1).
7. **Deploy schema CloudKit lên Production** cho đủ record type và field (nếu vẫn giữ CloudKit) ([C]).
8. **Thêm "Xóa toàn bộ dữ liệu"** trong Cá nhân (local + iCloud + zone `PartnerShare`). Nếu chưa làm kịp, privacy policy phải hướng dẫn xóa qua Cài đặt iOS → iCloud.
9. **Trả lời bảng câu hỏi Age rating mới.** Medical/Treatment: Frequent, dự kiến ra 16+ ([A]).
10. **Khai DSA trader status** ([D]), điền Copyright và thông tin liên hệ App Review.
11. **Notes for Review cụ thể:** cách thử Live Activity, chế độ bố bé (cần 2 Apple ID, kèm video), lý do dùng `remote-notification`, dữ liệu không rời iCloud của người dùng, và app không phải thiết bị y tế ([G] 2.3.1).
12. Thêm một dòng "không thay thế lời khuyên của bác sĩ" ở cuối bài tuần và bài kiến thức (không bắt buộc, nhưng giúp an toàn hơn với 1.4.1).
13. Xác nhận quyền thương mại của ảnh AI; kiểm tra `aps-environment` trên IPA phát hành.

---

## 3. App có cần đăng nhập, Sign in with Apple hay xóa tài khoản không?

**Không cần cả ba.**

- **Đăng nhập / tài khoản riêng:** 5.1.1(v) viết "let people use it without a login" khi app không có tính năng gắn với tài khoản ([G] 5.1.1(v)). Luna Mom không có server và không có tài khoản riêng; iCloud là tài khoản hệ thống của thiết bị, không phải tài khoản do app tạo.
- **Sign in with Apple:** 4.8 chỉ áp dụng khi app dùng dịch vụ đăng nhập bên thứ ba để tạo hoặc xác thực "primary account" của app ([G] 4.8). App không có đăng nhập nên không áp dụng.
- **Xóa tài khoản:** chỉ bắt buộc "If your app supports account creation" ([G] 5.1.1(v)). App không cho tạo tài khoản nên không bắt buộc. Tuy vậy vẫn nên có "Xóa toàn bộ dữ liệu" (việc số 8), vì privacy policy phải nêu cách xóa dữ liệu ([G] 5.1.1(i)).
- **Khi người dùng chưa đăng nhập iCloud**, app phải:
  - Chạy đầy đủ trên máy. SwiftData `.automatic` vẫn lưu cục bộ, chỉ không đồng bộ. Cần kiểm thử trên máy thật đã đăng xuất iCloud.
  - Không chặn hay ép đăng nhập. Chế độ bố bé đã hiện "Sign in to iCloud" (`partner.iCloud.*`, `ensureAccount()`), đúng tinh thần 5.1.1(iv) và 5.1.2(i).
  - Nên báo một dòng trong Cá nhân rằng iCloud đang tắt và dữ liệu chỉ có trên máy này.
  - Kiểm thử trường hợp đổi Apple ID: dữ liệu đồng bộ của tài khoản cũ có thể bị gỡ khỏi máy.
