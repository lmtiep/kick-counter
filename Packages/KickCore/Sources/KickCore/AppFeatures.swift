/// Compile-time feature switches.
public enum AppFeatures {
    /// iCloud mirroring of the SwiftData store and partner sharing (CloudKit).
    ///
    /// Off for version 1.0: App Review Guideline 5.1.3(ii) says apps "may not store
    /// personal health information in iCloud", so every record stays on the device
    /// (the App Group store and the user's iPhone backup). The CloudKit code is kept,
    /// behind this switch, and the partner mode is hidden while it is off.
    ///
    /// Turning it on is a deliberate change that must also restore, together:
    /// - the `aps-environment`, `com.apple.developer.icloud-container-identifiers` and
    ///   `com.apple.developer.icloud-services` entitlements (`project.yml`);
    /// - the Info keys `UIBackgroundModes: [remote-notification]` and `CKSharingSupported`;
    /// - the CloudKit Production schema;
    /// - an updated privacy policy (published before the release), and the guard test
    ///   `AppFeaturesTests.cloudSyncIsOffForVersion1`.
    /// See "Giai đoạn 12" in `docs/release-checklist.md`.
    public static let cloudSync = false
}
