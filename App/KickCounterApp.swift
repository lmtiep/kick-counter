import OSLog
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "app")

@main
struct KickCounterApp: App {
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
                    .environment(\.contentLibrary, env.content)
                    .modelContainer(env.container)
                    .preferredColorScheme(AppEnvironment.forceDarkMode ? .dark : nil)
            case .failure:
                StoreErrorView()
            }
        }
    }
}
