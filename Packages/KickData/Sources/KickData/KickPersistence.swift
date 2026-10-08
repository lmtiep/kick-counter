import Foundation
import KickCore
import SwiftData

public enum KickPersistence {
    public static let schema = Schema([
        KickSession.self, Kick.self, Appointment.self, PeriodEntry.self, CycleLog.self, WeightEntry.self,
    ])

    /// On-device store in the App Group. It is mirrored to the user's private iCloud
    /// database only when `AppFeatures.cloudSync` is on (and the CloudKit entitlement is
    /// present and the user is signed in). Version 1.0 keeps it off (App Review 5.1.3(ii)):
    /// the store, its path and its schema are unchanged, so existing data stays on the
    /// device, and records already in iCloud are neither read nor deleted.
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(
                schema: schema,
                groupContainer: .identifier(AppGroup.identifier),
                cloudKitDatabase: AppFeatures.cloudSync ? .automatic : .none
            )
        }
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
