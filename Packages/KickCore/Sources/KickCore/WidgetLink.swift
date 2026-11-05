import Foundation

/// Where a tap on the widget goes: `lunamom://today`, or `lunamom://kicks` for the
/// kick line. Nothing else is accepted, and no data travels in the URL.
public enum WidgetLink: String, Sendable, CaseIterable {
    case today
    case kicks

    public static let scheme = "lunamom"

    public var url: URL { URL(string: "\(Self.scheme)://\(rawValue)")! }

    public init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme,
              url.path.isEmpty || url.path == "/",
              url.query == nil,
              let host = url.host(), let link = WidgetLink(rawValue: host.lowercased())
        else { return nil }
        self = link
    }
}
