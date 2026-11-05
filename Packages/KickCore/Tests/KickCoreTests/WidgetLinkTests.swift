import Foundation
import Testing
@testable import KickCore

struct WidgetLinkTests {
    @Test func roundTrips() {
        for link in WidgetLink.allCases { #expect(WidgetLink(url: link.url) == link) }
        #expect(WidgetLink.kicks.url.absoluteString == "lunamom://kicks")
    }

    @Test func rejectsOtherURLs() {
        #expect(WidgetLink(url: URL(string: "https://today")!) == nil)
        #expect(WidgetLink(url: URL(string: "lunamom://profile")!) == nil)
        #expect(WidgetLink(url: URL(string: "lunamom://today/extra")!) == nil)
        #expect(WidgetLink(url: URL(string: "lunamom://today?x=1")!) == nil)
        #expect(WidgetLink(url: URL(fileURLWithPath: "/tmp/backup.lunamom")) == nil)
    }
}
