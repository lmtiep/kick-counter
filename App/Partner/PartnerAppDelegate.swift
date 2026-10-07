import CloudKit
import KickCore
import OSLog
import UIKit

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "partner-invitation")

extension PartnerInvitationInbox {
    /// The one inbox: the scene delegate fills it, `RootView` empties it.
    static let shared = PartnerInvitationInbox()
}

extension Notification.Name {
    /// A silent push from the partner's shared-database subscription arrived.
    static let partnerSnapshotChanged = Notification.Name("partnerSnapshotChanged")
}

/// Connects a scene delegate to the SwiftUI app so iCloud share invitations
/// reach it (phase 8 spec §4.2), and forwards the partner's silent pushes.
final class PartnerAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = PartnerSceneDelegate.self
        return configuration
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo),
              notification.subscriptionID == CloudPartnerSharing.subscriptionID
        else { return .noData }
        NotificationCenter.default.post(name: .partnerSnapshotChanged, object: nil)
        return .newData
    }
}

/// Receives the share metadata when the partner taps the invitation: as a
/// connection option when the tap launches the app, through
/// `windowScene(_:userDidAcceptCloudKitShareWith:)` when it is running.
final class PartnerSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let metadata = connectionOptions.cloudKitShareMetadata {
            receive(metadata)
        }
    }

    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        receive(cloudKitShareMetadata)
    }

    private func receive(_ metadata: CKShare.Metadata) {
        logger.info("Received a partner invitation")
        PartnerInvitationInbox.shared.receive(PartnerInvitation(payload: CloudInvitationBox(metadata: metadata)))
    }
}
