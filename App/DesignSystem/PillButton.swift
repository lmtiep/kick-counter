import KickCore
import SwiftUI

/// Pill buttons of the redesign (radius 99, 52 pt high, scale .98 when pressed,
/// 35 % opacity when disabled).
struct PillButtonStyle: ButtonStyle {
    enum Kind {
        /// Filled accent with `onAccent` text, e.g. `.filled(.cycleStrong)`.
        case filled(LunaToken)
        /// The dark in-app button (`buttonDark`).
        case dark
        /// White pill with dark text (Undo, Settings).
        case light
        /// Tinted pill: background, text (e.g. cycleSoft / cycleOnSoft).
        case soft(LunaToken, LunaToken)
        /// Text only ("Not now", "Later").
        case text(LunaToken)
        /// Onboarding: 60 pt, `buttonOnboarding`, 16/400.
        case onboarding

        var fill: LunaToken? {
            switch self {
            case .filled(let token): token
            case .dark: .buttonDark
            case .light: .card
            case .soft(let background, _): background
            case .text: nil
            case .onboarding: .buttonOnboarding
            }
        }

        var foreground: LunaToken {
            switch self {
            case .filled, .dark: .onAccent
            case .light: .textPrimary
            case .soft(_, let text): text
            case .text(let text): text
            case .onboarding: .onButtonOnboarding
            }
        }
    }

    var kind: Kind
    var fullWidth = true
    var height: CGFloat = 52

    func makeBody(configuration: Configuration) -> some View {
        PillButtonLabel(configuration: configuration, kind: kind, fullWidth: fullWidth, height: height)
    }
}

private struct PillButtonLabel: View {
    let configuration: ButtonStyleConfiguration
    let kind: PillButtonStyle.Kind
    let fullWidth: Bool
    let height: CGFloat
    @Environment(\.isEnabled) private var isEnabled

    private var isOnboarding: Bool {
        if case .onboarding = kind { return true }
        return false
    }

    var body: some View {
        configuration.label
            .font(.luna(isOnboarding ? .onboardingButton : .button))
            .multilineTextAlignment(.center)
            .foregroundStyle(.luna(kind.foreground))
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: isOnboarding ? 60 : height)
            .background {
                if let fill = kind.fill {
                    Capsule().fill(.luna(fill))
                }
            }
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(isEnabled ? 1 : 0.35)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    static func pill(_ kind: PillButtonStyle.Kind, fullWidth: Bool = true, height: CGFloat = 52) -> PillButtonStyle {
        PillButtonStyle(kind: kind, fullWidth: fullWidth, height: height)
    }
}

#Preview {
    VStack(spacing: 12) {
        Button {} label: { Text(verbatim: "Kỳ kinh bắt đầu") }.buttonStyle(.pill(.filled(.cycleStrong), fullWidth: false, height: 44))
        Button {} label: { Text(verbatim: "Lưu") }.buttonStyle(.pill(.dark))
        Button {} label: { Text(verbatim: "Hoàn tác") }.buttonStyle(.pill(.light, fullWidth: false, height: 44))
        Button {} label: { Text(verbatim: "Ghi chú") }.buttonStyle(.pill(.soft(.cycleSoft, .cycleOnSoft), fullWidth: false, height: 36))
        Button {} label: { Text(verbatim: "Để sau") }.buttonStyle(.pill(.text(.textSecondary)))
        Button {} label: { Text(verbatim: "Tiếp tục") }.buttonStyle(.pill(.onboarding)).disabled(true)
    }
    .padding(24)
    .background(.luna(.background))
}
