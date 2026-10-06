import Foundation
import KickCore
import SwiftData

public enum KickPersistence {
    public static let schema = Schema([
        KickSession.self, Kick.self, Appointment.self, PeriodEntry.self, CycleLog.self, WeightEntry.self,
    ])

    /// On-device store in the App Group, mirrored to the user's private iCloud
    /// database when the CloudKit entitlement is present and the user is signed in.
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(
                schema: schema,
                groupContainer: .identifier(AppGroup.identifier),
                cloudKitDatabase: .automatic
            )
        }
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
