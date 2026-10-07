import Foundation

/// The two rest positions of the week article sheet (phase 6 spec §3.4).
public enum SheetDetent: Sendable, Equatable, CaseIterable {
    /// Top edge just below the week chips: handle, title, tabs and lead visible.
    case peek
    /// Top edge 8 pt below the top safe area.
    case expanded
}

/// Pure drag and release rules of the article sheet (phase 6 spec §3.5).
/// Offsets are the sheet's top edge in points from the top of the safe area;
/// larger values are lower on screen. Velocities are points per second,
/// positive downwards (SwiftUI's `DragGesture.Value.velocity.height`).
public struct SheetDetentResolver: Sendable, Equatable {
    /// A release faster than this goes to the detent in the direction of travel.
    public static let flickSpeed: Double = 600
    /// Past a detent the sheet moves a quarter of the finger's distance…
    public static let rubberBandFactor: Double = 0.25
    /// …and never more than this many points.
    public static let rubberBandLimit: Double = 30

    public let peekOffset: Double
    public let expandedOffset: Double

    /// A peek offset above the expanded one (no room) is raised to it.
    public init(peekOffset: Double, expandedOffset: Double) {
        self.expandedOffset = expandedOffset
        self.peekOffset = max(peekOffset, expandedOffset)
    }

    public var span: Double { peekOffset - expandedOffset }

    public func offset(for detent: SheetDetent) -> Double {
        detent == .peek ? peekOffset : expandedOffset
    }

    /// Where the top edge is while dragging `translation` points from `detent`:
    /// clamped between the detents, with a little rubber-banding past them.
    public func dragOffset(from detent: SheetDetent, translation: Double) -> Double {
        let raw = offset(for: detent) + translation
        if raw < expandedOffset { return expandedOffset - rubberBand(expandedOffset - raw) }
        if raw > peekOffset { return peekOffset + rubberBand(raw - peekOffset) }
        return raw
    }

    /// 0 at peek, 1 at expanded, clamped; 1 when there is no room to peek.
    public func progress(atOffset offset: Double) -> Double {
        guard span >= 1 else { return 1 }
        return min(max((peekOffset - offset) / span, 0), 1)
    }

    public func progress(for detent: SheetDetent) -> Double {
        progress(atOffset: offset(for: detent))
    }

    /// The detent after a release at `offset`: a flick (faster than 600 pt/s)
    /// goes in its direction, otherwise the nearest detent (expanded on a tie).
    public func release(at offset: Double, velocity: Double) -> SheetDetent {
        guard span >= 1 else { return .expanded }
        if velocity < -Self.flickSpeed { return .expanded }
        if velocity > Self.flickSpeed { return .peek }
        return offset - expandedOffset <= peekOffset - offset ? .expanded : .peek
    }

    private func rubberBand(_ distance: Double) -> Double {
        min(distance * Self.rubberBandFactor, Self.rubberBandLimit)
    }
}
