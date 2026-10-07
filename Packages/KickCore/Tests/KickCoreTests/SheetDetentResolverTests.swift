import Testing
@testable import KickCore

/// Phase 6 spec §3.4–3.5: where the article sheet rests and goes on release.
/// Offsets are the sheet's top edge from the top of the safe area (larger = lower).
struct SheetDetentResolverTests {
    let resolver = SheetDetentResolver(peekOffset: 400, expandedOffset: 8)

    @Test func offsetsForDetents() {
        #expect(resolver.offset(for: .peek) == 400)
        #expect(resolver.offset(for: .expanded) == 8)
        #expect(resolver.span == 392)
    }

    @Test func slowReleaseGoesToTheNearestDetent() {
        #expect(resolver.release(at: 150, velocity: 0) == .expanded)
        #expect(resolver.release(at: 300, velocity: 200) == .peek)
        #expect(resolver.release(at: 204, velocity: 0) == .expanded) // exactly halfway
    }

    @Test func fastFlickUpExpandsEvenNearPeek() {
        #expect(resolver.release(at: 390, velocity: -800) == .expanded)
    }

    @Test func fastFlickDownCollapsesEvenNearExpanded() {
        #expect(resolver.release(at: 20, velocity: 900) == .peek)
    }

    @Test func aSpeedOfExactly600IsNotAFlick() {
        #expect(resolver.release(at: 390, velocity: -600) == .peek)
        #expect(resolver.release(at: 20, velocity: 600) == .expanded)
    }

    @Test func dragIsClampedWithALittleRubberBanding() {
        #expect(resolver.dragOffset(from: .peek, translation: -100) == 300)
        #expect(resolver.dragOffset(from: .expanded, translation: -100) == -17) // 8 − 100 × 0.25
        #expect(resolver.dragOffset(from: .expanded, translation: -400) == -22) // capped at 30
        #expect(resolver.dragOffset(from: .peek, translation: 40) == 410)
        #expect(resolver.dragOffset(from: .expanded, translation: 600) == 430)
    }

    @Test func progressRunsFromPeekToExpanded() {
        #expect(resolver.progress(atOffset: 400) == 0)
        #expect(resolver.progress(atOffset: 8) == 1)
        #expect(resolver.progress(atOffset: 204) == 0.5)
        #expect(resolver.progress(atOffset: -17) == 1)
        #expect(resolver.progress(atOffset: 410) == 0)
        #expect(resolver.progress(for: .peek) == 0)
        #expect(resolver.progress(for: .expanded) == 1)
    }

    /// When the chips reach the top (huge text), there is no room to peek.
    @Test func noRoomToPeekStaysExpanded() {
        let tight = SheetDetentResolver(peekOffset: 5, expandedOffset: 8)
        #expect(tight.peekOffset == 8)
        #expect(tight.release(at: 8, velocity: 900) == .expanded)
        #expect(tight.progress(for: .peek) == 1)
    }
}
