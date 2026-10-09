import KickCore
import SwiftUI

/// The top of the scroll content in the sheet's scroll view: 0 at the top,
/// negative once scrolled down, positive while bouncing past the top.
private struct ArticleScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// A two-detent sheet drawn inside a screen (phase 6 spec §3.3–3.5), not a
/// native `.sheet`: a grab handle that is also a button, a fixed header and a
/// scrolling body on the card colour with 24 pt top corners.
///
/// - Dragging the handle or header moves the sheet, clamped between the detents
///   with a little rubber-banding; on release `SheetDetentResolver` picks the detent.
/// - At peek the body does not scroll and an upward drag on it moves the sheet.
/// - Expanded, the body scrolls; pulling down while it is at the top (offset ≤ 0)
///   hands the drag to the sheet.
/// - `progress` is 0 at peek and 1 expanded, for the caller's background.
/// - The spring is off under Reduce Motion and in UI tests (`LunaMotion.sheet`).
struct ArticleSheet<Header: View, Content: View>: View {
    @Binding private var detent: SheetDetent
    @Binding private var progress: Double
    private let peekTop: CGFloat
    private let expandedTop: CGFloat
    private let containerHeight: CGFloat
    private let bottomInset: CGFloat
    private let resetKey: String
    private let initialAnchor: String?
    private let handleIdentifier: String
    private let scrollIdentifier: String
    private let handleLabel: (SheetDetent) -> String
    private let header: Header
    private let content: Content
    /// True while a drag on the handle/header is moving the sheet. A Button inside
    /// `header` (e.g. a tab pill) moves with the sheet's offset, so the finger stays
    /// over it and its tap would otherwise fire on release; callers with such a
    /// Button should ignore the resulting selection change while this is true.
    @Binding private var headerDragActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The drag moving the sheet, if any (`SheetDragState`).
    @State private var drag = SheetDragState()
    /// True while a header / body drag gesture is live. Unlike `drag`, these reset
    /// on their own when a gesture is cancelled without `onEnded`.
    @GestureState private var headerGestureLive = false
    @GestureState private var bodyGestureLive = false
    @State private var scrollOffset: CGFloat = 0

    private static var topID: String { "articleSheetTop" }
    private static var scrollSpace: String { "articleSheetScroll" }

    init(
        detent: Binding<SheetDetent>,
        progress: Binding<Double>,
        peekTop: CGFloat,
        expandedTop: CGFloat,
        containerHeight: CGFloat,
        bottomInset: CGFloat,
        resetKey: String,
        initialAnchor: String?,
        handleIdentifier: String,
        scrollIdentifier: String,
        handleLabel: @escaping (SheetDetent) -> String,
        headerDragActive: Binding<Bool> = .constant(false),
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) {
        _detent = detent
        _progress = progress
        self.peekTop = peekTop
        self.expandedTop = expandedTop
        self.containerHeight = containerHeight
        self.bottomInset = bottomInset
        self.resetKey = resetKey
        self.initialAnchor = initialAnchor
        self.handleIdentifier = handleIdentifier
        self.scrollIdentifier = scrollIdentifier
        self.handleLabel = handleLabel
        _headerDragActive = headerDragActive
        self.header = header()
        self.content = content()
    }

    private var resolver: SheetDetentResolver {
        SheetDetentResolver(peekOffset: Double(peekTop), expandedOffset: Double(expandedTop))
    }

    /// The sheet's top edge now.
    private var top: CGFloat {
        CGFloat(drag.translation.map { resolver.dragOffset(from: detent, translation: $0) }
            ?? resolver.offset(for: detent))
    }

