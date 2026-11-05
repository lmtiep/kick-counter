import KickCore
import MessageUI
import SwiftUI
import UIKit

/// The "Gửi góp ý" email as this phone would send it: the subject, an empty line for the
/// message and a few technical facts. Never any health data.
@MainActor
enum FeedbackContent {
    static func email(mode: FeedbackMode) -> FeedbackEmail {
        let info = Bundle.main.infoDictionary
        return FeedbackEmail(
            subject: L10n.feedbackSubject,
            labels: .init(
                app: L10n.feedbackLabelApp,
                ios: L10n.feedbackLabelIOS,
                device: L10n.feedbackLabelDevice,
                language: L10n.feedbackLabelLanguage,
                mode: L10n.feedbackLabelMode
            ),
            facts: .init(
                appVersion: info?["CFBundleShortVersionString"] as? String ?? "—",
                build: info?["CFBundleVersion"] as? String ?? "—",
                iOSVersion: UIDevice.current.systemVersion,
                deviceModel: deviceModel,
                language: AppLocale.language.rawValue,
                mode: modeName(mode)
            )
        )
    }

    private static func modeName(_ mode: FeedbackMode) -> String {
        switch mode {
        case .cycleTracking: L10n.feedbackModeTracking
        case .tryingToConceive: L10n.feedbackModeConceiving
        case .pregnant: L10n.feedbackModePregnant
        case .partner: L10n.feedbackModePartner
        }
    }

    /// e.g. `iPhone17,1`.
    private static var deviceModel: String {
        var system = utsname()
        uname(&system)
        let machine = withUnsafeBytes(of: &system.machine) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
        return FeedbackEmail.modelIdentifier(
            machine: machine,
            simulatorModel: ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"]
        )
    }
}

/// The system mail composer. It only opens a draft: nothing is sent unless the user taps Send.
struct MailComposeView: UIViewControllerRepresentable {
    let email: FeedbackEmail
    let onFinish: () -> Void

    static var canSendMail: Bool { MFMailComposeViewController.canSendMail() }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients([FeedbackEmail.address])
        controller.setSubject(email.subject)
        controller.setMessageBody(email.body, isHTML: false)
        return controller
    }

    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            onFinish()
        }
    }
}
