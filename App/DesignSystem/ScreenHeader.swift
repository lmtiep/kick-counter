import KickCore
import SwiftUI

/// Top of the Today screens (README §2): 38 pt avatar (opens Profile), today's
/// date in the middle, an icon button on the right.
struct ScreenHeader: View {
    let title: String
    let avatarLabel: String
    let trailingSymbol: String
    let trailingLabel: String
    let trailingIdentifier: String
    let onAvatar: () -> Void
    let onTrailing: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onAvatar) {
                // The initial of "Luna": there is no user name yet (spec §4.2).
                Text(verbatim: "L")
                    .font(.luna(size: 16, weight: .bold, relativeTo: .headline))
                    .foregroundStyle(.luna(.avatarText))
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(.luna(.avatar)))
                    .overlay(Circle().strokeBorder(.luna(.avatarBorder), lineWidth: 1))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(avatarLabel)
            .accessibilityIdentifier("headerAvatar")

            Text(title)
                .font(.luna(.cardTitle))
                .foregroundStyle(.luna(.textPrimary))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("headerDate")

            Button(action: onTrailing) {
                Image(systemName: trailingSymbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.luna(.textPrimary))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(trailingLabel)
            .accessibilityIdentifier(trailingIdentifier)
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }
}

#Preview {
    ScreenHeader(
        title: "4 tháng 10",
        avatarLabel: "Cá nhân",
        trailingSymbol: "calendar",
        trailingLabel: "Lịch",
        trailingIdentifier: "headerCalendar",
        onAvatar: {},
        onTrailing: {}
    )
    .background(.luna(.background))
}
