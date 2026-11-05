import Foundation
import Testing
@testable import KickCore

/// Hospital bag checklist (1.1 spec): the built-in list merged with the stored overrides.
struct ChecklistTests {
    private func override(
        _ builtInID: String, done: Bool = false, hidden: Bool = false
    ) -> ChecklistItemRecord {
        ChecklistItemRecord(
            kind: .bag, group: nil, builtInID: builtInID, text: "", isDone: done, isHidden: hidden,
            order: 0, createdAt: date("2026-11-06T08:00:00Z")
        )
    }

    private func custom(
        _ text: String, group: BagGroup = .mother, order: Int = 0, done: Bool = false, at iso: String = "2026-11-06T08:00:00Z"
    ) -> ChecklistItemRecord {
        ChecklistItemRecord(
            kind: .bag, group: group, builtInID: nil, text: text, isDone: done, isHidden: false,
            order: order, createdAt: date(iso)
        )
    }

    private func entries(_ sections: [BagSection], _ group: BagGroup) -> [BagEntry] {
        sections.first { $0.group == group }?.entries ?? []
    }

    @Test func catalogHasUniqueIdsAndAllFourGroups() {
        let ids = BagCatalog.items.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(Set(BagCatalog.items.map(\.group)) == Set(BagGroup.allCases))
        #expect(BagGroup.allCases == [.documents, .mother, .baby, .companion])
    }

    @Test func catalogSizeIsBetween25And35() {
        #expect((25...35).contains(BagCatalog.items.count))
    }

    @Test func documentsGroupHasTheVietnameseEssentials() {
        let documents = Set(BagCatalog.items.filter { $0.group == .documents }.map(\.id))
        #expect(documents.isSuperset(of: ["cccd", "prenatalBook", "bhyt", "referral", "cash"]))
    }

