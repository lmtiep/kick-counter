import KickCore
import SwiftUI

/// Rows of chips that wrap where the next chip no longer fits (spec §5): at
/// the largest text sizes chips move to the next row instead of being cut.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    private struct Row {
        var items: [(index: Int, size: CGSize)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, maxWidth: proposal.width ?? .infinity)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, maxWidth: bounds.width) {
            var x = bounds.minX
            for item in row.items {
                subviews[item.index].place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func arrange(_ subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            // A chip wider than the row wraps its own text (proposed the row's width).
            let size = subviews[index].sizeThatFits(ProposedViewSize(width: maxWidth.isFinite ? maxWidth : nil, height: nil))
            if !current.items.isEmpty, current.width + spacing + size.width > maxWidth {
                rows.append(current)
                current = Row()
            }
            current.width += (current.items.isEmpty ? 0 : spacing) + size.width
            current.height = max(current.height, size.height)
            current.items.append((index, size))
        }
        if !current.items.isEmpty { rows.append(current) }
        return rows
    }
}

/// A chip of the day-log sheets (spec §3.1): the mode's strong accent with
/// `onAccent` text when chosen, `surface` with `textPrimary` otherwise.
/// VoiceOver hears the selected trait.
struct SelectableChip: View {
    let title: String
    let isSelected: Bool
    var selectedFill: LunaToken = .cycleStrong
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.luna(.body))
                .foregroundStyle(.luna(isSelected ? .onAccent : .textPrimary))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .frame(minHeight: 40)
                .background(Capsule().fill(isSelected ? Color.luna(selectedFill) : Color.luna(.surface)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Flow: pick one; tapping the chosen chip again clears it (spec §3.1).
struct FlowChips: View {
    @Binding var selection: MenstrualFlow?

    var body: some View {
        FlowLayout {
            ForEach(MenstrualFlow.allCases, id: \.self) { flow in
                SelectableChip(title: L10n.flow(flow), isSelected: selection == flow) {
                    selection = selection == flow ? nil : flow
                }
                .accessibilityIdentifier("flowChip-\(flow.rawValue)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dayLogFlowPicker")
    }
}

/// Moods: several.
struct MoodChips: View {
    @Binding var selection: Set<Mood>
    var selectedFill: LunaToken = .cycleStrong

    var body: some View {
        FlowLayout {
            ForEach(Mood.allCases, id: \.self) { mood in
                SelectableChip(title: L10n.mood(mood), isSelected: selection.contains(mood), selectedFill: selectedFill) {
                    selection.formSymmetricDifference([mood])
                }
                .accessibilityIdentifier("moodChip-\(mood.rawValue)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dayLogMoodPicker")
    }
}

/// The current mode's symptoms: several.
struct SymptomChips: View {
    let mode: AppMode
    @Binding var selection: Set<Symptom>
    var selectedFill: LunaToken = .cycleStrong

    var body: some View {
        FlowLayout {
            ForEach(Symptom.cases(for: mode), id: \.self) { symptom in
                SelectableChip(title: L10n.symptom(symptom), isSelected: selection.contains(symptom), selectedFill: selectedFill) {
                    selection.formSymmetricDifference([symptom])
                }
                .accessibilityIdentifier("symptomChip-\(symptom.rawValue)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dayLogSymptomPicker")
    }
}

private struct SymptomChipsPreview: View {
    @State private var flow: MenstrualFlow? = .light
    @State private var moods: Set<Mood> = [.calm]
    @State private var symptoms: Set<Symptom> = [.contractions]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FlowChips(selection: $flow)
            MoodChips(selection: $moods)
            SymptomChips(mode: .pregnant, selection: $symptoms, selectedFill: .pregStrong)
        }
        .padding(22)
        .background(.luna(.background))
    }
}

#Preview {
    SymptomChipsPreview()
}
