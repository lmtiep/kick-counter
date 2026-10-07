import KickCore
import SwiftUI

/// The week opened from Today (fetus, "This week", baby and tips cards).
struct WeekSelection: Identifiable, Equatable {
    let week: Int
    var id: Int { week }
}

/// The week chips' bottom edge in the week detail's coordinate space.
private struct WeekChipsBottomKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Full-screen week detail, weeks 4…42 (phase 6 spec §3). The background holds
/// the ✕ button, a large fetus image and the week chips; a horizontal swipe on it
/// changes the week. The article sheet sits on top with two detents: peek (below
/// the chips) and expanded. From the symptoms safety card it opens expanded, on
/// the Mẹ tab, scrolled to "When to get care right away" (spec §3.6).
struct WeekDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.contentLibrary) private var library
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var selection: Int
    @State private var tab: ArticleTab
    @State private var detent: SheetDetent
    @State private var progress: Double
    @State private var chipsBottom: CGFloat = 0
    /// True while a drag on the sheet's handle/header is in progress (`ArticleSheet`).
    @State private var isHeaderDragging = false
    private let scrollToWarnings: Bool
    private let language = ContentLanguage.current

    private static let space = "weekDetail"
    /// The sheet's top edge when expanded: 8 pt below the top safe area (spec §3.4).
    private static let expandedTop: CGFloat = 8
    /// Room for the ✕ button above the fetus.
    private static let closeRowHeight: CGFloat = 52

    init(currentWeek: Int, scrollToWarnings: Bool = false) {
        _selection = State(initialValue: WeeklyContentLibrary.clampedWeek(currentWeek))
        _tab = State(initialValue: scrollToWarnings ? .mom : .baby)
        _detent = State(initialValue: scrollToWarnings ? .expanded : .peek)
        _progress = State(initialValue: scrollToWarnings ? 1 : 0)
        self.scrollToWarnings = scrollToWarnings
    }

    private var display: WeekDisplay? {
        library?.display(forWeek: selection, visibility: BuildFlags.contentVisibility)
    }

    /// Chips' bottom + 12 pt (spec §3.4); 55 % of the height until measured;
    /// never so low that the handle, title and tabs leave the screen.
    private static func peekTop(chipsBottom: CGFloat, height: CGFloat) -> CGFloat {
        let measured = chipsBottom > 0 ? chipsBottom + 12 : height * 0.55
        return min(measured, height - 220)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                backgroundLayer(height: proxy.size.height)
                ArticleSheet(
                    detent: $detent,
                    progress: $progress,
                    peekTop: Self.peekTop(chipsBottom: chipsBottom, height: proxy.size.height),
                    expandedTop: Self.expandedTop,
                    containerHeight: proxy.size.height,
                    bottomInset: proxy.safeAreaInsets.bottom,
                    resetKey: "\(selection)-\(tab.rawValue)",
                    initialAnchor: scrollToWarnings ? WeekArticleView.warningsAnchor : nil,
                    handleIdentifier: "weekSheetHandle",
                    scrollIdentifier: "weekArticleScroll",
                    handleLabel: { $0 == .peek ? L10n.weekArticleExpand : L10n.weekArticleCollapse },
                    headerDragActive: $isHeaderDragging
                ) {
                    sheetHeader
                } content: {
                    sheetContent
                }
                closeButton
            }
            .coordinateSpace(.named(Self.space))
            .onPreferenceChange(WeekChipsBottomKey.self) { value in
                MainActor.assumeIsolated { chipsBottom = value }
            }
        }
        .background {
            LinearGradient(
                stops: [
                    .init(color: .luna(.heroTop), location: 0),
                    .init(color: .luna(.heroMiddle), location: 0.45),
                    .init(color: .luna(.background), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        // VoiceOver two-finger scrub closes the cover, like the ✕ button.
        .accessibilityAction(.escape) { dismiss() }
        .onAppear {
            // Accessibility text sizes and VoiceOver open expanded (spec §3.4):
            // at peek the body does not scroll, so VoiceOver could not reach it.
            if (dynamicTypeSize.isAccessibilitySize || voiceOverEnabled), detent == .peek {
                detent = .expanded
                progress = 1
            }
        }
    }

    // MARK: Background

    private func backgroundLayer(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Color.clear.frame(height: Self.closeRowHeight)
                WeekArtwork.fetus(selection)
                    .resizable()
                    .scaledToFit()
                    .padding(28)
                    .background(
                        RadialGradient(
                            colors: [Color.luna(.card).opacity(0.7), Color.luna(.card).opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150
                        )
                        .clipShape(Circle())
                    )
                    .frame(height: min(height * 0.36, 320))
                    .frame(maxWidth: .infinity)
                    .opacity(1 - progress)
                    .scaleEffect(reduceMotion ? 1 : 1 - 0.1 * progress)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            // The week swipe stays on the fetus/hero area, not the chips below it.
            .gesture(
                DragGesture(minimumDistance: 30).onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) * 2 else { return }
                    changeWeek(by: value.translation.width < 0 ? 1 : -1)
                }
            )
            ChipScroller(
                values: Array(WeeklyContentLibrary.weekRange),
                selection: $selection,
                title: { L10n.weekChip($0) },
                identifier: { "weekChip-\($0)" },
                accessibilityTitle: { L10n.weekTitle($0) }
            )
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(key: WeekChipsBottomKey.self, value: geometry.frame(in: .named(Self.space)).maxY)
                }
            }
            .opacity(1 - progress)
            .padding(.top, 8)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Under the expanded sheet, VoiceOver must not reach the chips.
        .accessibilityHidden(detent == .expanded)
    }

    private var closeButton: some View {
        ArticleCloseButton(identifier: "weekDetailClose") { dismiss() }
    }

    // MARK: Sheet

    private var sheetHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.weekTitle(selection))
                .font(.luna(.sheetTitle))
                .foregroundStyle(.luna(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("weekDetailTitle")
            if case .content(_, let pendingReview)? = display {
                ArticleReviewerRow(pendingReview: pendingReview, reviewedText: L10n.weekReviewed, identifier: "weekReviewer")
                SegmentedPill(
                    options: [
                        SegmentedOption(value: ArticleTab.baby, title: L10n.weekArticleTabBaby, identifier: "weekTab-baby"),
                        SegmentedOption(value: ArticleTab.mom, title: L10n.weekArticleTabMom, identifier: "weekTab-mom"),
                    ],
                    // The pill sits inside the sheet's draggable header (spec §3), so a
                    // drag that starts on a segment also moves the sheet; the segment's
                    // Button then sees a tap on release too (it moved with the sheet, so
                    // the finger never left its bounds). Ignore that tap's selection
                    // while `isHeaderDragging` is true; a plain tap still goes through,
                    // since the drag gesture never reports itself as active for it.
                    selection: Binding(
                        get: { tab },
                        set: { newValue in
                            guard !isHeaderDragging else { return }
                            tab = newValue
                        }
                    )
                )
                .padding(.top, 14)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.bottom, 14)
    }

    /// Cross-fades over 0.2 s when the week changes; instant under Reduce Motion or in UI tests.
    private var sheetContent: some View {
        ZStack(alignment: .topLeading) {
            Group {
                switch display {
                case .content(let content, _)?:
                    WeekArticleView(content: content, tab: tab, sources: library?.sources ?? [], language: language)
                case .underReview?:
                    UnderReviewCard()
                case nil:
                    EmptyView()
                }
            }
            .id(selection)
            .transition(.opacity)
        }
        .animation(LunaMotion.isEnabled && !reduceMotion ? LunaMotion.fade : nil, value: selection)
    }

    private func changeWeek(by offset: Int) {
        let week = selection + offset
        guard WeeklyContentLibrary.weekRange.contains(week) else { return }
        selection = week
    }
}
