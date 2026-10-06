# Ghi triệu chứng & Cân nặng mẹ (Giai đoạn 5) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Với các task giao diện (4–6) áp dụng thêm skill `ui-ux-pro-max` để rà soát chi tiết thị giác — nhưng **không** đổi hành vi, accessibility identifier, chuỗi hay token màu đã định trong plan.

**Goal:** Thêm ghi lượng kinh / tâm trạng / triệu chứng cho cả hai chế độ (kèm màn "Triệu chứng" theo tuần thai và thẻ nhắc an toàn khi có "Cơn gò"/"Phù chân") và màn "Cân nặng" của mẹ ở chế độ Mang thai (mức tăng so với trước mang thai, dải khuyến nghị IOM 2009 theo BMI trước mang thai), dựng trên hệ thống thiết kế giai đoạn 4.

**Architecture:** Mọi phần tính được nằm trong `KickCore` (Swift thuần, test local): loại triệu chứng và mã hóa danh sách raw (`SymptomKinds.swift`), `CycleLogRecord`/`CycleRules` mở rộng (gộp trùng: hợp tâm trạng/triệu chứng, lượng kinh nặng hơn), tóm tắt một dòng (`CycleLogSummary.swift`), danh sách theo tuần (`SymptomTimeline.swift`), bản ghi/quy tắc cân nặng (`WeightRecords.swift`), dải IOM (`WeightGuidance.swift`), hồ sơ cân trước mang thai + chiều cao (`MaternalProfile.swift`, UserDefaults App Group), điểm biểu đồ/nhóm theo tuần (`WeightStats.swift`), `WeightCoordinator` (`@MainActor @Observable`) và dữ liệu mẫu (`WeightSeed.swift`). `KickData` thêm 3 trường raw vào `CycleLog` (giữ nguyên giá trị lạ) và model `WeightEntry` + `WeightStore` (CloudKit: chỉ thêm trường/record type). App thêm `App/Symptoms/` (chip xuống dòng bằng `FlowLayout`, sheet và màn Mang thai, thẻ an toàn) và `App/Weight/` (màn, biểu đồ Swift Charts, thẻ thiết lập, thẻ Hôm nay), sửa sheet ghi ngày Mong con, thẻ tóm tắt ở Hôm nay/Lịch, lối tắt Hôm nay Mang thai, Cá nhân.

**Máy dev không có Xcode.** Chỉ `KickCore` chạy được local qua `scripts/test-core.sh`. App, `KickData`, UI test và ảnh chụp chỉ được xác minh trên GitHub Actions: commit → `git push` → `scripts/ci-wait.sh`.

**Tech Stack:** Swift 6, SwiftUI (iOS 17), Swift Charts, SwiftData (+ CloudKit), Swift Testing, XCTest (UI), XcodeGen, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-05-symptoms-weight-design.md` (yêu cầu — làm đúng spec). Thiết kế tham chiếu: `docs/design/mam-handoff/README.md` §4, §8, "Bottom sheet – Ghi triệu chứng" + `prototype.html` (khối `<script data-dc-script>`: chuỗi `flowL`/`moodL`/`symL`/`weight*` trong `T`, `OPTS`, `SEED_W`, `PRE_KG`, `band`). Plan giai đoạn 4 tham khảo: `docs/superpowers/plans/2026-10-04-redesign.md`.

## Global Constraints

- iOS deployment target `17.0`; package platforms `.iOS(.v17), .macOS(.v14)`; Swift language mode 6. Không SDK bên thứ ba, không server, không thu thập dữ liệu.
- Làm việc trên nhánh `feat/phase5-symptoms-weight` (đã có, đang checkout). **Không bao giờ** đổi tài khoản/đăng nhập `gh`. Mọi commit message kết thúc bằng một dòng trống rồi `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (dùng `git commit -F - <<'MSG' … MSG` như trong từng task).
- **Phạm vi UI test trên CI:** `scripts/ci.sh` đọc dòng `CI-Only-Testing: ClassA, ClassB` trong message của commit HEAD khi push lên nhánh (không áp dụng cho PR, chạy tay hay `main`) và chỉ chạy các lớp UI test đó (`KickCore`/`KickData` vẫn chạy đủ). Dòng này đặt **ngay trước** dòng `Co-Authored-By` (cùng khối trailer, không dòng trống ở giữa). Commit của Task 1–6 có dòng này đúng như ghi trong task; commit cuối (Task 7) **không** có, để chạy toàn bộ bộ UI test.
- **Máy dev không có Xcode.** Local chỉ chạy được `scripts/test-core.sh` (cũng là pre-push hook `.githooks/pre-push`). App, `KickData`, UI test, ảnh chụp: chỉ trên CI qua `git push` + `scripts/ci-wait.sh`; ảnh ở `ci-artifacts/screenshots/`.
- **`KickCore` không được import SwiftUI, UIKit hay SwiftData.** Logic test được (raw ↔ enum, gộp trùng, tóm tắt, nhóm theo tuần, quy tắc cân nặng, BMI/IOM, hồ sơ, điểm biểu đồ, coordinator, dữ liệu mẫu) nằm trong `KickCore` với test Swift Testing. App chỉ hiển thị.
- Model SwiftData tương thích CloudKit: mọi thuộc tính có giá trị mặc định hoặc optional, quan hệ optional, **không** unique constraint; chỉ **thêm** trường/model (không đổi tên, không xóa). Giá trị raw là chuỗi tiếng Anh ổn định (`MenstrualFlow`/`Mood`/`Symptom.rawValue`); giá trị raw lạ (từ bản app mới hơn) được ghi lại nguyên vẹn.
- Mọi chuỗi giao diện đi qua `L10n` (`Shared/L10n.swift`) và có trong `Shared/Localizable.xcstrings` đủ `en` + `vi`, thêm/xóa bằng `scripts/add-strings.py` (JSON `{"key": ["English", "Tiếng Việt"]}` qua stdin; `--remove key …`). Không dùng `Text("…")` với chuỗi literal hay nội suy — dùng `Text(L10n.…)`, hoặc `Text(verbatim:)` cho ký hiệu không cần dịch ("kg", "–").
- Màu chỉ qua token: `.luna(.<token>)` (`App/DesignSystem/LunaColor.swift`, giá trị ở `KickCore/LunaPalette.swift`). **Không** viết hex trong view. Mọi cặp chữ/nền phải có trong `LunaContrast.usages` (đạt AA sáng + tối, `ContrastTests`). Cặp giai đoạn 5 dùng (đều đã khai báo, Task 4 thêm test khẳng định): chip chọn `onAccent` trên `cycleStrong` (Mong con) / `pregStrong` (Mang thai), chip chưa chọn `textPrimary` trên `surface`; thẻ an toàn `warningText` + `articleText` trên `warningBackground` (viền `warningBorder`); pill "Trong khoảng" `tealStrong` trên `fertileSoft`, "Thấp hơn/Cao hơn khoảng" `pregOnSoft` trên `pregSoft` (không dùng màu đỏ); mức tăng 32/700 `pregStrong` trên `card`; chữ phụ `textSecondary` trên `card`/`background`; nút Lưu Mang thai `.filled(.pregStrong)` (không dùng `preg`: chữ trắng trên `#C9673E` không đạt AA).
- Font: chỉ `Font.luna(_:)`/`Font.luna(size:weight:relativeTo:)` (co giãn theo Dynamic Type).
- Mọi animation tôn trọng Reduce Motion **và** `LunaMotion.isEnabled` (tắt hẳn khi `-uiTesting`): giai đoạn 5 chỉ có hiệu ứng mờ dần ≤ 0,2 s (`LunaMotion.fade`) khi thẻ an toàn hiện/ẩn, và toast có sẵn.
- Màn toàn màn hình có cuộn dùng `.lunaStatusBarBackdrop()` trên `ScrollView`/`List` (Triệu chứng, Cân nặng).
- Dynamic Type AX5 không cắt chữ: chip xuống dòng bằng `FlowLayout`; 4 lối tắt thành 2 hàng ở cỡ chữ trợ năng; bộ nhập kg đưa nút −/+ xuống dưới số ở cỡ chữ trợ năng.
- Launch argument chỉ cho test: chỉ có hiệu lực khi có `-uiTesting` và chỉ được đọc trong `#if DEBUG`. Giữ mọi cờ cũ. Mới: `-seedWeights` (cân trước 52 kg, cao 160 cm, các tuần 12/16/20/24/27/30 của `SEED_W` theo `-seedDueDate` và `-fixedNow`). `-seedCycles` mở rộng: `fertile` có tâm trạng + triệu chứng hôm qua, `period` có lượng kinh hôm qua và hôm nay.
- Giữ nguyên: mọi hành vi giai đoạn 3/4 (dự đoán chu kỳ — `CyclePredictor` chỉ đọc LH/BBT; LH/BBT/dịch nhầy; Cardiff; Hadlock; nhắc nhở; widget/Live Activity), mọi accessibility identifier đang được test dùng. Lượng kinh **không** tự tạo kỳ kinh. Ghi ở chế độ Mang thai dùng chung `CycleCoordinator`/`CycleStore`.
- Bài học CI (bắt buộc): `List`/`Form`/`LazyVGrid` chỉ tạo hàng gần màn hình — UI test phải cuộn tới phần tử (`scrollUntilHittable`) trước khi assert/tap; chờ bằng `waitForExistence`/`waitForLabel`, không `sleep` cố định. Bàn phím số không có phím Return: UI test đóng bàn phím bằng nút "Xong" (`keyboardDone`) trước khi bấm nút nằm dưới.
- Ngoài phạm vi (spec §1): Kiến thức/bài viết, Bạn đời, gộp cử động 5 phút, mục tiêu đếm 5–20, biểu đồ nhiệt độ, đếm cơn gò, chẩn đoán. Không chạy TestFlight (người dùng tự kích hoạt).

## Quy trình xác minh

- **Local** (mọi task có code `KickCore`): `scripts/test-core.sh` (có thể thêm `--filter <Suite>`). Không push khi local còn đỏ (pre-push hook cũng chặn). Số test `KickCore` sau từng task: 341 (trước) → 355 (Task 1) → 389 (Task 2) → 392 (Task 4) → 394 (Task 5).
- **CI** (điều kiện hoàn thành của **mọi** task): commit (kèm dòng `CI-Only-Testing:` của task, trừ Task 7), `git push`, rồi `scripts/ci-wait.sh`. Log CI in `==> UI tests: scoped to …` khi dòng đó có hiệu lực. Ảnh ở `ci-artifacts/screenshots/<tên>_0_<UUID>.png` (tên bắt đầu bằng tên trong test).
- **Flake đã biết:** UI test thỉnh thoảng timeout ở `waitForExistence` ở một test không liên quan. Nếu CI đỏ **chỉ** vì kiểu lỗi đó: chạy lại phần fail **một lần**:
  ```bash
  RUN_ID="$(gh run list --workflow ci.yml --commit "$(git rev-parse HEAD)" --limit 1 --json databaseId -q '.[0].databaseId')"
  gh run rerun "$RUN_ID" --failed
  gh run watch "$RUN_ID" --exit-status --interval 20 > /dev/null && echo "CI PASSED"
  rm -rf ci-artifacts && gh run download "$RUN_ID" --dir ci-artifacts
  ```
  Đỏ lần hai, hoặc lỗi ở test của task → dùng `superpowers:systematic-debugging`, sửa, commit (giữ dòng `CI-Only-Testing:` của task), push lại.
- **Lỗi biên dịch trên CI** (không có Xcode local): đọc log `scripts/ci-wait.sh`, sửa đúng chỗ, giữ nguyên tên/kiểu đã định trong plan (task sau phụ thuộc vào chúng).
- **Kiểm tra trực quan** (mọi task UI): mở từng PNG được liệt kê bằng **Read tool**, đối chiếu từng mục của danh sách kiểm tra **và** với `docs/design/mam-handoff/prototype.html` (khối `<script data-dc-script>` và phần markup của màn tương ứng). Sai một mục là chưa xong.
- Không đánh dấu task hoàn thành khi CI còn đỏ.

## File Structure

```
kick-counter/
├── Packages/KickCore/
│   ├── Sources/KickCore/
│   │   ├── SymptomKinds.swift                         # T1 (mới): MenstrualFlow, Mood, Symptom, RawList
│   │   ├── CycleRecords.swift                         # T1: CycleLogRecord + flow/moods/symptoms/unknown…, gộp trùng
│   │   ├── CycleSeed.swift                            # T1: log mẫu có lượng kinh, tâm trạng, triệu chứng
│   │   ├── WeightRecords.swift                        # T2 (mới): WeightRecord, WeightRepository, WeightRules, DecimalEntry
│   │   ├── WeightGuidance.swift                       # T2 (mới): BMICategory, WeightStatus, WeightGuidance (IOM 2009)
│   │   ├── MaternalProfile.swift                      # T2 (mới): cân trước mang thai + chiều cao (App Group)
│   │   ├── WeightStats.swift                          # T2 (mới): WeightPoint, WeightSection, WeightBandPoint
│   │   ├── WeightSeed.swift                           # T2 (mới): dữ liệu mẫu SEED_W / PRE_KG
│   │   ├── WeightCoordinator.swift                    # T2 (mới): WeightFailure, WeightCoordinator
│   │   ├── Settings.swift, UITestLaunchOptions.swift  # T2: khóa maternal*, -seedWeights
│   │   ├── CycleLogSummary.swift                      # T4 (mới): CycleLogSummaryItem, summaryItems(mode:)
│   │   ├── LunaPalette.swift                          # T4: LunaContrast.declares(_:on:)
│   │   └── SymptomTimeline.swift                      # T5 (mới): SymptomWeekSection, SymptomTimeline
│   └── Tests/KickCoreTests/
│       ├── SymptomKindsTests.swift                    # T1 (mới)
│       ├── CycleRulesTests.swift, CycleSeedTests.swift, CycleCoordinatorTests.swift, TestSupport.swift  # T1 (TestSupport: T2)
│       ├── WeightRulesTests.swift, WeightGuidanceTests.swift, MaternalProfileTests.swift,
│       │   WeightStatsTests.swift, WeightSeedTests.swift, WeightCoordinatorTests.swift   # T2 (mới)
│       ├── CycleLogSummaryTests.swift, ContrastTests.swift   # T4
│       └── SymptomTimelineTests.swift                 # T5 (mới)
├── Packages/KickData/
│   ├── Sources/KickData/{Models,KickPersistence}.swift   # T3: CycleLog flowRaw/moodsRaw/symptomsRaw, WeightEntry, schema
│   ├── Sources/KickData/WeightStore.swift             # T3 (mới)
│   └── Tests/KickDataTests/{CycleStoreTests,WeightStoreTests}.swift   # T3
├── Shared/{L10n.swift, Localizable.xcstrings}         # T4, T5, T6
├── App/
│   ├── Symptoms/SymptomChips.swift                    # T4 (mới): FlowLayout, SelectableChip, FlowChips, MoodChips, SymptomChips
│   ├── Cycle/{CycleDayLogSheet,CycleCards,CycleTodayView,CycleCalendarView}.swift   # T4
│   ├── Symptoms/{SymptomSafetyCard,PregnancySymptomSheet,PregnancySymptomsView}.swift   # T5 (mới)
│   ├── Pregnancy/WeekDetailView.swift                 # T5: mở thẳng tới mục cảnh báo
│   ├── Pregnancy/PregnancyTodayView.swift             # T5 (lối tắt Triệu chứng), T6 (lối tắt Cân nặng, thẻ cân nặng)
│   ├── Weight/{WeightView,WeightSummaryCard,WeightChart,WeightEntryCard,WeightTexts,
│   │   MaternalProfileForm,WeightTodayCard}.swift     # T6 (mới)
│   ├── DesignSystem/KeyboardDone.swift                # T6 (mới): nút "Xong" trên bàn phím số
│   ├── Formatting.swift                               # T6: kilograms, centimeters, decimal
│   ├── Profile/ProfileView.swift                      # T6: dòng "Cân nặng trước mang thai · Chiều cao"
│   └── AppEnvironment.swift, RootView.swift, KickCounterApp.swift   # T6: WeightCoordinator + -seedWeights
├── UITests/
│   ├── CycleSymptomsUITests.swift                     # T4 (mới)
│   ├── CycleUITests.swift, SheetsUITests.swift, CycleScreenshotTests.swift   # T4 (cuộn tới LH/BBT)
│   ├── PregnancySymptomsUITests.swift                 # T5 (mới)
│   ├── UITestSupport.swift                            # T5: confirmDialog, openPregnancySymptoms
│   ├── PregnancyTodayUITests.swift                    # T5, T6
│   ├── WeightUITests.swift                            # T6 (mới)
│   └── ProfileUITests.swift, PregnancyScreenshotTests.swift   # T6
├── README.md                                          # T7
└── docs/{release-checklist.md, content-review-for-doctor.md}   # T7
```

---
### Task 1: KickCore — lượng kinh, tâm trạng, triệu chứng trong `CycleLogRecord`

Thêm ba loại dữ liệu mới (spec §2.1) vào bản ghi ngày dùng chung cho hai chế độ: `MenstrualFlow` (`none | light | medium | heavy`), `Mood` (5 giá trị), `Symptom` (6 của Mong con + 7 của Mang thai, `Symptom.mode`), mã hóa thành chuỗi raw phân tách dấu phẩy có giữ giá trị lạ (`RawList`), quy tắc "log rỗng = xóa" và gộp trùng mở rộng (hợp tâm trạng/triệu chứng theo thứ tự enum, lượng kinh nặng hơn thắng), điều kiện thẻ an toàn (`needsSafetyNote`), dữ liệu mẫu `-seedCycles` có các trường mới. Chưa có giao diện nào dùng; app vẫn biên dịch vì mọi tham số mới có giá trị mặc định.

**Files:**
- Create: `Packages/KickCore/Sources/KickCore/SymptomKinds.swift`, `Packages/KickCore/Tests/KickCoreTests/SymptomKindsTests.swift`
- Modify: `Packages/KickCore/Sources/KickCore/CycleRecords.swift` (`CycleLogRecord`, `CycleRules.normalized`, `CycleRules.mergingDuplicates(_ logs:)`), `Packages/KickCore/Sources/KickCore/CycleSeed.swift`
- Modify (test): `Packages/KickCore/Tests/KickCoreTests/{CycleRulesTests,CycleSeedTests,CycleCoordinatorTests,TestSupport}.swift`

**Interfaces:**
- Consumes: `AppMode` (`.tryingToConceive`, `.pregnant`), `CycleLogRecord`, `CycleRules`, `CycleSeedScenario` (đã có).
- Produces (task sau dùng đúng tên này):
  - `public enum MenstrualFlow: String, Sendable, CaseIterable, Comparable { case noFlow = "none", light, medium, heavy }` (nhẹ → nặng; **không** đặt tên `none` để tránh nhầm với `Optional.none`).
  - `public enum Mood: String, Sendable, CaseIterable { happy, calm, sensitive, anxious, tired }`.
  - `public enum Symptom: String, Sendable, CaseIterable` — `cramps, headache, tenderBreasts, acne, bloating, cravings` (Mong con), `nausea, heartburn, swollenFeet, backPain, legCramps, insomnia, contractions` (Mang thai); `var mode: AppMode`, `static func cases(for: AppMode) -> [Symptom]`, `var needsSafetyNote: Bool` (`contractions`, `swollenFeet`), `static func needsSafetyNote(_: some Sequence<Symptom>) -> Bool`.
  - `public enum RawList`: `decode<V>(_ raw: String?) -> (known: [V], unknown: [String])`, `encode<V>(_ known: [V], unknown: [String]) -> String?` (nil khi rỗng), `ordered<V>(_ values: some Sequence<V>) -> [V]` (thứ tự enum, không lặp).
  - `CycleLogRecord` thêm `flow: MenstrualFlow?`, `moods: [Mood]`, `symptoms: [Symptom]`, `unknownMoodsRaw: [String]`, `unknownSymptomsRaw: [String]` (tham số init cùng tên, đặt sau `note`, mặc định rỗng/nil); `withID(_:) -> CycleLogRecord`; `symptoms(for: AppMode) -> [Symptom]`; `mutating setSymptoms(_: some Sequence<Symptom>, for: AppMode)` (giữ triệu chứng của chế độ kia). `isEmpty` tính cả trường mới và giá trị lạ.
  - `CycleSeedScenario.fertile`: log hôm qua có `moods: [.calm]`, `symptoms: [.bloating]`; `.period`: log hôm qua `flow: .heavy, moods: [.tired], symptoms: [.cramps]`, hôm nay `flow: .medium`.

- [ ] **Step 1: Viết test trước**

`Packages/KickCore/Tests/KickCoreTests/SymptomKindsTests.swift` (toàn bộ file):
```swift
import Foundation
import Testing
@testable import KickCore

struct SymptomKindsTests {
    @Test func rawListsDecodeInEnumOrderAndEncodeBack() {
        let decoded: (known: [Mood], unknown: [String]) = RawList.decode("tired,happy")
        #expect(decoded.known == [.happy, .tired])
        #expect(decoded.unknown.isEmpty)
        #expect(RawList.encode(decoded.known, unknown: decoded.unknown) == "happy,tired")
    }

    @Test func unknownRawValuesAreKeptOnceInTheOrderFound() {
        let decoded: (known: [Mood], unknown: [String]) = RawList.decode(" excited ,happy,,calm,excited,bored")
        #expect(decoded.known == [.happy, .calm])
        #expect(decoded.unknown == ["excited", "bored"])
        #expect(RawList.encode(decoded.known, unknown: decoded.unknown) == "happy,calm,excited,bored")
    }

    @Test func emptyListsAreStoredAsNil() {
        let decoded: (known: [Symptom], unknown: [String]) = RawList.decode(nil)
        #expect(decoded.known.isEmpty && decoded.unknown.isEmpty)
        #expect(RawList.encode([Symptom](), unknown: []) == nil)
        #expect(RawList.ordered([Symptom.nausea, .cramps, .nausea]) == [.cramps, .nausea])
    }

    @Test func symptomsBelongToOneMode() {
        #expect(Symptom.cases(for: .tryingToConceive) == [.cramps, .headache, .tenderBreasts, .acne, .bloating, .cravings])
        #expect(Symptom.cases(for: .pregnant) == [.nausea, .heartburn, .swollenFeet, .backPain, .legCramps, .insomnia, .contractions])
        #expect(Symptom.allCases.count == 13)
    }

    @Test func flowIsOrderedFromNoneToHeavyAndStoresNone() {
        #expect(MenstrualFlow.allCases.sorted() == [.noFlow, .light, .medium, .heavy])
        #expect([MenstrualFlow.light, .heavy, .noFlow].max() == .heavy)
        #expect(MenstrualFlow.noFlow.rawValue == "none")
        #expect(MenstrualFlow(rawValue: "none") == .noFlow)
    }

    @Test func onlyContractionsAndSwollenFeetShowTheSafetyCard() {
        #expect(Symptom.allCases.filter(\.needsSafetyNote) == [.swollenFeet, .contractions])
        #expect(Symptom.needsSafetyNote([.nausea, .contractions]))
        #expect(Symptom.needsSafetyNote([.swollenFeet]))
        #expect(!Symptom.needsSafetyNote([.nausea, .backPain]))
        #expect(!Symptom.needsSafetyNote([]))
    }

    @Test func settingOneModesSymptomsKeepsTheOthers() {
        var log = CycleLogRecord(day: date("2026-10-02T00:00:00Z"), symptoms: [.cramps, .nausea])
        log.setSymptoms([.contractions, .headache], for: .pregnant)
        #expect(log.symptoms == [.cramps, .contractions])
        #expect(log.symptoms(for: .pregnant) == [.contractions])
        log.setSymptoms([], for: .tryingToConceive)
        #expect(log.symptoms == [.contractions])
    }
}
```

Trong `Packages/KickCore/Tests/KickCoreTests/CycleRulesTests.swift`, thay:
```swift
    @Test func emptyLogIsDetected() {
        #expect(CycleLogRecord(day: today, note: "  ").isEmpty)
        #expect(!CycleLogRecord(day: today, mucus: .dry).isEmpty)
    }
```
bằng:
```swift
    @Test func emptyLogIsDetected() {
        #expect(CycleLogRecord(day: today, note: "  ").isEmpty)
        #expect(!CycleLogRecord(day: today, mucus: .dry).isEmpty)
    }

    @Test func flowMoodsSymptomsAndUnknownValuesAreNotEmpty() {
        #expect(!CycleLogRecord(day: today, flow: .noFlow).isEmpty)
        #expect(!CycleLogRecord(day: today, moods: [.calm]).isEmpty)
        #expect(!CycleLogRecord(day: today, symptoms: [.nausea]).isEmpty)
        #expect(!CycleLogRecord(day: today, unknownMoodsRaw: ["excited"]).isEmpty)
        #expect(!CycleLogRecord(day: today, unknownSymptomsRaw: ["hiccups"]).isEmpty)
    }

    @Test func normalizingOrdersMoodsAndSymptoms() {
        let log = CycleRules.normalized(
            CycleLogRecord(day: today, moods: [.tired, .happy, .tired], symptoms: [.nausea, .cramps]),
            calendar: calendar
        )
        #expect(log.moods == [.happy, .tired])
        #expect(log.symptoms == [.cramps, .nausea])
    }

    @Test func sameDayLogsUniteMoodsAndSymptomsAndKeepTheHeavierFlow() {
        let a = CycleLogRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!, day: day("2026-10-01"),
            flow: .light, moods: [.tired], symptoms: [.cramps], unknownMoodsRaw: ["excited"]
        )
        let b = CycleLogRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!, day: day("2026-10-01"),
            flow: .heavy, moods: [.happy, .tired], symptoms: [.nausea],
            unknownMoodsRaw: ["excited", "bored"], unknownSymptomsRaw: ["hiccups"]
        )
        let result = CycleRules.mergingDuplicates([b, a], calendar: calendar)
        #expect(result.logs == [CycleLogRecord(
            id: a.id, day: day("2026-10-01"), flow: .heavy, moods: [.happy, .tired], symptoms: [.cramps, .nausea],
            unknownMoodsRaw: ["excited", "bored"], unknownSymptomsRaw: ["hiccups"]
        )])
        #expect(result.removedIDs == [b.id])
    }

    @Test func aFlowOnlyOnOneCopySurvivesTheMerge() {
        let a = CycleLogRecord(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!, day: day("2026-10-01"), note: "x")
        let b = CycleLogRecord(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!, day: day("2026-10-01"), flow: .noFlow)
        #expect(CycleRules.mergingDuplicates([a, b], calendar: calendar).logs.first?.flow == .noFlow)
    }

    @Test func withIDKeepsEveryValue() {
        let log = CycleLogRecord(day: today, lh: .positive, flow: .medium, moods: [.calm], unknownSymptomsRaw: ["hiccups"])
        let id = UUID()
        let copy = log.withID(id)
        #expect(copy.id == id)
        #expect(copy == CycleLogRecord(id: id, day: today, lh: .positive, flow: .medium, moods: [.calm], unknownSymptomsRaw: ["hiccups"]))
    }
```

Thêm vào cuối `Packages/KickCore/Tests/KickCoreTests/CycleSeedTests.swift`:
```swift
struct CycleSeedSymptomTests {
    @Test func seededLogsCarryFlowMoodsAndSymptoms() throws {
        let now = date("2026-10-02T12:00:00Z")
        let period = CycleSeedScenario.period.records(today: now, calendar: utcCalendar).logs
        #expect(period.map(\.flow) == [.heavy, .medium])
        #expect(period.first?.symptoms == [.cramps])
        let fertile = CycleSeedScenario.fertile.records(today: now, calendar: utcCalendar).logs
        let yesterday = try #require(fertile.first { $0.day == date("2026-10-01T00:00:00Z") })
        #expect(yesterday.moods == [.calm])
        #expect(yesterday.symptoms == [.bloating])
        #expect(fertile.last?.moods.isEmpty == true)
    }
}
```

Trong `Packages/KickCore/Tests/KickCoreTests/CycleCoordinatorTests.swift`, thay:
```swift
    // MARK: - Loading

    @Test func loadComputesTheForecastAndSchedulesReminders() async throws {
```
bằng:
```swift
    // MARK: - Flow, moods and symptoms (phase 5)

    @Test func loggingFlowNeverStartsAPeriod() async {
        await coordinator.load()
        #expect(await coordinator.saveLog(CycleLogRecord(day: day("2026-09-05"), flow: .heavy, moods: [.tired])) == nil)
        #expect(coordinator.periods.isEmpty)
        #expect(coordinator.forecast == nil)
        #expect(coordinator.log(on: day("2026-09-05"))?.flow == .heavy)
    }

    // MARK: - Loading

    @Test func loadComputesTheForecastAndSchedulesReminders() async throws {
```

Trong `Packages/KickCore/Tests/KickCoreTests/TestSupport.swift` (fake giữ mọi trường khi ghi đè log cùng ngày), thay:
```swift
        var saved = normalized
        if let existing {
            saved = CycleLogRecord(
                id: existing.id, day: normalized.day, lh: normalized.lh,
                bbtCelsius: normalized.bbtCelsius, mucus: normalized.mucus, note: normalized.note
            )
        }
        storedLogs.append(saved)
```
bằng:
```swift
        storedLogs.append(existing.map { normalized.withID($0.id) } ?? normalized)
```

- [ ] **Step 2: Chạy để thấy fail**

Run: `scripts/test-core.sh --filter "SymptomKindsTests|CycleRulesTests|CycleSeedSymptomTests|CycleCoordinatorTests"`
Expected: lỗi biên dịch `cannot find 'RawList' in scope`, `extra argument 'flow' in call`, `value of type 'CycleLogRecord' has no member 'withID'`.

- [ ] **Step 3: Viết code**

`Packages/KickCore/Sources/KickCore/SymptomKinds.swift` (toàn bộ file):
```swift
import Foundation

/// Menstrual flow logged for a day (spec §2.1), lightest first: merging two
/// logs of the same day keeps the heavier one. Logging flow never starts a period.
public enum MenstrualFlow: String, Sendable, CaseIterable, Comparable {
    /// Stored as "none". Not named `none`, which would be ambiguous with
    /// `Optional.none` wherever a `MenstrualFlow?` is compared.
    case noFlow = "none"
    case light
    case medium
    case heavy

    public static func < (lhs: MenstrualFlow, rhs: MenstrualFlow) -> Bool {
        lhs.order < rhs.order
    }

    private var order: Int {
        switch self {
        case .noFlow: 0
        case .light: 1
        case .medium: 2
        case .heavy: 3
        }
    }
}

public enum Mood: String, Sendable, CaseIterable {
    case happy
    case calm
    case sensitive
    case anxious
    case tired
}

/// Symptoms of both modes in one list (spec §2.1). The UI shows only the
/// current mode's; the other mode's stay stored untouched.
public enum Symptom: String, Sendable, CaseIterable {
    // Trying to conceive
    case cramps
    case headache
    case tenderBreasts
    case acne
    case bloating
    case cravings
    // Pregnant
    case nausea
    case heartburn
    case swollenFeet
    case backPain
    case legCramps
    case insomnia
    case contractions

    public var mode: AppMode {
        switch self {
        case .cramps, .headache, .tenderBreasts, .acne, .bloating, .cravings: .tryingToConceive
        case .nausea, .heartburn, .swollenFeet, .backPain, .legCramps, .insomnia, .contractions: .pregnant
        }
    }

    /// The chips shown in that mode, in display order.
    public static func cases(for mode: AppMode) -> [Symptom] {
        allCases.filter { $0.mode == mode }
    }

    /// Contractions and swollen feet show the "when to get care" card (spec §3.2).
    public var needsSafetyNote: Bool {
        self == .contractions || self == .swollenFeet
    }

    public static func needsSafetyNote(_ symptoms: some Sequence<Symptom>) -> Bool {
        symptoms.contains { $0.needsSafetyNote }
    }
}

/// The comma-separated lists stored in `CycleLog.moodsRaw` / `symptomsRaw`:
/// stable English raw values in enum order. Values this build does not know
/// (synced from a newer version) are returned separately so they can be written
/// back unchanged.
public enum RawList {
    public static func decode<Value>(_ raw: String?) -> (known: [Value], unknown: [String])
    where Value: RawRepresentable & CaseIterable & Equatable, Value.RawValue == String {
        let tokens = (raw ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let known = Value.allCases.filter { tokens.contains($0.rawValue) }
        var unknown: [String] = []
        for token in tokens where Value(rawValue: token) == nil && !unknown.contains(token) {
            unknown.append(token)
        }
        return (known, unknown)
    }

    /// nil when both lists are empty (the attribute stays unset).
    public static func encode<Value>(_ known: [Value], unknown: [String]) -> String?
    where Value: RawRepresentable & CaseIterable & Equatable, Value.RawValue == String {
        let parts = Value.allCases.filter(known.contains).map(\.rawValue) + unknown
        return parts.isEmpty ? nil : parts.joined(separator: ",")
    }

    /// Enum order without repeats, e.g. for a merge or a sheet's selection.
    public static func ordered<Value>(_ values: some Sequence<Value>) -> [Value]
    where Value: CaseIterable & Equatable {
        let present = Array(values)
        return Value.allCases.filter(present.contains)
    }
}
```

