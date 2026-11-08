import Foundation

/// Launch arguments that make UI tests and screenshots deterministic. They only
/// take effect together with `-uiTesting`:
/// - `-fixedNow <ISO8601>` pins the app's clock for the pregnancy and appointment screens.
/// - `-seedDueDate <ISO8601>` stores that due date at launch.
/// - `-seedCycles <scenario>` switches to trying-to-conceive mode and stores
///   that `CycleSeedScenario`'s periods and logs, relative to the pinned clock.
/// - `-seedOverdueSession` starts a kick session 2 h 5 min ago (real clock) with 4 movements.
/// - `-seedSessions` stores `SessionSeed`'s four weeks of kick sessions.
/// - `-seedWeights` stores `WeightSeed`'s pre-pregnancy weight, height and weights.
/// - `-uiTestingSharing <state>` shares through `FakePartnerSharing` in that mother state.
/// - `-uiTestingPartner <state>` starts in partner mode with `FakePartnerSharing` in that partner state.
/// - `-seedCycleGoal <goal>` stores that `CycleGoal` (`tracking`, `conceiving`).
/// - `-seedContraception <method>` stores that `Contraception` (e.g. `pill`, `condom`).
/// - `-uiTestingPartnerUI` keeps the partner UI (share card, partner mode) reachable while
///   `AppFeatures.cloudSync` is off, so the partner tests keep their coverage (phase 12).
/// - `-seedAppMode <mode>` stores that `AppMode` (e.g. `partner`) without any fake sharing.
/// - `-uiTestingRestoreFile <path>` opens the restore sheet for that backup file at launch,
///   as opening a `.lunamom` file does (phase 15). A relative path is in the app's tmp folder.
/// - `-seedPill <type>:<offsetDays>` (e.g. `21+7:11`) turns the pill reminder on at 21:00
///   with a pack of that type that started `offsetDays` days before the pinned today (phase 17).
/// - `-uiTestingRestoreOnReactivate` opens that file each time the app comes back to the
///   foreground instead of at launch, so a test can open it while a sheet is up.
/// - `-seedContractions <scenario>` stores that `ContractionSeed` (`511`, `preterm`) (phase 20).
/// - `-contractionUndoWindow <seconds>` offers the contraction timer's "Hoàn tác" that long
///   instead of `ContractionRules.undoWindow`, so a slow CI simulator can still tap it.
/// - `-contractionClockStart <HH:mm>` starts the contraction timer's clock at that time on
///   launch day, ticking with the real clock (`ContractionClockStart`), so time-wheel tests
///   never depend on the hour CI happens to run at.
/// - `-seedLastBackupDaysAgo <days>` stores a last backup that many days before the pinned
///   now, so Profile shows the backup reminder card (1.1) when it is 30 or more.
/// - `-seedPregnancyEnded <birth|loss>:<daysAgo>` (1.1 item 4) stores a pregnancy that ended
///   that many days before the pinned today, in the cycle mode with predictions paused, and
///   one sample memory (`PregnancyEndSeed`).
/// - `-seedCareLowStreak <n>` stores that many low check-in answers in a row.
/// - `-uiTestingReportPreview` makes "Report for your doctor" write its PDF to a known path and
///   show its pages (scrollable) with the page count, instead of the share sheet (1.1).
/// - `-uiTestingReportLongNote` adds an appointment with a note of about 3,000 characters to that report.
public struct UITestLaunchOptions: Equatable, Sendable {
    public let isUITesting: Bool
    public let fixedNow: Date?
    public let seedDueDate: Date?
    public let seedCycles: CycleSeedScenario?
    public let seedOverdueSession: Bool
    public let seedSessions: Bool
    public let seedWeights: Bool
    public let sharing: FakePartnerSharing.MotherState?
    public let partner: FakePartnerSharing.PartnerState?
    public let seedCycleGoal: CycleGoal?
    public let seedContraception: Contraception?
    public let forcesPartnerUI: Bool
    public let seedAppMode: AppMode?
    public let restoreFile: String?
    public let restoresFileOnReactivate: Bool
    public let seedPill: PillSeed?
    public let seedContractions: ContractionSeed?
    public let contractionUndoWindow: TimeInterval?
    public let contractionClockStart: ContractionClockStart?
    public let seedLastBackupDaysAgo: Int?
    public let seedPregnancyEnded: PregnancyEndSeed?
    public let seedCareLowStreak: Int?
    public let reportPreview: Bool
    public let reportLongNote: Bool

