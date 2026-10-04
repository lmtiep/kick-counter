import KickCore
import SwiftUI

/// A short confirmation ("Period start logged") in a dark pill at the top,
/// hidden after 1.9 s and read out by VoiceOver. Errors use alerts, not toasts.
private struct ToastModifier: ViewModifier {
    @Binding var message: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let message {
                    Text(message)
                        .font(.luna(.captionMedium))
                        .foregroundStyle(.luna(.onAccent))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(.luna(.buttonDark)))
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 8)
                        .padding(.top, 10)
                        .padding(.horizontal, 20)
                        .transition(reduceMotion || !LunaMotion.isEnabled ? .opacity : .move(edge: .top).combined(with: .opacity))
                        .accessibilityIdentifier("toast")
                        .task(id: message) {
                            AccessibilityNotification.Announcement(message).post()
                            try? await Task.sleep(for: toastLifetime)
                            guard !Task.isCancelled else { return }
                            self.message = nil
                        }
                }
            }
            .animation(.easeOut(duration: 0.2), value: message)
    }
}

/// 1.9 s on screen; longer under UI tests, which only query the screen
/// about 2 s after a tap and would otherwise miss the toast.
private var toastLifetime: Duration {
    AppClock.launchOptions.isUITesting ? .seconds(6) : .seconds(1.9)
}

extension View {
    func toast(_ message: Binding<String?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}

#Preview {
    Color.luna(.background)
        .toast(.constant("Đã ghi ngày bắt đầu kỳ kinh"))
}
