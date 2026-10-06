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

/// Paragraphs of a week article, one array per language (phase 6 spec §4.1).
public struct LocalizedParagraphs: Codable, Equatable, Sendable {
    public var en: [String]
    public var vi: [String]

    public init(en: [String], vi: [String]) {
        self.en = en
        self.vi = vi
    }

    public func paragraphs(_ language: ContentLanguage) -> [String] {
        language == .vi ? vi : en
    }
}

/// A week's article (phase 6 spec §4.1). The Bé tab is `lead`, the generated
/// size line, `sizeNote` and `development`; the Mẹ tab is `body`, `todo` and
/// the week's `warnings`. Checked by `WeekArticleChecks`.
public struct WeekArticle: Codable, Equatable, Sendable {
    /// Bold opening of the Bé tab: at most 30 words (en) / 40 (vi).
    public var lead: LocalizedText
    /// "Bé lớn cỡ nào?", shown after the generated `WeekSizeLine`. No figures.
    public var sizeNote: LocalizedParagraphs
    /// "Bé phát triển ra sao": 2–3 paragraphs.
    public var development: LocalizedParagraphs
    /// Mẹ tab, "Cơ thể mẹ tuần này": 1–3 paragraphs.
    public var body: LocalizedParagraphs
    /// Mẹ tab, "Mẹ nên làm gì": 1–2 paragraphs.
    public var todo: LocalizedParagraphs
    /// Indices into `PregnancyContent.sources` (append-only, never reordered); at least one.
    public var sources: [Int]

    /// The paragraph fields by their JSON name, in reading order.
    var paragraphFields: [(name: String, paragraphs: LocalizedParagraphs)] {
        [
            (name: "sizeNote", paragraphs: sizeNote),
            (name: "development", paragraphs: development),
            (name: "body", paragraphs: body),
            (name: "todo", paragraphs: todo),
        ]
    }

    /// Every text of one language with its field name: the lead, then each paragraph.
    func texts(_ language: ContentLanguage) -> [(field: String, text: String)] {
        var result: [(field: String, text: String)] = [(field: "lead", text: lead.text(language))]
        for field in paragraphFields {
            for paragraph in field.paragraphs.paragraphs(language) {
                result.append((field: field.name, text: paragraph))
            }
        }
        return result
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
    /// The week's article (version 3); nil in a version-2 file or a week not yet written,
    /// in which case the week detail shows the bullet lists above.
    public var article: WeekArticle?

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
