import KickCore
import SwiftUI

// The reading pieces shared by the week article (phase 6) and the knowledge
// articles (phase 7 spec §4.3), so both use the same typography.

/// A section heading (headline style, header trait).
struct ArticleHeading: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.luna(.cardTitle))
            .foregroundStyle(.luna(.textPrimary))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 22)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Body paragraphs, line spacing 4.
struct ArticleParagraphs: View {
    let paragraphs: [String]

    init(_ paragraphs: [String]) {
        self.paragraphs = paragraphs
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(.luna(.articleBody))
                    .lineSpacing(4)
                    .foregroundStyle(.luna(.articleText))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 8)
    }
}

/// "References", collapsed until tapped; nothing when `sources` is empty.
struct ArticleReferences: View {
    let sources: [String]
    let identifier: String

    var body: some View {
        if !sources.isEmpty {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(sources, id: \.self) { source in
                        Text(verbatim: source)
                            .font(.luna(.small))
                            .foregroundStyle(.luna(.textSecondary))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
            } label: {
                Text(L10n.weekArticleReferences)
                    .font(.luna(.captionStrong))
                    .foregroundStyle(.luna(.textPrimary))
            }
            .tint(.luna(.textSecondary))
            .padding(.top, 26)
            .accessibilityIdentifier(identifier)
        }
    }
}

/// "Reviewed by" with "Content pending doctor review" or `reviewedText`, under a
/// sheet title. No doctor's name yet (phase 6 spec §4.6).
struct ArticleReviewerRow: View {
    let pendingReview: Bool
    let reviewedText: String
    let identifier: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "stethoscope")
                .font(.system(size: 15, weight: .medium))
                // articleText, not textSecondary: drawn on `surface` (AA rule).
                .foregroundStyle(.luna(.articleText))
                .frame(width: 38, height: 38)
                .background(Circle().fill(.luna(.surface)))
            VStack(alignment: .leading, spacing: 0) {
                Text(L10n.weekReviewer)
                    .font(.luna(.small))
                    .foregroundStyle(.luna(.textSecondary))
                Text(pendingReview ? L10n.weekPendingReview : reviewedText)
                    .font(.luna(.label))
                    .foregroundStyle(.luna(.textPrimary))
            }
        }
        .padding(.top, 10)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}

/// The ✕ of a full-screen reading cover, at the top left over the background
/// and the expanded sheet. Opaque `card` with a hairline border: a translucent
/// fill let the sheet's top edge show through once expanded. VoiceOver reaches
/// it before the background or the sheet.
struct ArticleCloseButton: View {
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.luna(.textPrimary))
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(.luna(.cardOpaque))
                        .overlay(Circle().strokeBorder(.luna(.divider), lineWidth: 1))
                )
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.commonClose)
        .accessibilityIdentifier(identifier)
        .accessibilitySortPriority(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }
}
