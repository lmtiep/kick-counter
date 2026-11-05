# Luna Mom

App iPhone cho mẹ: theo dõi chu kỳ khi mong con (kỳ kinh, rụng trứng, cửa sổ thụ thai),
theo dõi thai kỳ từng tuần và đếm cử động thai theo phương pháp đếm đến 10.
(Tên dự án và bundle ID vẫn là `KickCounter` / `kick-counter`.)

## Phát triển không cần Xcode
- Logic (`Packages/KickCore`) test local: `scripts/test-core.sh`
- Mọi thứ khác (SwiftData, build iOS, UI test, ảnh chụp) chạy trên GitHub Actions:
  push rồi chạy `scripts/ci-wait.sh`; ảnh chụp nằm ở `ci-artifacts/screenshots/`.
- Bật pre-push hook (mỗi bản clone một lần): `git config core.hooksPath .githooks`

## Có Xcode
    brew install xcodegen && xcodegen generate && open KickCounter.xcodeproj

Dự án Xcode được sinh từ `project.yml` — sửa `project.yml`, không sửa `.xcodeproj`.

## Phát hành TestFlight
    gh workflow run testflight.yml

## Thai kỳ (giai đoạn 2)
- Nội dung theo tuần: `Packages/KickCore/Sources/KickCore/Resources/pregnancy-content.json`
  (song ngữ, kiểm định bằng `scripts/test-core.sh`). Bác sĩ duyệt → đổi `reviewed` thành `true`.
- Bản TestFlight (`CONTENT_PREVIEW=1`) hiện cả nội dung chưa duyệt; bản App Store chỉ hiện nội dung đã duyệt.
- Chuỗi giao diện mới: `scripts/add-strings.py` (xem đầu file).
- UI test: `-uiTesting -fixedNow <ISO8601>` cố định đồng hồ màn thai kỳ/lịch khám/chu kỳ,
  `-seedDueDate <ISO8601>` ghi sẵn ngày dự sinh,
  `-seedCycles <empty|period|fertile|late|irregular>` bật chế độ Mong con với dữ liệu mẫu
  (`CycleSeedScenario`), `-seedSessions` thêm 4 tuần lượt đếm mẫu (`SessionSeed`),
  `-seedOverdueSession` mở một lượt đếm đã quá 2 giờ, `-seedWeights` ghi cân trước mang thai 52 kg, chiều cao
  160 cm và cân nặng mẫu các tuần 12–30 (`WeightSeed`, cần `-seedDueDate`). Chỉ có hiệu lực trong bản Debug và
  cùng `-uiTesting` (khi đó animation cũng tắt để ảnh chụp ổn định).

## Giao diện (giai đoạn 4)
- Thiết kế tham chiếu: `docs/design/mam-handoff/` (README + `prototype.html`; "Mầm" = Luna Mom).
- Màu: token trong `Packages/KickCore/Sources/KickCore/LunaPalette.swift` (sáng + tối, test tương phản
  WCAG trong `ContrastTests`); view dùng `.luna(.<token>)`, không viết hex.
- Font: Be Vietnam Pro (SIL OFL, `App/Fonts/OFL.txt`), dùng `Font.luna(_:)`.
- Thành phần dùng chung: `App/DesignSystem/`.
- Ngôn ngữ trong app (Cá nhân → Ngôn ngữ): `L10n` đọc `.lproj` của ngôn ngữ đã chọn (`AppLanguage`).

## Triệu chứng & cân nặng (giai đoạn 5)
- Lượng kinh / tâm trạng / triệu chứng: `KickCore/SymptomKinds.swift` (lưu trong `CycleLog` dạng raw tiếng Anh,
  giữ giá trị lạ), sheet Mong con `App/Cycle/CycleDayLogSheet.swift`, màn Mang thai `App/Symptoms/`.
- Cân nặng mẹ: `KickCore/Weight*.swift` + `MaternalProfile.swift` (ngưỡng IOM 2009 trong `WeightGuidance.swift`,
  chờ bác sĩ duyệt — `docs/content-review-for-doctor.md` mục 8), màn `App/Weight/`, lưu `WeightEntry` (iCloud).

