import Foundation
import Testing
@testable import KickCore

/// Final review: no copy of a backup (unencrypted health data) stays in the app.
struct BackupLeftoversTests {
    private func makeHome() throws -> (home: URL, documents: URL, tmp: URL) {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("home-\(UUID().uuidString)")
        let documents = home.appendingPathComponent("Documents")
        let tmp = home.appendingPathComponent("tmp")
        try FileManager.default.createDirectory(at: documents.appendingPathComponent("Inbox"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        return (home, documents, tmp)
    }

    @Test func insideTheAppContainer() throws {
        let (home, documents, _) = try makeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let inbox = documents.appendingPathComponent("Inbox/LunaMom-2026-10-01.lunamom")
        #expect(BackupLeftovers.isInside(inbox, directory: home))
        #expect(BackupLeftovers.isInside(URL(fileURLWithPath: home.path + "/../" + home.lastPathComponent + "/tmp/x.lunamom"), directory: home))
        #expect(!BackupLeftovers.isInside(URL(fileURLWithPath: "/private/var/mobile/Library/Mobile Documents/x.lunamom"), directory: home))
        #expect(!BackupLeftovers.isInside(URL(fileURLWithPath: home.path + "-other/x.lunamom"), directory: home))
        #expect(!BackupLeftovers.isInside(URL(string: "https://example.com/x.lunamom")!, directory: home))
    }

    @Test func removeAllClearsTheInboxExportFoldersAndTmpBackups() throws {
        let (home, documents, tmp) = try makeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let fm = FileManager.default
        let inboxFile = documents.appendingPathComponent("Inbox/LunaMom-2026-10-01.lunamom")
        try Data("x".utf8).write(to: inboxFile)
        let exportFolder = tmp.appendingPathComponent("\(BackupLeftovers.exportFolderPrefix)\(UUID().uuidString)")
        try fm.createDirectory(at: exportFolder, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: exportFolder.appendingPathComponent("LunaMom-2026-10-09.lunamom"))
        let tmpBackup = tmp.appendingPathComponent("LunaMom-2026-10-01.lunamom")
        try Data("x".utf8).write(to: tmpBackup)
        let unrelated = tmp.appendingPathComponent("other.txt")
        try Data("keep".utf8).write(to: unrelated)
        let documentFile = documents.appendingPathComponent("keep.json")
        try Data("keep".utf8).write(to: documentFile)

        BackupLeftovers.removeAll(documents: documents, temporary: tmp)

        #expect(!fm.fileExists(atPath: inboxFile.path))
        #expect(!fm.fileExists(atPath: exportFolder.path))
        #expect(!fm.fileExists(atPath: tmpBackup.path))
        #expect(fm.fileExists(atPath: unrelated.path))
        #expect(fm.fileExists(atPath: documentFile.path))
    }

    @Test func removeAllWithNothingThereDoesNothing() throws {
        let (home, documents, tmp) = try makeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        try FileManager.default.removeItem(at: documents.appendingPathComponent("Inbox"))
        BackupLeftovers.removeAll(documents: documents, temporary: tmp)
        #expect(FileManager.default.fileExists(atPath: documents.path))
    }
}
