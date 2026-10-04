# Chế độ "Mong con" (Giai đoạn 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. For UI tasks (8–11), also apply the `ui-ux-pro-max` skill for visual polish — but do not change behaviour, accessibility identifiers, or strings defined here.

**Goal:** Thêm chế độ **Mong con** cho Luna Mom: ghi kỳ kinh, dự đoán kỳ kinh tiếp theo / ngày rụng trứng / cửa sổ thụ thai (điều chỉnh bằng que thử LH, xác nhận bằng nhiệt độ BBT), ghi dấu hiệu cơ thể theo ngày, lịch tháng tô màu, nhắc lúc 9:00, và nút **"Tôi đã có thai"** chuyển sang chế độ mang thai với ngày dự sinh tính từ kỳ kinh cuối.

**Architecture:** Mọi logic nằm trong `KickCore` (Swift thuần, test local): `AppMode` + `CycleSettings` (UserDefaults), bản ghi giá trị `PeriodRecord`/`CycleLogRecord` + `CycleRules` (kiểm tra, gộp trùng, nhập nhiệt độ) + protocol `CycleRepository`, `CyclePredictor`/`CycleForecast` (thuần, nhận `now` + `Calendar`), nhắc chu kỳ (mở rộng `NotificationScheduler`), `CycleCoordinator` (nơi **duy nhất** ghi dữ liệu chu kỳ, đặt/hủy nhắc chu kỳ và chuyển chế độ), dữ liệu mẫu `CycleSeedScenario` và bố cục tháng `CycleCalendarGrid`. `KickData` thêm model SwiftData `PeriodEntry`, `CycleLog` + `CycleStore` (lưu trữ, kiểm tra bằng `CycleRules`, gộp bản trùng từ iCloud, rollback). App SwiftUI là lớp mỏng: `RootView` đổi bộ tab theo `appMode` (Chu kỳ · Lịch · Cài đặt **hoặc** Thai kỳ · Đếm · Lịch sử · Cài đặt).

**Máy dev không có Xcode.** Chỉ `KickCore` chạy được local qua `scripts/test-core.sh`. `KickData`, app, UI test và ảnh chụp chỉ được xác minh trên GitHub Actions: commit → `git push` → `scripts/ci-wait.sh`.

**Tech Stack:** Swift 6, SwiftUI, SwiftData (+ CloudKit private DB), UserNotifications, Swift Testing, XCTest (UI), XcodeGen, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-03-trying-to-conceive-design.md` (yêu cầu — làm đúng spec). Plan giai đoạn 2 tham khảo: `docs/superpowers/plans/2026-10-02-pregnancy-journey.md`.

## Global Constraints

- iOS deployment target `17.0`; package platforms `.iOS(.v17), .macOS(.v14)` (macOS chỉ để chạy `swift test`); Swift language mode 6. Không server, không SDK bên thứ ba, không HealthKit, không thu thập dữ liệu.
- Làm việc trên nhánh `feat/phase3-trying-to-conceive` (đã có, đang checkout). **Không bao giờ** đổi tài khoản/đăng nhập `gh` (`gh auth …`). Mọi commit message kết thúc bằng một dòng trống rồi `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (dùng `git commit -F - <<'MSG' … MSG` như trong từng task).
- **Máy dev không có Xcode.** Local chỉ chạy được `scripts/test-core.sh` (cũng là pre-push hook `.githooks/pre-push`). `KickData`, build app, UI test, ảnh chụp: chỉ trên CI qua `git push` + `scripts/ci-wait.sh`.
- **`KickCore` không được import SwiftData.** Mọi `@Model` nằm trong `KickData`.
- Model SwiftData tương thích CloudKit: mọi thuộc tính có default hoặc optional, **không** `@Attribute(.unique)`, không quan hệ bắt buộc. `PeriodEntry` và `CycleLog` được thêm vào `KickPersistence.schema` (thay đổi bổ sung, migrate nhẹ). Tên record CloudKit: `CD_PeriodEntry`, `CD_CycleLog`.
- Mọi chuỗi giao diện đi qua `L10n` (`Shared/L10n.swift`) và có trong `Shared/Localizable.xcstrings` đủ `en` + `vi`, thêm bằng `scripts/add-strings.py` (đọc JSON `{"key": ["English", "Tiếng Việt"]}` từ stdin, kiểm tra format specifier giống nhau). Không dùng `Text("… \(x)")` với chuỗi nội suy (Xcode sẽ trích thành khóa mới) — dùng `Text(L10n.…)`.
- Launch argument chỉ cho test: **chỉ** có hiệu lực khi có `-uiTesting` và chỉ được đọc trong `#if DEBUG` (như `AppEnvironment`/`AppClock` hiện nay). Mới: `-seedCycles <empty|period|fertile|late|irregular>` → ghi `appMode = tryingToConceive` và dữ liệu mẫu `CycleSeedScenario` tương đối với đồng hồ `-fixedNow`. Giữ: `-uiTesting`, `-skipOnboarding`, `-forceDarkMode`, `-fixedNow`, `-seedDueDate`.
- `SettingsKey.appMode` (`"tryingToConceive"` | `"pregnant"`); thiếu hoặc giá trị lạ → `pregnant` (người dùng cũ). `typicalCycleLength` 21–45 (mặc định 28), `typicalPeriodLength` 2–10 (mặc định 5), `cycleRemindersEnabled` (thiếu → bật). Nhắc chỉ thực sự được đặt khi đã có quyền thông báo.
- Dự đoán (spec §4.1, dùng nguyên văn): trung bình tối đa **6** chu kỳ hoàn chỉnh gần nhất **có độ dài 21–45 ngày** (không có → `typicalCycleLength`); `nextPeriodStart` = đầu kỳ hiện tại + trung bình; rụng trứng = `nextPeriodStart − 14`; LH dương tính đầu tiên trong chu kỳ hiện tại → ngày đó + 1; cửa sổ = rụng trứng − 5 … + 1; `.low` khi < 2 chu kỳ hợp lệ hoặc (≥ 3 chu kỳ hợp lệ và (độ lệch chuẩn > 4 hoặc max − min > 7)), khi đó (và chưa có LH/BBT) nới `min(3, (max − min) / 2)` ngày mỗi bên; BBT: 3 ngày liên tiếp ≥ mức cao nhất của 6 lần đo trước + 0,2 °C → rụng trứng đã xác nhận = ngày trước lần tăng; trễ kinh = số ngày quá `nextPeriodStart`; cảnh báo bất thường khi chu kỳ hoàn chỉnh gần nhất < 21 hoặc > 45 ngày, hoặc ≥ 3 chu kỳ hợp lệ chênh > 7 ngày.
- Mọi phép tính ngày dùng `Calendar` (`startOfDay`, `date(byAdding: .day…)`, `dateComponents([.day]…)`) — không cộng giây — để an toàn qua DST và đầu/cuối tháng.
- Nhắc chu kỳ: thông báo cục bộ id `cycle-fertile` (9:00, 2 ngày trước ngày đầu cửa sổ thụ thai), `cycle-period` (9:00, 1 ngày trước kỳ kinh dự kiến), `cycle-late` (9:00, ngày `nextPeriodStart + 3` — một lần). Thời điểm đã qua thì không đặt. `CycleCoordinator` là nơi **duy nhất** đặt/hủy nhắc chu kỳ; hủy khi tắt nhắc hoặc chuyển sang chế độ mang thai. `CycleStore` chỉ lưu trữ.
- Bài học giai đoạn 1–2 (bắt buộc): coordinator kiểm tra lại trạng thái sau **mỗi** `await` (bộ đếm `reminderGeneration`); `load()` **không bao giờ** xin quyền thông báo; test có cổng chặn (`hold…`) phải an toàn khi treo: `defer { center.release…() }` ngay sau `async let`, chờ bằng `waitUntil` có giới hạn; store rollback khi lưu lỗi (seam `saveContext`); bản trùng do iCloud được store gộp khi đọc; UI test với `List`/`Form` phải cuộn tới phần tử dưới màn hình trước khi assert (`scrollUntilHittable`).
- Lỗi kiểm tra dữ liệu (`futureDate`, `endBeforeStart`, `overlapsExistingPeriod`, `invalidTemperature`) chỉ được **trả về** cho màn hình gọi; `CycleCoordinator.failure` chỉ giữ lỗi lưu/đọc (`saveFailed`, `loadFailed`).
- Thứ tự tab — chế độ Mang thai: 0 Thai kỳ · 1 Đếm · 2 Lịch sử · 3 Cài đặt (không đổi). Chế độ Mong con: 0 Chu kỳ · 1 Lịch · 2 Cài đặt (Task 8 có Chu kỳ · Cài đặt; Task 9 chèn Lịch).
- Màu: kỳ kinh = `AccentColor` (hồng; dự đoán: nhạt + viền đứt), cửa sổ thụ thai = `Color(.systemGreen)` dịu, ngày rụng trứng + ngày trước = `Color(.systemPurple)`; không chỉ dựa vào màu: ký hiệu `drop.fill`/`drop`/`leaf.fill`/`sparkles` + nhãn VoiceOver từng ngày. Thẻ cảnh báo: cam như `OverdueBanner` (`Color.orange`, nền `Color.orange.opacity(0.12)`). Dynamic Type: chỉ font ngữ nghĩa / `@ScaledMetric`.
- Ngày hiển thị trên thẻ chu kỳ: `Formatting.cycleDate` = `.dateTime.day(.twoDigits).month(.twoDigits)` (vi "04/10", en "10/04"); VoiceOver: `Formatting.spokenDay` ("4 tháng 10" / "October 4").
- `KickCoordinator`, `AppointmentCoordinator` giữ nguyên. Đổi chế độ không xóa dữ liệu nào (thai kỳ, lịch hẹn, nhắc lịch hẹn, chu kỳ).
- Accessibility identifiers cố định (ngoài các id giai đoạn 1–2): `cycleStatusCard`, `cycleNextPeriodCard`, `cycleFertileCard`, `cycleLateCard`, `cycleIrregularCard`, `cycleLongPeriodCard`, `cycleAddPeriodButton`, `cyclePeriodButton`, `cycleLogTodayButton`, `lastPeriodPicker`, `lastPeriodSave`, `dayLogLHPicker`, `dayLogBBTField`, `dayLogBBTError`, `dayLogMucusPicker`, `dayLogNoteField`, `dayLogSave`, `dayLogPeriodInfo`, `dayLogStartPeriod`, `dayLogEndPeriod`, `dayLogDeletePeriod`, `calendarMonthTitle`, `calendarPrevious`, `calendarNext`, `calendarDay`, `calendarLegend`, `imPregnantButton`, `imPregnantSave`, `onboardingModeTTC`, `onboardingModePregnant`, `onboardingSaveCycle`, `onboardingSkipCycle`, `onboardingCycleLength`, `onboardingPeriodLength`, `settingsModePicker`, `settingsCycleLength`, `settingsPeriodLength`, `settingsCycleReminders`, `medicalTTC`.
- Ngoài phạm vi (YAGNI, spec §1): HealthKit, chia sẻ với bạn đời, ghi quan hệ, nhắc vitamin, biểu đồ BBT, máy học, dùng như biện pháp tránh thai. Không chạy TestFlight (người dùng tự kích hoạt).

## Quy trình xác minh

- **Local** (mọi task có code `KickCore`): `scripts/test-core.sh` (có thể thêm `--filter <TênSuite>`). Không push khi local còn đỏ (pre-push hook cũng chặn).
- **CI** (điều kiện hoàn thành của **mọi** task): commit, `git push`, rồi `scripts/ci-wait.sh`. Script chờ run CI của HEAD (CI đã tự boot simulator trước khi test), in log lỗi nếu fail và tải artifact về `ci-artifacts/` (ảnh ở `ci-artifacts/screenshots/`, tên file bắt đầu bằng tên ảnh trong test, ví dụ `cycle-home-fertile-vi-light_0_<UUID>.png`).
- **Flake đã biết:** UI test thỉnh thoảng timeout ở `waitForExistence` (hay gặp nhất: `KickCounterUITests.testCancelResetsCounter`). Nếu CI đỏ **chỉ** vì kiểu lỗi đó ở một test không liên quan tới thay đổi của task: chạy lại **một lần** phần fail rồi theo dõi chính run đó:
  ```bash
  RUN_ID="$(gh run list --workflow ci.yml --commit "$(git rev-parse HEAD)" --limit 1 --json databaseId -q '.[0].databaseId')"
  gh run rerun "$RUN_ID" --failed
  gh run watch "$RUN_ID" --exit-status --interval 20 > /dev/null && echo "CI PASSED"
  rm -rf ci-artifacts && gh run download "$RUN_ID" --dir ci-artifacts
  ```
  Đỏ lần hai (hoặc lỗi ở test của task) → không phải flake: dùng `superpowers:systematic-debugging`, sửa, commit, push lại.
- Task có danh sách kiểm tra trực quan: mở từng PNG liên quan bằng **Read tool** và đối chiếu từng mục. Sai một mục là chưa xong.
- Không đánh dấu task hoàn thành khi CI còn đỏ.

## File Structure

```
kick-counter/
├── Packages/KickCore/
│   ├── Sources/KickCore/
│   │   ├── Settings.swift                 # T1: khóa appMode, typicalCycleLength, typicalPeriodLength, cycleRemindersEnabled
│   │   ├── AppMode.swift                  # T1 (mới)
│   │   ├── CycleSettings.swift            # T1 (mới)
│   │   ├── CycleRecords.swift             # T2 (mới): PeriodRecord, LHResult, CervicalMucus, CycleLogRecord,
│   │   │                                  #   CycleRepositoryError, CycleRepository, CycleRules, TemperatureEntry
│   │   ├── CyclePredictor.swift           # T3 (mới): CycleForecast, CycleDayStatus, CycleConfidence, OvulationSource
│   │   ├── CycleReminders.swift           # T4 (mới): CycleReminderKind, CycleReminderTexts, NotificationScheduler+cycle
│   │   ├── CycleCoordinator.swift         # T5 (mới): CycleFailure, CycleCoordinator
│   │   ├── CycleSeed.swift                # T6 (mới): CycleSeedScenario
│   │   ├── CycleCalendarGrid.swift        # T6 (mới)
│   │   └── UITestLaunchOptions.swift      # T6: -seedCycles
│   └── Tests/KickCoreTests/
│       ├── TestSupport.swift              # T1: makeTestDefaults; T5: FakeCycleRepository
│       ├── AppModeTests.swift             # T1
│       ├── CycleRulesTests.swift          # T2
│       ├── CyclePredictorTests.swift      # T3
│       ├── CycleRemindersTests.swift      # T4
│       ├── CycleCoordinatorTests.swift    # T5
│       ├── CycleSeedTests.swift           # T6 (gồm CycleCalendarGridTests)
│       └── UITestLaunchOptionsTests.swift # T6
├── Packages/KickData/
│   ├── Sources/KickData/{Models,KickPersistence,CycleStore}.swift          # T7
│   └── Tests/KickDataTests/CycleStoreTests.swift                           # T7
├── Shared/{L10n.swift, Localizable.xcstrings}                              # T8–T11
├── App/
│   ├── AppEnvironment.swift, KickCounterApp.swift, RootView.swift, Formatting.swift   # T8 (RootView: T9)
│   ├── Cycle/
│   │   ├── CyclePalette.swift, CycleCards.swift, CycleHomeView.swift       # T8 (CycleHomeView: T10)
│   │   ├── LastPeriodSheet.swift, CycleDayLogSheet.swift                   # T8
│   │   ├── CycleCalendarView.swift                                         # T9
│   │   └── ImPregnantSheet.swift                                           # T10
│   ├── Onboarding/OnboardingView.swift                                     # T11
│   └── Settings/{SettingsView,MedicalInfoView}.swift                       # T11
├── UITests/
│   ├── UITestSupport.swift                # T8: seedCycles, CycleModeTab, scrollUntilHittable, waitForLabel; T9; T11
│   ├── CycleUITests.swift                 # T8–T11 (mới)
│   ├── CycleScreenshotTests.swift         # T8–T11 (mới)
│   ├── KickCounterUITests.swift, ScreenshotTests.swift, PregnancyUITests.swift  # T11: bước chọn chế độ
├── README.md                              # T8: -seedCycles
└── docs/{release-checklist.md, content-review-for-doctor.md}               # T12
```

---
### Task 1: `AppMode` + khóa cài đặt chu kỳ (`CycleSettings`)

**Files:**
- Modify: `Packages/KickCore/Sources/KickCore/Settings.swift` (enum `SettingsKey`)
- Create: `Packages/KickCore/Sources/KickCore/AppMode.swift`, `Packages/KickCore/Sources/KickCore/CycleSettings.swift`
- Modify: `Packages/KickCore/Tests/KickCoreTests/TestSupport.swift` (thêm `makeTestDefaults()` ở cuối file)
- Test: `Packages/KickCore/Tests/KickCoreTests/AppModeTests.swift`

**Interfaces:**
- Consumes: `SettingsKey`, `AppGroup` (đã có).
- Produces:
  - `SettingsKey.appMode = "appMode"`, `SettingsKey.typicalCycleLength`, `SettingsKey.typicalPeriodLength`, `SettingsKey.cycleRemindersEnabled` (giá trị chuỗi = tên).
  - `public enum AppMode: String, Sendable, CaseIterable { case tryingToConceive, pregnant; static func load(from: UserDefaults) -> AppMode; static func save(_: AppMode, to: UserDefaults) }`
  - `public struct CycleSettings: Equatable, Sendable { static let cycleLengthRange = 21...45; static let periodLengthRange = 2...10; static let defaultCycleLength = 28; static let defaultPeriodLength = 5; var typicalCycleLength: Int; var typicalPeriodLength: Int; var remindersEnabled: Bool; init(typicalCycleLength: Int = 28, typicalPeriodLength: Int = 5, remindersEnabled: Bool = true) /* kẹp vào khoảng */; static func load(from: UserDefaults) -> CycleSettings; func save(to: UserDefaults) }`
  - Test helper `func makeTestDefaults() -> UserDefaults` (domain rỗng mới mỗi lần gọi).

- [ ] **Step 1: Viết test trước**

Thêm vào cuối `Packages/KickCore/Tests/KickCoreTests/TestSupport.swift`:
```swift

/// A fresh, empty defaults domain (one per call).
func makeTestDefaults() -> UserDefaults {
    let name = "KickCoreTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}
```

`Packages/KickCore/Tests/KickCoreTests/AppModeTests.swift`:
```swift
import Foundation
import Testing
@testable import KickCore

struct AppModeTests {
    @Test func missingModeMeansPregnant() {
        #expect(AppMode.load(from: makeTestDefaults()) == .pregnant)
    }

    @Test func existingUserWithDueDateStaysPregnant() {
        let defaults = makeTestDefaults()
        defaults.set(date("2027-01-19T12:00:00Z").timeIntervalSince1970, forKey: SettingsKey.dueDate)
        defaults.set(true, forKey: SettingsKey.hasCompletedOnboarding)
        #expect(AppMode.load(from: defaults) == .pregnant)
    }

    @Test func savedModeRoundTrips() {
        let defaults = makeTestDefaults()
        AppMode.save(.tryingToConceive, to: defaults)
        #expect(defaults.string(forKey: SettingsKey.appMode) == "tryingToConceive")
        #expect(AppMode.load(from: defaults) == .tryingToConceive)
        AppMode.save(.pregnant, to: defaults)
        #expect(AppMode.load(from: defaults) == .pregnant)
    }

    @Test func unknownStoredValueFallsBackToPregnant() {
        let defaults = makeTestDefaults()
        defaults.set("planning", forKey: SettingsKey.appMode)
        #expect(AppMode.load(from: defaults) == .pregnant)
    }
}

struct CycleSettingsTests {
    @Test func defaultsAre28DayCycle5DayPeriodRemindersOn() {
        let settings = CycleSettings.load(from: makeTestDefaults())
        #expect(settings == CycleSettings(typicalCycleLength: 28, typicalPeriodLength: 5, remindersEnabled: true))
    }

    @Test func savedSettingsRoundTrip() {
        let defaults = makeTestDefaults()
        CycleSettings(typicalCycleLength: 32, typicalPeriodLength: 4, remindersEnabled: false).save(to: defaults)
        #expect(CycleSettings.load(from: defaults) == CycleSettings(typicalCycleLength: 32, typicalPeriodLength: 4, remindersEnabled: false))
        #expect(defaults.integer(forKey: SettingsKey.typicalCycleLength) == 32)
        #expect(defaults.bool(forKey: SettingsKey.cycleRemindersEnabled) == false)
    }

    @Test func lengthsAreClampedToTheAllowedRanges() {
        #expect(CycleSettings(typicalCycleLength: 14, typicalPeriodLength: 1).typicalCycleLength == 21)
        #expect(CycleSettings(typicalCycleLength: 14, typicalPeriodLength: 1).typicalPeriodLength == 2)
        #expect(CycleSettings(typicalCycleLength: 60, typicalPeriodLength: 12).typicalCycleLength == 45)
        #expect(CycleSettings(typicalCycleLength: 60, typicalPeriodLength: 12).typicalPeriodLength == 10)
    }

    @Test func outOfRangeStoredValuesAreClamped() {
        let defaults = makeTestDefaults()
        defaults.set(90, forKey: SettingsKey.typicalCycleLength)
        defaults.set(0, forKey: SettingsKey.typicalPeriodLength)
        let settings = CycleSettings.load(from: defaults)
        #expect(settings.typicalCycleLength == 45)
        #expect(settings.typicalPeriodLength == 2)
    }
}
```

- [ ] **Step 2: Chạy, xác nhận fail**

Run: `scripts/test-core.sh --filter "AppModeTests|CycleSettingsTests"`
Expected: lỗi biên dịch `cannot find 'AppMode' in scope` / `cannot find 'CycleSettings' in scope`.

- [ ] **Step 3: Viết code**

Trong `Packages/KickCore/Sources/KickCore/Settings.swift`, thay toàn bộ `public enum SettingsKey { … }` bằng:
```swift
public enum SettingsKey {
    public static let reminderEnabled = "reminderEnabled"
    public static let reminderHour = "reminderHour"
    public static let reminderMinute = "reminderMinute"
    /// `timeIntervalSince1970`; 0 means "not set".
    public static let dueDate = "dueDate"
    /// `"dueDate"` or `"lmp"`: which date the mother entered. `dueDate` stays the source of truth.
    public static let pregnancyDateSource = "pregnancyDateSource"
    /// First day of the last period, `timeIntervalSince1970`; 0 means "not set".
    public static let lmpDate = "lmpDate"
    public static let hasCompletedOnboarding = "hasCompletedOnboarding"
    /// `"tryingToConceive"` or `"pregnant"`. Missing means pregnant (everyone before phase 3).
    public static let appMode = "appMode"
    /// Days, 21–45 (default 28): used until enough cycles are logged.
    public static let typicalCycleLength = "typicalCycleLength"
    /// Days, 2–10 (default 5).
    public static let typicalPeriodLength = "typicalPeriodLength"
    /// Fertile-window, period and late-period reminders. Missing means on.
    public static let cycleRemindersEnabled = "cycleRemindersEnabled"
}
```

`Packages/KickCore/Sources/KickCore/AppMode.swift`:
```swift
import Foundation

/// Which half of the app the mother sees: cycle tracking while trying to
/// conceive, or the pregnancy journey (phases 1–2).
public enum AppMode: String, Sendable, CaseIterable {
    case tryingToConceive
    case pregnant

    /// The stored mode. Users from before phase 3 have none stored and stay
    /// pregnant; new users pick one in onboarding before seeing any tab.
    public static func load(from defaults: UserDefaults) -> AppMode {
        defaults.string(forKey: SettingsKey.appMode).flatMap(AppMode.init(rawValue:)) ?? .pregnant
    }

    public static func save(_ mode: AppMode, to defaults: UserDefaults) {
        defaults.set(mode.rawValue, forKey: SettingsKey.appMode)
    }
}
```

`Packages/KickCore/Sources/KickCore/CycleSettings.swift`:
```swift
import Foundation

/// The mother's own cycle numbers, kept in `AppGroup.defaults` (not synced).
public struct CycleSettings: Equatable, Sendable {
    public static let cycleLengthRange = 21...45
    public static let periodLengthRange = 2...10
    public static let defaultCycleLength = 28
    public static let defaultPeriodLength = 5

    public var typicalCycleLength: Int
    public var typicalPeriodLength: Int
    public var remindersEnabled: Bool

    /// Lengths outside the allowed ranges are clamped into them.
    public init(
        typicalCycleLength: Int = CycleSettings.defaultCycleLength,
        typicalPeriodLength: Int = CycleSettings.defaultPeriodLength,
        remindersEnabled: Bool = true
    ) {
        self.typicalCycleLength = Self.clamp(typicalCycleLength, to: Self.cycleLengthRange)
        self.typicalPeriodLength = Self.clamp(typicalPeriodLength, to: Self.periodLengthRange)
        self.remindersEnabled = remindersEnabled
    }

    public static func load(from defaults: UserDefaults) -> CycleSettings {
        CycleSettings(
            typicalCycleLength: defaults.object(forKey: SettingsKey.typicalCycleLength) == nil
                ? defaultCycleLength : defaults.integer(forKey: SettingsKey.typicalCycleLength),
            typicalPeriodLength: defaults.object(forKey: SettingsKey.typicalPeriodLength) == nil
                ? defaultPeriodLength : defaults.integer(forKey: SettingsKey.typicalPeriodLength),
            remindersEnabled: defaults.object(forKey: SettingsKey.cycleRemindersEnabled) == nil
                ? true : defaults.bool(forKey: SettingsKey.cycleRemindersEnabled)
        )
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(typicalCycleLength, forKey: SettingsKey.typicalCycleLength)
        defaults.set(typicalPeriodLength, forKey: SettingsKey.typicalPeriodLength)
        defaults.set(remindersEnabled, forKey: SettingsKey.cycleRemindersEnabled)
    }

    private static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
```

- [ ] **Step 4: Chạy lại, xác nhận pass**

Run: `scripts/test-core.sh --filter "AppModeTests|CycleSettingsTests"` → Expected: `Test run with 8 tests in 2 suites passed`.
Run: `scripts/test-core.sh` → Expected: `Test run with 181 tests in 19 suites passed` (173 test cũ + 8 mới; nếu số test cũ khác 173 thì tổng tăng đúng 8).

- [ ] **Step 5: Commit, push, xác minh CI**

```bash
git add Packages/KickCore
git commit -F - <<'MSG'
feat(core): add app mode and cycle settings

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED` (toàn bộ test cũ vẫn xanh).

---

### Task 2: Bản ghi chu kỳ, `CycleRepository`, `CycleRules` (kiểm tra, gộp trùng, nhập nhiệt độ)

`CycleRules` là nơi duy nhất chứa luật dữ liệu: cả `CycleStore` (KickData, Task 7) lẫn fake trong test (Task 5) đều gọi nó, nên luật được test local ở đây.

**Files:**
- Create: `Packages/KickCore/Sources/KickCore/CycleRecords.swift`
- Test: `Packages/KickCore/Tests/KickCoreTests/CycleRulesTests.swift`

**Interfaces:**
- Consumes: không.
- Produces:
  - `public struct PeriodRecord: Equatable, Sendable, Identifiable { let id: UUID; var startDate: Date; var endDate: Date?; init(id: UUID = UUID(), startDate: Date, endDate: Date? = nil); var isOpen: Bool }`
  - `public enum LHResult: String { case positive, negative }`, `public enum CervicalMucus: String, CaseIterable { case dry, sticky, creamy, eggWhite }`
  - `public struct CycleLogRecord: Equatable, Sendable, Identifiable { let id: UUID; var day: Date; var lh: LHResult?; var bbtCelsius: Double?; var mucus: CervicalMucus?; var note: String; init(id: UUID = UUID(), day: Date, lh: LHResult? = nil, bbtCelsius: Double? = nil, mucus: CervicalMucus? = nil, note: String = ""); var isEmpty: Bool }`
  - `public enum CycleRepositoryError: Error, Equatable, Sendable { case futureDate, endBeforeStart, overlapsExistingPeriod, invalidTemperature, notFound }`
  - `@MainActor public protocol CycleRepository: AnyObject { func periods() throws -> [PeriodRecord]; func logs() throws -> [CycleLogRecord]; func addPeriod(_: PeriodRecord, today: Date) throws; func updatePeriod(_: PeriodRecord, today: Date) throws; func deletePeriod(id: UUID) throws; func saveLog(_: CycleLogRecord, today: Date) throws }`
  - `public enum CycleRules { static let temperatureRange: ClosedRange<Double> = 35.0...38.5; static let longPeriodDays = 10; static func normalized(_: PeriodRecord, calendar:) -> PeriodRecord; static func normalized(_: CycleLogRecord, calendar:) -> CycleLogRecord; static func dayRange(of: PeriodRecord, today: Date, calendar:) -> ClosedRange<Date>; static func validate(_: PeriodRecord, existing: [PeriodRecord], today: Date, calendar:) throws; static func assumedPeriod(startingOn: Date, typicalLength: Int, today: Date, calendar:) -> PeriodRecord; static func lastPeriodRange(now: Date, calendar:) -> ClosedRange<Date>; static func validate(_: CycleLogRecord, today: Date, calendar:) throws; static func mergingDuplicates(_: [PeriodRecord], calendar:) -> (periods: [PeriodRecord], removedIDs: [UUID]); static func mergingDuplicates(_: [CycleLogRecord], calendar:) -> (logs: [CycleLogRecord], removedIDs: [UUID]) }`
  - `public enum TemperatureEntry: Equatable, Sendable { case empty, valid(Double), invalid; init(text: String) }` — nhận "36.5" lẫn "36,5", làm tròn 2 chữ số, ngoài 35,0–38,5 → `.invalid`.

- [ ] **Step 1: Viết test trước**

`Packages/KickCore/Tests/KickCoreTests/CycleRulesTests.swift`:
```swift
import Foundation
import Testing
@testable import KickCore

struct CycleRulesTests {
    let calendar = utcCalendar
    let today = date("2026-10-02T12:00:00Z")

    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00Z") }

    @Test func normalizingMovesDatesToTheStartOfTheDay() {
        let period = CycleRules.normalized(
            PeriodRecord(startDate: date("2026-09-03T18:30:00Z"), endDate: date("2026-09-07T07:00:00Z")), calendar: calendar
        )
        #expect(period.startDate == day("2026-09-03"))
        #expect(period.endDate == day("2026-09-07"))
        let log = CycleRules.normalized(CycleLogRecord(day: date("2026-10-01T22:00:00Z"), note: "  tired \n"), calendar: calendar)
        #expect(log.day == day("2026-10-01"))
        #expect(log.note == "tired")
    }

    @Test func openPeriodCoversUpToTodayAtMostTenDays() {
        let recent = PeriodRecord(startDate: day("2026-09-30"))
        #expect(CycleRules.dayRange(of: recent, today: today, calendar: calendar) == day("2026-09-30")...day("2026-10-02"))
        let long = PeriodRecord(startDate: day("2026-09-10"))
        #expect(CycleRules.dayRange(of: long, today: today, calendar: calendar) == day("2026-09-10")...day("2026-09-19"))
        let closed = PeriodRecord(startDate: day("2026-09-03"), endDate: day("2026-09-07"))
        #expect(CycleRules.dayRange(of: closed, today: today, calendar: calendar) == day("2026-09-03")...day("2026-09-07"))
    }

    @Test func futurePeriodsAreRejected() {
        #expect(throws: CycleRepositoryError.futureDate) {
            try CycleRules.validate(PeriodRecord(startDate: day("2026-10-03")), existing: [], today: today, calendar: calendar)
        }
        #expect(throws: CycleRepositoryError.futureDate) {
            try CycleRules.validate(PeriodRecord(startDate: day("2026-09-30"), endDate: day("2026-10-03")), existing: [], today: today, calendar: calendar)
        }
    }

    @Test func periodStartingTodayIsAllowed() throws {
        try CycleRules.validate(PeriodRecord(startDate: date("2026-10-02T23:00:00Z")), existing: [], today: today, calendar: calendar)
    }

    @Test func endBeforeStartIsRejected() {
        #expect(throws: CycleRepositoryError.endBeforeStart) {
            try CycleRules.validate(PeriodRecord(startDate: day("2026-09-10"), endDate: day("2026-09-08")), existing: [], today: today, calendar: calendar)
        }
    }

    @Test func overlappingPeriodsAreRejected() {
        let existing = [PeriodRecord(startDate: day("2026-09-03"), endDate: day("2026-09-07"))]
        #expect(throws: CycleRepositoryError.overlapsExistingPeriod) {
            try CycleRules.validate(PeriodRecord(startDate: day("2026-09-07")), existing: existing, today: today, calendar: calendar)
        }
        #expect(throws: CycleRepositoryError.overlapsExistingPeriod) {
            try CycleRules.validate(PeriodRecord(startDate: day("2026-09-01"), endDate: day("2026-09-03")), existing: existing, today: today, calendar: calendar)
        }
    }

    @Test func startingWhileAnotherPeriodIsOpenOverlaps() {
        let existing = [PeriodRecord(startDate: day("2026-09-29"))]
        #expect(throws: CycleRepositoryError.overlapsExistingPeriod) {
            try CycleRules.validate(PeriodRecord(startDate: day("2026-10-02")), existing: existing, today: today, calendar: calendar)
        }
    }

    @Test func adjacentPeriodsAndEditingItselfAreAllowed() throws {
        let existing = PeriodRecord(startDate: day("2026-09-03"), endDate: day("2026-09-07"))
        try CycleRules.validate(PeriodRecord(startDate: day("2026-09-08")), existing: [existing], today: today, calendar: calendar)
        var edited = existing
        edited.endDate = day("2026-09-08")
        try CycleRules.validate(edited, existing: [existing], today: today, calendar: calendar)
    }

    @Test func logsInTheFutureOrWithImplausibleTemperaturesAreRejected() throws {
        #expect(throws: CycleRepositoryError.futureDate) {
            try CycleRules.validate(CycleLogRecord(day: day("2026-10-03")), today: today, calendar: calendar)
        }
        #expect(throws: CycleRepositoryError.invalidTemperature) {
            try CycleRules.validate(CycleLogRecord(day: day("2026-10-02"), bbtCelsius: 34.9), today: today, calendar: calendar)
        }
        #expect(throws: CycleRepositoryError.invalidTemperature) {
            try CycleRules.validate(CycleLogRecord(day: day("2026-10-02"), bbtCelsius: 38.6), today: today, calendar: calendar)
        }
        try CycleRules.validate(CycleLogRecord(day: day("2026-10-02"), bbtCelsius: 35.0), today: today, calendar: calendar)
        try CycleRules.validate(CycleLogRecord(day: day("2026-10-02"), bbtCelsius: 38.5), today: today, calendar: calendar)
    }

    @Test func emptyLogIsDetected() {
        #expect(CycleLogRecord(day: today, note: "  ").isEmpty)
        #expect(!CycleLogRecord(day: today, mucus: .dry).isEmpty)
    }

    @Test func overlappingDuplicatePeriodsAreMergedKeepingTheEnd() {
        let open = PeriodRecord(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, startDate: day("2026-09-03"))
        let closed = PeriodRecord(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, startDate: day("2026-09-03"), endDate: day("2026-09-07"))
        let earlier = PeriodRecord(startDate: day("2026-08-06"), endDate: day("2026-08-10"))
        let result = CycleRules.mergingDuplicates([open, earlier, closed], calendar: calendar)
        #expect(result.periods == [earlier, closed])
        #expect(result.removedIDs == [open.id])
    }

    @Test func mergedPeriodSpansBothCopies() {
        let first = PeriodRecord(startDate: day("2026-09-03"), endDate: day("2026-09-06"))
        let second = PeriodRecord(startDate: day("2026-09-05"), endDate: day("2026-09-08"))
        let result = CycleRules.mergingDuplicates([second, first], calendar: calendar)
        #expect(result.periods == [PeriodRecord(id: first.id, startDate: day("2026-09-03"), endDate: day("2026-09-08"))])
        #expect(result.removedIDs == [second.id])
    }

    @Test func separatePeriodsAreLeftAlone() {
        let periods = [
            PeriodRecord(startDate: day("2026-08-06"), endDate: day("2026-08-10")),
            PeriodRecord(startDate: day("2026-09-03")),
        ]
        let result = CycleRules.mergingDuplicates(periods, calendar: calendar)
        #expect(result.periods == periods)
        #expect(result.removedIDs.isEmpty)
    }

    @Test func sameDayLogsAreMerged() {
        let a = CycleLogRecord(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!, day: day("2026-10-01"), lh: .negative, note: "Tired")
        let b = CycleLogRecord(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!, day: date("2026-10-01T08:00:00Z"), lh: .positive, bbtCelsius: 36.5, mucus: .eggWhite, note: "Tired")
        let other = CycleLogRecord(day: day("2026-09-30"), note: "Cramps")
        let result = CycleRules.mergingDuplicates([b, other, a], calendar: calendar)
        #expect(result.logs == [
            other,
            CycleLogRecord(id: a.id, day: day("2026-10-01"), lh: .positive, bbtCelsius: 36.5, mucus: .eggWhite, note: "Tired"),
        ])
        #expect(result.removedIDs == [b.id])
    }

    @Test func assumedPeriodIsClosedOnceItsTypicalLengthHasPassed() {
        let past = CycleRules.assumedPeriod(startingOn: date("2026-09-20T15:00:00Z"), typicalLength: 5, today: today, calendar: calendar)
        #expect(past.startDate == day("2026-09-20"))
        #expect(past.endDate == day("2026-09-24"))
        // 09-28 + 5 days → 10-02 is today: still going on.
        let ongoing = CycleRules.assumedPeriod(startingOn: day("2026-09-28"), typicalLength: 5, today: today, calendar: calendar)
        #expect(ongoing.endDate == nil)
        let yesterday = CycleRules.assumedPeriod(startingOn: day("2026-10-01"), typicalLength: 2, today: today, calendar: calendar)
        #expect(yesterday.endDate == nil)
    }

    @Test func lastPeriodPickerAllowsThePastYearUpToToday() {
        let range = CycleRules.lastPeriodRange(now: today, calendar: calendar)
        #expect(range.lowerBound == day("2025-10-02"))
        #expect(range.upperBound == date("2026-10-02T23:59:59Z"))
    }

    @Test func temperatureEntryAcceptsBothDecimalSeparators() {
        #expect(TemperatureEntry(text: "36.5") == .valid(36.5))
        #expect(TemperatureEntry(text: " 36,55 ") == .valid(36.55))
        #expect(TemperatureEntry(text: "35") == .valid(35.0))
        #expect(TemperatureEntry(text: "38.5") == .valid(38.5))
        #expect(TemperatureEntry(text: "") == .empty)
        #expect(TemperatureEntry(text: "  ") == .empty)
    }

    @Test func temperatureEntryRejectsTextAndImplausibleValues() {
        #expect(TemperatureEntry(text: "abc") == .invalid)
        #expect(TemperatureEntry(text: "34.9") == .invalid)
        #expect(TemperatureEntry(text: "38.51") == .invalid)
        #expect(TemperatureEntry(text: "98.6") == .invalid)
        #expect(TemperatureEntry(text: "36.5.1") == .invalid)
    }
}
```

