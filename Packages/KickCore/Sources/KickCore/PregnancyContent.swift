import Foundation

/// Language of the bundled medical content and of the whole app: the first of
/// the user's preferred languages that the app supports, falling back to
/// English — unless a language was chosen in the app (`AppLanguage`).
public enum ContentLanguage: String, Codable, Sendable, CaseIterable {
    case en
    case vi

    public init(preferredLanguages: [String]) {
        for identifier in preferredLanguages {
            switch Locale(identifier: identifier).language.languageCode?.identifier {
            case "vi":
                self = .vi
                return
            case "en":
                self = .en
                return
            default:
                continue
            }
        }
        self = .en
    }

    public static var current: ContentLanguage {
        AppLanguage.current.resolved(preferredLanguages: Locale.preferredLanguages)
    }
}

public struct LocalizedText: Codable, Equatable, Sendable {
    public var en: String
    public var vi: String

    public func text(_ language: ContentLanguage) -> String {
        language == .vi ? vi : en
    }
}

public struct LocalizedList: Codable, Equatable, Sendable {
    public var en: [String]
    public var vi: [String]

    public func items(_ language: ContentLanguage) -> [String] {
        language == .vi ? vi : en
    }
}

/// "Your baby is about the size of …", illustrated by an emoji (no images).
public struct FruitSize: Codable, Equatable, Sendable {
    public var emoji: String
    public var en: String
    public var vi: String

    public func name(_ language: ContentLanguage) -> String {
        language == .vi ? vi : en
    }
}

public struct WeekContent: Codable, Equatable, Sendable, Identifiable {
    public var week: Int
    /// Set to true by the reviewing obstetrician; Release builds hide unreviewed weeks.
    public var reviewed: Bool
    public var size: FruitSize
    /// Crown–rump length in mm (Hadlock 1992), weeks 7–13 only; absent otherwise.
    public var crlMm: Double?
    /// Estimated fetal weight in grams, Hadlock 1991 Table 1: 50th percentile with the
    /// 10th–90th range. Weeks 10–42 (41–42 reuse week 40); absent before week 10.
    public var weightG: Int?
    public var weightP10G: Int?
    public var weightP90G: Int?
    public var baby: LocalizedList
    public var mom: LocalizedList
    public var tips: LocalizedList
    /// "When to get care right away" — every item points to a doctor or maternity unit.
    public var warnings: LocalizedList

    public var id: Int { week }

    /// Hadlock's weight standard (1991, Table 1) ends at 40 weeks.
    public static let weightStandardLastWeek = 40

    /// True when the weight shown is week 40's because the standard has no later rows.
    public var weightBeyondStandard: Bool {
        weightG != nil && week > Self.weightStandardLastWeek
    }
}

/// A suggested check-up, e.g. the nuchal translucency scan in weeks 11–14.
public struct Milestone: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var fromWeek: Int
    public var toWeek: Int
    public var title: LocalizedText
    public var detail: LocalizedText
    public var reviewed: Bool
}

/// Root of `pregnancy-content.json`.
public struct PregnancyContent: Codable, Equatable, Sendable {
    public var version: Int
    public var sources: [String]
    public var weeks: [WeekContent]
    public var milestones: [Milestone]
}
