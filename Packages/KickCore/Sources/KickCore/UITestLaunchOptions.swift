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
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    private static func date(after flag: String, in arguments: [String]) -> Date? {
        value(after: flag, in: arguments).flatMap { try? Date($0, strategy: .iso8601) }
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