    public init(arguments: [String]) {
        isUITesting = arguments.contains("-uiTesting")
        fixedNow = isUITesting ? Self.date(after: "-fixedNow", in: arguments) : nil
        seedDueDate = isUITesting ? Self.date(after: "-seedDueDate", in: arguments) : nil
        seedCycles = isUITesting ? Self.value(after: "-seedCycles", in: arguments).flatMap(CycleSeedScenario.init(rawValue:)) : nil
        seedOverdueSession = isUITesting && arguments.contains("-seedOverdueSession")
        seedSessions = isUITesting && arguments.contains("-seedSessions")
        seedWeights = isUITesting && arguments.contains("-seedWeights")
        sharing = isUITesting
            ? Self.value(after: "-uiTestingSharing", in: arguments).flatMap(FakePartnerSharing.MotherState.init(rawValue:))
            : nil
        partner = isUITesting
            ? Self.value(after: "-uiTestingPartner", in: arguments).flatMap(FakePartnerSharing.PartnerState.init(rawValue:))
            : nil
        seedCycleGoal = isUITesting ? Self.value(after: "-seedCycleGoal", in: arguments).flatMap(CycleGoal.init(rawValue:)) : nil
        seedContraception = isUITesting
            ? Self.value(after: "-seedContraception", in: arguments).flatMap(Contraception.init(rawValue:))
            : nil
        forcesPartnerUI = isUITesting && arguments.contains("-uiTestingPartnerUI")
        seedAppMode = isUITesting ? Self.value(after: "-seedAppMode", in: arguments).flatMap(AppMode.init(rawValue:)) : nil
        restoreFile = isUITesting ? Self.value(after: "-uiTestingRestoreFile", in: arguments) : nil
        restoresFileOnReactivate = isUITesting && arguments.contains("-uiTestingRestoreOnReactivate")
        seedPill = isUITesting ? Self.value(after: "-seedPill", in: arguments).flatMap(PillSeed.init(argument:)) : nil
        seedContractions = isUITesting
            ? Self.value(after: "-seedContractions", in: arguments).flatMap(ContractionSeed.init(rawValue:))
            : nil
        contractionUndoWindow = isUITesting
            ? Self.value(after: "-contractionUndoWindow", in: arguments).flatMap(TimeInterval.init).flatMap { $0 > 0 ? $0 : nil }
            : nil
        contractionClockStart = isUITesting
            ? Self.value(after: "-contractionClockStart", in: arguments).flatMap(ContractionClockStart.init(argument:))
            : nil
        seedLastBackupDaysAgo = isUITesting
            ? Self.value(after: "-seedLastBackupDaysAgo", in: arguments).flatMap { Int($0) }.flatMap { $0 >= 0 ? $0 : nil }
            : nil
        seedPregnancyEnded = isUITesting
            ? Self.value(after: "-seedPregnancyEnded", in: arguments).flatMap(PregnancyEndSeed.init(argument:))
            : nil
        seedCareLowStreak = isUITesting
            ? Self.value(after: "-seedCareLowStreak", in: arguments).flatMap { Int($0) }.flatMap { $0 >= 0 ? $0 : nil }
            : nil
        reportPreview = isUITesting && arguments.contains("-uiTestingReportPreview")
        reportLongNote = isUITesting && arguments.contains("-uiTestingReportLongNote")
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    private static func date(after flag: String, in arguments: [String]) -> Date? {
        value(after: flag, in: arguments).flatMap { try? Date($0, strategy: .iso8601) }
    }
}

/// `-contractionClockStart <HH:mm>`: the time of day the contraction timer's clock
/// reads at launch. It ticks on from there, so stops and undo still behave as on
/// the real clock; only the time of day is fixed.
public struct ContractionClockStart: Equatable, Sendable {
    public let hour: Int
    public let minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    public init?(argument: String) {
        let parts = argument.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        self.init(hour: hour, minute: minute)
    }