Trong `Packages/KickCore/Sources/KickCore/CycleRecords.swift`, thay:
```swift
/// Body signals logged for one day (value snapshot of the SwiftData `CycleLog`).
public struct CycleLogRecord: Equatable, Sendable, Identifiable {
    public let id: UUID
    /// Start of the calendar day.
    public var day: Date
    public var lh: LHResult?
    /// Basal body temperature, 35.0–38.5 °C.
    public var bbtCelsius: Double?
    public var mucus: CervicalMucus?
    public var note: String

    public init(
        id: UUID = UUID(),
        day: Date,
        lh: LHResult? = nil,
        bbtCelsius: Double? = nil,
        mucus: CervicalMucus? = nil,
        note: String = ""
    ) {
        self.id = id
        self.day = day
        self.lh = lh
        self.bbtCelsius = bbtCelsius
        self.mucus = mucus
        self.note = note
    }

    /// Nothing logged: saving an empty log removes that day's log.
    public var isEmpty: Bool {
        lh == nil && bbtCelsius == nil && mucus == nil && note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
```
bằng:
```swift
/// What was logged for one day (value snapshot of the SwiftData `CycleLog`):
/// ovulation signals, flow, moods and symptoms of both modes, and a note.
public struct CycleLogRecord: Equatable, Sendable, Identifiable {
    public let id: UUID
    /// Start of the calendar day.
    public var day: Date
    public var lh: LHResult?
    /// Basal body temperature, 35.0–38.5 °C.
    public var bbtCelsius: Double?
    public var mucus: CervicalMucus?
    public var note: String
    public var flow: MenstrualFlow?
    /// Enum order, no repeats (`CycleRules.normalized`).
    public var moods: [Mood]
    /// Both modes' symptoms, enum order, no repeats.
    public var symptoms: [Symptom]
    /// Stored values this build does not know, written back unchanged.
    public var unknownMoodsRaw: [String]
    public var unknownSymptomsRaw: [String]

    public init(
        id: UUID = UUID(),
        day: Date,
        lh: LHResult? = nil,
        bbtCelsius: Double? = nil,
        mucus: CervicalMucus? = nil,
        note: String = "",
        flow: MenstrualFlow? = nil,
        moods: [Mood] = [],
        symptoms: [Symptom] = [],
        unknownMoodsRaw: [String] = [],
        unknownSymptomsRaw: [String] = []
    ) {
        self.id = id
        self.day = day
        self.lh = lh
        self.bbtCelsius = bbtCelsius
        self.mucus = mucus
        self.note = note
        self.flow = flow
        self.moods = moods
        self.symptoms = symptoms
        self.unknownMoodsRaw = unknownMoodsRaw
        self.unknownSymptomsRaw = unknownSymptomsRaw
    }

    /// The same values under another id (a store keeps the id it already has).
    public func withID(_ id: UUID) -> CycleLogRecord {
        CycleLogRecord(
            id: id, day: day, lh: lh, bbtCelsius: bbtCelsius, mucus: mucus, note: note,
            flow: flow, moods: moods, symptoms: symptoms,
            unknownMoodsRaw: unknownMoodsRaw, unknownSymptomsRaw: unknownSymptomsRaw
        )
    }

    /// Nothing logged: saving an empty log removes that day's log. Values this
    /// build cannot read count as something, so they are never dropped.
    public var isEmpty: Bool {
        lh == nil && bbtCelsius == nil && mucus == nil && flow == nil
            && moods.isEmpty && symptoms.isEmpty && unknownMoodsRaw.isEmpty && unknownSymptomsRaw.isEmpty
            && note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The symptoms of one mode, as that mode's sheet shows them.
    public func symptoms(for mode: AppMode) -> [Symptom] {
        symptoms.filter { $0.mode == mode }
    }

    /// Replaces one mode's symptoms; the other mode's stay as they are.
    public mutating func setSymptoms(_ selected: some Sequence<Symptom>, for mode: AppMode) {
        let chosen = Array(selected).filter { $0.mode == mode }
        symptoms = RawList.ordered(symptoms.filter { $0.mode != mode } + chosen)
    }
}
```

Trong `Packages/KickCore/Sources/KickCore/CycleRecords.swift`, thay:
```swift
    public static func normalized(_ log: CycleLogRecord, calendar: Calendar) -> CycleLogRecord {
        var copy = log
        copy.day = calendar.startOfDay(for: log.day)
        copy.note = log.note.trimmingCharacters(in: .whitespacesAndNewlines)
        return copy
    }
```
bằng:
```swift
    public static func normalized(_ log: CycleLogRecord, calendar: Calendar) -> CycleLogRecord {
        var copy = log
        copy.day = calendar.startOfDay(for: log.day)
        copy.note = log.note.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.moods = RawList.ordered(log.moods)
        copy.symptoms = RawList.ordered(log.symptoms)
        return copy
    }
```

Trong `Packages/KickCore/Sources/KickCore/CycleRecords.swift`, thay:
```swift
    /// Merges logs that fall on the same day (iCloud duplicates). Keeps the id
    /// that sorts first; a positive LH test wins over a negative one; the first
    /// temperature and mucus found win; distinct notes are joined by newlines.
```
bằng:
```swift
    /// Merges logs that fall on the same day (iCloud duplicates). Keeps the id
    /// that sorts first; a positive LH test wins over a negative one; the first
    /// temperature and mucus found win; distinct notes are joined by newlines;
    /// the heavier flow wins; moods, symptoms and unknown raw values are united.
```

Trong `Packages/KickCore/Sources/KickCore/CycleRecords.swift`, thay:
```swift
                first.note = notes.joined(separator: "\n")
```
bằng:
```swift
                first.note = notes.joined(separator: "\n")
                first.flow = group.compactMap(\.flow).max()
                first.moods = RawList.ordered(group.flatMap(\.moods))
                first.symptoms = RawList.ordered(group.flatMap(\.symptoms))
                first.unknownMoodsRaw = united(group.map(\.unknownMoodsRaw))
                first.unknownSymptomsRaw = united(group.map(\.unknownSymptomsRaw))
```

Trong `Packages/KickCore/Sources/KickCore/CycleRecords.swift`, thay:
```swift
        return (merged, removed)
    }
}

/// What the temperature field holds. Accepts "36.5" and "36,5".
```
bằng:
```swift
        return (merged, removed)
    }

    /// Every value once, in the order first seen.
    private static func united(_ lists: [[String]]) -> [String] {
        var result: [String] = []
        for value in lists.joined() where !result.contains(value) {
            result.append(value)
        }
        return result
    }
}

/// What the temperature field holds. Accepts "36.5" and "36,5".
```

Trong `Packages/KickCore/Sources/KickCore/CycleSeed.swift`, thay:
```swift
    /// Regular 28-day cycles, period started yesterday and still going (cycle day 2).
```
bằng:
```swift
    /// Regular 28-day cycles, period started yesterday and still going (cycle day 2),
    /// with flow logged yesterday and today.
```

Trong `Packages/KickCore/Sources/KickCore/CycleSeed.swift`, thay:
```swift
    /// Regular 28-day cycles at cycle day 13, inside the fertile window, with signals logged.
```
bằng:
```swift
    /// Regular 28-day cycles at cycle day 13, inside the fertile window, with signals
    /// logged (and a mood and a symptom yesterday).
```

Trong `Packages/KickCore/Sources/KickCore/CycleSeed.swift`, thay:
```swift
        case .period:
            return Records(periods: closed([-85, -57, -29]) + [PeriodRecord(startDate: day(-1))], logs: [])
```
bằng:
```swift
        case .period:
            return Records(
                periods: closed([-85, -57, -29]) + [PeriodRecord(startDate: day(-1))],
                logs: [
                    CycleLogRecord(day: day(-1), flow: .heavy, moods: [.tired], symptoms: [.cramps]),
                    CycleLogRecord(day: day(0), flow: .medium),
                ]
            )
```

Trong `Packages/KickCore/Sources/KickCore/CycleSeed.swift`, thay:
```swift
                    CycleLogRecord(day: day(-1), lh: .negative, bbtCelsius: 36.4, mucus: .creamy),
```
bằng:
```swift
                    CycleLogRecord(day: day(-1), lh: .negative, bbtCelsius: 36.4, mucus: .creamy, moods: [.calm], symptoms: [.bloating]),
```

- [ ] **Step 4: Chạy test**

Run: `scripts/test-core.sh`
Expected: PASS, `Test run with 355 tests` (341 + 14: `SymptomKindsTests` 7, `CycleRulesTests` +5, `CycleSeedSymptomTests` 1, `CycleCoordinatorTests` +1). `CycleSeedTests.seededDataPassesTheStoreRules` vẫn xanh.

- [ ] **Step 5: Commit, push, xác minh CI**

Dữ liệu mẫu `fertile`/`period` đổi → chạy các lớp UI test dùng chúng.
```bash
scripts/test-core.sh
git add Packages/KickCore
git commit -F - <<'MSG'
feat(core): log flow, moods and symptoms on a cycle day

MenstrualFlow, Mood and Symptom (trying-to-conceive and pregnancy lists)
are part of CycleLogRecord, stored as stable comma-separated raw values
that keep values from newer app versions. Same-day duplicates unite moods
and symptoms and keep the heavier flow; flow never starts a period. The
fertile and period samples carry the new fields.

CI-Only-Testing: CycleUITests, CycleTodayUITests, SheetsUITests
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`; log có `==> UI tests: scoped to CycleUITests CycleTodayUITests SheetsUITests`; `KickData` (41 test) vẫn xanh — `CycleLog` chưa lưu trường mới nên các log mẫu chỉ còn LH/BBT/dịch nhầy sau khi lưu (Task 3 bổ sung).

---
### Task 2: KickCore — cân nặng: bản ghi, quy tắc, dải IOM, hồ sơ, thống kê, coordinator, dữ liệu mẫu

Toàn bộ logic cân nặng (spec §2.2–2.4, §4) ở `KickCore`, test local: `WeightRecord`/`WeightRepository`/`WeightRules` (ngày chuẩn hóa, không ngày tương lai, 30,0–200,0 kg làm tròn 0,1, một bản ghi mỗi ngày, gộp trùng theo `uuidString`), `DecimalEntry` (nhận "56,2" và "56.2"), `WeightGuidance` (BMI một chữ số thập phân, 4 nhóm IOM, dải theo tuần, trạng thái), `MaternalProfile` (UserDefaults App Group, 0 = chưa đặt), `WeightStats` (điểm biểu đồ, nhóm theo tuần, dải tuần 0–40), `WeightSeed` + cờ `-seedWeights`, `WeightCoordinator` + fake repository. Chưa có giao diện nào dùng.

**Files:**
- Create: `Packages/KickCore/Sources/KickCore/{WeightRecords,WeightGuidance,MaternalProfile,WeightStats,WeightSeed,WeightCoordinator}.swift`
- Create: `Packages/KickCore/Tests/KickCoreTests/{WeightRulesTests,WeightGuidanceTests,MaternalProfileTests,WeightStatsTests,WeightSeedTests,WeightCoordinatorTests}.swift`
- Modify: `Packages/KickCore/Sources/KickCore/{Settings,UITestLaunchOptions}.swift`, `Packages/KickCore/Tests/KickCoreTests/TestSupport.swift`

**Interfaces:**
- Consumes: `PregnancyTimeline(dueDate:now:calendar:)` (`.week: GestationalWeek`, `.dueDate`), `PregnancyTimeline.pregnancyLengthDays` (280), `GestationalWeek(weeks:days:)`, `SettingsKey`, `UITestLaunchOptions`, test helpers `date(_:)`, `utcCalendar`, `makeTestDefaults()`, `TestClock` (đã có).
- Produces:
  - `public struct WeightRecord: Equatable, Sendable, Identifiable { let id: UUID; var day: Date; var kg: Double }`, `init(id: UUID = UUID(), day:kg:)`.
  - `public enum WeightRepositoryError: Error { futureDate, outOfRange }`.
  - `@MainActor public protocol WeightRepository: AnyObject { func entries() throws -> [WeightRecord]; func save(_ entry: WeightRecord, today: Date) throws; func delete(id: UUID) throws }`.
  - `public enum WeightRules`: `kgRange = 30.0...200.0`, `rounded(_:)`, `normalized(_:calendar:)`, `validate(_:today:calendar:) throws`, `mergingDuplicates(_:calendar:) -> (entries: [WeightRecord], removedIDs: [UUID])`, `dayRange(dueDate:now:calendar:) -> ClosedRange<Date>` (từ kỳ kinh cuối = dự sinh − 280 ngày tới cuối hôm nay).
  - `public enum DecimalEntry: Equatable { empty, valid(Double), invalid }`, `init(text:range:fractionDigits: = 1)`.
  - `public enum BMICategory: String, CaseIterable { under, normal, over, obese }`, `init(bmi:)`, `totalGainKg: ClosedRange<Double>`; `public enum WeightStatus: String, CaseIterable { below, inRange, above }`; `public enum WeightGuidance`: `termWeek = 40`, `bmi(weightKg:heightCm:) -> Double` (làm tròn 0,1), `range(atWeek: Double, category:) -> ClosedRange<Double>`, `status(gain:week:category:) -> WeightStatus`.
  - `SettingsKey.maternalPreWeightKg = "maternalPreWeightKg"`, `SettingsKey.maternalHeightCm = "maternalHeightCm"`.
  - `public struct MaternalProfile: Equatable, Sendable { var preWeightKg: Double?; var heightCm: Double? }`: `preWeightRange` (30–200), `heightRange` (120–220), `bmi: Double?`, `category: BMICategory?`, `static load(from:)`, `save(to:) throws` (`MaternalProfileError.invalidWeight/.invalidHeight`).
  - `public struct WeightPoint: Identifiable { id, day, kg, week: GestationalWeek, gainKg: Double?, status: WeightStatus?, exactWeek: Double }`, `public struct WeightSection: Identifiable { week: Int?; entries: [WeightRecord] }`, `public struct WeightBandPoint: Identifiable { week: Int; lowKg; highKg }`; `public enum WeightStats`: `points(_:profile:dueDate:calendar:) -> [WeightPoint]`, `sections(_:dueDate:calendar:) -> [WeightSection]`, `band(category:) -> [WeightBandPoint]`.
  - `public enum WeightSeed`: `preWeightKg = 52`, `heightCm = 160`, `samples`, `profile: MaternalProfile`, `entries(dueDate:today:calendar:) -> [WeightRecord]`; `UITestLaunchOptions.seedWeights: Bool`.
  - `public enum WeightFailure: Error, Equatable { loadFailed, saveFailed, futureDate, outOfRange, invalidHeight }`.
  - `@MainActor @Observable public final class WeightCoordinator`: `init(store:defaults:calendar: = .current, now: = { Date() })`, `entries: [WeightRecord]` (cũ → mới), `profile: MaternalProfile`, `failure: WeightFailure?`, `latest: WeightRecord?`, `entry(on:) -> WeightRecord?`, `load() async`, `@discardableResult save(kg:on:) -> WeightFailure?`, `@discardableResult delete(id:) -> WeightFailure?`, `@discardableResult updateProfile(_:) -> WeightFailure?`, `clearFailure()`.

- [ ] **Step 1: Viết test trước — quy tắc, dải IOM, hồ sơ**

`Packages/KickCore/Tests/KickCoreTests/WeightRulesTests.swift` (toàn bộ file):
```swift
import Foundation
import Testing
@testable import KickCore

struct WeightRulesTests {
    let calendar = utcCalendar
    let today = date("2026-10-02T12:00:00Z")

    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00Z") }

    @Test func normalizingMovesToTheStartOfTheDayAndRoundsToOneDecimal() {
        let entry = WeightRecord(day: date("2026-10-01T18:30:00Z"), kg: 58.04)
        #expect(WeightRules.normalized(entry, calendar: calendar) == WeightRecord(id: entry.id, day: day("2026-10-01"), kg: 58.0))
        #expect(WeightRules.rounded(56.25) == 56.3)
    }

    @Test func weightsFrom30To200KgAreAccepted() throws {
        try WeightRules.validate(WeightRecord(day: today, kg: 30.0), today: today, calendar: calendar)
        try WeightRules.validate(WeightRecord(day: today, kg: 200.0), today: today, calendar: calendar)
        try WeightRules.validate(WeightRecord(day: today, kg: 29.96), today: today, calendar: calendar) // rounds to 30.0
        #expect(throws: WeightRepositoryError.outOfRange) {
            try WeightRules.validate(WeightRecord(day: today, kg: 29.9), today: today, calendar: calendar)
        }
        #expect(throws: WeightRepositoryError.outOfRange) {
            try WeightRules.validate(WeightRecord(day: today, kg: 200.1), today: today, calendar: calendar)
        }
        #expect(throws: WeightRepositoryError.outOfRange) {
            try WeightRules.validate(WeightRecord(day: today, kg: .nan), today: today, calendar: calendar)
        }
    }

    @Test func futureDaysAreRefusedAndTodayIsAllowed() throws {
        try WeightRules.validate(WeightRecord(day: date("2026-10-02T23:59:00Z"), kg: 58), today: today, calendar: calendar)
        #expect(throws: WeightRepositoryError.futureDate) {
            try WeightRules.validate(WeightRecord(day: day("2026-10-03"), kg: 58), today: today, calendar: calendar)
        }
    }

    @Test func sameDayDuplicatesKeepTheFirstIdWithItsOwnWeight() {
        let a = WeightRecord(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!, day: day("2026-10-01"), kg: 58.0)
        let b = WeightRecord(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!, day: date("2026-10-01T09:00:00Z"), kg: 58.4)
        let other = WeightRecord(day: day("2026-09-24"), kg: 57.5)
        let result = WeightRules.mergingDuplicates([b, other, a], calendar: calendar)
        #expect(result.entries == [other, a])
        #expect(result.removedIDs == [b.id])
    }

    @Test func pickerRangeRunsFromTheLastPeriodToToday() {
        // Due 2027-01-19 → first day of the last period 2026-04-14.
        let range = WeightRules.dayRange(dueDate: date("2027-01-19T12:00:00Z"), now: today, calendar: calendar)
        #expect(range.lowerBound == day("2026-04-14"))
        #expect(range.upperBound == date("2026-10-02T23:59:59Z"))
    }

    @Test func decimalEntryAcceptsCommaAndDotAndChecksTheRange() {
        #expect(DecimalEntry(text: "56,2", range: WeightRules.kgRange) == .valid(56.2))
        #expect(DecimalEntry(text: " 56.24 ", range: WeightRules.kgRange) == .valid(56.2))
        #expect(DecimalEntry(text: "", range: WeightRules.kgRange) == .empty)
        #expect(DecimalEntry(text: "abc", range: WeightRules.kgRange) == .invalid)
        #expect(DecimalEntry(text: "250", range: WeightRules.kgRange) == .invalid)
        #expect(DecimalEntry(text: "160", range: MaternalProfile.heightRange) == .valid(160))
        #expect(DecimalEntry(text: "119,9", range: MaternalProfile.heightRange) == .invalid)
    }
}
```

`Packages/KickCore/Tests/KickCoreTests/WeightGuidanceTests.swift` (toàn bộ file):
```swift
import Foundation
import Testing
@testable import KickCore

struct WeightGuidanceTests {
    private func expectRange(
        _ range: ClosedRange<Double>,
        _ low: Double,
        _ high: Double,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(abs(range.lowerBound - low) < 1e-4, "\(range)", sourceLocation: sourceLocation)
        #expect(abs(range.upperBound - high) < 1e-4, "\(range)", sourceLocation: sourceLocation)
    }

    @Test func bmiIsRoundedToOneDecimal() {
        #expect(WeightGuidance.bmi(weightKg: 52, heightCm: 160) == 20.3)
        // 63.9 / 1.6² = 24.96 → shown and classified as 25.0.
        #expect(WeightGuidance.bmi(weightKg: 63.9, heightCm: 160) == 25.0)
    }

    @Test func categoriesSwitchAtTheIOMCutOffs() {
        #expect(BMICategory(bmi: 18.4) == .under)
        #expect(BMICategory(bmi: 18.5) == .normal)
        #expect(BMICategory(bmi: 24.9) == .normal)
        #expect(BMICategory(bmi: 25.0) == .over)
        #expect(BMICategory(bmi: 29.9) == .over)
        #expect(BMICategory(bmi: 30.0) == .obese)
        #expect(BMICategory(bmi: WeightGuidance.bmi(weightKg: 63.9, heightCm: 160)) == .over)
    }

    @Test func totalGainByWeek40FollowsIOM2009() {
        #expect(BMICategory.under.totalGainKg == 12.5...18.0)
        #expect(BMICategory.normal.totalGainKg == 11.5...16.0)
        #expect(BMICategory.over.totalGainKg == 7.0...11.5)
        #expect(BMICategory.obese.totalGainKg == 5.0...9.0)
    }

    @Test(arguments: BMICategory.allCases)
    func firstTrimesterIsTheSameForEveryGroup(category: BMICategory) {
        expectRange(WeightGuidance.range(atWeek: 0, category: category), 0, 0)
        expectRange(WeightGuidance.range(atWeek: 6.5, category: category), 0.25, 1.0)
        expectRange(WeightGuidance.range(atWeek: 13, category: category), 0.5, 2.0)
    }

    @Test func week14StartsTowardsEachGroupsTotal() {
        // 0.5 + (low − 0.5) / 27 and 2.0 + (high − 2.0) / 27.
        expectRange(WeightGuidance.range(atWeek: 14, category: .under), 0.94444, 2.59259)
        expectRange(WeightGuidance.range(atWeek: 14, category: .normal), 0.90741, 2.51852)
        expectRange(WeightGuidance.range(atWeek: 14, category: .over), 0.74074, 2.35185)
        expectRange(WeightGuidance.range(atWeek: 14, category: .obese), 0.66667, 2.25926)
    }

    @Test(arguments: BMICategory.allCases)
    func week40IsTheTotalAndLaterWeeksStayThere(category: BMICategory) {
        let total = category.totalGainKg
        expectRange(WeightGuidance.range(atWeek: 40, category: category), total.lowerBound, total.upperBound)
        expectRange(WeightGuidance.range(atWeek: 42, category: category), total.lowerBound, total.upperBound)
        expectRange(WeightGuidance.range(atWeek: -1, category: category), 0, 0)
    }

    @Test func statusComparesTheGainWithThatWeeksRange() {
        // Normal BMI, week 24: 4.98…7.70 kg.
        #expect(WeightGuidance.status(gain: 6.0, week: 24, category: .normal) == .inRange)
        #expect(WeightGuidance.status(gain: 4.9, week: 24, category: .normal) == .below)
        #expect(WeightGuidance.status(gain: 7.8, week: 24, category: .normal) == .above)
        #expect(WeightGuidance.status(gain: 2.0, week: 13, category: .obese) == .inRange)
        #expect(WeightGuidance.status(gain: 0, week: 0, category: .under) == .inRange)
    }
}
```

`Packages/KickCore/Tests/KickCoreTests/MaternalProfileTests.swift` (toàn bộ file):
```swift
import Foundation
import Testing
@testable import KickCore

struct MaternalProfileTests {
    @Test func missingValuesLoadAsNil() {
        let profile = MaternalProfile.load(from: makeTestDefaults())
        #expect(profile == MaternalProfile())
        #expect(profile.bmi == nil)
        #expect(profile.category == nil)
    }

    @Test func savedValuesRoundTripRoundedToOneDecimal() throws {
        let defaults = makeTestDefaults()
        try MaternalProfile(preWeightKg: 52.04, heightCm: 160).save(to: defaults)
        let profile = MaternalProfile.load(from: defaults)
        #expect(profile == MaternalProfile(preWeightKg: 52.0, heightCm: 160))
        #expect(profile.bmi == 20.3)
        #expect(profile.category == .normal)
        #expect(defaults.double(forKey: SettingsKey.maternalPreWeightKg) == 52.0)
    }

    @Test func heightIsOptionalAndClearingWritesZero() throws {
        let defaults = makeTestDefaults()
        try MaternalProfile(preWeightKg: 52, heightCm: 160).save(to: defaults)
        try MaternalProfile(preWeightKg: 52).save(to: defaults)
        let profile = MaternalProfile.load(from: defaults)
        #expect(profile.heightCm == nil)
        #expect(profile.category == nil)
        #expect(defaults.object(forKey: SettingsKey.maternalHeightCm) as? Double == 0)
    }

    @Test func outOfRangeValuesAreRefusedWithoutWritingAnything() throws {
        let defaults = makeTestDefaults()
        try MaternalProfile(preWeightKg: 52, heightCm: 160).save(to: defaults)
        #expect(throws: MaternalProfileError.invalidWeight) {
            try MaternalProfile(preWeightKg: 29.9, heightCm: 170).save(to: defaults)
        }
        #expect(throws: MaternalProfileError.invalidHeight) {
            try MaternalProfile(preWeightKg: 60, heightCm: 220.1).save(to: defaults)
        }
        #expect(MaternalProfile.load(from: defaults) == MaternalProfile(preWeightKg: 52, heightCm: 160))
        try MaternalProfile(preWeightKg: 30, heightCm: 120).save(to: defaults)
        try MaternalProfile(preWeightKg: 200, heightCm: 220).save(to: defaults)
    }

    @Test func storedValuesOutsideTheRangesAreIgnored() {
        let defaults = makeTestDefaults()
        defaults.set(12.0, forKey: SettingsKey.maternalPreWeightKg)
        defaults.set(300.0, forKey: SettingsKey.maternalHeightCm)
        #expect(MaternalProfile.load(from: defaults) == MaternalProfile())
    }
}
```

- [ ] **Step 2: Chạy để thấy fail**

Run: `scripts/test-core.sh --filter "WeightRulesTests|WeightGuidanceTests|MaternalProfileTests"`
Expected: lỗi biên dịch `cannot find 'WeightRecord' in scope`, `cannot find 'BMICategory' in scope`, `cannot find 'MaternalProfile' in scope`.

- [ ] **Step 3: Viết code**

`Packages/KickCore/Sources/KickCore/WeightRecords.swift` (toàn bộ file):
```swift
import Foundation

/// One logged weight (value snapshot of the SwiftData `WeightEntry`).
public struct WeightRecord: Equatable, Sendable, Identifiable {
    public let id: UUID
    /// Start of the calendar day.
    public var day: Date
    /// 30.0–200.0 kg, one decimal.
    public var kg: Double

    public init(id: UUID = UUID(), day: Date, kg: Double) {
        self.id = id
        self.day = day
        self.kg = kg
    }
}

public enum WeightRepositoryError: Error, Equatable, Sendable {
    case futureDate
    case outOfRange
}

/// Storage for the mother's weights. Implementations validate every write with
/// `WeightRules` and merge iCloud duplicates on read.
@MainActor
public protocol WeightRepository: AnyObject {
    /// Every entry, oldest first, one per day.
    func entries() throws -> [WeightRecord]
    /// Stores the entry for `entry.day`, replacing the weight already stored for
    /// that day (which keeps its id). Throws `.futureDate` or `.outOfRange`.
    func save(_ entry: WeightRecord, today: Date) throws
    /// No-op when no entry has that id (it may already be gone via iCloud).
    func delete(id: UUID) throws
}

/// Validation and duplicate merging shared by `WeightStore` and the test fake.
public enum WeightRules {
    public static let kgRange: ClosedRange<Double> = 30.0...200.0

    /// One decimal, as entered and shown.
    public static func rounded(_ kg: Double) -> Double {
        (kg * 10).rounded() / 10
    }

    public static func normalized(_ entry: WeightRecord, calendar: Calendar) -> WeightRecord {
        WeightRecord(id: entry.id, day: calendar.startOfDay(for: entry.day), kg: rounded(entry.kg))
    }

    public static func validate(_ entry: WeightRecord, today: Date, calendar: Calendar) throws {
        guard calendar.startOfDay(for: entry.day) <= calendar.startOfDay(for: today) else {
            throw WeightRepositoryError.futureDate
        }
        guard entry.kg.isFinite, kgRange.contains(rounded(entry.kg)) else {
            throw WeightRepositoryError.outOfRange
        }
    }

    /// Several entries on one day can only come from iCloud sync. Keeps the one
    /// whose id sorts first (`uuidString`) with its own weight, so every device
    /// picks the same one. Returns the entries oldest first and the ids to delete.
    public static func mergingDuplicates(_ entries: [WeightRecord], calendar: Calendar) -> (entries: [WeightRecord], removedIDs: [UUID]) {
        let byDay = Dictionary(grouping: entries.map { normalized($0, calendar: calendar) }, by: \.day)
        var kept: [WeightRecord] = []
        var removed: [UUID] = []
        for day in byDay.keys.sorted() {
            let group = byDay[day, default: []].sorted { $0.id.uuidString < $1.id.uuidString }
            guard let first = group.first else { continue }
            kept.append(first)
            removed += group.dropFirst().map(\.id)
        }
        return (kept, removed)
    }

    /// What the entry's date picker allows: from the first day of the last
    /// period (due date − 280 days) to the end of today.
    public static func dayRange(dueDate: Date, now: Date, calendar: Calendar) -> ClosedRange<Date> {
        let today = calendar.startOfDay(for: now)
        let lmp = calendar.date(byAdding: .day, value: -PregnancyTimeline.pregnancyLengthDays, to: calendar.startOfDay(for: dueDate)) ?? today
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        return min(lmp, today)...tomorrow.addingTimeInterval(-1)
    }
}

/// What a decimal field holds ("56,2" or "56.2"), rounded to `fractionDigits`
/// and checked against `range`.
public enum DecimalEntry: Equatable, Sendable {
    case empty
    case valid(Double)
    /// Not a number, or outside the range.
    case invalid

    public init(text: String, range: ClosedRange<Double>, fractionDigits: Int = 1) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self = .empty
            return
        }
        guard let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")), value.isFinite else {
            self = .invalid
            return
        }
        let scale = pow(10, Double(fractionDigits))
        let rounded = (value * scale).rounded() / scale
        self = range.contains(rounded) ? .valid(rounded) : .invalid
    }
}
```

`Packages/KickCore/Sources/KickCore/WeightGuidance.swift` (toàn bộ file):
```swift
import Foundation

/// IOM 2009 pre-pregnancy BMI groups (standard WHO cut-offs, not the Asian ones:
/// the doctor decides, see docs/content-review-for-doctor.md §8).
public enum BMICategory: String, Sendable, CaseIterable {
    case under
    case normal
    case over
    case obese

    /// `bmi` as shown, one decimal: < 18.5, 18.5–24.9, 25.0–29.9, ≥ 30.0.
    public init(bmi: Double) {
        switch bmi {
        case ..<18.5: self = .under
        case ..<25.0: self = .normal
        case ..<30.0: self = .over
        default: self = .obese
        }
    }

    /// Recommended total gain by week 40, single pregnancy (IOM 2009).
    public var totalGainKg: ClosedRange<Double> {
        switch self {
        case .under: 12.5...18.0
        case .normal: 11.5...16.0
        case .over: 7.0...11.5
        case .obese: 5.0...9.0
        }
    }
}

public enum WeightStatus: String, Sendable, CaseIterable {
    case below
    case inRange
    case above
}

/// The recommended gain at a given week (spec §2.4): 0 → 0.5–2.0 kg linearly
/// over weeks 0–13 (every group), then linearly to the group's week-40 total,
/// then flat.
public enum WeightGuidance {
    public static let firstTrimesterEndWeek = 13.0
    public static let termWeek = 40.0
    public static let firstTrimesterGainKg: ClosedRange<Double> = 0.5...2.0

    /// kg / m², one decimal (as shown and classified).
    public static func bmi(weightKg: Double, heightCm: Double) -> Double {
        let meters = heightCm / 100
        return ((weightKg / (meters * meters)) * 10).rounded() / 10
    }

    /// Recommended gain since pre-pregnancy at `week` (decimal weeks).
    public static func range(atWeek week: Double, category: BMICategory) -> ClosedRange<Double> {
        let week = min(max(week, 0), termWeek)
        let early = firstTrimesterGainKg
        if week <= firstTrimesterEndWeek {
            let share = week / firstTrimesterEndWeek
            return (early.lowerBound * share)...(early.upperBound * share)
        }
        let share = (week - firstTrimesterEndWeek) / (termWeek - firstTrimesterEndWeek)
        let total = category.totalGainKg
        let low = early.lowerBound + share * (total.lowerBound - early.lowerBound)
        let high = early.upperBound + share * (total.upperBound - early.upperBound)
        return low...high
    }

    public static func status(gain: Double, week: Double, category: BMICategory) -> WeightStatus {
        let range = range(atWeek: week, category: category)
        if gain < range.lowerBound - 1e-9 { return .below }
        if gain > range.upperBound + 1e-9 { return .above }
        return .inRange
    }
}
```

`Packages/KickCore/Sources/KickCore/MaternalProfile.swift` (toàn bộ file):
```swift
import Foundation

public enum MaternalProfileError: Error, Equatable, Sendable {
    case invalidWeight
    case invalidHeight
}

/// Pre-pregnancy weight and height, kept in `AppGroup.defaults` (not synced),
/// like `PregnancyProfile`. 0 means "not set" (so `@AppStorage` views update).
public struct MaternalProfile: Equatable, Sendable {
    public static let preWeightRange = WeightRules.kgRange
    public static let heightRange: ClosedRange<Double> = 120.0...220.0

    public var preWeightKg: Double?
    public var heightCm: Double?

    public init(preWeightKg: Double? = nil, heightCm: Double? = nil) {
        self.preWeightKg = preWeightKg
        self.heightCm = heightCm
    }

    /// Only with both values.
    public var bmi: Double? {
        guard let preWeightKg, let heightCm else { return nil }
        return WeightGuidance.bmi(weightKg: preWeightKg, heightCm: heightCm)
    }

    /// No height (or no pre-pregnancy weight) → no group, no range, no status.
    public var category: BMICategory? { bmi.map(BMICategory.init(bmi:)) }

    public static func load(from defaults: UserDefaults) -> MaternalProfile {
        let weight = defaults.double(forKey: SettingsKey.maternalPreWeightKg)
        let height = defaults.double(forKey: SettingsKey.maternalHeightCm)
        return MaternalProfile(
            preWeightKg: preWeightRange.contains(weight) ? weight : nil,
            heightCm: heightRange.contains(height) ? height : nil
        )
    }

    /// Rounds both to one decimal; throws before writing anything when either is out of range.
    public func save(to defaults: UserDefaults) throws {
        let weight = preWeightKg.map(WeightRules.rounded)
        let height = heightCm.map(WeightRules.rounded)
        if let weight, !Self.preWeightRange.contains(weight) { throw MaternalProfileError.invalidWeight }
        if let height, !Self.heightRange.contains(height) { throw MaternalProfileError.invalidHeight }
        defaults.set(weight ?? 0, forKey: SettingsKey.maternalPreWeightKg)
        defaults.set(height ?? 0, forKey: SettingsKey.maternalHeightCm)
    }
}
```

Trong `Packages/KickCore/Sources/KickCore/Settings.swift`, thay:
```swift
    /// A short vibration on every counted tap. Missing means on.
    public static let kickHapticsEnabled = "kickHapticsEnabled"
```
bằng:
```swift
    /// A short vibration on every counted tap. Missing means on.
    public static let kickHapticsEnabled = "kickHapticsEnabled"
    /// Pre-pregnancy weight in kg, 30–200; 0 means "not set" (`MaternalProfile`).
    public static let maternalPreWeightKg = "maternalPreWeightKg"
    /// Height in cm, 120–220; 0 means "not set".
    public static let maternalHeightCm = "maternalHeightCm"
```

- [ ] **Step 4: Chạy test**

Run: `scripts/test-core.sh --filter "WeightRulesTests|WeightGuidanceTests|MaternalProfileTests"`
Expected: PASS (18 test: 6 + 7 + 5).

- [ ] **Step 5: Viết test trước — thống kê, dữ liệu mẫu**

