import Foundation

/// Copies of backup files inside the app (phase 15 final review). A backup holds
/// unencrypted health data, so none may stay behind: not the copy iOS puts in
/// `Documents/Inbox` when a `.lunamom` file is opened from another app, nor the
/// export written to `tmp/Backup-…` for the share sheet.
public enum BackupLeftovers {
    /// `tmp/Backup-<uuid>/LunaMom-….lunamom`, made for one share.
    public static let exportFolderPrefix = "Backup-"

    /// Whether `url` is a file inside `directory` (the app's home): such a file is
    /// the app's own copy and is deleted once read. A file the user picked
    /// elsewhere (Files, iCloud Drive) is never inside it.
    public static func isInside(_ url: URL, directory: URL) -> Bool {
        guard url.isFileURL else { return false }
        let file = url.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        let folder = directory.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        return file.count > folder.count && Array(file.prefix(folder.count)) == folder
    }

    /// Removes `Documents/Inbox`, every `tmp/Backup-…` folder and every
    /// `.lunamom` file directly in `tmp`. Anything else is left alone.
    public static func removeAll(documents: URL, temporary: URL, fileManager: FileManager = .default) {
        try? fileManager.removeItem(at: documents.appendingPathComponent("Inbox", isDirectory: true))
        let items = (try? fileManager.contentsOfDirectory(at: temporary, includingPropertiesForKeys: nil)) ?? []
        for item in items where item.lastPathComponent.hasPrefix(exportFolderPrefix)
            || item.pathExtension.lowercased() == BackupFormat.fileExtension {
            try? fileManager.removeItem(at: item)
        }
    }
}