- [ ] **Step 2: Chạy, xác nhận fail**

Run: `scripts/test-core.sh --filter CycleRulesTests`
Expected: lỗi biên dịch `cannot find 'CycleRules' in scope` (và `PeriodRecord`, `CycleLogRecord`, `TemperatureEntry`).

- [ ] **Step 3: Viết code**

`Packages/KickCore/Sources/KickCore/CycleRecords.swift`:
```swift
import Foundation

/// A logged period (value snapshot of the SwiftData `PeriodEntry`). Dates are
/// the start of a calendar day; `endDate` is the last day of bleeding.
public struct PeriodRecord: Equatable, Sendable, Identifiable {
    public let id: UUID
    public var startDate: Date
    /// nil while the period is still going on.
    public var endDate: Date?

    public init(id: UUID = UUID(), startDate: Date, endDate: Date? = nil) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
    }

    public var isOpen: Bool { endDate == nil }
}

public enum LHResult: String, Sendable, CaseIterable {
    case positive
    case negative
}

public enum CervicalMucus: String, Sendable, CaseIterable {
    case dry
    case sticky
    case creamy
    case eggWhite
}

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

public enum CycleRepositoryError: Error, Equatable, Sendable {
    case futureDate
    case endBeforeStart
    case overlapsExistingPeriod
    case invalidTemperature
    case notFound
}

/// Storage for periods and day logs. Implementations validate every write with
/// `CycleRules` and merge iCloud duplicates on read; reminders are kept in step
/// by `CycleCoordinator`.
@MainActor
public protocol CycleRepository: AnyObject {
    /// Every period, oldest first, with overlapping duplicates merged.
    func periods() throws -> [PeriodRecord]
    /// Every day log, oldest first, at most one per day.
    func logs() throws -> [CycleLogRecord]
    /// Throws `CycleRepositoryError` when the period is in the future, ends before
    /// it starts, or overlaps another period.
    func addPeriod(_ period: PeriodRecord, today: Date) throws
    /// Same checks as `addPeriod`; throws `.notFound` for an unknown id.
    func updatePeriod(_ period: PeriodRecord, today: Date) throws
    /// No-op when no period has that id (it may already be gone via iCloud).
    func deletePeriod(id: UUID) throws
    /// Inserts or replaces the log for `log.day` (keeping the stored id); an empty
    /// log removes it. Throws `.futureDate` or `.invalidTemperature`.
    func saveLog(_ log: CycleLogRecord, today: Date) throws
}

/// Validation and duplicate merging shared by `CycleStore` and the test fake.
public enum CycleRules {
    public static let temperatureRange: ClosedRange<Double> = 35.0...38.5
    /// An open period is assumed to last at most this many days; past that the
    /// Cycle tab suggests logging the end (spec §6).
    public static let longPeriodDays = 10

    public static func normalized(_ period: PeriodRecord, calendar: Calendar) -> PeriodRecord {
        PeriodRecord(
            id: period.id,
            startDate: calendar.startOfDay(for: period.startDate),
            endDate: period.endDate.map { calendar.startOfDay(for: $0) }
        )
    }

    public static func normalized(_ log: CycleLogRecord, calendar: Calendar) -> CycleLogRecord {
        var copy = log
        copy.day = calendar.startOfDay(for: log.day)
        copy.note = log.note.trimmingCharacters(in: .whitespacesAndNewlines)
        return copy
    }

    /// The days a period covers, both ends included: up to its end day, or — while
    /// open — up to today, but no more than `longPeriodDays` days.
    public static func dayRange(of period: PeriodRecord, today: Date, calendar: Calendar) -> ClosedRange<Date> {
        let start = calendar.startOfDay(for: period.startDate)
        let end: Date
        if let endDate = period.endDate {
            end = calendar.startOfDay(for: endDate)
        } else {
            let cap = calendar.date(byAdding: .day, value: longPeriodDays - 1, to: start) ?? start
            end = min(calendar.startOfDay(for: today), cap)
        }
        return start...max(start, end)
    }

    /// Checks a new or edited period against the others (`existing` may include
    /// the period itself; it is skipped by id).
    public static func validate(_ period: PeriodRecord, existing: [PeriodRecord], today: Date, calendar: Calendar) throws {
        let candidate = normalized(period, calendar: calendar)
        let todayStart = calendar.startOfDay(for: today)
        guard candidate.startDate <= todayStart else { throw CycleRepositoryError.futureDate }
        if let end = candidate.endDate {
            guard end >= candidate.startDate else { throw CycleRepositoryError.endBeforeStart }
            guard end <= todayStart else { throw CycleRepositoryError.futureDate }
        }
        let range = dayRange(of: candidate, today: today, calendar: calendar)
        for other in existing where other.id != candidate.id {
            if dayRange(of: other, today: today, calendar: calendar).overlaps(range) {
                throw CycleRepositoryError.overlapsExistingPeriod
            }
        }
    }

    /// The period to store when the mother only knows its first day (onboarding,
    /// "add last period"): it lasted her typical length if that is already over,
    /// otherwise it is still going on.
    public static func assumedPeriod(startingOn start: Date, typicalLength: Int, today: Date, calendar: Calendar) -> PeriodRecord {
        let first = calendar.startOfDay(for: start)
        let last = calendar.date(byAdding: .day, value: typicalLength - 1, to: first) ?? first
        return PeriodRecord(startDate: first, endDate: last < calendar.startOfDay(for: today) ? last : nil)
    }

    /// What the "first day of your last period" picker allows: the past year up to today.
    public static func lastPeriodRange(now: Date, calendar: Calendar) -> ClosedRange<Date> {
        let today = calendar.startOfDay(for: now)
        let earliest = calendar.date(byAdding: .year, value: -1, to: today) ?? today
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        return earliest...tomorrow.addingTimeInterval(-1)
    }

    public static func validate(_ log: CycleLogRecord, today: Date, calendar: Calendar) throws {
        guard calendar.startOfDay(for: log.day) <= calendar.startOfDay(for: today) else {
            throw CycleRepositoryError.futureDate
        }
        if let bbt = log.bbtCelsius, !temperatureRange.contains(bbt) {
            throw CycleRepositoryError.invalidTemperature
        }
    }

    /// Merges periods that overlap — only iCloud sync can create them, e.g. the
    /// same period started on two devices. An open period counts as its start day
    /// only, so this never depends on today. The merged period keeps the earliest
    /// start and the latest end (open only when every copy is open), and the id of
    /// the earliest copy. Returns the periods oldest first and the ids to delete.
    public static func mergingDuplicates(_ periods: [PeriodRecord], calendar: Calendar) -> (periods: [PeriodRecord], removedIDs: [UUID]) {
        let sorted = periods.map { normalized($0, calendar: calendar) }.sorted {
            ($0.startDate, $0.id.uuidString) < ($1.startDate, $1.id.uuidString)
        }
        var kept: [PeriodRecord] = []
        var removed: [UUID] = []
        for period in sorted {
            if var last = kept.last, period.startDate <= (last.endDate ?? last.startDate) {
                if let end = period.endDate {
                    last.endDate = max(last.endDate ?? end, end)
                }
                kept[kept.count - 1] = last
                removed.append(period.id)
            } else {
                kept.append(period)
            }
        }
        return (kept, removed)
    }

    /// Merges logs that fall on the same day (iCloud duplicates). Keeps the id
    /// that sorts first; a positive LH test wins over a negative one; the first
    /// temperature and mucus found win; distinct notes are joined by newlines.
    public static func mergingDuplicates(_ logs: [CycleLogRecord], calendar: Calendar) -> (logs: [CycleLogRecord], removedIDs: [UUID]) {
        let byDay = Dictionary(grouping: logs.map { normalized($0, calendar: calendar) }, by: \.day)
        var merged: [CycleLogRecord] = []
        var removed: [UUID] = []
        for day in byDay.keys.sorted() {
            let group = byDay[day, default: []].sorted { $0.id.uuidString < $1.id.uuidString }
            guard var first = group.first else { continue }
            if group.count > 1 {
                let lhs = group.compactMap(\.lh)
                first.lh = lhs.contains(.positive) ? .positive : lhs.first
                first.bbtCelsius = group.lazy.compactMap(\.bbtCelsius).first
                first.mucus = group.lazy.compactMap(\.mucus).first
                var notes: [String] = []
                for note in group.map(\.note) where !note.isEmpty && !notes.contains(note) {
                    notes.append(note)
                }
                first.note = notes.joined(separator: "\n")
                removed += group.dropFirst().map(\.id)
            }
            merged.append(first)
        }
        return (merged, removed)
    }
}

/// What the temperature field holds. Accepts "36.5" and "36,5".
public enum TemperatureEntry: Equatable, Sendable {
    case empty
    case valid(Double)
    /// Not a number, or outside 35.0–38.5 °C.
    case invalid

    public init(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self = .empty
            return
        }
        guard let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")), value.isFinite else {
            self = .invalid
            return
        }
        let rounded = (value * 100).rounded() / 100
        self = CycleRules.temperatureRange.contains(rounded) ? .valid(rounded) : .invalid
    }
}
```

- [ ] **Step 4: Chạy lại, xác nhận pass**

Run: `scripts/test-core.sh --filter CycleRulesTests` → Expected: 18 test pass.
Run: `scripts/test-core.sh` → Expected: toàn bộ pass (181 + 18 = 199).

- [ ] **Step 5: Commit, push, xác minh CI**

```bash
git add Packages/KickCore
git commit -F - <<'MSG'
feat(core): add cycle records, repository protocol and data rules

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`.

---

### Task 3: `CyclePredictor` — dự đoán kỳ kinh, rụng trứng, cửa sổ thụ thai

Toàn bộ luật spec §4.1. Test bao phủ: chu kỳ đều 28, ngắn 24, dài 35, không đều (độ tin cậy thấp + nới cửa sổ), bỏ chu kỳ ngoài 21–45, chỉ 6 chu kỳ gần nhất, LH ghi đè, BBT 3-trên-6 (đúng/sai/thiếu ngày/thiếu dữ liệu/chu kỳ trước), trễ kinh, kỳ kinh chưa kết thúc, chưa có dữ liệu, ranh giới tháng/năm và DST (America/New_York, 2026-03-08 và 2026-11-01).

**Files:**
- Create: `Packages/KickCore/Sources/KickCore/CyclePredictor.swift`
- Test: `Packages/KickCore/Tests/KickCoreTests/CyclePredictorTests.swift`

**Interfaces:**
- Consumes: `PeriodRecord`, `CycleLogRecord`, `CycleRules.normalized/dayRange/longPeriodDays` (Task 2), `CycleSettings` (Task 1).
- Produces:
  - `public enum CycleConfidence { case normal, low }`, `public enum OvulationSource { case calendar, lhTest, temperature }`, `public enum CycleDayStatus: Equatable, Sendable { case period(isPredicted: Bool), fertile, peak, low }`
  - `public struct CycleForecast: Equatable, Sendable` với các thuộc tính public: `today`, `currentPeriodStart`, `cycleDay: Int`, `averageCycleLength: Int`, `usableCycleLengths: [Int]`, `nextPeriodStart`, `ovulationDate`, `ovulationSource`, `fertileWindow: ClosedRange<Date>`, `confidence`, `windowWidening: Int`, `daysLate: Int`, `irregularWarning: Bool`, `isLongOpenPeriod: Bool`; computed `ovulationConfirmed: Bool`, `daysUntilNextPeriod: Int`, `isNoticeablyLate: Bool` (≥ 3 ngày), `openPeriod: PeriodRecord?`; `func dayStatus(for date: Date) -> CycleDayStatus`.
  - `public enum CyclePredictor { public static let lateNoticeDays = 3; public static func forecast(periods: [PeriodRecord], logs: [CycleLogRecord], settings: CycleSettings, now: Date, calendar: Calendar = .current) -> CycleForecast? }` — `nil` khi chưa có kỳ kinh nào (≤ hôm nay).

- [ ] **Step 1: Viết test trước**

`Packages/KickCore/Tests/KickCoreTests/CyclePredictorTests.swift`:
```swift
import Foundation
import Testing
@testable import KickCore

struct CyclePredictorTests {
    let calendar = utcCalendar
    let settings = CycleSettings()

    /// Midnight UTC of a "yyyy-MM-dd" day.
    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00Z") }

    /// Noon UTC, as a "now" in the middle of that day.
    private func noon(_ iso: String) -> Date { date("\(iso)T12:00:00Z") }

    /// Closed 5-day periods starting on each day (oldest first).
    private func periods(_ starts: String...) -> [PeriodRecord] {
        starts.map { PeriodRecord(startDate: day($0), endDate: calendar.date(byAdding: .day, value: 4, to: day($0))) }
    }

    private func forecast(
        _ periods: [PeriodRecord],
        logs: [CycleLogRecord] = [],
        settings: CycleSettings = CycleSettings(),
        now: String
    ) throws -> CycleForecast {
        try #require(CyclePredictor.forecast(periods: periods, logs: logs, settings: settings, now: noon(now), calendar: calendar))
    }

    // MARK: - No data

    @Test func noPeriodsMeansNoForecast() {
        #expect(CyclePredictor.forecast(periods: [], logs: [], settings: settings, now: noon("2026-10-02"), calendar: calendar) == nil)
    }

    @Test func periodsInTheFutureAreIgnored() {
        let future = [PeriodRecord(startDate: day("2026-10-05"))]
        #expect(CyclePredictor.forecast(periods: future, logs: [], settings: settings, now: noon("2026-10-02"), calendar: calendar) == nil)
    }

    @Test func singlePeriodUsesTheTypicalLengthWithLowConfidence() throws {
        let result = try forecast(
            [PeriodRecord(startDate: day("2026-09-20"), endDate: day("2026-09-24"))],
            settings: CycleSettings(typicalCycleLength: 30), now: "2026-10-02"
        )
        #expect(result.cycleDay == 13)
        #expect(result.averageCycleLength == 30)
        #expect(result.usableCycleLengths.isEmpty)
        #expect(result.nextPeriodStart == day("2026-10-20"))
        #expect(result.ovulationDate == day("2026-10-06"))
        #expect(result.confidence == .low)
        #expect(result.windowWidening == 0)
        #expect(result.fertileWindow == day("2026-10-01")...day("2026-10-07"))
        #expect(result.irregularWarning == false)
    }

    // MARK: - Regular cycles

    @Test func regular28DayCycles() throws {
        let result = try forecast(periods("2026-07-09", "2026-08-06", "2026-09-03"), now: "2026-09-15")
        #expect(result.currentPeriodStart == day("2026-09-03"))
        #expect(result.cycleDay == 13)
        #expect(result.averageCycleLength == 28)
        #expect(result.usableCycleLengths == [28, 28])
        #expect(result.nextPeriodStart == day("2026-10-01"))
        #expect(result.ovulationDate == day("2026-09-17"))
        #expect(result.ovulationSource == .calendar)
        #expect(result.ovulationConfirmed == false)
        #expect(result.fertileWindow == day("2026-09-12")...day("2026-09-18"))
        #expect(result.confidence == .normal)
        #expect(result.daysLate == 0)
        #expect(result.irregularWarning == false)
        #expect(result.isLongOpenPeriod == false)
    }

    @Test func dayStatusesAcrossARegularCycle() throws {
        let result = try forecast(periods("2026-07-09", "2026-08-06", "2026-09-03"), now: "2026-09-15")
        #expect(result.dayStatus(for: day("2026-09-03")) == .period(isPredicted: false))
        #expect(result.dayStatus(for: noon("2026-09-07")) == .period(isPredicted: false))
        #expect(result.dayStatus(for: day("2026-09-08")) == .low)
        #expect(result.dayStatus(for: day("2026-09-11")) == .low)
        #expect(result.dayStatus(for: day("2026-09-12")) == .fertile)
        #expect(result.dayStatus(for: day("2026-09-15")) == .fertile)
        #expect(result.dayStatus(for: day("2026-09-16")) == .peak)
        #expect(result.dayStatus(for: day("2026-09-17")) == .peak)
        #expect(result.dayStatus(for: day("2026-09-18")) == .fertile)
        #expect(result.dayStatus(for: day("2026-09-19")) == .low)
        #expect(result.dayStatus(for: day("2026-09-30")) == .low)
        // Next period is predicted for the typical 5 days.
        #expect(result.dayStatus(for: day("2026-10-01")) == .period(isPredicted: true))
        #expect(result.dayStatus(for: day("2026-10-05")) == .period(isPredicted: true))
        #expect(result.dayStatus(for: day("2026-10-06")) == .low)
        // The cycle after repeats the calendar prediction.
        #expect(result.dayStatus(for: day("2026-10-09")) == .low)
        #expect(result.dayStatus(for: day("2026-10-10")) == .fertile)
        #expect(result.dayStatus(for: day("2026-10-14")) == .peak)
        #expect(result.dayStatus(for: day("2026-10-15")) == .peak)
        #expect(result.dayStatus(for: day("2026-10-16")) == .fertile)
        #expect(result.dayStatus(for: day("2026-10-29")) == .period(isPredicted: true))
        // Before the logged history: nothing is known.
        #expect(result.dayStatus(for: day("2026-06-01")) == .low)
        #expect(result.dayStatus(for: day("2026-08-08")) == .period(isPredicted: false))
    }

    @Test func short24DayCycles() throws {
        let result = try forecast(periods("2026-08-01", "2026-08-25", "2026-09-18"), now: "2026-09-25")
        #expect(result.averageCycleLength == 24)
        #expect(result.cycleDay == 8)
        #expect(result.nextPeriodStart == day("2026-10-12"))
        #expect(result.ovulationDate == day("2026-09-28"))
        #expect(result.fertileWindow == day("2026-09-23")...day("2026-09-29"))
        #expect(result.dayStatus(for: day("2026-09-25")) == .fertile)
        #expect(result.confidence == .normal)
    }

    @Test func long35DayCycles() throws {
        let result = try forecast(periods("2026-07-01", "2026-08-05", "2026-09-09"), now: "2026-09-20")
        #expect(result.averageCycleLength == 35)
        #expect(result.cycleDay == 12)
        #expect(result.nextPeriodStart == day("2026-10-14"))
        #expect(result.ovulationDate == day("2026-09-30"))
        #expect(result.fertileWindow == day("2026-09-25")...day("2026-10-01"))
        #expect(result.dayStatus(for: day("2026-09-20")) == .low)
        #expect(result.confidence == .normal)
    }

    @Test func averageIsRoundedToTheNearestDay() throws {
        // 29 and 30 → 29.5 → 30.
        let result = try forecast(periods("2026-07-01", "2026-07-30", "2026-08-29"), now: "2026-09-02")
        #expect(result.usableCycleLengths == [29, 30])
        #expect(result.averageCycleLength == 30)
    }

    @Test func onlyTheSixMostRecentCyclesAreAveraged() throws {
        // Two 40-day cycles, then six of 28 days.
        let starts = ["2026-01-01", "2026-02-10", "2026-03-22", "2026-04-19", "2026-05-17", "2026-06-14", "2026-07-12", "2026-08-09", "2026-09-06"]
        let records = starts.map { PeriodRecord(startDate: day($0), endDate: calendar.date(byAdding: .day, value: 4, to: day($0))) }
        let result = try forecast(records, now: "2026-09-10")
        #expect(result.usableCycleLengths == [28, 28, 28, 28, 28, 28])
        #expect(result.averageCycleLength == 28)
        #expect(result.confidence == .normal)
    }

    @Test func oneCompleteCycleIsStillLowConfidence() throws {
        let result = try forecast(periods("2026-08-06", "2026-09-03"), now: "2026-09-10")
        #expect(result.averageCycleLength == 28)
        #expect(result.confidence == .low)
        #expect(result.windowWidening == 0)
    }

    // MARK: - Irregular cycles

    @Test func irregularCyclesLowerConfidenceAndWidenTheWindow() throws {
        // 24, 35, 26, 34 days: mean 29.75 → 30; spread 11 > 7; SD ≈ 4.8 > 4.
        let result = try forecast(periods("2026-05-01", "2026-05-25", "2026-06-29", "2026-07-25", "2026-08-28"), now: "2026-09-05")
        #expect(result.usableCycleLengths == [24, 35, 26, 34])
        #expect(result.averageCycleLength == 30)
        #expect(result.confidence == .low)
        #expect(result.windowWidening == 3)
        #expect(result.nextPeriodStart == day("2026-09-27"))
        #expect(result.ovulationDate == day("2026-09-13"))
        #expect(result.fertileWindow == day("2026-09-05")...day("2026-09-17"))
        #expect(result.irregularWarning)
        #expect(result.dayStatus(for: day("2026-09-05")) == .fertile)
        #expect(result.dayStatus(for: day("2026-09-04")) == .low)
    }

    @Test func smallVariationKeepsNormalConfidence() throws {
        // 27, 29, 28: spread 2, SD ≈ 0.8.
        let result = try forecast(periods("2026-06-01", "2026-06-28", "2026-07-27", "2026-08-24"), now: "2026-08-30")
        #expect(result.confidence == .normal)
        #expect(result.windowWidening == 0)
        #expect(result.irregularWarning == false)
    }

    @Test func wideningIsHalfTheSpreadUpToThreeDays() throws {
        // 28, 29, 28 then a 36: spread 8 > 7 → low, widening min(3, 8 / 2) = 3.
        let result = try forecast(periods("2026-04-01", "2026-04-29", "2026-05-28", "2026-06-25", "2026-07-31"), now: "2026-08-05")
        #expect(result.usableCycleLengths == [28, 29, 28, 36])
        #expect(result.confidence == .low)
        #expect(result.windowWidening == 3)
    }

    @Test func cyclesOutside21To45DaysAreLeftOutOfTheAverage() throws {
        // 28, then 60 (a missed log), then 28.
        let result = try forecast(periods("2026-05-01", "2026-05-29", "2026-07-28", "2026-08-25"), now: "2026-09-01")
        #expect(result.usableCycleLengths == [28, 28])
        #expect(result.averageCycleLength == 28)
        #expect(result.confidence == .normal)
        #expect(result.irregularWarning == false)
    }

    @Test func aLatestCycleShorterThan21DaysRaisesTheIrregularWarning() throws {
        let result = try forecast(periods("2026-08-01", "2026-08-29", "2026-09-12"), now: "2026-09-15")
        #expect(result.usableCycleLengths == [28])
        #expect(result.averageCycleLength == 28)
        #expect(result.confidence == .low)
        #expect(result.irregularWarning)
    }

    @Test func aLatestCycleLongerThan45DaysRaisesTheIrregularWarning() throws {
        let result = try forecast(periods("2026-06-01", "2026-06-29", "2026-08-20"), now: "2026-08-25")
        #expect(result.usableCycleLengths == [28])
        #expect(result.irregularWarning)
    }

    // MARK: - LH tests

    @Test func positiveLHTestMovesOvulationToTheNextDay() throws {
        let logs = [
            CycleLogRecord(day: day("2026-09-13"), lh: .negative),
            CycleLogRecord(day: day("2026-09-14"), lh: .positive),
            CycleLogRecord(day: day("2026-09-15"), lh: .positive),
        ]
        let result = try forecast(periods("2026-07-09", "2026-08-06", "2026-09-03"), logs: logs, now: "2026-09-15")
        #expect(result.ovulationSource == .lhTest)
        #expect(result.ovulationDate == day("2026-09-15"))
        #expect(result.fertileWindow == day("2026-09-10")...day("2026-09-16"))
        #expect(result.nextPeriodStart == day("2026-10-01"))
        #expect(result.dayStatus(for: day("2026-09-14")) == .peak)
        #expect(result.dayStatus(for: day("2026-09-17")) == .low)
    }

    @Test func lhTestsFromAnEarlierCycleAreIgnored() throws {
        let logs = [CycleLogRecord(day: day("2026-08-20"), lh: .positive)]
        let result = try forecast(periods("2026-07-09", "2026-08-06", "2026-09-03"), logs: logs, now: "2026-09-15")
        #expect(result.ovulationSource == .calendar)
        #expect(result.ovulationDate == day("2026-09-17"))
    }

    @Test func lhOverrideIsNotWidenedEvenWithLowConfidence() throws {
        let logs = [CycleLogRecord(day: day("2026-09-10"), lh: .positive)]
        let result = try forecast(periods("2026-05-01", "2026-05-25", "2026-06-29", "2026-07-25", "2026-08-28"), logs: logs, now: "2026-09-12")
        #expect(result.confidence == .low)
        #expect(result.windowWidening == 0)
        #expect(result.ovulationDate == day("2026-09-11"))
        #expect(result.fertileWindow == day("2026-09-06")...day("2026-09-12"))
    }

    // MARK: - Basal body temperature

    /// Readings on consecutive days from `start`.
    private func temperatures(from start: String, _ values: [Double]) -> [CycleLogRecord] {
        values.enumerated().map { offset, value in
            CycleLogRecord(day: calendar.date(byAdding: .day, value: offset, to: day(start))!, bbtCelsius: value)
        }
    }

    @Test func threeHighReadingsOverSixConfirmOvulation() throws {
        let logs = temperatures(from: "2026-09-05", [36.3, 36.4, 36.2, 36.4, 36.3, 36.4, 36.6, 36.7, 36.6])
        let result = try forecast(periods("2026-07-09", "2026-08-06", "2026-09-03"), logs: logs, now: "2026-09-14")
        #expect(result.ovulationConfirmed)
        #expect(result.ovulationSource == .temperature)
        #expect(result.ovulationDate == day("2026-09-10"))
        #expect(result.fertileWindow == day("2026-09-05")...day("2026-09-11"))
    }

    @Test func aRiseOfLessThanTwoTenthsDoesNotConfirm() throws {
        let logs = temperatures(from: "2026-09-05", [36.3, 36.4, 36.2, 36.4, 36.3, 36.4, 36.6, 36.5, 36.7])
        let result = try forecast(periods("2026-07-09", "2026-08-06", "2026-09-03"), logs: logs, now: "2026-09-14")
        #expect(result.ovulationConfirmed == false)
        #expect(result.ovulationSource == .calendar)
    }

    @Test func highReadingsMustBeOnConsecutiveDays() throws {
        var logs = temperatures(from: "2026-09-05", [36.3, 36.4, 36.2, 36.4, 36.3, 36.4, 36.6])
        logs += temperatures(from: "2026-09-13", [36.7, 36.6]) // 09-12 is missing
        let result = try forecast(periods("2026-07-09", "2026-08-06", "2026-09-03"), logs: logs, now: "2026-09-14")
        #expect(result.ovulationConfirmed == false)
    }

    @Test func fewerThanSixEarlierReadingsDoNotConfirm() throws {
        let logs = temperatures(from: "2026-09-06", [36.3, 36.4, 36.2, 36.4, 36.3, 36.7, 36.8, 36.7])
        let result = try forecast(periods("2026-07-09", "2026-08-06", "2026-09-03"), logs: logs, now: "2026-09-14")
        #expect(result.ovulationConfirmed == false)
    }

    @Test func readingsBeforeThisCycleAreIgnored() throws {
        // Six low readings at the end of the previous cycle, three high ones in this one.
        let logs = temperatures(from: "2026-08-28", [36.3, 36.4, 36.2, 36.4, 36.3, 36.4, 36.7, 36.8, 36.7])
        let result = try forecast(periods("2026-07-09", "2026-08-06", "2026-09-03"), logs: logs, now: "2026-09-10")
        #expect(result.ovulationConfirmed == false)
    }

    @Test func temperatureConfirmationWinsOverAnLHTest() throws {
        var logs = temperatures(from: "2026-09-05", [36.3, 36.4, 36.2, 36.4, 36.3, 36.4, 36.6, 36.7, 36.6])
        logs.append(CycleLogRecord(day: day("2026-09-07"), lh: .positive))
        let result = try forecast(periods("2026-07-09", "2026-08-06", "2026-09-03"), logs: logs, now: "2026-09-14")
        #expect(result.ovulationSource == .temperature)
        #expect(result.ovulationDate == day("2026-09-10"))
    }

    // MARK: - Lateness and long periods

    @Test func daysLateCountFromThePredictedStart() throws {
        let records = periods("2026-07-09", "2026-08-06", "2026-09-03")
        #expect(try forecast(records, now: "2026-10-01").daysLate == 0)
        #expect(try forecast(records, now: "2026-09-25").daysUntilNextPeriod == 6)
        #expect(try forecast(records, now: "2026-10-01").daysUntilNextPeriod == 0)
        let twoDays = try forecast(records, now: "2026-10-03")
        #expect(twoDays.daysLate == 2)
        #expect(twoDays.isNoticeablyLate == false)
        let late = try forecast(records, now: "2026-10-04")
        #expect(late.daysLate == 3)
        #expect(late.isNoticeablyLate)
        #expect(late.daysUntilNextPeriod == 0)
        #expect(late.cycleDay == 32)
        // A missed period is not shown as predicted on days already passed.
        #expect(late.dayStatus(for: day("2026-10-02")) == .low)
    }

    @Test func openPeriodShowsLoggedDaysThenPredictedDays() throws {
        var records = periods("2026-08-06", "2026-09-03")
        records.append(PeriodRecord(startDate: day("2026-10-01")))
        let result = try forecast(records, now: "2026-10-02")
        #expect(result.cycleDay == 2)
        #expect(result.openPeriod?.startDate == day("2026-10-01"))
        #expect(result.dayStatus(for: day("2026-10-01")) == .period(isPredicted: false))
        #expect(result.dayStatus(for: day("2026-10-02")) == .period(isPredicted: false))
        #expect(result.dayStatus(for: day("2026-10-03")) == .period(isPredicted: true))
        #expect(result.dayStatus(for: day("2026-10-05")) == .period(isPredicted: true))
        #expect(result.dayStatus(for: day("2026-10-06")) == .low)
        #expect(result.isLongOpenPeriod == false)
    }

    @Test func periodOpenForMoreThanTenDaysIsFlagged() throws {
        let tenDays = try forecast([PeriodRecord(startDate: day("2026-09-23"))], now: "2026-10-02")
        #expect(tenDays.isLongOpenPeriod == false)
        let elevenDays = try forecast([PeriodRecord(startDate: day("2026-09-22"))], now: "2026-10-02")
        #expect(elevenDays.isLongOpenPeriod)
    }

    // MARK: - Calendar boundaries

    @Test func predictionsCrossMonthAndYearEnds() throws {
        let result = try forecast(periods("2025-12-06", "2026-01-03", "2026-01-31"), now: "2026-02-02")
        #expect(result.usableCycleLengths == [28, 28])
        #expect(result.cycleDay == 3)
        #expect(result.nextPeriodStart == day("2026-02-28"))
        #expect(result.ovulationDate == day("2026-02-14"))
        #expect(result.fertileWindow == day("2026-02-09")...day("2026-02-15"))
    }

    @Test func daylightSavingChangesDoNotShiftDays() throws {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        func local(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
            newYork.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
        }
        func closed(_ start: Date) -> PeriodRecord {
            PeriodRecord(startDate: start, endDate: newYork.date(byAdding: .day, value: 4, to: start))
        }

        // Clocks spring forward on 2026-03-08.
        let spring = try #require(CyclePredictor.forecast(
            periods: [closed(local(2026, 1, 23)), closed(local(2026, 2, 20))],
            logs: [], settings: settings, now: local(2026, 3, 10, hour: 12), calendar: newYork
        ))
        #expect(spring.cycleDay == 19)
        #expect(spring.nextPeriodStart == local(2026, 3, 20))
        #expect(newYork.component(.hour, from: spring.nextPeriodStart) == 0)
        #expect(spring.ovulationDate == local(2026, 3, 6))
        #expect(spring.fertileWindow == local(2026, 3, 1)...local(2026, 3, 7))
        #expect(spring.dayStatus(for: local(2026, 3, 7, hour: 23)) == .fertile)
        #expect(spring.dayStatus(for: local(2026, 3, 8, hour: 12)) == .low)

        // Clocks fall back on 2026-11-01, inside the fertile window.
        let fall = try #require(CyclePredictor.forecast(
            periods: [closed(local(2026, 9, 22)), closed(local(2026, 10, 20))],
            logs: [], settings: settings, now: local(2026, 10, 30, hour: 12), calendar: newYork
        ))
        #expect(fall.nextPeriodStart == local(2026, 11, 17))
        #expect(fall.ovulationDate == local(2026, 11, 3))
        #expect(fall.fertileWindow == local(2026, 10, 29)...local(2026, 11, 4))
        #expect(fall.dayStatus(for: local(2026, 11, 1, hour: 12)) == .fertile)
        #expect(fall.dayStatus(for: local(2026, 11, 2, hour: 12)) == .peak)
        #expect(fall.dayStatus(for: local(2026, 11, 3, hour: 1)) == .peak)
    }
}
```

- [ ] **Step 2: Chạy, xác nhận fail**

Run: `scripts/test-core.sh --filter CyclePredictorTests`
Expected: lỗi biên dịch `cannot find 'CyclePredictor' in scope`.

- [ ] **Step 3: Viết code**