`Packages/KickCore/Tests/KickCoreTests/WeightStatsTests.swift` (toàn bộ file):
```swift
import Foundation
import Testing
@testable import KickCore

struct WeightStatsTests {
    /// 24w3d on 2026-10-02; first day of the last period 2026-04-14.
    let dueDate = date("2027-01-19T12:00:00Z")
    let profile = MaternalProfile(preWeightKg: 52, heightCm: 160)

    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00Z") }

    @Test func pointsCarryTheWeekTheGainAndTheStatus() throws {
        let entries = [
            WeightRecord(day: day("2026-10-02"), kg: 58.0), // 24w3d
            WeightRecord(day: day("2026-07-07"), kg: 53.1), // 12w0d
        ]
        let points = WeightStats.points(entries, profile: profile, dueDate: dueDate, calendar: utcCalendar)
        #expect(points.map(\.kg) == [53.1, 58.0])
        #expect(points.map(\.week) == [GestationalWeek(weeks: 12, days: 0), GestationalWeek(weeks: 24, days: 3)])
        #expect(points.map(\.gainKg) == [1.1, 6.0])
        #expect(points.map(\.status) == [.inRange, .inRange])
        #expect(abs(try #require(points.last).exactWeek - (24 + 3.0 / 7)) < 1e-9)
    }

    @Test func noHeightMeansNoStatusAndNoPreWeightMeansNoGain() {
        let entries = [WeightRecord(day: day("2026-10-02"), kg: 58.0)]
        let noHeight = WeightStats.points(entries, profile: MaternalProfile(preWeightKg: 52), dueDate: dueDate, calendar: utcCalendar)
        #expect(noHeight.first?.gainKg == 6.0)
        #expect(noHeight.first?.status == nil)
        let nothing = WeightStats.points(entries, profile: MaternalProfile(), dueDate: dueDate, calendar: utcCalendar)
        #expect(nothing.first?.gainKg == nil)
        #expect(nothing.first?.status == nil)
    }

    @Test func entriesBeforeThePregnancyAreLeftOffTheChart() {
        let entries = [WeightRecord(day: day("2026-04-13"), kg: 52.0), WeightRecord(day: day("2026-04-14"), kg: 52.1)]
        let points = WeightStats.points(entries, profile: profile, dueDate: dueDate, calendar: utcCalendar)
        #expect(points.map(\.day) == [day("2026-04-14")])
    }

    @Test func sectionsGoNewestWeekFirstWithDaysOutsideLast() {
        let before = WeightRecord(day: day("2026-04-01"), kg: 51.8)
        let w24a = WeightRecord(day: day("2026-09-29"), kg: 57.6)
        let w24b = WeightRecord(day: day("2026-10-02"), kg: 58.0)
        let w12 = WeightRecord(day: day("2026-07-07"), kg: 53.1)
        let sections = WeightStats.sections([w12, before, w24a, w24b], dueDate: dueDate, calendar: utcCalendar)
        #expect(sections.map(\.week) == [24, 12, nil])
        #expect(sections.first?.entries == [w24b, w24a])
        #expect(sections.last?.entries == [before])
    }

    @Test func bandCoversWeeks0To40() {
        let band = WeightStats.band(category: .normal)
        #expect(band.count == 41)
        #expect(band.first == WeightBandPoint(week: 0, lowKg: 0, highKg: 0))
        #expect(band[13].lowKg == 0.5 && band[13].highKg == 2.0)
        #expect(band.last == WeightBandPoint(week: 40, lowKg: 11.5, highKg: 16.0))
    }
}
```

`Packages/KickCore/Tests/KickCoreTests/WeightSeedTests.swift` (toàn bộ file):
```swift
import Foundation
import Testing
@testable import KickCore

struct WeightSeedTests {
    @Test func samplesSitOnTheFirstDayOfTheirWeek() {
        // 38w0d on 2026-10-02: every sample is in the past.
        let due = date("2026-10-16T12:00:00Z")
        let now = date("2026-10-02T12:00:00Z")
        let entries = WeightSeed.entries(dueDate: due, today: now, calendar: utcCalendar)
        #expect(entries.map(\.kg) == [53.1, 54.6, 56.2, 58.0, 59.4, 60.9])
        let points = WeightStats.points(entries, profile: WeightSeed.profile, dueDate: due, calendar: utcCalendar)
        #expect(points.map(\.week.weeks) == [12, 16, 20, 24, 27, 30])
        #expect(points.allSatisfy { $0.week.days == 0 })
        #expect(points.last?.gainKg == 8.9)
        #expect(points.last?.status == .inRange)
        #expect(WeightSeed.profile.category == .normal)
    }

    @Test func futureWeeksAreLeftOut() {
        // 24w3d: weeks 27 and 30 have not come yet.
        let entries = WeightSeed.entries(dueDate: date("2027-01-19T12:00:00Z"), today: date("2026-10-02T12:00:00Z"), calendar: utcCalendar)
        #expect(entries.map(\.kg) == [53.1, 54.6, 56.2, 58.0])
    }

    @Test func seedWeightsNeedsUITesting() {
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-seedWeights"]).seedWeights)
        #expect(UITestLaunchOptions(arguments: ["-seedWeights"]).seedWeights == false)
        #expect(UITestLaunchOptions(arguments: ["-uiTesting"]).seedWeights == false)
    }
}
```

- [ ] **Step 6: Chạy để thấy fail**

Run: `scripts/test-core.sh --filter "WeightStatsTests|WeightSeedTests"`
Expected: lỗi biên dịch `cannot find 'WeightStats' in scope`, `cannot find 'WeightSeed' in scope`, `value of type 'UITestLaunchOptions' has no member 'seedWeights'`.

- [ ] **Step 7: Viết code**

`Packages/KickCore/Sources/KickCore/WeightStats.swift` (toàn bộ file):
```swift
import Foundation

/// A logged weight placed in the pregnancy, for the chart, the summary and the list.
public struct WeightPoint: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let day: Date
    public let kg: Double
    /// Gestational age on that day.
    public let week: GestationalWeek
    /// Gain since pre-pregnancy (one decimal); nil without a pre-pregnancy weight.
    public let gainKg: Double?
    /// nil without a BMI group (no height or no pre-pregnancy weight).
    public let status: WeightStatus?

    /// Weeks with days as a fraction (24w3d → 24.43), the chart's x value.
    public var exactWeek: Double { Double(week.weeks) + Double(week.days) / 7 }
}

/// One group of the history list: a pregnancy week, or (nil) days outside it.
public struct WeightSection: Equatable, Sendable, Identifiable {
    public let week: Int?
    /// Newest first.
    public let entries: [WeightRecord]

    public var id: Int { week ?? -1 }
}

/// The recommended range at a whole week, for the chart's band.
public struct WeightBandPoint: Equatable, Sendable, Identifiable {
    public let week: Int
    public let lowKg: Double
    public let highKg: Double

    public var id: Int { week }
}

public enum WeightStats {
    /// Entries inside the pregnancy (weeks 0–44), oldest first.
    public static func points(
        _ entries: [WeightRecord],
        profile: MaternalProfile,
        dueDate: Date,
        calendar: Calendar = .current
    ) -> [WeightPoint] {
        entries.sorted { $0.day < $1.day }.compactMap { entry in
            guard let timeline = PregnancyTimeline(dueDate: dueDate, now: entry.day, calendar: calendar) else { return nil }
            let week = timeline.week
            let gain = profile.preWeightKg.map { WeightRules.rounded(entry.kg - $0) }
            let exactWeek = Double(week.weeks) + Double(week.days) / 7
            let status: WeightStatus? = gain.flatMap { gain in
                profile.category.map { WeightGuidance.status(gain: gain, week: exactWeek, category: $0) }
            }
            return WeightPoint(id: entry.id, day: entry.day, kg: entry.kg, week: week, gainKg: gain, status: status)
        }
    }

    /// The history list: newest week first, newest day first inside a week;
    /// days outside the pregnancy (dates changed later) in a last group.
    public static func sections(_ entries: [WeightRecord], dueDate: Date, calendar: Calendar = .current) -> [WeightSection] {
        let newestFirst = entries.sorted { $0.day > $1.day }
        var weeks: [Int?] = []
        var grouped: [Int?: [WeightRecord]] = [:]
        for entry in newestFirst {
            let week = PregnancyTimeline(dueDate: dueDate, now: entry.day, calendar: calendar)?.week.weeks
            if grouped[week] == nil { weeks.append(week) }
            grouped[week, default: []].append(entry)
        }
        let ordered = weeks.compactMap { $0 }.sorted(by: >).map(Optional.some) + (weeks.contains(nil) ? [nil] : [])
        return ordered.map { WeightSection(week: $0, entries: grouped[$0] ?? []) }
    }

    /// The recommended range at weeks 0…40.
    public static func band(category: BMICategory) -> [WeightBandPoint] {
        (0...Int(WeightGuidance.termWeek)).map { week in
            let range = WeightGuidance.range(atWeek: Double(week), category: category)
            return WeightBandPoint(week: week, lowKg: range.lowerBound, highKg: range.upperBound)
        }
    }
}
```

`Packages/KickCore/Sources/KickCore/WeightSeed.swift` (toàn bộ file):
```swift
import Foundation

/// Sample weights for UI tests and screenshots (`-uiTesting -seedWeights`): the
/// design's `PRE_KG` and `SEED_W`, placed at those weeks of the stored pregnancy.
public enum WeightSeed {
    public static let preWeightKg = 52.0
    public static let heightCm = 160.0
    /// (gestational week, kg) from the prototype.
    public static let samples: [(week: Int, kg: Double)] = [
        (12, 53.1), (16, 54.6), (20, 56.2), (24, 58.0), (27, 59.4), (30, 60.9),
    ]

    public static var profile: MaternalProfile {
        MaternalProfile(preWeightKg: preWeightKg, heightCm: heightCm)
    }

    /// The samples on the first day of their week, leaving out days after today.
    public static func entries(dueDate: Date, today now: Date, calendar: Calendar = .current) -> [WeightRecord] {
        let today = calendar.startOfDay(for: now)
        guard let lmp = calendar.date(
            byAdding: .day, value: -PregnancyTimeline.pregnancyLengthDays, to: calendar.startOfDay(for: dueDate)
        ) else { return [] }
        return samples.compactMap { sample in
            guard let day = calendar.date(byAdding: .day, value: sample.week * 7, to: lmp), day <= today else { return nil }
            return WeightRecord(day: day, kg: sample.kg)
        }
    }
}
```

Trong `Packages/KickCore/Sources/KickCore/UITestLaunchOptions.swift`, thay:
```swift
/// - `-seedSessions` stores `SessionSeed`'s four weeks of kick sessions.
```
bằng:
```swift
/// - `-seedSessions` stores `SessionSeed`'s four weeks of kick sessions.
/// - `-seedWeights` stores `WeightSeed`'s pre-pregnancy weight, height and weights.
```

Trong `Packages/KickCore/Sources/KickCore/UITestLaunchOptions.swift`, thay:
```swift
    public let seedSessions: Bool
```
bằng:
```swift
    public let seedSessions: Bool
    public let seedWeights: Bool
```

Trong `Packages/KickCore/Sources/KickCore/UITestLaunchOptions.swift`, thay:
```swift
        seedSessions = isUITesting && arguments.contains("-seedSessions")
```
bằng:
```swift
        seedSessions = isUITesting && arguments.contains("-seedSessions")
        seedWeights = isUITesting && arguments.contains("-seedWeights")
```

- [ ] **Step 8: Chạy test**

Run: `scripts/test-core.sh --filter "WeightStatsTests|WeightSeedTests|UITestLaunchOptionsTests"`
Expected: PASS (`WeightStatsTests` 5, `WeightSeedTests` 3; test cũ của `UITestLaunchOptions` vẫn xanh).

- [ ] **Step 9: Viết test trước — coordinator**

Thêm vào cuối `Packages/KickCore/Tests/KickCoreTests/TestSupport.swift`:
```swift
/// In-memory WeightRepository with the same rules as WeightStore.
@MainActor
final class FakeWeightRepository: WeightRepository {
    struct Failed: Error {}

    private(set) var stored: [WeightRecord] = []
    var calendar = utcCalendar
    var failNextRead = false
    var failNextWrite = false
    private(set) var reads = 0

    func seed(_ entries: WeightRecord...) {
        stored += entries
    }

    func entries() throws -> [WeightRecord] {
        if failNextRead {
            failNextRead = false
            throw Failed()
        }
        reads += 1
        let merged = WeightRules.mergingDuplicates(stored, calendar: calendar)
        stored = merged.entries
        return merged.entries
    }

    func save(_ entry: WeightRecord, today: Date) throws {
        try WeightRules.validate(entry, today: today, calendar: calendar)
        if failNextWrite {
            failNextWrite = false
            throw Failed()
        }
        let normalized = WeightRules.normalized(entry, calendar: calendar)
        if let index = stored.firstIndex(where: { $0.day == normalized.day }) {
            stored[index].kg = normalized.kg
        } else {
            stored.append(normalized)
        }
    }

    func delete(id: UUID) throws {
        if failNextWrite {
            failNextWrite = false
            throw Failed()
        }
        stored.removeAll { $0.id == id }
    }
}
```

`Packages/KickCore/Tests/KickCoreTests/WeightCoordinatorTests.swift` (toàn bộ file):
```swift
import Foundation
import Testing
@testable import KickCore

@MainActor
struct WeightCoordinatorTests {
    let repository = FakeWeightRepository()
    let clock = TestClock(date("2026-10-02T12:00:00Z"))
    let defaults = makeTestDefaults()
    let coordinator: WeightCoordinator

    init() {
        let clock = clock
        coordinator = WeightCoordinator(store: repository, defaults: defaults, calendar: utcCalendar, now: { clock.now })
    }

    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00Z") }

    @Test func loadReadsTheEntriesAndTheProfile() async throws {
        repository.seed(WeightRecord(day: day("2026-09-29"), kg: 57.6), WeightRecord(day: day("2026-09-01"), kg: 56.0))
        try MaternalProfile(preWeightKg: 52, heightCm: 160).save(to: defaults)
        await coordinator.load()
        #expect(coordinator.entries.map(\.kg) == [56.0, 57.6])
        #expect(coordinator.latest?.kg == 57.6)
        #expect(coordinator.profile.category == .normal)
        #expect(coordinator.failure == nil)
    }

    @Test func savingTheSameDayTwiceKeepsOneEntryAndItsID() async {
        await coordinator.load()
        #expect(coordinator.save(kg: 57.95, on: date("2026-10-02T08:00:00Z")) == nil)
        let first = coordinator.entries.first?.id
        #expect(coordinator.save(kg: 58.2, on: day("2026-10-02")) == nil)
        #expect(coordinator.entries.count == 1)
        #expect(coordinator.entries.first?.id == first)
        #expect(coordinator.entry(on: date("2026-10-02T20:00:00Z"))?.kg == 58.2)
    }

    @Test func validationErrorsAreReturnedNotShown() async {
        await coordinator.load()
        #expect(coordinator.save(kg: 25, on: day("2026-10-02")) == .outOfRange)
        #expect(coordinator.save(kg: 58, on: day("2026-10-03")) == .futureDate)
        #expect(coordinator.failure == nil)
        #expect(coordinator.entries.isEmpty)
    }

    @Test func storeErrorsAreShownAndKeepTheEntries() async {
        repository.seed(WeightRecord(day: day("2026-09-29"), kg: 57.6))
        await coordinator.load()
        repository.failNextWrite = true
        #expect(coordinator.save(kg: 58, on: day("2026-10-02")) == .saveFailed)
        #expect(coordinator.failure == .saveFailed)
        #expect(coordinator.entries.map(\.kg) == [57.6])
        coordinator.clearFailure()
        #expect(coordinator.failure == nil)
    }

    @Test func failedLoadKeepsWhatWasLoaded() async {
        repository.seed(WeightRecord(day: day("2026-09-29"), kg: 57.6))
        await coordinator.load()
        repository.failNextRead = true
        await coordinator.load()
        #expect(coordinator.failure == .loadFailed)
        #expect(coordinator.entries.count == 1)
    }

    @Test func deleteRemovesTheEntry() async throws {
        repository.seed(WeightRecord(day: day("2026-09-29"), kg: 57.6))
        await coordinator.load()
        let id = try #require(coordinator.entries.first?.id)
        #expect(coordinator.delete(id: id) == nil)
        #expect(coordinator.entries.isEmpty)
        repository.failNextWrite = true
        #expect(coordinator.delete(id: UUID()) == .saveFailed)
    }

    @Test func profileUpdatesAreValidated() {
        #expect(coordinator.updateProfile(MaternalProfile(preWeightKg: 52, heightCm: 160)) == nil)
        #expect(coordinator.profile.bmi == 20.3)
        #expect(coordinator.updateProfile(MaternalProfile(preWeightKg: 52, heightCm: 99)) == .invalidHeight)
        #expect(coordinator.updateProfile(MaternalProfile(preWeightKg: 12, heightCm: 160)) == .outOfRange)
        #expect(coordinator.profile == MaternalProfile(preWeightKg: 52, heightCm: 160))
        #expect(coordinator.updateProfile(MaternalProfile(preWeightKg: 52)) == nil)
        #expect(coordinator.profile.category == nil)
        #expect(coordinator.failure == nil)
    }

    @Test func profileChangedElsewhereIsPickedUpOnLoad() async throws {
        try MaternalProfile(preWeightKg: 60).save(to: defaults)
        await coordinator.load()
        #expect(coordinator.profile.preWeightKg == 60)
    }
}
```

- [ ] **Step 10: Chạy để thấy fail**

Run: `scripts/test-core.sh --filter WeightCoordinatorTests`
Expected: lỗi biên dịch `cannot find 'WeightCoordinator' in scope`.

- [ ] **Step 11: Viết code**

`Packages/KickCore/Sources/KickCore/WeightCoordinator.swift` (toàn bộ file):
```swift
import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "weight")

public enum WeightFailure: Error, Equatable, Sendable {
    case loadFailed
    case saveFailed
    case futureDate
    case outOfRange
    case invalidHeight

    init(_ error: Error) {
        switch error {
        case WeightRepositoryError.futureDate: self = .futureDate
        case WeightRepositoryError.outOfRange, MaternalProfileError.invalidWeight: self = .outOfRange
        case MaternalProfileError.invalidHeight: self = .invalidHeight
        default: self = .saveFailed
        }
    }
}

/// Single entry point for the mother's weights and her pre-pregnancy profile,
/// used by the UI. Nothing here schedules reminders, so writes are synchronous;
/// `load()` is shared by concurrent callers like the other coordinators.
@MainActor
@Observable
public final class WeightCoordinator {
    /// Oldest first, one per day.
    public private(set) var entries: [WeightRecord] = []
    public private(set) var profile: MaternalProfile
    /// Store errors for the screen's alert; validation errors are only returned.
    public private(set) var failure: WeightFailure?

    private let store: WeightRepository
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let now: @MainActor () -> Date
    /// The in-flight `load()`, so concurrent callers share one refresh.
    private var loadTask: Task<Void, Never>?

    public init(
        store: WeightRepository,
        defaults: UserDefaults,
        calendar: Calendar = .current,
        now: @escaping @MainActor () -> Date = { Date() }
    ) {
        self.store = store
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
        profile = MaternalProfile.load(from: defaults)
    }

    public var latest: WeightRecord? { entries.last }

    public func entry(on day: Date) -> WeightRecord? {
        let start = calendar.startOfDay(for: day)
        return entries.first { $0.day == start }
    }

    /// Re-reads the store (e.g. after iCloud sync) and the profile. Call on
    /// launch and whenever the app becomes active.
    public func load() async {
        if let loadTask {
            await loadTask.value
            return
        }
        let task = Task { self.refresh() }
        loadTask = task
        await task.value
        loadTask = nil
    }

    /// Stores the weight for that day (one per day: a second save that day
    /// replaces the first). Future days and weights outside 30–200 kg are refused.
    @discardableResult
    public func save(kg: Double, on day: Date) -> WeightFailure? {
        let start = calendar.startOfDay(for: day)
        let record = WeightRecord(id: entry(on: start)?.id ?? UUID(), day: start, kg: kg)
        return write { try store.save(record, today: now()) }
    }

    @discardableResult
    public func delete(id: UUID) -> WeightFailure? {
        write { try store.delete(id: id) }
    }

    /// Pre-pregnancy weight 30–200 kg and height 120–220 cm; nil clears a value.
    @discardableResult
    public func updateProfile(_ newProfile: MaternalProfile) -> WeightFailure? {
        do {
            try newProfile.save(to: defaults)
        } catch {
            return WeightFailure(error)
        }
        profile = MaternalProfile.load(from: defaults)
        return nil
    }

    public func clearFailure() {
        failure = nil
    }

    private func write(_ change: () throws -> Void) -> WeightFailure? {
        do {
            try change()
        } catch {
            logger.error("Saving weight failed: \(error.localizedDescription)")
            let failure = WeightFailure(error)
            if failure == .saveFailed { self.failure = .saveFailed }
            return failure
        }
        refresh()
        return nil
    }

    private func refresh() {
        profile = MaternalProfile.load(from: defaults)
        do {
            entries = try store.entries()
        } catch {
            logger.error("Loading weights failed: \(error.localizedDescription)")
            failure = .loadFailed
        }
    }
}
```

- [ ] **Step 12: Chạy toàn bộ test**

Run: `scripts/test-core.sh`
Expected: PASS, `Test run with 389 tests` (355 + 34).

- [ ] **Step 13: Commit, push, xác minh CI**

Chưa có màn nào dùng: chỉ cần app biên dịch và một lớp UI test nhanh.
```bash
scripts/test-core.sh
git add Packages/KickCore
git commit -F - <<'MSG'
feat(core): weight records, IOM 2009 guidance and weight coordinator

WeightRecord/WeightRules (30-200 kg to one decimal, one entry a day,
no future days, deterministic duplicate merge), BMI groups with the
recommended gain by week, the pre-pregnancy profile in the App Group,
chart points and weekly sections, WeightCoordinator, and -seedWeights
sample data from the design.

CI-Only-Testing: NavigationUITests
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`.

---
### Task 3: KickData — lưu lượng kinh/tâm trạng/triệu chứng và `WeightEntry`

`CycleLog` thêm `flowRaw`, `moodsRaw`, `symptomsRaw` (optional, CloudKit `CD_flowRaw`, `CD_moodsRaw`, `CD_symptomsRaw`); `record`/`apply` giữ nguyên giá trị lạ như LH/dịch nhầy. Model mới `WeightEntry` (record type `CD_WeightEntry`) + `WeightStore` (seam `saveContext`, rollback, gộp trùng khi đọc) và schema có `WeightEntry.self`.

**Files:**
- Modify: `Packages/KickData/Sources/KickData/Models.swift` (`CycleLog`, thêm `WeightEntry`), `Packages/KickData/Sources/KickData/KickPersistence.swift`
- Create: `Packages/KickData/Sources/KickData/WeightStore.swift`, `Packages/KickData/Tests/KickDataTests/WeightStoreTests.swift`
- Modify: `Packages/KickData/Tests/KickDataTests/CycleStoreTests.swift`

**Interfaces:**
- Consumes: Task 1 (`MenstrualFlow`, `Mood`, `Symptom`, `RawList`, `CycleLogRecord` trường mới, `setSymptoms(_:for:)`), Task 2 (`WeightRecord`, `WeightRepository`, `WeightRules`, `WeightRepositoryError`).
- Produces:
  - `CycleLog.flowRaw: String?`, `CycleLog.moodsRaw: String?`, `CycleLog.symptomsRaw: String?`.
  - `@Model public final class WeightEntry { id: UUID = UUID(); day: Date = Date(); kg: Double = 0; init(record:); record: WeightRecord }`.
  - `@MainActor public final class WeightStore: WeightRepository`, `public convenience init(context: ModelContext, calendar: Calendar = .current)`.
  - `KickPersistence.schema` gồm `WeightEntry.self`.

- [ ] **Step 1: Viết test trước**

Trong `Packages/KickData/Tests/KickDataTests/CycleStoreTests.swift`, thay:
```swift
    // MARK: - Rollback
```
bằng:
```swift
    // MARK: - Flow, moods and symptoms (phase 5)

    @Test func flowMoodsAndSymptomsRoundTrip() throws {
        let log = CycleLogRecord(
            day: day("2026-10-01"), flow: .heavy, moods: [.tired, .happy], symptoms: [.nausea, .cramps]
        )
        try store.saveLog(log, today: today)
        #expect(try store.logs() == [CycleLogRecord(
            id: log.id, day: day("2026-10-01"), flow: .heavy, moods: [.happy, .tired], symptoms: [.cramps, .nausea]
        )])
        let model = try #require(try container.mainContext.fetch(FetchDescriptor<CycleLog>()).first)
        #expect(model.flowRaw == "heavy")
        #expect(model.moodsRaw == "happy,tired")
        #expect(model.symptomsRaw == "cramps,nausea")
    }

    @Test func aLogWithOnlyAMoodIsKeptAndClearingItDeletesTheDay() throws {
        try store.saveLog(CycleLogRecord(day: day("2026-10-01"), moods: [.calm]), today: today)
        #expect(try count(CycleLog.self) == 1)
        try store.saveLog(CycleLogRecord(day: day("2026-10-01")), today: today)
        #expect(try count(CycleLog.self) == 0)
    }

    @Test func unknownMoodsSymptomsAndFlowSurviveAnEdit() throws {
        // Values a newer app version may sync that this build does not know.
        let context = container.mainContext
        let model = CycleLog(record: CycleLogRecord(day: day("2026-10-01"), moods: [.calm]))
        model.flowRaw = "spotting"
        model.moodsRaw = "calm,excited"
        model.symptomsRaw = "hiccups,nausea"
        context.insert(model)
        try context.save()

        let loaded = try #require(try store.logs().first)
        #expect(loaded.flow == nil)
        #expect(loaded.moods == [.calm])
        #expect(loaded.unknownMoodsRaw == ["excited"])
        #expect(loaded.symptoms == [.nausea])
        #expect(loaded.unknownSymptomsRaw == ["hiccups"])

        // The sheet edits the record it loaded: unknown values ride along.
        var edited = loaded
        edited.moods = [.happy]
        edited.setSymptoms([.contractions], for: .pregnant)
        try store.saveLog(edited, today: today)
        #expect(model.flowRaw == "spotting")
        #expect(model.moodsRaw == "happy,excited")
        #expect(model.symptomsRaw == "contractions,hiccups")
    }

    @Test func sameDayLogsFromSyncUniteMoodsAndKeepTheHeavierFlow() throws {
        let context = container.mainContext
        context.insert(CycleLog(record: CycleLogRecord(day: day("2026-10-01"), flow: .light, moods: [.tired])))
        context.insert(CycleLog(record: CycleLogRecord(day: day("2026-10-01"), flow: .heavy, moods: [.happy], symptoms: [.cramps])))
        try context.save()

        let logs = try store.logs()
        #expect(logs.count == 1)
        #expect(logs.first?.flow == .heavy)
        #expect(logs.first?.moods == [.happy, .tired])
        #expect(logs.first?.symptoms == [.cramps])
        #expect(try count(CycleLog.self) == 1)
    }

    // MARK: - Rollback
```

`Packages/KickData/Tests/KickDataTests/WeightStoreTests.swift` (toàn bộ file):
```swift
import Foundation
import KickCore
import SwiftData
import Testing
@testable import KickData

@MainActor
struct WeightStoreTests {
    struct SaveFailed: Error {}

    let today = date("2026-10-02T12:00:00Z")
    let container: ModelContainer
    let store: WeightStore

    init() throws {
        container = try KickPersistence.makeContainer(inMemory: true)
        store = WeightStore(context: container.mainContext, calendar: utcCalendar)
    }

    private func failingStore() -> WeightStore {
        WeightStore(context: container.mainContext, calendar: utcCalendar, saveContext: { _ in throw SaveFailed() })
    }

    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00Z") }

    private func count() throws -> Int {
        try container.mainContext.fetchCount(FetchDescriptor<WeightEntry>())
    }

    @Test func schemaIncludesWeightEntry() {
        #expect(KickPersistence.schema.entities.map(\.name).contains("WeightEntry"))
    }

    @Test func savedEntryRoundTripsAtTheStartOfTheDayRounded() throws {
        let entry = WeightRecord(day: date("2026-10-01T18:00:00Z"), kg: 58.04)
        try store.save(entry, today: today)
        #expect(try store.entries() == [WeightRecord(id: entry.id, day: day("2026-10-01"), kg: 58.0)])
    }

    @Test func entriesAreOldestFirst() throws {
        try store.save(WeightRecord(day: day("2026-10-01"), kg: 58), today: today)
        try store.save(WeightRecord(day: day("2026-09-01"), kg: 56), today: today)
        #expect(try store.entries().map(\.kg) == [56, 58])
    }

    @Test func savingTheSameDayAgainUpdatesTheEntryAndKeepsItsID() throws {
        let first = WeightRecord(day: day("2026-10-01"), kg: 58)
        try store.save(first, today: today)
        try store.save(WeightRecord(day: date("2026-10-01T20:00:00Z"), kg: 58.4), today: today)
        #expect(try store.entries() == [WeightRecord(id: first.id, day: day("2026-10-01"), kg: 58.4)])
        #expect(try count() == 1)
    }

    @Test func futureDaysAndImplausibleWeightsAreRefused() throws {
        #expect(throws: WeightRepositoryError.futureDate) {
            try store.save(WeightRecord(day: day("2026-10-03"), kg: 58), today: today)
        }
        #expect(throws: WeightRepositoryError.outOfRange) {
            try store.save(WeightRecord(day: day("2026-10-01"), kg: 250), today: today)
        }
        #expect(try count() == 0)
    }

    @Test func deleteRemovesAndUnknownIDIsANoOp() throws {
        let entry = WeightRecord(day: day("2026-10-01"), kg: 58)
        try store.save(entry, today: today)
        try store.delete(id: UUID())
        #expect(try count() == 1)
        try store.delete(id: entry.id)
        #expect(try store.entries().isEmpty)
    }

    @Test func sameDayEntriesFromSyncKeepTheFirstIDWithItsOwnWeight() throws {
        let context = container.mainContext
        let keptID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        context.insert(WeightEntry(record: WeightRecord(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, day: day("2026-10-01"), kg: 58.4)))
        context.insert(WeightEntry(record: WeightRecord(id: keptID, day: day("2026-10-01"), kg: 58.0)))
        try context.save()
        #expect(try store.entries() == [WeightRecord(id: keptID, day: day("2026-10-01"), kg: 58.0)])
        #expect(try count() == 1)
    }

    @Test func failedSaveRollsBack() throws {
        let entry = WeightRecord(day: day("2026-10-01"), kg: 58)
        try store.save(entry, today: today)
        #expect(throws: SaveFailed.self) {
            try failingStore().save(WeightRecord(day: day("2026-10-01"), kg: 60), today: today)
        }
        #expect(throws: SaveFailed.self) {
            try failingStore().save(WeightRecord(day: day("2026-09-30"), kg: 57), today: today)
        }
        #expect(try store.entries() == [entry])
    }

    @Test func failedDeleteRollsBack() throws {
        let entry = WeightRecord(day: day("2026-10-01"), kg: 58)
        try store.save(entry, today: today)
        #expect(throws: SaveFailed.self) {
            try failingStore().delete(id: entry.id)
        }
        #expect(try store.entries() == [entry])
    }

    @Test func failedMergeSaveThrowsAndKeepsTheDuplicates() throws {
        let context = container.mainContext
        context.insert(WeightEntry(record: WeightRecord(day: day("2026-10-01"), kg: 58)))
        context.insert(WeightEntry(record: WeightRecord(day: day("2026-10-01"), kg: 59)))
        try context.save()
        #expect(throws: SaveFailed.self) {
            try failingStore().entries()
        }
        #expect(try count() == 2)
    }
}
```

- [ ] **Step 2: (Không chạy local)** `KickData` cần Xcode (macro SwiftData) — bước "thấy fail" là lỗi biên dịch dự kiến (`value of type 'CycleLog' has no member 'flowRaw'`, `cannot find 'WeightStore' in scope`); không push riêng bước này, CI ở Step 5 là bằng chứng.

- [ ] **Step 3: Viết code**

Trong `Packages/KickData/Sources/KickData/Models.swift`, thay:
```swift
    public var note: String = ""

    public init(record: CycleLogRecord) {
        id = record.id
        day = record.day
        lhRaw = record.lh?.rawValue
        bbtCelsius = record.bbtCelsius
        mucusRaw = record.mucus?.rawValue
        note = record.note
    }

    public var record: CycleLogRecord {
        CycleLogRecord(
            id: id,
            day: day,
            lh: lhRaw.flatMap(LHResult.init(rawValue:)),
            bbtCelsius: bbtCelsius,
            mucus: mucusRaw.flatMap(CervicalMucus.init(rawValue:)),
            note: note
        )
    }

    /// Raw values this build cannot decode (e.g. synced from a newer app version)
    /// are kept unless the record actually changes that field.
    func apply(_ record: CycleLogRecord) {
        day = record.day
        if lhRaw.flatMap(LHResult.init(rawValue:)) != record.lh {
            lhRaw = record.lh?.rawValue
        }
        bbtCelsius = record.bbtCelsius
        if mucusRaw.flatMap(CervicalMucus.init(rawValue:)) != record.mucus {
            mucusRaw = record.mucus?.rawValue
        }
        note = record.note
    }
}
```
bằng:
```swift
    public var note: String = ""
    /// `MenstrualFlow.rawValue`: "none" | "light" | "medium" | "heavy".
    public var flowRaw: String?
    /// Comma-separated `Mood` raw values (`RawList`), e.g. "happy,tired".
    public var moodsRaw: String?
    /// Comma-separated `Symptom` raw values of both modes.
    public var symptomsRaw: String?

    public init(record: CycleLogRecord) {
        id = record.id
        day = record.day
        lhRaw = record.lh?.rawValue
        bbtCelsius = record.bbtCelsius
        mucusRaw = record.mucus?.rawValue
        note = record.note
        flowRaw = record.flow?.rawValue
        moodsRaw = RawList.encode(record.moods, unknown: record.unknownMoodsRaw)
        symptomsRaw = RawList.encode(record.symptoms, unknown: record.unknownSymptomsRaw)
    }

    public var record: CycleLogRecord {
        let moods: (known: [Mood], unknown: [String]) = RawList.decode(moodsRaw)
        let symptoms: (known: [Symptom], unknown: [String]) = RawList.decode(symptomsRaw)
        return CycleLogRecord(
            id: id,
            day: day,
            lh: lhRaw.flatMap(LHResult.init(rawValue:)),
            bbtCelsius: bbtCelsius,
            mucus: mucusRaw.flatMap(CervicalMucus.init(rawValue:)),
            note: note,
            flow: flowRaw.flatMap(MenstrualFlow.init(rawValue:)),
            moods: moods.known,
            symptoms: symptoms.known,
            unknownMoodsRaw: moods.unknown,
            unknownSymptomsRaw: symptoms.unknown
        )
    }

    /// Raw values this build cannot decode (e.g. synced from a newer app version)
    /// are kept unless the record actually changes that field; unknown moods and
    /// symptoms travel in the record and are written back with it.
    func apply(_ record: CycleLogRecord) {
        day = record.day
        if lhRaw.flatMap(LHResult.init(rawValue:)) != record.lh {
            lhRaw = record.lh?.rawValue
        }
        bbtCelsius = record.bbtCelsius
        if mucusRaw.flatMap(CervicalMucus.init(rawValue:)) != record.mucus {
            mucusRaw = record.mucus?.rawValue
        }
        note = record.note
        if flowRaw.flatMap(MenstrualFlow.init(rawValue:)) != record.flow {
            flowRaw = record.flow?.rawValue
        }
        let moods = RawList.encode(record.moods, unknown: record.unknownMoodsRaw)
        if moodsRaw != moods {
            moodsRaw = moods
        }
        let symptoms = RawList.encode(record.symptoms, unknown: record.unknownSymptomsRaw)
        if symptomsRaw != symptoms {
            symptomsRaw = symptoms
        }
    }
}

/// The mother's weight on one day. At most one per day (kept so by `WeightStore`).
@Model
public final class WeightEntry {
    public var id: UUID = UUID()
    /// Start of the day.
    public var day: Date = Date()
    /// 30.0–200.0 kg, one decimal.
    public var kg: Double = 0

    public init(record: WeightRecord) {
        id = record.id
        day = record.day
        kg = record.kg
    }

    public var record: WeightRecord {
        WeightRecord(id: id, day: day, kg: kg)
    }

    func apply(_ record: WeightRecord) {
        day = record.day
        kg = record.kg
    }
}
```