    private var gestureLive: Bool { headerGestureLive || bodyGestureLive }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                handle
                header
            }
            .contentShape(Rectangle())
            .simultaneousGesture(headerDrag)
            ScrollViewReader { reader in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: ArticleScrollOffsetKey.self,
                                value: geometry.frame(in: .named(Self.scrollSpace)).minY
                            )
                        }
                        .frame(height: 0)
                        .id(Self.topID)
                        content
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, bottomInset + 32)
                }
                .coordinateSpace(.named(Self.scrollSpace))
                .scrollDisabled(detent == .peek || drag.handoffStart != nil)
                .scrollBounceBehavior(.basedOnSize)
                .accessibilityIdentifier(scrollIdentifier)
                .simultaneousGesture(bodyDrag)
                .onPreferenceChange(ArticleScrollOffsetKey.self) { value in
                    // Preference callbacks arrive on the main thread; the closure is @Sendable.
                    MainActor.assumeIsolated { scrollOffset = value }
                }
                .onChange(of: resetKey) {
                    reader.scrollTo(Self.topID, anchor: .top)
                }
                .task(id: initialAnchor) {
                    guard let initialAnchor else { return }
                    // Once laid out; a jump rather than an animated scroll (Reduce Motion, UI tests).
                    try? await Task.sleep(for: .milliseconds(150))
                    reader.scrollTo(initialAnchor, anchor: .top)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: max(0, containerHeight - expandedTop + bottomInset), alignment: .top)
        .background(
            .luna(.cardOpaque),
            in: UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous)
        )
        .offset(y: top)
        .onAppear { progress = resolver.progress(for: detent) }
        .onChange(of: peekTop) {
            if !drag.isDragging { progress = resolver.progress(for: detent) }
        }
        .onChange(of: expandedTop) {
            if !drag.isDragging { progress = resolver.progress(for: detent) }
        }
        .onChange(of: containerHeight) {
            if !drag.isDragging { progress = resolver.progress(for: detent) }
        }
        .onChange(of: detent) {
            if !drag.isDragging { progress = resolver.progress(for: detent) }
        }
        .onChange(of: gestureLive) { _, live in
            guard !live else { return }
            // A normal release has already run `onEnded` by the next main-queue
            // turn; a cancelled gesture never does, so clear what it left behind.
            DispatchQueue.main.async { clearCancelledDrag() }
        }
    }

    /// 36×5 pt capsule in a full-width, 44 pt tall hit area; tapping toggles the
    /// detent. Not a `Button`: the sheet's `.offset` follows the finger during a
    /// drag that starts here, so the finger stays inside a Button's bounds and
    /// its tap action would fire on release, flipping the detent a second time.
    private var handle: some View {
        Capsule()
            .fill(.luna(.chevron))
            .frame(width: 36, height: 5)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
            .onTapGesture(perform: toggle)
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { toggle() }
            .accessibilityLabel(handleLabel(detent))
            .accessibilityIdentifier(handleIdentifier)
    }

    private var headerDrag: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .updating($headerGestureLive) { _, live, _ in live = true }
            .onChanged { value in
                headerDragActive = true
                move(by: value.translation.height)
            }
            .onEnded { value in
                settle(velocity: value.velocity.height)
                // Deferred: a Button inside `header` resolves its own tap gesture
                // around the same release event, and must still see this as true.
                DispatchQueue.main.async { headerDragActive = false }
            }
    }

    private var bodyDrag: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .updating($bodyGestureLive) { _, live, _ in live = true }
            .onChanged { value in
                let translation = value.translation.height
                switch detent {
                case .peek:
                    move(by: translation)
                case .expanded:
                    if drag.handoffStart == nil {
                        // Only a downward pull while the article is at its top.
                        guard scrollOffset >= -1, translation > 0 else { return }
                        drag.beginHandoff(at: Double(translation))
                    }
                    move(by: max(0, translation - CGFloat(drag.handoffStart ?? Double(translation))))
                }
            }
            .onEnded { value in
                guard drag.isDragging else {
                    drag.end()
                    return
                }
                settle(velocity: value.velocity.height)
            }
    }

    private func move(by translation: CGFloat) {
        drag.move(by: Double(translation))
        progress = resolver.progress(atOffset: Double(top))
    }

    private func settle(velocity: CGFloat) {
        let target = resolver.release(at: Double(top), velocity: Double(velocity))
        withAnimation(LunaMotion.sheet(reduceMotion: reduceMotion)) {
            detent = target
            drag.end()
            progress = resolver.progress(for: target)
        }
    }

    /// After a cancelled drag (no `onEnded`): the sheet goes back to its detent
    /// and nothing stays marked as dragging. A no-op after a normal release, and
    /// skipped if a new drag has already begun.
    private func clearCancelledDrag() {
        guard !gestureLive else { return }
        headerDragActive = false
        guard drag != SheetDragState() else { return }
        withAnimation(LunaMotion.sheet(reduceMotion: reduceMotion)) {
            drag.end()
            progress = resolver.progress(for: detent)
        }
    }

    private func toggle() {
        let target: SheetDetent = detent == .peek ? .expanded : .peek
        withAnimation(LunaMotion.sheet(reduceMotion: reduceMotion)) {
            detent = target
            progress = resolver.progress(for: target)
        }
    }
}

private struct ArticleSheetPreview: View {
    @State private var detent = SheetDetent.peek
    @State private var progress = 0.0

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Text(verbatim: "Background")
                    .font(.luna(.weekTitle))
                    .foregroundStyle(.luna(.textPrimary))
                    .opacity(1 - progress)
                    .padding(.top, 80)
                ArticleSheet(
                    detent: $detent,
                    progress: $progress,
                    peekTop: proxy.size.height * 0.5,
                    expandedTop: 8,
                    containerHeight: proxy.size.height,
                    bottomInset: proxy.safeAreaInsets.bottom,
                    resetKey: "preview",
                    initialAnchor: nil,
                    handleIdentifier: "previewHandle",
                    scrollIdentifier: "previewScroll",
                    handleLabel: { $0 == .peek ? "Expand" : "Collapse" }
                ) {
                    Text(verbatim: "Tuần 24")
                        .font(.luna(.sheetTitle))
                        .foregroundStyle(.luna(.textPrimary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                } content: {
                    ForEach(0..<30, id: \.self) { index in
                        Text(verbatim: "Đoạn \(index)")
                            .font(.luna(.articleBody))
                            .foregroundStyle(.luna(.articleText))
                            .padding(.vertical, 6)
                    }
                }
            }
        }
        .background(.luna(.heroMiddle))
    }
}

#Preview {
    ArticleSheetPreview()
}
