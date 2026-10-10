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
  "Khôi phục từ file" mở trình chọn tệp. App không tự ghi lên iCloud và file không mã hoá (có ghi chú dưới hàng).
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

## Kích thước theo tuần (giai đoạn 11)
- Từ tuần 10, câu "Bé lớn cỡ nào?" so sánh **cân nặng** ("tương đương một quả mận"): `size.typicalGrams` / `size.sourceKey`
  và `produceSources` trong `pregnancy-content.json` (phiên bản 4); `ContentValidator` buộc có nguồn và lệch không quá
  ±25 % so với `weightG` (Hadlock 1991). Tuần 4–9 giữ so sánh cũ.
- Bảng và nguồn: `docs/research/2026-10-08-produce-weights.md` (bản máy đọc `.json`; test `BundledContentTests` so khớp).
- Tranh thai nhi theo tuần: `docs/design/fetus-artwork-brief.md`. Bác sĩ duyệt: `docs/content-review-for-doctor.md` mục 13.
