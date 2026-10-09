import Foundation
import KickCore
import KickData
import OSLog
import SwiftData
import UniformTypeIdentifiers

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "backup")

extension UTType {
    /// `com.lmtiep.kickcounter.backup`, exported in `project.yml` (phase 15).
    static let lunaMomBackup = UTType(exportedAs: BackupFormat.typeIdentifier, conformingTo: .json)
}

/// A backup file to restore (phase 15 spec §4.2), opened from Profile, from
/// onboarding or from another app. RootView presents `RestoreBackupSheet` for it.
@MainActor
@Observable
final class BackupCenter {
    struct Request: Identifiable {
        let id = UUID()
        /// The file's document after `BackupValidation`, and how many records it dropped;
        /// or why the file cannot be read. A decode error never touches any data.
        let result: Result<(document: BackupDocument, skipped: Int), BackupError>
    }

    var request: Request?
    /// Changes after every successful restore, so RootView can land on Today.
    private(set) var restoreCount = 0

    /// Reads the file (security-scoped when it comes from the document picker or
    /// another app), decodes and validates it. Nothing is written.
    func open(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            open(data: try Data(contentsOf: url))
        } catch {
            logger.error("Reading a backup file failed: \(error.localizedDescription)")
            request = Request(result: .failure(.corrupt))
        }
    }

    func open(data: Data) {
        do {
            let document = try BackupCodec.decode(data)
            let cleaned = BackupValidation.clean(document, now: AppClock.now(), calendar: AppLocale.calendar)
            request = Request(result: .success((cleaned.0, cleaned.skipped)))
        } catch let error as BackupError {
            request = Request(result: .failure(error))
        } catch {
            request = Request(result: .failure(.corrupt))
        }
    }

    func didRestore() {
        request = nil
        restoreCount += 1
    }

    /// Whether `url` is a backup this app should open (`onOpenURL`).
    static func isBackupFile(_ url: URL) -> Bool {
        url.isFileURL && url.pathExtension.lowercased() == BackupFormat.fileExtension
    }

    /// Writes `LunaMom-YYYY-MM-DD.lunamom` with every record and the owned settings
    /// to a fresh temporary folder (spec §4.1).
    static func makeExportFile(container: ModelContainer, now: Date) throws -> URL {
        let document = BackupDocument(
            createdAt: now,
            appVersion: appVersion,
            records: try BackupStore.export(from: container),
            settings: BackupSettings.read(from: AppGroup.defaults)
        )
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("Backup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(BackupDocument.fileName(for: now, calendar: AppLocale.calendar))
        try BackupCodec.encode(document).write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    #if DEBUG
    /// `-uiTestingRestoreFile <name>`: the UI test passes the file's bytes in
    /// `UITEST_RESTORE_FILE_BASE64`; they are written to the app's tmp folder under
    /// that name and opened like a file from another app. Without the bytes, the
    /// path is opened as given.
    func openUITestFile(_ name: String) {
        let environment = ProcessInfo.processInfo.environment
        guard let base64 = environment["UITEST_RESTORE_FILE_BASE64"], let data = Data(base64Encoded: base64) else {
            open(URL(fileURLWithPath: name))
            return
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent((name as NSString).lastPathComponent)
        do {
            try data.write(to: url, options: .atomic)
            open(url)
        } catch {
            logger.error("Writing the UI test backup file failed: \(error.localizedDescription)")
        }
    }
    #endif
}