## Bài viết theo tuần (giai đoạn 6)
- Chi tiết tuần: nền cố định (ảnh thai nhi + hàng chip tuần) dưới một sheet kéo được hai nấc
  (`App/DesignSystem/ArticleSheet.swift`, quy tắc thả tay `KickCore/SheetDetentResolver.swift`), thẻ Bé / Mẹ
  trong `App/Pregnancy/WeekArticleView.swift`.
- Bài viết: trường `article` của mỗi tuần trong `pregnancy-content.json` (từ phiên bản 3). Thêm hoặc sửa bằng
  `scripts/set-week-articles.py` (JSON qua stdin, xem đầu file; in số chữ mỗi thẻ). Kiểm tra tự động:
  `scripts/test-core.sh --filter "BundledArticleTests|WeekArticleChecksTests"`.
- Câu "Bé lớn cỡ nào?" tự sinh từ số liệu Hadlock (`KickCore/WeekSizeLine.swift`, mẫu câu `weekArticle.size.*`).
- Ảnh riêng từng tuần: ảnh trái cây `Fruit-W04…W42` (SVG, giai đoạn 11) và ảnh thai nhi `Fetus-W04…W42` (PNG
  1024×1024 nền trong suốt, @3x) đều đã có. Ảnh thai nhi mới: xoá nền, căn giữa và nén bằng lệnh `luna-art --white-bg`
  (rembg + pngquant, cài ở máy dev), rồi đặt vào `App/Images.xcassets/Fetus-W##.imageset`. Khi thiếu ảnh, app dùng
  ảnh `Fetus` chung và emoji kích thước.
- Nội dung vẫn chờ bác sĩ duyệt: `docs/content-review-for-doctor.md` mục 9.

## Kiến thức chuyên sâu (giai đoạn 7)
- 18 bài viết trong 6 chủ đề, gắn tam cá nguyệt: `Packages/KickCore/Sources/KickCore/Resources/knowledge-content.json`
  (phiên bản 1; mô hình `KickCore/KnowledgeContent.swift`, nạp bằng `KnowledgeLibrary`, lỗi thì ẩn thẻ và thư viện).
- Hôm nay (mang thai): thẻ "Gợi ý cho tam cá nguyệt N" (`App/Knowledge/KnowledgeCard.swift`), 3 bài chọn bởi
  `KickCore/KnowledgeSuggester.swift` (cùng tuần cùng kết quả, tuần sau đổi bài đầu, ưu tiên mỗi chủ đề một bài).
- Thư viện "Kiến thức" (`KnowledgeLibraryView`) và màn đọc (`KnowledgeArticleView`, dùng `ArticleSheet` hai nấc).
  Phần chữ dùng chung với Chi tiết tuần: `App/DesignSystem/ArticleText.swift`.
- Thêm hoặc sửa bài: `scripts/set-knowledge-articles.py` (JSON qua stdin, xem đầu file; in số chữ). Kiểm tra tự
  động: `scripts/test-core.sh --filter "BundledKnowledgeTests|KnowledgeChecksTests"`.
- Ảnh riêng từng bài (chưa có): thêm asset `Knowledge-<id>` (ví dụ `Knowledge-safe-exercise`) vào
  `App/Images.xcassets`; khi thiếu, app vẽ biểu tượng SF Symbol của chủ đề.
- Nội dung chờ bác sĩ duyệt: `docs/content-review-for-doctor.md` mục 10. Bản App Store chỉ hiện bài đã duyệt.

## Chia sẻ với bố bé (giai đoạn 8)
- Mẹ (chế độ Mang thai) mời qua iCloud ở Cá nhân → "Chia sẻ với bố bé"; bố bé cài app, chạm lời mời và vào
  **chế độ Bạn đời** chỉ xem (Hôm nay · Kiến thức · Cá nhân). Đặc tả: `docs/superpowers/specs/2026-10-07-partner-design.md`.
- Dữ liệu chia sẻ là một bản `PartnerSnapshot` (`KickCore/PartnerSnapshot.swift`, JSON phiên bản 1), dựng bởi
  `PartnerSnapshotBuilder` — hàm này không nhận ghi chú, triệu chứng, cân nặng hay dữ liệu chu kỳ.
