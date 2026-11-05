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
        let content: Content
    }

    enum Content {
        /// The file's document after `BackupValidation`, and how many records it dropped.
        case ready(document: BackupDocument, skipped: Int)
        /// A password-protected file (1.1), kept in memory only until it is opened
        /// or the sheet closes; nothing in it has been read yet.
        case locked(Data)
        /// Why the file cannot be read. A decode error never touches any data.
        case failed(BackupError)
    }

    enum UnlockResult: Equatable {
        case opened
        case wrongPassword
    }

    var request: Request?
    /// Changes after every successful restore, so RootView can land on Today.
    private(set) var restoreCount = 0

    /// Reads the file (security-scoped when it comes from the document picker),
    /// decodes and validates it; no app data is written. A copy inside the app
    /// (`Documents/Inbox`, where iOS puts a file opened from another app, or tmp)
    /// is deleted once read: it holds unencrypted health data.
    func open(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
            if BackupLeftovers.isInside(url, directory: URL(fileURLWithPath: NSHomeDirectory())) {
                try? FileManager.default.removeItem(at: url)
            }
        }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            // A sealed file is the JSON plus a header and a tag.
            guard size <= BackupCodec.maxFileSize + BackupEncryption.headerLength + BackupEncryption.tagLength else {
                request = Request(content: .failed(.corrupt))
                return
            }
            open(data: try Data(contentsOf: url))
        } catch {
            logger.error("Reading a backup file failed: \(error.localizedDescription)")
            request = Request(content: .failed(.corrupt))
        }
    }

    func open(data: Data) {
        if BackupEncryption.isEncrypted(data) {
            // Only the header is read here; a file this build cannot open says so now.
            do {
                _ = try BackupEncryption.parameters(of: data)
                request = Request(content: .locked(data))
            } catch BackupEncryptionError.unsupportedVersion(let version) where version > BackupEncryption.formatVersion {
                request = Request(content: .failed(.newerVersion(Int(version))))
            } catch {
                request = Request(content: .failed(.corrupt))
            }
            return
        }
        decode(data)
    }

    /// Opens a password-protected file. A wrong password (or a damaged file: AES-GCM
    /// cannot tell them apart) changes nothing and the sheet asks again; otherwise
    /// the decrypted JSON goes through the same decoding and validation as a plain
    /// file. The key derivation runs off the main actor. The password is not kept.
    func unlock(_ data: Data, password: String) async -> UnlockResult {
        let requestID = request?.id
        let opened = await Task.detached(priority: .userInitiated) { () -> Result<Data, BackupEncryptionError> in
            do {
                return .success(try BackupEncryption.open(data, password: password))
            } catch let error as BackupEncryptionError {
                return .failure(error)
            } catch {
                return .failure(.wrongPassword)
            }
        }.value
        // Another file was opened meanwhile: this result belongs to a request that is gone.
        guard request?.id == requestID else { return .opened }
        switch opened {
        case .success(let json):
            decode(json)
            return .opened
        case .failure(.wrongPassword):
            logger.info("A protected backup did not open: wrong password or damaged file")
            return .wrongPassword
        case .failure:
            request = Request(content: .failed(.corrupt))
            return .opened
        }
    }

    private func decode(_ data: Data) {
        do {
            let document = try BackupCodec.decode(data)
            let cleaned = BackupValidation.clean(document, now: AppClock.now(), calendar: AppLocale.calendar)
            request = Request(content: .ready(document: cleaned.0, skipped: cleaned.skipped))
        } catch let error as BackupError {
            request = Request(content: .failed(error))
        } catch {
            request = Request(content: .failed(.corrupt))
        }
    }

    func didRestore() {
        request = nil
        restoreCount += 1
    }

    /// Deletes every backup copy inside the app (`BackupLeftovers`): after "Xoá toàn
    /// bộ dữ liệu" and after a restore.
    static func removeLeftovers() {
        let fileManager = FileManager.default
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        BackupLeftovers.removeAll(documents: documents, temporary: fileManager.temporaryDirectory)
    }

    /// Remembers the first day the app is used, for the backup reminder (1.1).
    static func recordUse() {
        BackupReminderStore.recordUse(in: AppGroup.defaults, now: AppClock.now())
    }

    /// Whether `url` is a backup this app should open (`onOpenURL`).
    static func isBackupFile(_ url: URL) -> Bool {
        url.isFileURL && url.pathExtension.lowercased() == BackupFormat.fileExtension
    }

    /// Writes `LunaMom-YYYY-MM-DD.lunamom` with every record and the owned settings
    /// to a fresh temporary folder (spec §4.1). With a password (1.1) the JSON is
    /// sealed by `BackupEncryption` off the main actor and only the sealed bytes
    /// are written; the password is used for this call only and never stored.
    static func makeExportFile(container: ModelContainer, now: Date, password: String?) async throws -> URL {
        let document = BackupDocument(
            createdAt: now,
            appVersion: appVersion,
            records: try BackupStore.export(from: container),
            settings: BackupSettings.read(from: AppGroup.defaults)
        )
        var bytes = try BackupCodec.encode(document)
        if let password {
            let plain = bytes
            bytes = try await Task.detached(priority: .userInitiated) {
                try BackupEncryption.seal(plain, password: password)
            }.value
        }
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(BackupLeftovers.exportFolderPrefix)\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(BackupDocument.fileName(for: now, calendar: AppLocale.calendar))
        do {
            try bytes.write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
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
