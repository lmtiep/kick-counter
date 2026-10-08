# Rà soát tuân thủ App Store — Luna Mom

Ngày đọc tài liệu Apple: **2026-10-08**. Trang App Review Guidelines khi đọc không hiện ngày cập nhật.
Đã đối chiếu với repo trên nhánh `feat/fetus-artwork` (commit `6e93122`).
Lời trích từ Apple được giữ ngắn và luôn kèm URL. Tài liệu này **không phải tư vấn pháp lý**.

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
| **Không lưu thông tin sức khỏe cá nhân trong iCloud.** Apple viết: "may not store personal health information in iCloud." | [G] 5.1.3(ii) | **Cần kiểm tra — rủi ro cao** | Kick, kỳ kinh, LH/BBT, triệu chứng, cân nặng, lịch khám được SwiftData đồng bộ lên iCloud (`KickPersistence.swift`, `cloudKitDatabase: .automatic`). Bản snapshot chia sẻ với bố bé cũng nằm trong iCloud (`CloudPartnerSharing.swift`). Câu chữ của mục này **không phân biệt** HealthKit với dữ liệu người dùng tự nhập. Cần quyết định trước khi gửi duyệt (xem mục 2, việc số 1). |
| Ứng dụng y tế: nêu rõ dữ liệu và phương pháp khi đưa ra con số sức khỏe | [G] 1.4.1 | Đạt | Cân nặng thai theo Hadlock có ghi chú sai số (`pregnancy.baby.estimateNote`, `standardEnds`). Ngày dự sinh ghi rõ "280 ngày". Dự đoán chu kỳ ghi "chỉ là ước tính". Giữ nguyên như vậy. |
| Nhắc người dùng hỏi bác sĩ: "remind users to check with a doctor" | [G] 1.4.1 | Đạt | Có ở `medical.body` (onboarding bước 1, luôn hiện) và `medical.sources.note`. Nên thêm một dòng ngắn "Không thay thế lời khuyên của bác sĩ" ở cuối mỗi bài tuần và bài kiến thức (hiện chỉ có trong Thông tin y tế). |
| Nội dung y khoa chính xác, có nguồn | [G] 1.4.1 | **Thiếu** | Nội dung còn chờ bác sĩ duyệt (`reviewed: false`; xem `docs/content-review-for-doctor.md`). Phải duyệt xong và gửi bản build với `LunaContentPreview = NO`. |
| Không dùng làm biện pháp tránh thai | [G] 1.4 / 1.4.1 | Đạt | Đã có `cycle.disclaimer`, `cycle.notContraception`, `medical.ttc.body`. Đưa câu này vào mô tả App Store (checklist đã ghi). |
| Gửi bản hoàn chỉnh, URL hoạt động, không có nội dung tạm | [G] 2.1(a) | **Thiếu** | Icon vẫn là icon tạm (release-checklist). Nội dung chờ duyệt. Không cần tài khoản demo vì app không có đăng nhập. |
| Ghi rõ tính năng trong Notes for Review, không có tính năng ẩn | [G] 2.3.1(a) | Cần kiểm tra | Notes phải mô tả cụ thể: 3 chế độ, Live Activity, chia sẻ cho bố bé (cần 2 Apple ID, nên gửi kèm video), dữ liệu nằm trong iCloud riêng của người dùng. Cờ `LunaContentPreview` và tham số launch của UI test không được bật trong bản release. |
| Ảnh chụp cho thấy app đang dùng; metadata phù hợp 4+ | [G] 2.3.3, 2.3.8 | Cần kiểm tra | Có ảnh vi/en trong `ci-artifacts/screenshots/`. Ảnh thai nhi giữ ở mức minh họa. Không dùng cụm "For Kids". |
| Tên ≤ 30 ký tự, từ khóa đúng nội dung | [G] 2.3.7 | Đạt | "Luna Mom". Không nhồi tên app khác vào từ khóa. |
| Chế độ nền chỉ dùng đúng mục đích | [G] 2.5.4 | Đạt | Chỉ có `remote-notification`, dùng cho push im lặng của CloudKit. Ghi một dòng giải thích trong Notes. |
| App tự chứa, không tải code | [G] 2.5.2 | Đạt | Nội dung JSON được đóng gói sẵn trong bundle. |
| Business (miễn phí, không IAP) | [G] 3 | Đạt | Không có IAP hay quảng cáo. |
| Tính năng tối thiểu | [G] 4.2 | Đạt | App có nhiều tính năng gốc (đếm, Live Activity, lịch, chia sẻ). |
| Sign in with Apple / dịch vụ đăng nhập | [G] 4.8 | Không áp dụng | App không có đăng nhập bên thứ ba và không có tài khoản riêng (xem mục 3). |
| **Privacy policy: có link trong ASC và trong app**. Apple viết: "link to their privacy policy in the App Store Connect metadata field and within the app". | [G] 5.1.1(i), [I] | **Thiếu** | Repo không có URL chính sách nào. Cần trang công khai (vi + en) và một dòng "Chính sách quyền riêng tư" trong Cá nhân (`ProfileView`) mở link đó. Chính sách phải nêu cách người dùng xóa dữ liệu. |
| Đồng ý và rút lại đồng ý khi thu thập dữ liệu | [G] 5.1.1(ii) | Đạt | Developer không thu thập dữ liệu nào. Việc chia sẻ cho bố bé do người dùng chủ động bật, có mô tả rõ phạm vi (`partner.share.privacy`) và có thể ngừng chia sẻ. |
| Chỉ xin quyền cần thiết; không ép người dùng cấp quyền | [G] 5.1.1(iii)(iv), 5.1.2(i) | Đạt | Chỉ xin quyền thông báo. Từ chối quyền thì app vẫn chạy (checklist có kiểm thử). |
| Xin quyền thông báo đúng ngữ cảnh, không hỏi ngay lần mở đầu | [N] | Đạt | Hỏi khi chạm đếm lần đầu, khi ghi kỳ kinh đầu tiên, khi bật nhắc lịch hẹn (`requestAuthorizationIfNeeded`). |
| Không bắt đăng nhập; không đòi thông tin cá nhân nếu không cần | [G] 5.1.1(v) | Đạt | Không có đăng nhập. Ngày dự sinh/kỳ kinh cuối có nút "Để sau". |
| Xóa tài khoản trong app | [G] 5.1.1(v) | Không áp dụng | Chỉ bắt buộc khi app cho tạo tài khoản. |
| Cho người dùng xóa toàn bộ dữ liệu | [G] 5.1.1(i) (chính sách phải nêu cách xóa) | **Thiếu (nên có)** | Hiện chỉ có "Xóa thông tin thai kỳ" và vuốt để xóa từng mục. Nên thêm "Xóa toàn bộ dữ liệu": xóa store SwiftData (kéo theo bản trong iCloud), App Group defaults và zone `PartnerShare`. Hiện cách duy nhất là Cài đặt iOS → iCloud → Quản lý dung lượng; nếu chưa làm tính năng này thì phải ghi rõ cách đó trong privacy policy. |
| Chia sẻ dữ liệu cá nhân cần sự cho phép rõ ràng | [G] 5.1.2(i) | Đạt | Bố bé chỉ nhận dữ liệu qua `CKShare` sau khi mẹ chủ động mời. Snapshot không chứa ghi chú, triệu chứng, cân nặng hay dữ liệu chu kỳ. |
| Không dùng dữ liệu sức khỏe cho quảng cáo / khai thác dữ liệu | [G] 5.1.3(i) | Đạt | Không có SDK, analytics hay server. |
| Kids | [G] 1.3, 5.1.4 | Không áp dụng | Không chọn Kids Category. |
| App Privacy "Data Not Collected" | [P] | Đạt (theo cách hiểu) | "Collect" là gửi dữ liệu ra khỏi máy để "you and/or your third-party partners" truy cập được. Dữ liệu trong iCloud riêng/`CKShare` thì developer không truy cập được. Apple không có câu nào nói riêng về CloudKit; đây là cách hiểu phổ biến. Privacy policy phải viết nhất quán với nhãn này. |
| Privacy manifest của app | [R] | Đạt | `App/PrivacyInfo.xcprivacy` khai UserDefaults `CA92.1` (dữ liệu chỉ app đọc được) và `1C8F.1` (App Group) — đúng mã. grep không thấy API về timestamp file, boot time, dung lượng đĩa hay bàn phím. |
| **Privacy manifest của widget extension** | [R]: mỗi bundle chứa executable dùng API cần lý do phải có manifest riêng | **Thiếu** | Widget đọc App Group defaults (`AppLanguage` qua `KickCore` / `AppLocale`) nhưng không có `PrivacyInfo.xcprivacy`. Thêm file `Widgets/PrivacyInfo.xcprivacy` (UserDefaults `1C8F.1`, `NSPrivacyTracking` false, không có collected types) và đưa vào resources của target `KickCounterWidgets` trong `project.yml`. |
| Age rating — bộ câu hỏi mới (2025) | [A] | Cần kiểm tra | Mục "Medical or Treatment Information": Infrequent → 13+, Frequent → 16+; "Health and wellness topics" → 9+. Nội dung tuần, cảnh báo và hướng dẫn đếm cử động gần như chắc là **Frequent → 16+** (hợp với người dùng trưởng thành). Không có UGC, chat, quảng cáo, web view. Trả lời trung thực. Hạn trả lời câu hỏi mới là 31/1/2026 (đã qua), nên app mới bắt buộc trả lời đủ. |
| Mã hóa xuất khẩu | [E] | Đạt | `ITSAppUsesNonExemptEncryption = false`. App chỉ dùng HTTPS/CloudKit của hệ thống, thuộc loại miễn trừ. |
| Privacy Policy URL trong ASC: "Required for iOS and macOS apps" | [I] | **Thiếu** | Xem dòng 5.1.1(i). |
| Support URL (bắt buộc, phải có thông tin liên hệ thật) | [V] | **Thiếu** | Tạo trang hỗ trợ có email liên hệ (có thể dùng chung site với privacy policy). Điền thêm Copyright và liên hệ App Review. |
| DSA trader status (EU) | [D] | Cần kiểm tra | Bắt buộc khai, kể cả khi không bán ở EU. App miễn phí của cá nhân thường khai "not a trader". Nếu khai trader, địa chỉ, SĐT và email sẽ hiện công khai. |
| Deploy schema CloudKit lên Production. Apple viết: "Apps in the App Store can access only the production environment." | [C] | Cần kiểm tra | Checklist đã liệt kê `CD_KickSession`, `CD_Kick`, `CD_Appointment`, `CD_PeriodEntry`, `CD_CycleLog` (cùng field mới), `CD_WeightEntry`, `Snapshot`. Xác nhận trong CloudKit Console rằng tất cả đã ở Production trước khi gửi duyệt. |
| `aps-environment` = production trong bản phát hành | [C] (CloudKit push) | Cần kiểm tra | `project.yml` để `development`. Khi export `app-store-connect` (`scripts/release.sh`), Xcode tự đổi theo profile phân phối. Kiểm tra bằng `codesign -d --entitlements - <app>` trên bản IPA. |
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