`Packages/KickCore/Sources/KickCore/CyclePredictor.swift`:
```swift
import Foundation

public enum CycleConfidence: Sendable, Equatable {
    case normal
    /// Fewer than 2 usable cycles, or cycles that vary a lot: the fertile window is widened.
    case low
}

/// Where the estimated ovulation day comes from, most reliable last.
public enum OvulationSource: Sendable, Equatable {
    /// Next period − 14 days.
    case calendar
    /// The day after the first positive LH test of this cycle.
    case lhTest
    /// Confirmed afterwards by a sustained BBT rise (the day before the rise).
    case temperature
}

/// How a calendar day is coloured.
public enum CycleDayStatus: Sendable, Equatable {
    /// A logged period day, or a predicted one (`isPredicted`).
    case period(isPredicted: Bool)
    case fertile
    /// Ovulation day and the day before it.
    case peak
    case low
}

/// The calendar-based forecast for the current cycle, adjusted by LH tests and
/// confirmed by basal body temperature (spec §4.1). All dates are the start of
/// a calendar day.
public struct CycleForecast: Equatable, Sendable {
    public let today: Date
    public let currentPeriodStart: Date
    /// 1 on the first day of the latest period.
    public let cycleDay: Int
    /// Mean of up to 6 most recent complete cycles of 21–45 days, else the typical length.
    public let averageCycleLength: Int
    /// The cycle lengths behind the average, oldest first.
    public let usableCycleLengths: [Int]
    public let nextPeriodStart: Date
    public let ovulationDate: Date
    public let ovulationSource: OvulationSource
    public let fertileWindow: ClosedRange<Date>
    public let confidence: CycleConfidence
    /// Extra days added on each side of a low-confidence calendar window.
    public let windowWidening: Int
    /// Days past `nextPeriodStart` with no new period logged.
    public let daysLate: Int
    public let irregularWarning: Bool
    /// The latest period has no end date and has gone on for more than 10 days.
    public let isLongOpenPeriod: Bool

    let periods: [PeriodRecord]
    let typicalPeriodLength: Int
    let calendar: Calendar

    public var ovulationConfirmed: Bool { ovulationSource == .temperature }

    /// Whole days from today to `nextPeriodStart` (0 when due today or late).
    public var daysUntilNextPeriod: Int {
        max(0, calendar.dateComponents([.day], from: today, to: nextPeriodStart).day ?? 0)
    }

    /// Late enough for the "take a test" card and reminder (3 days or more).
    public var isNoticeablyLate: Bool { daysLate >= CyclePredictor.lateNoticeDays }

    /// The latest period, still open.
    public var openPeriod: PeriodRecord? {
        guard let latest = periods.last, latest.isOpen else { return nil }
        return latest
    }

    public func dayStatus(for date: Date) -> CycleDayStatus {
        let day = calendar.startOfDay(for: date)
        for period in periods where CycleRules.dayRange(of: period, today: today, calendar: calendar).contains(day) {
            return .period(isPredicted: false)
        }
        if let open = openPeriod, day > today, let lastDay = adding(typicalPeriodLength - 1, to: open.startDate), day <= lastDay {
            return .period(isPredicted: true)
        }
        guard day >= currentPeriodStart else { return .low }
        if let status = windowStatus(day, ovulation: ovulationDate, window: fertileWindow) {
            return status
        }
        // Later cycles repeat the calendar prediction.
        let cycleIndex = days(from: currentPeriodStart, to: day) / averageCycleLength
        guard cycleIndex >= 1, let cycleStart = adding(cycleIndex * averageCycleLength, to: currentPeriodStart) else { return .low }
        if day > today, let lastDay = adding(typicalPeriodLength - 1, to: cycleStart), day <= lastDay {
            return .period(isPredicted: true)
        }
        guard let ovulation = adding(averageCycleLength - CyclePredictor.lutealPhaseDays, to: cycleStart),
              let window = CyclePredictor.window(around: ovulation, widening: windowWidening, calendar: calendar)
        else { return .low }
        return windowStatus(day, ovulation: ovulation, window: window) ?? .low
    }

    private func windowStatus(_ day: Date, ovulation: Date, window: ClosedRange<Date>) -> CycleDayStatus? {
        if day == ovulation || adding(1, to: day) == ovulation { return .peak }
        return window.contains(day) ? .fertile : nil
    }

    private func adding(_ days: Int, to date: Date) -> Date? {
        calendar.date(byAdding: .day, value: days, to: date)
    }

    private func days(from start: Date, to end: Date) -> Int {
        calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }
}

public enum CyclePredictor {
    static let lutealPhaseDays = 14
    static let daysBeforeOvulation = 5
    static let daysAfterOvulation = 1
    static let maxCyclesAveraged = 6
    static let usableCycleLengths = 21...45
    static let maxStandardDeviation = 4.0
    static let maxSpread = 7
    static let maxWidening = 3
    static let minimumTemperatureRise = 0.2
    static let temperatureBaselineDays = 6
    static let temperatureHighDays = 3
    public static let lateNoticeDays = 3

    /// nil when no period has been logged yet (the Cycle tab asks for the last one).
    public static func forecast(
        periods: [PeriodRecord],
        logs: [CycleLogRecord],
        settings: CycleSettings,
        now: Date,
        calendar: Calendar = .current
    ) -> CycleForecast? {
        let today = calendar.startOfDay(for: now)
        let sorted = periods
            .map { CycleRules.normalized($0, calendar: calendar) }
            .filter { $0.startDate <= today }
            .sorted { $0.startDate < $1.startDate }
        guard let current = sorted.last else { return nil }
        func days(_ start: Date, _ end: Date) -> Int {
            calendar.dateComponents([.day], from: start, to: end).day ?? 0
        }
        func adding(_ count: Int, to date: Date) -> Date {
            calendar.date(byAdding: .day, value: count, to: date) ?? date
        }

        let allLengths = zip(sorted, sorted.dropFirst()).map { days($0.startDate, $1.startDate) }
        let usable = Array(allLengths.filter { usableCycleLengths.contains($0) }.suffix(maxCyclesAveraged))
        let average = usable.isEmpty
            ? settings.typicalCycleLength
            : Int((Double(usable.reduce(0, +)) / Double(usable.count)).rounded())
        let spread = (usable.max() ?? 0) - (usable.min() ?? 0)
        let isVariable = usable.count >= 3 && (standardDeviation(usable) > maxStandardDeviation || spread > maxSpread)
        let confidence: CycleConfidence = usable.count < 2 || isVariable ? .low : .normal

        let nextPeriodStart = adding(average, to: current.startDate)
        let cycleLogs = logs
            .map { CycleRules.normalized($0, calendar: calendar) }
            .filter { $0.day >= current.startDate && $0.day <= today }
            .sorted { $0.day < $1.day }

        var ovulation = adding(-lutealPhaseDays, to: nextPeriodStart)
        var source = OvulationSource.calendar
        if let firstPositive = cycleLogs.first(where: { $0.lh == .positive }) {
            ovulation = adding(1, to: firstPositive.day)
            source = .lhTest
        }
        if let confirmed = temperatureConfirmedOvulation(cycleLogs, calendar: calendar) {
            ovulation = confirmed
            source = .temperature
        }
        let widening = confidence == .low && source == .calendar ? min(maxWidening, spread / 2) : 0
        let window = window(around: ovulation, widening: widening, calendar: calendar)
            ?? ovulation...ovulation

        let lastLength = allLengths.last
        let irregular = (lastLength.map { !usableCycleLengths.contains($0) } ?? false) || (usable.count >= 3 && spread > maxSpread)

        return CycleForecast(
            today: today,
            currentPeriodStart: current.startDate,
            cycleDay: days(current.startDate, today) + 1,
            averageCycleLength: average,
            usableCycleLengths: usable,
            nextPeriodStart: nextPeriodStart,
            ovulationDate: ovulation,
            ovulationSource: source,
            fertileWindow: window,
            confidence: confidence,
            windowWidening: widening,
            daysLate: max(0, days(nextPeriodStart, today)),
            irregularWarning: irregular,
            isLongOpenPeriod: current.isOpen && days(current.startDate, today) + 1 > CycleRules.longPeriodDays,
            periods: sorted,
            typicalPeriodLength: settings.typicalPeriodLength,
            calendar: calendar
        )
    }

    /// Ovulation − 5 … ovulation + 1, widened by `widening` days on each side.
    static func window(around ovulation: Date, widening: Int, calendar: Calendar) -> ClosedRange<Date>? {
        guard let start = calendar.date(byAdding: .day, value: -(daysBeforeOvulation + widening), to: ovulation),
              let end = calendar.date(byAdding: .day, value: daysAfterOvulation + widening, to: ovulation)
        else { return nil }
        return start...end
    }

    /// The 3-over-6 rule: the first 3 readings on consecutive days that are all at
    /// least 0.2 °C above the highest of the 6 readings before them confirm that
    /// ovulation happened the day before the first high reading.
    static func temperatureConfirmedOvulation(_ cycleLogs: [CycleLogRecord], calendar: Calendar) -> Date? {
        let readings = cycleLogs.compactMap { log in log.bbtCelsius.map { (day: log.day, celsius: $0) } }
        guard readings.count >= temperatureBaselineDays + temperatureHighDays else { return nil }
        for start in temperatureBaselineDays...(readings.count - temperatureHighDays) {
            let high = readings[start..<(start + temperatureHighDays)]
            let consecutive = zip(high, high.dropFirst()).allSatisfy { pair in
                calendar.dateComponents([.day], from: pair.0.day, to: pair.1.day).day == 1
            }
            guard consecutive else { continue }
            let baseline = readings[(start - temperatureBaselineDays)..<start].map(\.celsius).max() ?? .infinity
            // Readings are entered to 0.1 °C; the epsilon absorbs floating-point error.
            if high.allSatisfy({ $0.celsius >= baseline + minimumTemperatureRise - 0.0001 }) {
                return calendar.date(byAdding: .day, value: -1, to: readings[start].day)
            }
        }
        return nil
    }

    static func standardDeviation(_ values: [Int]) -> Double {
        guard !values.isEmpty else { return 0 }
        let mean = Double(values.reduce(0, +)) / Double(values.count)
        let variance = values.map { (Double($0) - mean) * (Double($0) - mean) }.reduce(0, +) / Double(values.count)
        return variance.squareRoot()
    }
}
```

Ghi chú cho người làm: thứ tự ưu tiên trong `dayStatus` là kỳ kinh đã ghi → kỳ kinh dự đoán → `peak` → `fertile` → `low`. Ngày đã qua của một kỳ kinh bị lỡ (đang trễ) **không** được tô "dự đoán". Các chu kỳ sau chu kỳ hiện tại lặp lại dự đoán theo lịch (dùng cho tab Lịch).

- [ ] **Step 4: Chạy lại, xác nhận pass**

Run: `scripts/test-core.sh --filter CyclePredictorTests` → Expected: 30 test pass.
Run: `scripts/test-core.sh` → Expected: toàn bộ pass (229).

- [ ] **Step 5: Commit, push, xác minh CI**

```bash
git add Packages/KickCore
git commit -F - <<'MSG'
feat(core): predict next period, ovulation and fertile window

Calendar method adjusted by positive LH tests and confirmed by the BBT
3-over-6 rule; low confidence widens the window for irregular cycles.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`.

---

### Task 4: Nhắc chu kỳ (mở rộng `NotificationScheduler`)

**Files:**
- Create: `Packages/KickCore/Sources/KickCore/CycleReminders.swift`
- Test: `Packages/KickCore/Tests/KickCoreTests/CycleRemindersTests.swift`

**Interfaces:**
- Consumes: `NotificationScheduler` (`center` là `internal let`), `NotificationText.makeContent()` (internal), `FakeNotificationCenter` (TestSupport), `CycleForecast`, `CyclePredictor.lateNoticeDays` (Task 3).
- Produces:
  - `public enum CycleReminderKind: String, CaseIterable { case fertile, period, late; var identifier: String /* "cycle-<rawValue>" */ }`
  - `public struct CycleReminderTexts: Sendable { init(fertile: NotificationText, period: NotificationText, late: NotificationText) }`
  - `extension NotificationScheduler { public static let cycleReminderHour = 9; public static func cycleReminderFireDates(for: CycleForecast, calendar: Calendar = .current) -> [CycleReminderKind: Date]; @discardableResult public func scheduleCycleReminders(for: CycleForecast, now: Date, texts: CycleReminderTexts, calendar: Calendar = .current) async throws -> Set<CycleReminderKind>; public func cancelCycleReminders() }`

- [ ] **Step 1: Viết test trước**

`Packages/KickCore/Tests/KickCoreTests/CycleRemindersTests.swift`:
```swift
import Foundation
import Testing
@preconcurrency import UserNotifications
@testable import KickCore

@MainActor
struct CycleRemindersTests {
    let center = FakeNotificationCenter()
    let texts = CycleReminderTexts(
        fertile: NotificationText(title: "Fertile window soon", body: "Starts in 2 days"),
        period: NotificationText(title: "Period tomorrow", body: "Your period is due tomorrow"),
        late: NotificationText(title: "Period is late", body: "Consider a pregnancy test")
    )
    var scheduler: NotificationScheduler { NotificationScheduler(center: center) }

    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00Z") }

    /// Regular 28-day cycles; current period 2026-09-03 → window 09-12…09-18, next period 10-01.
    private func regularForecast() throws -> CycleForecast {
        let periods = ["2026-07-09", "2026-08-06", "2026-09-03"].map {
            PeriodRecord(startDate: day($0), endDate: utcCalendar.date(byAdding: .day, value: 4, to: day($0)))
        }
        return try #require(CyclePredictor.forecast(
            periods: periods, logs: [], settings: CycleSettings(), now: date("2026-09-05T12:00:00Z"), calendar: utcCalendar
        ))
    }

    private func components(_ id: String) -> [Int?] {
        let trigger = center.added.first { $0.identifier == id }?.trigger as? UNCalendarNotificationTrigger
        let c = trigger?.dateComponents
        return [c?.year, c?.month, c?.day, c?.hour, c?.minute]
    }

    @Test func fireDatesAre9OClockAroundTheForecast() throws {
        let dates = NotificationScheduler.cycleReminderFireDates(for: try regularForecast(), calendar: utcCalendar)
        #expect(dates[.fertile] == date("2026-09-10T09:00:00Z"))
        #expect(dates[.period] == date("2026-09-30T09:00:00Z"))
        #expect(dates[.late] == date("2026-10-04T09:00:00Z"))
    }

    @Test func schedulesAllThreeWithTheirTexts() async throws {
        let scheduled = try await scheduler.scheduleCycleReminders(
            for: try regularForecast(), now: date("2026-09-05T12:00:00Z"), texts: texts, calendar: utcCalendar
        )
        #expect(scheduled == [.fertile, .period, .late])
        #expect(Set(center.added.map(\.identifier)) == ["cycle-fertile", "cycle-period", "cycle-late"])
        #expect(components("cycle-fertile") == [2026, 9, 10, 9, 0])
        #expect(components("cycle-period") == [2026, 9, 30, 9, 0])
        #expect(components("cycle-late") == [2026, 10, 4, 9, 0])
        let fertile = try #require(center.added.first { $0.identifier == "cycle-fertile" })
        #expect(fertile.content.title == "Fertile window soon")
        #expect((fertile.trigger as? UNCalendarNotificationTrigger)?.repeats == false)
        #expect(center.added.first { $0.identifier == "cycle-late" }?.content.body == "Consider a pregnancy test")
    }

    @Test func remindersWhoseTimeHasPassedAreSkipped() async throws {
        // 2026-09-10 at 09:00 exactly: the fertile reminder is not in the future.
        let scheduled = try await scheduler.scheduleCycleReminders(
            for: try regularForecast(), now: date("2026-09-10T09:00:00Z"), texts: texts, calendar: utcCalendar
        )
        #expect(scheduled == [.period, .late])
        #expect(center.added.map(\.identifier).contains("cycle-fertile") == false)
    }

    @Test func onlyTheLateReminderRemainsOnceThePeriodIsDue() async throws {
        let scheduled = try await scheduler.scheduleCycleReminders(
            for: try regularForecast(), now: date("2026-10-02T12:00:00Z"), texts: texts, calendar: utcCalendar
        )
        #expect(scheduled == [.late])
    }

    @Test func reschedulingReplacesEarlierReminders() async throws {
        try await scheduler.scheduleCycleReminders(for: try regularForecast(), now: date("2026-09-05T12:00:00Z"), texts: texts, calendar: utcCalendar)
        try await scheduler.scheduleCycleReminders(for: try regularForecast(), now: date("2026-09-05T12:00:00Z"), texts: texts, calendar: utcCalendar)
        #expect(center.added.count == 3)
    }

    @Test func cancelRemovesEveryCycleReminderOnly() async throws {
        try await scheduler.scheduleCycleReminders(for: try regularForecast(), now: date("2026-09-05T12:00:00Z"), texts: texts, calendar: utcCalendar)
        try await scheduler.scheduleDailyReminder(hour: 20, minute: 0, text: texts.period)
        scheduler.cancelCycleReminders()
        #expect(center.added.map(\.identifier) == [NotificationScheduler.dailyReminderID])
        #expect(Set(center.removed).isSuperset(of: ["cycle-fertile", "cycle-period", "cycle-late"]))
    }
}
```

- [ ] **Step 2: Chạy, xác nhận fail**

Run: `scripts/test-core.sh --filter CycleRemindersTests`
Expected: lỗi biên dịch `cannot find 'CycleReminderTexts' in scope`.

- [ ] **Step 3: Viết code**

`Packages/KickCore/Sources/KickCore/CycleReminders.swift`:
```swift
import Foundation
@preconcurrency import UserNotifications

public enum CycleReminderKind: String, Sendable, CaseIterable {
    /// 2 days before the fertile window opens.
    case fertile
    /// 1 day before the next period is due.
    case period
    /// Once, when the period is 3 days late.
    case late

    public var identifier: String { "cycle-\(rawValue)" }
}

public struct CycleReminderTexts: Sendable {
    public let fertile: NotificationText
    public let period: NotificationText
    public let late: NotificationText

    public init(fertile: NotificationText, period: NotificationText, late: NotificationText) {
        self.fertile = fertile
        self.period = period
        self.late = late
    }

    func text(for kind: CycleReminderKind) -> NotificationText {
        switch kind {
        case .fertile: fertile
        case .period: period
        case .late: late
        }
    }
}

/// Cycle reminders at 9:00. Only `CycleCoordinator` calls these.
extension NotificationScheduler {
    public static let cycleReminderHour = 9
    static let fertileReminderLeadDays = 2
    static let periodReminderLeadDays = 1

    /// When each reminder for `forecast` would fire (9:00 local), past or not.
    public static func cycleReminderFireDates(for forecast: CycleForecast, calendar: Calendar = .current) -> [CycleReminderKind: Date] {
        func nineOClock(_ days: Int, from date: Date) -> Date? {
            guard let day = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: date)) else { return nil }
            return calendar.date(bySettingHour: cycleReminderHour, minute: 0, second: 0, of: day)
        }
        var dates: [CycleReminderKind: Date] = [:]
        dates[.fertile] = nineOClock(-fertileReminderLeadDays, from: forecast.fertileWindow.lowerBound)
        dates[.period] = nineOClock(-periodReminderLeadDays, from: forecast.nextPeriodStart)
        dates[.late] = nineOClock(CyclePredictor.lateNoticeDays, from: forecast.nextPeriodStart)
        return dates
    }

    /// Replaces all three cycle reminders with those for `forecast` whose time is
    /// still ahead of `now`. Returns the kinds that were scheduled.
    @discardableResult
    public func scheduleCycleReminders(
        for forecast: CycleForecast,
        now: Date,
        texts: CycleReminderTexts,
        calendar: Calendar = .current
    ) async throws -> Set<CycleReminderKind> {
        cancelCycleReminders()
        let fireDates = Self.cycleReminderFireDates(for: forecast, calendar: calendar)
        var scheduled: Set<CycleReminderKind> = []
        for kind in CycleReminderKind.allCases {
            guard let fireDate = fireDates[kind], fireDate > now else { continue }
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: kind.identifier, content: texts.text(for: kind).makeContent(), trigger: trigger
            )
            try await center.add(request)
            scheduled.insert(kind)
        }
        return scheduled
    }

    public func cancelCycleReminders() {
        center.removePending(ids: CycleReminderKind.allCases.map(\.identifier))
    }
}
```

- [ ] **Step 4: Chạy lại, xác nhận pass**

Run: `scripts/test-core.sh --filter CycleRemindersTests` → Expected: 6 test pass.
Run: `scripts/test-core.sh` → Expected: toàn bộ pass (235).

- [ ] **Step 5: Commit, push, xác minh CI**

```bash
git add Packages/KickCore
git commit -F - <<'MSG'
feat(core): schedule fertile-window, period and late-period reminders

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`.

---

### Task 5: `CycleCoordinator` (ghi dữ liệu, dự báo, nhắc, chuyển chế độ)

Cùng mẫu với `AppointmentCoordinator`: `@MainActor @Observable`, `load()` dùng chung một task đang chạy và **không** xin quyền, mọi thay đổi tăng `reminderGeneration`, đồng bộ nhắc kiểm tra lại sau mỗi `await` (nếu có thay đổi mới trong lúc chờ quyền hoặc chờ `center.add`, áp lại trạng thái mới nhất). Khác `AppointmentCoordinator` ở một điểm có chủ đích: nếu thế hệ đổi **sau khi** được cấp quyền, coordinator không bỏ qua mà đồng bộ lại theo trạng thái mới (để thay đổi xảy ra trong lúc hộp thoại quyền đang mở vẫn được đặt nhắc).

**Files:**
- Create: `Packages/KickCore/Sources/KickCore/CycleCoordinator.swift`
- Modify: `Packages/KickCore/Tests/KickCoreTests/TestSupport.swift` (thêm `FakeCycleRepository` ở cuối file)
- Test: `Packages/KickCore/Tests/KickCoreTests/CycleCoordinatorTests.swift`

**Interfaces:**
- Consumes: `CycleRepository`, `CycleRules`, `PeriodRecord`, `CycleLogRecord`, `CycleRepositoryError` (Task 2); `CyclePredictor`, `CycleForecast` (Task 3); `NotificationScheduler.scheduleCycleReminders/cancelCycleReminders`, `CycleReminderTexts` (Task 4); `AppMode`, `CycleSettings` (Task 1); `PregnancyProfile.save(source:date:to:calendar:)`, `PregnancyDateSource`, `NotificationScheduler.requestAuthorizationIfNeeded/isAuthorized/isDenied` (có sẵn); test: `FakeNotificationCenter`, `TestClock`, `waitUntil`, `utcCalendar`, `date(_:)`, `makeTestDefaults()`.
- Produces:
  - `public enum CycleFailure: Equatable, Sendable { case loadFailed, saveFailed, futureDate, endBeforeStart, overlapsExistingPeriod, invalidTemperature }`
  - `@MainActor @Observable public final class CycleCoordinator` với `init(store: CycleRepository, notifications: NotificationScheduler, reminderTexts: CycleReminderTexts, defaults: UserDefaults, calendar: Calendar = .current, now: @escaping @MainActor () -> Date = { Date() })`; trạng thái `public private(set) var periods: [PeriodRecord]`, `logs: [CycleLogRecord]`, `forecast: CycleForecast?`, `settings: CycleSettings`, `failure: CycleFailure?`, `notificationsDenied: Bool`; `public var mode: AppMode`; `func log(on: Date) -> CycleLogRecord?`; `func period(on: Date) -> PeriodRecord?`; `func load() async`; `@discardableResult func startPeriod(on: Date) async -> CycleFailure?`; `logLastPeriod(startingOn: Date) async -> CycleFailure?`; `endPeriod(id: UUID, on: Date) async -> CycleFailure?`; `updatePeriod(_: PeriodRecord) async -> CycleFailure?`; `deletePeriod(id: UUID) async -> CycleFailure?`; `saveLog(_: CycleLogRecord) async -> CycleFailure?`; `func updateSettings(_: CycleSettings) async`; `func activateTryingToConceive() async`; `func switchToPregnant(source: PregnancyDateSource, date: Date)`; `func clearFailure()`.
  - Test fake `@MainActor final class FakeCycleRepository: CycleRepository` (`storedPeriods`, `storedLogs`, `failNextRead`, `failNextWrite`, `periodReads`, `seed(periods:logs:)`).

- [ ] **Step 1: Viết test trước**

Thêm vào cuối `Packages/KickCore/Tests/KickCoreTests/TestSupport.swift`:
```swift

/// In-memory CycleRepository with the same rules as CycleStore.
@MainActor
final class FakeCycleRepository: CycleRepository {
    struct Failed: Error {}

    private(set) var storedPeriods: [PeriodRecord] = []
    private(set) var storedLogs: [CycleLogRecord] = []
    var calendar = utcCalendar
    var failNextRead = false
    var failNextWrite = false

    func seed(periods: [PeriodRecord] = [], logs: [CycleLogRecord] = []) {
        storedPeriods += periods
        storedLogs += logs
    }

    private func checkRead() throws {
        if failNextRead {
            failNextRead = false
            throw Failed()
        }
    }

    private func checkWrite() throws {
        if failNextWrite {
            failNextWrite = false
            throw Failed()
        }
    }

    private(set) var periodReads = 0

    func periods() throws -> [PeriodRecord] {
        try checkRead()
        periodReads += 1
        let merged = CycleRules.mergingDuplicates(storedPeriods, calendar: calendar)
        storedPeriods = merged.periods
        return merged.periods
    }

    func logs() throws -> [CycleLogRecord] {
        try checkRead()
        let merged = CycleRules.mergingDuplicates(storedLogs, calendar: calendar)
        storedLogs = merged.logs
        return merged.logs
    }

    func addPeriod(_ period: PeriodRecord, today: Date) throws {
        try CycleRules.validate(period, existing: storedPeriods, today: today, calendar: calendar)
        try checkWrite()
        storedPeriods.append(CycleRules.normalized(period, calendar: calendar))
    }

    func updatePeriod(_ period: PeriodRecord, today: Date) throws {
        guard let index = storedPeriods.firstIndex(where: { $0.id == period.id }) else {
            throw CycleRepositoryError.notFound
        }
        try CycleRules.validate(period, existing: storedPeriods, today: today, calendar: calendar)
        try checkWrite()
        storedPeriods[index] = CycleRules.normalized(period, calendar: calendar)
    }

    func deletePeriod(id: UUID) throws {
        try checkWrite()
        storedPeriods.removeAll { $0.id == id }
    }

    func saveLog(_ log: CycleLogRecord, today: Date) throws {
        let normalized = CycleRules.normalized(log, calendar: calendar)
        try CycleRules.validate(normalized, today: today, calendar: calendar)
        try checkWrite()
        let existing = storedLogs.first { $0.day == normalized.day }
        storedLogs.removeAll { $0.day == normalized.day }
        guard !normalized.isEmpty else { return }
        var saved = normalized
        if let existing {
            saved = CycleLogRecord(
                id: existing.id, day: normalized.day, lh: normalized.lh,
                bbtCelsius: normalized.bbtCelsius, mucus: normalized.mucus, note: normalized.note
            )
        }
        storedLogs.append(saved)
    }
}
```

`Packages/KickCore/Tests/KickCoreTests/CycleCoordinatorTests.swift`:
```swift
import Foundation
import Testing
@preconcurrency import UserNotifications
@testable import KickCore

@MainActor
struct CycleCoordinatorTests {
    let repository: FakeCycleRepository
    let center: FakeNotificationCenter
    let clock: TestClock
    let defaults: UserDefaults
    let coordinator: CycleCoordinator

    init() {
        let repository = FakeCycleRepository()
        let center = FakeNotificationCenter()
        let clock = TestClock(date("2026-09-05T12:00:00Z"))
        let defaults = makeTestDefaults()
        AppMode.save(.tryingToConceive, to: defaults)
        self.repository = repository
        self.center = center
        self.clock = clock
        self.defaults = defaults
        coordinator = CycleCoordinator(
            store: repository,
            notifications: NotificationScheduler(center: center),
            reminderTexts: CycleReminderTexts(
                fertile: NotificationText(title: "Fertile window soon", body: "In 2 days"),
                period: NotificationText(title: "Period tomorrow", body: "Due tomorrow"),
                late: NotificationText(title: "Period is late", body: "Consider a test")
            ),
            defaults: defaults,
            calendar: utcCalendar,
            now: { clock.now }
        )
    }

    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00Z") }

    /// Regular 28-day cycles; current period 2026-09-03 → window 09-12…09-18, next period 10-01.
    private func seedRegularCycles() {
        repository.seed(periods: ["2026-07-09", "2026-08-06", "2026-09-03"].map {
            PeriodRecord(startDate: day($0), endDate: utcCalendar.date(byAdding: .day, value: 4, to: day($0)))
        })
    }

    private func reminderDay(_ kind: CycleReminderKind) -> Int? {
        (center.added.first { $0.identifier == kind.identifier }?.trigger as? UNCalendarNotificationTrigger)?.dateComponents.day
    }

    private var reminderIDs: Set<String> { Set(center.added.map(\.identifier)) }

    // MARK: - Loading

    @Test func loadComputesTheForecastAndSchedulesReminders() async throws {
        seedRegularCycles()
        await coordinator.load()
        #expect(coordinator.periods.count == 3)
        let forecast = try #require(coordinator.forecast)
        #expect(forecast.cycleDay == 3)
        #expect(forecast.nextPeriodStart == day("2026-10-01"))
        #expect(reminderIDs == ["cycle-fertile", "cycle-period", "cycle-late"])
        #expect(reminderDay(.fertile) == 10)
    }

    @Test func loadNeverPromptsForPermission() async {
        seedRegularCycles()
        center.status = .notDetermined
        await coordinator.load()
        #expect(center.requestCount == 0)
        #expect(center.added.isEmpty)
        #expect(coordinator.notificationsDenied == false)
    }

    @Test func loadInPregnancyModeCancelsCycleReminders() async {
        seedRegularCycles()
        AppMode.save(.pregnant, to: defaults)
        await coordinator.load()
        #expect(coordinator.forecast != nil)
        #expect(center.added.isEmpty)
        #expect(center.removed.contains("cycle-fertile"))
    }

    @Test func loadWithNoDataHasNoForecastOrReminders() async {
        await coordinator.load()
        #expect(coordinator.forecast == nil)
        #expect(center.added.isEmpty)
    }

    @Test func failedLoadReportsLoadFailure() async {
        repository.failNextRead = true
        await coordinator.load()
        #expect(coordinator.failure == .loadFailed)
        coordinator.clearFailure()
        #expect(coordinator.failure == nil)
    }

    @Test func concurrentLoadsShareOneRefresh() async throws {
        seedRegularCycles()
        center.holdAuthorizationStatus = true
        async let first: Void = coordinator.load() // suspends in isAuthorized()
        defer { center.releaseAuthorizationStatus() }
        try await waitUntil(center.authorizationStatusPending)
        async let second: Void = coordinator.load()
        await Task.yield()
        center.releaseAuthorizationStatus()
        _ = await (first, second)
        #expect(repository.periodReads == 1)
    }

    // MARK: - Periods

    @Test func startingAPeriodSavesItAndPromptsOnce() async throws {
        center.status = .notDetermined
        let failure = await coordinator.startPeriod(on: date("2026-09-05T08:00:00Z"))
        #expect(failure == nil)
        #expect(repository.storedPeriods == [PeriodRecord(id: try #require(coordinator.periods.first?.id), startDate: day("2026-09-05"))])
        #expect(coordinator.forecast?.cycleDay == 1)
        #expect(center.requestCount == 1)
        // One period: 28-day default → next period 10-03, window 09-14…09-20.
        #expect(reminderDay(.fertile) == 12)
        #expect(reminderDay(.period) == 2)
    }

    @Test func lastPeriodFromItsFirstDayUsesTheTypicalLength() async {
        await coordinator.updateSettings(CycleSettings(typicalPeriodLength: 4))
        #expect(await coordinator.logLastPeriod(startingOn: day("2026-08-20")) == nil)
        #expect(coordinator.periods.first?.endDate == day("2026-08-23"))
        #expect(coordinator.forecast?.cycleDay == 17)
    }

    @Test func futurePeriodIsRefusedWithoutAnAlert() async {
        let failure = await coordinator.startPeriod(on: day("2026-09-06"))
        #expect(failure == .futureDate)
        #expect(coordinator.failure == nil)
        #expect(repository.storedPeriods.isEmpty)
    }

    @Test func overlappingPeriodIsRefused() async {
        seedRegularCycles()
        await coordinator.load()
        let failure = await coordinator.startPeriod(on: day("2026-09-05"))
        #expect(failure == .overlapsExistingPeriod)
        #expect(coordinator.periods.count == 3)
    }

    @Test func endingThePeriodStoresTheEndDay() async throws {
        await coordinator.startPeriod(on: day("2026-09-01"))
        let id = try #require(coordinator.periods.first?.id)
        let failure = await coordinator.endPeriod(id: id, on: date("2026-09-04T20:00:00Z"))
        #expect(failure == nil)
        #expect(coordinator.periods.first?.endDate == day("2026-09-04"))
        #expect(coordinator.forecast?.openPeriod == nil)
    }

    @Test func endBeforeStartIsRefused() async throws {
        await coordinator.startPeriod(on: day("2026-09-03"))
        let id = try #require(coordinator.periods.first?.id)
        #expect(await coordinator.endPeriod(id: id, on: day("2026-09-01")) == .endBeforeStart)
        #expect(coordinator.periods.first?.endDate == nil)
    }

    @Test func endingAnUnknownPeriodIsASaveFailure() async {
        #expect(await coordinator.endPeriod(id: UUID(), on: day("2026-09-04")) == .saveFailed)
        #expect(coordinator.failure == .saveFailed)
    }

    @Test func deletingThePeriodRemovesTheForecastAndReminders() async throws {
        await coordinator.startPeriod(on: day("2026-09-05"))
        let id = try #require(coordinator.periods.first?.id)
        #expect(await coordinator.deletePeriod(id: id) == nil)
        #expect(coordinator.forecast == nil)
        #expect(center.added.isEmpty)
    }

    @Test func failedWriteReportsSaveFailureAndSchedulesNothing() async {
        repository.failNextWrite = true
        #expect(await coordinator.startPeriod(on: day("2026-09-05")) == .saveFailed)
        #expect(coordinator.failure == .saveFailed)
        #expect(coordinator.periods.isEmpty)
        #expect(center.added.isEmpty)
    }

    @Test func periodLookupFindsTheCoveringPeriod() async {
        seedRegularCycles()
        await coordinator.load()
        #expect(coordinator.period(on: date("2026-09-06T15:00:00Z"))?.startDate == day("2026-09-03"))
        #expect(coordinator.period(on: day("2026-09-08")) == nil)
    }

    // MARK: - Day logs

    @Test func positiveLHTestMovesOvulationAndTheFertileReminder() async throws {
        seedRegularCycles()
        clock.now = date("2026-09-09T07:00:00Z")
        await coordinator.load()
        #expect(coordinator.forecast?.ovulationDate == day("2026-09-17"))
        #expect(reminderDay(.fertile) == 10)

        let failure = await coordinator.saveLog(CycleLogRecord(day: clock.now, lh: .positive, note: " Strong line "))
        #expect(failure == nil)
        #expect(coordinator.log(on: day("2026-09-09"))?.note == "Strong line")
        #expect(coordinator.forecast?.ovulationDate == day("2026-09-10"))
        #expect(coordinator.forecast?.ovulationSource == .lhTest)
        // Window 09-05…09-11 → the fertile reminder (09-03) has passed.
        #expect(reminderIDs == ["cycle-period", "cycle-late"])
    }

    @Test func implausibleTemperatureIsRefused() async {
        let failure = await coordinator.saveLog(CycleLogRecord(day: day("2026-09-05"), bbtCelsius: 39.2))
        #expect(failure == .invalidTemperature)
        #expect(coordinator.failure == nil)
        #expect(repository.storedLogs.isEmpty)
    }

    @Test func emptyLogRemovesTheDay() async {
        await coordinator.saveLog(CycleLogRecord(day: day("2026-09-05"), mucus: .creamy))
        #expect(coordinator.logs.count == 1)
        await coordinator.saveLog(CycleLogRecord(day: day("2026-09-05")))
        #expect(coordinator.logs.isEmpty)
        #expect(coordinator.log(on: day("2026-09-05")) == nil)
    }

    // MARK: - Settings

    @Test func typicalCycleLengthDrivesASinglePeriodForecast() async {
        await coordinator.startPeriod(on: day("2026-09-01"))
        #expect(coordinator.forecast?.nextPeriodStart == day("2026-09-29"))
        await coordinator.updateSettings(CycleSettings(typicalCycleLength: 32, typicalPeriodLength: 4))
        #expect(coordinator.settings.typicalCycleLength == 32)
        #expect(defaults.integer(forKey: SettingsKey.typicalCycleLength) == 32)
        #expect(coordinator.forecast?.nextPeriodStart == day("2026-10-03"))
        #expect(reminderDay(.period) == 2)
    }

    @Test func turningRemindersOffCancelsThemAndOnSchedulesAgain() async {
        seedRegularCycles()
        await coordinator.load()
        await coordinator.updateSettings(CycleSettings(remindersEnabled: false))
        #expect(center.added.isEmpty)
        #expect(defaults.bool(forKey: SettingsKey.cycleRemindersEnabled) == false)
        await coordinator.updateSettings(CycleSettings(remindersEnabled: true))
        #expect(reminderIDs == ["cycle-fertile", "cycle-period", "cycle-late"])
    }

    @Test func deniedNotificationsStillSaveAndRaiseTheHint() async {
        center.status = .denied
        #expect(await coordinator.startPeriod(on: day("2026-09-05")) == nil)
        #expect(coordinator.periods.count == 1)
        #expect(center.added.isEmpty)
        #expect(coordinator.notificationsDenied)
    }

    // MARK: - Mode

    @Test func imPregnantStoresTheLastPeriodSwitchesModeAndCancelsReminders() async throws {
        seedRegularCycles()
        await coordinator.load()
        #expect(center.added.count == 3)
        let lastPeriod = try #require(coordinator.forecast?.currentPeriodStart)

        coordinator.switchToPregnant(source: .lmp, date: lastPeriod)

        #expect(coordinator.mode == .pregnant)
        #expect(AppMode.load(from: defaults) == .pregnant)
        let profile = PregnancyProfile.load(from: defaults)
        #expect(profile.source == .lmp)
        #expect(profile.lmpDate == day("2026-09-03"))
        #expect(profile.dueDate == day("2027-06-10"))
        #expect(center.added.isEmpty)
        #expect(repository.storedPeriods.count == 3)
        // A later load in pregnancy mode keeps them cancelled.
        await coordinator.load()
        #expect(center.added.isEmpty)
    }

    @Test func switchingToTryingToConceiveKeepsPregnancyDataAndSchedulesReminders() async {
        AppMode.save(.pregnant, to: defaults)
        PregnancyProfile.saveDueDate(date("2027-01-19T12:00:00Z"), to: defaults)
        seedRegularCycles()
        await coordinator.load()
        #expect(center.added.isEmpty)

        await coordinator.activateTryingToConceive()

        #expect(coordinator.mode == .tryingToConceive)
        #expect(PregnancyProfile.load(from: defaults).dueDate == date("2027-01-19T12:00:00Z"))
        #expect(reminderIDs == ["cycle-fertile", "cycle-period", "cycle-late"])
    }

    // MARK: - Re-entrancy

    @Test func imPregnantWhileThePermissionPromptIsOpenLeavesNoReminders() async throws {
        center.status = .notDetermined
        center.holdRequestAuthorization = true

        async let starting = coordinator.startPeriod(on: day("2026-09-05")) // suspends on the prompt
        defer { center.releaseRequestAuthorization() }
        try await waitUntil(center.requestAuthorizationPending)

        coordinator.switchToPregnant(source: .lmp, date: day("2026-09-05"))
        center.releaseRequestAuthorization()
        _ = await starting

        #expect(center.added.isEmpty)
        #expect(coordinator.mode == .pregnant)
    }

    @Test func changeDuringThePromptIsScheduledOnceGranted() async throws {
        seedRegularCycles()
        center.status = .notDetermined
        center.holdRequestAuthorization = true

        async let saving = coordinator.saveLog(CycleLogRecord(day: day("2026-09-05"), mucus: .sticky))
        defer { center.releaseRequestAuthorization() }
        try await waitUntil(center.requestAuthorizationPending)

        // A second change while the prompt is still open (status is still "not determined").
        _ = await coordinator.updateSettings(CycleSettings(typicalCycleLength: 30))
        center.releaseRequestAuthorization()
        _ = await saving

        #expect(reminderIDs == ["cycle-fertile", "cycle-period", "cycle-late"])
    }

    @Test func imPregnantWhileSchedulingIsInFlightRemovesTheReminders() async throws {
        seedRegularCycles()
        await coordinator.load()
        center.holdAdd = true

        async let saving = coordinator.saveLog(CycleLogRecord(day: day("2026-09-05"), mucus: .creamy)) // suspends in center.add
        defer { center.releaseAdd() }
        try await waitUntil(center.addPending)

        coordinator.switchToPregnant(source: .lmp, date: day("2026-09-03"))
        center.releaseAdd()
        _ = await saving

        #expect(center.added.isEmpty)
    }

    @Test func newestForecastWinsWhenAnOlderScheduleLandsLast() async throws {
        seedRegularCycles()
        clock.now = date("2026-09-09T07:00:00Z")
        await coordinator.load()
        center.holdAdd = true

        async let first = coordinator.saveLog(CycleLogRecord(day: day("2026-09-08"), mucus: .creamy)) // suspends in center.add
        defer { center.releaseAdd() }
        try await waitUntil(center.addPending)

        // LH positive today: ovulation 09-10, window 09-05…09-11 → no fertile reminder.
        await coordinator.saveLog(CycleLogRecord(day: day("2026-09-09"), lh: .positive))
        center.releaseAdd()
        _ = await first

        #expect(reminderIDs == ["cycle-period", "cycle-late"])
    }
}
```

