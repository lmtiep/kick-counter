import Foundation
import Testing
@testable import KickCore

/// Phase 9 spec §3.2: step order, skips, "I don't remember" and what is saved.
struct OnboardingFlowTests {
    private let now = date("2026-10-02T12:00:00Z")
    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00Z") }

    private func newFlow() -> OnboardingFlow {
        OnboardingFlow(lastPeriodStart: day("2026-10-02"), pregnancyDates: PregnancyDateSelection(source: .dueDate, date: day("2027-02-19")))
    }

    /// Walks with "Continue" and records every step.
    private func walk(_ flow: inout OnboardingFlow) -> [OnboardingStep] {
        var seen = [flow.step]
        while flow.step != .result {
            flow.next()
            seen.append(flow.step)
        }
        return seen
    }

    @Test func eachGoalHasItsOwnSteps() {
        #expect(OnboardingFlow.steps(for: .tracking) == [.welcome, .goal, .lastPeriod, .periodLength, .cycleLength, .regularity, .contraception, .result])
        #expect(OnboardingFlow.steps(for: .conceiving) == [.welcome, .goal, .lastPeriod, .periodLength, .cycleLength, .regularity, .result])
        #expect(OnboardingFlow.steps(for: .pregnant) == [.welcome, .goal, .dueDate, .result])
    }

    @Test func continueFollowsTheChosenBranch() {
        for goal in OnboardingGoal.allCases {
            var flow = newFlow()
            flow.next()
            flow.goal = goal
            #expect(walk(&flow) == Array(OnboardingFlow.steps(for: goal).dropFirst()))
            #expect(flow.stepNumber == flow.stepCount)
        }
    }

    @Test func theGoalStepNeedsAnAnswerToContinue() {
        var flow = newFlow()
        flow.next()
        #expect(flow.step == .goal)
        #expect(flow.canContinue == false)
        flow.next()
        #expect(flow.step == .goal)
        flow.goal = .conceiving
        flow.next()
        #expect(flow.step == .lastPeriod)
    }

    @Test func progressCountsTheLongestBranchUntilAGoalIsChosen() {
        var flow = newFlow()
        #expect(flow.stepNumber == 1)
        #expect(flow.stepCount == 8)
        flow.next()
        flow.goal = .pregnant
        #expect(flow.stepNumber == 2)
        #expect(flow.stepCount == 4)
    }

    @Test func backReturnsToThePreviousStepAndStopsAtWelcome() {
        var flow = newFlow()
        #expect(flow.canGoBack == false)
        flow.back()
        #expect(flow.step == .welcome)
        flow.next()
        flow.goal = .tracking
        flow.next()
        flow.next()
        #expect(flow.step == .periodLength)
        flow.back()
        #expect(flow.step == .lastPeriod)
    }

    /// Fix round 1: changing the goal while past it must not strand the flow
    /// on a step the new branch doesn't have.
    @Test func changingTheGoalOffTheGoalStepReturnsToIt() {
        var flow = newFlow()
        flow.next()
        flow.goal = .tracking
        flow.next()
        flow.next()
        #expect(flow.step == .periodLength)
        flow.goal = .pregnant
        #expect(flow.step == .goal)
    }

    @Test func onlyQuestionStepsCanBeSkipped() {
        var flow = newFlow()
        #expect(flow.isQuestion == false)
        flow.skip()
        #expect(flow.step == .welcome)
        flow.next()
        #expect(flow.isQuestion)
    }

    @Test func skippingTheGoalMeansPregnancy() {
        var flow = newFlow()
        flow.next()
        flow.skip()
        #expect(flow.goal == .pregnant)
        #expect(flow.step == .dueDate)
    }