`Packages/KickData/Sources/KickData/WeightStore.swift` (toàn bộ file):
```swift
import Foundation
import KickCore
import SwiftData

/// SwiftData-backed WeightRepository. Validates every write with `WeightRules`
/// and merges iCloud duplicates (several entries on one day) on read.
@MainActor
public final class WeightStore: WeightRepository {
    private let context: ModelContext
    private let calendar: Calendar
    private let saveContext: @MainActor (ModelContext) throws -> Void

    public convenience init(context: ModelContext, calendar: Calendar = .current) {
        self.init(context: context, calendar: calendar, saveContext: { try $0.save() })
    }

    /// `saveContext` is a seam for tests: SwiftData offers no reliable way to
    /// make a real save fail (see commit 59dd6a1).
    init(context: ModelContext, calendar: Calendar, saveContext: @escaping @MainActor (ModelContext) throws -> Void) {
        self.context = context
        self.calendar = calendar
        self.saveContext = saveContext
    }

    public func entries() throws -> [WeightRecord] {
        let models = try context.fetch(FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.day)]))
        let merged = WeightRules.mergingDuplicates(models.map(\.record), calendar: calendar)
        guard merged.entries.count != models.count else { return merged.entries }
        var keep = Dictionary(merged.entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for model in models {
            if let record = keep.removeValue(forKey: model.id) {
                // Only touch rows the merge changed (CloudKit would re-upload them).
                if model.record != record {
                    model.apply(record)
                }
            } else {
                context.delete(model)
            }
        }
        try save()
        return merged.entries
    }

    public func save(_ entry: WeightRecord, today: Date) throws {
        try WeightRules.validate(entry, today: today, calendar: calendar)
        let normalized = WeightRules.normalized(entry, calendar: calendar)
        let sameDay = try context.fetch(FetchDescriptor<WeightEntry>())
            .filter { calendar.startOfDay(for: $0.day) == normalized.day }
            .sorted { $0.id.uuidString < $1.id.uuidString }
        if let kept = sameDay.first {
            kept.apply(normalized)
            for duplicate in sameDay.dropFirst() {
                context.delete(duplicate)
            }
        } else {
            context.insert(WeightEntry(record: normalized))
        }
        try save()
    }

    public func delete(id: UUID) throws {
        let models = try context.fetch(FetchDescriptor<WeightEntry>(predicate: #Predicate { $0.id == id }))
        guard !models.isEmpty else { return }
        for model in models {
            context.delete(model)
        }
        try save()
    }

    /// Saves, rolling back on failure so a failed write leaves no half-applied change.
    private func save() throws {
        do {
            try saveContext(context)
        } catch {
            context.rollback()
            throw error
        }
    }
}
```

Trong `Packages/KickData/Sources/KickData/KickPersistence.swift`, thay:
```swift
    public static let schema = Schema([KickSession.self, Kick.self, Appointment.self, PeriodEntry.self, CycleLog.self])
```
bằng:
```swift
    public static let schema = Schema([
        KickSession.self, Kick.self, Appointment.self, PeriodEntry.self, CycleLog.self, WeightEntry.self,
    ])
```

- [ ] **Step 4: Chạy test local được**

Run: `scripts/test-core.sh`
Expected: PASS, 389 test (KickCore không đổi).

- [ ] **Step 5: Commit, push, xác minh CI**

```bash
scripts/test-core.sh
git add Packages/KickData
git commit -F - <<'MSG'
feat(data): store flow, moods and symptoms, and the mother's weights

CycleLog gains flowRaw, moodsRaw and symptomsRaw (unknown values are
written back unchanged). WeightEntry and WeightStore keep one weight a
day, merge iCloud duplicates on read and roll back failed saves.

CI-Only-Testing: CycleUITests, CycleTodayUITests
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`; log `KickData` có `Test run with 55 tests` (41 + 4 ở `CycleStoreTests` + 10 ở `WeightStoreTests`).

---
### Task 4: Mong con — lượng kinh, tâm trạng, triệu chứng trong sheet ghi ngày + tóm tắt trên Hôm nay và Lịch

Sheet ghi ngày (`CycleDayLogSheet`, giữ mọi id cũ) theo spec §3.1: Kỳ kinh (như cũ) · **Lượng kinh** (chip chọn 1, chạm lại để bỏ) · **Tâm trạng** (nhiều) · **Triệu chứng** (nhiều, danh sách Mong con) · tiêu đề "Dấu hiệu rụng trứng" rồi LH, BBT, dịch nhầy (như cũ) · Ghi chú · Lưu. Mọi nhóm chip (cả dịch nhầy) dùng `FlowLayout` để xuống dòng ở AX5; chip `cycleStrong` khi chọn / `surface` khi chưa, trait `.isSelected`. Lưu bắt đầu từ log đã có nên triệu chứng Mang thai và giá trị lạ được giữ. Thẻ "Hôm nay bạn thấy thế nào?" và thẻ ngày chọn ở Lịch hiện tóm tắt một dòng theo thứ tự lượng kinh · tâm trạng · triệu chứng · nhiệt độ · LH · dịch nhầy · ghi chú, cắt bằng "…" (VoiceOver đọc đủ).

**Files:**
- Create: `Packages/KickCore/Sources/KickCore/CycleLogSummary.swift`, `Packages/KickCore/Tests/KickCoreTests/CycleLogSummaryTests.swift`
- Modify: `Packages/KickCore/Sources/KickCore/LunaPalette.swift`, `Packages/KickCore/Tests/KickCoreTests/ContrastTests.swift`
- Create: `App/Symptoms/SymptomChips.swift`, `UITests/CycleSymptomsUITests.swift`
- Modify: `App/Cycle/{CycleDayLogSheet,CycleCards,CycleTodayView,CycleCalendarView}.swift`, `Shared/L10n.swift`, `Shared/Localizable.xcstrings` (script), `UITests/{CycleUITests,SheetsUITests,CycleScreenshotTests}.swift`

**Interfaces:**
- Consumes: Task 1 (`MenstrualFlow`, `Mood`, `Symptom.cases(for:)`, `RawList.ordered`, `CycleLogRecord.flow/moods/symptoms(for:)/setSymptoms(_:for:)`), Task 3 (lưu bền các trường mới); `LunaSheet`, `LunaSheetSectionTitle`, `.luna(_:)`, `Font.luna`, `CycleTexts`, `L10n.cycleLogLH`, `L10n.dayLogLHPositive/Negative`, `L10n.mucus(_:)`, `L10n.dayLogNote`, `Formatting.temperature`.
- Produces:
  - KickCore: `public enum CycleLogSummaryItem: Equatable { flow(MenstrualFlow), mood(Mood), symptom(Symptom), temperature(Double), lh(LHResult), mucus(CervicalMucus), note }`, `CycleLogRecord.summaryItems(mode: AppMode) -> [CycleLogSummaryItem]`, `LunaContrast.declares(_ text: LunaToken, on: LunaToken) -> Bool`.
  - App: `struct FlowLayout: Layout` (`spacing: CGFloat = 8`), `struct SelectableChip(title:isSelected:selectedFill: = .cycleStrong, action:)`, `struct FlowChips(selection: Binding<MenstrualFlow?>)`, `struct MoodChips(selection: Binding<Set<Mood>>, selectedFill: = .cycleStrong)`, `struct SymptomChips(mode:selection: Binding<Set<Symptom>>, selectedFill: = .cycleStrong)`; `CycleTexts.logSummary(_ log: CycleLogRecord?, mode: AppMode = .tryingToConceive) -> String?`.
  - L10n: `symptomFlowTitle`, `symptomMoodTitle`, `symptomTitle`, `dayLogSignals`, `symptomSummaryFlow(_:)`, `flow(_:)`, `mood(_:)`, `symptom(_:)`; giá trị mới của `cycle.log.prompt`.
  - Accessibility id mới: `dayLogFlowPicker`, `dayLogMoodPicker`, `dayLogSymptomPicker` (khung chứa), `flowChip-<raw>` (`flowChip-none`, `-light`, `-medium`, `-heavy`), `moodChip-<raw>`, `symptomChip-<raw>`. Giữ: `dayLogLHPicker`, `dayLogBBTField`, `dayLogBBTError`, `dayLogMucusPicker`, `dayLogNoteField`, `dayLogSave`, `dayLogCancel`, `dayLogPeriodInfo`, `dayLogStartPeriod`, `dayLogEndPeriod`, `dayLogDeletePeriod`, `cycleLogTodayButton`, `calendarSelectedDay`, `calendarLogButton`.

- [ ] **Step 1: Viết test trước (KickCore)**

`Packages/KickCore/Tests/KickCoreTests/CycleLogSummaryTests.swift` (toàn bộ file):
```swift
import Foundation
import Testing
@testable import KickCore

struct CycleLogSummaryTests {
    let day = date("2026-10-02T00:00:00Z")

    @Test func flowMoodsSymptomsThenTheSignalsInOrder() {
        let log = CycleLogRecord(
            day: day, lh: .positive, bbtCelsius: 36.4, mucus: .eggWhite, note: "x",
            flow: .light, moods: [.happy, .tired], symptoms: [.cramps, .nausea]
        )
        #expect(log.summaryItems(mode: .tryingToConceive) == [
            .flow(.light), .mood(.happy), .mood(.tired), .symptom(.cramps),
            .temperature(36.4), .lh(.positive), .mucus(.eggWhite), .note,
        ])
        #expect(log.summaryItems(mode: .pregnant).contains(.symptom(.nausea)))
        #expect(!log.summaryItems(mode: .pregnant).contains(.symptom(.cramps)))
    }

    @Test func unknownValuesAndBlankNotesAreLeftOut() {
        let log = CycleLogRecord(day: day, note: "  ", unknownMoodsRaw: ["excited"])
        #expect(log.summaryItems(mode: .tryingToConceive).isEmpty)
    }
}
```

Trong `Packages/KickCore/Tests/KickCoreTests/ContrastTests.swift`, thay:
```swift
    @Test func everyTokenHasAValue() {
```
bằng:
```swift
    /// Text/fill pairs of the symptom chips, the safety card and the weight
    /// screens (phase 5) are declared, so `everyDeclaredPairMeetsAA` checks them.
    @Test func phase5PairsAreDeclared() {
        let pairs: [(LunaToken, LunaToken)] = [
            (.onAccent, .cycleStrong), (.onAccent, .pregStrong), (.textPrimary, .surface),
            (.warningText, .warningBackground), (.articleText, .warningBackground),
            (.tealStrong, .fertileSoft), (.pregOnSoft, .pregSoft), (.pregStrong, .card),
            (.textSecondary, .card), (.textPrimary, .card), (.onAccent, .pregOnSoft),
        ]
        for (text, background) in pairs {
            #expect(LunaContrast.declares(text, on: background), "\(text) on \(background)")
        }
        #expect(!LunaContrast.declares(.textMuted, on: .card))
    }

    @Test func everyTokenHasAValue() {
```

- [ ] **Step 2: Chạy để thấy fail**

Run: `scripts/test-core.sh --filter "CycleLogSummaryTests|ContrastTests"`
Expected: lỗi biên dịch `value of type 'CycleLogRecord' has no member 'summaryItems'`, `type 'LunaContrast' has no member 'declares'`.

- [ ] **Step 3: Viết code (KickCore)**

`Packages/KickCore/Sources/KickCore/CycleLogSummary.swift` (toàn bộ file):
```swift
import Foundation

/// One part of a day's one-line summary (Today's "How are you feeling today?"
/// card, the calendar's day card): the app turns each into words.
public enum CycleLogSummaryItem: Equatable, Sendable {
    case flow(MenstrualFlow)
    case mood(Mood)
    case symptom(Symptom)
    case temperature(Double)
    case lh(LHResult)
    case mucus(CervicalMucus)
    case note
}

extension CycleLogRecord {
    /// Flow · moods · that mode's symptoms · temperature · LH · mucus · note
    /// (spec §3.1). Values this build cannot read are left out.
    public func summaryItems(mode: AppMode) -> [CycleLogSummaryItem] {
        var items: [CycleLogSummaryItem] = []
        if let flow { items.append(.flow(flow)) }
        items += moods.map(CycleLogSummaryItem.mood)
        items += symptoms(for: mode).map(CycleLogSummaryItem.symptom)
        if let bbtCelsius { items.append(.temperature(bbtCelsius)) }
        if let lh { items.append(.lh(lh)) }
        if let mucus { items.append(.mucus(mucus)) }
        if !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { items.append(.note) }
        return items
    }
}
```

Trong `Packages/KickCore/Sources/KickCore/LunaPalette.swift`, thay:
```swift
    public static func ratio(_ first: LunaHex, _ second: LunaHex) -> Double {
```
bằng:
```swift
    /// Whether `usages` lists that text colour on that background.
    public static func declares(_ text: LunaToken, on background: LunaToken) -> Bool {
        usages.contains { $0.text == text && $0.background == background }
    }

    public static func ratio(_ first: LunaHex, _ second: LunaHex) -> Double {
```

- [ ] **Step 4: Chạy test**

Run: `scripts/test-core.sh`
Expected: PASS, `Test run with 392 tests` (389 + `CycleLogSummaryTests` 2 + `ContrastTests.phase5PairsAreDeclared` 1).

- [ ] **Step 5: Chuỗi**

```bash
# apply
scripts/add-strings.py --remove cycle.log.prompt
scripts/add-strings.py <<'JSON'
{
  "cycle.log.prompt": ["Log mood, symptoms and flow", "Ghi tâm trạng, triệu chứng, lượng kinh"],
  "dayLog.signals": ["Ovulation signs", "Dấu hiệu rụng trứng"],
  "symptom.title": ["Symptoms", "Triệu chứng"],
  "symptom.flow.title": ["Flow", "Lượng kinh"],
  "symptom.flow.none": ["None", "Không"],
  "symptom.flow.light": ["Light", "Ít"],
  "symptom.flow.medium": ["Medium", "Vừa"],
  "symptom.flow.heavy": ["Heavy", "Nhiều"],
  "symptom.mood.title": ["Mood", "Tâm trạng"],
  "symptom.mood.happy": ["Happy", "Vui vẻ"],
  "symptom.mood.calm": ["Calm", "Bình thường"],
  "symptom.mood.sensitive": ["Sensitive", "Nhạy cảm"],
  "symptom.mood.anxious": ["Anxious", "Lo âu"],
  "symptom.mood.tired": ["Tired", "Mệt mỏi"],
  "symptom.kind.cramps": ["Cramps", "Đau bụng"],
  "symptom.kind.headache": ["Headache", "Đau đầu"],
  "symptom.kind.tenderBreasts": ["Tender breasts", "Căng ngực"],
  "symptom.kind.acne": ["Acne", "Nổi mụn"],
  "symptom.kind.bloating": ["Bloating", "Đầy hơi"],
  "symptom.kind.cravings": ["Cravings", "Thèm ăn"],
  "symptom.kind.nausea": ["Nausea", "Buồn nôn"],
  "symptom.kind.heartburn": ["Heartburn", "Ợ nóng"],
  "symptom.kind.swollenFeet": ["Swollen feet", "Phù chân"],
  "symptom.kind.backPain": ["Back pain", "Đau lưng"],
  "symptom.kind.legCramps": ["Leg cramps", "Chuột rút"],
  "symptom.kind.insomnia": ["Insomnia", "Khó ngủ"],
  "symptom.kind.contractions": ["Contractions", "Cơn gò"],
  "symptom.summary.flow": ["Flow: %@", "Lượng kinh: %@"]
}
JSON
```
Expected: in ra `344 strings` rồi `372 strings`. Tên tâm trạng/triệu chứng/lượng kinh lấy nguyên từ `OPTS` của prototype.

Trong `Shared/L10n.swift`, thay:
```swift
    static var imPregnantConfirm: String { t("imPregnant.confirm") }
}
```
bằng:
```swift
    static var imPregnantConfirm: String { t("imPregnant.confirm") }

    // MARK: - Phase 5: symptoms

    static var symptomFlowTitle: String { t("symptom.flow.title") }
    static var symptomMoodTitle: String { t("symptom.mood.title") }
    static var symptomTitle: String { t("symptom.title") }
    static var dayLogSignals: String { t("dayLog.signals") }
    /// "Flow: Light" in a day's summary.
    static func symptomSummaryFlow(_ flow: String) -> String { String(format: t("symptom.summary.flow"), flow) }
    static func flow(_ value: MenstrualFlow) -> String {
        switch value {
        case .noFlow: t("symptom.flow.none")
        case .light: t("symptom.flow.light")
        case .medium: t("symptom.flow.medium")
        case .heavy: t("symptom.flow.heavy")
        }
    }
    static func mood(_ value: Mood) -> String {
        switch value {
        case .happy: t("symptom.mood.happy")
        case .calm: t("symptom.mood.calm")
        case .sensitive: t("symptom.mood.sensitive")
        case .anxious: t("symptom.mood.anxious")
        case .tired: t("symptom.mood.tired")
        }
    }
    static func symptom(_ value: Symptom) -> String {
        switch value {
        case .cramps: t("symptom.kind.cramps")
        case .headache: t("symptom.kind.headache")
        case .tenderBreasts: t("symptom.kind.tenderBreasts")
        case .acne: t("symptom.kind.acne")
        case .bloating: t("symptom.kind.bloating")
        case .cravings: t("symptom.kind.cravings")
        case .nausea: t("symptom.kind.nausea")
        case .heartburn: t("symptom.kind.heartburn")
        case .swollenFeet: t("symptom.kind.swollenFeet")
        case .backPain: t("symptom.kind.backPain")
        case .legCramps: t("symptom.kind.legCramps")
        case .insomnia: t("symptom.kind.insomnia")
        case .contractions: t("symptom.kind.contractions")
        }
    }
}
```

- [ ] **Step 6: Nhóm chip xuống dòng**

`App/Symptoms/SymptomChips.swift` (toàn bộ file):
```swift
import KickCore
import SwiftUI

/// Rows of chips that wrap where the next chip no longer fits (spec §5): at
/// the largest text sizes chips move to the next row instead of being cut.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    private struct Row {
        var items: [(index: Int, size: CGSize)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, maxWidth: proposal.width ?? .infinity)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, maxWidth: bounds.width) {
            var x = bounds.minX
            for item in row.items {
                subviews[item.index].place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func arrange(_ subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            // A chip wider than the row wraps its own text (proposed the row's width).
            let size = subviews[index].sizeThatFits(ProposedViewSize(width: maxWidth.isFinite ? maxWidth : nil, height: nil))
            if !current.items.isEmpty, current.width + spacing + size.width > maxWidth {
                rows.append(current)
                current = Row()
            }
            current.width += (current.items.isEmpty ? 0 : spacing) + size.width
            current.height = max(current.height, size.height)
            current.items.append((index, size))
        }
        if !current.items.isEmpty { rows.append(current) }
        return rows
    }
}

/// A chip of the day-log sheets (spec §3.1): the mode's strong accent with
/// `onAccent` text when chosen, `surface` with `textPrimary` otherwise.
/// VoiceOver hears the selected trait.
struct SelectableChip: View {
    let title: String
    let isSelected: Bool
    var selectedFill: LunaToken = .cycleStrong
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.luna(.body))
                .foregroundStyle(.luna(isSelected ? .onAccent : .textPrimary))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .frame(minHeight: 40)
                .background(Capsule().fill(isSelected ? Color.luna(selectedFill) : Color.luna(.surface)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Flow: pick one; tapping the chosen chip again clears it (spec §3.1).
struct FlowChips: View {
    @Binding var selection: MenstrualFlow?

    var body: some View {
        FlowLayout {
            ForEach(MenstrualFlow.allCases, id: \.self) { flow in
                SelectableChip(title: L10n.flow(flow), isSelected: selection == flow) {
                    selection = selection == flow ? nil : flow
                }
                .accessibilityIdentifier("flowChip-\(flow.rawValue)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dayLogFlowPicker")
    }
}

/// Moods: several.
struct MoodChips: View {
    @Binding var selection: Set<Mood>
    var selectedFill: LunaToken = .cycleStrong

    var body: some View {
        FlowLayout {
            ForEach(Mood.allCases, id: \.self) { mood in
                SelectableChip(title: L10n.mood(mood), isSelected: selection.contains(mood), selectedFill: selectedFill) {
                    selection.formSymmetricDifference([mood])
                }
                .accessibilityIdentifier("moodChip-\(mood.rawValue)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dayLogMoodPicker")
    }
}

/// The current mode's symptoms: several.
struct SymptomChips: View {
    let mode: AppMode
    @Binding var selection: Set<Symptom>
    var selectedFill: LunaToken = .cycleStrong

    var body: some View {
        FlowLayout {
            ForEach(Symptom.cases(for: mode), id: \.self) { symptom in
                SelectableChip(title: L10n.symptom(symptom), isSelected: selection.contains(symptom), selectedFill: selectedFill) {
                    selection.formSymmetricDifference([symptom])
                }
                .accessibilityIdentifier("symptomChip-\(symptom.rawValue)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dayLogSymptomPicker")
    }
}

private struct SymptomChipsPreview: View {
    @State private var flow: MenstrualFlow? = .light
    @State private var moods: Set<Mood> = [.calm]
    @State private var symptoms: Set<Symptom> = [.contractions]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FlowChips(selection: $flow)
            MoodChips(selection: $moods)
            SymptomChips(mode: .pregnant, selection: $symptoms, selectedFill: .pregStrong)
        }
        .padding(22)
        .background(.luna(.background))
    }
}

#Preview {
    SymptomChipsPreview()
}
```

- [ ] **Step 7: Sheet ghi ngày**

Trong `App/Cycle/CycleDayLogSheet.swift`, thay:
```swift
/// Log or edit one day (spec §4.9): start/end a period there, LH test, BBT,
/// mucus, note. Period buttons apply at once; the signals are saved with "Save",
/// which stays above the keyboard.
```
bằng:
```swift
/// Log or edit one day (phase 5 spec §3.1): start/end a period there, then
/// flow, mood and symptoms, the ovulation signs (LH test, BBT, mucus) and a
/// note. Period buttons apply at once; the rest is saved with "Save", which
/// stays above the keyboard. Pregnancy symptoms and values this build cannot
/// read are kept as they are.
```

Trong `App/Cycle/CycleDayLogSheet.swift`, thay:
```swift
    @State private var note: String
    @State private var temperatureInvalid = false
```
bằng:
```swift
    @State private var note: String
    @State private var flow: MenstrualFlow?
    @State private var moods: Set<Mood>
    @State private var symptoms: Set<Symptom>
    @State private var temperatureInvalid = false
```

Trong `App/Cycle/CycleDayLogSheet.swift`, thay:
```swift
        _note = State(initialValue: existing?.note ?? "")
    }
```
bằng:
```swift
        _note = State(initialValue: existing?.note ?? "")
        _flow = State(initialValue: existing?.flow)
        _moods = State(initialValue: Set(existing?.moods ?? []))
        _symptoms = State(initialValue: Set(existing?.symptoms(for: .tryingToConceive) ?? []))
    }
```

Trong `App/Cycle/CycleDayLogSheet.swift`, thay:
```swift
            LunaSheetSectionTitle(title: L10n.dayLogPeriodSection)
            periodSection

            LunaSheetSectionTitle(title: L10n.dayLogLH)
```
bằng:
```swift
            LunaSheetSectionTitle(title: L10n.dayLogPeriodSection)
            periodSection

            LunaSheetSectionTitle(title: L10n.symptomFlowTitle)
            FlowChips(selection: $flow)

            LunaSheetSectionTitle(title: L10n.symptomMoodTitle)
            MoodChips(selection: $moods)

            LunaSheetSectionTitle(title: L10n.symptomTitle)
            SymptomChips(mode: .tryingToConceive, selection: $symptoms)

            Text(L10n.dayLogSignals)
                .font(.luna(.cardTitleSmall))
                .foregroundStyle(.luna(.textPrimary))
                .padding(.top, 26)
                .accessibilityAddTraits(.isHeader)

            LunaSheetSectionTitle(title: L10n.dayLogLH)
```

Trong `App/Cycle/CycleDayLogSheet.swift`, thay:
```swift
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 8) {
                mucusChip(nil, title: L10n.dayLogMucusNone)
```
bằng:
```swift
            FlowLayout {
                mucusChip(nil, title: L10n.dayLogMucusNone)
```

Trong `App/Cycle/CycleDayLogSheet.swift`, thay:
```swift
    private func mucusChip(_ value: CervicalMucus?, title: String) -> some View {
        let isSelected = mucus == value
        return Button {
            mucus = value
        } label: {
            Text(title)
                .font(.luna(.body))
                .foregroundStyle(.luna(isSelected ? .onAccent : .textPrimary))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(Capsule().fill(isSelected ? Color.luna(.cycleStrong) : Color.luna(.card)))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
```
bằng:
```swift
    private func mucusChip(_ value: CervicalMucus?, title: String) -> some View {
        SelectableChip(title: title, isSelected: mucus == value) { mucus = value }
    }
```

Trong `App/Cycle/CycleDayLogSheet.swift`, thay:
```swift
        let log = CycleLogRecord(
            id: existing?.id ?? UUID(), day: day, lh: lh, bbtCelsius: temperature, mucus: mucus, note: note
        )
        saving = true
```
bằng:
```swift
        // Start from what is stored: pregnancy symptoms and unknown values stay.
        var log = existing ?? CycleLogRecord(day: day)
        log.day = day
        log.lh = lh
        log.bbtCelsius = temperature
        log.mucus = mucus
        log.note = note
        log.flow = flow
        log.moods = RawList.ordered(moods)
        log.setSymptoms(symptoms, for: .tryingToConceive)
        saving = true
```

- [ ] **Step 8: Tóm tắt một dòng trên Hôm nay và Lịch**

Trong `App/Cycle/CycleCards.swift`, thay:
```swift
    /// What is logged for a day, e.g. "LH Positive · 36.4°C · Egg white"; nil when nothing is.
    static func logSummary(_ log: CycleLogRecord?) -> String? {
        guard let log, !log.isEmpty else { return nil }
        var parts: [String] = []
        switch log.lh {
        case .positive?: parts.append(L10n.cycleLogLH(L10n.dayLogLHPositive))
        case .negative?: parts.append(L10n.cycleLogLH(L10n.dayLogLHNegative))
        case nil: break
        }
        if let bbt = log.bbtCelsius { parts.append(Formatting.temperature(bbt)) }
        if let mucus = log.mucus { parts.append(L10n.mucus(mucus)) }
        if !log.note.isEmpty { parts.append(L10n.dayLogNote) }
        return parts.joined(separator: " · ")
    }
```
bằng:
```swift
    /// What is logged for a day in the order of phase 5 spec §3.1, e.g.
    /// "Flow: Light · Calm · Cramps · 36.4 °C · LH Positive · Egg white"; only
    /// `mode`'s symptoms. nil when nothing readable is logged.
    static func logSummary(_ log: CycleLogRecord?, mode: AppMode = .tryingToConceive) -> String? {
        guard let log else { return nil }
        let parts = log.summaryItems(mode: mode).map(summaryText)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func summaryText(_ item: CycleLogSummaryItem) -> String {
        switch item {
        case .flow(let flow): L10n.symptomSummaryFlow(L10n.flow(flow))
        case .mood(let mood): L10n.mood(mood)
        case .symptom(let symptom): L10n.symptom(symptom)
        case .temperature(let celsius): Formatting.temperature(celsius)
        case .lh(.positive): L10n.cycleLogLH(L10n.dayLogLHPositive)
        case .lh(.negative): L10n.cycleLogLH(L10n.dayLogLHNegative)
        case .mucus(let mucus): L10n.mucus(mucus)
        case .note: L10n.dayLogNote
        }
    }
```

Trong `App/Cycle/CycleTodayView.swift`, thay:
```swift
                    Text(CycleTexts.logSummary(cycle.log(on: today)) ?? L10n.cycleLogPrompt)
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
```
bằng:
```swift
                    // One line, cut with "…"; VoiceOver still reads all of it (spec §3.1).
                    Text(CycleTexts.logSummary(cycle.log(on: today)) ?? L10n.cycleLogPrompt)
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.textSecondary))
                        .lineLimit(1)
                        .truncationMode(.tail)
```

Trong `App/Cycle/CycleCalendarView.swift`, thay:
```swift
                if let summary = CycleTexts.logSummary(cycle.log(on: selected)) {
                    Text(summary)
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.textSecondary))
                }
```
bằng:
```swift
                if let summary = CycleTexts.logSummary(cycle.log(on: selected)) {
                    // One line, cut with "…"; VoiceOver still reads all of it (spec §3.1).
                    Text(summary)
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.textSecondary))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
```

- [ ] **Step 9: UI test**

`UITests/CycleSymptomsUITests.swift` (toàn bộ file):
```swift
import XCTest

/// Phase 5 spec §3.1 and §6: flow, mood and symptoms in the trying-to-conceive day log.
final class CycleSymptomsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Mood and symptoms logged today show on Today's card and the calendar's day card.
    @MainActor
    func testFlowMoodAndSymptomsShowInBothSummaries() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "fertile")
        let logToday = app.buttons["cycleLogTodayButton"]
        XCTAssertTrue(logToday.waitForExistence(timeout: 10))
        app.scrollUntilHittable(logToday)
        logToday.tap()

        let light = app.buttons["flowChip-light"]
        XCTAssertTrue(light.waitForExistence(timeout: 5))
        XCTAssertEqual(light.label, "Light")
        XCTAssertFalse(light.isSelected)
        light.tap()
        XCTAssertTrue(light.isSelected)
        light.tap() // the chosen flow, tapped again, is cleared
        XCTAssertFalse(light.isSelected)
        app.buttons["flowChip-medium"].tap()
        XCTAssertTrue(app.buttons["flowChip-medium"].isSelected)

        let happy = app.buttons["moodChip-happy"]
        app.scrollUntilHittable(happy)
        happy.tap()
        XCTAssertTrue(happy.isSelected)
        let headache = app.buttons["symptomChip-headache"]
        app.scrollUntilHittable(headache)
        headache.tap()
        XCTAssertTrue(headache.isSelected)
        // Only the trying-to-conceive list: no pregnancy symptoms here.
        XCTAssertFalse(app.buttons["symptomChip-nausea"].exists)
        app.buttons["dayLogSave"].tap()
        let closed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: app.buttons["dayLogSave"]
        )
        XCTAssertEqual(XCTWaiter().wait(for: [closed], timeout: 5), .completed)

        // Flow · mood · symptom · temperature (the seed logged 36.3 °C and egg white today).
        waitForLabel(logToday, containing: "Flow: Medium · Happy · Headache · 36.3")
        XCTAssertTrue(logToday.label.contains("Egg white"), logToday.label) // cut on screen, read in full
        attachScreenshot(app, "cycle-home-summary-en")

        app.openCycleTab(.calendar)
        let selectedDay = app.descendants(matching: .any)["calendarSelectedDay"]
        XCTAssertTrue(selectedDay.waitForExistence(timeout: 5))
        app.scrollUntilHittable(selectedDay)
        XCTAssertTrue(selectedDay.label.contains("Flow: Medium · Happy · Headache"), selectedDay.label)
        attachScreenshot(app, "calendar-summary-en")
    }

    /// A logged mood and symptom are chosen again when the day is reopened.
    @MainActor
    func testSeededMoodAndSymptomAreSelectedWhenReopened() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "fertile")
        let yesterday = app.buttons.matching(
            NSPredicate(format: "identifier == 'stripDay' AND label BEGINSWITH 'October 1,'")
        ).firstMatch
        XCTAssertTrue(yesterday.waitForExistence(timeout: 10))
        yesterday.tap()
        let calm = app.buttons["moodChip-calm"]
        XCTAssertTrue(calm.waitForExistence(timeout: 5))
        XCTAssertTrue(calm.isSelected)
        XCTAssertFalse(app.buttons["moodChip-happy"].isSelected)
        XCTAssertTrue(app.buttons["symptomChip-bloating"].isSelected)
        XCTAssertFalse(app.buttons["flowChip-none"].isSelected)
    }

    /// Clearing every chip of a day that only had flow removes the day's log.
    @MainActor
    func testClearingTheOnlyFlowRemovesTheLog() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "period")
        let logToday = app.buttons["cycleLogTodayButton"]
        XCTAssertTrue(logToday.waitForExistence(timeout: 10))
        XCTAssertTrue(logToday.label.contains("Flow: Medium"), logToday.label)
        app.scrollUntilHittable(logToday)
        logToday.tap()
        let medium = app.buttons["flowChip-medium"]
        XCTAssertTrue(medium.waitForExistence(timeout: 5))
        XCTAssertTrue(medium.isSelected)
        medium.tap()
        app.buttons["dayLogSave"].tap()
        waitForLabel(logToday, containing: "Log mood, symptoms and flow")
    }

    /// Spec §5: chips wrap at the largest text size instead of being cut.
    @MainActor
    func testDayLogChipsWrapAtTheLargestTextSize() {
        let app = XCUIApplication.launchPinned(language: "vi", seedCycles: "fertile", largestText: true)
        let logToday = app.buttons["cycleLogTodayButton"]
        XCTAssertTrue(logToday.waitForExistence(timeout: 10))
        app.scrollUntilHittable(logToday, maxSwipes: 12)
        logToday.tap()
        let tender = app.buttons["symptomChip-tenderBreasts"]
        XCTAssertTrue(tender.waitForExistence(timeout: 5))
        app.scrollUntilHittable(tender, maxSwipes: 12)
        XCTAssertLessThanOrEqual(tender.frame.maxX, app.windows.firstMatch.frame.maxX)
        attachScreenshot(app, "day-log-symptoms-vi-ax5")
    }
}
```