- iCloud: zone riêng `PartnerShare` trong cơ sở dữ liệu riêng của mẹ, một record `Snapshot` tên `current`, chia sẻ cả
  zone ở quyền chỉ xem (`App/Partner/CloudPartnerSharing.swift`, chỉ file này và các delegate trong `App/Partner/`
  dùng CloudKit). Kho SwiftData và đồng bộ riêng của nó không đổi.
- Logic kiểm thử được nằm trong KickCore (`scripts/test-core.sh`): giao thức `PartnerSharing` và bản giả
  `FakePartnerSharing`, `PartnerShareCoordinator`, `PartnerPublisher` (gom thay đổi, tải lên 5 giây sau thay đổi
  cuối), `PartnerJourneyModel`, `PartnerAcceptance`.
- Lời mời: `PartnerAppDelegate` / `PartnerSceneDelegate` (`App/Partner/PartnerAppDelegate.swift`) nhận
  `CKShare.Metadata`; `CKSharingSupported` khai báo trong `project.yml`.
- UI test: `-uiTestingSharing <notShared|invited|joined|icloudUnavailable>` (phía mẹ) và
  `-uiTestingPartner <snapshot|stopped|error|icloudUnavailable|notReadyYet>` (vào thẳng chế độ Bạn đời với dữ liệu mẫu tuần 24)
  dùng `FakePartnerSharing`; chỉ có hiệu lực cùng `-uiTesting`. Không UI test nào chạm iCloud.
- Chia sẻ thật chỉ thử bằng tay với hai Apple ID: `docs/partner-sharing-manual-test.md`. Trước khi phát hành:
  record type `Snapshot` phải được deploy lên Production (`docs/release-checklist.md`, "Giai đoạn 8").

## Mục tiêu "Theo dõi chu kỳ" và phần giới thiệu mới (giai đoạn 9)
- Chế độ chu kỳ có **mục tiêu** (`CycleGoal`): `tracking` (theo dõi kỳ kinh) hoặc `conceiving` (mong con). Cùng dữ liệu,
  lịch và dự đoán; mục tiêu chỉ đổi cách trình bày. Đặc tả: `docs/superpowers/specs/2026-10-08-cycle-tracking-design.md`.
- Lưu trong App Group, không đồng bộ (`CyclePreferences` trong `KickCore/CycleGoal.swift`): mục tiêu (mặc định
  `conceiving`, nên người dùng cũ giữ nguyên mọi thứ), biện pháp tránh thai (`Contraception`, nil = chưa hỏi), độ đều
  (`CycleRegularity`) và công tắc hiện que thử LH/nhiệt độ khi theo dõi chu kỳ.
- `CycleDisplayPolicy` (`KickCore/CycleDisplayPolicy.swift`, thuần, có test) quyết định màn hình nào hiện gì: tên cửa sổ
  thụ thai, ghi chú "không phải biện pháp tránh thai", ẩn cửa sổ và ngày rụng trứng khi dùng biện pháp có nội tiết, "Ra
  máu dự kiến", có hiện LH/BBT không, và loại nhắc nhở (`reminderKinds`). Hôm nay, Lịch, phần ghi ngày và
  `CycleCoordinator` (nhắc nhở) đều đọc `cycle.policy`.
- Phần giới thiệu: `OnboardingFlow` (`KickCore/OnboardingFlow.swift`) giữ câu trả lời và thứ tự bước cho từng nhánh
  (theo dõi 8 bước, mong con 7, mang thai 4), cách bỏ qua, "Không nhớ", dự đoán ở bước kết quả và những gì cần lưu
  (`finish()`). `OnboardingView` chỉ hiển thị; nhánh chu kỳ lưu qua `CycleCoordinator.completeOnboarding(…)`
  (chỉ hỏi quyền thông báo khi chọn "Bật nhắc nhở").
- Cá nhân: thẻ "Mục tiêu" có ba lựa chọn (Theo dõi chu kỳ · Mong con · Mang thai); hai lựa chọn chu kỳ cùng đi qua
  `CycleCoordinator.activateCycleMode(goal:)`, nên rời chế độ Mang thai bằng lựa chọn nào cũng dừng chia sẻ với bố bé
  (`RootView`, giai đoạn 8). Khi theo dõi chu kỳ, thẻ Chu kỳ có thêm "Biện pháp tránh thai" và công tắc LH/BBT.