- [ ] **Step 2: Chạy, xác nhận fail**

Run: `scripts/test-core.sh --filter CycleCoordinatorTests`
Expected: lỗi biên dịch `cannot find 'CycleCoordinator' in scope`.

- [ ] **Step 3: Viết code**

`Packages/KickCore/Sources/KickCore/CycleCoordinator.swift`:
```swift
import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "cycle")

public enum CycleFailure: Equatable, Sendable {
    case loadFailed
    case saveFailed
    case futureDate
    case endBeforeStart
    case overlapsExistingPeriod
    case invalidTemperature

    init(_ error: Error) {
        switch error as? CycleRepositoryError {
        case .futureDate?: self = .futureDate
        case .endBeforeStart?: self = .endBeforeStart
        case .overlapsExistingPeriod?: self = .overlapsExistingPeriod
        case .invalidTemperature?: self = .invalidTemperature
        case .notFound?, nil: self = .saveFailed
        }
    }
}

/// Single entry point for cycle data, cycle settings and switching mode, used
/// by the UI. Keeps the repository, the forecast and the three cycle reminders
/// in step: the store never touches notifications, and nothing else schedules
/// cycle reminders.
///
/// Every change bumps `reminderGeneration`. A reminder sync captures it and
/// re-checks it after each `await`, so a change made while a permission prompt
/// or a scheduling request is in flight (e.g. "I'm pregnant") always wins.
@MainActor
@Observable
public final class CycleCoordinator {
    public private(set) var periods: [PeriodRecord] = []
    public private(set) var logs: [CycleLogRecord] = []
    public private(set) var forecast: CycleForecast?
    public private(set) var settings: CycleSettings
    /// Store errors for the screen to show; validation errors are only returned.
    public private(set) var failure: CycleFailure?
    /// True when the user has turned notifications off; the UI shows a hint.
    public private(set) var notificationsDenied = false

    private let store: CycleRepository
    private let notifications: NotificationScheduler
    private let reminderTexts: CycleReminderTexts
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let now: @MainActor () -> Date

    private var reminderGeneration = 0
    /// The in-flight `load()`, so concurrent callers share one refresh.
    private var loadTask: Task<Void, Never>?

    public init(
        store: CycleRepository,
        notifications: NotificationScheduler,
        reminderTexts: CycleReminderTexts,
        defaults: UserDefaults,
        calendar: Calendar = .current,
        now: @escaping @MainActor () -> Date = { Date() }
    ) {
        self.store = store
        self.notifications = notifications
        self.reminderTexts = reminderTexts
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
        settings = CycleSettings.load(from: defaults)
    }

    public var mode: AppMode { AppMode.load(from: defaults) }

    /// The log for that calendar day, if any.
    public func log(on day: Date) -> CycleLogRecord? {
        let start = calendar.startOfDay(for: day)
        return logs.first { $0.day == start }
    }

    /// The logged period covering that day, if any.
    public func period(on day: Date) -> PeriodRecord? {
        let start = calendar.startOfDay(for: day)
        let today = now()
        return periods.last { CycleRules.dayRange(of: $0, today: today, calendar: calendar).contains(start) }
    }

    /// Re-reads the store (e.g. after iCloud sync) and reconciles reminders.
    /// Call on launch and whenever the app becomes active. Never prompts for permission.
    public func load() async {
        if let loadTask {
            await loadTask.value
            return
        }
        let task = Task { await self.performLoad() }
        loadTask = task
        await task.value
        loadTask = nil
    }

    private func performLoad() async {
        guard refresh() else { return }
        await syncReminders(generation: reminderGeneration, mayPrompt: false)
    }

    // MARK: - Periods

    @discardableResult
    public func startPeriod(on day: Date) async -> CycleFailure? {
        let record = PeriodRecord(startDate: calendar.startOfDay(for: day))
        return await write { try store.addPeriod(record, today: now()) }
    }

    /// Stores the last period from its first day alone (onboarding, empty Cycle
    /// tab), assuming the typical period length when it is already over.
    @discardableResult
    public func logLastPeriod(startingOn day: Date) async -> CycleFailure? {
        let record = CycleRules.assumedPeriod(
            startingOn: day, typicalLength: settings.typicalPeriodLength, today: now(), calendar: calendar
        )
        return await write { try store.addPeriod(record, today: now()) }
    }

    @discardableResult
    public func endPeriod(id: UUID, on day: Date) async -> CycleFailure? {
        guard var record = periods.first(where: { $0.id == id }) else { return report(.saveFailed) }
        record.endDate = calendar.startOfDay(for: day)
        return await write { [record] in try store.updatePeriod(record, today: now()) }
    }

    @discardableResult
    public func updatePeriod(_ period: PeriodRecord) async -> CycleFailure? {
        await write { try store.updatePeriod(period, today: now()) }
    }

    @discardableResult
    public func deletePeriod(id: UUID) async -> CycleFailure? {
        await write { try store.deletePeriod(id: id) }
    }

    // MARK: - Day logs

    /// Saves the day's log (an empty log removes it). Temperatures outside
    /// 35.0–38.5 °C and future days are refused.
    @discardableResult
    public func saveLog(_ log: CycleLogRecord) async -> CycleFailure? {
        await write { try store.saveLog(log, today: now()) }
    }

    // MARK: - Settings and mode

    public func updateSettings(_ newSettings: CycleSettings) async {
        newSettings.save(to: defaults)
        settings = CycleSettings.load(from: defaults)
        recomputeForecast()
        await syncReminders(generation: bump(), mayPrompt: settings.remindersEnabled)
    }

    /// Onboarding or Settings chose "Trying to conceive". Pregnancy data,
    /// appointments and their reminders are left as they are.
    public func activateTryingToConceive() async {
        AppMode.save(.tryingToConceive, to: defaults)
        guard refresh() else { return }
        await syncReminders(generation: bump(), mayPrompt: true)
    }

    /// "I'm pregnant": stores the pregnancy dates (usually the first day of the
    /// latest period), switches to pregnancy mode and cancels cycle reminders.
    /// Cycle data is kept.
    public func switchToPregnant(source: PregnancyDateSource, date: Date) {
        PregnancyProfile.save(source: source, date: date, to: defaults, calendar: calendar)
        AppMode.save(.pregnant, to: defaults)
        bump()
        notifications.cancelCycleReminders()
    }

    public func clearFailure() {
        failure = nil
    }

    // MARK: - Internals

    private func write(_ change: () throws -> Void) async -> CycleFailure? {
        do {
            try change()
        } catch {
            logger.error("Saving cycle data failed: \(error.localizedDescription)")
            return report(CycleFailure(error))
        }
        refresh()
        await syncReminders(generation: bump(), mayPrompt: true)
        return nil
    }

    /// Store errors also go to `failure` for the screen's alert.
    private func report(_ failure: CycleFailure) -> CycleFailure {
        if failure == .saveFailed { self.failure = .saveFailed }
        return failure
    }

    private var wantsReminders: Bool {
        mode == .tryingToConceive && settings.remindersEnabled && forecast != nil
    }

    /// Brings the three cycle reminders in line with the current forecast.
    /// `generation` is the value captured when the triggering change happened:
    /// if a newer change lands during an `await`, the newest state is re-applied.
    private func syncReminders(generation: Int, mayPrompt: Bool) async {
        guard wantsReminders else {
            notifications.cancelCycleReminders()
            return
        }
        let authorized: Bool
        if mayPrompt {
            authorized = await notifications.requestAuthorizationIfNeeded()
        } else {
            authorized = await notifications.isAuthorized()
        }
        await updateDeniedHint(authorized: authorized)
        guard authorized else { return }
        guard generation == reminderGeneration else {
            await syncReminders(generation: reminderGeneration, mayPrompt: false)
            return
        }
        guard wantsReminders, let forecast else {
            notifications.cancelCycleReminders()
            return
        }
        do {
            try await notifications.scheduleCycleReminders(for: forecast, now: now(), texts: reminderTexts, calendar: calendar)
        } catch {
            logger.error("Scheduling cycle reminders failed: \(error.localizedDescription)")
            return
        }
        // Changed while the requests were in flight: re-apply the newest state.
        if generation != reminderGeneration {
            await syncReminders(generation: reminderGeneration, mayPrompt: false)
        }
    }

    private func updateDeniedHint(authorized: Bool) async {
        if authorized {
            notificationsDenied = false
        } else {
            notificationsDenied = await notifications.isDenied()
        }
    }

    @discardableResult
    private func refresh() -> Bool {
        settings = CycleSettings.load(from: defaults)
        do {
            periods = try store.periods()
            logs = try store.logs()
        } catch {
            logger.error("Loading cycle data failed: \(error.localizedDescription)")
            failure = .loadFailed
            return false
        }
        recomputeForecast()
        return true
    }

    private func recomputeForecast() {
        forecast = CyclePredictor.forecast(periods: periods, logs: logs, settings: settings, now: now(), calendar: calendar)
    }

    @discardableResult
    private func bump() -> Int {
        reminderGeneration += 1
        return reminderGeneration
    }
}
```

- [ ] **Step 4: Chạy lại, xác nhận pass**

Run: `scripts/test-core.sh --filter CycleCoordinatorTests` → Expected: 28 test pass, không test nào treo (mọi test có cổng chặn đều `defer { center.release…() }` ngay sau `async let` và chờ bằng `waitUntil`).
Run: `scripts/test-core.sh` → Expected: toàn bộ pass (263).

- [ ] **Step 5: Commit, push, xác minh CI**

```bash
git add Packages/KickCore
git commit -F - <<'MSG'
feat(core): add CycleCoordinator for cycle data, reminders and mode switching

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`.

---

### Task 6: Dữ liệu mẫu `-seedCycles`, bố cục lịch tháng

**Files:**
- Create: `Packages/KickCore/Sources/KickCore/CycleSeed.swift`, `Packages/KickCore/Sources/KickCore/CycleCalendarGrid.swift`
- Modify: `Packages/KickCore/Sources/KickCore/UITestLaunchOptions.swift` (thay toàn bộ file)
- Test: `Packages/KickCore/Tests/KickCoreTests/CycleSeedTests.swift`, `Packages/KickCore/Tests/KickCoreTests/UITestLaunchOptionsTests.swift` (thêm suite ở cuối)

**Interfaces:**
- Consumes: `PeriodRecord`, `CycleLogRecord`, `CycleRules.validate` (Task 2), `CyclePredictor` (Task 3).
- Produces:
  - `public enum CycleSeedScenario: String, Sendable, CaseIterable { case empty, period, fertile, late, irregular; struct Records: Equatable, Sendable { let periods: [PeriodRecord]; let logs: [CycleLogRecord] }; func records(today: Date, calendar: Calendar = .current) -> Records }`. Với `now` = 2026-10-02: `period` = ngày 2 của chu kỳ, đang hành kinh; `fertile` = ngày 13, trong cửa sổ 29/09–05/10, rụng trứng 04/10, kỳ sau 18/10, có log BBT/dịch nhầy/LH âm tính hôm qua; `late` = trễ 4 ngày (kỳ cuối 31/08, ngày 33); `irregular` = chu kỳ 24/35/26/34, ngày 11, độ tin cậy thấp + cảnh báo.
  - `UITestLaunchOptions.seedCycles: CycleSeedScenario?` (chỉ với `-uiTesting`, tên lạ → `nil`).
  - `public enum CycleCalendarGrid { static func startOfMonth(_: Date, calendar: Calendar = .current) -> Date; static func month(_ offset: Int, from: Date, calendar: Calendar = .current) -> Date; static func days(inMonthOf: Date, calendar: Calendar = .current) -> [Date?] /* nil = ô trống đầu tháng theo firstWeekday */; static func weekdaySymbols(calendar: Calendar = .current) -> [String] }`

- [ ] **Step 1: Viết test trước**

`Packages/KickCore/Tests/KickCoreTests/CycleSeedTests.swift`:
```swift
import Foundation
import Testing
@testable import KickCore

/// The seeded scenarios must show what the screenshots claim (fixed now 2026-10-02).
struct CycleSeedTests {
    let now = date("2026-10-02T12:00:00Z")

    private func forecast(_ scenario: CycleSeedScenario) -> CycleForecast? {
        let records = scenario.records(today: now, calendar: utcCalendar)
        return CyclePredictor.forecast(periods: records.periods, logs: records.logs, settings: CycleSettings(), now: now, calendar: utcCalendar)
    }

    @Test func emptyHasNoData() {
        #expect(CycleSeedScenario.empty.records(today: now, calendar: utcCalendar) == .init(periods: [], logs: []))
        #expect(forecast(.empty) == nil)
    }

    @Test func periodIsOnCycleDayTwoWithAnOpenPeriod() throws {
        let result = try #require(forecast(.period))
        #expect(result.cycleDay == 2)
        #expect(result.openPeriod != nil)
        #expect(result.dayStatus(for: now) == .period(isPredicted: false))
        #expect(result.confidence == .normal)
    }

    @Test func fertileIsInsideTheWindowWithOvulationInTwoDays() throws {
        let result = try #require(forecast(.fertile))
        #expect(result.cycleDay == 13)
        #expect(result.dayStatus(for: now) == .fertile)
        #expect(result.ovulationDate == date("2026-10-04T00:00:00Z"))
        #expect(result.nextPeriodStart == date("2026-10-18T00:00:00Z"))
        #expect(result.ovulationSource == .calendar)
    }

    @Test func positiveLHTodayMovesOvulationToTomorrow() throws {
        var records = CycleSeedScenario.fertile.records(today: now, calendar: utcCalendar)
        var logs = records.logs
        logs[logs.count - 1].lh = .positive
        records = .init(periods: records.periods, logs: logs)
        let result = try #require(CyclePredictor.forecast(periods: records.periods, logs: records.logs, settings: CycleSettings(), now: now, calendar: utcCalendar))
        #expect(result.ovulationDate == date("2026-10-03T00:00:00Z"))
    }

    @Test func lateIsFourDaysLate() throws {
        let result = try #require(forecast(.late))
        #expect(result.daysLate == 4)
        #expect(result.cycleDay == 33)
        #expect(result.currentPeriodStart == date("2026-08-31T00:00:00Z"))
    }

    @Test func irregularHasLowConfidenceAndTheWarning() throws {
        let result = try #require(forecast(.irregular))
        #expect(result.cycleDay == 11)
        #expect(result.usableCycleLengths == [24, 35, 26, 34])
        #expect(result.confidence == .low)
        #expect(result.irregularWarning)
        #expect(result.dayStatus(for: now) == .fertile)
    }

    @Test func seededDataPassesTheStoreRules() throws {
        for scenario in CycleSeedScenario.allCases {
            let records = scenario.records(today: now, calendar: utcCalendar)
            var accepted: [PeriodRecord] = []
            for period in records.periods {
                try CycleRules.validate(period, existing: accepted, today: now, calendar: utcCalendar)
                accepted.append(period)
            }
            for log in records.logs {
                try CycleRules.validate(log, today: now, calendar: utcCalendar)
            }
        }
    }
}

struct CycleCalendarGridTests {
    private func calendar(firstWeekday: Int, locale: String) -> Calendar {
        var calendar = utcCalendar
        calendar.firstWeekday = firstWeekday
        calendar.locale = Locale(identifier: locale)
        return calendar
    }

    @Test func october2026StartsOnThursday() {
        let sundayFirst = calendar(firstWeekday: 1, locale: "en_US")
        let days = CycleCalendarGrid.days(inMonthOf: date("2026-10-15T12:00:00Z"), calendar: sundayFirst)
        #expect(days.prefix(4).allSatisfy { $0 == nil })
        #expect(days[4] == date("2026-10-01T00:00:00Z"))
        #expect(days.compactMap { $0 }.count == 31)
        #expect(days.last == date("2026-10-31T00:00:00Z"))

        let mondayFirst = calendar(firstWeekday: 2, locale: "vi_VN")
        let vietnamese = CycleCalendarGrid.days(inMonthOf: date("2026-10-15T12:00:00Z"), calendar: mondayFirst)
        #expect(vietnamese.prefix(3).allSatisfy { $0 == nil })
        #expect(vietnamese[3] == date("2026-10-01T00:00:00Z"))
    }

    @Test func monthStartingOnTheFirstWeekdayHasNoBlanks() {
        // 2026-02-01 is a Sunday.
        let days = CycleCalendarGrid.days(inMonthOf: date("2026-02-10T00:00:00Z"), calendar: calendar(firstWeekday: 1, locale: "en_US"))
        #expect(days.first == date("2026-02-01T00:00:00Z"))
        #expect(days.count == 28)
    }

    @Test func monthsStepAcrossYearEnds() {
        let cal = utcCalendar
        #expect(CycleCalendarGrid.month(1, from: date("2026-12-31T23:00:00Z"), calendar: cal) == date("2027-01-01T00:00:00Z"))
        #expect(CycleCalendarGrid.month(-1, from: date("2026-01-31T00:00:00Z"), calendar: cal) == date("2025-12-01T00:00:00Z"))
        #expect(CycleCalendarGrid.startOfMonth(date("2028-02-29T10:00:00Z"), calendar: cal) == date("2028-02-01T00:00:00Z"))
        #expect(CycleCalendarGrid.days(inMonthOf: date("2028-02-29T10:00:00Z"), calendar: cal).compactMap { $0 }.count == 29)
    }

    @Test func weekdaySymbolsFollowTheFirstWeekday() {
        #expect(CycleCalendarGrid.weekdaySymbols(calendar: calendar(firstWeekday: 1, locale: "en_US")) == ["S", "M", "T", "W", "T", "F", "S"])
        let monday = CycleCalendarGrid.weekdaySymbols(calendar: calendar(firstWeekday: 2, locale: "en_US"))
        #expect(monday.first == "M")
        #expect(monday.last == "S")
        #expect(monday.count == 7)
    }
}
```

Thêm vào cuối `Packages/KickCore/Tests/KickCoreTests/UITestLaunchOptionsTests.swift`:
```swift
struct UITestCycleSeedOptionTests {
    @Test func parsesTheCycleScenarioWhenUITesting() {
        let options = UITestLaunchOptions(arguments: ["-uiTesting", "-seedCycles", "fertile"])
        #expect(options.seedCycles == .fertile)
    }

    @Test func ignoresTheCycleScenarioWithoutUITestingOrWhenUnknown() {
        #expect(UITestLaunchOptions(arguments: ["-seedCycles", "fertile"]).seedCycles == nil)
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-seedCycles", "twins"]).seedCycles == nil)
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-seedCycles"]).seedCycles == nil)
    }
}
```

- [ ] **Step 2: Chạy, xác nhận fail**

Run: `scripts/test-core.sh --filter "CycleSeedTests|CycleCalendarGridTests|UITestCycleSeedOptionTests"`
Expected: lỗi biên dịch `cannot find 'CycleSeedScenario' in scope`.

- [ ] **Step 3: Viết code**

`Packages/KickCore/Sources/KickCore/CycleSeed.swift`:
```swift
import Foundation

/// Sample cycle data for UI tests and screenshots (`-uiTesting -seedCycles <name>`).
/// Every scenario uses 5-day periods relative to `today`.
public enum CycleSeedScenario: String, Sendable, CaseIterable {
    /// Trying-to-conceive mode with nothing logged.
    case empty
    /// Regular 28-day cycles, period started yesterday and still going (cycle day 2).
    case period
    /// Regular 28-day cycles at cycle day 13, inside the fertile window, with signals logged.
    case fertile
    /// Regular 28-day cycles, next period 4 days late.
    case late
    /// 24/35/26/34-day cycles: low confidence and the irregular warning, cycle day 11.
    case irregular

    public struct Records: Equatable, Sendable {
        public let periods: [PeriodRecord]
        public let logs: [CycleLogRecord]
    }

    public func records(today now: Date, calendar: Calendar = .current) -> Records {
        let today = calendar.startOfDay(for: now)
        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: today) ?? today
        }
        func closed(_ offsets: [Int]) -> [PeriodRecord] {
            offsets.map { PeriodRecord(startDate: day($0), endDate: day($0 + 4)) }
        }
        switch self {
        case .empty:
            return Records(periods: [], logs: [])
        case .period:
            return Records(periods: closed([-85, -57, -29]) + [PeriodRecord(startDate: day(-1))], logs: [])
        case .fertile:
            return Records(
                periods: closed([-96, -68, -40, -12]),
                logs: [
                    CycleLogRecord(day: day(-4), bbtCelsius: 36.3),
                    CycleLogRecord(day: day(-3), bbtCelsius: 36.4),
                    CycleLogRecord(day: day(-2), bbtCelsius: 36.3, mucus: .sticky),
                    CycleLogRecord(day: day(-1), lh: .negative, bbtCelsius: 36.4, mucus: .creamy),
                    CycleLogRecord(day: day(0), bbtCelsius: 36.3, mucus: .eggWhite),
                ]
            )
        case .late:
            return Records(periods: closed([-116, -88, -60, -32]), logs: [])
        case .irregular:
            return Records(periods: closed([-129, -105, -70, -44, -10]), logs: [])
        }
    }
}
```

`Packages/KickCore/Sources/KickCore/CycleCalendarGrid.swift`:
```swift
import Foundation

/// Month layout for the Calendar tab, following the locale's first weekday.
public enum CycleCalendarGrid {
    /// Midnight on the first day of the month containing `date`.
    public static func startOfMonth(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? calendar.startOfDay(for: date)
    }

    /// The first day of the month `offset` months from the one containing `date`.
    public static func month(_ offset: Int, from date: Date, calendar: Calendar = .current) -> Date {
        let start = startOfMonth(date, calendar: calendar)
        return calendar.date(byAdding: .month, value: offset, to: start) ?? start
    }

    /// One entry per cell, row by row: `nil` for the blanks before day 1, then
    /// every day of the month (midnight). No trailing blanks.
    public static func days(inMonthOf date: Date, calendar: Calendar = .current) -> [Date?] {
        let first = startOfMonth(date, calendar: calendar)
        guard let count = calendar.range(of: .day, in: .month, for: first)?.count else { return [] }
        let leading = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        let days: [Date?] = (0..<count).map { calendar.date(byAdding: .day, value: $0, to: first) }
        return Array(repeating: nil, count: leading) + days
    }

    /// Very short weekday names starting at the calendar's first weekday ("S M T…" / "T2 T3…").
    public static func weekdaySymbols(calendar: Calendar = .current) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }
}
```

Thay toàn bộ `Packages/KickCore/Sources/KickCore/UITestLaunchOptions.swift` bằng:
```swift
import Foundation

/// Launch arguments that make UI tests and screenshots deterministic. They only
/// take effect together with `-uiTesting`:
/// - `-fixedNow <ISO8601>` pins the app's clock for the pregnancy and appointment screens.
/// - `-seedDueDate <ISO8601>` stores that due date at launch.
/// - `-seedCycles <scenario>` switches to trying-to-conceive mode and stores
///   that `CycleSeedScenario`'s periods and logs, relative to the pinned clock.
public struct UITestLaunchOptions: Equatable, Sendable {
    public let isUITesting: Bool
    public let fixedNow: Date?
    public let seedDueDate: Date?
    public let seedCycles: CycleSeedScenario?

    public init(arguments: [String]) {
        isUITesting = arguments.contains("-uiTesting")
        fixedNow = isUITesting ? Self.date(after: "-fixedNow", in: arguments) : nil
        seedDueDate = isUITesting ? Self.date(after: "-seedDueDate", in: arguments) : nil
        seedCycles = isUITesting ? Self.value(after: "-seedCycles", in: arguments).flatMap(CycleSeedScenario.init(rawValue:)) : nil
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    private static func date(after flag: String, in arguments: [String]) -> Date? {
        value(after: flag, in: arguments).flatMap { try? Date($0, strategy: .iso8601) }
    }
}
```

- [ ] **Step 4: Chạy lại, xác nhận pass**

Run: `scripts/test-core.sh --filter "CycleSeedTests|CycleCalendarGridTests|UITestCycleSeedOptionTests|UITestLaunchOptionsTests"` → Expected: tất cả pass (13 test mới + 3 test cũ).
Run: `scripts/test-core.sh` → Expected: toàn bộ pass (276).

- [ ] **Step 5: Commit, push, xác minh CI**

```bash
git add Packages/KickCore
git commit -F - <<'MSG'
feat(core): add -seedCycles scenarios and month grid layout

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`.

---
### Task 7: KickData — model `PeriodEntry`, `CycleLog` + `CycleStore`

Chỉ build/test được trên CI (SwiftData macro cần Xcode). Như `AppointmentStore`: seam nội bộ `saveContext` để test rollback (SwiftData không có cách tin cậy để làm `save()` thật thất bại — commit `59dd6a1`). `CycleStore` kiểm tra mọi lần ghi bằng `CycleRules` (Task 2) và gộp bản trùng do iCloud khi đọc (kỳ kinh chồng nhau; nhiều log cùng một ngày), giống bất biến "một session active" của `KickStore`.

**Files:**
- Modify: `Packages/KickData/Sources/KickData/Models.swift` (thêm 2 model ở cuối file), `Packages/KickData/Sources/KickData/KickPersistence.swift` (schema)
- Create: `Packages/KickData/Sources/KickData/CycleStore.swift`
- Test: `Packages/KickData/Tests/KickDataTests/CycleStoreTests.swift` (dùng `date(_:)` và `utcCalendar` có sẵn trong `Packages/KickData/Tests/KickDataTests/TestSupport.swift`)

**Interfaces:**
- Consumes: `PeriodRecord`, `CycleLogRecord`, `LHResult`, `CervicalMucus`, `CycleRepository`, `CycleRepositoryError`, `CycleRules` (Task 2).
- Produces:
  - `@Model public final class PeriodEntry { public var id: UUID = UUID(); public var startDate: Date = Date(); public var endDate: Date?; public init(record: PeriodRecord); public var record: PeriodRecord }`
  - `@Model public final class CycleLog { public var id: UUID = UUID(); public var day: Date = Date(); public var lhRaw: String?; public var bbtCelsius: Double?; public var mucusRaw: String?; public var note: String = ""; public init(record: CycleLogRecord); public var record: CycleLogRecord }`
  - `KickPersistence.schema` = `Schema([KickSession.self, Kick.self, Appointment.self, PeriodEntry.self, CycleLog.self])`
  - `@MainActor public final class CycleStore: CycleRepository` với `public convenience init(context: ModelContext, calendar: Calendar = .current)` và `init(context: ModelContext, calendar: Calendar, saveContext: @escaping @MainActor (ModelContext) throws -> Void)` (internal, seam cho test).

- [ ] **Step 1: Viết test trước**

`Packages/KickData/Tests/KickDataTests/CycleStoreTests.swift`:
```swift
import Foundation
import KickCore
import SwiftData
import Testing
@testable import KickData

@MainActor
struct CycleStoreTests {
    struct SaveFailed: Error {}

    let today = date("2026-10-02T12:00:00Z")
    let container: ModelContainer
    let store: CycleStore

    init() throws {
        container = try KickPersistence.makeContainer(inMemory: true)
        store = CycleStore(context: container.mainContext, calendar: utcCalendar)
    }

    /// A store on the same context whose saves always fail.
    private func failingStore() -> CycleStore {
        CycleStore(context: container.mainContext, calendar: utcCalendar, saveContext: { _ in throw SaveFailed() })
    }

    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00Z") }

    private func count<T: PersistentModel>(_ type: T.Type) throws -> Int {
        try container.mainContext.fetchCount(FetchDescriptor<T>())
    }

    @Test func schemaIncludesTheCycleModels() {
        let names = KickPersistence.schema.entities.map(\.name)
        #expect(names.contains("PeriodEntry"))
        #expect(names.contains("CycleLog"))
        #expect(names.contains("Appointment"))
    }

    // MARK: - Periods

    @Test func addedPeriodRoundTripsAtTheStartOfTheDay() throws {
        let period = PeriodRecord(startDate: date("2026-09-03T18:00:00Z"), endDate: date("2026-09-07T06:00:00Z"))
        try store.addPeriod(period, today: today)
        #expect(try store.periods() == [PeriodRecord(id: period.id, startDate: day("2026-09-03"), endDate: day("2026-09-07"))])
    }

    @Test func periodsAreSortedOldestFirst() throws {
        let later = PeriodRecord(startDate: day("2026-09-03"), endDate: day("2026-09-07"))
        let earlier = PeriodRecord(startDate: day("2026-08-06"), endDate: day("2026-08-10"))
        try store.addPeriod(later, today: today)
        try store.addPeriod(earlier, today: today)
        #expect(try store.periods().map(\.id) == [earlier.id, later.id])
    }

    @Test func overlappingPeriodIsRejectedAndNotSaved() throws {
        try store.addPeriod(PeriodRecord(startDate: day("2026-09-03"), endDate: day("2026-09-07")), today: today)
        #expect(throws: CycleRepositoryError.overlapsExistingPeriod) {
            try store.addPeriod(PeriodRecord(startDate: day("2026-09-06")), today: today)
        }
        #expect(try count(PeriodEntry.self) == 1)
    }

    @Test func futurePeriodIsRejected() throws {
        #expect(throws: CycleRepositoryError.futureDate) {
            try store.addPeriod(PeriodRecord(startDate: day("2026-10-03")), today: today)
        }
        #expect(try count(PeriodEntry.self) == 0)
    }

    @Test func updateSetsTheEndAndChecksOverlap() throws {
        var open = PeriodRecord(startDate: day("2026-09-28"))
        try store.addPeriod(PeriodRecord(startDate: day("2026-09-03"), endDate: day("2026-09-07")), today: today)
        try store.addPeriod(open, today: today)
        open.endDate = day("2026-10-01")
        try store.updatePeriod(open, today: today)
        #expect(try store.periods().last == open)

        open.startDate = day("2026-09-05")
        #expect(throws: CycleRepositoryError.overlapsExistingPeriod) {
            try store.updatePeriod(open, today: today)
        }
        #expect(try store.periods().last?.startDate == day("2026-09-28"))
    }

    @Test func updatingAnUnknownPeriodThrowsNotFound() {
        #expect(throws: CycleRepositoryError.notFound) {
            try store.updatePeriod(PeriodRecord(startDate: day("2026-09-03")), today: today)
        }
    }

    @Test func deleteRemovesAndUnknownIDIsANoOp() throws {
        let period = PeriodRecord(startDate: day("2026-09-03"), endDate: day("2026-09-07"))
        try store.addPeriod(period, today: today)
        try store.deletePeriod(id: period.id)
        try store.deletePeriod(id: UUID())
        #expect(try store.periods().isEmpty)
        #expect(try count(PeriodEntry.self) == 0)
    }

    @Test func overlappingPeriodsFromSyncAreMerged() throws {
        // iCloud delivers the same period started on two devices.
        let context = container.mainContext
        context.insert(PeriodEntry(record: PeriodRecord(startDate: day("2026-09-03"))))
        context.insert(PeriodEntry(record: PeriodRecord(startDate: day("2026-09-03"), endDate: day("2026-09-07"))))
        context.insert(PeriodEntry(record: PeriodRecord(startDate: day("2026-08-06"), endDate: day("2026-08-10"))))
        try context.save()

        let periods = try store.periods()
        #expect(periods.map(\.startDate) == [day("2026-08-06"), day("2026-09-03")])
        #expect(periods.last?.endDate == day("2026-09-07"))
        #expect(try count(PeriodEntry.self) == 2)
    }

    // MARK: - Day logs

    @Test func logRoundTripsEveryField() throws {
        let log = CycleLogRecord(day: date("2026-10-01T21:00:00Z"), lh: .positive, bbtCelsius: 36.55, mucus: .eggWhite, note: " Cramps ")
        try store.saveLog(log, today: today)
        #expect(try store.logs() == [CycleLogRecord(id: log.id, day: day("2026-10-01"), lh: .positive, bbtCelsius: 36.55, mucus: .eggWhite, note: "Cramps")])
    }

    @Test func savingTheSameDayAgainReplacesTheLogAndKeepsItsID() throws {
        let first = CycleLogRecord(day: day("2026-10-01"), lh: .negative)
        try store.saveLog(first, today: today)
        try store.saveLog(CycleLogRecord(day: date("2026-10-01T09:00:00Z"), lh: .positive, mucus: .creamy), today: today)
        #expect(try store.logs() == [CycleLogRecord(id: first.id, day: day("2026-10-01"), lh: .positive, mucus: .creamy)])
        #expect(try count(CycleLog.self) == 1)
    }

    @Test func emptyLogDeletesTheDay() throws {
        try store.saveLog(CycleLogRecord(day: day("2026-10-01"), mucus: .dry), today: today)
        try store.saveLog(CycleLogRecord(day: day("2026-10-01"), note: "  "), today: today)
        #expect(try store.logs().isEmpty)
        #expect(try count(CycleLog.self) == 0)
    }

    @Test func implausibleTemperatureAndFutureDaysAreRejected() throws {
        #expect(throws: CycleRepositoryError.invalidTemperature) {
            try store.saveLog(CycleLogRecord(day: day("2026-10-01"), bbtCelsius: 40.1), today: today)
        }
        #expect(throws: CycleRepositoryError.futureDate) {
            try store.saveLog(CycleLogRecord(day: day("2026-10-03"), mucus: .dry), today: today)
        }
        #expect(try count(CycleLog.self) == 0)
    }

    @Test func sameDayLogsFromSyncAreMerged() throws {
        let context = container.mainContext
        context.insert(CycleLog(record: CycleLogRecord(day: day("2026-10-01"), lh: .negative, note: "Tired")))
        context.insert(CycleLog(record: CycleLogRecord(day: day("2026-10-01"), lh: .positive, bbtCelsius: 36.4)))
        try context.save()

        let logs = try store.logs()
        #expect(logs.count == 1)
        #expect(logs.first?.lh == .positive)
        #expect(logs.first?.bbtCelsius == 36.4)
        #expect(logs.first?.note == "Tired")
        #expect(try count(CycleLog.self) == 1)
    }

    // MARK: - Rollback

    @Test func failedPeriodSaveRollsBack() throws {
        #expect(throws: SaveFailed.self) {
            try failingStore().addPeriod(PeriodRecord(startDate: day("2026-09-03")), today: today)
        }
        #expect(try store.periods().isEmpty)
        #expect(try count(PeriodEntry.self) == 0)
    }

    @Test func failedLogSaveRollsBack() throws {
        let log = CycleLogRecord(day: day("2026-10-01"), lh: .negative)
        try store.saveLog(log, today: today)
        #expect(throws: SaveFailed.self) {
            try failingStore().saveLog(CycleLogRecord(day: day("2026-10-01"), lh: .positive), today: today)
        }
        #expect(try store.logs() == [log])
    }

    @Test func failedDeleteRollsBack() throws {
        let period = PeriodRecord(startDate: day("2026-09-03"), endDate: day("2026-09-07"))
        try store.addPeriod(period, today: today)
        #expect(throws: SaveFailed.self) {
            try failingStore().deletePeriod(id: period.id)
        }
        #expect(try store.periods() == [period])
    }
}
```

- [ ] **Step 2: Xác nhận test chưa biên dịch được (không chạy local được)**

Run: `grep -n "class CycleStore\|PeriodEntry.self" Packages/KickData/Sources/KickData/*.swift`
Expected: không có kết quả (test sẽ fail biên dịch nếu đẩy lên CI lúc này — không push ở bước này).

- [ ] **Step 3: Viết code**

Thêm vào cuối `Packages/KickData/Sources/KickData/Models.swift`:
```swift

/// A logged period. Synced through iCloud; `CycleStore` merges overlapping
/// duplicates that sync can create.
@Model
public final class PeriodEntry {
    public var id: UUID = UUID()
    /// Start of the first day.
    public var startDate: Date = Date()
    /// Start of the last day; nil while the period is still going on.
    public var endDate: Date?

    public init(record: PeriodRecord) {
        id = record.id
        startDate = record.startDate
        endDate = record.endDate
    }

    public var record: PeriodRecord {
        PeriodRecord(id: id, startDate: startDate, endDate: endDate)
    }

    func apply(_ record: PeriodRecord) {
        startDate = record.startDate
        endDate = record.endDate
    }
}

/// Body signals for one day. At most one per day (kept so by `CycleStore`).
@Model
public final class CycleLog {
    public var id: UUID = UUID()
    /// Start of the day.
    public var day: Date = Date()
    /// `LHResult.rawValue`: "positive" | "negative".
    public var lhRaw: String?
    /// 35.0–38.5 °C.
    public var bbtCelsius: Double?
    /// `CervicalMucus.rawValue`: "dry" | "sticky" | "creamy" | "eggWhite".
    public var mucusRaw: String?
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

    func apply(_ record: CycleLogRecord) {
        day = record.day
        lhRaw = record.lh?.rawValue
        bbtCelsius = record.bbtCelsius
        mucusRaw = record.mucus?.rawValue
        note = record.note
    }
}
```