    /// Seconds to add to the real clock so that `launch` reads this time on its own day.
    public func offset(launch: Date, calendar: Calendar) -> TimeInterval {
        let start = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: launch) ?? launch
        return start.timeIntervalSince(launch)
    }
}

/// `-seedPill <type>:<offsetDays>`: a pill pack for UI tests and screenshots.
public struct PillSeed: Equatable, Sendable {
    public let type: PillPackType
    /// Days from the pack's first day to today (0: today is day 1).
    public let offsetDays: Int

    public init?(argument: String) {
        let parts = argument.split(separator: ":")
        guard parts.count == 2, let type = PillPackType(rawValue: String(parts[0])),
              let offset = Int(parts[1]), offset >= 0 else { return nil }
        self.type = type
        offsetDays = offset
    }

    /// Switched on at 21:00 with the pack starting `offsetDays` before `today`.
    public func settings(today: Date, calendar: Calendar) -> PillReminderSettings {
        let start = CalendarDay(today, calendar: calendar).adding(days: -offsetDays)
        return PillReminderSettings(enabled: true, packType: type, packStartDay: start, hour: 21, minute: 0)
    }
}

/// `-seedPregnancyEnded <birth|loss>:<daysAgo>` (1.1 item 4): a pregnancy that
/// ended `daysAgo` days before the pinned today, and one sample memory.
public struct PregnancyEndSeed: Equatable, Sendable {
    public let branch: PregnancyEndBranch
    public let daysAgo: Int

    public init(branch: PregnancyEndBranch, daysAgo: Int) {
        self.branch = branch
        self.daysAgo = daysAgo
    }

    public init?(argument: String) {
        let parts = argument.split(separator: ":")
        guard parts.count == 2, let branch = PregnancyEndBranch(rawValue: String(parts[0])),
              let days = Int(parts[1]), days >= 0 else { return nil }
        self.init(branch: branch, daysAgo: days)
    }

    public func state(now: Date, calendar: Calendar) -> PregnancyEndState {
        let today = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
        return PregnancyEndState(branch: branch, endDate: end, calendar: calendar)
    }

    /// A journey of 39 weeks (birth) or 12 weeks (loss) with a few entries of each kind.
    public func memory(now: Date, calendar: Calendar) -> PregnancyMemoryContent {
        let end = state(now: now, calendar: calendar).endDate
        let weeks = branch == .birth ? 39 : 12
        func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: end) ?? end }
        let start = day(-weeks * 7)
        let lastWeeks = branch == .birth ? [-20, -13, -6] : [-30, -16, -9]
        return PregnancyMemoryContent(
            branch: branch,
            start: start,
            end: end,
            furthestWeek: weeks,
            kickDays: branch == .birth
                ? lastWeeks.map { KickDay(day: day($0), sessionCount: 2, totalKicks: 20, bestDuration: 18 * 60) }
                : [],
            appointments: [
                MemoryAppointment(date: day(-weeks * 7 + 56).addingTimeInterval(9 * 3600), title: "Siêu âm", note: "Nghe tim bé"),
                MemoryAppointment(date: day(lastWeeks[1]).addingTimeInterval(9 * 3600), title: "Khám định kỳ", note: ""),
            ],
            weights: lastWeeks.enumerated().map { MemoryWeight(day: day($0.element), kg: 54 + Double($0.offset)) },
            notes: [
                MemoryNote(day: day(-weeks * 7 + 50), text: "Hôm nay biết tin, vui quá.", moods: ["happy"], pregnancySymptoms: ["nausea"]),
                MemoryNote(day: day(lastWeeks[2]), text: "Nói chuyện với con trước khi ngủ.", moods: ["calm"], pregnancySymptoms: []),
            ]
        )
    }
}
