import Foundation
import Testing
@testable import KickCore

/// 1.1: the backup gains an optional `checklistItems` array, still version 1.
struct ChecklistBackupTests {
    private let appointmentID = UUID(uuidString: "00000000-0000-0000-0000-0000000000a1")!
    private let at = date("2026-11-06T08:00:00.5Z")

    private var tickedBuiltIn: ChecklistItemRecord {
        ChecklistItemRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000071")!,
            kind: .bag, builtInID: "cccd", isDone: true, createdAt: at
        )
    }
    private var customBag: ChecklistItemRecord {
        ChecklistItemRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000072")!,
            kind: .bag, group: .baby, text: "Gối cho bé", order: 3, createdAt: at
        )
    }
    private var question: ChecklistItemRecord {
        ChecklistItemRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000073")!,
            kind: .question, text: "Khi nào siêu âm?", isDone: true, order: 1, appointmentID: appointmentID, createdAt: at
        )
    }

    private func document(_ records: [ChecklistItemRecord], appointments: [AppointmentRecord]? = nil) -> BackupDocument {
        var document = BackupCodecTests.sampleDocument()
        if let appointments { document.appointments = appointments.map(AppointmentDTO.init) }
        document.checklistItems = records.map(ChecklistItemDTO.init)
        return document
    }

    @Test func checklistRoundTrips() throws {
        let original = document([tickedBuiltIn, customBag, question])
        let decoded = try BackupCodec.decode(BackupCodec.encode(original))
        #expect(decoded == original)
        #expect(decoded.version == 1)
        #expect(decoded.records.checklistItems == [tickedBuiltIn, customBag, question])
    }

    @Test func anOlderFileLoadsAsEmptyAndAnEmptyListIsNotWritten() throws {
        let data = try BackupCodec.encode(BackupCodecTests.sampleDocument())
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["checklistItems"] == nil)
        #expect(try BackupCodec.decode(data).checklistItems.isEmpty)
    }

    @Test func recordsCarryTheChecklist() {
        var records = BackupCodecTests.sampleDocument().records
        records.checklistItems = [question]
        let document = BackupDocument(createdAt: BackupCodecTests.created, appVersion: "1.1", records: records, settings: [:])
        #expect(document.checklistItems == [ChecklistItemDTO(question)])
        #expect(document.records.checklistItems == [question])
    }

    @Test func summaryCountsTheChecklistItems() {
        let empty = BackupDocument(
            createdAt: BackupCodecTests.created, appVersion: "1.1",
            sessions: [], appointments: [], periods: [], cycleLogs: [], weights: [], settings: [:]
        )
        var withOne = empty
        withOne.checklistItems = [ChecklistItemDTO(question)]
        #expect(withOne.summary.checklistItems == 1)
        #expect(!withOne.summary.isEmpty)
        #expect(empty.summary.isEmpty)
    }

    @Test func validationDropsUnknownKindsBlankTextAndDuplicates() {
        let now = date("2026-11-07T12:00:00Z")
        var unknownKind = ChecklistItemDTO(question)
        unknownKind.list = "journal"
        let blankQuestion = ChecklistItemRecord(kind: .question, text: "  ", appointmentID: appointmentID, createdAt: at)
        let blankCustom = ChecklistItemRecord(kind: .bag, group: .mother, text: "", createdAt: at)
        var unknownGroup = ChecklistItemDTO(customBag)
        unknownGroup.id = UUID()
        unknownGroup.group = "garage"
        var file = document([tickedBuiltIn, customBag, question, blankQuestion, blankCustom])
        file.checklistItems += [unknownKind, unknownGroup, ChecklistItemDTO(tickedBuiltIn)]
        let appointment = AppointmentRecord(id: appointmentID, date: date("2026-11-20T08:00:00Z"), title: "Khám")
        file.appointments = [AppointmentDTO(appointment)]

        let (cleaned, skipped) = BackupValidation.clean(file, now: now, calendar: utcCalendar)

        #expect(cleaned.records.checklistItems == [tickedBuiltIn, customBag, question])
        #expect(skipped == 5)
    }

    @Test func aQuestionForAMissingAppointmentBecomesUnassigned() {
        let now = date("2026-11-07T12:00:00Z")
        var file = document([question])
        file.appointments = []
        let (cleaned, skipped) = BackupValidation.clean(file, now: now, calendar: utcCalendar)
        #expect(skipped == 0)
        #expect(cleaned.records.checklistItems.first?.appointmentID == nil)
        #expect(cleaned.records.checklistItems.first?.text == question.text)
    }

    @Test func aQuestionKeepsItsAppointmentWhenTheFileHasIt() {
        let now = date("2026-11-07T12:00:00Z")
        let appointment = AppointmentRecord(id: appointmentID, date: date("2026-11-20T08:00:00Z"), title: "Khám")
        let (cleaned, _) = BackupValidation.clean(document([question], appointments: [appointment]), now: now, calendar: utcCalendar)
        #expect(cleaned.records.checklistItems.first?.appointmentID == appointmentID)
    }

    @Test func aQuestionForADroppedBlankTitleAppointmentBecomesUnassigned() {
        let now = date("2026-11-07T12:00:00Z")
        let blank = AppointmentRecord(id: appointmentID, date: date("2026-11-20T08:00:00Z"), title: "  ")
        let (cleaned, skipped) = BackupValidation.clean(document([question], appointments: [blank]), now: now, calendar: utcCalendar)
        #expect(cleaned.appointments.isEmpty)
        #expect(skipped == 1)
        #expect(cleaned.records.checklistItems.first?.appointmentID == nil)
    }

    @Test func duplicateBuiltInOverridesKeepTheNewest() {
        let now = date("2026-11-07T12:00:00Z")
        let older = ChecklistItemRecord(kind: .bag, builtInID: "cccd", isDone: true, createdAt: date("2026-11-01T08:00:00Z"))
        let newer = ChecklistItemRecord(kind: .bag, builtInID: "cccd", isDone: false, isHidden: true, createdAt: date("2026-11-02T08:00:00Z"))
        for order in [[older, newer], [newer, older]] {
            let (cleaned, skipped) = BackupValidation.clean(document(order), now: now, calendar: utcCalendar)
            #expect(cleaned.records.checklistItems == [newer])
            #expect(skipped == 1)
        }
    }
}