LH và BBT giờ nằm dưới ba nhóm chip: test cũ cuộn tới trước khi chạm.

Trong `UITests/CycleUITests.swift`, thay **cả 2 chỗ**:
```swift
        let positive = app.segmentedControls.buttons["Positive"]
        XCTAssertTrue(positive.waitForExistence(timeout: 5))
        positive.tap()
```
bằng:
```swift
        let positive = app.segmentedControls.buttons["Positive"]
        XCTAssertTrue(positive.waitForExistence(timeout: 5))
        app.scrollUntilHittable(positive) // below flow, mood and symptoms (phase 5)
        positive.tap()
```

Trong `UITests/CycleUITests.swift`, thay:
```swift
        let field = app.textFields["dayLogBBTField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
```
bằng:
```swift
        let field = app.textFields["dayLogBBTField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        app.scrollUntilHittable(field)
        field.tap()
```

Trong `UITests/SheetsUITests.swift`, thay:
```swift
        let field = app.textFields["dayLogBBTField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
```
bằng:
```swift
        let field = app.textFields["dayLogBBTField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        app.scrollUntilHittable(field) // below flow, mood and symptoms (phase 5)
        field.tap()
```

Trong `UITests/CycleScreenshotTests.swift`, thay:
```swift
            XCTAssertTrue(app.buttons["dayLogSave"].waitForExistence(timeout: 5))
            attachScreenshot(app, "day-log-\(suffix)")
            if language == "vi", !dark {
                let field = app.textFields["dayLogBBTField"]
                field.tap()
```
bằng:
```swift
            XCTAssertTrue(app.buttons["dayLogSave"].waitForExistence(timeout: 5))
            attachScreenshot(app, "day-log-\(suffix)")
            let field = app.textFields["dayLogBBTField"]
            app.scrollUntilHittable(field)
            attachScreenshot(app, "day-log-signals-\(suffix)")
            if language == "vi", !dark {
                field.tap()
```

- [ ] **Step 10: Commit, push, xác minh CI**

```bash
scripts/test-core.sh
git add Packages/KickCore App Shared UITests
git commit -F - <<'MSG'
feat(cycle): log flow, mood and symptoms in the day log

The trying-to-conceive day log gets flow (pick one, tap again to clear),
mood and symptom chips that wrap at large text sizes, above the
ovulation signs. Today's "How are you feeling today?" card and the
calendar's day card show a one-line summary that VoiceOver reads in full.

CI-Only-Testing: CycleSymptomsUITests, CycleUITests, CycleTodayUITests, SheetsUITests, CycleScreenshotTests
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`, gồm `CycleSymptomsUITests` (4 test) và mọi test cũ của 4 lớp còn lại.

- [ ] **Step 11: Kiểm tra trực quan (so với prototype "Bottom sheet – Ghi triệu chứng")**

- `day-log-vi-light`: tiêu đề "Hôm nay, 2 tháng 10" 22/700; thẻ trắng "Kỳ kinh"; nhãn "Lượng kinh" 13/600 xám rồi 4 chip "Không · Ít · Vừa · Nhiều" bo tròn nền `#F4ECE5`, chữ `#2B201C`, cao ≥ 40 pt, khoảng cách 8; "Tâm trạng" 5 chip "Vui vẻ · Bình thường · Nhạy cảm · Lo âu · Mệt mỏi" xuống dòng tự nhiên; "Triệu chứng" 6 chip Mong con ("Đau bụng … Thèm ăn"), **không** có "Buồn nôn"/"Cơn gò"; nút "Lưu" đen ở đáy.
- `day-log-signals-vi-light`: tiêu đề "Dấu hiệu rụng trứng" 15/600 rồi "Que thử rụng trứng (LH)", ô BBT có "36,3", chip dịch nhầy "Như lòng trắng trứng" chọn (nền `#C2384F`, chữ trắng) — chip dịch nhầy giờ cùng kiểu bo tròn, xuống dòng.
- `day-log-*-dark`: chip chưa chọn nền `#2F2722`, chữ `#F4ECE5`; chip chọn `#F59AA8` chữ `#1A1412`; tiêu đề đọc rõ.
- `day-log-*-en-*`: "Flow · Mood · Symptoms", "None/Light/Medium/Heavy", "Happy/Calm/Sensitive/Anxious/Tired", "Cramps/Headache/Tender breasts/Acne/Bloating/Cravings", "Ovulation signs".
- `day-log-symptoms-vi-ax5`: chip "Căng ngực" xuống dòng/giãn, không chip nào bị cắt hay tràn mép phải.
- `cycle-home-summary-en`: thẻ "How are you feeling today?" một dòng "Flow: Medium · Happy · Headache · 36.3°C · …" cắt bằng "…" ở mép phải.
- `calendar-summary-en`: thẻ ngày chọn "Today" · "Day 13 · …" · dòng tóm tắt một dòng có "…", nút "Log" hồng.
- `cycle-home-fertile-*` (ảnh cũ): thẻ log hôm nay vẫn là "36,3 °C · Như lòng trắng trứng" (định dạng nhiệt độ như cũ), không đổi bố cục.
- `cycle-home-period-vi-light` (ảnh cũ, dữ liệu mẫu mới): thẻ log hôm nay "Lượng kinh: Vừa"; bản `-en-` "Flow: Medium".

---
### Task 5: Mang thai — màn "Triệu chứng", sheet ghi, thẻ nhắc an toàn, lối tắt

Màn `PregnancySymptomsView` (spec §3.2) mở từ lối tắt mới "Triệu chứng" trên Hôm nay (Mang thai): thẻ hôm nay (tóm tắt + "Ghi hôm nay"/"Sửa"), danh sách ngày đã ghi nhóm theo tuần thai (`SymptomTimeline`), chạm để sửa, vuốt để xóa (xác nhận). Sheet `PregnancySymptomSheet`: Tâm trạng · Triệu chứng (danh sách Mang thai) · Ghi chú · Lưu (`pregStrong`). Chọn "Cơn gò" hoặc "Phù chân" → `SymptomSafetyCard` ngay dưới nhóm chip (nền `warningBackground`, câu chữ cố định `symptom.safety.*`), nút "Xem dấu hiệu cần đi khám" lưu rồi mở Chi tiết tuần hiện tại cuộn tới mục cảnh báo. Dòng ngày có triệu chứng đó mang biểu tượng cảnh báo + nhãn VoiceOver. Không chẩn đoán, không đếm cơn gò. Hôm nay có 3 lối tắt (Đếm cử động · Triệu chứng · Tuần thai; Task 6 thêm Cân nặng), 2 hàng ở cỡ chữ trợ năng.

**Files:**
- Create: `Packages/KickCore/Sources/KickCore/SymptomTimeline.swift`, `Packages/KickCore/Tests/KickCoreTests/SymptomTimelineTests.swift`
- Create: `App/Symptoms/{SymptomSafetyCard,PregnancySymptomSheet,PregnancySymptomsView}.swift`, `UITests/PregnancySymptomsUITests.swift`
- Modify: `App/Pregnancy/{WeekDetailView,PregnancyTodayView}.swift`, `Shared/L10n.swift`, `Shared/Localizable.xcstrings` (script), `UITests/{UITestSupport,PregnancyTodayUITests}.swift`

**Interfaces:**
- Consumes: Task 1 (`Symptom.needsSafetyNote(_:)`, `CycleLogRecord.symptoms(for:)`, `setSymptoms(_:for:)`, `RawList.ordered`), Task 4 (`MoodChips`, `SymptomChips`, `SelectableChip`, `CycleTexts.logSummary(_:mode:)`, `L10n.symptomMoodTitle/symptomTitle/mood/symptom`); `CycleCoordinator.logs/log(on:)/saveLog(_:)/clearFailure()`, `CycleDaySelection`, `WeekSelection`, `WeeklyContentLibrary.clampedWeek`, `PregnancyTimeline`, `PregnancyDateSheet`, `L10n.pregnancyEmpty*`, `L10n.weekTitle(_:)`, `L10n.dayLogTitleToday(_:)`, `L10n.cycleFailure(_:)`.
- Produces:
  - KickCore: `public struct SymptomWeekSection: Identifiable { week: Int; logs: [CycleLogRecord] }`, `SymptomTimeline.sections(_:dueDate:now:calendar:) -> [SymptomWeekSection]`.
  - App: `WeekDetailView(currentWeek:scrollToWarnings: Bool = false)`; `SymptomSafetyCard(symptoms:onShowWarnings:)`; `PregnancySymptomSheet(day:existing:onShowWarnings:)`; `PregnancySymptomsView()`; `enum PregnancyRoute: Hashable { case symptoms }` (Task 6 thêm `.weight`) và `@State route` + `.navigationDestination(item:)` trong `PregnancyTodayView`; hàm `symbolIcon(_:)`, `shortcut(_:identifier:action:icon:)` (mỗi lối tắt `maxWidth: .infinity`).
  - L10n: `pregnancyShortcutSymptoms`, `symptomsListTitle`, `symptomsListEmpty`, `symptomsTodayEmpty`, `symptomsLogToday`, `symptomsEdit`, `symptomsDeleteConfirm`, `symptomsRowWarning`, `symptomSafetyTitle`, `symptomSafetyContractions`, `symptomSafetySwelling`, `symptomSafetyNote`, `symptomSafetyAction`.
  - UI test: `XCUIApplication.confirmDialog(_ label: String)`, `XCUIApplication.openPregnancySymptoms()`.
  - Accessibility id mới: `shortcutSymptoms`, `symptomsTodayCard`, `symptomsTodaySummary`, `symptomsLogToday`, `symptomsListEmpty`, `symptomDayRow`, `symptomsAddDates`, `symptomSafetyCard`, `symptomSafetyAction`, `symptomNoteField`, `symptomSave`, `symptomCancel` (chip dùng lại `moodChip-*`, `symptomChip-*`). Giữ: `shortcutKicks`, `shortcutWeek`, `weekWarnings`, `weekDetailTitle`, `weekDetailClose`.

- [ ] **Step 1: Viết test trước (KickCore)**

`Packages/KickCore/Tests/KickCoreTests/SymptomTimelineTests.swift` (toàn bộ file):
```swift
import Foundation
import Testing
@testable import KickCore

struct SymptomTimelineTests {
    /// 24w3d on 2026-10-02; first day of the last period 2026-04-14.
    let dueDate = date("2027-01-19T12:00:00Z")
    let now = date("2026-10-02T12:00:00Z")

    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00Z") }

    @Test func pregnancyLogsAreGroupedByWeekNewestFirst() {
        let today = CycleLogRecord(day: day("2026-10-02"), symptoms: [.contractions])
        let monday = CycleLogRecord(day: day("2026-09-29"), moods: [.tired])
        let week23 = CycleLogRecord(day: day("2026-09-27"), note: "Slept badly")
        let sections = SymptomTimeline.sections([monday, week23, today], dueDate: dueDate, now: now, calendar: utcCalendar)
        #expect(sections.map(\.week) == [24, 23])
        #expect(sections.first?.logs == [today, monday])
        #expect(sections.last?.logs == [week23])
    }

    @Test func cycleOnlyLogsAndDaysOutsideThePregnancyAreLeftOut() {
        let ovulation = CycleLogRecord(day: day("2026-09-30"), lh: .positive, symptoms: [.cramps])
        let beforeLMP = CycleLogRecord(day: day("2026-04-13"), moods: [.happy])
        let future = CycleLogRecord(day: day("2026-10-03"), moods: [.happy])
        #expect(SymptomTimeline.sections([ovulation, beforeLMP, future], dueDate: dueDate, now: now, calendar: utcCalendar).isEmpty)
    }
}
```

- [ ] **Step 2: Chạy để thấy fail**

Run: `scripts/test-core.sh --filter SymptomTimelineTests`
Expected: lỗi biên dịch `cannot find 'SymptomTimeline' in scope`.

- [ ] **Step 3: Viết code (KickCore)**

`Packages/KickCore/Sources/KickCore/SymptomTimeline.swift` (toàn bộ file):
```swift
import Foundation

/// One pregnancy week of the Symptoms screen's list.
public struct SymptomWeekSection: Equatable, Sendable, Identifiable {
    public let week: Int
    /// Newest first.
    public let logs: [CycleLogRecord]

    public var id: Int { week }
}

/// The Symptoms screen's list (spec §3.2): days logged in pregnancy mode,
/// grouped by gestational week.
public enum SymptomTimeline {
    /// Logs with a mood, a pregnancy symptom or a note, from the first day of
    /// the last period to today; newest week first, newest day first.
    public static func sections(
        _ logs: [CycleLogRecord],
        dueDate: Date,
        now: Date,
        calendar: Calendar = .current
    ) -> [SymptomWeekSection] {
        let today = calendar.startOfDay(for: now)
        var weeks: [Int] = []
        var grouped: [Int: [CycleLogRecord]] = [:]
        for log in logs.sorted(by: { $0.day > $1.day }) where log.day <= today && showsInPregnancy(log) {
            guard let week = PregnancyTimeline(dueDate: dueDate, now: log.day, calendar: calendar)?.week.weeks else { continue }
            if grouped[week] == nil { weeks.append(week) }
            grouped[week, default: []].append(log)
        }
        return weeks.sorted(by: >).map { SymptomWeekSection(week: $0, logs: grouped[$0] ?? []) }
    }

    static func showsInPregnancy(_ log: CycleLogRecord) -> Bool {
        !log.moods.isEmpty || !log.symptoms(for: .pregnant).isEmpty
            || !log.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
```

- [ ] **Step 4: Chạy test**

Run: `scripts/test-core.sh`
Expected: PASS, `Test run with 394 tests` (392 + 2).

- [ ] **Step 5: Chuỗi**

Câu chữ thẻ an toàn chờ bác sĩ duyệt (Task 7, mục 8 của `docs/content-review-for-doctor.md`).
```bash
# apply
scripts/add-strings.py <<'JSON'
{
  "pregnancy.shortcut.symptoms": ["Symptoms", "Triệu chứng"],
  "symptoms.list.title": ["Logged days", "Những ngày đã ghi"],
  "symptoms.list.empty": ["Days you log show here, by week of pregnancy.", "Những ngày bạn ghi sẽ hiện ở đây, theo tuần thai."],
  "symptoms.today.empty": ["Nothing logged yet today", "Hôm nay chưa ghi gì"],
  "symptoms.logToday": ["Log today", "Ghi hôm nay"],
  "symptoms.edit": ["Edit", "Sửa"],
  "symptoms.delete.confirm": ["Delete this day's mood, symptoms and note?", "Xóa tâm trạng, triệu chứng và ghi chú của ngày này?"],
  "symptoms.row.warning": ["A symptom to watch", "Có triệu chứng cần lưu ý"],
  "symptom.safety.title": ["When to get care right away", "Khi nào cần đi khám ngay"],
  "symptom.safety.contractions": ["Go now if contractions come regularly or hurt before week 37, or if fluid or blood leaks.", "Đi khám ngay nếu cơn gò đều đặn hoặc đau trước tuần 37, hoặc ra nước, ra máu."],
  "symptom.safety.swelling": ["Go now if your face or hands swell suddenly with a headache, blurred vision or pain under the ribs.", "Đi khám ngay nếu mặt hoặc tay phù đột ngột kèm đau đầu, nhìn mờ hoặc đau vùng thượng vị."],
  "symptom.safety.note": ["Luna Mom does not diagnose. If in doubt, call your doctor.", "Luna Mom không chẩn đoán. Khi không chắc, hãy gọi bác sĩ."],
  "symptom.safety.action": ["See warning signs", "Xem dấu hiệu cần đi khám"]
}
JSON
```
Expected: `385 strings`.

Trong `Shared/L10n.swift`, thay:
```swift
        case .contractions: t("symptom.kind.contractions")
        }
    }
}
```
bằng:
```swift
        case .contractions: t("symptom.kind.contractions")
        }
    }

    // MARK: - Phase 5: pregnancy symptoms

    static var pregnancyShortcutSymptoms: String { t("pregnancy.shortcut.symptoms") }
    static var symptomsListTitle: String { t("symptoms.list.title") }
    static var symptomsListEmpty: String { t("symptoms.list.empty") }
    static var symptomsTodayEmpty: String { t("symptoms.today.empty") }
    static var symptomsLogToday: String { t("symptoms.logToday") }
    static var symptomsEdit: String { t("symptoms.edit") }
    static var symptomsDeleteConfirm: String { t("symptoms.delete.confirm") }
    /// VoiceOver, on a day with contractions or swollen feet.
    static var symptomsRowWarning: String { t("symptoms.row.warning") }
    static var symptomSafetyTitle: String { t("symptom.safety.title") }
    static var symptomSafetyContractions: String { t("symptom.safety.contractions") }
    static var symptomSafetySwelling: String { t("symptom.safety.swelling") }
    static var symptomSafetyNote: String { t("symptom.safety.note") }
    static var symptomSafetyAction: String { t("symptom.safety.action") }
}
```

- [ ] **Step 6: Thẻ an toàn, sheet và màn Triệu chứng**

`App/Symptoms/SymptomSafetyCard.swift` (toàn bộ file):
```swift
import KickCore
import SwiftUI

/// "When to get care right away" (phase 5 spec §3.2), right under the symptom
/// chips once contractions or swollen feet are chosen. Fixed, reviewed wording;
/// no diagnosis and no contraction counting.
struct SymptomSafetyCard: View {
    let symptoms: Set<Symptom>
    let onShowWarnings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L10n.symptomSafetyTitle, systemImage: "exclamationmark.triangle.fill")
                .font(.luna(.cardTitleSmall))
                .foregroundStyle(.luna(.warningText))
                .accessibilityAddTraits(.isHeader)
            if symptoms.contains(.contractions) {
                Text(L10n.symptomSafetyContractions)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if symptoms.contains(.swollenFeet) {
                Text(L10n.symptomSafetySwelling)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(L10n.symptomSafetyNote)
                .font(.luna(.small))
            Button(L10n.symptomSafetyAction, action: onShowWarnings)
                .buttonStyle(.pill(.text(.warningText), fullWidth: false, height: 44))
                .accessibilityIdentifier("symptomSafetyAction")
        }
        .font(.luna(.body))
        .foregroundStyle(.luna(.articleText))
        .lunaCard(.warningBackground, border: .warningBorder, padding: 16)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("symptomSafetyCard")
    }
}

#Preview {
    SymptomSafetyCard(symptoms: [.contractions, .swollenFeet]) {}
        .padding(22)
        .background(.luna(.background))
}
```

`App/Symptoms/PregnancySymptomSheet.swift` (toàn bộ file):
```swift
import KickCore
import SwiftUI

/// Log or edit one pregnancy day (phase 5 spec §3.2): mood, pregnancy symptoms
/// and a note. Contractions or swollen feet show the safety card under the
/// chips. Flow, cycle symptoms, LH, BBT, mucus and unknown values stay as stored.
struct PregnancySymptomSheet: View {
    let day: Date
    private let existing: CycleLogRecord?
    /// After a save from the safety card: open the week detail at its warnings.
    private let onShowWarnings: () -> Void

    @Environment(CycleCoordinator.self) private var cycle
    @Environment(\.dismiss) private var dismiss
    @State private var moods: Set<Mood>
    @State private var symptoms: Set<Symptom>
    @State private var note: String
    @State private var failure: CycleFailure?
    @State private var saving = false

    init(day: Date, existing: CycleLogRecord?, onShowWarnings: @escaping () -> Void) {
        self.day = Calendar.current.startOfDay(for: day)
        self.existing = existing
        self.onShowWarnings = onShowWarnings
        _moods = State(initialValue: Set(existing?.moods ?? []))
        _symptoms = State(initialValue: Set(existing?.symptoms(for: .pregnant) ?? []))
        _note = State(initialValue: existing?.note ?? "")
    }

    private var title: String {
        Calendar.current.isDate(day, inSameDayAs: AppClock.now())
            ? L10n.dayLogTitleToday(Formatting.shortDay(day))
            : Formatting.weekdayDay(day)
    }

    private var showsSafetyCard: Bool { Symptom.needsSafetyNote(symptoms) }

    var body: some View {
        LunaSheet(title: title) {
            LunaSheetSectionTitle(title: L10n.symptomMoodTitle)
            MoodChips(selection: $moods, selectedFill: .pregStrong)

            LunaSheetSectionTitle(title: L10n.symptomTitle)
            SymptomChips(mode: .pregnant, selection: $symptoms, selectedFill: .pregStrong)

            // Read right after the chips, before the note (spec §5).
            if showsSafetyCard {
                SymptomSafetyCard(symptoms: symptoms) {
                    Task {
                        if await save() { onShowWarnings() }
                    }
                }
                .padding(.top, 14)
                .transition(.opacity)
            }

            LunaSheetSectionTitle(title: L10n.dayLogNote)
            TextField(L10n.dayLogNote, text: $note, axis: .vertical)
                .lineLimit(2...5)
                .font(.luna(.body))
                .padding(14)
                .background(.luna(.card), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityIdentifier("symptomNoteField")

            Button(L10n.commonCancel) { dismiss() }
                .buttonStyle(.pill(.text(.textSecondary), height: 44))
                .padding(.top, 12)
                .accessibilityIdentifier("symptomCancel")
        }
        // A fade (also with Reduce Motion); none in UI tests.
        .animation(LunaMotion.isEnabled ? LunaMotion.fade : nil, value: showsSafetyCard)
        .safeAreaInset(edge: .bottom) {
            Button(L10n.commonSave) { Task { await save() } }
                .buttonStyle(.pill(.filled(.pregStrong)))
                .disabled(saving)
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
                .background(.luna(.background))
                .accessibilityIdentifier("symptomSave")
        }
        .lunaSheetPresentation()
        .alert(failure.map(L10n.cycleFailure) ?? "", isPresented: Binding(
            get: { failure != nil },
            set: { if !$0 { failure = nil } }
        )) {
            Button(L10n.commonOK) {}
        }
    }

    /// Saves and closes; false (sheet stays open with an alert) when it failed.
    @discardableResult
    private func save() async -> Bool {
        // Start from what is stored: everything this sheet does not show stays.
        var log = existing ?? CycleLogRecord(day: day)
        log.day = day
        log.moods = RawList.ordered(moods)
        log.setSymptoms(symptoms, for: .pregnant)
        log.note = note
        saving = true
        defer { saving = false }
        if let result = await cycle.saveLog(log) {
            cycle.clearFailure()
            failure = result
            return false
        }
        dismiss()
        return true
    }
}
```

`App/Symptoms/PregnancySymptomsView.swift` (toàn bộ file):
```swift
import KickCore
import SwiftUI

/// Pregnancy mode "Symptoms" (phase 5 spec §3.2), opened from Today's
/// shortcut: today's card, then the logged days grouped by gestational week.
/// Tap a day to edit it, swipe to delete (with a confirmation).
struct PregnancySymptomsView: View {
    @Environment(CycleCoordinator.self) private var cycle
    @AppStorage(SettingsKey.dueDate, store: AppGroup.defaults) private var dueDate: Double = 0
    @State private var logDay: CycleDaySelection?
    @State private var pendingDelete: CycleLogRecord?
    /// Set by the sheet's safety card: once the sheet is gone, open the week detail.
    @State private var showWarningsNext = false
    @State private var warningsWeek: WeekSelection?
    @State private var showingDateSheet = false
    @State private var actionFailure: CycleFailure?

    private var now: Date { AppClock.now() }
    private var today: Date { Calendar.current.startOfDay(for: now) }
    private var due: Date? { dueDate > 0 ? Date(timeIntervalSince1970: dueDate) : nil }
    private var timeline: PregnancyTimeline? { due.flatMap { PregnancyTimeline(dueDate: $0, now: now) } }

    var body: some View {
        List {
            Group {
                Text(L10n.symptomTitle)
                    .font(.luna(.screenTitle))
                    .tracking(-0.56)
                    .foregroundStyle(.luna(.textPrimary))
                    .accessibilityAddTraits(.isHeader)
                if timeline != nil {
                    todayCard
                    Text(L10n.symptomsListTitle)
                        .font(.luna(.cardTitle))
                        .foregroundStyle(.luna(.textPrimary))
                        .padding(.top, 10)
                        .accessibilityAddTraits(.isHeader)
                } else {
                    datesCard
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))

            if let due, timeline != nil {
                let sections = SymptomTimeline.sections(cycle.logs, dueDate: due, now: now)
                if sections.isEmpty {
                    Text(L10n.symptomsListEmpty)
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.textSecondary))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 6, trailing: 20))
                        .accessibilityIdentifier("symptomsListEmpty")
                }
                ForEach(sections) { section in
                    Section {
                        ForEach(section.logs) { log in
                            row(log)
                                .listRowBackground(Color.luna(.card))
                                .swipeActions {
                                    Button(role: .destructive) {
                                        pendingDelete = log
                                    } label: {
                                        Label(L10n.commonDelete, systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        Text(L10n.weekTitle(section.week))
                            .font(.luna(.captionStrong))
                            .foregroundStyle(.luna(.textSecondary))
                            .textCase(nil)
                            .accessibilityAddTraits(.isHeader)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .lunaStatusBarBackdrop()
        .background(.luna(.background))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $logDay, onDismiss: openWarningsIfAsked) { selection in
            PregnancySymptomSheet(day: selection.date, existing: cycle.log(on: selection.date)) {
                showWarningsNext = true
            }
        }
        .fullScreenCover(item: $warningsWeek) { selection in
            WeekDetailView(currentWeek: selection.week, scrollToWarnings: true)
        }
        .sheet(isPresented: $showingDateSheet) { PregnancyDateSheet() }
        .confirmationDialog(
            L10n.symptomsDeleteConfirm,
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button(L10n.commonDelete, role: .destructive) { Task { await deletePending() } }
            Button(L10n.commonCancel, role: .cancel) { pendingDelete = nil }
        }
        .alert(failureMessage ?? "", isPresented: failureBinding) {
            Button(L10n.commonOK) {}
        }
    }

    // MARK: - Cards and rows

    private var todayCard: some View {
        let log = cycle.log(on: today)
        let summary = CycleTexts.logSummary(log, mode: .pregnant)
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.commonToday)
                    .lunaLabelStyle(.pregStrong)
                Text(summary ?? L10n.symptomsTodayEmpty)
                    .font(.luna(.cardTitle))
                    .foregroundStyle(.luna(.textPrimary))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("symptomsTodaySummary")
            Button(summary == nil ? L10n.symptomsLogToday : L10n.symptomsEdit) {
                logDay = CycleDaySelection(date: today)
            }
            .buttonStyle(.pill(.filled(.pregStrong), fullWidth: false, height: 44))
            .accessibilityIdentifier("symptomsLogToday")
        }
        .lunaCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("symptomsTodayCard")
    }

    private func row(_ log: CycleLogRecord) -> some View {
        let warns = Symptom.needsSafetyNote(log.symptoms(for: .pregnant))
        let summary = CycleTexts.logSummary(log, mode: .pregnant) ?? ""
        return Button {
            logDay = CycleDaySelection(date: log.day)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Formatting.weekdayDay(log.day))
                        .font(.luna(.bodyStrong))
                        .foregroundStyle(.luna(.textPrimary))
                    Text(summary)
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if warns {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.luna(.warningText))
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            [Formatting.weekdayDay(log.day), summary, warns ? L10n.symptomsRowWarning : nil]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("symptomDayRow")
    }

    private var datesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.pregnancyEmptyTitle)
                .font(.luna(.sheetTitle))
                .foregroundStyle(.luna(.textPrimary))
            Text(L10n.pregnancyEmptyBody)
                .font(.luna(.body))
                .foregroundStyle(.luna(.textSecondary))
            Button(L10n.pregnancyEmptyAction) { showingDateSheet = true }
                .buttonStyle(.pill(.filled(.pregStrong)))
                .accessibilityIdentifier("symptomsAddDates")
        }
        .lunaCard()
    }

    // MARK: - Actions

    private func openWarningsIfAsked() {
        guard showWarningsNext else { return }
        showWarningsNext = false
        if let timeline {
            warningsWeek = WeekSelection(week: WeeklyContentLibrary.clampedWeek(timeline.week.weeks))
        }
    }

    /// Clears what this screen shows (mood, pregnancy symptoms, note); a day
    /// with nothing else logged is removed.
    private func deletePending() async {
        guard var log = pendingDelete else { return }
        pendingDelete = nil
        log.moods = []
        log.setSymptoms([], for: .pregnant)
        log.note = ""
        if let failure = await cycle.saveLog(log) {
            cycle.clearFailure()
            actionFailure = failure
        }
    }

    private var failureMessage: String? {
        (actionFailure ?? cycle.failure).map(L10n.cycleFailure)
    }

    /// Only while no sheet is open: the sheet reports its own errors.
    private var failureBinding: Binding<Bool> {
        Binding(
            get: { failureMessage != nil && logDay == nil },
            set: { if !$0 { actionFailure = nil; cycle.clearFailure() } }
        )
    }
}
```

- [ ] **Step 7: Chi tiết tuần mở thẳng tới mục cảnh báo**

Trong `App/Pregnancy/WeekDetailView.swift`, thay:
```swift
/// Full-screen week detail, weeks 4…42 (spec §4.5): close button, fetus, a row
/// of week chips scrolled to the current week, and the week's panel. Swipe left
/// or right on the panel to change week.
```
bằng:
```swift
/// Full-screen week detail, weeks 4…42 (spec §4.5): close button, fetus, a row
/// of week chips scrolled to the current week, and the week's panel. Swipe left
/// or right on the panel to change week. From the symptoms safety card it opens
/// scrolled to "When to get care right away" (phase 5 spec §3.2).
```

Trong `App/Pregnancy/WeekDetailView.swift`, thay:
```swift
    @State private var selection: Int
    private let language = ContentLanguage.current

    init(currentWeek: Int) {
        _selection = State(initialValue: WeeklyContentLibrary.clampedWeek(currentWeek))
    }
```
bằng:
```swift
    @State private var selection: Int
    private let scrollToWarnings: Bool
    private let language = ContentLanguage.current
    private static let warningsAnchor = "weekWarnings"

    init(currentWeek: Int, scrollToWarnings: Bool = false) {
        _selection = State(initialValue: WeeklyContentLibrary.clampedWeek(currentWeek))
        self.scrollToWarnings = scrollToWarnings
    }
```

Trong `App/Pregnancy/WeekDetailView.swift`, thay (toàn bộ `body`, giờ bọc trong `ScrollViewReader`):
```swift
    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    topBar
                    Image("Fetus")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 170)
                        .frame(width: 220, height: 220)
                        .background(
                            RadialGradient(
                                colors: [Color.luna(.card).opacity(0.7), Color.luna(.card).opacity(0)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 110
                            )
                            .clipShape(Circle())
                        )
                        .padding(.top, 14)
                        .padding(.bottom, 10)
                        .accessibilityHidden(true)
                    ChipScroller(
                        values: Array(WeeklyContentLibrary.weekRange),
                        selection: $selection,
                        title: { L10n.weekChip($0) },
                        identifier: { "weekChip-\($0)" },
                        accessibilityTitle: { L10n.weekTitle($0) }
                    )
                    .padding(.bottom, 16)
                    panel(minHeight: proxy.size.height * 0.6)
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 30).onEnded { value in
                                guard abs(value.translation.width) > abs(value.translation.height) * 2 else { return }
                                changeWeek(by: value.translation.width < 0 ? 1 : -1)
                            }
                        )
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            // VoiceOver two-finger scrub closes the cover, like the ✕ button.
            .accessibilityAction(.escape) { dismiss() }
            .background {
                // linear-gradient(heroTop 0 %, heroMiddle 38 %, background 60 %), then the panel colour.
                VStack(spacing: 0) {
                    LinearGradient(
                        stops: [
                            .init(color: .luna(.heroTop), location: 0),
                            .init(color: .luna(.heroMiddle), location: 0.38 / 0.6),
                            .init(color: .luna(.background), location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: (proxy.size.height + proxy.safeAreaInsets.top) * 0.6)
                    Color.luna(.card)
                }
                .ignoresSafeArea()
            }
        }
    }
```
bằng:
```swift
    var body: some View {
        GeometryReader { proxy in
            ScrollViewReader { reader in
                ScrollView {
                    VStack(spacing: 0) {
                        topBar
                        Image("Fetus")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 170)
                            .frame(width: 220, height: 220)
                            .background(
                                RadialGradient(
                                    colors: [Color.luna(.card).opacity(0.7), Color.luna(.card).opacity(0)],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 110
                                )
                                .clipShape(Circle())
                            )
                            .padding(.top, 14)
                            .padding(.bottom, 10)
                            .accessibilityHidden(true)
                        ChipScroller(
                            values: Array(WeeklyContentLibrary.weekRange),
                            selection: $selection,
                            title: { L10n.weekChip($0) },
                            identifier: { "weekChip-\($0)" },
                            accessibilityTitle: { L10n.weekTitle($0) }
                        )
                        .padding(.bottom, 16)
                        panel(minHeight: proxy.size.height * 0.6)
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 30).onEnded { value in
                                    guard abs(value.translation.width) > abs(value.translation.height) * 2 else { return }
                                    changeWeek(by: value.translation.width < 0 ? 1 : -1)
                                }
                            )
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .task {
                    guard scrollToWarnings else { return }
                    // Once laid out; a jump rather than an animated scroll (Reduce Motion, UI tests).
                    try? await Task.sleep(for: .milliseconds(150))
                    reader.scrollTo(Self.warningsAnchor, anchor: .top)
                }
            }
            // VoiceOver two-finger scrub closes the cover, like the ✕ button.
            .accessibilityAction(.escape) { dismiss() }
            .background {
                // linear-gradient(heroTop 0 %, heroMiddle 38 %, background 60 %), then the panel colour.
                VStack(spacing: 0) {
                    LinearGradient(
                        stops: [
                            .init(color: .luna(.heroTop), location: 0),
                            .init(color: .luna(.heroMiddle), location: 0.38 / 0.6),
                            .init(color: .luna(.background), location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: (proxy.size.height + proxy.safeAreaInsets.top) * 0.6)
                    Color.luna(.card)
                }
                .ignoresSafeArea()
            }
        }
    }
```

