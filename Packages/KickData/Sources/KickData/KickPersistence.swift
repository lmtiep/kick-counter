import Foundation
import KickCore
import SwiftData

public enum KickPersistence {
    public static let schema = Schema([
        KickSession.self, Kick.self, Appointment.self, PeriodEntry.self, CycleLog.self, WeightEntry.self, PillDose.self, Contraction.self,
        ChecklistItem.self,
    ])

    /// The one place the store's configuration is built (the app and the widget both use it):
    /// the App Group store, or the store at `url` (tests). `readOnly` (the widget) refuses
    /// every save and never mirrors to iCloud; otherwise it is mirrored to the user's private
    /// iCloud database only when `AppFeatures.cloudSync` is on (and the CloudKit entitlement
    /// is present and the user is signed in). Version 1.0 keeps it off (App Review 5.1.3(ii)):
    /// the store, its path and its schema are unchanged, so existing data stays on the
    /// device, and records already in iCloud are neither read nor deleted.
    public static func configuration(readOnly: Bool = false, url: URL? = nil) -> ModelConfiguration {
        let cloudKit: ModelConfiguration.CloudKitDatabase = !readOnly && AppFeatures.cloudSync ? .automatic : .none
        if let url {
            return ModelConfiguration(schema: schema, url: url, allowsSave: !readOnly, cloudKitDatabase: cloudKit)
        }
        return ModelConfiguration(
            schema: schema,
            allowsSave: !readOnly,
            groupContainer: .identifier(AppGroup.identifier),
            cloudKitDatabase: cloudKit
        )
    }

    public static func makeContainer(inMemory: Bool = false, readOnly: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let configuration = inMemory
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            : Self.configuration(readOnly: readOnly, url: url)
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
