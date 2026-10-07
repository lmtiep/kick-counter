import CloudKit
import KickCore
import OSLog
import UIKit

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "partner-share")

/// Shows `UICloudSharingController` for the mother's saved share (phase 8 spec
/// §5.1), presented from the top-most view controller of the active window.
/// Read-only and private only: the partner can never edit, and the link works
/// only for the people she invites.
@MainActor
enum CloudSharingPresenter {
    /// UIKit holds the controller's delegate weakly.
    private static var delegate: CloudSharingDelegate?

    /// Returns false when `handle` carries no CloudKit share (the UI-test fake)
    /// or no window can present it; nothing is shown then.
    @discardableResult
    static func present(
        _ handle: PartnerShareHandle,
        onChange: @escaping @MainActor () -> Void,
        onStop: @escaping @MainActor () -> Void
    ) -> Bool {
        guard let box = handle.payload as? CloudShareBox, let presenter = topViewController() else { return false }
        let controller = UICloudSharingController(share: box.share, container: box.container)
        // Never `.allowPublic` or `.allowReadWrite`.
        controller.availablePermissions = [.allowReadOnly, .allowPrivate]
        let delegate = CloudSharingDelegate(onChange: onChange, onStop: onStop)
        controller.delegate = delegate
        self.delegate = delegate
        presenter.present(controller, animated: LunaMotion.isEnabled)
        return true
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

private final class CloudSharingDelegate: NSObject, UICloudSharingControllerDelegate {
    private let onChange: @MainActor () -> Void
    private let onStop: @MainActor () -> Void

    init(onChange: @escaping @MainActor () -> Void, onStop: @escaping @MainActor () -> Void) {
        self.onChange = onChange
        self.onStop = onStop
    }

    func itemTitle(for csc: UICloudSharingController) -> String? {
        L10n.appName
    }

    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        logger.error("Saving the share failed: \(error.localizedDescription)")
        onChange()
    }

    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        onChange()
    }

    /// The controller deleted only the `CKShare`; `onStop` must call
    /// `stopSharing()` so the zone, with the snapshot, is deleted too.
    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
        onStop()
    }
}