Trong `App/Pregnancy/WeekDetailView.swift`, thay:
```swift
                WarningSection(items: content.warnings.items(language))
```
bằng:
```swift
                WarningSection(items: content.warnings.items(language))
                    .id(Self.warningsAnchor)
```

- [ ] **Step 8: Lối tắt "Triệu chứng" trên Hôm nay (Mang thai)**

Trong `App/Pregnancy/PregnancyTodayView.swift`, thay:
```swift
/// Pregnancy mode, Today tab (spec §4.4): header, 7-day strip, the fetus
/// (→ week detail), weeks and days with the trimester bar, shortcuts, today's
/// movements, the baby this week, tips and the next check-up.
struct PregnancyTodayView: View {
```
bằng:
```swift
/// Screens pushed from pregnancy Today (phase 5 spec §3.4).
enum PregnancyRoute: Hashable {
    case symptoms
}

/// Pregnancy mode, Today tab (spec §4.4): header, 7-day strip, the fetus
/// (→ week detail), weeks and days with the trimester bar, shortcuts, today's
/// movements, the baby this week, tips and the next check-up.
struct PregnancyTodayView: View {
```

Trong `App/Pregnancy/PregnancyTodayView.swift`, thay:
```swift
    @State private var showingDateSheet = false
    @State private var detailWeek: WeekSelection?
```
bằng:
```swift
    @State private var showingDateSheet = false
    @State private var detailWeek: WeekSelection?
    @State private var route: PregnancyRoute?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
```

Trong `App/Pregnancy/PregnancyTodayView.swift`, thay:
```swift
            .sheet(isPresented: $showingDateSheet) {
                PregnancyDateSheet()
            }
        }
    }
```
bằng:
```swift
            .sheet(isPresented: $showingDateSheet) {
                PregnancyDateSheet()
            }
            .navigationDestination(item: $route) { route in
                switch route {
                case .symptoms: PregnancySymptomsView()
                }
            }
        }
    }
```

Trong `App/Pregnancy/PregnancyTodayView.swift`, thay (hai hàm lối tắt):
```swift
    private func shortcuts(week: Int, contentWeek: Int) -> some View {
        HStack(alignment: .top, spacing: 28) {
            shortcut(L10n.pregnancyShortcutKicks, identifier: "shortcutKicks", action: onOpenKicks) {
                Circle()
                    .fill(.luna(.preg))
                    .overlay(
                        Circle()
                            .fill(.luna(.card))
                            .frame(width: 16, height: 16)
                            .padding(6)
                            .background(Circle().fill(Color.luna(.card).opacity(0.3)))
                    )
            }
            shortcut(L10n.pregnancyShortcutWeek, identifier: "shortcutWeek", action: { detailWeek = WeekSelection(week: contentWeek) }) {
                Circle()
                    .fill(.luna(.card))
                    .overlay(
                        Text(week, format: .number)
                            .font(.luna(size: 15, weight: .bold))
                            .foregroundStyle(.luna(.textPrimary))
                    )
            }
        }
        .padding(.top, 22)
    }

    private func shortcut<Icon: View>(
        _ title: String,
        identifier: String,
        action: @escaping () -> Void,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                icon().frame(width: 58, height: 58)
                Text(title)
                    .font(.luna(size: 12, weight: .medium, relativeTo: .caption))
                    .foregroundStyle(.luna(.textPrimary))
                    .multilineTextAlignment(.center)
            }
            // 96 pt in the design; wider at large text so words are not broken mid-word.
            .frame(minWidth: 96, maxWidth: 160)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
```
bằng:
```swift
    /// Round shortcuts (phase 5 spec §3.4); two per row at accessibility text
    /// sizes so no label is cut.
    private func shortcuts(week: Int, contentWeek: Int) -> some View {
        let kicks = shortcut(L10n.pregnancyShortcutKicks, identifier: "shortcutKicks", action: onOpenKicks) {
            Circle()
                .fill(.luna(.preg))
                .overlay(
                    Circle()
                        .fill(.luna(.card))
                        .frame(width: 16, height: 16)
                        .padding(6)
                        .background(Circle().fill(Color.luna(.card).opacity(0.3)))
                )
        }
        let symptoms = shortcut(L10n.pregnancyShortcutSymptoms, identifier: "shortcutSymptoms", action: { route = .symptoms }) {
            symbolIcon("plus")
        }
        let weekShortcut = shortcut(L10n.pregnancyShortcutWeek, identifier: "shortcutWeek", action: { detailWeek = WeekSelection(week: contentWeek) }) {
            Circle()
                .fill(.luna(.card))
                .overlay(
                    Text(week, format: .number)
                        .font(.luna(size: 15, weight: .bold))
                        .foregroundStyle(.luna(.textPrimary))
                )
        }
        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                Grid(horizontalSpacing: 8, verticalSpacing: 18) {
                    GridRow { kicks; symptoms }
                    GridRow { weekShortcut }
                }
            } else {
                HStack(alignment: .top, spacing: 8) { kicks; symptoms; weekShortcut }
            }
        }
        .padding(.top, 22)
    }

    /// A white 58 pt circle with a symbol, like the design's "+".
    private func symbolIcon(_ name: String) -> some View {
        Circle()
            .fill(.luna(.card))
            .overlay(
                Image(systemName: name)
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(.luna(.textPrimary))
            )
    }

    private func shortcut<Icon: View>(
        _ title: String,
        identifier: String,
        action: @escaping () -> Void,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                icon().frame(width: 58, height: 58)
                Text(title)
                    .font(.luna(size: 12, weight: .medium, relativeTo: .caption))
                    .foregroundStyle(.luna(.textPrimary))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // An equal share of the row each (the design's 4-column grid).
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
```

- [ ] **Step 9: UI test**

Trong `UITests/UITestSupport.swift`, thay:
```swift
    /// History lives inside the Kicks tab (spec §2.3).
```
bằng:
```swift
    /// Taps `label` in a confirmation dialog: an action sheet, or on newer iOS a
    /// popover whose button comes after the one that opened it.
    func confirmDialog(_ label: String) {
        let sheetButton = sheets.buttons[label]
        if sheetButton.waitForExistence(timeout: 3) {
            sheetButton.tap()
            return
        }
        let named = buttons.matching(NSPredicate(format: "label == %@", label))
        named.element(boundBy: max(named.count - 1, 0)).tap()
    }

    /// Phase 5: pregnancy Today → "Symptoms".
    func openPregnancySymptoms() {
        let shortcut = buttons["shortcutSymptoms"]
        XCTAssertTrue(shortcut.waitForExistence(timeout: 10))
        scrollUntilHittable(shortcut)
        shortcut.tap()
        XCTAssertTrue(descendants(matching: .any)["symptomsTodayCard"].waitForExistence(timeout: 5))
    }

    /// History lives inside the Kicks tab (spec §2.3).
```

`UITests/PregnancySymptomsUITests.swift` (toàn bộ file):
```swift
import XCTest

/// Phase 5 spec §3.2 and §6: the pregnancy Symptoms screen, its sheet and the safety card.
final class PregnancySymptomsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Contractions → the safety card → the week detail opens at its warnings;
    /// the saved day shows the warning mark.
    @MainActor
    func testContractionsShowTheSafetyCardAndOpenTheWarnings() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        app.openPregnancySymptoms()
        XCTAssertTrue(app.descendants(matching: .any)["symptomsListEmpty"].exists)
        let logToday = app.buttons["symptomsLogToday"]
        XCTAssertEqual(logToday.label, "Log today")
        logToday.tap()

        let contractions = app.buttons["symptomChip-contractions"]
        XCTAssertTrue(contractions.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["symptomChip-cramps"].exists) // cycle symptoms stay hidden
        let card = app.descendants(matching: .any)["symptomSafetyCard"]
        XCTAssertFalse(card.exists)
        app.scrollUntilHittable(contractions)
        contractions.tap()
        XCTAssertTrue(contractions.isSelected)
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        let advice = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'before week 37'")).firstMatch
        XCTAssertTrue(advice.exists)
        attachScreenshot(app, "symptoms-safety-en")

        let action = app.buttons["symptomSafetyAction"]
        app.scrollUntilHittable(action)
        action.tap()
        let warnings = app.descendants(matching: .any)["weekWarnings"].firstMatch
        XCTAssertTrue(warnings.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["weekDetailTitle"].label, "Week 24")
        let scrolled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: warnings)
        XCTAssertEqual(XCTWaiter().wait(for: [scrolled], timeout: 5), .completed)
        attachScreenshot(app, "week-warnings-en")
        app.buttons["weekDetailClose"].tap()

        // Saved before the week detail opened.
        let summary = app.descendants(matching: .any)["symptomsTodaySummary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        waitForLabel(summary, containing: "Contractions")
        XCTAssertEqual(app.buttons["symptomsLogToday"].label, "Edit")
        let row = app.descendants(matching: .any)["symptomDayRow"].firstMatch
        app.scrollUntilHittable(row)
        XCTAssertTrue(row.label.contains("Contractions"), row.label)
        XCTAssertTrue(row.label.contains("A symptom to watch"), row.label)
    }

    /// Swollen feet also shows the card; unselecting every such symptom hides it.
    @MainActor
    func testSwollenFeetShowsTheCardAndUnselectingHidesIt() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        app.openPregnancySymptoms()
        app.buttons["symptomsLogToday"].tap()
        let swollen = app.buttons["symptomChip-swollenFeet"]
        XCTAssertTrue(swollen.waitForExistence(timeout: 5))
        app.scrollUntilHittable(swollen)
        swollen.tap()
        let card = app.descendants(matching: .any)["symptomSafetyCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'face or hands'")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'before week 37'")).firstMatch.exists)
        swollen.tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: card)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed)
    }

    /// Mood and symptoms are saved, listed under their week, and deleted after a confirmation.
    @MainActor
    func testLoggedDayIsListedByWeekAndDeletedAfterConfirming() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        app.openPregnancySymptoms()
        app.buttons["symptomsLogToday"].tap()
        let tired = app.buttons["moodChip-tired"]
        XCTAssertTrue(tired.waitForExistence(timeout: 5))
        tired.tap()
        let nausea = app.buttons["symptomChip-nausea"]
        app.scrollUntilHittable(nausea)
        nausea.tap()
        app.buttons["symptomSave"].tap()

        let row = app.descendants(matching: .any)["symptomDayRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Tired · Nausea"), row.label)
        XCTAssertFalse(row.label.contains("A symptom to watch"), row.label)
        XCTAssertTrue(app.staticTexts["Week 24"].exists)

        app.scrollUntilHittable(row)
        row.swipeLeft()
        app.buttons["Delete"].firstMatch.tap()
        app.confirmDialog("Delete")
        XCTAssertTrue(app.descendants(matching: .any)["symptomsListEmpty"].waitForExistence(timeout: 5))
        waitForLabel(app.descendants(matching: .any)["symptomsTodaySummary"], containing: "Nothing logged yet today")
    }

    /// Spec §6: the screen and the sheet in vi/en × light/dark.
    @MainActor
    func testSymptomsScreens() {
        for (language, dark) in UITestVariants.all {
            let suffix = UITestVariants.suffix(language, dark)
            let app = XCUIApplication.launchPinned(language: language, dark: dark, dueDate: UITestDates.dueAtWeek24)
            app.openPregnancySymptoms()
            attachScreenshot(app, "symptoms-empty-\(suffix)")
            app.buttons["symptomsLogToday"].tap()
            let calm = app.buttons["moodChip-calm"]
            XCTAssertTrue(calm.waitForExistence(timeout: 5))
            calm.tap()
            for symptom in ["nausea", "backPain", "contractions"] {
                let chip = app.buttons["symptomChip-\(symptom)"]
                app.scrollUntilHittable(chip)
                chip.tap()
            }
            XCTAssertTrue(app.descendants(matching: .any)["symptomSafetyCard"].waitForExistence(timeout: 5))
            attachScreenshot(app, "symptoms-sheet-\(suffix)")
            app.buttons["symptomSave"].tap()
            XCTAssertTrue(app.descendants(matching: .any)["symptomDayRow"].firstMatch.waitForExistence(timeout: 5))
            attachScreenshot(app, "symptoms-list-\(suffix)")
            app.terminate()
        }
    }

    /// Spec §5–6: Dynamic Type AX5 — chips wrap, nothing is cut.
    @MainActor
    func testSymptomsLargestText() {
        let app = XCUIApplication.launchPinned(language: "vi", dueDate: UITestDates.dueAtWeek24, largestText: true)
        let shortcut = app.buttons["shortcutSymptoms"]
        XCTAssertTrue(shortcut.waitForExistence(timeout: 10))
        app.scrollUntilHittable(shortcut, maxSwipes: 12)
        shortcut.tap()
        let logToday = app.buttons["symptomsLogToday"]
        XCTAssertTrue(logToday.waitForExistence(timeout: 5))
        attachScreenshot(app, "symptoms-vi-ax5")
        app.scrollUntilHittable(logToday)
        logToday.tap()
        let contractions = app.buttons["symptomChip-contractions"]
        XCTAssertTrue(contractions.waitForExistence(timeout: 5))
        app.scrollUntilHittable(contractions, maxSwipes: 12)
        XCTAssertLessThanOrEqual(contractions.frame.maxX, app.windows.firstMatch.frame.maxX)
        contractions.tap()
        let card = app.descendants(matching: .any)["symptomSafetyCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        app.swipeUp()
        attachScreenshot(app, "symptoms-sheet-vi-ax5")
    }
}
```

Trong `UITests/PregnancyTodayUITests.swift`, thay:
```swift
    /// Spec §4.5: chips change the week (scrolled into view), ✕ goes back to Today.
```
bằng:
```swift
    /// Phase 5 spec §3.4: "Symptoms" opens the pregnancy Symptoms screen.
    @MainActor
    func testSymptomsShortcutOpensTheSymptomsScreen() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        let shortcut = app.buttons["shortcutSymptoms"]
        XCTAssertTrue(shortcut.waitForExistence(timeout: 10))
        XCTAssertEqual(shortcut.label, "Symptoms")
        app.scrollUntilHittable(shortcut)
        shortcut.tap()
        XCTAssertTrue(app.descendants(matching: .any)["symptomsTodayCard"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Today"].isSelected)
    }

    /// Spec §4.5: chips change the week (scrolled into view), ✕ goes back to Today.
```

- [ ] **Step 10: Commit, push, xác minh CI**

```bash
scripts/test-core.sh
git add Packages/KickCore App Shared UITests
git commit -F - <<'MSG'
feat(pregnancy): symptoms screen with the when-to-get-care card

A Symptoms shortcut on pregnancy Today opens today's card and the logged
days by week of pregnancy (tap to edit, swipe to delete). The sheet logs
mood, pregnancy symptoms and a note; contractions or swollen feet show
fixed advice and open this week's warning signs. No diagnosis.

CI-Only-Testing: PregnancySymptomsUITests, PregnancyTodayUITests, PregnancyScreenshotTests, PregnancyUITests
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`, gồm `PregnancySymptomsUITests` (5 test) và `PregnancyTodayUITests.testSymptomsShortcutOpensTheSymptomsScreen`; test cũ `testShortcutsOpenKicksAndTheWeek` vẫn xanh.

- [ ] **Step 11: Kiểm tra trực quan (so với prototype "Bottom sheet – Ghi triệu chứng", chế độ thai kỳ)**

- `symptoms-empty-vi-light`: nút quay lại "‹" trên thanh điều hướng; "Triệu chứng" 28/700; thẻ trắng nhãn "HÔM NAY" cam `#B8572F`, "Hôm nay chưa ghi gì" 16/600, nút "Ghi hôm nay" cam đậm `#B8572F` chữ trắng; "Những ngày đã ghi" 16/600 và dòng xám "Những ngày bạn ghi sẽ hiện ở đây, theo tuần thai."; không gì bị che bởi thanh trạng thái khi cuộn.
- `symptoms-sheet-vi-light`: "Hôm nay, 2 tháng 10"; "Tâm trạng" (chip "Bình thường" chọn: nền `#B8572F`, chữ trắng); "Triệu chứng" 7 chip Mang thai "Buồn nôn · Ợ nóng · Phù chân · Đau lưng · Chuột rút · Khó ngủ · Cơn gò" (chọn: Buồn nôn, Đau lưng, Cơn gò), **không** có "Đau bụng"; ngay dưới là thẻ hồng nhạt `#FDE8E4` viền `#F3C2B8`: tiêu đề đỏ sẫm "⚠ Khi nào cần đi khám ngay", câu "Đi khám ngay nếu cơn gò đều đặn hoặc đau trước tuần 37…", dòng nhỏ "Luna Mom không chẩn đoán…", nút chữ "Xem dấu hiệu cần đi khám"; rồi "Ghi chú"; nút "Lưu" cam đậm ở đáy.
- `symptoms-list-vi-light`: thẻ hôm nay "Bình thường · Buồn nôn · Đau lưng · Cơn gò", nút "Sửa"; tiêu đề nhóm "Tuần 24" xám; dòng "T6, 2 tháng 10" + tóm tắt và biểu tượng ⚠ đỏ sẫm bên phải.
- `symptoms-safety-en`, `week-warnings-en`: sheet tiếng Anh có thẻ an toàn; Chi tiết tuần "Week 24" đã cuộn để thẻ "When to get care right away" nằm ở đầu màn hình.
- Bản `-dark`: thẻ an toàn nền `#4A1E18` chữ `#FF9C8A`/`#D8CCC4`; chip chọn `#F0A07A` chữ `#1A1412`; mọi chữ đọc rõ.
- Bản `-en-*`: "Symptoms", "Nothing logged yet today", "Log today", "Logged days", "Nausea · Heartburn · Swollen feet · Back pain · Leg cramps · Insomnia · Contractions", "Week 24".
- `symptoms-vi-ax5`, `symptoms-sheet-vi-ax5`: chữ cực lớn không bị cắt; chip xuống dòng, mỗi chip nằm trong màn hình; thẻ an toàn dàn nhiều dòng.
- `pregnancy-home-24-*` (ảnh cũ): 3 lối tắt chia đều hàng (Đếm cử động · Triệu chứng với dấu "+" mảnh · Tuần thai "24"); `pregnancy-home-38-vi-ax5`: lối tắt thành 2 hàng, nhãn không bị cắt.

---
### Task 6: Mang thai — màn "Cân nặng", thẻ Cân nặng trên Hôm nay, lối tắt, dòng hồ sơ trong Cá nhân, `-seedWeights`

`WeightView` (spec §3.3) mở từ lối tắt "Cân nặng" hoặc thẻ "Cân nặng của mẹ": chưa có cân trước mang thai → thẻ thiết lập (cân trước, chiều cao — chiều cao có thể bỏ trống); có rồi → thẻ tóm tắt ("Đã tăng +X kg" 32/700 `pregStrong`, cân mới nhất + tuần, "BMI 20,3 · Bình thường", pill trạng thái), biểu đồ Swift Charts 170 pt (trục tuần 0–40, dải khuyến nghị `AreaMark` `pregSoft` khi có nhóm BMI, đường `pregStrong` 2,5 pt có chấm, VoiceOver đọc từng chấm), chú thích; thẻ nhập (ngày mặc định hôm nay trong khoảng kỳ kinh cuối…hôm nay, kg ±0,1 bằng nút tròn 42 pt và ô gõ "56,2"/"56.2", "Lưu" `pregStrong`, nhập ngoài khoảng → báo dưới ô + VoiceOver); lịch sử theo tuần (mới nhất trên), vuốt để xóa có xác nhận. Hôm nay (Mang thai) có 4 lối tắt và thẻ "Cân nặng của mẹ" ngay sau thẻ kích thước bé (pill `Trong khoảng` `fertileSoft`/`tealStrong`, `Thấp hơn/Cao hơn khoảng` `pregSoft`/`pregOnSoft` + "Trao đổi với bác sĩ ở lần khám tới"; chưa có dữ liệu → "Ghi cân nặng"). Cá nhân → mục Thai kỳ thêm dòng "Cân nặng trước mang thai · Chiều cao" (`profileMaternal`) mở sheet sửa. `WeightCoordinator` nạp cùng các coordinator khác.

**Files:**
- Create: `App/Weight/{WeightTexts,WeightChart,WeightSummaryCard,WeightEntryCard,MaternalProfileForm,WeightTodayCard,WeightView}.swift`, `App/DesignSystem/KeyboardDone.swift`, `UITests/WeightUITests.swift`
- Modify: `App/Formatting.swift`, `App/Pregnancy/PregnancyTodayView.swift`, `App/Profile/ProfileView.swift`, `App/AppEnvironment.swift`, `App/RootView.swift`, `App/KickCounterApp.swift`, `Shared/L10n.swift`, `Shared/Localizable.xcstrings` (script), `UITests/{PregnancyTodayUITests,ProfileUITests,PregnancyScreenshotTests}.swift`

**Interfaces:**
- Consumes: Task 2 (`WeightCoordinator` và toàn bộ API, `WeightStats.points/sections/band`, `WeightPoint`, `WeightRules.dayRange/kgRange/rounded`, `DecimalEntry`, `MaternalProfile`, `WeightGuidance.termWeek`, `WeightSeed`, `UITestLaunchOptions.seedWeights`), Task 3 (`WeightStore`), Task 5 (`PregnancyRoute`, `route`, `symbolIcon(_:)`, `shortcut(_:identifier:action:icon:)`, `XCUIApplication.confirmDialog(_:)`); `LunaSheet`, `lunaCard`, `.pill(_:)`, `toast(_:)`, `lunaStatusBarBackdrop()`, `LunaRow`, `LunaDivider`, `PregnancyDateSheet`.
- Produces:
  - App: `WeightView()`, `WeightTodayCard(dueDate:)`, `WeightSummaryCard(points:profile:)`, `WeightChart(points:band:)`, `WeightChartLegend(showsBand:)`, `WeightEntryCard(dueDate:onSaved:)`, `MaternalProfileForm(requiresPreWeight:onSaved:)`, `MaternalProfileSheet()`, `WeightStatusPill(status:)`, `enum WeightTexts { line(_:), pointLabel(_:) }`, `View.keyboardDoneButton()`; `Formatting.kilograms(_:signed:spoken:)`, `Formatting.centimeters(_:)`, `Formatting.decimal(_:)`; `AppEnvironment.weight: WeightCoordinator` (trong environment của mọi màn).
  - L10n: `commonDone`, `pregnancyShortcutWeight`, `weightTitle`, `weightGained`, `weightSince`, `weightBMI(_:_:)`, `weightCategory(_:)`, `weightStatus(_:)`, `weightStatusTalk`, `weightNoHeight`, `weightChartWeek/Gain/Range/You`, `weightChartGainPoint(_:_:)`, `weightChartLossPoint(_:_:)`, `weightAdd`, `weightAddDate`, `weightAddKg`, `weightLess`, `weightMore`, `weightInvalidKg`, `weightInvalidHeight`, `weightSaved`, `weightHistory`, `weightHistoryEmpty`, `weightHistoryOutside`, `weightDeleteConfirm`, `weightSetupTitle/Body/PreWeight/Height`, `weightCardTitle`, `maternalTitle`, `profileMaternal`, `profileMaternalNotSet`, `weightFailure(_:)`.
  - Accessibility id mới: `shortcutWeight`, `weightCard`, `weightSetupCard`, `weightSetupPreWeight`, `weightSetupHeight`, `weightSetupSave`, `weightSetupPreWeightError`, `weightSetupHeightError`, `weightSummaryCard`, `weightSummary`, `weightBMI`, `weightStatusPill`, `weightNoHeightHint`, `weightChart`, `weightDatePicker`, `weightMinus`, `weightPlus`, `weightKgField`, `weightKgError`, `weightSave`, `weightHistoryEmpty`, `weightRow`, `weightAddDates`, `keyboardDone`, `profileMaternal`, `maternalSheetTitle`, `maternalCancel`.

- [ ] **Step 1: Chuỗi**

```bash
# apply
scripts/add-strings.py <<'JSON'
{
  "common.done": ["Done", "Xong"],
  "pregnancy.shortcut.weight": ["Weight", "Cân nặng"],
  "weight.title": ["Weight", "Cân nặng"],
  "weight.gained": ["Gained", "Đã tăng"],
  "weight.since": ["since pre-pregnancy", "so với trước khi mang thai"],
  "weight.bmi": ["BMI %@ · %@", "BMI %@ · %@"],
  "weight.category.under": ["Underweight", "Thiếu cân"],
  "weight.category.normal": ["Normal", "Bình thường"],
  "weight.category.over": ["Overweight", "Thừa cân"],
  "weight.category.obese": ["Obese", "Béo phì"],
  "weight.status.below": ["Below range", "Thấp hơn khoảng"],
  "weight.status.inRange": ["In range", "Trong khoảng"],
  "weight.status.above": ["Above range", "Cao hơn khoảng"],
  "weight.status.talk": ["Talk to your doctor at your next visit", "Trao đổi với bác sĩ ở lần khám tới"],
  "weight.noHeight": ["Add your height in Profile to see the recommended range.", "Thêm chiều cao trong Cá nhân để xem khoảng khuyến nghị."],
  "weight.chart.week": ["Week of pregnancy", "Tuần thai"],
  "weight.chart.gain": ["Gain", "Mức tăng"],
  "weight.chart.range": ["Recommended range", "Khoảng khuyến nghị"],
  "weight.chart.you": ["You", "Bạn"],
  "weight.chart.point.gain": ["Week %ld: gained %@", "Tuần %ld: tăng %@"],
  "weight.chart.point.loss": ["Week %ld: lost %@", "Tuần %ld: giảm %@"],
  "weight.add": ["Log weight", "Ghi cân nặng"],
  "weight.add.date": ["Day", "Ngày"],
  "weight.add.kg": ["Weight in kilograms", "Cân nặng (kg)"],
  "weight.less": ["0.1 kg less", "Bớt 0,1 kg"],
  "weight.more": ["0.1 kg more", "Thêm 0,1 kg"],
  "weight.invalid.kg": ["Enter a weight from 30 to 200 kg", "Nhập cân nặng từ 30 đến 200 kg"],
  "weight.invalid.height": ["Enter a height from 120 to 220 cm", "Nhập chiều cao từ 120 đến 220 cm"],
  "weight.saved": ["Weight saved", "Đã lưu cân nặng"],
  "weight.history": ["History", "Lịch sử"],
  "weight.history.empty": ["No weights logged yet", "Chưa ghi cân nặng nào"],
  "weight.history.outside": ["Outside this pregnancy", "Ngoài thai kỳ này"],
  "weight.delete.confirm": ["Delete this weight?", "Xóa cân nặng này?"],
  "weight.setup.title": ["Before you start", "Trước khi bắt đầu"],
  "weight.setup.body": ["Your weight before pregnancy and your height set the recommended range (IOM 2009). Height is optional; you can change both in Profile.", "Cân nặng trước mang thai và chiều cao giúp tính khoảng tăng cân khuyến nghị (IOM 2009). Chiều cao không bắt buộc; có thể sửa cả hai trong Cá nhân."],
  "weight.setup.preWeight": ["Weight before pregnancy (kg)", "Cân nặng trước mang thai (kg)"],
  "weight.setup.height": ["Height (cm, optional)", "Chiều cao (cm, không bắt buộc)"],
  "weight.card.title": ["Your weight", "Cân nặng của mẹ"],
  "weight.failure.load": ["Couldn't read your weights. Please try again later.", "Không đọc được dữ liệu cân nặng. Hãy thử lại sau."],
  "weight.failure.save": ["Couldn't save. Please try again.", "Không lưu được. Hãy thử lại."],
  "weight.failure.future": ["Pick today or an earlier day.", "Hãy chọn hôm nay hoặc một ngày trước đó."],
  "maternal.title": ["Weight and height", "Cân nặng và chiều cao"],
  "profile.maternal": ["Pre-pregnancy weight · Height", "Cân nặng trước mang thai · Chiều cao"],
  "profile.maternal.notSet": ["Not set", "Chưa nhập"]
}
JSON
```
Expected: `429 strings`. Chữ thẻ Hôm nay, "Trong khoảng"/"Đã tăng"/"so với trước khi mang thai"/"Khoảng khuyến nghị"/"Bạn"/"Lịch sử" theo `T` của prototype; "Thấp hơn khoảng"/"Cao hơn khoảng" theo spec §3.4.

Trong `Shared/L10n.swift`, thay:
```swift
    static var symptomSafetyAction: String { t("symptom.safety.action") }
}
```
bằng:
```swift
    static var symptomSafetyAction: String { t("symptom.safety.action") }

    // MARK: - Phase 5: weight

    static var commonDone: String { t("common.done") }
    static var pregnancyShortcutWeight: String { t("pregnancy.shortcut.weight") }
    static var weightTitle: String { t("weight.title") }
    static var weightGained: String { t("weight.gained") }
    static var weightSince: String { t("weight.since") }
    /// "BMI 20.3 · Normal".
    static func weightBMI(_ bmi: String, _ category: String) -> String { String(format: t("weight.bmi"), bmi, category) }
    static func weightCategory(_ category: BMICategory) -> String {
        switch category {
        case .under: t("weight.category.under")
        case .normal: t("weight.category.normal")
        case .over: t("weight.category.over")
        case .obese: t("weight.category.obese")
        }
    }
    static func weightStatus(_ status: WeightStatus) -> String {
        switch status {
        case .below: t("weight.status.below")
        case .inRange: t("weight.status.inRange")
        case .above: t("weight.status.above")
        }
    }
    static var weightStatusTalk: String { t("weight.status.talk") }
    static var weightNoHeight: String { t("weight.noHeight") }
    static var weightChartWeek: String { t("weight.chart.week") }
    static var weightChartGain: String { t("weight.chart.gain") }
    static var weightChartRange: String { t("weight.chart.range") }
    static var weightChartYou: String { t("weight.chart.you") }
    /// VoiceOver for a chart dot: "Week 24: gained 6.0 kilograms".
    static func weightChartGainPoint(_ week: Int, _ kg: String) -> String { String(format: t("weight.chart.point.gain"), week, kg) }
    static func weightChartLossPoint(_ week: Int, _ kg: String) -> String { String(format: t("weight.chart.point.loss"), week, kg) }
    static var weightAdd: String { t("weight.add") }
    static var weightAddDate: String { t("weight.add.date") }
    static var weightAddKg: String { t("weight.add.kg") }
    static var weightLess: String { t("weight.less") }
    static var weightMore: String { t("weight.more") }
    static var weightInvalidKg: String { t("weight.invalid.kg") }
    static var weightInvalidHeight: String { t("weight.invalid.height") }
    static var weightSaved: String { t("weight.saved") }
    static var weightHistory: String { t("weight.history") }
    static var weightHistoryEmpty: String { t("weight.history.empty") }
    static var weightHistoryOutside: String { t("weight.history.outside") }
    static var weightDeleteConfirm: String { t("weight.delete.confirm") }
    static var weightSetupTitle: String { t("weight.setup.title") }
    static var weightSetupBody: String { t("weight.setup.body") }
    static var weightSetupPreWeight: String { t("weight.setup.preWeight") }
    static var weightSetupHeight: String { t("weight.setup.height") }
    static var weightCardTitle: String { t("weight.card.title") }
    static var maternalTitle: String { t("maternal.title") }
    static var profileMaternal: String { t("profile.maternal") }
    static var profileMaternalNotSet: String { t("profile.maternal.notSet") }
    static func weightFailure(_ failure: WeightFailure) -> String {
        switch failure {
        case .loadFailed: t("weight.failure.load")
        case .saveFailed: t("weight.failure.save")
        case .futureDate: t("weight.failure.future")
        case .outOfRange: t("weight.invalid.kg")
        case .invalidHeight: t("weight.invalid.height")
        }
    }
}
```

- [ ] **Step 2: Định dạng kg, cm, số thập phân**

Trong `App/Formatting.swift`, thay:
```swift
    private static var kilogramDigits: FloatingPointFormatStyle<Double> {
```
bằng:
```swift
    /// The mother's weight: "58.0 kg" / "58,0 kg"; `signed` writes gains as
    /// "+6.0 kg" / "−0.4 kg"; `spoken` spells the unit out for VoiceOver.
    static func kilograms(_ kg: Double, signed: Bool = false, spoken: Bool = false) -> String {
        let digits = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(1))
            .sign(strategy: signed ? .always() : .automatic)
            .locale(locale)
        return Measurement(value: kg, unit: UnitMass.kilograms).formatted(
            .measurement(width: spoken ? .wide : .abbreviated, usage: .asProvided, numberFormatStyle: digits).locale(locale)
        )
    }

    /// Height: "160 cm" / "158,5 cm".
    static func centimeters(_ cm: Double) -> String {
        Measurement(value: cm, unit: UnitLength.centimeters).formatted(
            .measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0...1)))
                .locale(locale)
        )
    }

    /// One decimal, e.g. a BMI: "20.3" / "20,3".
    static func decimal(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)).locale(locale))
    }

    private static var kilogramDigits: FloatingPointFormatStyle<Double> {
```

- [ ] **Step 3: Nút "Xong" trên bàn phím số**

`App/DesignSystem/KeyboardDone.swift` (toàn bộ file):
```swift
import SwiftUI
import UIKit

extension View {
    /// A "Done" button above the keyboard: number pads have no return key.
    func keyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L10n.commonDone) {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .font(.luna(.button))
                .accessibilityIdentifier("keyboardDone")
            }
        }
    }
}
```

- [ ] **Step 4: Các thành phần màn Cân nặng**

