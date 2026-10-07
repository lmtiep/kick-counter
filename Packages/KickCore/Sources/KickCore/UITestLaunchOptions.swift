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
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    private static func date(after flag: String, in arguments: [String]) -> Date? {
        value(after: flag, in: arguments).flatMap { try? Date($0, strategy: .iso8601) }
    }
}
