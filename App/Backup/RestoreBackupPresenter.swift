import KickCore
import SwiftUI
import UIKit

/// Presents `RestoreBackupSheet` from the top-most view controller (phase 15 final
/// review). A SwiftUI `.sheet` on RootView cannot appear while another sheet, a
/// cover or an alert is up, and a backup file can be opened from another app at
/// any moment; presenting over whatever is on top always works. A presentation
/// that is still animating is waited for.
@MainActor
final class RestoreBackupPresenter: NSObject, UIAdaptivePresentationControllerDelegate {
    static let shared = RestoreBackupPresenter()

    private weak var controller: UIHostingController<AnyView>?
    private var onSwipeDown: (() -> Void)?

    /// Shows `content`, or swaps it into the sheet already shown. `style` is
    /// `.light` over onboarding (phase 18: onboarding is light only).
    func present(_ content: AnyView, style: UIUserInterfaceStyle, onSwipeDown: @escaping () -> Void) async {
        self.onSwipeDown = onSwipeDown
        if let controller, controller.presentingViewController != nil {
            controller.rootView = content
            controller.overrideUserInterfaceStyle = style
            return
        }
        // Up to 10 s for an appearing cover or a closing sheet to settle.
        for _ in 0..<40 {
            if let top = UIApplication.shared.topViewController,
               !top.isBeingPresented, !top.isBeingDismissed, top.transitionCoordinator == nil {
                let controller = UIHostingController(rootView: content)
                controller.modalPresentationStyle = .pageSheet
                controller.view.backgroundColor = .luna(.background)
                controller.overrideUserInterfaceStyle = style
                if let sheet = controller.sheetPresentationController {
                    sheet.detents = [.large()]
                    sheet.preferredCornerRadius = 28
                    sheet.prefersGrabberVisible = false
                }
                controller.presentationController?.delegate = self
                top.present(controller, animated: true)
                self.controller = controller
                return
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
    }

    func dismiss() {
        guard let controller, controller.presentingViewController != nil else { return }
        controller.dismiss(animated: true)
        self.controller = nil
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        controller = nil
        onSwipeDown?()
    }
}
