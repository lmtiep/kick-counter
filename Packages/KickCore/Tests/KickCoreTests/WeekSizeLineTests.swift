import Foundation
import Testing
@testable import KickCore

/// Phase 6 spec §4.2: the generated "Bé lớn cỡ nào?" sentence, with the app's
/// templates (`weekArticle.size.*` in Localizable.xcstrings) and number formats.
struct WeekSizeLineTests {
    static let en = WeekSizeLine.Templates(
        length: "Your baby is about %1$@ long from head to bottom, roughly the size of %2$@.",
        lengthAndWeight: "Your baby is about %1$@ long from head to bottom and weighs about %2$@, roughly the size of %3$@.",
        weightAndRange: "Your baby weighs about %1$@ (typically %2$@ to %3$@), roughly the size of %4$@."
    )
    static let vi = WeekSizeLine.Templates(
        length: "Bé dài khoảng %1$@ (từ đầu đến mông), cỡ %2$@.",
        lengthAndWeight: "Bé dài khoảng %1$@ (từ đầu đến mông) và nặng khoảng %2$@, cỡ %3$@.",
        weightAndRange: "Bé nặng khoảng %1$@ (thường từ %2$@ đến %3$@), cỡ %4$@."
    )

    static func decimal(_ value: Double, comma: Bool) -> String {
        let text = String(format: "%.1f", value)
        return comma ? text.replacingOccurrences(of: ".", with: ",") : text
    }

    /// Like the app's `Formatting`: at most one decimal for mm, kilograms with one
    /// decimal from 1,000 g, a decimal comma in Vietnamese, the range's unit once.
    static func numbers(comma: Bool, grams: String = "g", kilograms: String = "kg", millimeters: String = "mm") -> WeekSizeLine.Numbers {
        WeekSizeLine.Numbers(
            length: { mm in
                mm == mm.rounded() ? "\(Int(mm)) \(millimeters)" : "\(decimal(mm, comma: comma)) \(millimeters)"
            },
            weight: { g in
                g >= 1000 ? "\(decimal(Double(g) / 1000, comma: comma)) \(kilograms)" : "\(g) \(grams)"
            },
            rangeLow: { g, reference in
                reference >= 1000 ? decimal(Double(g) / 1000, comma: comma) : "\(g)"
            },
            rangeHigh: { g, reference in
                reference >= 1000 ? "\(decimal(Double(g) / 1000, comma: comma)) \(kilograms)" : "\(g) \(grams)"
            }
        )
    }

    let library: WeeklyContentLibrary

    init() throws {
        library = try WeeklyContentLibrary.bundled()
    }

    private func line(_ week: Int, _ language: ContentLanguage) throws -> String? {
        let content = try #require(library.content(forWeek: week))
        return WeekSizeLine.make(
            for: content,
            language: language,
            templates: language == .vi ? Self.vi : Self.en,
            numbers: Self.numbers(comma: language == .vi)
        )
    }

    @Test func weeks4To6HaveNoLine() throws {
        for week in 4...6 {
            #expect(try line(week, .vi) == nil, "week \(week)")
            #expect(try line(week, .en) == nil, "week \(week)")
        }
    }

    @Test func week8GivesTheCrownRumpLength() throws {
        #expect(try line(8, .vi) == "Bé dài khoảng 16 mm (từ đầu đến mông), cỡ một quả anh đào.")
        #expect(try line(8, .en) == "Your baby is about 16 mm long from head to bottom, roughly the size of a cherry.")
    }

    @Test func week12GivesLengthAndWeight() throws {
        #expect(try line(12, .vi) == "Bé dài khoảng 53,5 mm (từ đầu đến mông) và nặng khoảng 58 g, cỡ một quả kiwi.")
        #expect(try line(12, .en) == "Your baby is about 53.5 mm long from head to bottom and weighs about 58 g, roughly the size of a kiwi.")
    }

    @Test func week31GivesWeightAndRangeInKilograms() throws {
        #expect(try line(31, .vi) == "Bé nặng khoảng 1,8 kg (thường từ 1,5 đến 2,0 kg), cỡ một quả dưa lưới.")
        #expect(try line(31, .en) == "Your baby weighs about 1.8 kg (typically 1.5 to 2.0 kg), roughly the size of a cantaloupe.")
    }

    @Test func week40() throws {
        #expect(try line(40, .vi) == "Bé nặng khoảng 3,6 kg (thường từ 3,0 đến 4,2 kg), cỡ một quả dưa hấu vừa.")
        #expect(try line(40, .en) == "Your baby weighs about 3.6 kg (typically 3.0 to 4.2 kg), roughly the size of a medium watermelon.")
    }

    @Test func week42RepeatsWeek40sFiguresWithItsOwnComparison() throws {
        #expect(try line(42, .vi) == "Bé nặng khoảng 3,6 kg (thường từ 3,0 đến 4,2 kg), cỡ một quả dưa hấu to.")
        #expect(try line(42, .en) == "Your baby weighs about 3.6 kg (typically 3.0 to 4.2 kg), roughly the size of a large watermelon.")
        #expect(library.content(forWeek: 42)?.weightBeyondStandard == true)
    }

    /// VoiceOver reads the same sentence with the units spelled out.
    @Test func spokenNumbersAreUsedAsGiven() throws {
        let content = try #require(library.content(forWeek: 24))
        let spoken = WeekSizeLine.make(
            for: content,
            language: .en,
            templates: Self.en,
            numbers: Self.numbers(comma: false, grams: "grams", kilograms: "kilograms", millimeters: "millimeters")
        )
        #expect(spoken == "Your baby weighs about 670 grams (typically 556 to 784 grams), roughly the size of an ear of corn.")
    }
}