    @Test func skippedAnswersKeepTheirDefaults() {
        var flow = newFlow()
        flow.next()
        flow.goal = .tracking
        flow.next()
        flow.skip() // last period
        flow.periodLength = 7
        flow.skip()
        flow.cycleLength = 35
        flow.skip()
        flow.regularity = .irregular
        flow.skip()
        flow.contraception = .pill
        flow.skip()
        #expect(flow.step == .result)
        #expect(flow.finish() == .cycle(
            goal: .tracking, settings: CycleSettings(), firstPeriodStart: nil, regularity: .unknown, contraception: nil
        ))
    }

    @Test func dontRememberLeavesNoPeriodAndNoPrediction() {
        var flow = newFlow()
        flow.lastPeriodStart = nil
        #expect(flow.prediction(now: now, calendar: utcCalendar) == nil)
    }

    @Test func thePredictionUsesTheAnsweredLengths() {
        var flow = newFlow()
        flow.lastPeriodStart = day("2026-09-20")
        flow.cycleLength = 30
        #expect(flow.prediction(now: now, calendar: utcCalendar) == .nextPeriod(day("2026-10-20")))
    }

    @Test func aPeriodOlderThanOneCycleIsLate() {
        var flow = newFlow()
        flow.lastPeriodStart = day("2026-08-30")
        #expect(flow.prediction(now: now, calendar: utcCalendar) == .late(days: 5))
    }

    @Test func lengthsStayInTheirRanges() {
        var flow = newFlow()
        flow.periodLength = 1
        flow.cycleLength = 60
        #expect(flow.periodLength == 2)
        #expect(flow.cycleLength == 45)
    }

    /// Fix round 1: a replay starting from stored 30/6 must not have skipping
    /// the length steps silently change them to the app-wide 28/5 default.
    @Test func skippingALengthRestoresTheStartingValueNotTheGlobalDefault() {
        var flow = OnboardingFlow(
            lastPeriodStart: nil,
            settings: CycleSettings(typicalCycleLength: 30, typicalPeriodLength: 6),
            pregnancyDates: nil
        )
        flow.next() // goal
        flow.goal = .tracking
        flow.next() // lastPeriod
        flow.next() // periodLength
        flow.periodLength = 9
        flow.skip() // restores 6, moves to cycleLength
        flow.cycleLength = 40
        flow.skip() // restores 30, moves to regularity
        #expect(flow.periodLength == 6)
        #expect(flow.cycleLength == 30)
    }

    @Test func trackingFinishesWithEveryAnswer() {
        var flow = newFlow()
        flow.goal = .tracking
        flow.lastPeriodStart = day("2026-09-20")
        flow.periodLength = 4
        flow.cycleLength = 31
        flow.regularity = .regular
        flow.contraception = .condom
        #expect(flow.finish() == .cycle(
            goal: .tracking,
            settings: CycleSettings(typicalCycleLength: 31, typicalPeriodLength: 4),
            firstPeriodStart: day("2026-09-20"),
            regularity: .regular,
            contraception: .condom
        ))
        #expect(flow.finish().mode == .tryingToConceive)
    }

    @Test func conceivingNeverSavesAContraception() {
        var flow = newFlow()
        flow.goal = .conceiving
        flow.contraception = .pill
        guard case .cycle(let goal, _, _, _, let contraception) = flow.finish() else {
            Issue.record("expected the cycle branch")
            return
        }
        #expect(goal == .conceiving)
        #expect(contraception == nil)
    }

    @Test func pregnancyFinishesWithTheDatesOrNone() {
        var flow = newFlow()
        flow.goal = .pregnant
        #expect(flow.finish() == .pregnant(dates: PregnancyDateSelection(source: .dueDate, date: day("2027-02-19"))))
        #expect(flow.finish().mode == .pregnant)
        flow.next()
        flow.next()
        #expect(flow.step == .dueDate)
        flow.skip()
        #expect(flow.finish() == .pregnant(dates: nil))
    }

    @Test func remindersSettingIsKept() {
        let flow = OnboardingFlow(lastPeriodStart: nil, settings: CycleSettings(remindersEnabled: false), pregnancyDates: nil)
        #expect(flow.settings.remindersEnabled == false)
    }

    @Test func replayStartsFromTheStoredGoal() {
        #expect(OnboardingGoal(mode: .tryingToConceive, cycleGoal: .tracking) == .tracking)
        #expect(OnboardingGoal(mode: .tryingToConceive, cycleGoal: .conceiving) == .conceiving)
        #expect(OnboardingGoal(mode: .pregnant, cycleGoal: .tracking) == .pregnant)
        #expect(OnboardingGoal(mode: .partner, cycleGoal: .conceiving) == nil)
        #expect(OnboardingGoal.tracking.cycleGoal == .tracking)
        #expect(OnboardingGoal.pregnant.cycleGoal == nil)
        #expect(OnboardingGoal.conceiving.mode == .tryingToConceive)
    }
}