- UI test: `-seedCycleGoal <tracking|conceiving>` và `-seedContraception <pill|condom|…>` (cùng `-uiTesting`, thường đi với
  `-seedCycles`); không có hai cờ này là người dùng cũ (mong con).

## Lịch sử chu kỳ (giai đoạn 10)
- Lịch sử chu kỳ: độ dài trung bình, khoảng dao động, từng chu kỳ và những ngày đã ghi. Đặc tả:
  `docs/superpowers/specs/2026-10-08-cycle-history-design.md`.
- `CycleHistory.make` (`KickCore/CycleHistory.swift`, thuần, có test) dựng tóm tắt và danh sách chu kỳ từ `PeriodRecord`
  và `CycleLogRecord`, dùng cùng quy tắc trung bình với `CyclePredictor`. `CycleHistoryView`/`CycleDetailView`
  (`App/Cycle/CycleHistoryView.swift`) đọc `cycle.periods`/`cycle.logs`, nên tự cập nhật sau khi ghi ngày.
- Giai đoạn 13: nút "Thêm kỳ kinh trước đây" (`App/Cycle/AddPastPeriodSheet.swift`,
  `CycleCoordinator.addPastPeriod`) ghi bù kỳ kinh cũ; bắt đầu kỳ kinh ở một ngày đã qua đủ lâu thì kỳ đó được đóng ở
  độ dài thường gặp. Đặc tả: `docs/superpowers/specs/2026-10-08-past-periods-design.md`.
- Giai đoạn 19: nút "Sửa kỳ kinh" trên Lịch (`App/Cycle/CalendarPeriodEditor.swift`) cho tích những ngày có kinh đã
  qua, qua nhiều tháng, rồi lưu một lần. `PeriodEditPlan` (`KickCore`, thuần, có test) so các ngày đã tích với kỳ kinh
  đã ghi thành xoá/sửa/thêm; `CycleCoordinator.applyPeriodEdits` lưu tất cả trong một lần (lỗi thì không lưu gì).
  Đặc tả: `docs/superpowers/specs/2026-10-10-calendar-period-edit-design.md`.

## Sẵn sàng lên App Store (giai đoạn 12)
- Bản 1.0 giữ toàn bộ dữ liệu trên máy: `KickCore/AppFeatures.swift` (`cloudSync = false`),
  `KickPersistence` dùng `cloudKitDatabase: .none`. Chế độ chia sẻ với bố bé (giai đoạn 8) bị ẩn cùng với
  switch này — mã vẫn còn, để bật lại ở phiên bản sau (cách khôi phục: `docs/release-checklist.md`,
  "Giai đoạn 12").
- "Xoá toàn bộ dữ liệu" (Cá nhân, hàng cuối): xóa mọi lượt đếm, kỳ kinh, ghi chép, cân nặng, lịch khám và
  cài đặt trên máy, hủy mọi thông báo và Live Activity đang chạy, rồi về onboarding
  (`KickData/DataReset.swift`, `KickCore/AppDataReset.swift`).
- Cuối mục Cá nhân, dưới "Thông tin y tế", có hai liên kết mở Safari: "Chính sách quyền riêng tư" và "Hỗ trợ"
  (`App/AppLinks.swift`), dẫn tới các trang tĩnh trong `site/` (xuất bản qua GitHub Pages, nhánh `gh-pages`):
  trang chủ, chính sách quyền riêng tư và hỗ trợ, cả vi và en, không script hay theo dõi.
- Lời hứa quyền riêng tư (1.1): bước chào mừng của onboarding nêu bốn dòng — miễn phí, không quảng cáo, không cần
  tài khoản, dữ liệu chỉ nằm trên iPhone; Cá nhân → "Quyền riêng tư của bạn" (`App/Settings/PrivacyPromiseView.swift`)
  nhắc lại bốn ý đó. Chỉ nói những gì app làm thật, khớp nhãn "Data Not Collected".
- `Widgets/PrivacyInfo.xcprivacy` khai báo quyền riêng tư của widget (không thu thập dữ liệu, chỉ đọc
  UserDefaults của App Group).