`App/Weight/WeightTexts.swift` (toàn bộ file):
```swift
import KickCore
import SwiftUI

/// Words and the status pill shared by the Weight screen and Today's card.
enum WeightTexts {
    /// "58.0 kg · +6.0 kg", or "58.0 kg" without a pre-pregnancy weight.
    static func line(_ point: WeightPoint) -> String {
        guard let gain = point.gainKg else { return Formatting.kilograms(point.kg) }
        return "\(Formatting.kilograms(point.kg)) · \(Formatting.kilograms(gain, signed: true))"
    }

    /// VoiceOver for a chart dot: "Week 24: gained 6.0 kilograms, In range".
    static func pointLabel(_ point: WeightPoint) -> String {
        let gain = point.gainKg ?? 0
        let change = gain < 0
            ? L10n.weightChartLossPoint(point.week.weeks, Formatting.kilograms(-gain, spoken: true))
            : L10n.weightChartGainPoint(point.week.weeks, Formatting.kilograms(gain, spoken: true))
        guard let status = point.status else { return change }
        return "\(change), \(L10n.weightStatus(status))"
    }
}

/// "In range" (`fertileSoft` / `tealStrong`), "Below range" / "Above range"
/// (`pregSoft` / `pregOnSoft`, never red: spec §3.4).
struct WeightStatusPill: View {
    let status: WeightStatus

    var body: some View {
        let inRange = status == .inRange
        Text(L10n.weightStatus(status))
            .font(.luna(.label))
            .foregroundStyle(.luna(inRange ? .tealStrong : .pregOnSoft))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(.luna(inRange ? .fertileSoft : .pregSoft)))
            .accessibilityIdentifier("weightStatusPill")
    }
}
```

`App/Weight/WeightChart.swift` (toàn bộ file):
```swift
import Charts
import KickCore
import SwiftUI

/// 170 pt gain chart (phase 5 spec §3.3): x = gestational weeks 0–40, the
/// recommended band (`pregSoft`, only with a BMI group) and the mother's gain
/// (`pregStrong` 2.5 pt line with dots). VoiceOver reads every dot.
struct WeightChart: View {
    /// Points with a gain (a pre-pregnancy weight is set), oldest first.
    let points: [WeightPoint]
    /// Empty without a BMI group.
    let band: [WeightBandPoint]

    private var yDomain: ClosedRange<Double> {
        let gains = points.compactMap(\.gainKg)
        let low = min(0, (gains.min() ?? 0) - 1)
        let high = max(band.last?.highKg ?? 0, gains.max() ?? 0) + 1
        return low...high
    }

    private var xDomain: ClosedRange<Double> {
        0...max(WeightGuidance.termWeek, points.last?.exactWeek ?? 0)
    }

    var body: some View {
        Chart {
            ForEach(band) { item in
                AreaMark(
                    x: .value(L10n.weightChartWeek, Double(item.week)),
                    yStart: .value(L10n.weightChartGain, item.lowKg),
                    yEnd: .value(L10n.weightChartGain, item.highKg)
                )
                .foregroundStyle(.luna(.pregSoft))
                .accessibilityHidden(true)
            }
            ForEach(points) { point in
                LineMark(
                    x: .value(L10n.weightChartWeek, point.exactWeek),
                    y: .value(L10n.weightChartGain, point.gainKg ?? 0)
                )
                .foregroundStyle(.luna(.pregStrong))
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .accessibilityHidden(true)
                PointMark(
                    x: .value(L10n.weightChartWeek, point.exactWeek),
                    y: .value(L10n.weightChartGain, point.gainKg ?? 0)
                )
                .symbol {
                    Circle()
                        .fill(.luna(.card))
                        .overlay(Circle().strokeBorder(.luna(.pregStrong), lineWidth: 2))
                        .frame(width: 8, height: 8)
                }
                .accessibilityLabel(WeightTexts.pointLabel(point))
            }
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: [0, 13, 27, 40]) { _ in
                AxisGridLine().foregroundStyle(.luna(.divider))
                AxisValueLabel()
                    .font(.luna(size: 10, weight: .regular, relativeTo: .caption2))
                    .foregroundStyle(.luna(.textSecondary))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(.luna(.divider))
                AxisValueLabel()
                    .font(.luna(size: 10, weight: .regular, relativeTo: .caption2))
                    .foregroundStyle(.luna(.textSecondary))
            }
        }
        .frame(height: 170)
        .accessibilityIdentifier("weightChart")
    }
}

/// "Recommended range" swatch and "You" line under the chart.
struct WeightChartLegend: View {
    let showsBand: Bool

    var body: some View {
        HStack(spacing: 16) {
            if showsBand {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3).fill(.luna(.pregSoft)).frame(width: 14, height: 10)
                    Text(L10n.weightChartRange)
                }
            }
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2).fill(.luna(.pregStrong)).frame(width: 14, height: 3)
                Text(L10n.weightChartYou)
            }
        }
        .font(.luna(.small))
        .foregroundStyle(.luna(.textSecondary))
        .accessibilityHidden(true)
    }
}
```

`App/Weight/WeightSummaryCard.swift` (toàn bộ file):
```swift
import KickCore
import SwiftUI

/// Top of the Weight screen (phase 5 spec §3.3): gain since pre-pregnancy
/// (32/700 `pregStrong`), the latest weight and week, "BMI 21.3 · Normal",
/// the latest status, and the chart.
struct WeightSummaryCard: View {
    let points: [WeightPoint]
    let profile: MaternalProfile

    var body: some View {
        let latest = points.last
        let band = profile.category.map(WeightStats.band(category:)) ?? []
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.weightGained)
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.textSecondary))
                    Text(latest?.gainKg.map { Formatting.kilograms($0, signed: true) } ?? "–")
                        .font(.luna(.display))
                        .foregroundStyle(.luna(.pregStrong))
                    Text(L10n.weightSince)
                        .font(.luna(.small))
                        .foregroundStyle(.luna(.textSecondary))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let latest {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(Formatting.kilograms(latest.kg))
                            .font(.luna(size: 24, weight: .bold, relativeTo: .title2))
                            .foregroundStyle(.luna(.textPrimary))
                        Text(L10n.weekTitle(latest.week.weeks))
                            .font(.luna(.small))
                            .foregroundStyle(.luna(.textSecondary))
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("weightSummary")

            if let bmi = profile.bmi, let category = profile.category {
                HStack(spacing: 10) {
                    Text(L10n.weightBMI(Formatting.decimal(bmi), L10n.weightCategory(category)))
                        .font(.luna(.bodyMedium))
                        .foregroundStyle(.luna(.textPrimary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("weightBMI")
                    if let status = latest?.status {
                        WeightStatusPill(status: status)
                    }
                }
            } else {
                Text(L10n.weightNoHeight)
                    .font(.luna(.caption))
                    .foregroundStyle(.luna(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("weightNoHeightHint")
            }

            if !points.isEmpty {
                WeightChart(points: points, band: band)
                WeightChartLegend(showsBand: !band.isEmpty)
            }
        }
        .lunaCard()
    }
}
```

`App/Weight/WeightEntryCard.swift` (toàn bộ file):
```swift
import Accessibility
import KickCore
import SwiftUI

/// "Log weight" (phase 5 spec §3.3): the day (today by default, never later
/// than today nor before the last period), the weight with −/+ 0.1 kg buttons
/// and a field that takes "56,2" and "56.2", and Save.
struct WeightEntryCard: View {
    let dueDate: Date
    let onSaved: () -> Void

    @Environment(WeightCoordinator.self) private var weight
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var day = Calendar.current.startOfDay(for: AppClock.now())
    @State private var text = ""
    @State private var invalid = false
    @State private var failure: WeightFailure?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.weightAdd)
                .font(.luna(.cardTitleSmall))
                .foregroundStyle(.luna(.textPrimary))
                .accessibilityAddTraits(.isHeader)
            DatePicker(
                L10n.weightAddDate,
                selection: $day,
                in: WeightRules.dayRange(dueDate: dueDate, now: AppClock.now(), calendar: .current),
                displayedComponents: .date
            )
            .font(.luna(.body))
            .foregroundStyle(.luna(.textPrimary))
            .tint(.luna(.pregStrong))
            .accessibilityIdentifier("weightDatePicker")
            // At accessibility sizes the −/+ buttons go under the figure so it is not cut.
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 12) {
                    kgField
                    HStack {
                        stepButton(symbol: "minus", label: L10n.weightLess, delta: -0.1, identifier: "weightMinus")
                        Spacer()
                        stepButton(symbol: "plus", label: L10n.weightMore, delta: 0.1, identifier: "weightPlus")
                    }
                }
            } else {
                HStack(spacing: 12) {
                    stepButton(symbol: "minus", label: L10n.weightLess, delta: -0.1, identifier: "weightMinus")
                    kgField
                    stepButton(symbol: "plus", label: L10n.weightMore, delta: 0.1, identifier: "weightPlus")
                }
            }
            if invalid {
                Label(L10n.weightInvalidKg, systemImage: "exclamationmark.triangle.fill")
                    .font(.luna(.caption))
                    .foregroundStyle(.luna(.warningText))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("weightKgError")
            }
            Button(L10n.commonSave, action: save)
                .buttonStyle(.pill(.filled(.pregStrong)))
                .accessibilityIdentifier("weightSave")
        }
        .lunaCard()
        .onAppear { if text.isEmpty { prefill() } }
        .onChange(of: day) { prefill() }
        // Set up just now: start from the pre-pregnancy weight.
        .onChange(of: weight.profile.preWeightKg) { if weight.entries.isEmpty { prefill() } }
        .alert(failure.map(L10n.weightFailure) ?? "", isPresented: Binding(
            get: { failure != nil },
            set: { if !$0 { failure = nil } }
        )) {
            Button(L10n.commonOK) {}
        }
    }

    /// The figure (32/700, tabular digits) and "kg".
    private var kgField: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            TextField(L10n.weightAddKg, text: $text, prompt: Text(verbatim: "–"))
                .keyboardType(.decimalPad)
                .font(.luna(.display))
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .accessibilityLabel(L10n.weightAddKg)
                .accessibilityIdentifier("weightKgField")
                .onChange(of: text) { invalid = false }
            Text(verbatim: "kg")
                .font(.luna(.cardTitle))
                .foregroundStyle(.luna(.textSecondary))
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
    }

    /// 42 pt round −/+ button on `surface`.
    private func stepButton(symbol: String, label: String, delta: Double, identifier: String) -> some View {
        Button {
            let value = (currentValue ?? startValue) + delta
            text = format(min(max(WeightRules.rounded(value), WeightRules.kgRange.lowerBound), WeightRules.kgRange.upperBound))
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.luna(.textPrimary))
                .frame(width: 42, height: 42)
                .background(Circle().fill(.luna(.surface)))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    private var currentValue: Double? {
        if case .valid(let value) = DecimalEntry(text: text, range: WeightRules.kgRange) { return value }
        return nil
    }

    /// The day's stored weight, else the latest, else the pre-pregnancy weight.
    private var knownValue: Double? {
        weight.entry(on: day)?.kg ?? weight.latest?.kg ?? weight.profile.preWeightKg
    }

    /// Where −/+ start from an empty field.
    private var startValue: Double { knownValue ?? 60 }

    private func prefill() {
        text = knownValue.map(format) ?? ""
    }

    private func format(_ kg: Double) -> String {
        kg.formatted(.number.precision(.fractionLength(1)).grouping(.never).locale(Formatting.locale))
    }

    private func save() {
        guard case .valid(let kg) = DecimalEntry(text: text, range: WeightRules.kgRange) else {
            invalid = true
            AccessibilityNotification.Announcement(L10n.weightInvalidKg).post()
            return
        }
        switch weight.save(kg: kg, on: day) {
        case nil:
            onSaved()
        case .outOfRange?:
            invalid = true
            AccessibilityNotification.Announcement(L10n.weightInvalidKg).post()
        case let other?:
            weight.clearFailure()
            failure = other
        }
    }
}
```

`App/Weight/MaternalProfileForm.swift` (toàn bộ file):
```swift
import Accessibility
import KickCore
import SwiftUI

/// Pre-pregnancy weight (30–200 kg) and height (120–220 cm, optional): the
/// Weight screen's setup card and Profile's sheet (phase 5 spec §3.3, §3.5).
struct MaternalProfileForm: View {
    /// The setup card needs a weight; Profile may clear both.
    let requiresPreWeight: Bool
    let onSaved: () -> Void

    @Environment(WeightCoordinator.self) private var weight
    @State private var weightText = ""
    @State private var heightText = ""
    @State private var weightInvalid = false
    @State private var heightInvalid = false
    @State private var filled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            field(L10n.weightSetupPreWeight, text: $weightText, identifier: "weightSetupPreWeight")
                .onChange(of: weightText) { weightInvalid = false }
            if weightInvalid {
                error(L10n.weightInvalidKg, identifier: "weightSetupPreWeightError")
            }
            field(L10n.weightSetupHeight, text: $heightText, identifier: "weightSetupHeight")
                .onChange(of: heightText) { heightInvalid = false }
                .padding(.top, 6)
            if heightInvalid {
                error(L10n.weightInvalidHeight, identifier: "weightSetupHeightError")
            }
            Button(L10n.commonSave, action: save)
                .buttonStyle(.pill(.filled(.pregStrong)))
                .padding(.top, 10)
                .accessibilityIdentifier("weightSetupSave")
        }
        .onAppear(perform: fill)
    }

    private func field(_ title: String, text: Binding<String>, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.luna(.captionStrong))
                .foregroundStyle(.luna(.textSecondary))
                .accessibilityHidden(true)
            TextField(title, text: text)
                .keyboardType(.decimalPad)
                .font(.luna(.body))
                .foregroundStyle(.luna(.textPrimary))
                .padding(14)
                .background(.luna(.surface), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityLabel(title)
                .accessibilityIdentifier(identifier)
        }
    }

    private func error(_ message: String, identifier: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.luna(.caption))
            .foregroundStyle(.luna(.warningText))
            .accessibilityIdentifier(identifier)
    }

    private func fill() {
        guard !filled else { return }
        filled = true
        weightText = weight.profile.preWeightKg.map(format) ?? ""
        heightText = weight.profile.heightCm.map(format) ?? ""
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)).grouping(.never).locale(Formatting.locale))
    }

    private func save() {
        let preWeight = DecimalEntry(text: weightText, range: MaternalProfile.preWeightRange)
        let height = DecimalEntry(text: heightText, range: MaternalProfile.heightRange)
        weightInvalid = preWeight == .invalid || (requiresPreWeight && preWeight == .empty)
        heightInvalid = height == .invalid
        guard !weightInvalid, !heightInvalid else {
            AccessibilityNotification.Announcement(weightInvalid ? L10n.weightInvalidKg : L10n.weightInvalidHeight).post()
            return
        }
        let profile = MaternalProfile(preWeightKg: value(of: preWeight), heightCm: value(of: height))
        if weight.updateProfile(profile) == nil {
            onSaved()
        }
    }

    private func value(of entry: DecimalEntry) -> Double? {
        if case .valid(let value) = entry { return value }
        return nil
    }
}

/// Profile → "Pre-pregnancy weight · Height".
struct MaternalProfileSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // A stack only for the keyboard's "Done" toolbar; its bar stays hidden.
        NavigationStack {
            LunaSheet(title: L10n.maternalTitle, titleIdentifier: "maternalSheetTitle") {
                Text(L10n.weightSetupBody)
                    .font(.luna(.body))
                    .foregroundStyle(.luna(.articleText))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
                    .padding(.bottom, 18)
                MaternalProfileForm(requiresPreWeight: false) { dismiss() }
                Button(L10n.commonCancel) { dismiss() }
                    .buttonStyle(.pill(.text(.textSecondary), height: 44))
                    .padding(.top, 8)
                    .accessibilityIdentifier("maternalCancel")
            }
            .toolbar(.hidden, for: .navigationBar)
            .keyboardDoneButton()
        }
        .lunaSheetPresentation()
    }
}
```

`App/Weight/WeightTodayCard.swift` (toàn bộ file):
```swift
import KickCore
import SwiftUI

/// "Your weight" on pregnancy Today (phase 5 spec §3.4), after the baby's
/// size: the latest weight and gain with its status, and "Talk to your doctor
/// at your next visit" when out of range. Nothing logged → "Log weight".
struct WeightTodayCard: View {
    let dueDate: Date

    @Environment(WeightCoordinator.self) private var weight

    var body: some View {
        let latest = WeightStats.points(weight.entries, profile: weight.profile, dueDate: dueDate).last
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.weightCardTitle)
                    .lunaLabelStyle()
                Text(latest.map(WeightTexts.line) ?? L10n.weightAdd)
                    .font(.luna(.cardTitle))
                    .foregroundStyle(.luna(.textPrimary))
                if let status = latest?.status, status != .inRange {
                    Text(L10n.weightStatusTalk)
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let status = latest?.status {
                WeightStatusPill(status: status)
            }
            Image(systemName: "chevron.right")
                .foregroundStyle(.luna(.chevron))
                .accessibilityHidden(true)
        }
        .lunaCard(padding: 16)
    }
}
```

`App/Weight/WeightView.swift` (toàn bộ file):
```swift
import KickCore
import SwiftUI

/// The mother's weight (phase 5 spec §3.3), opened from Today's shortcut or
/// card: setup (pre-pregnancy weight, optional height) until a pre-pregnancy
/// weight is known, then the gain, BMI group, status and chart; the entry
/// card; the history by week (swipe to delete, with a confirmation).
struct WeightView: View {
    @Environment(WeightCoordinator.self) private var weight
    @AppStorage(SettingsKey.dueDate, store: AppGroup.defaults) private var dueDate: Double = 0
    @State private var pendingDelete: WeightRecord?
    @State private var showingDateSheet = false
    @State private var toast: String?

    private var now: Date { AppClock.now() }
    private var due: Date? { dueDate > 0 ? Date(timeIntervalSince1970: dueDate) : nil }
    private var timeline: PregnancyTimeline? { due.flatMap { PregnancyTimeline(dueDate: $0, now: now) } }

    var body: some View {
        List {
            Group {
                Text(L10n.weightTitle)
                    .font(.luna(.screenTitle))
                    .tracking(-0.56)
                    .foregroundStyle(.luna(.textPrimary))
                    .accessibilityAddTraits(.isHeader)
                if let due, timeline != nil {
                    if weight.profile.preWeightKg == nil {
                        setupCard
                    } else {
                        WeightSummaryCard(
                            points: WeightStats.points(weight.entries, profile: weight.profile, dueDate: due),
                            profile: weight.profile
                        )
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("weightSummaryCard")
                    }
                    WeightEntryCard(dueDate: due) { toast = L10n.weightSaved }
                    Text(L10n.weightHistory)
                        .font(.luna(.cardTitle))
                        .foregroundStyle(.luna(.textPrimary))
                        .padding(.top, 10)
                        .accessibilityAddTraits(.isHeader)
                    if weight.entries.isEmpty {
                        Text(L10n.weightHistoryEmpty)
                            .font(.luna(.caption))
                            .foregroundStyle(.luna(.textSecondary))
                            .accessibilityIdentifier("weightHistoryEmpty")
                    }
                } else {
                    datesCard
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))

            if let due, timeline != nil {
                ForEach(WeightStats.sections(weight.entries, dueDate: due)) { section in
                    Section {
                        ForEach(section.entries) { entry in
                            row(entry)
                                .listRowBackground(Color.luna(.card))
                                .swipeActions {
                                    Button(role: .destructive) {
                                        pendingDelete = entry
                                    } label: {
                                        Label(L10n.commonDelete, systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        Text(section.week.map(L10n.weekTitle) ?? L10n.weightHistoryOutside)
                            .font(.luna(.captionStrong))
                            .foregroundStyle(.luna(.textSecondary))
                            .textCase(nil)
                            .accessibilityAddTraits(.isHeader)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .lunaStatusBarBackdrop()
        .background(.luna(.background))
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneButton()
        .toast($toast)
        .sheet(isPresented: $showingDateSheet) { PregnancyDateSheet() }
        .confirmationDialog(
            L10n.weightDeleteConfirm,
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button(L10n.commonDelete, role: .destructive) {
                if let entry = pendingDelete { weight.delete(id: entry.id) }
                pendingDelete = nil
            }
            Button(L10n.commonCancel, role: .cancel) { pendingDelete = nil }
        }
        .alert(weight.failure.map(L10n.weightFailure) ?? "", isPresented: Binding(
            get: { weight.failure != nil && !showingDateSheet },
            set: { if !$0 { weight.clearFailure() } }
        )) {
            Button(L10n.commonOK) {}
        }
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.weightSetupTitle)
                .font(.luna(.cardTitle))
                .foregroundStyle(.luna(.textPrimary))
                .accessibilityAddTraits(.isHeader)
            Text(L10n.weightSetupBody)
                .font(.luna(.caption))
                .foregroundStyle(.luna(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 8)
            MaternalProfileForm(requiresPreWeight: true) {}
        }
        .lunaCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("weightSetupCard")
    }

    /// "Thu, Oct 1" and "+6.0 kg" on the left, "58.0 kg" on the right.
    private func row(_ entry: WeightRecord) -> some View {
        let gain = weight.profile.preWeightKg.map { Formatting.kilograms(WeightRules.rounded(entry.kg - $0), signed: true) }
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Formatting.weekdayDay(entry.day))
                    .font(.luna(.body))
                    .foregroundStyle(.luna(.textPrimary))
                if let gain {
                    Text(gain)
                        .font(.luna(.small))
                        .foregroundStyle(.luna(.textSecondary))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(Formatting.kilograms(entry.kg))
                .font(.luna(.bodyStrong))
                .foregroundStyle(.luna(.textPrimary))
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("weightRow")
    }

    private var datesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.pregnancyEmptyTitle)
                .font(.luna(.sheetTitle))
                .foregroundStyle(.luna(.textPrimary))
            Text(L10n.pregnancyEmptyBody)
                .font(.luna(.body))
                .foregroundStyle(.luna(.textSecondary))
            Button(L10n.pregnancyEmptyAction) { showingDateSheet = true }
                .buttonStyle(.pill(.filled(.pregStrong)))
                .accessibilityIdentifier("weightAddDates")
        }
        .lunaCard()
    }
}
```

- [ ] **Step 5: Hôm nay — lối tắt "Cân nặng" và thẻ "Cân nặng của mẹ"**

Trong `App/Pregnancy/PregnancyTodayView.swift`, thay:
```swift
enum PregnancyRoute: Hashable {
    case symptoms
}
```
bằng:
```swift
enum PregnancyRoute: Hashable {
    case symptoms
    case weight
}
```

Trong `App/Pregnancy/PregnancyTodayView.swift`, thay:
```swift
                case .symptoms: PregnancySymptomsView()
```
bằng:
```swift
                case .symptoms: PregnancySymptomsView()
                case .weight: WeightView()
```

Trong `App/Pregnancy/PregnancyTodayView.swift`, thay:
```swift
                .accessibilityIdentifier("babySizeCard")

```
bằng:
```swift
                .accessibilityIdentifier("babySizeCard")

                weightCard(dueDate: timeline.dueDate)

```

Trong `App/Pregnancy/PregnancyTodayView.swift`, thay:
```swift
                Button { detailWeek = WeekSelection(week: contentWeek) } label: { UnderReviewCard() }
                    .buttonStyle(.plain)
            case nil:
                EmptyView()
            }
```
bằng:
```swift
                Button { detailWeek = WeekSelection(week: contentWeek) } label: { UnderReviewCard() }
                    .buttonStyle(.plain)
                weightCard(dueDate: timeline.dueDate)
            case nil:
                weightCard(dueDate: timeline.dueDate)
            }
```

Trong `App/Pregnancy/PregnancyTodayView.swift`, thay:
```swift
            symbolIcon("plus")
        }
```
bằng:
```swift
            symbolIcon("plus")
        }
        let weight = shortcut(L10n.pregnancyShortcutWeight, identifier: "shortcutWeight", action: { route = .weight }) {
            symbolIcon("scalemass")
        }
```

Trong `App/Pregnancy/PregnancyTodayView.swift`, thay:
```swift
                    GridRow { weekShortcut }
```
bằng:
```swift
                    GridRow { weight; weekShortcut }
```

Trong `App/Pregnancy/PregnancyTodayView.swift`, thay:
```swift
                HStack(alignment: .top, spacing: 8) { kicks; symptoms; weekShortcut }
```
bằng:
```swift
                HStack(alignment: .top, spacing: 8) { kicks; symptoms; weight; weekShortcut }
```

Trong `App/Pregnancy/PregnancyTodayView.swift`, thay:
```swift
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

```
bằng:
```swift
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    /// "Your weight" (phase 5 spec §3.4), after the baby's size.
    private func weightCard(dueDate: Date) -> some View {
        Button { route = .weight } label: {
            WeightTodayCard(dueDate: dueDate)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("weightCard")
    }

```

- [ ] **Step 6: Cá nhân — dòng "Cân nặng trước mang thai · Chiều cao"**

Trong `App/Profile/ProfileView.swift`, thay:
```swift
    @Environment(KickCoordinator.self) private var coordinator
    @Environment(CycleCoordinator.self) private var cycle
```
bằng:
```swift
    @Environment(KickCoordinator.self) private var coordinator
    @Environment(CycleCoordinator.self) private var cycle
    @Environment(WeightCoordinator.self) private var weight
```

Trong `App/Profile/ProfileView.swift`, thay:
```swift
    @State private var showingKickSettings = false
```
bằng:
```swift
    @State private var showingKickSettings = false
    @State private var showingMaternal = false
```

Trong `App/Profile/ProfileView.swift`, thay:
```swift
            .sheet(isPresented: $showingPregnancyDates) { PregnancyDateSheet() }
```
bằng:
```swift
            .sheet(isPresented: $showingPregnancyDates) { PregnancyDateSheet() }
            .sheet(isPresented: $showingMaternal) { MaternalProfileSheet() }
```

Trong `App/Profile/ProfileView.swift`, thay:
```swift
            .buttonStyle(.plain)
            .accessibilityIdentifier("settingsPregnancyDates")
            if dueDate > 0 {
```
bằng:
```swift
            .buttonStyle(.plain)
            .accessibilityIdentifier("settingsPregnancyDates")
            LunaDivider()
            Button { showingMaternal = true } label: {
                LunaRow(title: L10n.profileMaternal, value: maternalText)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profileMaternal")
            if dueDate > 0 {
```

Trong `App/Profile/ProfileView.swift`, thay:
```swift
    private var cycleCard: some View {
```
bằng:
```swift
    /// "52.0 kg · 160 cm", "52.0 kg", or "Not set".
    private var maternalText: String {
        let parts = [weight.profile.preWeightKg.map { Formatting.kilograms($0) }, weight.profile.heightCm.map(Formatting.centimeters)]
            .compactMap { $0 }
        return parts.isEmpty ? L10n.profileMaternalNotSet : parts.joined(separator: " · ")
    }

    private var cycleCard: some View {
```

- [ ] **Step 7: `WeightCoordinator` trong app + `-seedWeights`**

Trong `App/AppEnvironment.swift`, thay:
```swift
    let cycle: CycleCoordinator
    let content: WeeklyContentLibrary?
```
bằng:
```swift
    let cycle: CycleCoordinator
    let weight: WeightCoordinator
    let content: WeeklyContentLibrary?
```

Trong `App/AppEnvironment.swift`, thay:
```swift
        return AppEnvironment(
            container: container,
            coordinator: coordinator,
            appointments: appointments,
            cycle: cycle,
            content: WeeklyContentLibrary.loadBundled()
        )
    }
```
bằng:
```swift
        let weightStore = WeightStore(context: container.mainContext)
        #if DEBUG
        if isUITesting, AppClock.launchOptions.seedWeights {
            try seedWeights(into: weightStore)
        }
        #endif
        let weight = WeightCoordinator(store: weightStore, defaults: AppGroup.defaults, now: { AppClock.now() })
        return AppEnvironment(
            container: container,
            coordinator: coordinator,
            appointments: appointments,
            cycle: cycle,
            weight: weight,
            content: WeeklyContentLibrary.loadBundled()
        )
    }
```

Trong `App/AppEnvironment.swift`, thay:
```swift
    /// `-uiTesting -seedOverdueSession`: a session started 2 h 5 min ago on the real
```
bằng:
```swift
    /// `-uiTesting -seedWeights`: the design's pre-pregnancy weight (52 kg), height
    /// (160 cm) and weights at weeks 12–30 of the seeded pregnancy (`-seedDueDate`),
    /// up to the pinned today.
    private static func seedWeights(into store: WeightStore) throws {
        try WeightSeed.profile.save(to: AppGroup.defaults)
        guard let dueDate = PregnancyProfile.load(from: AppGroup.defaults).dueDate else { return }
        let now = AppClock.now()
        for entry in WeightSeed.entries(dueDate: dueDate, today: now) {
            try store.save(entry, today: now)
        }
    }

    /// `-uiTesting -seedOverdueSession`: a session started 2 h 5 min ago on the real
```

Trong `App/RootView.swift`, thay:
```swift
    @Environment(CycleCoordinator.self) private var cycle
```
bằng:
```swift
    @Environment(CycleCoordinator.self) private var cycle
    @Environment(WeightCoordinator.self) private var weight
```

Trong `App/RootView.swift`, thay:
```swift
        await cycle.load()
    }
```
bằng:
```swift
        await cycle.load()
        await weight.load()
    }
```

Trong `App/KickCounterApp.swift`, thay:
```swift
                    .environment(env.cycle)
```
bằng:
```swift
                    .environment(env.cycle)
                    .environment(env.weight)
```

- [ ] **Step 8: UI test**

`UITests/WeightUITests.swift` (toàn bộ file):
```swift
import XCTest

/// Phase 5 spec §3.3–3.5 and §6: the mother's weight.
final class WeightUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openWeight(_ app: XCUIApplication) {
        let shortcut = app.buttons["shortcutWeight"]
        XCTAssertTrue(shortcut.waitForExistence(timeout: 10))
        app.scrollUntilHittable(shortcut, maxSwipes: 12)
        shortcut.tap()
    }

    /// Replaces a field's text: taps near its right edge so the cursor lands after
    /// centred text, deletes it, types, then "Done" (decimal pads have no return key).
    @MainActor
    private func type(_ text: String, into field: XCUIElement, in app: XCUIApplication) {
        app.scrollUntilHittable(field)
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8) + text)
        app.buttons["keyboardDone"].tap()
    }

    @MainActor
    private func tapSetupSave(_ app: XCUIApplication) {
        let save = app.buttons["weightSetupSave"]
        app.scrollUntilHittable(save)
        save.tap()
    }

    /// Spec §6: set up 52 kg / 160 cm → log 58.0 at week 24 → "In range".
    @MainActor
    func testSetupThenWeek24WeightIsInRange() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        openWeight(app)
        XCTAssertTrue(app.descendants(matching: .any)["weightSetupCard"].waitForExistence(timeout: 5))
        type("52", into: app.textFields["weightSetupPreWeight"], in: app)
        type("160", into: app.textFields["weightSetupHeight"], in: app)
        tapSetupSave(app)

        let bmi = app.staticTexts["weightBMI"]
        XCTAssertTrue(bmi.waitForExistence(timeout: 5))
        XCTAssertEqual(bmi.label, "BMI 20.3 · Normal")
        XCTAssertFalse(app.descendants(matching: .any)["weightSetupCard"].exists)

        let field = app.textFields["weightKgField"]
        XCTAssertEqual(field.value as? String, "52.0") // starts from the pre-pregnancy weight
        type("58.0", into: field, in: app)
        let save = app.buttons["weightSave"]
        app.scrollUntilHittable(save)
        save.tap()

        let pill = app.staticTexts["weightStatusPill"]
        XCTAssertTrue(pill.waitForExistence(timeout: 5))
        XCTAssertEqual(pill.label, "In range")
        let summary = app.descendants(matching: .any)["weightSummary"]
        XCTAssertTrue(summary.label.contains("+6.0 kg"), summary.label)
        XCTAssertTrue(summary.label.contains("Week 24"), summary.label)
        let row = app.descendants(matching: .any)["weightRow"].firstMatch
        app.scrollUntilHittable(row)
        XCTAssertTrue(row.label.contains("58.0 kg"), row.label)

        app.navigationBars.buttons.firstMatch.tap()
        let card = app.buttons["weightCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        app.scrollUntilHittable(card)
        XCTAssertTrue(card.label.contains("58.0 kg · +6.0 kg"), card.label)
        XCTAssertTrue(card.label.contains("In range"), card.label)
        XCTAssertFalse(card.label.contains("Talk to your doctor"), card.label)
    }

    /// Spec §6: without a height there is no BMI group, range or status.
    @MainActor
    func testSkippingTheHeightShowsNoRange() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        openWeight(app)
        XCTAssertTrue(app.descendants(matching: .any)["weightSetupCard"].waitForExistence(timeout: 5))
        type("52", into: app.textFields["weightSetupPreWeight"], in: app)
        tapSetupSave(app)
        XCTAssertTrue(app.staticTexts["weightNoHeightHint"].waitForExistence(timeout: 5))

        type("58.0", into: app.textFields["weightKgField"], in: app)
        let save = app.buttons["weightSave"]
        app.scrollUntilHittable(save)
        save.tap()
        XCTAssertTrue(app.descendants(matching: .any)["weightRow"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["weightStatusPill"].exists)
        XCTAssertFalse(app.staticTexts["weightBMI"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["weightSummary"].label.contains("+6.0 kg"))

        app.navigationBars.buttons.firstMatch.tap()
        let card = app.buttons["weightCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(card.label.contains("58.0 kg · +6.0 kg"), card.label)
        XCTAssertFalse(card.label.contains("range"), card.label)
    }

    /// Spec §5: out-of-range input is not saved and says why under the field.
    @MainActor
    func testImplausibleWeightIsNotSaved() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24, extraArguments: ["-seedWeights"])
        openWeight(app)
        let field = app.textFields["weightKgField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "58.0") // the latest weight (week 24)
        type("250", into: field, in: app)
        let save = app.buttons["weightSave"]
        app.scrollUntilHittable(save)
        save.tap()
        let error = app.descendants(matching: .any)["weightKgError"]
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertTrue(error.label.contains("30 to 200 kg"), error.label)
        let newest = app.descendants(matching: .any)["weightRow"].firstMatch
        app.scrollUntilHittable(newest)
        XCTAssertTrue(newest.label.contains("58.0 kg"), newest.label) // nothing new was saved
    }

    /// Above the range at week 38: neutral pill and "Talk to your doctor" on Today.
    @MainActor
    func testAboveRangeAsksToTalkToTheDoctor() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek38, extraArguments: ["-seedWeights"])
        let card = app.buttons["weightCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        app.scrollUntilHittable(card)
        // Week 30: 60.9 kg, +8.9 kg, in range.
        XCTAssertTrue(card.label.contains("60.9 kg · +8.9 kg"), card.label)
        XCTAssertTrue(card.label.contains("In range"), card.label)
        card.tap()

        let field = app.textFields["weightKgField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        type("70", into: field, in: app)
        let save = app.buttons["weightSave"]
        app.scrollUntilHittable(save)
        save.tap()
        let pill = app.staticTexts["weightStatusPill"]
        waitForLabel(pill, containing: "Above range")

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        waitForLabel(card, containing: "70.0 kg · +18.0 kg")
        XCTAssertTrue(card.label.contains("Above range"), card.label)
        XCTAssertTrue(card.label.contains("Talk to your doctor at your next visit"), card.label)
    }

    /// The chart and history of the seeded weeks; a swipe deletes after a confirmation.
    @MainActor
    func testSeededHistoryAndDelete() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek38, extraArguments: ["-seedWeights"])
        openWeight(app)
        XCTAssertTrue(app.descendants(matching: .any)["weightChart"].waitForExistence(timeout: 5))
        let rows = app.descendants(matching: .any).matching(identifier: "weightRow")
        let first = rows.firstMatch
        app.scrollUntilHittable(first)
        XCTAssertTrue(first.label.contains("60.9 kg"), first.label) // newest first
        XCTAssertTrue(app.staticTexts["Week 30"].exists)
        first.swipeLeft()
        app.buttons["Delete"].firstMatch.tap()
        app.confirmDialog("Delete")
        waitForLabel(rows.firstMatch, containing: "59.4 kg")
    }

    /// Spec §6: the screen in vi/en × light/dark, the setup card, AX5.
    @MainActor
    func testWeightScreens() {
        for (language, dark) in UITestVariants.all {
            let suffix = UITestVariants.suffix(language, dark)
            let app = XCUIApplication.launchPinned(
                language: language, dark: dark, dueDate: UITestDates.dueAtWeek38, extraArguments: ["-seedWeights"]
            )
            openWeight(app)
            XCTAssertTrue(app.descendants(matching: .any)["weightChart"].waitForExistence(timeout: 5))
            attachScreenshot(app, "weight-\(suffix)")
            let row = app.descendants(matching: .any)["weightRow"].firstMatch
            app.scrollUntilHittable(row)
            attachScreenshot(app, "weight-history-\(suffix)")
            app.terminate()

            let fresh = XCUIApplication.launchPinned(language: language, dark: dark, dueDate: UITestDates.dueAtWeek24)
            openWeight(fresh)
            XCTAssertTrue(fresh.descendants(matching: .any)["weightSetupCard"].waitForExistence(timeout: 5))
            attachScreenshot(fresh, "weight-setup-\(suffix)")
            fresh.terminate()
        }
    }

    @MainActor
    func testWeightLargestText() {
        let app = XCUIApplication.launchPinned(
            language: "vi", dueDate: UITestDates.dueAtWeek38, largestText: true, extraArguments: ["-seedWeights"]
        )
        openWeight(app)
        XCTAssertTrue(app.descendants(matching: .any)["weightSummaryCard"].waitForExistence(timeout: 5))
        attachScreenshot(app, "weight-vi-ax5")
        app.swipeUp()
        attachScreenshot(app, "weight-vi-ax5-chart")
        let save = app.buttons["weightSave"]
        app.scrollUntilHittable(save, maxSwipes: 12)
        attachScreenshot(app, "weight-vi-ax5-entry")
    }
}
```