    /// Every built-in and group title has an English and a Vietnamese string in the catalog.
    @Test func everyBuiltInHasViAndEnStrings() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Shared/Localizable.xcstrings")
        let catalog = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let strings = try #require(catalog["strings"] as? [String: Any])
        func value(_ key: String, _ language: String) -> String? {
            let localizations = (strings[key] as? [String: Any])?["localizations"] as? [String: Any]
            let unit = (localizations?[language] as? [String: Any])?["stringUnit"] as? [String: Any]
            return unit?["value"] as? String
        }
        let keys = BagCatalog.items.map { BagCatalog.stringKey(forItem: $0.id) }
            + BagGroup.allCases.map { BagCatalog.stringKey(forGroup: $0) }
        for key in keys {
            for language in ["en", "vi"] {
                #expect(value(key, language)?.isEmpty == false, "\(key) \(language)")
            }
        }
    }

    /// Practical items only: no medicines or medical items (spec, project rule).
    @Test func noBuiltInMentionsMedicine() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Shared/Localizable.xcstrings")
        let catalog = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let strings = try #require(catalog["strings"] as? [String: Any])
        let banned = ["thuốc", "vitamin", "kháng sinh", "medicine", "medication", "pills", "tablet", "drug", "vaccine", "thermometer", "nhiệt kế"]
        for item in BagCatalog.items {
            let localizations = (strings[BagCatalog.stringKey(forItem: item.id)] as? [String: Any])?["localizations"] as? [String: Any]
            for language in ["en", "vi"] {
                let unit = (localizations?[language] as? [String: Any])?["stringUnit"] as? [String: Any]
                let text = (unit?["value"] as? String ?? "").lowercased()
                for word in banned {
                    #expect(!text.contains(word), "\(item.id) \(language): \(text)")
                }
            }
        }
    }

    @Test func untouchedBuiltInsAreUndoneAndVisible() {
        let sections = BagList.sections(overrides: [])
        #expect(sections.map(\.group) == BagGroup.allCases)
        let all = sections.flatMap(\.entries)
        #expect(all.count == BagCatalog.items.count)
        #expect(all.allSatisfy { !$0.isDone && $0.builtInID != nil && $0.itemID == nil })
        #expect(entries(sections, .documents).map(\.builtInID) == BagCatalog.items.filter { $0.group == .documents }.map(\.id))
    }

    @Test func overrideTicksABuiltIn() {
        let sections = BagList.sections(overrides: [override("cccd", done: true)])
        let cccd = entries(sections, .documents).first { $0.builtInID == "cccd" }
        #expect(cccd?.isDone == true)
        #expect(sections.flatMap(\.entries).filter(\.isDone).count == 1)
    }

    @Test func hiddenBuiltInLeavesTheSectionAndTheCount() {
        let sections = BagList.sections(overrides: [override("cash", hidden: true)])
        #expect(entries(sections, .documents).contains { $0.builtInID == "cash" } == false)
        #expect(BagList.progress(sections).total == BagCatalog.items.count - 1)
        #expect(BagList.hiddenCount(overrides: [override("cash", hidden: true)]) == 1)
    }

    @Test func customItemsFollowBuiltInsByOrder() {
        let second = custom("Gối ôm", order: 2)
        let first = custom("Kẹp tóc", order: 1)
        let sections = BagList.sections(overrides: [second, first])
        let mother = entries(sections, .mother)
        let builtIns = BagCatalog.items.filter { $0.group == .mother }.count
        #expect(mother.count == builtIns + 2)
        #expect(mother.suffix(2).map(\.text) == ["Kẹp tóc", "Gối ôm"])
        #expect(mother.suffix(2).allSatisfy { $0.itemID != nil && $0.builtInID == nil })
    }

    @Test func customItemsWithTheSameOrderKeepCreationOrder() {
        let late = custom("B", order: 1, at: "2026-11-06T09:00:00Z")
        let early = custom("A", order: 1, at: "2026-11-06T08:00:00Z")
        let mother = entries(BagList.sections(overrides: [late, early]), .mother)
        #expect(mother.suffix(2).map(\.text) == ["A", "B"])
    }

    @Test func aCustomItemInAnotherGroupStaysThere() {
        let sections = BagList.sections(overrides: [custom("Sổ ghi chép", group: .companion, done: true)])
        #expect(entries(sections, .companion).last?.text == "Sổ ghi chép")
        #expect(entries(sections, .companion).last?.isDone == true)
    }

    @Test func overrideForAnUnknownBuiltInIsIgnored() {
        let sections = BagList.sections(overrides: [override("futureItem", done: true)])
        #expect(sections.flatMap(\.entries).count == BagCatalog.items.count)
        #expect(BagList.progress(sections).done == 0)
    }

    @Test func questionsNeverAppearInTheBag() {
        let question = ChecklistItemRecord(kind: .question, text: "Hỏi về cân nặng", createdAt: date("2026-11-06T08:00:00Z"))
        #expect(BagList.sections(overrides: [question]).flatMap(\.entries).count == BagCatalog.items.count)
    }

    @Test func progressCountsVisibleItemsOnly() {
        let overrides = [
            override("cccd", done: true), override("cash", done: true, hidden: true),
            custom("Gối", done: true), custom("Kẹp", done: false),
        ]
        let progress = BagList.progress(BagList.sections(overrides: overrides))
        #expect(progress.done == 2)
        #expect(progress.total == BagCatalog.items.count - 1 + 2)
        #expect(progress.fraction == Double(progress.done) / Double(progress.total))
    }

    @Test func todayCardFromWeek32() {
        #expect(BagRules.showsTodayCard(week: 31) == false)
        #expect(BagRules.showsTodayCard(week: 32))
        #expect(BagRules.showsTodayCard(week: 33))
        #expect(BagRules.showsTodayCard(week: 41))
    }

    @Test func cleanTrimsAndRejectsEmptyText() {
        #expect(ChecklistText.clean("  Gối ôm \n") == "Gối ôm")
        #expect(ChecklistText.clean("   ") == nil)
        #expect(ChecklistText.clean("") == nil)
        #expect(ChecklistText.clean(String(repeating: "a", count: 900))?.count == ChecklistText.maxLength)
    }
}
