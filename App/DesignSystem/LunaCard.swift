import KickCore
import SwiftUI

/// The standard card of the redesign: white (`card`), radius 20, padding 18,
/// full width. Screens add the 20 pt side margin and 12 pt spacing.
/// Dark mode (phase 18): glass, a 9 % white fill with a 1 pt `cardBorder`, radius 24;
/// tinted cards get their tint's border (`cycleSoftBorder`, `pregSoftBorder`).
struct LunaCard<Content: View>: View {
    var fill: LunaToken = .card
    var border: LunaToken?
    var padding: CGFloat = 18
    var cornerRadius: CGFloat = 20
    @ViewBuilder var content: Content
    @Environment(\.colorScheme) private var colorScheme

    /// The handoff's radius 24 replaces the standard 20 in dark mode.
    private var radius: CGFloat {
        colorScheme == .dark && cornerRadius == 20 ? 24 : cornerRadius
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.luna(fill), in: shape)
            .overlay {
                if let border = border ?? fill.glassBorder {
                    shape.strokeBorder(.luna(border), lineWidth: 1)
                }
            }
    }
}

extension LunaToken {
    /// The 1 pt border a fill carries: invisible in light mode (the light value is
    /// the fill's own), the glass edge in dark mode.
    var glassBorder: LunaToken? {
        switch self {
        case .card: .cardBorder
        case .cycleSoft: .cycleSoftBorder
        case .pregSoft: .pregSoftBorder
        default: nil
        }
    }
}

extension View {
    func lunaCard(
        _ fill: LunaToken = .card,
        border: LunaToken? = nil,
        padding: CGFloat = 18,
        cornerRadius: CGFloat = 20
    ) -> some View {
        LunaCard(fill: fill, border: border, padding: padding, cornerRadius: cornerRadius) { self }
    }

    /// Uppercase 12/600 label with letter spacing, e.g. "MOVEMENTS TODAY".
    func lunaLabelStyle(_ color: LunaToken = .textSecondary) -> some View {
        font(.luna(.label))
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(.luna(color))
    }
}

/// 1 pt separator between rows inside a card.
struct LunaDivider: View {
    var body: some View {
        Rectangle().fill(.luna(.divider)).frame(height: 1).accessibilityHidden(true)
    }
}

/// A tappable row inside a card: title, optional value, chevron.
struct LunaRow: View {
    let title: String
    var value: String?
    var showsChevron = true

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.luna(.body))
                .foregroundStyle(.luna(.textPrimary))
                .frame(maxWidth: .infinity, alignment: .leading)
            if let value {
                Text(value)
                    .font(.luna(.body))
                    .foregroundStyle(.luna(.textSecondary))
                    .multilineTextAlignment(.trailing)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.luna(.chevron))
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

#Preview {
    VStack(spacing: 12) {
        LunaCard {
            Text(verbatim: "Dự đoán sắp tới").font(.luna(.cardTitle))
        }
        Text(verbatim: "Bé cử động ít hơn bình thường")
            .lunaCard(.warningBackground, border: .warningBorder)
        VStack(spacing: 0) {
            LunaRow(title: "Ngôn ngữ", value: "Tiếng Việt")
            LunaDivider()
            LunaRow(title: "Xem lại phần giới thiệu")
        }
        .lunaCard(padding: 0)
    }
    .padding(20)
    .background(.luna(.background))
}