Trong `Packages/KickData/Sources/KickData/KickPersistence.swift`, thay dòng
```swift
    public static let schema = Schema([KickSession.self, Kick.self, Appointment.self])
```
bằng
```swift
    public static let schema = Schema([KickSession.self, Kick.self, Appointment.self, PeriodEntry.self, CycleLog.self])
```

`Packages/KickData/Sources/KickData/CycleStore.swift`:
```swift
import Foundation
import KickCore
import SwiftData

/// SwiftData-backed CycleRepository. Validates every write with `CycleRules`
/// and merges iCloud duplicates on read (overlapping periods, several logs on
/// one day). Storage only: reminders are kept in step by `CycleCoordinator`.
@MainActor
public final class CycleStore: CycleRepository {
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

    public func periods() throws -> [PeriodRecord] {
        let models = try context.fetch(FetchDescriptor<PeriodEntry>(sortBy: [SortDescriptor(\.startDate)]))
        let merged = CycleRules.mergingDuplicates(models.map(\.record), calendar: calendar)
        guard merged.periods.count != models.count else { return merged.periods }
        var keep = Dictionary(merged.periods.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for model in models {
            if let record = keep.removeValue(forKey: model.id) {
                model.apply(record)
            } else {
                context.delete(model)
            }
        }
        try save()
        return merged.periods
    }

    public func logs() throws -> [CycleLogRecord] {
        let models = try context.fetch(FetchDescriptor<CycleLog>(sortBy: [SortDescriptor(\.day)]))
        let merged = CycleRules.mergingDuplicates(models.map(\.record), calendar: calendar)
        guard merged.logs.count != models.count else { return merged.logs }
        var keep = Dictionary(merged.logs.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for model in models {
            if let record = keep.removeValue(forKey: model.id) {
                model.apply(record)
            } else {
                context.delete(model)
            }
        }
        try save()
        return merged.logs
    }

    public func addPeriod(_ period: PeriodRecord, today: Date) throws {
        try CycleRules.validate(period, existing: try periods(), today: today, calendar: calendar)
        context.insert(PeriodEntry(record: CycleRules.normalized(period, calendar: calendar)))
        try save()
    }

    public func updatePeriod(_ period: PeriodRecord, today: Date) throws {
        let existing = try periods()
        guard let model = try periodModel(id: period.id) else { throw CycleRepositoryError.notFound }
        try CycleRules.validate(period, existing: existing, today: today, calendar: calendar)
        model.apply(CycleRules.normalized(period, calendar: calendar))
        try save()
    }

    public func deletePeriod(id: UUID) throws {
        let models = try context.fetch(FetchDescriptor<PeriodEntry>(predicate: #Predicate { $0.id == id }))
        guard !models.isEmpty else { return }
        for model in models {
            context.delete(model)
        }
        try save()
    }

    public func saveLog(_ log: CycleLogRecord, today: Date) throws {
        let normalized = CycleRules.normalized(log, calendar: calendar)
        try CycleRules.validate(normalized, today: today, calendar: calendar)
        let sameDay = try context.fetch(FetchDescriptor<CycleLog>())
            .filter { calendar.startOfDay(for: $0.day) == normalized.day }
            .sorted { $0.id.uuidString < $1.id.uuidString }
        if normalized.isEmpty {
            guard !sameDay.isEmpty else { return }
            for model in sameDay {
                context.delete(model)
            }
        } else if let kept = sameDay.first {
            kept.apply(normalized)
            for duplicate in sameDay.dropFirst() {
                context.delete(duplicate)
            }
        } else {
            context.insert(CycleLog(record: normalized))
        }
        try save()
    }

    private func periodModel(id: UUID) throws -> PeriodEntry? {
        var descriptor = FetchDescriptor<PeriodEntry>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
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

- [ ] **Step 4: Commit, push, xác minh trên CI**

```bash
scripts/test-core.sh
git add Packages/KickData
git commit -F - <<'MSG'
feat(data): add CloudKit-compatible PeriodEntry and CycleLog with CycleStore

The store validates writes with CycleRules, merges iCloud duplicates on
read and rolls back failed saves.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`; bước "KickData unit tests" chạy `CycleStoreTests` với 17 test pass, `AppointmentStoreTests`/`KickStoreTests` vẫn pass. Kiểm tra:
```bash
RUN_ID="$(gh run list --workflow ci.yml --commit "$(git rev-parse HEAD)" --limit 1 --json databaseId -q '.[0].databaseId')"
gh run view "$RUN_ID" --log | grep -E "CycleStoreTests|Test run with" | head -20
```
Expected: `Suite CycleStoreTests passed` (hoặc từng `Test … passed`), không có `failed`.

---
### Task 8: Nền tảng app chế độ Mong con + tab Chu kỳ + sheet ghi ngày

Nối `CycleCoordinator` vào app, đọc `-seedCycles` (chỉ `DEBUG` + `-uiTesting`), `RootView` chọn bộ tab theo `appMode` (Mong con: **Chu kỳ · Cài đặt**; Task 9 chèn **Lịch**), tab Chu kỳ (vòng chu kỳ, dòng trạng thái, thẻ kỳ kinh tiếp theo, thẻ cửa sổ thụ thai + rụng trứng, nhãn độ tin cậy thấp, thẻ trễ kinh / chu kỳ bất thường / kỳ kinh kéo dài, nút ghi nhanh, màn mời nhập kỳ kinh) và sheet ghi ngày (bắt đầu/kết thúc/xóa kỳ kinh, LH, BBT 35,0–38,5, dịch nhầy, ghi chú). Nút "Tôi đã có thai" trên thẻ trễ kinh thêm ở Task 10.

**Files:**
- Modify: `App/AppEnvironment.swift` (thay toàn bộ), `App/RootView.swift` (thay toàn bộ), `App/KickCounterApp.swift:28`, `App/Formatting.swift` (thêm 3 hàm), `Shared/L10n.swift`, `Shared/Localizable.xcstrings` (qua script), `README.md:24-25`, `UITests/UITestSupport.swift` (thay toàn bộ)
- Create: `App/Cycle/CyclePalette.swift`, `App/Cycle/CycleCards.swift`, `App/Cycle/CycleHomeView.swift`, `App/Cycle/LastPeriodSheet.swift`, `App/Cycle/CycleDayLogSheet.swift`, `UITests/CycleUITests.swift`, `UITests/CycleScreenshotTests.swift`

**Interfaces:**
- Consumes: `CycleCoordinator` (mọi API ở Task 5), `CycleForecast`/`CycleDayStatus`/`CyclePredictor` (Task 3), `CycleRules.lastPeriodRange`, `TemperatureEntry`, `LHResult`, `CervicalMucus`, `CycleLogRecord`, `PeriodRecord` (Task 2), `CycleReminderTexts` (Task 4), `CycleSeedScenario`, `UITestLaunchOptions.seedCycles` (Task 6), `CycleStore` (Task 7), `AppMode`/`SettingsKey.appMode` (Task 1); có sẵn: `AppClock.now()`, `View.card(tint:)` (`App/Pregnancy/PregnancyCards.swift`), `L10n.errorSave/errorLoad/commonOK/commonCancel/commonSave/commonDelete`.
- Produces:
  - `AppEnvironment.cycle: CycleCoordinator` và `.environment(env.cycle)` ở gốc app (mọi view dùng `@Environment(CycleCoordinator.self)`).
  - `enum AppTab { case pregnancy, counter, history, settings, cycle }` (app; Task 9 thêm `calendar`); `RootView.homeTab(for: AppMode) -> AppTab`.
  - `Formatting.cycleDate(_: Date) -> String`, `Formatting.spokenDay(_: Date) -> String`, `Formatting.temperature(_ celsius: Double) -> String`.
  - `enum CyclePalette { static let period, fertile, peak, low: Color; static func ringColor(for: CycleDayStatus) -> Color; static func symbol(for: CycleDayStatus) -> String? }`
  - `struct CycleDaySelection: Identifiable { let date: Date }`; `struct CycleDayLogSheet: View { init(day: Date, existing: CycleLogRecord?) }`; `struct LastPeriodPicker: View { @Binding var date: Date; let now: Date }` (một `Section`, dùng lại ở onboarding Task 11); `struct LastPeriodSheet: View`; `struct CycleNoticeCard<Actions: View>: View { init(symbol:title:message:identifier:actions:) }` (+ init không có actions); `CycleHomeView`, `CycleRing`, `CycleStatusCard`, `NextPeriodCard`, `FertileWindowCard`.
  - L10n: mọi khóa trong khối Step 2; `L10n.cycleFailure(_: CycleFailure) -> String`, `L10n.cycleStatus(_: CycleDayStatus) -> String`, `L10n.mucus(_: CervicalMucus) -> String`.
  - UI test: `XCUIApplication.launchPinned(language:dark:dueDate:seedCycles:)`, `XCUIApplication.scrollUntilHittable(_:maxSwipes:)`, `XCTestCase.waitForLabel(_:containing:timeout:)`, `enum CycleModeTab: Int { case cycle = 0, settings }`, `XCUIApplication.openCycleTab(_:)` (tên khác `openTab` vì cả hai enum có `.settings`).

- [ ] **Step 1: Viết UI test trước**

Thay toàn bộ `UITests/UITestSupport.swift` bằng:
```swift
import XCTest

/// Fixed dates for deterministic pregnancy UI tests. `fixedNow` is noon UTC so
/// it falls on the same calendar day in any simulator time zone from UTC−11 to UTC+11.
enum UITestDates {
    static let fixedNow = "2026-10-02T12:00:00Z"
    /// 12w0d at `fixedNow`.
    static let dueAtWeek12 = "2027-04-16T12:00:00Z"
    /// 24w3d at `fixedNow`, 109 days to go (the spec's example).
    static let dueAtWeek24 = "2027-01-19T12:00:00Z"
    /// 38w0d at `fixedNow`.
    static let dueAtWeek38 = "2026-10-16T12:00:00Z"
    /// 41w0d at `fixedNow`: 7 days past the due date.
    static let dueSevenDaysAgo = "2026-09-25T12:00:00Z"
}

extension XCUIApplication {
    /// Launches with onboarding skipped and the clock pinned to `UITestDates.fixedNow`,
    /// optionally with a stored due date, or — with `seedCycles` (a `CycleSeedScenario`
    /// name: empty, period, fertile, late, irregular) — in trying-to-conceive mode with
    /// sample cycles. Only the pregnancy, appointment and cycle screens (and the Count
    /// tab's week line) use the pinned clock; counting kicks uses real time.
    @MainActor
    static func launchPinned(
        language: String = "en",
        dark: Bool = false,
        dueDate: String? = nil,
        seedCycles: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting", "-skipOnboarding",
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", language == "vi" ? "vi_VN" : "en_US",
            "-fixedNow", UITestDates.fixedNow,
        ]
        if let dueDate { app.launchArguments += ["-seedDueDate", dueDate] }
        if let seedCycles { app.launchArguments += ["-seedCycles", seedCycles] }
        if dark { app.launchArguments.append("-forceDarkMode") }
        app.launch()
        return app
    }

    /// Swipes up, at most `maxSwipes` times, until `element` exists and is
    /// hittable — lazy containers (List, Form) only create cells near the viewport.
    func scrollUntilHittable(_ element: XCUIElement, maxSwipes: Int = 6) {
        var remaining = maxSwipes
        while !(element.exists && element.isHittable), remaining > 0 {
            swipeUp()
            remaining -= 1
        }
    }
}

extension XCTestCase {
    /// Attaches a screenshot; CI exports it to build/screenshots/<name>_….png.
    @MainActor
    func attachScreenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Waits until `element`'s accessibility label contains `text`.
    @MainActor
    func waitForLabel(
        _ element: XCUIElement,
        containing text: String,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let result = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout)
        XCTAssertEqual(result, .completed, "\(element.label) does not contain \(text)", file: file, line: line)
    }
}

/// Tab order in RootView in pregnancy mode.
enum AppTab: Int {
    case pregnancy = 0
    case counter
    case history
    case settings
}

/// Tab order in RootView in trying-to-conceive mode.
enum CycleModeTab: Int {
    case cycle = 0
    case settings
}

extension XCUIApplication {
    func openTab(_ tab: AppTab) {
        openTab(at: tab.rawValue)
    }

    /// Named differently from `openTab(_:)`: both enums have a `.settings` case.
    func openCycleTab(_ tab: CycleModeTab) {
        openTab(at: tab.rawValue)
    }

    private func openTab(at index: Int) {
        let button = tabBars.buttons.element(boundBy: index)
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
    }
}
```

`UITests/CycleUITests.swift`:
```swift
import XCTest

/// Functional checks of trying-to-conceive mode with a pinned clock (2026-10-02)
/// and seeded cycles (see `CycleSeedScenario`).
final class CycleUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Spec §8: logging a positive LH test moves the estimated ovulation day.
    @MainActor
    func testPositiveLHTestMovesOvulation() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "fertile")
        let fertileCard = app.descendants(matching: .any)["cycleFertileCard"]
        XCTAssertTrue(fertileCard.waitForExistence(timeout: 10))
        // Regular 28-day cycles, cycle day 13: calendar ovulation on 10-04.
        XCTAssertTrue(fertileCard.label.contains("Estimated ovulation: 10/04"), fertileCard.label)

        let logToday = app.buttons["cycleLogTodayButton"]
        app.scrollUntilHittable(logToday)
        logToday.tap()
        let positive = app.segmentedControls.buttons["Positive"]
        XCTAssertTrue(positive.waitForExistence(timeout: 5))
        positive.tap()
        app.buttons["dayLogSave"].tap()

        // A positive test today (10-02) puts ovulation on the next day.
        waitForLabel(fertileCard, containing: "Estimated ovulation: 10/03")
        XCTAssertTrue(fertileCard.label.contains("Based on your positive LH test"), fertileCard.label)
    }

    @MainActor
    func testEmptyCycleTabAddsTheLastPeriod() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "empty")
        let add = app.buttons["cycleAddPeriodButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        let wheels = app.pickerWheels
        XCTAssertTrue(wheels.element(boundBy: 2).waitForExistence(timeout: 5))
        wheels.element(boundBy: 0).adjust(toPickerWheelValue: "September") // en_US order: month, day, year
        wheels.element(boundBy: 1).adjust(toPickerWheelValue: "20")
        app.buttons["lastPeriodSave"].tap()

        // 2026-09-20 → 2026-10-02 is cycle day 13.
        let status = app.descendants(matching: .any)["cycleStatusCard"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertTrue(status.label.contains("Day 13 of your cycle"), status.label)
    }

    @MainActor
    func testStartingAPeriodClearsTheLateCard() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "late")
        let late = app.descendants(matching: .any)["cycleLateCard"]
        XCTAssertTrue(late.waitForExistence(timeout: 10))
        XCTAssertTrue(late.label.contains("Your period is 4 days late"), late.label)

        let periodButton = app.buttons["cyclePeriodButton"]
        app.scrollUntilHittable(periodButton)
        XCTAssertEqual(periodButton.label, "Period started today")
        periodButton.tap()

        let status = app.descendants(matching: .any)["cycleStatusCard"]
        waitForLabel(status, containing: "Day 1 of your cycle")
        XCTAssertFalse(late.exists)
        XCTAssertEqual(periodButton.label, "Period ended today")
    }

    /// Spec §6: a temperature outside 35.0–38.5 °C is not saved.
    @MainActor
    func testImplausibleTemperatureIsNotSaved() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "fertile")
        let logToday = app.buttons["cycleLogTodayButton"]
        XCTAssertTrue(logToday.waitForExistence(timeout: 10))
        app.scrollUntilHittable(logToday)
        logToday.tap()

        let field = app.textFields["dayLogBBTField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        // Clear the seeded "36.3", then type an implausible value.
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6) + "40")
        app.buttons["dayLogSave"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["dayLogBBTError"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["dayLogSave"].exists) // the sheet stays open
    }
}
```

`UITests/CycleScreenshotTests.swift`:
```swift
import XCTest

/// Screenshots of trying-to-conceive mode (spec §8), pinned to 2026-10-02.
final class CycleScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private static let variants = [("vi", false), ("vi", true), ("en", false)]

    /// The Cycle tab during a period, in the fertile window, when late, and with irregular cycles.
    @MainActor
    func testCycleHomeScreens() {
        for scenario in ["period", "fertile", "late", "irregular"] {
            for (language, dark) in Self.variants {
                let name = "cycle-home-\(scenario)-\(language)-\(dark ? "dark" : "light")"
                let app = XCUIApplication.launchPinned(language: language, dark: dark, seedCycles: scenario)
                XCTAssertTrue(app.descendants(matching: .any)["cycleStatusCard"].waitForExistence(timeout: 10), name)
                attachScreenshot(app, name)
                if language == "vi", !dark {
                    let logToday = app.buttons["cycleLogTodayButton"]
                    app.scrollUntilHittable(logToday)
                    attachScreenshot(app, "\(name)-bottom")
                }
                app.terminate()
            }
        }
    }

    @MainActor
    func testEmptyCycleScreens() {
        for (language, dark) in Self.variants {
            let suffix = "\(language)-\(dark ? "dark" : "light")"
            let app = XCUIApplication.launchPinned(language: language, dark: dark, seedCycles: "empty")
            let add = app.buttons["cycleAddPeriodButton"]
            XCTAssertTrue(add.waitForExistence(timeout: 10))
            attachScreenshot(app, "cycle-empty-\(suffix)")
            if language == "vi", !dark {
                add.tap()
                XCTAssertTrue(app.buttons["lastPeriodSave"].waitForExistence(timeout: 5))
                attachScreenshot(app, "last-period-sheet-vi")
            }
            app.terminate()
        }
    }

    /// The day log sheet for today in the fertile scenario (BBT, mucus already logged).
    @MainActor
    func testDayLogScreens() {
        for (language, dark) in Self.variants {
            let suffix = "\(language)-\(dark ? "dark" : "light")"
            let app = XCUIApplication.launchPinned(language: language, dark: dark, seedCycles: "fertile")
            let logToday = app.buttons["cycleLogTodayButton"]
            XCTAssertTrue(logToday.waitForExistence(timeout: 10))
            app.scrollUntilHittable(logToday)
            logToday.tap()
            XCTAssertTrue(app.buttons["dayLogSave"].waitForExistence(timeout: 5))
            attachScreenshot(app, "day-log-\(suffix)")
            if language == "vi", !dark {
                let field = app.textFields["dayLogBBTField"]
                field.tap()
                field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6) + "34")
                app.buttons["dayLogSave"].tap()
                XCTAssertTrue(app.descendants(matching: .any)["dayLogBBTError"].waitForExistence(timeout: 5))
                attachScreenshot(app, "day-log-bbt-error-vi")
            }
            app.terminate()
        }
    }
}
```

(Không push ở bước này: các id/khóa chưa tồn tại nên CI sẽ đỏ.)

- [ ] **Step 2: Thêm chuỗi (en + vi) và L10n**

```bash
scripts/add-strings.py <<'JSON'
{
  "tab.cycle": ["Cycle", "Chu kỳ"],
  "cycle.title": ["Your cycle", "Chu kỳ của bạn"],
  "cycle.empty.title": ["When did your last period start?", "Kỳ kinh gần nhất bắt đầu ngày nào?"],
  "cycle.empty.body": ["Enter the first day of your last period to see your next period and your fertile window.", "Nhập ngày đầu tiên của kỳ kinh gần nhất để xem kỳ kinh tiếp theo và cửa sổ thụ thai."],
  "cycle.empty.action": ["Add last period", "Nhập kỳ kinh"],
  "cycle.day": ["Day %d of your cycle", "Ngày %d của chu kỳ"],
  "cycle.status.period": ["Period", "Đang hành kinh"],
  "cycle.status.fertile": ["High chance of conceiving", "Khả năng thụ thai cao"],
  "cycle.status.peak": ["Highest chance of conceiving", "Khả năng thụ thai cao nhất"],
  "cycle.status.low": ["Low chance of conceiving", "Khả năng thụ thai thấp"],
  "cycle.nextPeriod.title": ["Next period", "Kỳ kinh tiếp theo"],
  "cycle.nextPeriod.in": ["%1$@ · days to go: %2$d", "%1$@ (còn %2$d ngày)"],
  "cycle.nextPeriod.today": ["%@ (today)", "%@ (hôm nay)"],
  "cycle.nextPeriod.late": ["Days late: %d", "Trễ %d ngày"],
  "cycle.fertile.title": ["Fertile window", "Cửa sổ thụ thai"],
  "cycle.fertile.range": ["%1$@ – %2$@", "%1$@ – %2$@"],
  "cycle.ovulation": ["Estimated ovulation: %@", "Ngày rụng trứng ước tính: %@"],
  "cycle.ovulation.confirmed": ["Ovulation confirmed by temperature: %@", "Đã xác nhận rụng trứng qua nhiệt độ: %@"],
  "cycle.ovulation.lh": ["Based on your positive LH test", "Theo que thử rụng trứng (LH) dương tính"],
  "cycle.lowConfidence.irregular": ["Low confidence: your cycles vary", "Độ tin cậy thấp — chu kỳ chưa đều"],
  "cycle.lowConfidence.fewCycles": ["Low confidence: log a few more periods", "Độ tin cậy thấp — cần ghi thêm vài kỳ kinh"],
  "cycle.late.title": ["Your period is %d days late", "Kỳ kinh đã trễ %d ngày"],
  "cycle.late.body": ["You could take a pregnancy test. If it is positive, tap “I'm pregnant”.", "Bạn có thể thử thai. Nếu que thử dương tính, hãy bấm “Tôi đã có thai”."],
  "cycle.irregular.title": ["Your cycle looks irregular", "Chu kỳ có vẻ không đều"],
  "cycle.irregular.body": ["Cycles shorter than 21 days, longer than 45 days, or that vary a lot are worth talking over with a doctor.", "Chu kỳ ngắn hơn 21 ngày, dài hơn 45 ngày hoặc thay đổi nhiều — bạn nên trao đổi với bác sĩ."],
  "cycle.longPeriod.title": ["Period logged for %d days", "Kỳ kinh đã kéo dài %d ngày"],
  "cycle.longPeriod.body": ["If it has ended, log the day it ended. If you are still bleeding, see a doctor.", "Nếu đã hết, hãy ghi ngày kết thúc. Nếu vẫn còn ra máu, bạn nên đi khám."],
  "cycle.startPeriod": ["Period started today", "Hôm nay bắt đầu kỳ kinh"],
  "cycle.endPeriod": ["Period ended today", "Hôm nay hết kỳ kinh"],
  "cycle.logToday": ["Log today", "Ghi hôm nay"],
  "cycle.disclaimer": ["Predictions are estimates. Do not use this app as contraception.", "Dự đoán chỉ là ước tính. Không dùng ứng dụng để tránh thai."],
  "cycle.notificationsOff": ["Notifications are off, so the app can't send cycle reminders. You can turn them on in Settings.", "Thông báo đang tắt nên ứng dụng không thể nhắc chu kỳ. Bạn có thể bật trong Cài đặt."],
  "cycle.reminder.fertile.title": ["Fertile window in 2 days", "2 ngày nữa vào cửa sổ thụ thai"],
  "cycle.reminder.fertile.body": ["Your most fertile days are coming up.", "Những ngày dễ thụ thai nhất sắp đến."],
  "cycle.reminder.period.title": ["Period due tomorrow", "Ngày mai có thể đến kỳ kinh"],
  "cycle.reminder.period.body": ["Log it when it starts to keep predictions accurate.", "Hãy ghi lại khi kỳ kinh bắt đầu để dự đoán chính xác hơn."],
  "cycle.reminder.late.title": ["Your period is 3 days late", "Kỳ kinh đã trễ 3 ngày"],
  "cycle.reminder.late.body": ["You could take a pregnancy test.", "Bạn có thể thử thai."],
  "cycle.error.future": ["You can't log a day in the future.", "Không thể ghi một ngày trong tương lai."],
  "cycle.error.endBeforeStart": ["A period can't end before it starts.", "Ngày kết thúc không thể trước ngày bắt đầu."],
  "cycle.error.overlap": ["This overlaps a period you have already logged.", "Trùng với một kỳ kinh đã ghi."],
  "cycle.error.temperature": ["Enter a temperature between 35.0 and 38.5 °C.", "Nhập nhiệt độ trong khoảng 35,0–38,5 °C."],
  "lastPeriod.title": ["Last period", "Kỳ kinh gần nhất"],
  "lastPeriod.date": ["First day of your last period", "Ngày đầu tiên của kỳ kinh gần nhất"],
  "lastPeriod.hint": ["The first day of bleeding, not spotting.", "Ngày đầu tiên ra máu kinh (không tính ra máu lấm tấm)."],
  "dayLog.period": ["Period", "Kỳ kinh"],
  "dayLog.period.start": ["Period started this day", "Bắt đầu kỳ kinh ngày này"],
  "dayLog.period.end": ["Period ended this day", "Hết kỳ kinh ngày này"],
  "dayLog.period.delete": ["Delete this period", "Xóa kỳ kinh này"],
  "dayLog.period.delete.confirm": ["Delete this period?", "Xóa kỳ kinh này?"],
  "dayLog.period.since": ["Period since %@", "Kỳ kinh từ %@"],
  "dayLog.period.range": ["Period %1$@ – %2$@", "Kỳ kinh %1$@ – %2$@"],
  "dayLog.lh": ["Ovulation (LH) test", "Que thử rụng trứng (LH)"],
  "dayLog.lh.none": ["Not taken", "Chưa thử"],
  "dayLog.lh.negative": ["Negative", "Âm tính"],
  "dayLog.lh.positive": ["Positive", "Dương tính"],
  "dayLog.bbt": ["Basal body temperature", "Nhiệt độ cơ thể cơ bản (BBT)"],
  "dayLog.bbt.placeholder": ["e.g. 36.5", "VD: 36,5"],
  "dayLog.bbt.hint": ["°C, taken right after waking, before getting up.", "°C, đo ngay khi vừa thức dậy, trước khi ra khỏi giường."],
  "dayLog.mucus": ["Cervical mucus", "Dịch nhầy cổ tử cung"],
  "dayLog.mucus.none": ["Not noted", "Chưa ghi"],
  "dayLog.mucus.dry": ["Dry", "Khô"],
  "dayLog.mucus.sticky": ["Sticky", "Dính"],
  "dayLog.mucus.creamy": ["Creamy", "Như kem"],
  "dayLog.mucus.eggWhite": ["Egg white", "Như lòng trắng trứng"],
  "dayLog.note": ["Note", "Ghi chú"]
}
JSON
```
Expected: in `208 strings` (142 + 66; nếu catalog đã khác thì tổng tăng đúng 66).

Trong `Shared/L10n.swift`, chèn ngay sau dòng `    static var laAdd: String { t("la.add") }` (trước dấu `}` đóng `enum L10n`):
```swift

    static var tabCycle: String { t("tab.cycle") }

    static var cycleTitle: String { t("cycle.title") }
    static var cycleEmptyTitle: String { t("cycle.empty.title") }
    static var cycleEmptyBody: String { t("cycle.empty.body") }
    static var cycleEmptyAction: String { t("cycle.empty.action") }
    static func cycleDay(_ day: Int) -> String { String(format: t("cycle.day"), day) }
    static func cycleStatus(_ status: CycleDayStatus) -> String {
        switch status {
        case .period: t("cycle.status.period")
        case .fertile: t("cycle.status.fertile")
        case .peak: t("cycle.status.peak")
        case .low: t("cycle.status.low")
        }
    }
    static var cycleNextPeriodTitle: String { t("cycle.nextPeriod.title") }
    /// "04/10 (còn 2 ngày)" / "10/04 · days to go: 2".
    static func cycleNextPeriodIn(_ date: String, _ days: Int) -> String { String(format: t("cycle.nextPeriod.in"), date, days) }
    static func cycleNextPeriodToday(_ date: String) -> String { String(format: t("cycle.nextPeriod.today"), date) }
    static func cycleNextPeriodLate(_ days: Int) -> String { String(format: t("cycle.nextPeriod.late"), days) }
    static var cycleFertileTitle: String { t("cycle.fertile.title") }
    static func cycleFertileRange(_ start: String, _ end: String) -> String { String(format: t("cycle.fertile.range"), start, end) }
    static func cycleOvulation(_ date: String) -> String { String(format: t("cycle.ovulation"), date) }
    static func cycleOvulationConfirmed(_ date: String) -> String { String(format: t("cycle.ovulation.confirmed"), date) }
    static var cycleOvulationLH: String { t("cycle.ovulation.lh") }
    static var cycleLowConfidenceIrregular: String { t("cycle.lowConfidence.irregular") }
    static var cycleLowConfidenceFewCycles: String { t("cycle.lowConfidence.fewCycles") }
    static func cycleLateTitle(_ days: Int) -> String { String(format: t("cycle.late.title"), days) }
    static var cycleLateBody: String { t("cycle.late.body") }
    static var cycleIrregularTitle: String { t("cycle.irregular.title") }
    static var cycleIrregularBody: String { t("cycle.irregular.body") }
    static func cycleLongPeriodTitle(_ days: Int) -> String { String(format: t("cycle.longPeriod.title"), days) }
    static var cycleLongPeriodBody: String { t("cycle.longPeriod.body") }
    static var cycleStartPeriod: String { t("cycle.startPeriod") }
    static var cycleEndPeriod: String { t("cycle.endPeriod") }
    static var cycleLogToday: String { t("cycle.logToday") }
    static var cycleDisclaimer: String { t("cycle.disclaimer") }
    static var cycleNotificationsOff: String { t("cycle.notificationsOff") }
    static var cycleReminderFertileTitle: String { t("cycle.reminder.fertile.title") }
    static var cycleReminderFertileBody: String { t("cycle.reminder.fertile.body") }
    static var cycleReminderPeriodTitle: String { t("cycle.reminder.period.title") }
    static var cycleReminderPeriodBody: String { t("cycle.reminder.period.body") }
    static var cycleReminderLateTitle: String { t("cycle.reminder.late.title") }
    static var cycleReminderLateBody: String { t("cycle.reminder.late.body") }
    static func cycleFailure(_ failure: CycleFailure) -> String {
        switch failure {
        case .loadFailed: errorLoad
        case .saveFailed: errorSave
        case .futureDate: t("cycle.error.future")
        case .endBeforeStart: t("cycle.error.endBeforeStart")
        case .overlapsExistingPeriod: t("cycle.error.overlap")
        case .invalidTemperature: t("cycle.error.temperature")
        }
    }

    static var lastPeriodTitle: String { t("lastPeriod.title") }
    static var lastPeriodDate: String { t("lastPeriod.date") }
    static var lastPeriodHint: String { t("lastPeriod.hint") }

    static var dayLogPeriodSection: String { t("dayLog.period") }
    static var dayLogPeriodStart: String { t("dayLog.period.start") }
    static var dayLogPeriodEnd: String { t("dayLog.period.end") }
    static var dayLogPeriodDelete: String { t("dayLog.period.delete") }
    static var dayLogPeriodDeleteConfirm: String { t("dayLog.period.delete.confirm") }
    static func dayLogPeriodSince(_ date: String) -> String { String(format: t("dayLog.period.since"), date) }
    static func dayLogPeriodRange(_ start: String, _ end: String) -> String { String(format: t("dayLog.period.range"), start, end) }
    static var dayLogLH: String { t("dayLog.lh") }
    static var dayLogLHNone: String { t("dayLog.lh.none") }
    static var dayLogLHNegative: String { t("dayLog.lh.negative") }
    static var dayLogLHPositive: String { t("dayLog.lh.positive") }
    static var dayLogBBT: String { t("dayLog.bbt") }
    static var dayLogBBTPlaceholder: String { t("dayLog.bbt.placeholder") }
    static var dayLogBBTHint: String { t("dayLog.bbt.hint") }
    static var dayLogMucus: String { t("dayLog.mucus") }
    static var dayLogMucusNone: String { t("dayLog.mucus.none") }
    static func mucus(_ value: CervicalMucus) -> String {
        switch value {
        case .dry: t("dayLog.mucus.dry")
        case .sticky: t("dayLog.mucus.sticky")
        case .creamy: t("dayLog.mucus.creamy")
        case .eggWhite: t("dayLog.mucus.eggWhite")
        }
    }
    static var dayLogNote: String { t("dayLog.note") }
```

- [ ] **Step 3: Môi trường app, `-seedCycles`, định dạng**

Thay toàn bộ `App/AppEnvironment.swift` bằng:
```swift
import Foundation
import KickCore
import KickData
import SwiftData

@MainActor
struct AppEnvironment {
    let container: ModelContainer
    let coordinator: KickCoordinator
    let appointments: AppointmentCoordinator
    let cycle: CycleCoordinator
    let content: WeeklyContentLibrary?

    private static let arguments = ProcessInfo.processInfo.arguments
    #if DEBUG
    static let isUITesting = AppClock.launchOptions.isUITesting
    static let forceDarkMode = arguments.contains("-forceDarkMode")
    #else
    static let isUITesting = false
    static let forceDarkMode = false
    #endif

    static func make() throws -> AppEnvironment {
        #if DEBUG
        if isUITesting {
            AppGroup.defaults.removePersistentDomain(forName: AppGroup.identifier)
            if arguments.contains("-skipOnboarding") {
                AppGroup.defaults.set(true, forKey: SettingsKey.hasCompletedOnboarding)
            }
            if let seededDueDate = AppClock.launchOptions.seedDueDate {
                PregnancyProfile.saveDueDate(seededDueDate, to: AppGroup.defaults)
            }
            if AppClock.launchOptions.seedCycles != nil {
                AppMode.save(.tryingToConceive, to: AppGroup.defaults)
            }
        }
        #endif
        let container = try KickPersistence.makeContainer(inMemory: isUITesting)
        let notificationCenter: NotificationCenterClient = isUITesting ? DisabledNotificationCenter() : SystemNotificationCenter()
        let liveActivities: LiveActivityManaging = isUITesting ? NoopLiveActivityManager() : SystemLiveActivityManager()
        let notifications = NotificationScheduler(center: notificationCenter)
        let coordinator = KickCoordinator(
            store: KickStore(context: container.mainContext),
            notifications: notifications,
            liveActivities: liveActivities,
            overdueText: NotificationText(title: L10n.overdueTitle, body: L10n.overdueBody)
        )
        let appointments = AppointmentCoordinator(
            store: AppointmentStore(context: container.mainContext),
            notifications: notifications,
            reminderText: NotificationText(title: L10n.appointmentsReminderTitle, body: L10n.appointmentsReminderBody),
            now: { AppClock.now() }
        )
        let cycleStore = CycleStore(context: container.mainContext)
        #if DEBUG
        if isUITesting, let scenario = AppClock.launchOptions.seedCycles {
            try seedCycles(scenario, into: cycleStore)
        }
        #endif
        let cycle = CycleCoordinator(
            store: cycleStore,
            notifications: notifications,
            reminderTexts: CycleReminderTexts(
                fertile: NotificationText(title: L10n.cycleReminderFertileTitle, body: L10n.cycleReminderFertileBody),
                period: NotificationText(title: L10n.cycleReminderPeriodTitle, body: L10n.cycleReminderPeriodBody),
                late: NotificationText(title: L10n.cycleReminderLateTitle, body: L10n.cycleReminderLateBody)
            ),
            defaults: AppGroup.defaults,
            now: { AppClock.now() }
        )
        return AppEnvironment(
            container: container,
            coordinator: coordinator,
            appointments: appointments,
            cycle: cycle,
            content: WeeklyContentLibrary.loadBundled()
        )
    }

    #if DEBUG
    /// `-uiTesting -seedCycles <scenario>`: sample periods and logs relative to the pinned clock.
    private static func seedCycles(_ scenario: CycleSeedScenario, into store: CycleStore) throws {
        let now = AppClock.now()
        let records = scenario.records(today: now)
        for period in records.periods {
            try store.addPeriod(period, today: now)
        }
        for log in records.logs {
            try store.saveLog(log, today: now)
        }
    }
    #endif
}
```

Trong `App/KickCounterApp.swift`, ngay sau dòng `                    .environment(env.appointments)` thêm:
```swift
                    .environment(env.cycle)
```

Trong `App/Formatting.swift`, thêm vào trong `enum Formatting`, ngay sau hàm `duration(_:)`:
```swift

    /// Day and month in the locale's order: "04/10" (vi) / "10/04" (en).
    static func cycleDate(_ date: Date) -> String {
        date.formatted(.dateTime.day(.twoDigits).month(.twoDigits))
    }

    /// For VoiceOver: "October 4" / "4 tháng 10".
    static func spokenDay(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.wide))
    }

    /// "36.5 °C" / "36,5 °C".
    static func temperature(_ celsius: Double) -> String {
        Measurement(value: celsius, unit: UnitTemperature.celsius).formatted(
            .measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(1...2)))
        )
    }
