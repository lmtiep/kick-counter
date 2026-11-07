import Foundation
import KickCore
import SwiftData
import Testing
@testable import KickData

/// 1.1: bag overrides, custom items and questions travel through export and restore.
@MainActor
struct ChecklistBackupStoreTests {
    let container: ModelContainer
    let store: ChecklistStore
    let now = date("2026-11-06T08:00:00Z")

    init() throws {
        container = try KickPersistence.makeContainer(inMemory: true)
        store = ChecklistStore(context: container.mainContext)
    }

    private func records(_ items: [ChecklistItemRecord]) -> BackupRecords {
        BackupRecords(sessions: [], appointments: [], periods: [], logs: [], weights: [], checklistItems: items)
    }

    @Test func exportReadsTheChecklistItems() throws {
        try store.setBuiltInDone("cccd", done: true, now: now)
        _ = try store.addBagItem("Gối", group: .mother, now: now)
        _ = try store.addQuestion("Hỏi về cân nặng", appointmentID: nil, now: now)
        let exported = try BackupStore.export(from: container)
        #expect(exported.checklistItems.count == 3)
        #expect(exported.checklistItems.map(\.text).sorted() == ["", "Gối", "Hỏi về cân nặng"])
    }

    @Test func exportAndReplaceRoundTripChecklistItems() throws {
        try store.setBuiltInDone("cccd", done: true, now: now)
        try store.setBuiltInHidden("cash", hidden: true, now: now)
        _ = try store.addBagItem("Gối", group: .mother, now: now)
        _ = try store.addQuestion("Hỏi", appointmentID: UUID(), now: now)
        let exported = try BackupStore.export(from: container)
        let document = BackupDocument(createdAt: now, appVersion: "1.1", records: exported, settings: [:])
        let decoded = try BackupCodec.decode(BackupCodec.encode(document))

        try DataReset.deleteAll(in: container)
        #expect(try store.items().isEmpty)
        try BackupStore.replaceAll(in: container, with: decoded.records)

        let restored = try store.items()
        #expect(Set(restored.map(\.id)) == Set(exported.checklistItems.map(\.id)))
        #expect(BagList.progress(BagList.sections(overrides: restored)).done == 1)
        #expect(BagList.hiddenCount(overrides: restored) == 1)
    }

    @Test func replaceAllRemovesOldChecklistItems() throws {
        _ = try store.addQuestion("Cũ", appointmentID: nil, now: now)
        let new = ChecklistItemRecord(kind: .question, text: "Mới", createdAt: now)
        try BackupStore.replaceAll(in: container, with: records([new]))
        #expect(try store.items().map(\.text) == ["Mới"])
        try BackupStore.replaceAll(in: container, with: records([]))
        #expect(try store.items().isEmpty)
    }

    @Test func aFailedRestoreKeepsTheOldChecklistItems() throws {
        _ = try store.addQuestion("Cũ", appointmentID: nil, now: now)
        struct Boom: Error {}
        #expect(throws: Boom.self) {
            try BackupStore.replaceAll(in: container, with: records([ChecklistItemRecord(kind: .question, text: "Mới", createdAt: now)])) { _ in throw Boom() }
        }
        #expect(try store.items().map(\.text) == ["Cũ"])
    }
}
