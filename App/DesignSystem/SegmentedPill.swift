import KickCore
import SwiftUI

struct SegmentedOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    /// Accessibility identifier of this segment's button.
    let identifier: String
    var id: Value { value }
}

/// Two or three segments on a tinted track; the chosen one is a light pill (`segmentSelected`)
/// (History 7 days / 4 weeks, onboarding language, "I'm pregnant" date type).
/// Each segment is a button with the `.isSelected` trait for VoiceOver.
struct SegmentedPill<Value: Hashable>: View {
    let options: [SegmentedOption<Value>]
    @Binding var selection: Value
    /// Capsule segments (onboarding) instead of rounded rectangles.
    var capsule = false

    private var segmentShape: AnyShape {
        capsule ? AnyShape(Capsule()) : AnyShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private var trackShape: AnyShape {
        capsule ? AnyShape(Capsule()) : AnyShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                let isSelected = option.value == selection
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { selection = option.value }
                } label: {
                    Text(option.title)
                        .font(.luna(.captionStrong))
                        .foregroundStyle(.luna(.textPrimary))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: capsule ? nil : .infinity, minHeight: 36)
                        .background {
                            if isSelected {
                                segmentShape.fill(.luna(.segmentSelected))
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier(option.identifier)
            }
        }
        .padding(capsule ? 3 : 4)
        .background(trackShape.fill(.luna(.surfaceAlt)))
    }
}

private struct SegmentedPillPreview: View {
    @State private var range = 7

    var body: some View {
        VStack(spacing: 16) {
            SegmentedPill(options: [
                SegmentedOption(value: 7, title: "7 ngày", identifier: "a"),
                SegmentedOption(value: 28, title: "4 tuần", identifier: "b"),
            ], selection: $range)
            SegmentedPill(options: [
                SegmentedOption(value: 7, title: "Tiếng Việt", identifier: "c"),
                SegmentedOption(value: 28, title: "English", identifier: "d"),
            ], selection: $range, capsule: true)
        }
        .padding(20)
        .background(.luna(.background))
    }
}

#Preview {
    SegmentedPillPreview()
}
