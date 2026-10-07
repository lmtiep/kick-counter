import KickCore
import OSLog
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "app")

@main
struct KickCounterApp: App {
    /// Hands iCloud share invitations to the app (phase 8).
    @UIApplicationDelegateAdaptor(PartnerAppDelegate.self) private var appDelegate
    private let environment: Result<AppEnvironment, Error>

    init() {
        LunaAppearance.configure()
        environment = Result { try AppEnvironment.make() }
        switch environment {
        case .success(let env):
            let coordinator = env.coordinator
            KickIntentBridge.recordKick = { _ = await coordinator.recordKick() }
        case .failure(let error):
            logger.fault("Could not open the data store: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            switch environment {
            case .success(let env):
                RootView()
                    .environment(env.coordinator)
                    .environment(env.appointments)
                    .environment(env.cycle)
                    .environment(env.weight)
                    .environment(PartnerInvitationInbox.shared)
                    .environment(\.partnerSharing, env.sharing)
                    .environment(env.partnerShare)
                    .environment(\.partnerPublisher, env.partnerPublisher)
                    .environment(\.contentLibrary, env.content)
                    .environment(\.knowledgeLibrary, env.knowledge)
                    .modelContainer(env.container)
                    .preferredColorScheme(AppEnvironment.forceDarkMode ? .dark : nil)
            case .failure:
                StoreErrorView()
            }
        }
    }
}