- Các capability không còn dùng đã gỡ: `remote-notification`, `CKSharingSupported`, và entitlement iCloud
  (`aps-environment`, container/services) — chỉ giữ App Group.
- Tài liệu: `docs/app-store-compliance.md` (bảng kiểm, các mục đã giải quyết đánh "Đạt (giai đoạn 12)"),
  `docs/app-review-notes.md` (ghi chú dán vào App Store Connect), `docs/release-checklist.md` ("Giai đoạn 12").
- Việc còn lại thuộc về chủ dự án: bác sĩ duyệt nội dung y khoa, icon chính thức, bật GitHub Pages, điền
  thông tin App Store Connect (xem checklist).

## Sao lưu & khôi phục (giai đoạn 15)
- Cá nhân → "Dữ liệu" (trên "Xoá toàn bộ dữ liệu"): "Sao lưu ra file" tạo `LunaMom-YYYY-MM-DD.lunamom` rồi mở bảng chia
  sẻ của iOS (Tệp, iCloud Drive, AirDrop, Zalo…); "Lần sao lưu gần nhất" chỉ ghi khi chia sẻ xong (`lastBackupAt`).
  "Khôi phục từ file" mở trình chọn tệp. App không tự ghi lên iCloud; file chỉ được mã hoá khi đặt mật khẩu (1.1, xem dưới).
- Mở một file `.lunamom` từ app khác (UTType `com.lmtiep.kickcounter.backup`, khai báo trong `project.yml`) hoặc chọn
  "Khôi phục từ bản sao lưu" ở bước đầu của onboarding cũng mở trang khôi phục: tóm tắt file, cảnh báo thay toàn bộ
  dữ liệu, rồi khôi phục **tất cả hoặc không gì cả** (`KickData/BackupStore.replaceAll`, một lần lưu, rollback khi
  lỗi). File lỗi chỉ hiện thông báo, không đụng tới dữ liệu.
- Định dạng: JSON có phiên bản (`KickCore/Backup.swift`, `BackupCodec.swift`, `BackupSettings.swift`); bảng cài đặt
  là `AppDataReset.ownedKeys` trừ khoá chia sẻ với bố bé và `hasCompletedOnboarding` (test buộc khớp). File mẫu cho UI
  test `UITests/Fixtures/sample.lunamom` do encoder của KickCore tạo:
  `WRITE_BACKUP_FIXTURE=1 scripts/test-core.sh --filter BackupFixtureTests`.
- Đặc tả: `docs/superpowers/specs/2026-10-09-backup-design.md`. Kiểm thử hai máy: `docs/release-checklist.md`
  ("Giai đoạn 15").

## Sao lưu có mật khẩu, lời nhắc, chuyển sang iPhone mới (1.1)
- "Sao lưu ra file" mở trước bước "Bảo vệ file bằng mật khẩu" (`BackupExportSheet`), **bật sẵn**, người dùng có thể
  tắt. Mật khẩu ≥ 6 ký tự, nhập hai lần, có nút hiện/ẩn, cảnh báo quên mật khẩu là mất file. Mật khẩu chỉ nằm trong
  state của trang (xoá khi tạo xong file hoặc đóng trang), không lưu, không ghi log.
- Định dạng mã hoá (`KickCore/BackupEncryption.swift`, chỉ dùng thư viện của Apple): `LUNAENC1` (8 byte) · phiên bản
  (1) · KDF (1 = PBKDF2-HMAC-SHA256, CommonCrypto) · số vòng `UInt32` big-endian (mặc định 600 000, đọc từ file, chỉ
  nhận 100 000–3 000 000) · salt 16 byte · nonce AES-GCM 12 byte · ciphertext · tag 16 byte. 42 byte đầu là dữ liệu
  xác thực (AAD) của AES-GCM (CryptoKit); bên trong là đúng JSON sao lưu cũ. Mật khẩu chuẩn hoá NFC trước khi dẫn
  khoá. Sai mật khẩu hay file bị sửa đều là `.wrongPassword`, không trả dữ liệu nào. File thường (JSON) không đổi,
  nhận biết bằng 8 byte đầu. File mẫu có mật khẩu cho UI test: `UITests/Fixtures/sample-protected.lunamom` (mật khẩu
  `matkhau123`), tạo lại cùng lệnh `WRITE_BACKUP_FIXTURE=1` ở trên.