Trong `UITests/PregnancyTodayUITests.swift`, thay:
```swift
    /// Spec §4.5: chips change the week (scrolled into view), ✕ goes back to Today.
```
bằng:
```swift
    /// Phase 5 spec §3.4: "Weight" and the weight card open the Weight screen.
    @MainActor
    func testWeightShortcutAndCardOpenTheWeightScreen() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        let shortcut = app.buttons["shortcutWeight"]
        XCTAssertTrue(shortcut.waitForExistence(timeout: 10))
        XCTAssertEqual(shortcut.label, "Weight")
        app.scrollUntilHittable(shortcut)
        shortcut.tap()
        XCTAssertTrue(app.descendants(matching: .any)["weightSetupCard"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()

        let card = app.buttons["weightCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(card.label.contains("Log weight"), card.label) // nothing logged yet
        app.scrollUntilHittable(card)
        card.tap()
        XCTAssertTrue(app.descendants(matching: .any)["weightSetupCard"].waitForExistence(timeout: 5))
    }

    /// Spec §4.5: chips change the week (scrolled into view), ✕ goes back to Today.
```

Trong `UITests/ProfileUITests.swift`, thay:
```swift
    @MainActor
    func testNotNowKeepsPregnancyMode() {
```
bằng:
```swift
    /// Phase 5 spec §3.5: pre-pregnancy weight and height are edited from Profile.
    @MainActor
    func testMaternalRowEditsWeightAndHeight() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        app.openTab(.profile)
        let row = app.buttons["profileMaternal"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertTrue(row.label.contains("Not set"), row.label)
        app.scrollUntilHittable(row)
        row.tap()
        let weight = app.textFields["weightSetupPreWeight"]
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        weight.tap()
        weight.typeText("52")
        let height = app.textFields["weightSetupHeight"]
        // Near the right edge: the cursor lands after any text already there.
        height.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        height.typeText("150")
        app.buttons["keyboardDone"].tap()
        app.buttons["weightSetupSave"].tap()
        waitForLabel(row, containing: "52.0 kg · 150 cm")

        // A height outside 120–220 cm is refused and the sheet stays open.
        row.tap()
        XCTAssertTrue(height.waitForExistence(timeout: 5))
        height.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        height.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 5) + "99")
        app.buttons["keyboardDone"].tap()
        app.buttons["weightSetupSave"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["weightSetupHeightError"].waitForExistence(timeout: 5))
        app.buttons["maternalCancel"].tap()
        XCTAssertTrue(row.label.contains("150 cm"), row.label)
    }

    @MainActor
    func testNotNowKeepsPregnancyMode() {
```

Trong `UITests/PregnancyScreenshotTests.swift`, thay:
```swift
    /// Spec §5: Dynamic Type AX5 — nothing cut off.
```
bằng:
```swift
    /// Phase 5: Today's four shortcuts and the weight card with sample weights.
    @MainActor
    func testPregnancyHomeWeightCard() {
        for (language, dark) in UITestVariants.all {
            let suffix = UITestVariants.suffix(language, dark)
            let app = XCUIApplication.launchPinned(
                language: language, dark: dark, dueDate: UITestDates.dueAtWeek38, extraArguments: ["-seedWeights"]
            )
            let card = app.buttons["weightCard"]
            XCTAssertTrue(card.waitForExistence(timeout: 10))
            app.scrollUntilHittable(card)
            attachScreenshot(app, "pregnancy-home-weight-\(suffix)")
            app.terminate()
        }
    }

    /// Spec §5: Dynamic Type AX5 — nothing cut off.
```

- [ ] **Step 9: Commit, push, xác minh CI**

```bash
scripts/test-core.sh
git add App Shared UITests
git commit -F - <<'MSG'
feat(pregnancy): track the mother's weight against the IOM range

A Weight screen (setup with pre-pregnancy weight and optional height,
gain since pre-pregnancy, BMI group and status, a 170 pt chart with the
recommended band, entry with -/+ 0.1 kg, history by week), a Weight
shortcut and "Your weight" card on pregnancy Today, and the pre-pregnancy
weight and height in Profile. -seedWeights adds the design's samples.

CI-Only-Testing: WeightUITests, PregnancyTodayUITests, ProfileUITests, PregnancyScreenshotTests
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`, gồm `WeightUITests` (7 test), `PregnancyTodayUITests.testWeightShortcutAndCardOpenTheWeightScreen`, `ProfileUITests.testMaternalRowEditsWeightAndHeight`, `PregnancyScreenshotTests.testPregnancyHomeWeightCard`.

- [ ] **Step 10: Kiểm tra trực quan (so với prototype "Cân nặng" và thẻ cân nặng ở Hôm nay)**

- `weight-vi-light` (tuần 38, dữ liệu mẫu): nút quay lại "‹"; "Cân nặng" 28/700; thẻ trắng: "Đã tăng" 13 xám, "+8,9 kg" 32/700 cam đậm `#B8572F`, "so với trước khi mang thai"; bên phải "60,9 kg" 24/700 và "Tuần 30"; dòng "BMI 20,3 · Bình thường" + pill "Trong khoảng" nền `#E3F2F0` chữ `#1F6E67`; biểu đồ cao 170 pt: dải `#F7E3D7` từ 0 lên 11,5–16 kg ở tuần 40, đường cam đậm dày 2,5 nối 6 chấm trắng viền cam (tuần 12–30), mốc trục x 0 · 13 · 27 · 40; chú thích "Khoảng khuyến nghị" (ô cam nhạt) và "Bạn" (vạch cam). So prototype: dải và đường cùng màu, cùng hình dạng (dải giai đoạn 5 theo IOM nên hơi khác hàm `band` của prototype — đúng spec §2.4).
- `weight-history-vi-light`: thẻ "Ghi cân nặng": hàng "Ngày" + ngày hôm nay; hàng nút tròn 42 pt nền `#F4ECE5` "−", số "60,9" 32/700 + "kg" xám, "+"; nút "Lưu" cam đậm full width; "Lịch sử" 16/600; nhóm "Tuần 30" … "Tuần 12", dòng đầu "T6, 7 tháng 8" + "+8,9 kg" nhỏ bên trái, "60,9 kg" đậm bên phải (mọi ngày mẫu là thứ Sáu, đầu tuần thai).
- `weight-setup-vi-light` (tuần 24, chưa có hồ sơ): thẻ "Trước khi bắt đầu" + câu giải thích IOM 2009; hai ô nền `#F4ECE5` "Cân nặng trước mang thai (kg)", "Chiều cao (cm, không bắt buộc)"; nút "Lưu" cam đậm; dưới là thẻ "Ghi cân nặng" (ô số trống "–") và "Chưa ghi cân nặng nào".
- Bản `-dark`: thẻ `#262019`, dải `#45281A`, đường/chấm `#F0A07A`, pill "Trong khoảng" nền `#1E3A37` chữ `#A6E3DB`; chữ đọc rõ.
- Bản `-en-*`: "Weight", "Gained", "+8.9 kg", "since pre-pregnancy", "Week 30", "BMI 20.3 · Normal", "In range", "Recommended range", "You", "Log weight", "History".
- `weight-vi-ax5`, `weight-vi-ax5-chart`, `weight-vi-ax5-entry`: chữ cực lớn không cắt; nút −/+ nằm dưới số kg; biểu đồ vẫn 170 pt.
- `pregnancy-home-weight-vi-light`: 4 lối tắt đều nhau (Đếm cử động cam · "+" Triệu chứng · cân Cân nặng · "38" Tuần thai); thẻ "CÂN NẶNG CỦA MẸ" (nhãn 12/600 hoa xám) ngay dưới thẻ kích thước bé: "60,9 kg · +8,9 kg" 16/600, pill "Trong khoảng" xanh, chevron; không có dòng "Trao đổi với bác sĩ…". Bản `-dark`/`-en-` tương ứng ("YOUR WEIGHT", "In range").
- `pregnancy-home-38-vi-ax5` (ảnh cũ): 4 lối tắt thành 2 hàng × 2, nhãn không bị cắt.

---
### Task 7: Tài liệu — nội dung cho bác sĩ (mục 8), checklist phát hành giai đoạn 5, README; CI toàn bộ

Ghi lại cho bác sĩ duyệt: ngưỡng IOM 2009, cách chia theo tuần, câu hỏi ngưỡng BMI châu Á, câu chữ trạng thái và thẻ an toàn, tên triệu chứng/tâm trạng/lượng kinh (spec §7). Checklist phát hành: schema CloudKit mới (spec §8), quyền riêng tư, ảnh chụp, kiểm thử thủ công. README: chỗ code và cờ `-seedWeights`. Commit cuối **không** có dòng `CI-Only-Testing:` → CI chạy toàn bộ UI test.

**Files:**
- Modify: `docs/content-review-for-doctor.md`, `docs/release-checklist.md`, `README.md`

**Interfaces:**
- Consumes: các khóa chuỗi của Task 4–6, `WeightGuidance`/`BMICategory` (Task 2), tên ảnh chụp của Task 4–6.
- Produces: không có API mới.

- [ ] **Step 1: Mục 8 cho bác sĩ**

Thêm vào cuối `docs/content-review-for-doctor.md`:
```markdown

## 8. Ghi triệu chứng & cân nặng mẹ (giai đoạn 5)

Chuỗi trong `Shared/Localizable.xcstrings`; xem câu chữ thật trên ảnh `weight-*`, `pregnancy-home-weight-*`,
`symptoms-sheet-*`, `symptoms-safety-en`, `week-warnings-en`, `day-log-*` trong `ci-artifacts/screenshots/`.
Ngưỡng nằm trong `Packages/KickCore/Sources/KickCore/WeightGuidance.swift` (có test `WeightGuidanceTests`).

**Ngưỡng tăng cân (IOM 2009, thai đơn) theo BMI trước mang thai** — BMI = kg / m², làm tròn 1 chữ số thập phân:

| Nhóm (`BMICategory`) | BMI | Tổng tăng tới tuần 40 |
|---|---|---|
| Thiếu cân (`under`) | < 18,5 | 12,5–18 kg |
| Bình thường (`normal`) | 18,5–24,9 | 11,5–16 kg |
| Thừa cân (`over`) | 25,0–29,9 | 7–11,5 kg |
| Béo phì (`obese`) | ≥ 30,0 | 5–9 kg |

Cách chia theo tuần (mọi nhóm): tuần 0–13 tăng tuyến tính từ 0 tới 0,5–2,0 kg; tuần 13–40 tuyến tính từ
0,5 / 2,0 kg tới cận dưới / cận trên của nhóm; sau tuần 40 giữ giá trị tuần 40. Ví dụ BMI bình thường ở tuần 24:
4,98–7,70 kg. Trạng thái: "Trong khoảng" khi mức tăng nằm trong dải của tuần đó, ngoài ra "Thấp hơn khoảng" /
"Cao hơn khoảng" (màu trung tính, không đỏ) kèm "Trao đổi với bác sĩ ở lần khám tới". Không có chiều cao → không
hiện nhóm, dải hay trạng thái.

| Khóa | Nội dung (vi) cần duyệt |
|---|---|
| `weight.status.inRange`, `weight.status.below`, `weight.status.above` | "Trong khoảng" / "Thấp hơn khoảng" / "Cao hơn khoảng" |
| `weight.status.talk` | "Trao đổi với bác sĩ ở lần khám tới" (chỉ khi ngoài khoảng) |
| `weight.setup.body`, `weight.noHeight` | Giải thích dải IOM 2009 và việc chiều cao không bắt buộc |
| `weight.category.*` | "Thiếu cân / Bình thường / Thừa cân / Béo phì" (tên nhóm BMI hiển thị cho mẹ) |
| `symptom.safety.title` | "Khi nào cần đi khám ngay" (cùng câu với `week.warnings` đã có) |
| `symptom.safety.contractions` | "Đi khám ngay nếu cơn gò đều đặn hoặc đau trước tuần 37, hoặc ra nước, ra máu." |
| `symptom.safety.swelling` | "Đi khám ngay nếu mặt hoặc tay phù đột ngột kèm đau đầu, nhìn mờ hoặc đau vùng thượng vị." |
| `symptom.safety.note`, `symptom.safety.action` | "Luna Mom không chẩn đoán. Khi không chắc, hãy gọi bác sĩ." / "Xem dấu hiệu cần đi khám" (mở Chi tiết tuần tại mục cảnh báo đã duyệt) |
| `symptom.flow.*` | Lượng kinh: Không / Ít / Vừa / Nhiều |
| `symptom.mood.*` | Tâm trạng: Vui vẻ / Bình thường / Nhạy cảm / Lo âu / Mệt mỏi |
| `symptom.kind.*` | Mong con: Đau bụng / Đau đầu / Căng ngực / Nổi mụn / Đầy hơi / Thèm ăn. Mang thai: Buồn nôn / Ợ nóng / Phù chân / Đau lưng / Chuột rút / Khó ngủ / Cơn gò |

29. [ ] **Ngưỡng BMI cho người châu Á:** app đang dùng ngưỡng chuẩn WHO/IOM (thừa cân ≥ 25, béo phì ≥ 30). WHO
        (2004) gợi ý cho người châu Á mức hành động thấp hơn (thừa cân ≥ 23, béo phì ≥ 27,5). Bác sĩ chọn: giữ ngưỡng
        chuẩn, hay đổi sang ngưỡng châu Á (và khi đó dùng dải IOM của nhóm nào)? Đổi chỉ là sửa hằng số trong
        `BMICategory.init(bmi:)` + test, **không** đổi dữ liệu đã lưu (BMI tính lại từ cân nặng và chiều cao).
30. [ ] Xác nhận dải IOM 2009 và cách chia theo tuần ở trên (đặc biệt 0,5–2,0 kg ở tuần 13 cho mọi nhóm), và việc
        không áp dụng cho song thai.
31. [ ] Duyệt (hoặc sửa) câu chữ thẻ an toàn "Cơn gò" / "Phù chân" và việc thẻ chỉ nhắc đi khám, không chẩn đoán,
        không đếm cơn gò.
32. [ ] Duyệt (hoặc sửa) tên lượng kinh, tâm trạng, triệu chứng (vi + en) và các câu trạng thái cân nặng.
```

- [ ] **Step 2: Checklist phát hành**

Thêm vào cuối `docs/release-checklist.md`:
```markdown

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
```

- [ ] **Step 3: README**

Trong `README.md`, thay:
```markdown
  `-seedOverdueSession` mở một lượt đếm đã quá 2 giờ. Chỉ có hiệu lực trong bản Debug và cùng `-uiTesting`
  (khi đó animation cũng tắt để ảnh chụp ổn định).
```
bằng:
```markdown
  `-seedOverdueSession` mở một lượt đếm đã quá 2 giờ, `-seedWeights` ghi cân trước mang thai 52 kg, chiều cao
  160 cm và cân nặng mẫu các tuần 12–30 (`WeightSeed`, cần `-seedDueDate`). Chỉ có hiệu lực trong bản Debug và
  cùng `-uiTesting` (khi đó animation cũng tắt để ảnh chụp ổn định).
```

Thêm vào cuối `README.md`:
```markdown

## Triệu chứng & cân nặng (giai đoạn 5)
- Lượng kinh / tâm trạng / triệu chứng: `KickCore/SymptomKinds.swift` (lưu trong `CycleLog` dạng raw tiếng Anh,
  giữ giá trị lạ), sheet Mong con `App/Cycle/CycleDayLogSheet.swift`, màn Mang thai `App/Symptoms/`.
- Cân nặng mẹ: `KickCore/Weight*.swift` + `MaternalProfile.swift` (ngưỡng IOM 2009 trong `WeightGuidance.swift`,
  chờ bác sĩ duyệt — `docs/content-review-for-doctor.md` mục 8), màn `App/Weight/`, lưu `WeightEntry` (iCloud).
```

- [ ] **Step 4: Commit, push, CI toàn bộ**

Commit này **không** có dòng `CI-Only-Testing:` → `scripts/ci.sh` chạy mọi lớp UI test (kiểm tra cả các lớp không thuộc task nào, ví dụ `KickCounterUITests`, `ScreenshotTests`, `HistoryUITests`, `KicksUITests`, `OnboardingUITests`, `NavigationUITests`).
```bash
scripts/test-core.sh
git add docs README.md
git commit -F - <<'MSG'
docs: phase 5 doctor review, release checklist and README

The IOM 2009 thresholds and the Asian BMI cut-off question, the status
and safety card wording and the symptom names for the doctor; the new
CloudKit fields and record type, privacy and manual tests for release.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`; log có `==> UI tests: full suite`.

- [ ] **Step 5: Bàn giao**

Không tự chạy TestFlight: báo người dùng có thể chạy `gh workflow run testflight.yml --ref feat/phase5-symptoms-weight` rồi kiểm theo "Kiểm thử thủ công" ở trên. Sau đó dùng `superpowers:finishing-a-development-branch` để mở PR `feat/phase5-symptoms-weight` → `main` (chạy `scripts/test-core.sh` trước khi push, như pre-push hook).

---
## Quyết định làm rõ spec

| Điểm chưa rõ trong spec | Quyết định |
|---|---|
| §2.1 giá trị lượng kinh `none` | Case Swift là `MenstrualFlow.noFlow` với raw `"none"`: một case tên `none` làm mọi so sánh `MenstrualFlow?` mơ hồ với `Optional.none`. Dữ liệu lưu vẫn đúng `none \| light \| medium \| heavy`. |
| §2.1 "`unknownMoodsRaw` / `unknownSymptomsRaw` / flow raw lạ: giữ nguyên" | Hai danh sách giá trị lạ nằm trong `CycleLogRecord` (đọc từ raw, ghi lại cùng giá trị đã biết, đứng sau chúng). Lượng kinh lạ giữ như LH/dịch nhầy: `CycleLog.apply` chỉ ghi `flowRaw` khi bản ghi thật sự đổi lượng kinh. Danh sách lạ khác rỗng tính là "có log" (không bao giờ bị xóa ngầm); lượng kinh lạ thì không (như LH lạ). |
| §2.1 gộp trùng | Tâm trạng/triệu chứng: hợp theo thứ tự enum; giá trị lạ: hợp theo thứ tự gặp (nhóm xếp theo `id.uuidString`); lượng kinh: mức nặng nhất (`MenstrualFlow: Comparable`); trường cũ giữ quy tắc phase 3. |
| §2.1 "UI chỉ hiện mục của chế độ hiện tại, dữ liệu mục kia vẫn giữ" | Cả hai sheet bắt đầu từ log đã lưu và chỉ thay triệu chứng của chế độ mình (`setSymptoms(_:for:)`); tóm tắt chỉ liệt kê triệu chứng của chế độ đang xem. |
| §2.2 `WeightRepository.save(_:)` | Thành `save(_:today:)` (cần "hôm nay" để chặn ngày tương lai, như `CycleRepository.saveLog(_:today:)`). Lưu ngày đã có → cập nhật bản ghi đó (giữ `id`); `entries()` cũ → mới. |
| §2.3 giá trị hồ sơ hỏng | Đọc ra ngoài 30–200 kg / 120–220 cm (hoặc 0) = chưa đặt; lưu làm tròn 0,1 và từ chối trước khi ghi bất cứ gì. |
| §2.4 BMI ở biên (24,96…) | BMI làm tròn 1 chữ số thập phân **rồi** mới xếp nhóm, để số hiển thị và nhóm khớp nhau (63,9 kg / 160 cm → "BMI 25,0 · Thừa cân"). |
| §2.4 / §3.3 "pill trạng thái tuần hiện tại" | Trạng thái của **lần cân mới nhất**, so với dải ở đúng tuần (kể cả ngày lẻ, 24w3d = 24,43) của lần cân đó — không so cân cũ với tuần hôm nay. Thẻ Hôm nay dùng cùng điểm đó. |
| §2.4 tuần < 0 hoặc > 40 | < 0 → dải 0; > 40 → giữ tổng tuần 40. Trục x biểu đồ kéo dài quá 40 nếu có lần cân sau tuần 40. |
| §3.1 vị trí phần "Kỳ kinh" của sheet | Giữ ở đầu sheet (nút bắt đầu/kết thúc kỳ kinh có sẵn), sau đó mới theo thứ tự spec. Chip dịch nhầy cũng chuyển sang `FlowLayout` + kiểu chip mới (`surface` khi chưa chọn) để AX5 không cắt và đồng bộ kiểu. |
| §3.1 nội dung tóm tắt | Lượng kinh · tâm trạng · triệu chứng · nhiệt độ, rồi các tín hiệu cũ (LH · dịch nhầy · "Ghi chú") để không mất thông tin phase 3; lượng kinh hiện "Lượng kinh: Ít" (một chữ "Không" đứng một mình khó hiểu). Câu mời khi chưa ghi đổi thành "Ghi tâm trạng, triệu chứng, lượng kinh" (prototype). |
| §3.2 ngày nào hiện ở màn Triệu chứng | Log trong khoảng kỳ kinh cuối…hôm nay có tâm trạng, triệu chứng Mang thai hoặc ghi chú. "Vuốt để xóa" xóa đúng những gì màn này hiện (tâm trạng, triệu chứng Mang thai, ghi chú); ngày không còn gì khác thì mất hẳn. |
| §3.2 "Xem dấu hiệu cần đi khám" | Lưu sheet trước (lựa chọn không mất), đóng sheet rồi mở Chi tiết tuần (tuần hiện tại, giới hạn 4–42) nhảy thẳng tới thẻ cảnh báo (không cuộn có animation). Lưu lỗi → sheet ở lại với alert. |
| §3.2 câu chữ thẻ an toàn | Câu cho "Cơn gò" và câu cho "Phù chân" chỉ hiện khi chọn triệu chứng đó, kèm câu cố định "không chẩn đoán". Tiêu đề trùng chữ `week.warnings` nhưng có khóa riêng `symptom.safety.title` để bác sĩ duyệt cùng nhóm. |
| §3.3 giá trị mặc định ô kg | Cân của ngày đang chọn, nếu không thì lần cân mới nhất, rồi cân trước mang thai; không có gì → ô trống ("–"), nút −/+ bắt đầu từ 60 kg. Bàn phím số có nút "Xong" (`keyboardDone`). |
| §3.3 chưa có cân trước / chưa có chiều cao | Chưa có cân trước: thẻ thiết lập + thẻ nhập + danh sách kg (không tóm tắt, không biểu đồ). Có cân trước, chưa có chiều cao: tóm tắt mức tăng + biểu đồ không dải + gợi ý "Thêm chiều cao trong Cá nhân…", không nhóm BMI, không pill. |
| §3.3 cân ngoài thai kỳ | Lần cân có ngày trước kỳ kinh cuối (chỉ xảy ra khi đổi ngày dự sinh sau đó) nằm trong nhóm "Ngoài thai kỳ này" ở cuối danh sách, không vẽ lên biểu đồ. |
| §3.3 "Chưa có ngày thai kỳ" | Màn Cân nặng/Triệu chứng hiện thẻ mời nhập ngày (dùng lại chuỗi `pregnancy.empty.*`, mở `PregnancyDateSheet`). Thực tế chỉ gặp khi xóa ngày thai kỳ lúc màn đang mở, vì lối tắt chỉ có khi đã có ngày. |
| §3.3 nút "Lưu" `preg` | `.filled(.pregStrong)`: chữ trắng trên `preg` (#C9673E) chỉ 3,82:1 — quy tắc AA của giai đoạn 4. |
| §3.4 lối tắt | 4 cột đều nhau (lưới 4 cột của prototype), mỗi nút `maxWidth: .infinity`; cỡ chữ trợ năng → lưới 2 × 2. Biểu tượng: "+" mảnh (Triệu chứng), SF Symbol `scalemass` (Cân nặng). |
| §3.4 vị trí thẻ cân nặng | Ngay sau thẻ kích thước bé; khi nội dung tuần đang chờ duyệt hoặc không có, vẫn hiện ở vị trí tương ứng. |
| §3.5 sheet hồ sơ | Dùng chung form với thẻ thiết lập (`MaternalProfileForm`); ở Cá nhân được để trống cả hai (xóa), ở thẻ thiết lập bắt buộc cân trước mang thai. |
| §4 `WeightCoordinator` "re-check sau await" | Store đồng bộ, không có nhắc nhở hay quyền → ghi/xóa/hồ sơ là hàm đồng bộ (không có `await` nào để kiểm tra lại); `load()` vẫn `async` và dùng chung một task như các coordinator khác; lỗi store vào `failure` (alert), lỗi kiểm tra chỉ trả về. |
| §4 `-seedWeights` | Mỗi mẫu `SEED_W` đặt vào ngày đầu của tuần đó (kỳ kinh cuối + 7·tuần), bỏ ngày sau hôm nay (đồng hồ ghim); cần `-seedDueDate`. Ảnh chụp dùng tuần 38 để đủ 6 mẫu; UI test tuần 24 có 4 mẫu. |
| §4 `-seedCycles` mở rộng | `fertile`: hôm qua "Bình thường" + "Đầy hơi" (hôm nay để trống tâm trạng cho UI test ghi). `period`: hôm qua "Nhiều" + "Mệt mỏi" + "Đau bụng", hôm nay "Vừa". |
| §6 ảnh chụp | Màn mới (Triệu chứng, sheet Mang thai, Cân nặng, thẻ Hôm nay, thiết lập) vi/en × sáng/tối; AX5 cho Cân nặng, Triệu chứng và sheet Mong con; ảnh tóm tắt Hôm nay/Lịch chỉ bản en sáng (màn cũ). |
| §6 UI test trên CI | Mỗi task giới hạn lớp UI test bằng `CI-Only-Testing:`; Task 7 chạy toàn bộ. |

## Spec coverage (self-review)

| Spec | Task |
|---|---|
| §1 Triệu chứng + tâm trạng + lượng kinh (Mong con), tâm trạng + triệu chứng (Mang thai) | 1 (dữ liệu), 3 (lưu), 4 (Mong con), 5 (Mang thai) |
| §1 Cân nặng mẹ, dải IOM theo BMI trước mang thai, không chiều cao → không dải | 2, 3, 6 |
| §1 Màn "Triệu chứng" theo tuần thai; thẻ nhắc "Cơn gò"/"Phù chân" | 5 |
| §1 Giữ nguyên hành vi phase 3/4, id accessibility | Mọi task (test cũ chạy trong trailer; Task 7 chạy toàn bộ); id giữ liệt kê ở Task 4–5 |
| §2.1 `CycleLog` thêm `flowRaw`/`moodsRaw`/`symptomsRaw`; `CycleLogRecord` flow/moods/symptoms/`Symptom.mode`; giá trị lạ giữ nguyên | 1, 3 |
| §2.1 Log rỗng = xóa; gộp trùng hợp/nặng hơn; lượng kinh không tạo kỳ kinh; Mang thai dùng chung `CycleStore` | 1 (`isEmpty`, `mergingDuplicates`, `loggingFlowNeverStartsAPeriod`), 3 (`aLogWithOnlyAMoodIsKept…`), 5 |
| §2.2 `WeightEntry`, `WeightRecord`, `WeightRepository`, `WeightRules` (ngày, tương lai, 30–200, 0,1, một/ngày, gộp trùng) | 2, 3 |
| §2.3 `MaternalProfile` (khóa, khoảng) | 2, 6 (form + Cá nhân) |
| §2.4 BMI, 4 nhóm, tổng tuần 40, tuần 0–13, 13–40, sau 40, `status` | 2 (`WeightGuidanceTests`) |
| §3.1 Sheet Mong con: thứ tự, chip chọn 1/nhiều, kiểu chip, `.isSelected`; tóm tắt Hôm nay + Lịch một dòng + VoiceOver đầy đủ | 4 |
| §3.2 Màn Triệu chứng: thẻ hôm nay, nhóm theo tuần, sửa, xóa có xác nhận; sheet; thẻ an toàn + mở Chi tiết tuần tại cảnh báo; ⚠ + VoiceOver | 5 |
| §3.3 Màn Cân nặng: thiết lập, tóm tắt 32/700, BMI, pill, biểu đồ 170 (dải `AreaMark`, đường 2,5 pt, VoiceOver từng điểm), nhập (ngày, ±0,1, "56,2"/"56.2", Lưu), danh sách, vuốt xóa, trạng thái trống | 6 |
| §3.4 4 lối tắt (AX5 không cắt); thẻ "Cân nặng của mẹ" + pill + "Trao đổi với bác sĩ…" + "Ghi cân nặng" | 5 (Triệu chứng), 6 (Cân nặng, thẻ) |
| §3.5 Cá nhân: dòng `profileMaternal` mở sheet sửa | 6 |
| §4 Kiến trúc KickCore/KickData/App, `AppEnvironment` + seed, `-seedWeights`, `-seedCycles` mở rộng | 1, 2, 3, 4, 5, 6 |
| §5 Lỗi lưu/đọc → alert, rollback; nhập ngoài khoảng → báo dưới ô + announcement | 3 (rollback), 4 (BBT cũ), 6 (kg, cân trước, chiều cao), 5/6 (alert) |
| §5 AX5 (flow layout), chip trait chọn, biểu đồ có nhãn từng điểm, thẻ an toàn đọc trước nhóm tiếp theo | 4, 5, 6 |
| §5 Animation tôn trọng Reduce Motion + `LunaMotion.isEnabled`; màu chỉ qua token, cặp khai báo | 5 (mờ dần thẻ an toàn), 4 (`phase5PairsAreDeclared`), Global Constraints |
| §6 Test KickCore (raw, gộp, rỗng, `WeightRules`, `WeightGuidance` biên 18,5/25,0/30,0 và tuần 0/13/14/40/42, `MaternalProfile`, `WeightCoordinator`, điều kiện thẻ an toàn) | 1, 2, 4, 5 |
| §6 Test KickData (`CycleLog` trường mới, raw lạ, gộp; `WeightStore` CRUD, rollback, gộp) | 3 |
| §6 UI: Mong con ghi tâm trạng + triệu chứng → tóm tắt Hôm nay + Lịch; "Cơn gò" → thẻ an toàn → Chi tiết tuần; 52 kg/160 cm → 58,0 ở tuần 24 → "Trong khoảng"; bỏ chiều cao → không dải/pill; 4 lối tắt mở đúng màn | 4 (`CycleSymptomsUITests`), 5 (`PregnancySymptomsUITests`, `testSymptomsShortcut…`), 6 (`WeightUITests`, `testWeightShortcutAndCard…`; Đếm cử động/Tuần thai: `testShortcutsOpenKicksAndTheWeek` có sẵn) |
| §6 Ảnh mọi màn mới vi/en × sáng/tối + AX5 Cân nặng và Triệu chứng | 4, 5, 6 (bước "Kiểm tra trực quan") |
| §7 Mục 8 cho bác sĩ (IOM, chia tuần, ngưỡng châu Á, câu trạng thái, thẻ an toàn, tên) | 7 |
| §8 Rủi ro: ngưỡng châu Á là hằng số; schema CloudKit (`CD_flowRaw`, `CD_moodsRaw`, `CD_symptomsRaw`, `CD_WeightEntry`); quyền riêng tư | 2 (hằng số trong `BMICategory`), 7 (checklist, privacy) |
