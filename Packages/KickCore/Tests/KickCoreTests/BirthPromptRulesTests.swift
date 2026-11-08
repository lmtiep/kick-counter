import Testing
@testable import KickCore

/// Birth celebration spec §1: the Today "Has your baby arrived?" card shows from week 37.
struct BirthPromptRulesTests {
    @Test func todayCardFromWeek37() {
        #expect(BirthPromptRules.showsTodayCard(week: 30) == false)
        #expect(BirthPromptRules.showsTodayCard(week: 36) == false)
        #expect(BirthPromptRules.showsTodayCard(week: 37))
        #expect(BirthPromptRules.showsTodayCard(week: 38))
        #expect(BirthPromptRules.showsTodayCard(week: 42))
    }
}