```

Trong `README.md`, thay hai dòng 24–25:
```
- UI test: `-uiTesting -fixedNow <ISO8601>` cố định đồng hồ màn thai kỳ/lịch khám,
  `-seedDueDate <ISO8601>` ghi sẵn ngày dự sinh.
```
bằng:
```
- UI test: `-uiTesting -fixedNow <ISO8601>` cố định đồng hồ màn thai kỳ/lịch khám/chu kỳ,
  `-seedDueDate <ISO8601>` ghi sẵn ngày dự sinh,
  `-seedCycles <empty|period|fertile|late|irregular>` bật chế độ Mong con với dữ liệu mẫu
  (`CycleSeedScenario`). Chỉ có hiệu lực trong bản Debug và cùng `-uiTesting`.
```

- [ ] **Step 4: `RootView` theo chế độ**

Thay toàn bộ `App/RootView.swift` bằng:
```swift
import KickCore
import SwiftUI

enum AppTab: Hashable {
    case pregnancy
    case counter
    case history
    case settings
    case cycle
}

struct RootView: View {
    @Environment(KickCoordinator.self) private var coordinator
    @Environment(AppointmentCoordinator.self) private var appointments
    @Environment(CycleCoordinator.self) private var cycle
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKey.hasCompletedOnboarding, store: AppGroup.defaults)
    private var hasCompletedOnboarding = false
    @AppStorage(SettingsKey.appMode, store: AppGroup.defaults)
    private var appMode = AppMode.pregnant.rawValue
    @State private var selectedTab: AppTab

    init() {
        _selectedTab = State(initialValue: Self.homeTab(for: AppMode.load(from: AppGroup.defaults)))
    }

    private var mode: AppMode { AppMode(rawValue: appMode) ?? .pregnant }

    var body: some View {
        Group {
            switch mode {
            case .tryingToConceive: cycleTabs
            case .pregnant: pregnancyTabs
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasCompletedOnboarding },
            set: { hasCompletedOnboarding = !$0 }
        )) {
            OnboardingView { hasCompletedOnboarding = true }
        }
        .task { await reload() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await reload() } }
        }
        .onChange(of: appMode) {
            // Settings stays open after switching mode there; anywhere else
            // (e.g. "I'm pregnant" on the Cycle tab) lands on the new home tab.
            if selectedTab != .settings { selectedTab = Self.homeTab(for: mode) }
        }
    }

    /// Pregnancy mode (phases 1–2): Pregnancy · Count · History · Settings.
    private var pregnancyTabs: some View {
        TabView(selection: $selectedTab) {
            PregnancyHomeView { selectedTab = .counter }
                .tabItem { Label(L10n.tabPregnancy, systemImage: "heart.text.square.fill") }
                .tag(AppTab.pregnancy)
            CounterView()
                .tabItem { Label(L10n.tabCounter, systemImage: "hand.tap.fill") }
                .tag(AppTab.counter)
            HistoryView()
                .tabItem { Label(L10n.tabHistory, systemImage: "chart.bar.fill") }
                .tag(AppTab.history)
            SettingsView()
                .tabItem { Label(L10n.tabSettings, systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
    }

    /// Trying-to-conceive mode: Cycle · Settings (Task 9 adds Calendar).
    private var cycleTabs: some View {
        TabView(selection: $selectedTab) {
            CycleHomeView()
                .tabItem { Label(L10n.tabCycle, systemImage: "drop.circle.fill") }
                .tag(AppTab.cycle)
            SettingsView()
                .tabItem { Label(L10n.tabSettings, systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
    }

    static func homeTab(for mode: AppMode) -> AppTab {
        mode == .tryingToConceive ? .cycle : .pregnancy
    }

    private func reload() async {
        await coordinator.load()
        await appointments.load()
        await cycle.load()
    }
}
```

- [ ] **Step 5: Tab Chu kỳ**

`App/Cycle/CyclePalette.swift`:
```swift
import KickCore
import SwiftUI

/// Colours and symbols for cycle days. Never colour alone: each status also has
/// a symbol, and VoiceOver reads it out.
enum CyclePalette {
    /// Logged period: the app's pink accent.
    static let period = Color.accentColor
    /// Soft green for the fertile window (system green adapts to dark mode).
    static let fertile = Color(.systemGreen)
    /// Purple for ovulation and the day before.
    static let peak = Color(.systemPurple)
    static let low = Color(.systemGray5)

    /// Stroke colour for a day on the cycle ring.
    static func ringColor(for status: CycleDayStatus) -> Color {
        switch status {
        case .period(let isPredicted): isPredicted ? period.opacity(0.35) : period
        case .fertile: fertile.opacity(0.6)
        case .peak: peak
        case .low: low
        }
    }

    static func symbol(for status: CycleDayStatus) -> String? {
        switch status {
        case .period(let isPredicted): isPredicted ? "drop" : "drop.fill"
        case .fertile: "leaf.fill"
        case .peak: "sparkles"
        case .low: nil
        }
    }
}
```

`App/Cycle/CycleCards.swift`:
```swift
import KickCore
import SwiftUI

/// Ring of the current cycle's days coloured by status, with today marked.
/// Decorative: `CycleStatusCard` says the same in words.
struct CycleRing: View {
    let forecast: CycleForecast
    var lineWidth: CGFloat = 14

    private var length: Int { max(forecast.averageCycleLength, forecast.cycleDay) }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                ForEach(0..<length, id: \.self) { index in
                    Circle()
                        .trim(from: start(of: index), to: end(of: index))
                        .stroke(color(of: index), style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                        .padding(lineWidth / 2)
                }
                Circle()
                    .fill(Color.primary)
                    .frame(width: lineWidth * 0.7, height: lineWidth * 0.7)
                    .offset(y: -(size - lineWidth) / 2)
                    .rotationEffect(.degrees(360 * (Double(forecast.cycleDay) - 0.5) / Double(length)))
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }

    private func start(of index: Int) -> CGFloat { (CGFloat(index) + 0.08) / CGFloat(length) }
    private func end(of index: Int) -> CGFloat { (CGFloat(index) + 0.92) / CGFloat(length) }

    private func color(of index: Int) -> Color {
        let day = Calendar.current.date(byAdding: .day, value: index, to: forecast.currentPeriodStart) ?? forecast.currentPeriodStart
        return CyclePalette.ringColor(for: forecast.dayStatus(for: day))
    }
}

/// "Day 12 of your cycle · High chance of conceiving" around the ring.
struct CycleStatusCard: View {
    let forecast: CycleForecast
    @ScaledMetric(relativeTo: .title) private var ringSize: CGFloat = 190

    private var todayStatus: CycleDayStatus { forecast.dayStatus(for: forecast.today) }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                CycleRing(forecast: forecast)
                VStack(spacing: 2) {
                    Text(forecast.cycleDay, format: .number)
                        .font(.system(.largeTitle, design: .rounded).bold())
                        .accessibilityHidden(true)
                }
            }
            .frame(width: ringSize, height: ringSize)
            .frame(maxWidth: .infinity)

            VStack(spacing: 6) {
                Text(L10n.cycleDay(forecast.cycleDay))
                    .font(.title3.bold())
                Label {
                    Text(L10n.cycleStatus(todayStatus))
                } icon: {
                    Image(systemName: CyclePalette.symbol(for: todayStatus) ?? "circle")
                        .foregroundStyle(CyclePalette.ringColor(for: todayStatus))
                }
                .font(.headline)
            }
            .multilineTextAlignment(.center)
        }
        .card()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cycleStatusCard")
    }
}

struct NextPeriodCard: View {
    let forecast: CycleForecast

    private var value: String {
        if forecast.daysLate > 0 { return L10n.cycleNextPeriodLate(forecast.daysLate) }
        let date = Formatting.cycleDate(forecast.nextPeriodStart)
        let days = forecast.daysUntilNextPeriod
        return days == 0 ? L10n.cycleNextPeriodToday(date) : L10n.cycleNextPeriodIn(date, days)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(L10n.cycleNextPeriodTitle)
            } icon: {
                Image(systemName: "drop.fill").foregroundStyle(CyclePalette.period)
            }
            .font(.headline)
            Text(value)
                .font(.title3.weight(.semibold))
        }
        .card()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cycleNextPeriodCard")
    }
}

struct FertileWindowCard: View {
    let forecast: CycleForecast

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(L10n.cycleFertileTitle)
            } icon: {
                Image(systemName: "leaf.fill").foregroundStyle(CyclePalette.fertile)
            }
            .font(.headline)
            Text(L10n.cycleFertileRange(
                Formatting.cycleDate(forecast.fertileWindow.lowerBound),
                Formatting.cycleDate(forecast.fertileWindow.upperBound)
            ))
            .font(.title3.weight(.semibold))
            Label {
                Text(forecast.ovulationConfirmed
                    ? L10n.cycleOvulationConfirmed(Formatting.cycleDate(forecast.ovulationDate))
                    : L10n.cycleOvulation(Formatting.cycleDate(forecast.ovulationDate)))
            } icon: {
                Image(systemName: forecast.ovulationConfirmed ? "checkmark.seal.fill" : "sparkles")
                    .foregroundStyle(CyclePalette.peak)
            }
            .font(.subheadline)
            if forecast.ovulationSource == .lhTest {
                Text(L10n.cycleOvulationLH)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if forecast.confidence == .low {
                Label(
                    forecast.usableCycleLengths.count < 2 ? L10n.cycleLowConfidenceFewCycles : L10n.cycleLowConfidenceIrregular,
                    systemImage: "exclamationmark.circle"
                )
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.orange)
            }
        }
        .card()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cycleFertileCard")
    }
}

/// Orange notice card, same style as `OverdueBanner`.
struct CycleNoticeCard<Actions: View>: View {
    let symbol: String
    let title: String
    let message: String
    let identifier: String
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    Text(message).font(.subheadline)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(identifier)
            actions
        }
        .card(tint: Color.orange.opacity(0.12))
    }
}

extension CycleNoticeCard where Actions == EmptyView {
    init(symbol: String, title: String, message: String, identifier: String) {
        self.init(symbol: symbol, title: title, message: message, identifier: identifier) { EmptyView() }
    }
}
```

`App/Cycle/CycleHomeView.swift`:
```swift
import KickCore
import SwiftUI

/// A calendar day picked for the day log sheet.
struct CycleDaySelection: Identifiable {
    let date: Date
    var id: Date { date }
}

/// Trying-to-conceive mode, tab 1 (default): where the cycle stands today,
/// the next period, the fertile window and quick logging.
struct CycleHomeView: View {
    @Environment(CycleCoordinator.self) private var cycle
    @State private var showingLastPeriodSheet = false
    @State private var logDay: CycleDaySelection?
    @State private var actionFailure: CycleFailure?
    @State private var working = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(L10n.cycleTitle)
                .sheet(isPresented: $showingLastPeriodSheet) { LastPeriodSheet() }
                .sheet(item: $logDay) { selection in
                    CycleDayLogSheet(day: selection.date, existing: cycle.log(on: selection.date))
                }
                .alert(failureMessage ?? "", isPresented: failureBinding) {
                    Button(L10n.commonOK) {}
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let forecast = cycle.forecast {
            ScrollView {
                cards(for: forecast)
                    .padding()
            }
        } else {
            ContentUnavailableView {
                Label(L10n.cycleEmptyTitle, systemImage: "drop.circle")
            } description: {
                Text(L10n.cycleEmptyBody)
            } actions: {
                Button(L10n.cycleEmptyAction) { showingLastPeriodSheet = true }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("cycleAddPeriodButton")
            }
        }
    }

    private func cards(for forecast: CycleForecast) -> some View {
        VStack(spacing: 16) {
            CycleStatusCard(forecast: forecast)
            if forecast.isLongOpenPeriod {
                CycleNoticeCard(
                    symbol: "drop.triangle.fill",
                    title: L10n.cycleLongPeriodTitle(forecast.cycleDay),
                    message: L10n.cycleLongPeriodBody,
                    identifier: "cycleLongPeriodCard"
                )
            }
            if forecast.isNoticeablyLate {
                lateCard(forecast)
            }
            if forecast.irregularWarning {
                CycleNoticeCard(
                    symbol: "stethoscope",
                    title: L10n.cycleIrregularTitle,
                    message: L10n.cycleIrregularBody,
                    identifier: "cycleIrregularCard"
                )
            }
            NextPeriodCard(forecast: forecast)
            FertileWindowCard(forecast: forecast)
            quickActions(for: forecast)
            if cycle.notificationsDenied {
                Text(L10n.cycleNotificationsOff)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(L10n.cycleDisclaimer)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func lateCard(_ forecast: CycleForecast) -> some View {
        CycleNoticeCard(
            symbol: "calendar.badge.exclamationmark",
            title: L10n.cycleLateTitle(forecast.daysLate),
            message: L10n.cycleLateBody,
            identifier: "cycleLateCard"
        )
    }

    private func quickActions(for forecast: CycleForecast) -> some View {
        VStack(spacing: 12) {
            Button {
                Task { await togglePeriod(open: forecast.openPeriod) }
            } label: {
                Label(
                    forecast.openPeriod == nil ? L10n.cycleStartPeriod : L10n.cycleEndPeriod,
                    systemImage: forecast.openPeriod == nil ? "drop.fill" : "drop"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(working)
            .accessibilityIdentifier("cyclePeriodButton")

            Button {
                logDay = CycleDaySelection(date: Calendar.current.startOfDay(for: AppClock.now()))
            } label: {
                Label(L10n.cycleLogToday, systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityIdentifier("cycleLogTodayButton")
        }
    }

    private func togglePeriod(open: PeriodRecord?) async {
        working = true
        defer { working = false }
        let failure: CycleFailure?
        if let open {
            failure = await cycle.endPeriod(id: open.id, on: AppClock.now())
        } else {
            failure = await cycle.startPeriod(on: AppClock.now())
        }
        if let failure {
            cycle.clearFailure()
            actionFailure = failure
        }
    }

    private var failureMessage: String? {
        (actionFailure ?? cycle.failure).map(L10n.cycleFailure)
    }

    /// Only while no sheet is open: the sheets report their own errors.
    private var failureBinding: Binding<Bool> {
        Binding(
            get: { failureMessage != nil && logDay == nil && !showingLastPeriodSheet },
            set: { if !$0 { actionFailure = nil; cycle.clearFailure() } }
        )
    }
}
```

`App/Cycle/LastPeriodSheet.swift`:
```swift
import KickCore
import SwiftUI

/// "When did your last period start?" — from the empty Cycle tab.
struct LastPeriodSheet: View {
    @Environment(CycleCoordinator.self) private var cycle
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var failure: CycleFailure?
    @State private var saving = false
    private let now: Date

    init(now: Date = AppClock.now()) {
        self.now = now
        _date = State(initialValue: now)
    }

    var body: some View {
        NavigationStack {
            Form {
                LastPeriodPicker(date: $date, now: now)
            }
            .navigationTitle(L10n.lastPeriodTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.commonCancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.commonSave) { Task { await save() } }
                        .disabled(saving)
                        .accessibilityIdentifier("lastPeriodSave")
                }
            }
            .alert(failure.map(L10n.cycleFailure) ?? "", isPresented: Binding(
                get: { failure != nil },
                set: { if !$0 { failure = nil } }
            )) {
                Button(L10n.commonOK) {}
            }
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        if let failure = await cycle.logLastPeriod(startingOn: date) {
            cycle.clearFailure()
            self.failure = failure
        } else {
            dismiss()
        }
    }
}

/// Wheel picker for the first day of the last period (the past year up to
/// today). A `Section`: place it inside a `Form`. Shared with onboarding.
struct LastPeriodPicker: View {
    @Binding var date: Date
    let now: Date

    var body: some View {
        Section {
            DatePicker(
                L10n.lastPeriodDate,
                selection: $date,
                in: CycleRules.lastPeriodRange(now: now, calendar: .current),
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .accessibilityLabel(L10n.lastPeriodDate)
            .accessibilityIdentifier("lastPeriodPicker")
        } header: {
            Text(L10n.lastPeriodDate)
        } footer: {
            Text(L10n.lastPeriodHint)
        }
    }
}
```

- [ ] **Step 6: Sheet ghi ngày**

`App/Cycle/CycleDayLogSheet.swift`:
```swift
import KickCore
import SwiftUI

/// Log or edit one day: start/end a period there, LH test, BBT, mucus, note.
/// Period buttons apply at once; the signals are saved with "Save".
struct CycleDayLogSheet: View {
    let day: Date
    private let existing: CycleLogRecord?

    @Environment(CycleCoordinator.self) private var cycle
    @Environment(\.dismiss) private var dismiss
    @State private var lh: LHResult?
    @State private var temperatureText: String
    @State private var mucus: CervicalMucus?
    @State private var note: String
    @State private var temperatureInvalid = false
    @State private var failure: CycleFailure?
    @State private var saving = false
    @State private var confirmingDeletePeriod = false

    init(day: Date, existing: CycleLogRecord?) {
        self.day = Calendar.current.startOfDay(for: day)
        self.existing = existing
        _lh = State(initialValue: existing?.lh)
        _temperatureText = State(initialValue: existing?.bbtCelsius.map {
            $0.formatted(.number.precision(.fractionLength(1...2)).grouping(.never))
        } ?? "")
        _mucus = State(initialValue: existing?.mucus)
        _note = State(initialValue: existing?.note ?? "")
    }

    /// The period covering this day, or an earlier one still open that this day could end.
    private var coveringPeriod: PeriodRecord? { cycle.period(on: day) }
    private var openPeriodBefore: PeriodRecord? {
        guard let open = cycle.forecast?.openPeriod, open.startDate < day else { return nil }
        return open
    }

    var body: some View {
        NavigationStack {
            Form {
                periodSection

                Section(L10n.dayLogLH) {
                    Picker(L10n.dayLogLH, selection: $lh) {
                        Text(L10n.dayLogLHNone).tag(LHResult?.none)
                        Text(L10n.dayLogLHNegative).tag(LHResult?.some(.negative))
                        Text(L10n.dayLogLHPositive).tag(LHResult?.some(.positive))
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("dayLogLHPicker")
                }

                Section {
                    TextField(L10n.dayLogBBTPlaceholder, text: $temperatureText)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel(L10n.dayLogBBT)
                        .accessibilityIdentifier("dayLogBBTField")
                        .onChange(of: temperatureText) { temperatureInvalid = false }
                    if temperatureInvalid {
                        Label(L10n.cycleFailure(.invalidTemperature), systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("dayLogBBTError")
                    }
                } header: {
                    Text(L10n.dayLogBBT)
                } footer: {
                    Text(L10n.dayLogBBTHint)
                }

                Section(L10n.dayLogMucus) {
                    Picker(L10n.dayLogMucus, selection: $mucus) {
                        Text(L10n.dayLogMucusNone).tag(CervicalMucus?.none)
                        ForEach(CervicalMucus.allCases, id: \.self) { value in
                            Text(L10n.mucus(value)).tag(CervicalMucus?.some(value))
                        }
                    }
                    .accessibilityIdentifier("dayLogMucusPicker")
                }

                Section(L10n.dayLogNote) {
                    TextField(L10n.dayLogNote, text: $note, axis: .vertical)
                        .lineLimit(2...5)
                        .accessibilityIdentifier("dayLogNoteField")
                }
            }
            .navigationTitle(day.formatted(date: .abbreviated, time: .omitted))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.commonCancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.commonSave) { Task { await save() } }
                        .disabled(saving)
                        .accessibilityIdentifier("dayLogSave")
                }
            }
            .alert(failure.map(L10n.cycleFailure) ?? "", isPresented: Binding(
                get: { failure != nil },
                set: { if !$0 { failure = nil } }
            )) {
                Button(L10n.commonOK) {}
            }
            .confirmationDialog(L10n.dayLogPeriodDeleteConfirm, isPresented: $confirmingDeletePeriod, titleVisibility: .visible) {
                Button(L10n.commonDelete, role: .destructive) {
                    if let period = coveringPeriod {
                        Task { await run { await cycle.deletePeriod(id: period.id) } }
                    }
                }
                Button(L10n.commonCancel, role: .cancel) {}
            }
        }
    }

    @ViewBuilder
    private var periodSection: some View {
        Section(L10n.dayLogPeriodSection) {
            if let period = coveringPeriod {
                Text(description(of: period))
                    .accessibilityIdentifier("dayLogPeriodInfo")
                if period.isOpen, day > period.startDate {
                    endButton(for: period)
                }
                Button(L10n.dayLogPeriodDelete, role: .destructive) { confirmingDeletePeriod = true }
                    .accessibilityIdentifier("dayLogDeletePeriod")
            } else {
                if let open = openPeriodBefore {
                    endButton(for: open)
                }
                Button(L10n.dayLogPeriodStart) {
                    Task { await run { await cycle.startPeriod(on: day) } }
                }
                .disabled(saving)
                .accessibilityIdentifier("dayLogStartPeriod")
            }
        }
    }

    private func endButton(for period: PeriodRecord) -> some View {
        Button(L10n.dayLogPeriodEnd) {
            Task { await run { await cycle.endPeriod(id: period.id, on: day) } }
        }
        .disabled(saving)
        .accessibilityIdentifier("dayLogEndPeriod")
    }

    private func description(of period: PeriodRecord) -> String {
        let start = Formatting.cycleDate(period.startDate)
        guard let end = period.endDate else { return L10n.dayLogPeriodSince(start) }
        return L10n.dayLogPeriodRange(start, Formatting.cycleDate(end))
    }

    private func run(_ action: () async -> CycleFailure?) async {
        saving = true
        defer { saving = false }
        if let result = await action() {
            cycle.clearFailure()
            failure = result
        }
    }

    private func save() async {
        let temperature: Double?
        switch TemperatureEntry(text: temperatureText) {
        case .empty: temperature = nil
        case .valid(let value): temperature = value
        case .invalid:
            temperatureInvalid = true
            return
        }
        let log = CycleLogRecord(
            id: existing?.id ?? UUID(), day: day, lh: lh, bbtCelsius: temperature, mucus: mucus, note: note
        )
        saving = true
        defer { saving = false }
        if let result = await cycle.saveLog(log) {
            cycle.clearFailure()
            failure = result
        } else {
            dismiss()
        }
    }
}
```

- [ ] **Step 7: Commit, push, xác minh CI**

```bash
scripts/test-core.sh
git add App Shared UITests README.md
git commit -F - <<'MSG'
feat(app): add trying-to-conceive mode with the Cycle tab and day log

RootView picks the tabs from appMode; -seedCycles seeds sample cycles in
Debug UI tests only.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`, gồm `CycleUITests` (4 test), `CycleScreenshotTests` (3 test) và mọi test cũ (chế độ mang thai không đổi vì `appMode` mặc định là `pregnant`). Nếu chỉ một UI test không liên quan timeout → quy tắc flake ở "Quy trình xác minh".

- [ ] **Step 8: Kiểm tra trực quan (Read tool, `ci-artifacts/screenshots/`)**

- `cycle-home-period-vi-light`: tiêu đề "Chu kỳ của bạn"; vòng 28 đoạn: đoạn 1–2 hồng đậm, 3–5 hồng nhạt (dự đoán), 10–16 xanh lá, 14–15 tím; chấm hôm nay ở đoạn 2; số "2" giữa vòng; "Ngày 2 của chu kỳ"; "Đang hành kinh" kèm giọt nước hồng; thẻ "Kỳ kinh tiếp theo" "29/10 (còn 27 ngày)"; thẻ "Cửa sổ thụ thai" "10/10 – 16/10", "Ngày rụng trứng ước tính: 15/10"; **không** có nhãn độ tin cậy thấp; thanh tab đúng 2 mục "Chu kỳ" (đang chọn) và "Cài đặt". `…-bottom`: nút "Hôm nay hết kỳ kinh", nút "Ghi hôm nay", dòng "Dự đoán chỉ là ước tính. Không dùng ứng dụng để tránh thai.", dòng nhắc thông báo đang tắt.
- `cycle-home-fertile-vi-light`: "Ngày 13 của chu kỳ", "Khả năng thụ thai cao" (lá xanh); thẻ kỳ kinh "18/10 (còn 16 ngày)"; thẻ cửa sổ "29/09 – 05/10", "Ngày rụng trứng ước tính: 04/10". `…-bottom`: nút "Hôm nay bắt đầu kỳ kinh".
- `cycle-home-late-vi-light`: số "33", "Ngày 33 của chu kỳ", "Khả năng thụ thai thấp"; thẻ cam "Kỳ kinh đã trễ 4 ngày" + lời khuyên thử thai; thẻ kỳ kinh "Trễ 4 ngày"; chấm hôm nay ở cuối vòng (vòng dài 33 đoạn).
- `cycle-home-irregular-vi-light`: "Ngày 11 của chu kỳ"; thẻ cam "Chu kỳ có vẻ không đều" (ống nghe) + gợi ý gặp bác sĩ; thẻ cửa sổ "30/09 – 12/10", rụng trứng "08/10" và nhãn cam "Độ tin cậy thấp — chu kỳ chưa đều"; thẻ kỳ kinh "22/10 (còn 20 ngày)".
- Bản `-en-light`: "Your cycle", "Day 13 of your cycle", "High chance of conceiving", "10/18 · days to go: 16", "09/29 – 10/05", "Estimated ovulation: 10/04"; late: "Your period is 4 days late", "Days late: 4".
- Bản `-vi-dark`: nền tối, chữ trắng đủ tương phản, đoạn vòng xám/hồng/xanh/tím phân biệt rõ, thẻ cam đọc được.
- `cycle-empty-*`: biểu tượng giọt nước, "Kỳ kinh gần nhất bắt đầu ngày nào?"/"When did your last period start?", mô tả, nút "Nhập kỳ kinh"/"Add last period". `last-period-sheet-vi`: tiêu đề "Kỳ kinh gần nhất", bánh xe ngày (thứ tự ngày–tháng–năm của vi), header "Ngày đầu tiên của kỳ kinh gần nhất", footer gợi ý, "Hủy"/"Lưu".
- `day-log-vi-light`: tiêu đề ngày 2 thg 10 2026 dạng rút gọn; mục "Kỳ kinh" có nút "Bắt đầu kỳ kinh ngày này"; "Que thử rụng trứng (LH)" segmented 3 lựa chọn, "Chưa thử" đang chọn; ô BBT "36,3", footer "°C, đo ngay khi vừa thức dậy…"; "Dịch nhầy cổ tử cung" = "Như lòng trắng trứng"; "Ghi chú" trống; "Hủy"/"Lưu". `day-log-en-light`: "36.3", "Egg white", "Not taken". `day-log-vi-dark`: đọc rõ.
- `day-log-bbt-error-vi`: ô "34", dòng đỏ có tam giác "Nhập nhiệt độ trong khoảng 35,0–38,5 °C.", sheet vẫn mở.
- Ảnh cũ (`pregnancy-home-*`, `counter-*`, `history-*`, `appointments-*`, `settings*`) không đổi so với trước.

---
### Task 9: Tab Lịch — lịch tháng, chú thích màu, VoiceOver từng ngày, chạm ngày → sheet ghi ngày

**Files:**
- Create: `App/Cycle/CycleCalendarView.swift`
- Modify: `App/RootView.swift` (enum `AppTab`, `cycleTabs`), `Shared/L10n.swift`, `Shared/Localizable.xcstrings`, `UITests/UITestSupport.swift` (enum `CycleModeTab`), `UITests/CycleUITests.swift`, `UITests/CycleScreenshotTests.swift`

**Interfaces:**
- Consumes: `CycleCalendarGrid` (Task 6), `CycleForecast.dayStatus(for:)` (Task 3), `CycleCoordinator.forecast/log(on:)` (Task 5), `CycleDaySelection`, `CycleDayLogSheet(day:existing:)`, `CyclePalette`, `Formatting.spokenDay/temperature`, `L10n.mucus(_:)`, `View.card(tint:)` (Task 8 / có sẵn).
- Produces: `struct CycleCalendarView: View`, `struct CalendarDayCell: View`, `struct CycleLegend: View`, `enum CycleAccessibility { static func dayLabel(day: Date, status: CycleDayStatus?, log: CycleLogRecord?, isToday: Bool) -> String }` (vd. "October 1, fertile window, negative LH test logged, temperature 36.4 °C, Creamy" / "1 tháng 10, cửa sổ thụ thai, đã ghi que thử âm tính, …"); `AppTab.calendar`; `CycleModeTab { case cycle = 0, calendar, settings }`.

- [ ] **Step 1: Viết UI test trước**

Trong `UITests/UITestSupport.swift`, thay
```swift
enum CycleModeTab: Int {
    case cycle = 0
    case settings
}
```
bằng
```swift
enum CycleModeTab: Int {
    case cycle = 0
    case calendar
    case settings
}
```

Trong `UITests/CycleUITests.swift`, thay dấu `}` cuối cùng của file (đóng `class CycleUITests`) bằng:
```swift

    /// Spec §5/§7: the Calendar tab colours days, reads them out for VoiceOver,
    /// changes month and opens the day log.
    @MainActor
    func testCalendarDaysChangeMonthAndOpenTheDayLog() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "fertile")
        app.openCycleTab(.calendar)
        let title = app.staticTexts["calendarMonthTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, "October 2026")

        func day(_ prefix: String) -> XCUIElement {
            app.buttons.matching(NSPredicate(format: "identifier == 'calendarDay' AND label BEGINSWITH %@", prefix)).firstMatch
        }
        // Fertile window 09-29…10-05, ovulation 10-04; a negative LH test was logged on 10-01.
        XCTAssertTrue(day("October 1,").label.contains("fertile window, negative LH test logged"), day("October 1,").label)
        XCTAssertTrue(day("October 2,").label.contains("today, fertile window"), day("October 2,").label)
        XCTAssertTrue(day("October 4,").label.contains("most fertile day"), day("October 4,").label)
        XCTAssertTrue(day("October 18,").label.contains("predicted period"), day("October 18,").label)
        XCTAssertFalse(day("October 20,").isEnabled) // future days can't be logged

        app.buttons["calendarNext"].tap()
        waitForLabel(title, containing: "November 2026")
        app.buttons["calendarPrevious"].tap()
        waitForLabel(title, containing: "October 2026")

        day("October 2,").tap()
        let positive = app.segmentedControls.buttons["Positive"]
        XCTAssertTrue(positive.waitForExistence(timeout: 5))
        positive.tap()
        app.buttons["dayLogSave"].tap()
        // Ovulation moves from 10-04 to 10-03: today (the day before) becomes a most
        // fertile day and 10-04 drops back to the end of the fertile window.
        waitForLabel(day("October 2,"), containing: "today, most fertile day, positive LH test logged")
        XCTAssertTrue(day("October 4,").label.contains("fertile window"), day("October 4,").label)
    }
}
```

Trong `UITests/CycleScreenshotTests.swift`, thay dấu `}` cuối cùng của file bằng:
```swift

    @MainActor
    func testCalendarScreens() {
        for (language, dark) in Self.variants {
            let suffix = "\(language)-\(dark ? "dark" : "light")"
            let app = XCUIApplication.launchPinned(language: language, dark: dark, seedCycles: "fertile")
            app.openCycleTab(.calendar)
            XCTAssertTrue(app.staticTexts["calendarMonthTitle"].waitForExistence(timeout: 10))
            attachScreenshot(app, "calendar-fertile-\(suffix)")
            if language == "vi", !dark {
                app.buttons["calendarNext"].tap()
                attachScreenshot(app, "calendar-next-month-vi-light")
                app.buttons["calendarPrevious"].tap()
                let legend = app.descendants(matching: .any)["calendarLegend"]
                app.scrollUntilHittable(legend)
                attachScreenshot(app, "calendar-legend-vi-light")
            }
            app.terminate()
        }
        for scenario in ["period", "irregular"] {
            let app = XCUIApplication.launchPinned(language: "vi", seedCycles: scenario)
            app.openCycleTab(.calendar)
            XCTAssertTrue(app.staticTexts["calendarMonthTitle"].waitForExistence(timeout: 10))
            attachScreenshot(app, "calendar-\(scenario)-vi-light")
            app.terminate()
        }
    }
}
```

- [ ] **Step 2: Chuỗi và L10n**

```bash
scripts/add-strings.py <<'JSON'
{
  "tab.calendar": ["Calendar", "Lịch"],
  "calendar.title": ["Calendar", "Lịch chu kỳ"],
  "calendar.previous": ["Previous month", "Tháng trước"],
  "calendar.next": ["Next month", "Tháng sau"],
  "calendar.emptyHint": ["Add your last period on the Cycle tab to see predictions here.", "Nhập kỳ kinh gần nhất ở tab Chu kỳ để xem dự đoán tại đây."],
  "calendar.legend.period": ["Period", "Kỳ kinh"],
  "calendar.legend.predicted": ["Predicted period", "Kỳ kinh dự đoán"],
  "calendar.legend.fertile": ["Fertile window", "Cửa sổ thụ thai"],
  "calendar.legend.peak": ["Ovulation and the day before", "Ngày rụng trứng và ngày trước đó"],
  "calendar.legend.logged": ["Signals logged", "Có ghi dấu hiệu"],
  "calendar.a11y.today": ["today", "hôm nay"],
  "calendar.a11y.period": ["period", "kỳ kinh"],
  "calendar.a11y.predicted": ["predicted period", "kỳ kinh dự đoán"],
  "calendar.a11y.fertile": ["fertile window", "cửa sổ thụ thai"],
  "calendar.a11y.peak": ["most fertile day", "ngày dễ thụ thai nhất"],
  "calendar.a11y.lhPositive": ["positive LH test logged", "đã ghi que thử dương tính"],
  "calendar.a11y.lhNegative": ["negative LH test logged", "đã ghi que thử âm tính"],
  "calendar.a11y.temperature": ["temperature %@", "nhiệt độ %@"],
  "calendar.a11y.note": ["note logged", "có ghi chú"]
}
JSON
```
Expected: tổng số chuỗi tăng 19.

Trong `Shared/L10n.swift`, chèn ngay sau dòng `    static var dayLogNote: String { t("dayLog.note") }`:
```swift

    static var tabCalendar: String { t("tab.calendar") }

    static var calendarTitle: String { t("calendar.title") }
    static var calendarPrevious: String { t("calendar.previous") }
    static var calendarNext: String { t("calendar.next") }
    static var calendarEmptyHint: String { t("calendar.emptyHint") }
    static var calendarLegendPeriod: String { t("calendar.legend.period") }
    static var calendarLegendPredicted: String { t("calendar.legend.predicted") }
    static var calendarLegendFertile: String { t("calendar.legend.fertile") }
    static var calendarLegendPeak: String { t("calendar.legend.peak") }
    static var calendarLegendLogged: String { t("calendar.legend.logged") }
    static var calendarA11yToday: String { t("calendar.a11y.today") }
    static var calendarA11yPeriod: String { t("calendar.a11y.period") }
    static var calendarA11yPredicted: String { t("calendar.a11y.predicted") }
    static var calendarA11yFertile: String { t("calendar.a11y.fertile") }
    static var calendarA11yPeak: String { t("calendar.a11y.peak") }
    static var calendarA11yLHPositive: String { t("calendar.a11y.lhPositive") }
    static var calendarA11yLHNegative: String { t("calendar.a11y.lhNegative") }
    static func calendarA11yTemperature(_ value: String) -> String { String(format: t("calendar.a11y.temperature"), value) }
    static var calendarA11yNote: String { t("calendar.a11y.note") }
```

- [ ] **Step 3: Màn Lịch**

`App/Cycle/CycleCalendarView.swift`:
```swift
import KickCore
import SwiftUI

/// Trying-to-conceive mode, tab 2: month grid coloured by cycle status.
/// Swipe or use the arrows to change month; tap a past day to log it.
struct CycleCalendarView: View {
    @Environment(CycleCoordinator.self) private var cycle
    @State private var month = CycleCalendarGrid.startOfMonth(AppClock.now())
    @State private var logDay: CycleDaySelection?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    monthHeader
                    grid
                    CycleLegend()
                    if cycle.forecast == nil {
                        Text(L10n.calendarEmptyHint)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 30).onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) * 2 else { return }
                    showMonth(value.translation.width < 0 ? 1 : -1)
                }
            )
            .navigationTitle(L10n.calendarTitle)
            .sheet(item: $logDay) { selection in
                CycleDayLogSheet(day: selection.date, existing: cycle.log(on: selection.date))
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button { showMonth(-1) } label: {
                Image(systemName: "chevron.left")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel(L10n.calendarPrevious)
            .accessibilityIdentifier("calendarPrevious")
            Spacer()
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("calendarMonthTitle")
            Spacer()
            Button { showMonth(1) } label: {
                Image(systemName: "chevron.right")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel(L10n.calendarNext)
            .accessibilityIdentifier("calendarNext")
        }
    }

    private var grid: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: AppClock.now())
        let days = CycleCalendarGrid.days(inMonthOf: month, calendar: calendar)
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(CycleCalendarGrid.weekdaySymbols(calendar: calendar).enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let day {
                    CalendarDayCell(
                        day: day,
                        status: cycle.forecast?.dayStatus(for: day),
                        log: cycle.log(on: day),
                        isToday: day == today,
                        isFuture: day > today
                    ) {
                        logDay = CycleDaySelection(date: day)
                    }
                } else {
                    Color.clear
                        .frame(height: 1)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private func showMonth(_ offset: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            month = CycleCalendarGrid.month(offset, from: month)
        }
    }
}

