import KickCore
import UIKit

extension UIApplication {
    /// The view controller on top of the key window: a sheet or cover when one is up.
    @MainActor
    var topViewController: UIViewController? {
        let scenes = connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.first?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}

/// Presents the system share sheet for the backup file. `ShareLink` needs the file
/// before the tap, and does not say whether the file was shared; this does, so
/// "Last backup" is only recorded after a share that completed (spec §4.1).
@MainActor
enum BackupSharePresenter {
    static func present(_ url: URL, completion: @escaping @MainActor (_ completed: Bool) -> Void) {
        // The file holds unencrypted health data: it is only kept while the sheet is open.
        let folder = url.deletingLastPathComponent()
        guard let presenter = UIApplication.shared.topViewController else {
            try? FileManager.default.removeItem(at: folder)
            completion(false)
            return
        }
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.view.accessibilityIdentifier = "backupShareSheet"
        controller.popoverPresentationController?.sourceView = presenter.view
        controller.completionWithItemsHandler = { _, completed, _, _ in
            try? FileManager.default.removeItem(at: folder)
            Task { @MainActor in completion(completed) }
        }
        presenter.present(controller, animated: true)
    }
}
