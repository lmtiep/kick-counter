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
