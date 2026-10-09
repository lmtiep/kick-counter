import UIKit

/// Presents the system share sheet for the backup file. `ShareLink` needs the file
/// before the tap, and does not say whether the file was shared; this does, so
/// "Last backup" is only recorded after a share that completed (spec §4.1).
@MainActor
enum BackupSharePresenter {
    static func present(_ url: URL, completion: @escaping @MainActor (_ completed: Bool) -> Void) {
        guard let presenter = topViewController() else {
            completion(false)
            return
        }
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.view.accessibilityIdentifier = "backupShareSheet"
        controller.popoverPresentationController?.sourceView = presenter.view
        controller.completionWithItemsHandler = { _, completed, _, _ in
            // The file is only needed while the sheet is open.
            try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
            Task { @MainActor in completion(completed) }
        }
        presenter.present(controller, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.first?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}