struct CalendarDayCell: View {
    let day: Date
    /// nil when nothing has been logged yet (no forecast).
    let status: CycleDayStatus?
    let log: CycleLogRecord?
    let isToday: Bool
    let isFuture: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .callout) private var height: CGFloat = 46

    private var isRecordedPeriod: Bool { status == .period(isPredicted: false) }
    private var isPredictedPeriod: Bool { status == .period(isPredicted: true) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(day.formatted(.dateTime.day()))
                    .font(.callout.weight(isToday || isRecordedPeriod || status == .peak ? .bold : .regular))
                HStack(spacing: 2) {
                    if let symbol = status.flatMap(CyclePalette.symbol(for:)) {
                        Image(systemName: symbol)
                    }
                    if log != nil {
                        Circle().frame(width: 5, height: 5)
                    }
                }
                .font(.system(size: 8))
                .frame(height: 9)
            }
            .frame(maxWidth: .infinity, minHeight: height)
            .foregroundStyle(foreground)
            .background(background, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                if isPredictedPeriod {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(CyclePalette.period, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                }
                if isToday {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.primary, lineWidth: 2)
                }
            }
            .opacity(isFuture && status == nil ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(CycleAccessibility.dayLabel(day: day, status: status, log: log, isToday: isToday))
        .accessibilityIdentifier("calendarDay")
    }

    private var background: Color {
        switch status {
        case .period(isPredicted: false)?: CyclePalette.period
        case .period(isPredicted: true)?: CyclePalette.period.opacity(0.12)
        case .fertile?: CyclePalette.fertile.opacity(0.3)
        case .peak?: CyclePalette.peak
        case .low?, nil: Color.clear
        }
    }

    /// Light text on the solid period and peak fills, normal text elsewhere.
    private var foreground: Color {
        switch status {
        case .period(isPredicted: false)?, .peak?: Color(.systemBackground)
        default: Color.primary
        }
    }
}

struct CycleLegend: View {
    private struct Item: Identifiable {
        let id: String
        let title: String
        let symbol: String
        let fill: Color
        var dashed = false
    }

    private var items: [Item] {
        [
            Item(id: "period", title: L10n.calendarLegendPeriod, symbol: "drop.fill", fill: CyclePalette.period),
            Item(id: "predicted", title: L10n.calendarLegendPredicted, symbol: "drop", fill: CyclePalette.period.opacity(0.12), dashed: true),
            Item(id: "fertile", title: L10n.calendarLegendFertile, symbol: "leaf.fill", fill: CyclePalette.fertile.opacity(0.3)),
            Item(id: "peak", title: L10n.calendarLegendPeak, symbol: "sparkles", fill: CyclePalette.peak),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items) { item in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(item.fill)
                        .overlay {
                            if item.dashed {
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(CyclePalette.period, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                            }
                        }
                        .overlay {
                            Image(systemName: item.symbol)
                                .font(.caption2)
                                .foregroundStyle(item.id == "period" || item.id == "peak" ? Color(.systemBackground) : Color.primary)
                        }
                        .frame(width: 28, height: 22)
                    Text(item.title).font(.subheadline)
                }
            }
            HStack(spacing: 10) {
                Circle().frame(width: 6, height: 6)
                    .frame(width: 28, height: 22)
                Text(L10n.calendarLegendLogged).font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("calendarLegend")
    }
}

/// What VoiceOver reads for a calendar day, e.g.
/// "October 12, fertile window, positive LH test logged".
enum CycleAccessibility {
    static func dayLabel(day: Date, status: CycleDayStatus?, log: CycleLogRecord?, isToday: Bool) -> String {
        var parts = [Formatting.spokenDay(day)]
        if isToday { parts.append(L10n.calendarA11yToday) }
        switch status {
        case .period(isPredicted: false)?: parts.append(L10n.calendarA11yPeriod)
        case .period(isPredicted: true)?: parts.append(L10n.calendarA11yPredicted)
        case .fertile?: parts.append(L10n.calendarA11yFertile)
        case .peak?: parts.append(L10n.calendarA11yPeak)
        case .low?, nil: break
        }
        if let log {
            switch log.lh {
            case .positive?: parts.append(L10n.calendarA11yLHPositive)
            case .negative?: parts.append(L10n.calendarA11yLHNegative)
            case nil: break
            }
            if let bbt = log.bbtCelsius { parts.append(L10n.calendarA11yTemperature(Formatting.temperature(bbt))) }
            if let mucus = log.mucus { parts.append(L10n.mucus(mucus)) }
            if !log.note.isEmpty { parts.append(L10n.calendarA11yNote) }
        }
        return parts.joined(separator: ", ")
    }
}
```

- [ ] **Step 4: Thêm tab Lịch vào `RootView`**

Trong `App/RootView.swift`, thay
```swift
    case settings
    case cycle
}
```
bằng
```swift
    case settings
    case cycle
    case calendar
}
```
và thay toàn bộ thuộc tính `cycleTabs` bằng:
```swift
    /// Trying-to-conceive mode: Cycle · Calendar · Settings.
    private var cycleTabs: some View {
        TabView(selection: $selectedTab) {
            CycleHomeView()
                .tabItem { Label(L10n.tabCycle, systemImage: "drop.circle.fill") }
                .tag(AppTab.cycle)
            CycleCalendarView()
                .tabItem { Label(L10n.tabCalendar, systemImage: "calendar") }
                .tag(AppTab.calendar)
            SettingsView()
                .tabItem { Label(L10n.tabSettings, systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
    }
```

- [ ] **Step 5: Commit, push, xác minh CI**

```bash
scripts/test-core.sh
git add App Shared UITests
git commit -F - <<'MSG'
feat(app): add the cycle Calendar tab with legend and per-day VoiceOver labels

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`, gồm `CycleUITests.testCalendarDaysChangeMonthAndOpenTheDayLog` và `CycleScreenshotTests.testCalendarScreens`.

- [ ] **Step 6: Kiểm tra trực quan (Read tool)**

- `calendar-fertile-vi-light`: tiêu đề "Lịch chu kỳ"; giữa hai mũi tên là "tháng 10 năm 2026"; hàng thứ bắt đầu bằng thứ Hai ("T2 … CN"); ngày 1 nằm ở cột thứ Năm (3 ô trống); ngày 1–5 nền xanh nhạt có lá (cửa sổ 29/09–05/10), ngày 3–4 nền tím đặc, chữ sáng, có ✨; ngày 2 có viền đậm (hôm nay); chấm nhỏ ở ngày 1 và 2 (đã ghi log); 18–22 nền hồng rất nhạt **viền đứt** (kỳ kinh dự đoán, giọt nước rỗng); 27–30 xanh, 31 tím (chu kỳ sau: rụng trứng 01/11); thanh tab 3 mục "Chu kỳ" · "Lịch" (đang chọn) · "Cài đặt".
- `calendar-fertile-en-light`: "October 2026", hàng thứ bắt đầu "S" (Chủ nhật), ngày 1 ở cột thứ Năm (4 ô trống), màu như trên.
- `calendar-fertile-vi-dark`: nền tối; số trên ô tím/hồng đậm đọc được; viền hôm nay sáng.
- `calendar-next-month-vi-light`: "tháng 11 năm 2026"; ngày 1 tím, 2 xanh; 15–19 hồng nhạt viền đứt.
- `calendar-legend-vi-light`: thẻ chú thích 5 dòng: "Kỳ kinh" (ô hồng đặc + giọt nước), "Kỳ kinh dự đoán" (ô nhạt viền đứt), "Cửa sổ thụ thai" (xanh + lá), "Ngày rụng trứng và ngày trước đó" (tím + ✨), "Có ghi dấu hiệu" (chấm).
- `calendar-period-vi-light`: ngày 1–2 hồng đặc (đã ghi), 3–5 hồng nhạt viền đứt, 10–16 xanh với 14–15 tím, 29–31 hồng nhạt viền đứt.
- `calendar-irregular-vi-light`: ngày 1–12 xanh (cửa sổ nới rộng 30/09–12/10) với 7–8 tím; 22–26 hồng nhạt viền đứt.

---
### Task 10: "Tôi đã có thai" — sheet xác nhận và chuyển sang chế độ mang thai

Sheet xác nhận ngày đầu kỳ kinh cuối = `currentPeriodStart` (sửa được bằng `PregnancyDateForm`, mặc định ở chế độ LMP) → `CycleCoordinator.switchToPregnant(source:date:)` (lưu `PregnancyProfile`, `appMode = pregnant`, hủy nhắc chu kỳ, giữ dữ liệu chu kỳ) → `RootView` đổi sang 4 tab và mở tab Thai kỳ (Task 8 đã có `onChange(of: appMode)`). Nút nằm trên thẻ trễ kinh (≥ 3 ngày); Task 11 dùng lại sheet khi đổi chế độ trong Cài đặt.

**Files:**
- Create: `App/Cycle/ImPregnantSheet.swift`
- Modify: `App/Cycle/CycleHomeView.swift` (thay toàn bộ), `Shared/L10n.swift`, `Shared/Localizable.xcstrings`, `UITests/CycleUITests.swift`, `UITests/CycleScreenshotTests.swift`

**Interfaces:**
- Consumes: `CycleCoordinator.switchToPregnant(source:date:)`, `CycleForecast.currentPeriodStart` (Task 3/5); có sẵn: `PregnancyDateForm(source:date:now:)` (id `pregnancyDateSourcePicker`, `pregnancyDatePicker`, `pregnancyEstimatedDue`), `PregnancyDateInput.clamp(_:for:now:)`, `PregnancyDateInput.initialSelection(for:now:)`, `PregnancyProfile.load(from:)`.
- Produces: `struct ImPregnantSheet: View { init(lastPeriodStart: Date?, now: Date = AppClock.now()) }` — có kỳ kinh → LMP = ngày đó; không có → lấy theo hồ sơ thai kỳ đã lưu (hoặc mặc định của `PregnancyDateInput`). Nút lưu id `imPregnantSave`; nút trên thẻ trễ kinh id `imPregnantButton`. L10n: `cycleImPregnant`, `imPregnantTitle`, `imPregnantBody`, `imPregnantKeepsData`.

- [ ] **Step 1: Viết UI test trước**

Trong `UITests/CycleUITests.swift`, thay dấu `}` cuối cùng của file bằng:
```swift

    /// Spec §8: "I'm pregnant" switches to the Pregnancy tab at the right week.
    @MainActor
    func testImPregnantOpensThePregnancyTabAtTheRightWeek() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "late")
        let button = app.buttons["imPregnantButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        app.scrollUntilHittable(button)
        button.tap()

        // Prefilled with the latest period, 2026-08-31 → due 2027-06-07.
        let estimate = app.staticTexts["pregnancyEstimatedDue"]
        XCTAssertTrue(estimate.waitForExistence(timeout: 5))
        XCTAssertTrue(estimate.label.contains("June 7, 2027"), estimate.label)
        app.buttons["imPregnantSave"].tap()

        // 32 days since the last period: 4 weeks 4 days, on the four pregnancy tabs.
        let progress = app.descendants(matching: .any)["weekProgressCard"]
        XCTAssertTrue(progress.waitForExistence(timeout: 10))
        XCTAssertTrue(progress.label.contains("Week 4 + 4 days"), progress.label)
        XCTAssertEqual(app.tabBars.buttons.count, 4)
    }
}
```

Trong `UITests/CycleScreenshotTests.swift`, thay dấu `}` cuối cùng của file bằng:
```swift

    @MainActor
    func testImPregnantScreens() {
        for (language, dark) in Self.variants {
            let suffix = "\(language)-\(dark ? "dark" : "light")"
            let app = XCUIApplication.launchPinned(language: language, dark: dark, seedCycles: "late")
            let button = app.buttons["imPregnantButton"]
            XCTAssertTrue(button.waitForExistence(timeout: 10))
            app.scrollUntilHittable(button)
            button.tap()
            XCTAssertTrue(app.buttons["imPregnantSave"].waitForExistence(timeout: 5))
            attachScreenshot(app, "im-pregnant-\(suffix)")
            if language == "vi", !dark {
                app.buttons["imPregnantSave"].tap()
                XCTAssertTrue(app.descendants(matching: .any)["weekProgressCard"].waitForExistence(timeout: 10))
                attachScreenshot(app, "im-pregnant-after-vi-light")
            }
            app.terminate()
        }
    }
}
```

- [ ] **Step 2: Chuỗi và L10n**

```bash
scripts/add-strings.py <<'JSON'
{
  "cycle.imPregnant": ["I'm pregnant", "Tôi đã có thai"],
  "imPregnant.title": ["Congratulations!", "Chúc mừng bạn!"],
  "imPregnant.body": ["Your due date is worked out from the first day of your last period. Check the date, then tap Save.", "Ngày dự sinh được tính từ ngày đầu tiên của kỳ kinh cuối. Hãy kiểm tra lại ngày rồi bấm Lưu."],
  "imPregnant.keepsData": ["Your cycle history is kept. You can switch back in Settings.", "Dữ liệu chu kỳ vẫn được giữ lại. Bạn có thể đổi lại trong Cài đặt."]
}
JSON
```
Expected: tổng số chuỗi tăng 4.

Trong `Shared/L10n.swift`, chèn ngay sau dòng `    static var cycleLogToday: String { t("cycle.logToday") }`:
```swift
    static var cycleImPregnant: String { t("cycle.imPregnant") }
    static var imPregnantTitle: String { t("imPregnant.title") }
    static var imPregnantBody: String { t("imPregnant.body") }
    static var imPregnantKeepsData: String { t("imPregnant.keepsData") }
```

- [ ] **Step 3: Sheet "Tôi đã có thai"**

`App/Cycle/ImPregnantSheet.swift`:
```swift
import KickCore
import SwiftUI

/// "I'm pregnant": confirm the first day of the last period (or a due date),
/// then switch to pregnancy mode. Cycle data is kept.
struct ImPregnantSheet: View {
    @Environment(CycleCoordinator.self) private var cycle
    @Environment(\.dismiss) private var dismiss
    @State private var source: PregnancyDateSource
    @State private var date: Date
    private let now: Date

    /// Starts from the latest logged period; without one, from the stored
    /// pregnancy dates (or the usual default).
    init(lastPeriodStart: Date?, now: Date = AppClock.now()) {
        self.now = now
        if let lastPeriodStart {
            _source = State(initialValue: .lmp)
            _date = State(initialValue: PregnancyDateInput.clamp(lastPeriodStart, for: .lmp, now: now))
        } else {
            let selection = PregnancyDateInput.initialSelection(for: PregnancyProfile.load(from: AppGroup.defaults), now: now)
            _source = State(initialValue: selection.source)
            _date = State(initialValue: selection.date)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.imPregnantTitle).font(.headline)
                            Text(L10n.imPregnantBody).font(.subheadline)
                        }
                    } icon: {
                        Image(systemName: "heart.fill").foregroundStyle(Color.accentColor)
                    }
                    .accessibilityElement(children: .combine)
                }
                PregnancyDateForm(source: $source, date: $date, now: now)
                Section {
                    Text(L10n.imPregnantKeepsData)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(L10n.cycleImPregnant)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.commonCancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.commonSave) {
                        cycle.switchToPregnant(source: source, date: date)
                        dismiss()
                    }
                    .accessibilityIdentifier("imPregnantSave")
                }
            }
        }
    }
}
```

- [ ] **Step 4: Nút trên thẻ trễ kinh**

Thay toàn bộ `App/Cycle/CycleHomeView.swift` bằng (khác bản Task 8 ở: `showingImPregnant`, sheet `ImPregnantSheet`, nút trong `lateCard`, điều kiện alert):
```swift
import KickCore
import SwiftUI

/// A calendar day picked for the day log sheet.
struct CycleDaySelection: Identifiable {
    let date: Date
    var id: Date { date }
}

/// Trying-to-conceive mode, tab 1 (default): where the cycle stands today,
/// the next period, the fertile window, quick logging and — once the period
/// is 3 days late — "I'm pregnant".
struct CycleHomeView: View {
    @Environment(CycleCoordinator.self) private var cycle
    @State private var showingLastPeriodSheet = false
    @State private var logDay: CycleDaySelection?
    @State private var actionFailure: CycleFailure?
    @State private var working = false
    @State private var showingImPregnant = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(L10n.cycleTitle)
                .sheet(isPresented: $showingLastPeriodSheet) { LastPeriodSheet() }
                .sheet(item: $logDay) { selection in
                    CycleDayLogSheet(day: selection.date, existing: cycle.log(on: selection.date))
                }
                .sheet(isPresented: $showingImPregnant) {
                    ImPregnantSheet(lastPeriodStart: cycle.forecast?.currentPeriodStart)
                }
                .alert(failureMessage ?? "", isPresented: failureBinding) {
                    Button(L10n.commonOK) {}
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let forecast = cycle.forecast {
            ScrollView {
                cards(for: forecast)
                    .padding()
            }
        } else {
            ContentUnavailableView {
                Label(L10n.cycleEmptyTitle, systemImage: "drop.circle")
            } description: {
                Text(L10n.cycleEmptyBody)
            } actions: {
                Button(L10n.cycleEmptyAction) { showingLastPeriodSheet = true }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("cycleAddPeriodButton")
            }
        }
    }

