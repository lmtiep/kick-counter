import Foundation

/// The mode named in the feedback email: the four things the app can be doing.
public enum FeedbackMode: String, Equatable, Sendable {
    case cycleTracking, tryingToConceive, pregnant, partner

    public init(appMode: AppMode, goal: CycleGoal) {
        switch appMode {
        case .pregnant: self = .pregnant
        case .partner: self = .partner
        case .tryingToConceive: self = goal == .tracking ? .cycleTracking : .tryingToConceive
        }
    }
}

/// The "Gửi góp ý" email: where it goes, its subject and a body that holds the user's
/// message plus a few technical facts. No health data ever goes into it.
public struct FeedbackEmail: Equatable, Sendable {
    public static let address = "lmtiep@gmail.com"

    /// Labels (already localized) and values of the technical block, in order.
    public struct Facts: Equatable, Sendable {
        public var appVersion: String
        public var build: String
        public var iOSVersion: String
        public var deviceModel: String
        public var language: String
        public var mode: String

        public init(appVersion: String, build: String, iOSVersion: String, deviceModel: String, language: String, mode: String) {
            self.appVersion = appVersion
            self.build = build
            self.iOSVersion = iOSVersion
            self.deviceModel = deviceModel
            self.language = language
            self.mode = mode
        }
    }

    public struct Labels: Equatable, Sendable {
        public var app: String
        public var ios: String
        public var device: String
        public var language: String
        public var mode: String

        public init(app: String, ios: String, device: String, language: String, mode: String) {
            self.app = app
            self.ios = ios
            self.device = device
            self.language = language
            self.mode = mode
        }
    }

    public let subject: String
    public let body: String

    /// An empty line for the message, then the facts.
    public init(subject: String, labels: Labels, facts: Facts) {
        self.subject = subject
        body = [
            "",
            "",
            "—",
            "\(labels.app): \(facts.appVersion) (\(facts.build))",
            "\(labels.ios): \(facts.iOSVersion)",
            "\(labels.device): \(facts.deviceModel)",
            "\(labels.language): \(facts.language)",
            "\(labels.mode): \(facts.mode)",
        ].joined(separator: "\n")
    }

    /// `mailto:` with the subject and body percent-encoded; nil only if encoding fails.
    public var mailtoURL: URL? {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+?#/:@")
        guard let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: allowed),
              let encodedBody = body.addingPercentEncoding(withAllowedCharacters: allowed)
        else { return nil }
        return URL(string: "mailto:\(Self.address)?subject=\(encodedSubject)&body=\(encodedBody)")
    }

    /// The device model identifier from `uname`'s machine name, e.g. `iPhone16,2`. In the
    /// simulator the machine is `arm64`/`x86_64`, so the simulated identifier is used.
    public static func modelIdentifier(machine: String, simulatorModel: String?) -> String {
        if let simulatorModel, !simulatorModel.isEmpty { return simulatorModel }
        return machine
    }
}
