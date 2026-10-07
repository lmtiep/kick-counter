import KickCore
import SwiftUI

private struct ContentLibraryKey: EnvironmentKey {
    static let defaultValue: WeeklyContentLibrary? = nil
}

private struct KnowledgeLibraryKey: EnvironmentKey {
    static let defaultValue: KnowledgeLibrary? = nil
}

private struct PartnerSharingKey: EnvironmentKey {
    static let defaultValue: any PartnerSharing = FakePartnerSharing()
}

private struct PartnerPublisherKey: EnvironmentKey {
    static let defaultValue: PartnerPublisher? = nil
}

extension EnvironmentValues {
    /// The bundled week-by-week content; nil if it failed to load (cards are hidden).
    var contentLibrary: WeeklyContentLibrary? {
        get { self[ContentLibraryKey.self] }
        set { self[ContentLibraryKey.self] = newValue }
    }

    /// The bundled knowledge articles; nil if they failed to load (card and library hidden).
    var knowledgeLibrary: KnowledgeLibrary? {
        get { self[KnowledgeLibraryKey.self] }
        set { self[KnowledgeLibraryKey.self] = newValue }
    }

    /// iCloud partner sharing (phase 8): CloudKit in the app, the fake in UI tests and previews.
    var partnerSharing: any PartnerSharing {
        get { self[PartnerSharingKey.self] }
        set { self[PartnerSharingKey.self] = newValue }
    }

    /// Uploads the mother's snapshot while she shares (phase 8); nil in previews.
    var partnerPublisher: PartnerPublisher? {
        get { self[PartnerPublisherKey.self] }
        set { self[PartnerPublisherKey.self] = newValue }
    }
}

enum BuildFlags {
    /// Debug and TestFlight builds (`CONTENT_PREVIEW`, set by testflight.yml through
    /// release.sh) show all content with a "pending review" label; App Store builds
    /// show only content an obstetrician has marked `reviewed`.
    static var contentVisibility: ContentVisibility {
        #if DEBUG || CONTENT_PREVIEW
        return .all
        #else
        return .reviewedOnly
        #endif
    }
}
