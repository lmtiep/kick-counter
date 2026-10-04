import KickCore
import SwiftUI

/// A horizontal row of chips that scrolls the chosen chip into the middle,
/// on appear and whenever the selection changes (week detail, spec §4.5).
struct ChipScroller<Value: Hashable>: View {
    let values: [Value]
    @Binding var selection: Value
    let title: (Value) -> String
    let identifier: (Value) -> String
    var selectedFill: LunaToken = .card
    var selectedText: LunaToken = .textPrimary
    var idleText: LunaToken = .pregOnSoft

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(values, id: \.self) { value in
                        let isSelected = value == selection
                        Button {
                            selection = value
                        } label: {
                            Text(title(value))
                                .font(.luna(.bodyStrong))
                                .foregroundStyle(.luna(isSelected ? selectedText : idleText))
                                .padding(.horizontal, 16)
                                .frame(minHeight: 40)
                                .background(
                                    Capsule().fill(isSelected ? Color.luna(selectedFill) : Color.luna(.card).opacity(0.35))
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                        .accessibilityIdentifier(identifier(value))
                        .id(value)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }
            .onAppear { proxy.scrollTo(selection, anchor: .center) }
            .onChange(of: selection) { _, value in
                withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(value, anchor: .center) }
            }
        }
    }
}

private struct ChipScrollerPreview: View {
    @State private var week = 24

    var body: some View {
        ChipScroller(
            values: Array(4...42),
            selection: $week,
            title: { "\($0) tuần" },
            identifier: { "weekChip-\($0)" }
        )
        .padding(.vertical)
        .background(.luna(.heroMiddle))
    }
}

#Preview {
    ChipScrollerPreview()
}
