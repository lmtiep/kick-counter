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
- Bài viết: trường `article` của mỗi tuần trong `pregnancy-content.json` (phiên bản 3). Thêm hoặc sửa bằng
  `scripts/set-week-articles.py` (JSON qua stdin, xem đầu file; in số chữ mỗi thẻ). Kiểm tra tự động:
  `scripts/test-core.sh --filter "BundledArticleTests|WeekArticleChecksTests"`.
- Câu "Bé lớn cỡ nào?" tự sinh từ số liệu Hadlock (`KickCore/WeekSizeLine.swift`, mẫu câu `weekArticle.size.*`).
- Ảnh riêng từng tuần (chưa có): thêm asset `Fetus-W##` / `Fruit-W##` (ví dụ `Fetus-W31`) vào
  `App/Images.xcassets`; khi thiếu, app dùng ảnh `Fetus` chung và emoji kích thước.
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