    private func cards(for forecast: CycleForecast) -> some View {
        VStack(spacing: 16) {
            CycleStatusCard(forecast: forecast)
            if forecast.isLongOpenPeriod {
                CycleNoticeCard(
                    symbol: "drop.triangle.fill",
                    title: L10n.cycleLongPeriodTitle(forecast.cycleDay),
                    message: L10n.cycleLongPeriodBody,
                    identifier: "cycleLongPeriodCard"
                )
            }
            if forecast.isNoticeablyLate {
                lateCard(forecast)
            }
            if forecast.irregularWarning {
                CycleNoticeCard(
                    symbol: "stethoscope",
                    title: L10n.cycleIrregularTitle,
                    message: L10n.cycleIrregularBody,
                    identifier: "cycleIrregularCard"
                )
            }
            NextPeriodCard(forecast: forecast)
            FertileWindowCard(forecast: forecast)
            quickActions(for: forecast)
            if cycle.notificationsDenied {
                Text(L10n.cycleNotificationsOff)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(L10n.cycleDisclaimer)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func lateCard(_ forecast: CycleForecast) -> some View {
        CycleNoticeCard(
            symbol: "calendar.badge.exclamationmark",
            title: L10n.cycleLateTitle(forecast.daysLate),
            message: L10n.cycleLateBody,
            identifier: "cycleLateCard"
        ) {
            Button { showingImPregnant = true } label: {
                Label(L10n.cycleImPregnant, systemImage: "heart.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("imPregnantButton")
        }
    }

    private func quickActions(for forecast: CycleForecast) -> some View {
        VStack(spacing: 12) {
            Button {
                Task { await togglePeriod(open: forecast.openPeriod) }
            } label: {
                Label(
                    forecast.openPeriod == nil ? L10n.cycleStartPeriod : L10n.cycleEndPeriod,
                    systemImage: forecast.openPeriod == nil ? "drop.fill" : "drop"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(working)
            .accessibilityIdentifier("cyclePeriodButton")

            Button {
                logDay = CycleDaySelection(date: Calendar.current.startOfDay(for: AppClock.now()))
            } label: {
                Label(L10n.cycleLogToday, systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityIdentifier("cycleLogTodayButton")
        }
    }

    private func togglePeriod(open: PeriodRecord?) async {
        working = true
        defer { working = false }
        let failure: CycleFailure?
        if let open {
            failure = await cycle.endPeriod(id: open.id, on: AppClock.now())
        } else {
            failure = await cycle.startPeriod(on: AppClock.now())
        }
        if let failure {
            cycle.clearFailure()
            actionFailure = failure
        }
    }

    private var failureMessage: String? {
        (actionFailure ?? cycle.failure).map(L10n.cycleFailure)
    }

    /// Only while no sheet is open: the sheets report their own errors.
    private var failureBinding: Binding<Bool> {
        Binding(
            get: { failureMessage != nil && logDay == nil && !showingLastPeriodSheet && !showingImPregnant },
            set: { if !$0 { actionFailure = nil; cycle.clearFailure() } }
        )
    }
}
```

- [ ] **Step 5: Commit, push, xác minh CI**

```bash
scripts/test-core.sh
git add App Shared UITests
git commit -F - <<'MSG'
feat(app): switch to pregnancy mode from the late-period card

"I'm pregnant" stores the last period as the LMP, switches mode, cancels
cycle reminders and keeps the cycle history.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`, gồm `CycleUITests.testImPregnantOpensThePregnancyTabAtTheRightWeek` và `CycleScreenshotTests.testImPregnantScreens`.

- [ ] **Step 6: Kiểm tra trực quan (Read tool)**

- `cycle-home-late-vi-light` (chụp lại): thẻ cam "Kỳ kinh đã trễ 4 ngày" có nút nổi bật "Tôi đã có thai" (trái tim) rộng hết thẻ, nằm trong nền cam.
- `im-pregnant-vi-light`: tiêu đề "Tôi đã có thai"; dòng đầu trái tim hồng "Chúc mừng bạn!" + giải thích; segmented "Ngày dự sinh | Kỳ kinh cuối" với "Kỳ kinh cuối" được chọn; bánh xe 31/08/2026; footer "Ngày dự sinh dự kiến: …7…6…2027" (định dạng dài vi); dòng "Dữ liệu chu kỳ vẫn được giữ lại…"; "Hủy"/"Lưu". `im-pregnant-en-light`: "Congratulations!", "Last period", "June 7, 2027". `im-pregnant-vi-dark`: đọc rõ.
- `im-pregnant-after-vi-light`: tab Thai kỳ "Thai kỳ của mẹ", "Tuần 4 + 4 ngày", "Tam cá nguyệt 1"; thanh tab 4 mục, "Thai kỳ" được chọn.

---
### Task 11: Onboarding chọn chế độ, Cài đặt (Chế độ + Chu kỳ), Thông tin y tế

Onboarding: sau "Tôi đã hiểu" là bước chọn chế độ; **Mong con** → nhập ngày đầu kỳ kinh gần nhất (hoặc "Để sau"), độ dài chu kỳ, số ngày hành kinh; **Đang mang thai** → bước nhập ngày thai kỳ như giai đoạn 2. Cài đặt: mục "Chế độ" (Mong con / Đang mang thai — sang Mong con đổi ngay, sang Mang thai đi qua sheet "Tôi đã có thai"), mục "Chu kỳ" chỉ ở chế độ Mong con, mục "Thai kỳ" chỉ ở chế độ mang thai. Thông tin y tế thêm đoạn cho chế độ Mong con (spec §5).

**Files:**
- Modify: `App/Onboarding/OnboardingView.swift` (thay toàn bộ), `App/Settings/SettingsView.swift` (thay toàn bộ), `App/Settings/MedicalInfoView.swift` (thay toàn bộ), `Shared/L10n.swift`, `Shared/Localizable.xcstrings`, `UITests/UITestSupport.swift` (`launchPinned`), `UITests/KickCounterUITests.swift` (`completeOnboarding`), `UITests/ScreenshotTests.swift` (`testOnboardingAndSettingsScreens`), `UITests/PregnancyUITests.swift` (`testClearingPregnancyDatesEmptiesPregnancyAndCounterTabs`), `UITests/CycleUITests.swift`, `UITests/CycleScreenshotTests.swift`

**Interfaces:**
- Consumes: `CycleCoordinator.settings/updateSettings(_:)/activateTryingToConceive()/logLastPeriod(startingOn:)/forecast` (Task 5), `CycleSettings` ranges/defaults, `AppMode` (Task 1), `LastPeriodPicker(date:now:)` (Task 8), `ImPregnantSheet(lastPeriodStart:)` (Task 10); có sẵn: `PregnancyDateForm`, `PregnancyDateSheet`, `KickCoordinator.setDailyReminder/notificationsAuthorized/liveActivitiesAvailable`.
- Produces: id `onboardingModeTTC`, `onboardingModePregnant`, `onboardingSaveCycle`, `onboardingSkipCycle`, `onboardingCycleLength`, `onboardingPeriodLength`, `settingsModePicker`, `settingsCycleLength`, `settingsPeriodLength`, `settingsCycleReminders`, `medicalTTC`; L10n `onboardingMode*`, `onboardingCycle*`, `modeTryingToConceive`, `modePregnant`, `cycleSettingsCycleLength(_:)`, `cycleSettingsPeriodLength(_:)`, `cycleSettingsHint`, `settingsModeSection`, `settingsCycleSection`, `settingsCycleReminders`, `settingsCycleRemindersHint`, `medicalTTCTitle`, `medicalTTCBody`; UI test `launchPinned(…, skipOnboarding: Bool = true)`.

- [ ] **Step 1: Cập nhật UI test có sẵn cho bước chọn chế độ**

Trong `UITests/UITestSupport.swift`, thay phần đầu hàm `launchPinned` (chữ ký + mảng `launchArguments`):
```swift
    @MainActor
    static func launchPinned(
        language: String = "en",
        dark: Bool = false,
        dueDate: String? = nil,
        seedCycles: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting", "-skipOnboarding",
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", language == "vi" ? "vi_VN" : "en_US",
            "-fixedNow", UITestDates.fixedNow,
        ]
```
bằng:
```swift
    @MainActor
    static func launchPinned(
        language: String = "en",
        dark: Bool = false,
        dueDate: String? = nil,
        seedCycles: String? = nil,
        skipOnboarding: Bool = true
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"] + (skipOnboarding ? ["-skipOnboarding"] : []) + [
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", language == "vi" ? "vi_VN" : "en_US",
            "-fixedNow", UITestDates.fixedNow,
        ]
```

Trong `UITests/KickCounterUITests.swift`, thay hàm `completeOnboarding()` bằng:
```swift
    private func completeOnboarding() {
        let next = app.buttons["onboardingNext"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        next.tap()
        next.tap()
        app.buttons["onboardingAgree"].tap()
        let pregnant = app.buttons["onboardingModePregnant"]
        XCTAssertTrue(pregnant.waitForExistence(timeout: 5))
        pregnant.tap()
        let later = app.buttons["onboardingSkipDate"]
        XCTAssertTrue(later.waitForExistence(timeout: 5))
        later.tap()
    }
```

Trong `UITests/ScreenshotTests.swift` (`testOnboardingAndSettingsScreens`), thay:
```swift
        app.buttons["onboardingAgree"].tap()
        let later = app.buttons["onboardingSkipDate"]
        XCTAssertTrue(later.waitForExistence(timeout: 5))
        snap(app, "onboarding-4")
        later.tap()

        app.openTab(.settings)
        let datesRow = app.buttons["settingsPregnancyDates"]
        XCTAssertTrue(datesRow.waitForExistence(timeout: 5))
        snap(app, "settings")
```
bằng:
```swift
        app.buttons["onboardingAgree"].tap()
        let pregnant = app.buttons["onboardingModePregnant"]
        XCTAssertTrue(pregnant.waitForExistence(timeout: 5))
        snap(app, "onboarding-mode")
        pregnant.tap()
        let later = app.buttons["onboardingSkipDate"]
        XCTAssertTrue(later.waitForExistence(timeout: 5))
        snap(app, "onboarding-4")
        later.tap()

        app.openTab(.settings)
        // The new "Mode" section sits on top; Form only creates rows near the viewport.
        XCTAssertTrue(app.segmentedControls.firstMatch.waitForExistence(timeout: 5))
        let datesRow = app.buttons["settingsPregnancyDates"]
        app.scrollUntilHittable(datesRow)
        XCTAssertTrue(datesRow.waitForExistence(timeout: 5))
        snap(app, "settings")
```

Trong `UITests/PregnancyUITests.swift` (`testClearingPregnancyDatesEmptiesPregnancyAndCounterTabs`), thay:
```swift
        app.openTab(.settings)
        let clearButton = app.buttons["settingsPregnancyClear"]
        XCTAssertTrue(clearButton.waitForExistence(timeout: 10))
```
bằng:
```swift
        app.openTab(.settings)
        XCTAssertTrue(app.segmentedControls.firstMatch.waitForExistence(timeout: 10))
        let clearButton = app.buttons["settingsPregnancyClear"]
        app.scrollUntilHittable(clearButton)
        XCTAssertTrue(clearButton.waitForExistence(timeout: 5))
```

- [ ] **Step 2: Viết UI test mới**

Trong `UITests/CycleUITests.swift`, thay dấu `}` cuối cùng của file bằng:
```swift

    /// Spec §8: onboarding → "Trying to conceive" → last period → the Cycle tab shows the right cycle day.
    @MainActor
    func testOnboardingTryingToConceiveShowsTheCycleDay() {
        let app = XCUIApplication.launchPinned(language: "en", skipOnboarding: false)
        let next = app.buttons["onboardingNext"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        next.tap()
        next.tap()
        app.buttons["onboardingAgree"].tap()
        let tryingToConceive = app.buttons["onboardingModeTTC"]
        XCTAssertTrue(tryingToConceive.waitForExistence(timeout: 5))
        tryingToConceive.tap()

        let wheels = app.pickerWheels
        XCTAssertTrue(wheels.element(boundBy: 2).waitForExistence(timeout: 5))
        wheels.element(boundBy: 0).adjust(toPickerWheelValue: "September") // en_US order: month, day, year
        wheels.element(boundBy: 1).adjust(toPickerWheelValue: "20")
        app.buttons["onboardingSaveCycle"].tap()

        // 2026-09-20 → 2026-10-02 is cycle day 13, on the three trying-to-conceive tabs.
        let status = app.descendants(matching: .any)["cycleStatusCard"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertTrue(status.label.contains("Day 13 of your cycle"), status.label)
        XCTAssertEqual(app.tabBars.buttons.count, 3)
    }

    /// Spec §4.3: switching mode in Settings keeps the pregnancy dates.
    @MainActor
    func testSwitchingModeInSettingsKeepsThePregnancyDates() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        app.openTab(.settings)
        let tryingToConceive = app.segmentedControls.buttons["Trying to conceive"]
        XCTAssertTrue(tryingToConceive.waitForExistence(timeout: 10))
        tryingToConceive.tap()

        // Settings stays open, now with the cycle section and three tabs.
        XCTAssertTrue(app.descendants(matching: .any)["settingsCycleLength"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.tabBars.buttons.count, 3)
        XCTAssertFalse(app.buttons["settingsPregnancyDates"].exists)
        app.openCycleTab(.cycle)
        XCTAssertTrue(app.buttons["cycleAddPeriodButton"].waitForExistence(timeout: 5))

        // Back to pregnant: no period logged, so the sheet starts from the stored due date.
        app.openCycleTab(.settings)
        let pregnant = app.segmentedControls.buttons["Pregnant"]
        XCTAssertTrue(pregnant.waitForExistence(timeout: 5))
        pregnant.tap()
        let save = app.buttons["imPregnantSave"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()

        XCTAssertTrue(app.buttons["settingsPregnancyDates"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.tabBars.buttons.count, 4)
        app.openTab(.pregnancy)
        let progress = app.descendants(matching: .any)["weekProgressCard"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        XCTAssertTrue(progress.label.contains("Week 24 + 3 days"), progress.label)
    }
}
```

Trong `UITests/CycleScreenshotTests.swift`, thay dấu `}` cuối cùng của file bằng:
```swift

    @MainActor
    func testOnboardingModeScreens() {
        for (language, dark) in Self.variants {
            let suffix = "\(language)-\(dark ? "dark" : "light")"
            let app = XCUIApplication.launchPinned(language: language, dark: dark, skipOnboarding: false)
            let next = app.buttons["onboardingNext"]
            XCTAssertTrue(next.waitForExistence(timeout: 10))
            next.tap()
            next.tap()
            app.buttons["onboardingAgree"].tap()
            let tryingToConceive = app.buttons["onboardingModeTTC"]
            XCTAssertTrue(tryingToConceive.waitForExistence(timeout: 5))
            attachScreenshot(app, "onboarding-mode-\(suffix)")
            tryingToConceive.tap()
            XCTAssertTrue(app.buttons["onboardingSaveCycle"].waitForExistence(timeout: 5))
            attachScreenshot(app, "onboarding-cycle-\(suffix)")
            app.terminate()
        }
    }

    @MainActor
    func testSettingsScreens() {
        for (language, dark) in Self.variants {
            let suffix = "\(language)-\(dark ? "dark" : "light")"
            let app = XCUIApplication.launchPinned(language: language, dark: dark, seedCycles: "fertile")
            app.openCycleTab(.settings)
            XCTAssertTrue(app.descendants(matching: .any)["settingsCycleLength"].waitForExistence(timeout: 10))
            attachScreenshot(app, "settings-ttc-\(suffix)")
            if language == "vi", !dark {
                let medical = app.buttons["settingsMedicalInfo"]
                app.scrollUntilHittable(medical)
                medical.tap()
                let ttc = app.descendants(matching: .any)["medicalTTC"]
                XCTAssertTrue(ttc.waitForExistence(timeout: 5))
                app.scrollUntilHittable(ttc)
                attachScreenshot(app, "medical-ttc-vi")
            }
            app.terminate()
        }
    }
}
```

- [ ] **Step 3: Chuỗi và L10n**

```bash
scripts/add-strings.py <<'JSON'
{
  "onboarding.mode.title": ["What would you like to track?", "Bạn muốn theo dõi điều gì?"],
  "onboarding.mode.body": ["You can change this any time in Settings.", "Bạn có thể đổi bất cứ lúc nào trong Cài đặt."],
  "onboarding.mode.ttc.detail": ["Track your periods and your most fertile days", "Theo dõi kỳ kinh và những ngày dễ thụ thai"],
  "onboarding.mode.pregnant.detail": ["Follow your pregnancy week by week and count your baby's kicks", "Theo dõi thai kỳ từng tuần và đếm cử động thai"],
  "onboarding.cycle.title": ["Your cycle", "Chu kỳ của bạn"],
  "onboarding.cycle.body": ["Enter the first day of your last period, or skip this and add it later.", "Nhập ngày đầu tiên của kỳ kinh gần nhất, hoặc bỏ qua để nhập sau."],
  "mode.tryingToConceive": ["Trying to conceive", "Mong con"],
  "mode.pregnant": ["Pregnant", "Đang mang thai"],
  "cycleSettings.cycleLength": ["Cycle length: %d days", "Độ dài chu kỳ: %d ngày"],
  "cycleSettings.periodLength": ["Period length: %d days", "Số ngày hành kinh: %d ngày"],
  "cycleSettings.hint": ["Used for predictions until you have logged a few cycles.", "Dùng để dự đoán cho tới khi bạn đã ghi vài chu kỳ."],
  "settings.mode.section": ["Mode", "Chế độ"],
  "settings.cycle.section": ["Cycle", "Chu kỳ"],
  "settings.cycle.reminders": ["Cycle reminders", "Nhắc chu kỳ"],
  "settings.cycle.remindersHint": ["Reminders come at 9:00: 2 days before your fertile window, the day before your period is due, and once if it is 3 days late.", "Nhắc lúc 9:00: 2 ngày trước cửa sổ thụ thai, 1 ngày trước kỳ kinh dự kiến và một lần khi trễ kinh 3 ngày."],
  "medical.ttc.title": ["Trying to conceive", "Khi đang mong con"],
  "medical.ttc.body": ["Trying-to-conceive mode only helps you track your cycle. It is not a method of contraception and must not be used to avoid pregnancy. Ovulation, the fertile window and the next period are estimates based on what you log.\n\nSee a doctor if:\n• you have been trying for 12 months without getting pregnant (6 months if you are 35 or older);\n• your cycles are shorter than 21 days, longer than 45 days, or very irregular;\n• you have unusual bleeding between periods.", "Chế độ Mong con chỉ giúp bạn theo dõi chu kỳ. Đây không phải là biện pháp tránh thai và không được dùng để tránh thai. Ngày rụng trứng, cửa sổ thụ thai và kỳ kinh tiếp theo chỉ là ước tính dựa trên những gì bạn ghi.\n\nHãy đi khám bác sĩ nếu:\n• đã cố gắng có thai 12 tháng mà chưa có (6 tháng nếu từ 35 tuổi trở lên);\n• chu kỳ ngắn hơn 21 ngày, dài hơn 45 ngày hoặc rất không đều;\n• ra máu bất thường giữa hai kỳ kinh."]
}
JSON
```
Expected: tổng số chuỗi tăng 17 (sau Task 8–11: 248 nếu ban đầu là 142).

Trong `Shared/L10n.swift`, chèn ngay sau dòng `    static var onboardingLater: String { t("onboarding.later") }`:
```swift
    static var onboardingModeTitle: String { t("onboarding.mode.title") }
    static var onboardingModeBody: String { t("onboarding.mode.body") }
    static var onboardingModeTTCDetail: String { t("onboarding.mode.ttc.detail") }
    static var onboardingModePregnantDetail: String { t("onboarding.mode.pregnant.detail") }
    static var onboardingCycleTitle: String { t("onboarding.cycle.title") }
    static var onboardingCycleBody: String { t("onboarding.cycle.body") }
    static var modeTryingToConceive: String { t("mode.tryingToConceive") }
    static var modePregnant: String { t("mode.pregnant") }
    static func cycleSettingsCycleLength(_ days: Int) -> String { String(format: t("cycleSettings.cycleLength"), days) }
    static func cycleSettingsPeriodLength(_ days: Int) -> String { String(format: t("cycleSettings.periodLength"), days) }
    static var cycleSettingsHint: String { t("cycleSettings.hint") }
    static var settingsModeSection: String { t("settings.mode.section") }
    static var settingsCycleSection: String { t("settings.cycle.section") }
    static var settingsCycleReminders: String { t("settings.cycle.reminders") }
    static var settingsCycleRemindersHint: String { t("settings.cycle.remindersHint") }
    static var medicalTTCTitle: String { t("medical.ttc.title") }
    static var medicalTTCBody: String { t("medical.ttc.body") }
```

- [ ] **Step 4: Onboarding**

Thay toàn bộ `App/Onboarding/OnboardingView.swift` bằng:
```swift
import KickCore
import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @Environment(CycleCoordinator.self) private var cycle
    @State private var page = 0
    @State private var step = Step.intro
    @State private var dateSource: PregnancyDateSource
    @State private var date: Date
    @State private var lastPeriod: Date
    @State private var cycleLength = CycleSettings.defaultCycleLength
    @State private var periodLength = CycleSettings.defaultPeriodLength
    @State private var saving = false
    private let now: Date

    /// Intro pages → mode → pregnancy dates or cycle. The mode step comes after
    /// "I understand" so the medical disclaimer can't be swiped past.
    private enum Step {
        case intro
        case mode
        case pregnancy
        case cycle
    }

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        let now = AppClock.now()
        self.now = now
        let selection = PregnancyDateInput.initialSelection(for: PregnancyProfile.load(from: AppGroup.defaults), now: now)
        _dateSource = State(initialValue: selection.source)
        _date = State(initialValue: selection.date)
        _lastPeriod = State(initialValue: now)
    }

    private struct Page {
        let symbol: String
        let title: String
        let body: String
    }

    private var pages: [Page] {
        [
            Page(symbol: "hand.tap.fill", title: L10n.onboarding1Title, body: L10n.onboarding1Body),
            Page(symbol: "moon.stars.fill", title: L10n.onboarding2Title, body: L10n.onboarding2Body),
            Page(symbol: "stethoscope", title: L10n.onboarding3Title, body: L10n.onboarding3Body),
        ]
    }

    var body: some View {
        Group {
            switch step {
            case .intro: introPages
            case .mode: modeStep
            case .pregnancy: pregnancyStep
            case .cycle: cycleStep
            }
        }
        .interactiveDismissDisabled()
    }

    private var introPages: some View {
        VStack {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    VStack(spacing: 24) {
                        Image(systemName: pages[index].symbol)
                            .font(.system(size: 72))
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)
                        Text(pages[index].title)
                            .font(.title.bold())
                            .multilineTextAlignment(.center)
                        Text(pages[index].body)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .padding(32)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            if page < pages.count - 1 {
                Button {
                    withAnimation { page += 1 }
                } label: {
                    Text(L10n.onboardingNext).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityIdentifier("onboardingNext")
                .padding(24)
            } else {
                Button {
                    withAnimation { step = .mode }
                } label: {
                    Text(L10n.onboardingAgree).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("onboardingAgree")
                .padding(24)
            }
        }
    }

    private var modeStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                header(symbol: "heart.circle.fill", title: L10n.onboardingModeTitle, body: L10n.onboardingModeBody)
                VStack(spacing: 12) {
                    modeButton(
                        title: L10n.modeTryingToConceive,
                        detail: L10n.onboardingModeTTCDetail,
                        symbol: "drop.circle.fill",
                        identifier: "onboardingModeTTC"
                    ) {
                        withAnimation { step = .cycle }
                    }
                    modeButton(
                        title: L10n.modePregnant,
                        detail: L10n.onboardingModePregnantDetail,
                        symbol: "heart.text.square.fill",
                        identifier: "onboardingModePregnant"
                    ) {
                        AppMode.save(.pregnant, to: AppGroup.defaults)
                        withAnimation { step = .pregnancy }
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 24)
        }
    }

    private func modeButton(
        title: String,
        detail: String,
        symbol: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.title)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 44)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    Text(detail).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private func header(symbol: String, title: String, body: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text(title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text(body)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 32)
        .padding(.top, 32)
    }

    private var pregnancyStep: some View {
        VStack(spacing: 0) {
            header(symbol: "calendar.badge.clock", title: L10n.onboarding4Title, body: L10n.onboarding4Body)

            Form {
                PregnancyDateForm(source: $dateSource, date: $date, now: now)
            }
            .scrollContentBackground(.hidden)

            VStack(spacing: 12) {
                Button {
                    PregnancyProfile.save(source: dateSource, date: date, to: AppGroup.defaults)
                    onFinish()
                } label: {
                    Text(L10n.commonSave).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("onboardingSaveDate")

                Button(action: onFinish) {
                    Text(L10n.onboardingLater).frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .accessibilityIdentifier("onboardingSkipDate")
            }
            .padding(24)
        }
    }

    private var cycleStep: some View {
        VStack(spacing: 0) {
            header(symbol: "drop.circle.fill", title: L10n.onboardingCycleTitle, body: L10n.onboardingCycleBody)

            Form {
                LastPeriodPicker(date: $lastPeriod, now: now)
                Section {
                    Stepper(L10n.cycleSettingsCycleLength(cycleLength), value: $cycleLength, in: CycleSettings.cycleLengthRange)
                        .accessibilityIdentifier("onboardingCycleLength")
                    Stepper(L10n.cycleSettingsPeriodLength(periodLength), value: $periodLength, in: CycleSettings.periodLengthRange)
                        .accessibilityIdentifier("onboardingPeriodLength")
                } footer: {
                    Text(L10n.cycleSettingsHint)
                }
            }
            .scrollContentBackground(.hidden)

            VStack(spacing: 12) {
                Button {
                    Task { await finishCycleStep(savingLastPeriod: true) }
                } label: {
                    Text(L10n.commonSave).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(saving)
                .accessibilityIdentifier("onboardingSaveCycle")

                Button {
                    Task { await finishCycleStep(savingLastPeriod: false) }
                } label: {
                    Text(L10n.onboardingLater).frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .disabled(saving)
                .accessibilityIdentifier("onboardingSkipCycle")
            }
            .padding(24)
        }
    }

    /// Saves the cycle numbers, switches to trying-to-conceive mode and — unless
    /// skipped — the last period. A failed save shows on the Cycle tab.
    private func finishCycleStep(savingLastPeriod: Bool) async {
        saving = true
        defer { saving = false }
        var settings = cycle.settings
        settings.typicalCycleLength = cycleLength
        settings.typicalPeriodLength = periodLength
        await cycle.updateSettings(settings)
        await cycle.activateTryingToConceive()
        if savingLastPeriod {
            await cycle.logLastPeriod(startingOn: lastPeriod)
        }
        onFinish()
    }
}
```

- [ ] **Step 5: Cài đặt**

Thay toàn bộ `App/Settings/SettingsView.swift` bằng:
```swift
import KickCore
import SwiftUI

struct SettingsView: View {
    @Environment(KickCoordinator.self) private var coordinator
    @Environment(CycleCoordinator.self) private var cycle
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(SettingsKey.appMode, store: AppGroup.defaults) private var appMode = AppMode.pregnant.rawValue
    @AppStorage(SettingsKey.reminderEnabled, store: AppGroup.defaults) private var reminderEnabled = false
    @AppStorage(SettingsKey.reminderHour, store: AppGroup.defaults) private var reminderHour = SettingsDefault.reminderHour
    @AppStorage(SettingsKey.reminderMinute, store: AppGroup.defaults) private var reminderMinute = SettingsDefault.reminderMinute
    @AppStorage(SettingsKey.dueDate, store: AppGroup.defaults) private var dueDate: Double = 0
    @AppStorage(SettingsKey.lmpDate, store: AppGroup.defaults) private var lmpDate: Double = 0
    @AppStorage(SettingsKey.pregnancyDateSource, store: AppGroup.defaults)
    private var pregnancyDateSource = PregnancyDateSource.dueDate.rawValue

    @State private var notificationsAuthorized = true
    @State private var showingPregnancyDates = false
    @State private var confirmingClearPregnancy = false
    @State private var showingImPregnant = false

    private var mode: AppMode { AppMode(rawValue: appMode) ?? .pregnant }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.settingsModeSection) {
                    Picker(L10n.settingsModeSection, selection: modeBinding) {
                        Text(L10n.modeTryingToConceive).tag(AppMode.tryingToConceive)
                        Text(L10n.modePregnant).tag(AppMode.pregnant)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("settingsModePicker")
                }

                if mode == .tryingToConceive {
                    Section {
                        Stepper(
                            L10n.cycleSettingsCycleLength(cycle.settings.typicalCycleLength),
                            value: cycleSetting(\.typicalCycleLength),
                            in: CycleSettings.cycleLengthRange
                        )
                        .accessibilityIdentifier("settingsCycleLength")
                        Stepper(
                            L10n.cycleSettingsPeriodLength(cycle.settings.typicalPeriodLength),
                            value: cycleSetting(\.typicalPeriodLength),
                            in: CycleSettings.periodLengthRange
                        )
                        .accessibilityIdentifier("settingsPeriodLength")
                        Toggle(L10n.settingsCycleReminders, isOn: cycleSetting(\.remindersEnabled))
                            .accessibilityIdentifier("settingsCycleReminders")
                    } header: {
                        Text(L10n.settingsCycleSection)
                    } footer: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.cycleSettingsHint)
                            Text(L10n.settingsCycleRemindersHint)
                        }
                    }
                }

                // The kick-count reminder belongs to pregnancy mode, but stays
                // visible while it is on so it can always be turned off.
                if mode == .pregnant || reminderEnabled {
                    Section(L10n.settingsReminderSection) {
                        Toggle(L10n.settingsReminderToggle, isOn: $reminderEnabled)
                            .accessibilityIdentifier("settingsReminderToggle")
                        if reminderEnabled {
                            DatePicker(L10n.settingsReminderTime, selection: reminderTime, displayedComponents: .hourAndMinute)
                        }
                    }
                }

                if mode == .pregnant {
                    Section(L10n.settingsPregnancySection) {
                        Button {
                            showingPregnancyDates = true
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                LabeledContent(dueDate > 0 ? L10n.settingsDueDate : L10n.settingsPregnancySet, value: dueDateText)
                                if let lmpText {
                                    Text(L10n.settingsPregnancyFromLMP(lmpText))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .tint(.primary)
                        .accessibilityIdentifier("settingsPregnancyDates")

                        if dueDate > 0 {
                            Button(L10n.settingsPregnancyClear, role: .destructive) {
                                confirmingClearPregnancy = true
                            }
                            .accessibilityIdentifier("settingsPregnancyClear")
                        }
                    }
                }

                let showsLiveActivityHint = mode == .pregnant && !coordinator.liveActivitiesAvailable
                if !notificationsAuthorized || showsLiveActivityHint {
                    Section(L10n.settingsPermissionsSection) {
                        if !notificationsAuthorized {
                            Text(L10n.settingsNotificationsDenied).font(.footnote)
                        }
                        if showsLiveActivityHint {
                            Text(L10n.settingsLiveActivitiesOff).font(.footnote)
                        }
                        Button(L10n.settingsOpenSettings) {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                    }
                }

                Section(L10n.settingsAboutSection) {
                    NavigationLink(L10n.settingsMedicalInfo) { MedicalInfoView() }
                        .accessibilityIdentifier("settingsMedicalInfo")
                    LabeledContent(L10n.settingsVersion, value: appVersion)
                }
            }
            .navigationTitle(L10n.settingsTitle)
            .sheet(isPresented: $showingPregnancyDates) { PregnancyDateSheet() }
            .sheet(isPresented: $showingImPregnant) {
                ImPregnantSheet(lastPeriodStart: cycle.forecast?.currentPeriodStart)
            }
            .confirmationDialog(
                L10n.settingsPregnancyClearConfirm,
                isPresented: $confirmingClearPregnancy,
                titleVisibility: .visible
            ) {
                Button(L10n.settingsPregnancyClear, role: .destructive) { PregnancyProfile.clear(AppGroup.defaults) }
                Button(L10n.commonCancel, role: .cancel) {}
            }
            .task { await refreshPermissions() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refreshPermissions() } }
            }
            .onChange(of: reminderEnabled) { Task { await applyReminder() } }
            .onChange(of: reminderHour) { Task { await applyReminder() } }
            .onChange(of: reminderMinute) { Task { await applyReminder() } }
        }
    }

    /// Switching to "Trying to conceive" is immediate; switching to "Pregnant"
    /// goes through the "I'm pregnant" sheet so the due date is set.
    private var modeBinding: Binding<AppMode> {
        Binding(
            get: { mode },
            set: { newMode in
                guard newMode != mode else { return }
                switch newMode {
                case .tryingToConceive:
                    Task {
                        await cycle.activateTryingToConceive()
                        await refreshPermissions()
                    }
                case .pregnant:
                    showingImPregnant = true
                }
            }
        )
    }

    /// A binding to one cycle setting, saved through the coordinator (which reschedules reminders).
    private func cycleSetting<Value>(_ keyPath: WritableKeyPath<CycleSettings, Value>) -> Binding<Value> {
        Binding(
            get: { cycle.settings[keyPath: keyPath] },
            set: { value in
                var settings = cycle.settings
                settings[keyPath: keyPath] = value
                Task {
                    await cycle.updateSettings(settings)
                    await refreshPermissions()
                }
            }
        )
    }

    private var dueDateText: String {
        guard dueDate > 0 else { return L10n.settingsPregnancyNotSet }
        return Date(timeIntervalSince1970: dueDate).formatted(date: .long, time: .omitted)
    }

    private var lmpText: String? {
        guard pregnancyDateSource == PregnancyDateSource.lmp.rawValue, lmpDate > 0 else { return nil }
        return Date(timeIntervalSince1970: lmpDate).formatted(date: .long, time: .omitted)
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: reminderHour, minute: reminderMinute)) ?? .now
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                reminderHour = components.hour ?? SettingsDefault.reminderHour
                reminderMinute = components.minute ?? SettingsDefault.reminderMinute
            }
        )
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private func applyReminder() async {
        let scheduled = await coordinator.setDailyReminder(
            enabled: reminderEnabled,
            hour: reminderHour,
            minute: reminderMinute,
            text: NotificationText(title: L10n.reminderTitle, body: L10n.reminderBody)
        )
        if !scheduled {
            reminderEnabled = false
        }
        await refreshPermissions()
    }

    private func refreshPermissions() async {
        notificationsAuthorized = await coordinator.notificationsAuthorized()
    }
}
```

- [ ] **Step 6: Thông tin y tế**

Thay toàn bộ `App/Settings/MedicalInfoView.swift` bằng:
```swift
import SwiftUI

struct MedicalInfoView: View {
    @Environment(\.contentLibrary) private var library

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(L10n.medicalBody)
                    .font(.body)

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.medicalTTCTitle)
                        .font(.headline)
                    Text(L10n.medicalTTCBody)
                        .font(.body)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("medicalTTC")

                if let sources = library?.sources, !sources.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.medicalSourcesTitle)
                            .font(.headline)
                        Text(L10n.medicalSourcesNote)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        ForEach(sources, id: \.self) { source in
                            Label {
                                Text(verbatim: source)
                            } icon: {
                                Image(systemName: "book.closed")
                                    .foregroundStyle(Color.accentColor)
                            }
                            .font(.subheadline)
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("medicalSources")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(L10n.medicalTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

- [ ] **Step 7: Commit, push, xác minh CI**

```bash
scripts/test-core.sh
git add App Shared UITests
git commit -F - <<'MSG'
feat(app): choose the mode in onboarding and Settings, add cycle settings

Onboarding asks for the mode after the disclaimer; Settings switches mode
(to pregnant through "I'm pregnant") and shows cycle length, period length
and cycle reminders in trying-to-conceive mode. Medical info gains the
trying-to-conceive notes.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`, gồm `CycleUITests.testOnboardingTryingToConceiveShowsTheCycleDay`, `CycleUITests.testSwitchingModeInSettingsKeepsThePregnancyDates`, `CycleScreenshotTests.testOnboardingModeScreens`, `CycleScreenshotTests.testSettingsScreens`, và mọi test cũ (`KickCounterUITests`, `ScreenshotTests`, `PregnancyUITests` đi qua bước chọn chế độ).

- [ ] **Step 8: Kiểm tra trực quan (Read tool)**

- `onboarding-mode-vi-light` và `onboarding-mode` (ScreenshotTests): biểu tượng tim, "Bạn muốn theo dõi điều gì?", "Bạn có thể đổi bất cứ lúc nào trong Cài đặt."; hai thẻ bo góc có chevron: "Mong con" / "Theo dõi kỳ kinh và những ngày dễ thụ thai" (giọt nước) và "Đang mang thai" / "Theo dõi thai kỳ từng tuần và đếm cử động thai". `onboarding-mode-en-light`: "What would you like to track?", "Trying to conceive", "Pregnant". `onboarding-mode-vi-dark`: thẻ nền xám tối, chữ đọc rõ.
- `onboarding-cycle-vi-light`: "Chu kỳ của bạn" + mô tả; bánh xe ngày (hôm nay 2/10/2026); "Độ dài chu kỳ: 28 ngày", "Số ngày hành kinh: 5 ngày" có nút −/+; footer "Dùng để dự đoán cho tới khi bạn đã ghi vài chu kỳ."; nút "Lưu" (nổi bật) và "Để sau".
- `onboarding-4` (ScreenshotTests): như giai đoạn 2 (bước ngày thai kỳ), sau bước chọn chế độ.
- `settings-ttc-vi-light`: mục "Chế độ" segmented "Mong con | Đang mang thai" với "Mong con" được chọn; mục "Chu kỳ": "Độ dài chu kỳ: 28 ngày", "Số ngày hành kinh: 5 ngày", công tắc "Nhắc chu kỳ" bật; footer hai dòng (ý nghĩa độ dài + "Nhắc lúc 9:00: …"); **không** có mục "Thai kỳ" và "Nhắc nhở" đếm cử động; mục "Quyền" chỉ có dòng thông báo tắt (không có dòng Live Activities); mục "Giới thiệu"; thanh tab 3 mục với "Cài đặt" được chọn. `settings-ttc-en-light`: "Mode", "Trying to conceive", "Cycle length: 28 days", "Cycle reminders". `settings-ttc-vi-dark`: đọc rõ.
- `settings` (ScreenshotTests, chế độ mang thai): mục "Chế độ" ở đầu với "Đang mang thai" được chọn; các mục giai đoạn 2 còn nguyên bên dưới.
- `medical-ttc-vi`: tiêu đề "Khi đang mong con"; đoạn "không phải là biện pháp tránh thai", "chỉ là ước tính"; danh sách 3 gạch đầu dòng (12 tháng / 6 tháng nếu ≥ 35 tuổi; chu kỳ < 21 hoặc > 45 ngày hoặc rất không đều; ra máu bất thường giữa hai kỳ kinh).

---
### Task 12: Tài liệu phát hành — checklist giai đoạn 3, CloudKit, nội dung cho bác sĩ

Không chạy TestFlight trong task này (người dùng tự kích hoạt `testflight.yml`).

**Files:**
- Modify: `docs/release-checklist.md` (thêm mục cuối), `docs/content-review-for-doctor.md` (thêm mục 6 ở cuối file, sau mục 5)

**Interfaces:**
- Consumes: khóa chuỗi y tế mới (Task 8–11), hằng số dự đoán (Task 3), id nhắc (Task 4), record type `CD_PeriodEntry`/`CD_CycleLog` (Task 7), ảnh chụp (Task 8–11).
- Produces: checklist phát hành giai đoạn 3; danh sách duyệt y khoa cho chế độ Mong con.

- [ ] **Step 1: Bổ sung checklist phát hành**

Thêm vào cuối `docs/release-checklist.md`:
```markdown

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
```

- [ ] **Step 2: Bổ sung nội dung cho bác sĩ**

Thêm vào cuối `docs/content-review-for-doctor.md`:
```markdown

## 6. Chế độ "Mong con" (giai đoạn 3) — chuỗi y tế và quy tắc dự đoán

Các chuỗi dưới đây nằm trong `Shared/Localizable.xcstrings` (không có cờ `reviewed` như nội dung
thai kỳ, nên **phải được duyệt trước khi gửi App Store**). Xem câu chữ thật trên ảnh chụp
`medical-ttc-vi`, `cycle-home-*`, `day-log-*` trong `ci-artifacts/screenshots/` của lần CI gần nhất.

| Khóa | Nội dung (vi) cần duyệt |
|---|---|
| `medical.ttc.body` | Không dùng để tránh thai; dự đoán chỉ là ước tính; khi nào nên gặp bác sĩ (12 tháng, 6 tháng nếu ≥ 35 tuổi; chu kỳ < 21 hoặc > 45 ngày hay rất không đều; ra máu bất thường giữa kỳ) |
| `cycle.irregular.title`, `cycle.irregular.body` | Cảnh báo chu kỳ bất thường → gợi ý gặp bác sĩ |
| `cycle.late.title`, `cycle.late.body`, `cycle.reminder.late.*` | Gợi ý thử thai khi trễ kinh từ ngày thứ 3 |
| `cycle.longPeriod.title`, `cycle.longPeriod.body` | Kỳ kinh chưa kết thúc > 10 ngày → ghi ngày kết thúc / đi khám nếu ra máu kéo dài |
| `cycle.disclaimer`, `cycle.lowConfidence.*` | Dự đoán chỉ là ước tính; độ tin cậy thấp khi chu kỳ chưa đều hoặc chưa đủ dữ liệu |
| `cycle.status.*`, `cycle.reminder.fertile.*`, `cycle.reminder.period.*` | Cách gọi "khả năng thụ thai cao/cao nhất/thấp", nhắc trước cửa sổ thụ thai và kỳ kinh |
| `lastPeriod.hint`, `dayLog.bbt.hint`, `dayLog.lh.*`, `dayLog.mucus.*` | Hướng dẫn: ngày đầu ra máu (không tính lấm tấm); đo BBT ngay khi thức dậy; tên các loại dịch nhầy (khô, dính, như kem, như lòng trắng trứng) |

22. [ ] Bác sĩ đã duyệt (hoặc sửa) toàn bộ các khóa trong bảng trên, cả bản vi lẫn en.
23. [ ] **Quy tắc dự đoán** (theo spec §4.1, `Packages/KickCore/Sources/KickCore/CyclePredictor.swift`):
        pha hoàng thể cố định 14 ngày (rụng trứng = kỳ kinh dự kiến − 14); cửa sổ thụ thai = 5 ngày trước
        đến 1 ngày sau rụng trứng; LH dương tính → rụng trứng ngày hôm sau; BBT: 3 ngày liền cao hơn mức
        cao nhất của 6 lần đo trước ≥ 0,2 °C; chỉ tính chu kỳ 21–45 ngày, trung bình 6 chu kỳ gần nhất;
        độ tin cậy thấp khi độ lệch chuẩn > 4 ngày hoặc chênh > 7 ngày (nới cửa sổ tối đa 3 ngày mỗi bên).
        Xác nhận các ngưỡng này phù hợp để hiển thị cho người dùng (không dùng cho tránh thai).
24. [ ] **Khoảng nhiệt độ BBT hợp lệ 35,0–38,5 °C** và ngưỡng "kỳ kinh kéo dài" 10 ngày: xác nhận.
25. [ ] **Thời điểm gợi ý thử thai**: từ ngày trễ thứ 3 (thẻ + một thông báo). Xác nhận hay đổi.
```

- [ ] **Step 3: Commit, push, CI**

```bash
git add docs/release-checklist.md docs/content-review-for-doctor.md
git commit -F - <<'MSG'
docs: add phase 3 release checklist and doctor review items

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push
scripts/ci-wait.sh
```
Expected: `CI PASSED`.

- [ ] **Step 4: Bàn giao**

Không tự chạy TestFlight: báo người dùng rằng bản thử có thể chạy bằng `gh workflow run testflight.yml --ref feat/phase3-trying-to-conceive` khi họ muốn, rồi kiểm theo mục "Kiểm thử thủ công" ở trên. Sau đó dùng `superpowers:finishing-a-development-branch` để mở PR `feat/phase3-trying-to-conceive` → `main` (chạy `scripts/test-core.sh` trước khi push, như pre-push hook).

---
## Quyết định làm rõ spec

| Điểm chưa rõ trong spec | Quyết định |
|---|---|
| §4.1 "trung bình tối đa 6 chu kỳ gần nhất có độ dài 21–45" | Lọc 21–45 **trước**, rồi lấy 6 chu kỳ hợp lệ gần nhất; trung bình làm tròn tới ngày gần nhất. Chu kỳ = khoảng cách giữa hai ngày bắt đầu kỳ kinh liên tiếp. |
| §4.1 "chưa đủ 2 chu kỳ đã ghi" | Hiểu là < 2 chu kỳ **hoàn chỉnh hợp lệ** (tức < 3 kỳ kinh hợp lệ) → `.low`; khớp §6 "chỉ 1 kỳ kinh → `.low`". |
| §4.1 nới cửa sổ `min(3, (max−min)/2)` | Chia nguyên; bằng 0 khi < 2 chu kỳ hợp lệ (không có chênh lệch); chỉ áp khi rụng trứng theo lịch (không nới khi có LH/BBT). Với ngưỡng của spec, thực tế độ nới là 0 hoặc 3. |
| §4.1 "LH dương tính trong chu kỳ hiện tại" | Que dương tính **đầu tiên** từ ngày đầu kỳ kinh hiện tại đến hôm nay. |
| §4.1 BBT "6 ngày trước đó" | 6 **lần đo** gần nhất trước lần tăng (trong chu kỳ hiện tại, ngày có thể cách quãng); 3 lần cao phải ở 3 ngày **liên tiếp**; "≥ 0,2 °C" có sai số 0,0001 cho số thực. Rụng trứng xác nhận = ngày trước lần cao đầu tiên. |
| §4.1 BBT "ghi ngày rụng trứng xác nhận" | Ưu tiên BBT > LH > lịch cho `ovulationDate` và cửa sổ tính lại quanh ngày đó; `nextPeriodStart` vẫn theo trung bình. Thẻ hiện nhãn "Đã xác nhận rụng trứng qua nhiệt độ". |
| §4.1 `dayStatus` | Ưu tiên: kỳ kinh đã ghi → kỳ kinh dự đoán → `peak` → `fertile` → `low`. Chu kỳ tương lai lặp dự đoán theo lịch (cho tab Lịch); trước kỳ kinh hiện tại chỉ tô kỳ kinh đã ghi; ngày đã qua của kỳ kinh bị lỡ **không** tô "dự đoán". Kỳ kinh đang mở: tô đã ghi tới hôm nay (tối đa 10 ngày), phần còn lại tới `typicalPeriodLength` là dự đoán. |
| §4.1 `irregularWarning` | Dùng độ dài thô của chu kỳ hoàn chỉnh gần nhất (kể cả ngoài 21–45) và độ chênh của các chu kỳ hợp lệ dùng cho trung bình. |
| §3.2/§6 "không chồng nhau" với kỳ kinh chưa kết thúc | Khi kiểm tra ghi mới: kỳ đang mở chiếm từ ngày đầu tới hôm nay (tối đa 10 ngày, `CycleRules.longPeriodDays`). Khi gộp bản trùng iCloud: kỳ đang mở chỉ tính ngày đầu (không phụ thuộc hôm nay); bản gộp giữ ngày đầu sớm nhất, ngày kết thúc muộn nhất (mở chỉ khi mọi bản đều mở) và id của bản sớm nhất. |
| §3.2 "một log mỗi ngày" khi gộp | Giữ id sắp xếp trước; LH dương thắng âm; BBT/dịch nhầy lấy giá trị đầu tiên có; ghi chú khác nhau nối bằng xuống dòng. Lưu log rỗng = xóa log ngày đó. |
| §3.1 `appMode` mặc định | Thiếu khóa → `pregnant` (người dùng cũ). Người dùng mới luôn chọn ở onboarding trước khi thấy tab (bước chọn chế độ lưu khóa). |
| §3.1 `cycleRemindersEnabled` "mặc định bật sau khi được cấp quyền" | Thiếu khóa → bật; nhắc chỉ được đặt khi đã có quyền. Quyền chỉ được hỏi khi người dùng ghi dữ liệu / đổi cài đặt / bật chế độ **và** đã có dự báo; `load()` không bao giờ hỏi. |
| §2 nhắc "trễ kinh 3 ngày" | Một thông báo 9:00 ngày `nextPeriodStart + 3`; thẻ trễ kinh hiện khi `daysLate ≥ 3` (`CyclePredictor.lateNoticeDays`). Nhắc cửa sổ thụ thai tính từ ngày đầu cửa sổ **sau** khi đã điều chỉnh (nới/LH/BBT). |
| §4.3 đổi sang "Đang mang thai" từ Cài đặt | Đi qua cùng sheet "Tôi đã có thai" (cần ngày dự sinh); có kỳ kinh → điền sẵn LMP, không có → lấy hồ sơ thai kỳ đã lưu. Sang "Mong con" đổi ngay. Sau khi đổi chế độ ở Cài đặt, vẫn ở tab Cài đặt; đổi ở nơi khác → mở tab chính của chế độ mới. |
| §5 Cài đặt chế độ Mong con | Ẩn mục nhắc đếm cử động (của chế độ mang thai) trừ khi nhắc đó đang bật (để luôn tắt được); dòng Live Activities chỉ ở chế độ mang thai. |
| §5 Onboarding Mong con chỉ hỏi ngày đầu kỳ kinh | Lưu kỳ kinh giả định dài `typicalPeriodLength` ngày nếu đã qua (`CycleRules.assumedPeriod`), ngược lại để mở — tránh cảnh báo "kéo dài > 10 ngày" sai. Cùng cách cho màn mời nhập kỳ kinh. |
| §6 thông báo lỗi | Lỗi kiểm tra (`futureDate`, `endBeforeStart`, `overlapsExistingPeriod`, `invalidTemperature`) trả về cho sheet/nút gọi và hiện alert ở đó; `failure` toàn cục chỉ cho lỗi lưu/đọc. UI còn chặn trước: bộ chọn ngày không cho ngày tương lai, ô lịch tương lai bị vô hiệu. |
| §6 BBT nhập liệu | Nhận "36.5" và "36,5", làm tròn 0,01 °C (`TemperatureEntry`); ngoài 35,0–38,5 → báo ngay dưới ô, không lưu. |
| §5 "dd/MM" | `Formatting.cycleDate` = ngày + tháng hai chữ số theo thứ tự của locale (vi "04/10", en "10/04"); VoiceOver đọc tên tháng. |
| §5 "Độ tin cậy thấp — chu kỳ chưa đều" | Dùng nguyên văn khi chu kỳ dao động; khi độ tin cậy thấp vì chưa đủ dữ liệu, dùng "Độ tin cậy thấp — cần ghi thêm vài kỳ kinh". |
| §5 vòng chu kỳ | Dài `max(averageCycleLength, cycleDay)` đoạn; trang trí (ẩn với VoiceOver), thẻ nói lại bằng chữ. |
| §5 lịch "vuốt đổi tháng" | Cử chỉ vuốt ngang + hai nút mũi tên (cho VoiceOver/Switch Control). |
| §8 `-seedCycles` | Giá trị là tên kịch bản `CycleSeedScenario` (`empty`, `period`, `fertile`, `late`, `irregular`), tương đối với `-fixedNow`; tự bật chế độ Mong con. |
| §4.2 "re-check sau mỗi await" | Một bộ đếm thế hệ chung cho cả 3 nhắc; nếu có thay đổi trong lúc chờ quyền thì sau khi được cấp quyền đồng bộ lại theo trạng thái mới (không bỏ qua như `AppointmentCoordinator`), để thay đổi giữa chừng vẫn có nhắc. |

## Spec coverage (self-review)

| Spec | Task |
|---|---|
| §1 Ghi bắt đầu/kết thúc kỳ kinh; dự đoán kỳ sau, rụng trứng, cửa sổ thụ thai | 2, 3, 5, 8 (nút nhanh, sheet ghi ngày), 9 |
| §1 LH và BBT điều chỉnh/xác nhận | 3 (test LH, 3-trên-6), 8 (UI test LH), 9 (UI test lịch) |
| §1 Lịch tháng tô màu; nhắc trước cửa sổ, trước kỳ kinh, khi trễ | 4, 5, 6 (`CycleCalendarGrid`), 9 |
| §1 "Tôi đã có thai" → mang thai với ngày dự sinh từ kỳ kinh cuối | 5 (`switchToPregnant`), 10 (UI test tuần 4 + 4 ngày) |
| §1 Ngoài phạm vi | Không task nào thêm HealthKit, chia sẻ, ghi quan hệ, vitamin, biểu đồ BBT, máy học, tránh thai |
| §2 Lưu SwiftData + iCloud | 7, 12 (CloudKit schema) |
| §2 `AppMode`, onboarding hỏi, nút "Tôi đã có thai", đổi trong Cài đặt | 1, 10, 11 |
| §2 Tab Mong con Chu kỳ · Lịch · Cài đặt; tab Mang thai giữ nguyên | 8, 9 (UI test đếm tab ở 10, 11) |
| §2 Nhắc 9:00 (2 ngày trước cửa sổ, 1 ngày trước kỳ kinh, trễ 3 ngày) | 4, 5 |
| §3.1 `appMode`, `typicalCycleLength` 21–45/28, `typicalPeriodLength` 2–10/5, `cycleRemindersEnabled` | 1, 11 (Cài đặt, onboarding) |
| §3.2 `PeriodEntry`, `CycleLog` CloudKit-compatible, trong schema; không trùng ngày/không chồng nhau, gộp khi đồng bộ | 2 (`CycleRules`), 7 |
| §4.1 `CyclePredictor` đủ mọi đầu ra (`cycleDay`, `currentPeriodStart`, `averageCycleLength`, `nextPeriodStart`, `ovulationDate`, `fertileWindow`, `confidence` + nới, `ovulationConfirmed`, `dayStatus`, `daysLate`, `irregularWarning`) | 3 |
| §4.2 `CycleCoordinator` (`@MainActor @Observable`), `CycleRepository` trong KickCore, `CycleStore` trong KickData, đặt lại 3 nhắc sau mỗi thay đổi, hủy khi tắt/đổi chế độ, `load()` không xin quyền, re-check sau await | 2, 5, 7 |
| §4.3 "Tôi đã có thai": sheet, `PregnancyDateForm` LMP, `saveLMP`, `appMode = pregnant`, hủy nhắc, giữ dữ liệu | 5, 10 |
| §4.3 Đổi sang Mong con: giữ thai kỳ, lịch hẹn, nhắc lịch hẹn; bật lại nhắc chu kỳ | 5 (`activateTryingToConceive` test), 11 (UI test) |
| §5 Tab Chu kỳ (vòng, trạng thái, kỳ kinh tiếp theo, cửa sổ + rụng trứng + "đã xác nhận", độ tin cậy thấp, nút nhanh, thẻ trễ kinh + "Tôi đã có thai", cảnh báo bất thường) | 8, 10 |
| §5 Tab Lịch (vuốt đổi tháng, màu đã ghi/dự đoán/cửa sổ/rụng trứng, chấm log, chạm ngày → sheet, chú thích) | 9 |
| §5 Onboarding bước chọn chế độ + nhập Mong con ("Để sau") | 11 |
| §5 Cài đặt: "Chế độ", "Chu kỳ" chỉ ở Mong con, "Thai kỳ" chỉ ở mang thai | 11 |
| §5 Thông tin y tế: đoạn Mong con | 11, 12 (bác sĩ duyệt) |
| §5 Màu hồng/xanh lá/tím, tương phản sáng/tối, ký hiệu + VoiceOver | 8 (`CyclePalette`), 9 (ô lịch, chú thích, nhãn), ảnh dark ở 8–11 |
| §6 Chưa có kỳ kinh → màn mời nhập | 3 (`nil`), 8 |
| §6 Chỉ 1 kỳ kinh → `typicalCycleLength`, `.low` | 3, 5 |
| §6 Kỳ kinh chưa kết thúc > 10 ngày → gợi ý | 3 (`isLongOpenPeriod`), 8 (thẻ) |
| §6 Tương lai / chồng nhau → UI chặn, store kiểm tra | 2, 5, 7, 8 (bộ chọn ngày), 9 (ô tương lai vô hiệu) |
| §6 BBT ngoài 35,0–38,5 → không lưu, báo nhập lại | 2 (`TemperatureEntry`), 5, 7, 8 (UI test) |
| §6 Trễ kinh: thẻ từ ngày 3, nhắc một lần | 3, 4, 8 |
| §6 Từ chối quyền → vẫn hoạt động, dòng nhắc trong Cài đặt | 5 (test), 8 (dòng trên tab Chu kỳ), 11 (mục Quyền) |
| §6 Đồng bộ tạo trùng → store gộp | 2, 7 |
| §7 L10n en + vi; lịch theo locale (thứ đầu tuần); Dynamic Type; VoiceOver từng ô; chế độ tối | 6 (`weekdaySymbols`), 8–11 (`add-strings.py`), 9 (nhãn VoiceOver, UI test), ảnh dark |
| §8 Unit KickCore: đều 28, ngắn 24, dài 35, không đều, lọc 21–45, LH, BBT đúng/sai, trễ kinh, không dữ liệu, ranh giới tháng và DST; coordinator (nhắc đặt/hủy, chuyển chế độ, re-entrancy, lỗi lưu) | 3, 4, 5 |
| §8 KickData CI: CRUD, chặn chồng nhau, gộp trùng, rollback | 7 |
| §8 UI test: onboarding Mong con → ngày chu kỳ; LH dương → rụng trứng đổi; "Tôi đã có thai" → đúng tuần | 11, 8, 10 |
| §8 Ảnh: tab Chu kỳ (kinh, cửa sổ, trễ, độ tin cậy thấp), Lịch, sheet ghi ngày, onboarding chọn chế độ, Cài đặt — sáng/tối, vi/en, `-fixedNow`, `-seedCycles` (chỉ `-uiTesting`, `#if DEBUG`) | 6, 8, 9, 10, 11 |
| §9 Tài liệu bác sĩ, CloudKit `CD_PeriodEntry`/`CD_CycleLog` (build ký development), ghi chú phát hành + ảnh App Store | 12 |