- Mở file có mật khẩu: trang hỏi mật khẩu (`UnlockBackupView`); sai thì "Mật khẩu không đúng", thử lại, không đổi gì;
  đúng thì vào trang khôi phục như cũ.
- Thẻ "Đã lâu chưa sao lưu" ở đầu mục Dữ liệu (`BackupReminderPolicy`): lần sao lưu gần nhất ≥ 30 ngày, hoặc chưa
  sao lưu lần nào và đã dùng app ≥ 14 ngày; "Để sau" ẩn 14 ngày. Chỉ trong app, không có thông báo. Khoá
  `backupFirstUseAt`, `backupReminderSnoozedAt` thuộc `ownedKeys` và không vào file sao lưu. UI test:
  `-seedLastBackupDaysAgo <ngày>`.
- Cá nhân → Dữ liệu → "Chuyển sang iPhone mới": hướng dẫn 3 bước, bước 1 có nút mở luôn trang sao lưu.
- Đặc tả: `docs/superpowers/specs/2026-11-05-backup-plus-design.md`. Kiểm thử: `docs/release-checklist.md` ("1.1 — Sao
  lưu có mật khẩu").

## Nhắc uống thuốc tránh thai (giai đoạn 17)
- Chỉ khi theo dõi chu kỳ với biện pháp "Thuốc tránh thai hằng ngày": Cá nhân → Chu kỳ → "Nhắc uống thuốc" (dưới
  "Biện pháp tránh thai") mở `PillReminderSheet`: bật/tắt, loại vỉ (21 + 7 ngày nghỉ / 28 viên), ngày bắt đầu vỉ này
  (60 ngày gần nhất), giờ nhắc và đúng một câu về quên thuốc. Đổi sang biện pháp khác, sang "Mong có thai" hay mang
  thai thì huỷ nhắc nhở nhưng giữ cài đặt.
- Logic thuần ở KickCore: `PillPack` (ngày trong vỉ, tuần nghỉ, vỉ kế tiếp), `PillReminderPlan` (14 ngày uống thuốc
  tới, mỗi ngày `pill-YYYYMMDD` và `pill-YYYYMMDD-followup` sau 2 giờ, rồi `pill-renew` nhắc mở app; tối đa 29 yêu
  cầu, không có gì trong tuần nghỉ hay ngày đã đánh dấu), `PillCoordinator`. Ngày bắt đầu vỉ và ngày uống là **ngày
  lịch** (`CalendarDay`, yyyymmdd), nên đổi múi giờ không làm lệch viên. Sau nửa đêm, nếu viên hôm qua chưa đánh dấu
  và chưa tới giờ nhắc lại, thẻ Hôm nay hiện "Viên n/21 (hôm qua)". Nhắc lịch khám chỉ lên lịch 20 lịch gần nhất để
  tổng số thông báo chờ luôn dưới 64. Liều đã uống là model `PillDose` (KickData, một liều mỗi ngày), có trong
  xoá toàn bộ dữ liệu và trong file sao lưu (mảng `pillDoses` tuỳ chọn, vẫn phiên bản 1).
- Nút "Đã uống" trên thông báo (category `PILL_REMINDER`, action `PILL_TAKEN`) do `PillNotificationDelegate` — delegate
  thông báo duy nhất của app — ghi liều rồi bỏ lần nhắc lại. Ở Hôm nay có thẻ "Thuốc tránh thai".
- UI test: `-seedPill 21+7:<số ngày từ đầu vỉ>`; `PillReminderUITests`, `PillReminderScreenshotTests`. Kiểm thử trên
  máy thật: `docs/release-checklist.md` ("Giai đoạn 17").

## Đếm cơn gò (giai đoạn 20)
- Màn "Cơn gò" (`App/Contractions/ContractionTimerView.swift`): lối tắt "Cơn gò" ở Hôm nay từ tuần 28, và hàng "Đếm cơn
  gò" ở tab Đếm cử động (mọi tuần). Một nút lớn "Bắt đầu cơn gò" / "Hết cơn gò" có "Hoàn tác" trong 5 giây; thẻ "Trong 1
  giờ qua" (số cơn, dài TB, cách nhau TB); danh sách "Lần theo dõi này" (nút xoá từng cơn, có hỏi lại), "Kết thúc theo dõi" và
  "Lịch sử cơn gò" theo ngày (vuốt để xoá cả lần theo dõi). Câu an toàn luôn hiện.
- Logic thuần ở KickCore: `ContractionRules` (mọi ngưỡng), `ContractionStats` (lần theo dõi, giờ qua, cảnh báo),
  `ContractionCoordinator`. Từ tuần 37 (hoặc chưa biết tuần) là thẻ 5-1-1: ≥ 6 cơn trong giờ qua, cách nhau TB ≤ 5:30,
  dài TB ≥ 45 s, lần theo dõi đã ≥ 60 phút. Trước tuần 37 là thẻ khẩn: ≥ 4 cơn bắt đầu trong giờ qua, đếm cả sau khi
  "Kết thúc theo dõi". Cả hai thẻ có nút "Gọi cấp cứu 115" (`EmergencyCallButton`, dùng chung với thẻ 2 giờ khi đếm cử
  động). Cơn chạy quá 5 phút được đóng ở mốc 5 phút; cơn dưới 3 giây là bấm nhầm và bị bỏ; hai cơn cách nhau quá 2 giờ
  là hai lần theo dõi. Model `Contraction` (KickData) có trong xoá toàn bộ dữ liệu và file sao lưu (mảng `contractions`
  tuỳ chọn).
- Live Activity riêng (`Widgets/ContractionLiveActivityWidget.swift`, `Shared/ContractionActivityAttributes.swift`)
  chạy song song với Live Activity đếm cử động: nút "Bắt đầu" / "Hết cơn" trên màn hình khoá và Dynamic Island gọi
  `ToggleContractionIntent`, không mở app. `staleDate` = lần bắt đầu cuối + 2 giờ: hệ thống đánh dấu cũ, app kết thúc
  activity khi mở lại hoặc quay lại foreground.
- UI test: `-seedContractions 511|preterm`; `ContractionTimerUITests`, `ContractionTimerScreenshotTests`. Bác sĩ duyệt:
  `docs/content-review-for-doctor.md` mục 18 (96–100). Kiểm thử trên máy thật: `docs/release-checklist.md` ("Giai đoạn
  20").

## Kích thước theo tuần (giai đoạn 11)
- Từ tuần 10, câu "Bé lớn cỡ nào?" so sánh **cân nặng** ("tương đương một quả mận"): `size.typicalGrams` / `size.sourceKey`
  và `produceSources` trong `pregnancy-content.json` (phiên bản 4); `ContentValidator` buộc có nguồn và lệch không quá
  ±25 % so với `weightG` (Hadlock 1991). Tuần 4–9 giữ so sánh cũ.
- Bảng và nguồn: `docs/research/2026-10-08-produce-weights.md` (bản máy đọc `.json`; test `BundledContentTests` so khớp).
- Tranh thai nhi theo tuần: `docs/design/fetus-artwork-brief.md`. Bác sĩ duyệt: `docs/content-review-for-doctor.md` mục 13.

## Góp ý và xin đánh giá (giai đoạn 21)
- Cá nhân → "Gửi góp ý" mở màn soạn thư hệ thống tới lmtiep@gmail.com; phần thân chỉ ghi sẵn phiên bản app + build, iOS,
  mã máy, ngôn ngữ và chế độ (không có dữ liệu sức khỏe), người dùng bấm Gửi thì mới đi. Máy không gửi được thư thì mở
  `mailto:` cùng nội dung, cuối cùng là hiện địa chỉ để sao chép (`FeedbackEmail`, `App/Profile/FeedbackMail.swift`).
- Hộp xin đánh giá của Apple (`requestReview`) chỉ hiện ở lúc vui: xong một lượt đếm cử động đủ mục tiêu, ghi kỳ kinh thứ 3
  trở lên, lưu cân nặng sau 7 ngày dùng; không bao giờ sau khi dùng bộ đếm cơn gò, khi đang có thẻ cảnh báo, hay trong phần
  giới thiệu. Cần dùng app từ 3 ngày khác nhau, tối đa 1 lần/120 ngày, 3 lần/365 ngày, 1 lần cho mỗi phiên bản
  (`ReviewPromptPolicy`, trạng thái ở App Group, xóa khi "Xóa toàn bộ dữ liệu", không vào file sao lưu). Tắt hẳn trong UI test.

## Widget Màn hình chính và Màn hình khoá (1.1)
- Một widget "Luna Mom" thích ứng theo chế độ (`Widgets/Home/`): theo dõi chu kỳ (số ngày tới kỳ kinh + ngày, ngày kinh,
  trễ), đang chuẩn bị mang thai (trạng thái thụ thai hôm nay, ngày chu kỳ, dải 7 ngày cửa sổ thụ thai), mang thai (tuần,
  còn bao nhiêu ngày, quả/trái của tuần và "Cử động hôm nay" ở cỡ vừa), chế độ người thân hoặc chưa có dữ liệu thì hiện
  "Mở Luna Mom để bắt đầu". Cỡ: nhỏ, vừa, và Màn hình khoá (hình chữ nhật, một dòng, tròn). Chạm mở Hôm nay (`lunamom://today`),
  dòng cử động mở tab Đếm cử động (`lunamom://kicks`, `WidgetLink`).
- Số liệu là số của màn Hôm nay: logic thuần ở KickCore (`WidgetSnapshot` dựng từ `CyclePredictor`, `PregnancyTimeline`,
  `HistoryStats`; `WidgetLink`). Widget đọc App Group **chỉ đọc, trên máy** (`KickData.WidgetReader`: `allowsSave: false`, không
  gộp bản sao trong store, không CloudKit); không gửi gì đi đâu. Nội dung Màn hình khoá dùng `.privacySensitive()`.
- Timeline có mục cho mỗi nửa đêm của 3 ngày tới. App gọi `WidgetCenter.reloadAllTimelines()` qua `App/WidgetRefresh.swift`
  (gộp lại 0,6 giây) mỗi khi store lưu (`ModelContext.didSave`: kỳ kinh, nhật ký, phiên đếm, khôi phục, xoá toàn bộ), khi
  cài đặt dùng chung đổi (chế độ, mục tiêu, ngày dự sinh, ngôn ngữ), và khi app lên/xuống nền.
- Tranh quả theo tuần: `Widgets/FruitArt.xcassets` là bản sao `Fruit-W##` của app (actool không theo symlink; test
  `WidgetArtTests` giữ hai bản giống nhau). Phông Be Vietnam Pro nằm trong `UIAppFonts` của widget.
- Ảnh xem trước: `KickCounterWidgetTests/WidgetPreviewRenderTests` dựng mọi mẫu (vi/en, sáng/tối, 5 cỡ) ra PNG; chạy cục bộ
  `TEST_RUNNER_WIDGET_PREVIEW_DIR=/đường/dẫn xcodebuild -scheme KickCounter -only-testing:KickCounterWidgetTests test`.
- Kiểm thử trên máy thật: `docs/release-checklist.md` ("Widget 1.1").

## Siri, Nút Tác vụ và Trung tâm điều khiển (1.1)
- Ba lệnh: "Bắt đầu đếm cử động", "Bấm cơn gò", "Kết thúc theo dõi cơn gò" (Siri, Spotlight, Phím tắt không cần cài đặt; điều khiển
  cho Trung tâm điều khiển / Màn hình khoá / Nút Tác vụ từ iOS 18). Đặc tả: `docs/superpowers/specs/2026-11-06-siri-controls-design.md`.
- Quyết định nằm trong KickCore (`SiriPlanner`, thuần, có test) và chạy bởi `SiriControls`; các App Intent ở `Shared/SiriIntents.swift`,
  cụm từ ở `App/LunaShortcuts.swift` + `App/AppShortcuts.xcstrings`, điều khiển ở `Widgets/LunaControls.swift` (`@available(iOS 18, *)`).
- Câu trả lời ngắn, chung chung, không đọc số liệu. Ngoài chế độ Mang thai không bắt đầu gì cả. Phần chỉ thử được trên máy thật:
  `docs/release-checklist.md`.
