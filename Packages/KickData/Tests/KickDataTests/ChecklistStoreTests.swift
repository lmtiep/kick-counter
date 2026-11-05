import Foundation
import KickCore
import SwiftData
import Testing
@testable import KickData

@MainActor
struct ChecklistStoreTests {
    struct SaveFailed: Error {}

    let now = date("2026-11-06T08:00:00Z")
    let container: ModelContainer
    let store: ChecklistStore

    init() throws {
        container = try KickPersistence.makeContainer(inMemory: true)
        store = ChecklistStore(context: container.mainContext)
    }

    private func rowCount() throws -> Int {
        try container.mainContext.fetchCount(FetchDescriptor<ChecklistItem>())
    }

    @Test func schemaIncludesChecklistItemWithNoRelationships() {
        let entity = KickPersistence.schema.entitiesByName["ChecklistItem"]
        #expect(entity != nil)
        #expect(entity?.relationships.isEmpty == true)
    }

    @Test func untouchedBuiltInsStoreNothing() throws {
        #expect(try store.items().isEmpty)
        #expect(try rowCount() == 0)
    }

    @Test func tickingABuiltInStoresOneOverride() throws {
        try store.setBuiltInDone("cccd", done: true, now: now)
        try store.setBuiltInDone("cccd", done: true, now: now)
        let rows = try store.items()
        #expect(rows.count == 1)
        #expect(rows[0].builtInID == "cccd")
        #expect(rows[0].isDone)
        #expect(rows[0].kind == .bag)
        let sections = BagList.sections(overrides: rows)
        #expect(BagList.progress(sections).done == 1)
    }

    @Test func untickingAnUntouchedOverrideRemovesIt() throws {
        try store.setBuiltInDone("cccd", done: true, now: now)
        try store.setBuiltInDone("cccd", done: false, now: now)
        #expect(try rowCount() == 0)
    }

    @Test func anUnknownBuiltInIsNotStored() throws {
        try store.setBuiltInDone("notAnItem", done: true, now: now)
        try store.setBuiltInHidden("notAnItem", hidden: true, now: now)
        #expect(try rowCount() == 0)
    }

    @Test func hidingAndUnhidingABuiltIn() throws {
        try store.setBuiltInHidden("cash", hidden: true, now: now)
        #expect(BagList.hiddenCount(overrides: try store.items()) == 1)
        try store.setBuiltInDone("cash", done: true, now: now)
        try store.setBuiltInHidden("cash", hidden: false, now: now)
        let rows = try store.items()
        #expect(rows.count == 1, "the tick stays")
        #expect(rows[0].isHidden == false && rows[0].isDone)
    }

    @Test func addingACustomItemTrimsAndOrders() throws {
        let first = try #require(try store.addBagItem("  Gối ôm ", group: .mother, now: now))
        let second = try #require(try store.addBagItem("Kẹp tóc", group: .mother, now: now))
        #expect(first.text == "Gối ôm")
        #expect(first.order < second.order)
        let mother = BagList.sections(overrides: try store.items()).first { $0.group == .mother }
        #expect(mother?.entries.suffix(2).map(\.text) == ["Gối ôm", "Kẹp tóc"])
    }

    @Test func blankTextIsRejected() throws {
        #expect(try store.addBagItem("   ", group: .baby, now: now) == nil)
        #expect(try store.addQuestion("\n", appointmentID: nil, now: now) == nil)
        #expect(try rowCount() == 0)
    }

    @Test func resetClearsTicksButKeepsHiddenAndCustomItems() throws {
        try store.setBuiltInDone("cccd", done: true, now: now)
        try store.setBuiltInDone("cash", done: true, now: now)
        try store.setBuiltInHidden("cash", hidden: true, now: now)
        let custom = try #require(try store.addBagItem("Gối", group: .mother, now: now))
        try store.setDone(id: custom.id, done: true)
        let question = try #require(try store.addQuestion("Hỏi về cân nặng", appointmentID: nil, now: now))
        try store.setDone(id: question.id, done: true)

        try store.resetBagTicks()

        let rows = try store.items()
        #expect(rows.filter { $0.kind == .bag }.allSatisfy { !$0.isDone })
        #expect(rows.contains { $0.builtInID == "cccd" } == false, "an untouched built-in is not stored")
        #expect(rows.contains { $0.builtInID == "cash" && $0.isHidden })
        #expect(rows.contains { $0.id == custom.id })
        #expect(rows.first { $0.id == question.id }?.isDone == true, "questions are not bag ticks")
    }

    @Test func unhideAllShowsEveryHiddenBuiltIn() throws {
        try store.setBuiltInHidden("cash", hidden: true, now: now)
        try store.setBuiltInHidden("towel", hidden: true, now: now)
        try store.unhideAllBuiltIns()
        #expect(BagList.hiddenCount(overrides: try store.items()) == 0)
        #expect(try rowCount() == 0)
    }

    @Test func questionsAttachToAnAppointmentOrStayUnassigned() throws {
        let appointment = UUID()
        let attached = try #require(try store.addQuestion(" Khi nào siêu âm? ", appointmentID: appointment, now: now))
        let loose = try #require(try store.addQuestion("Ăn gì tốt?", appointmentID: nil, now: now))
        #expect(attached.text == "Khi nào siêu âm?")
        let items = try store.items()
        #expect(QuestionRouting.questions(for: appointment, in: items).map(\.id) == [attached.id])
        #expect(QuestionRouting.unassigned(in: items).map(\.id) == [loose.id])
    }

    @Test func adoptMovesOnlyUnassignedQuestions() throws {
        let other = UUID()
        let mine = UUID()
        _ = try store.addQuestion("đã gán", appointmentID: other, now: now)
        _ = try store.addQuestion("chưa gán 1", appointmentID: nil, now: now)
        _ = try store.addQuestion("chưa gán 2", appointmentID: nil, now: now)
        _ = try store.addBagItem("Gối", group: .mother, now: now)

        let moved = try store.adoptUnassignedQuestions(into: mine)

        #expect(moved == 2)
        let items = try store.items()
        #expect(QuestionRouting.questions(for: mine, in: items).map(\.text) == ["chưa gán 1", "chưa gán 2"])
        #expect(QuestionRouting.questions(for: other, in: items).map(\.text) == ["đã gán"])
        #expect(QuestionRouting.unassigned(in: items).isEmpty)
    }

    @Test func deleteRemovesAnItem() throws {
        let question = try #require(try store.addQuestion("Hỏi", appointmentID: nil, now: now))
        try store.delete(id: question.id)
        try store.delete(id: UUID())
        #expect(try rowCount() == 0)
    }

    @Test func aFailedSaveRollsBack() throws {
        let failing = ChecklistStore(context: container.mainContext, saveContext: { _ in throw SaveFailed() })
        #expect(throws: SaveFailed.self) { try failing.setBuiltInDone("cccd", done: true, now: now) }
        #expect(try store.items().isEmpty)
    }
}
