import KickCore
import SwiftUI

/// Profile → "Kỷ niệm" (1.1 item 4, spec §4.3): every kept journey, newest
/// first. Calm cards, no numbers: the title (or "Your journey") and the dates.
struct MemoryListView: View {
    @Environment(PregnancyEnding.self) private var ending
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(ending.memories) { memory in
                    NavigationLink {
                        MemoryDetailView(memoryID: memory.id)
                    } label: {
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(MemoryTexts.title(memory))
                                    .font(.luna(.cardTitle))
                                    .foregroundStyle(.luna(.textPrimary))
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(MemoryTexts.dates(memory.content))
                                    .font(.luna(.caption))
                                    .foregroundStyle(.luna(.textSecondary))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.luna(.chevron))
                                .accessibilityHidden(true)
                        }
                        .lunaCard()
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("memoryRow")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .lunaBackground()
        .navigationTitle(L10n.memoryTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { ending.loadMemories() }
        // The last one deleted: back to Profile, where the row is gone too.
        .onChange(of: ending.memories.isEmpty) { _, empty in
            if empty { dismiss() }
        }
    }
}

/// The words a memory shows, shared by the list and the detail page.
enum MemoryTexts {
    static func title(_ memory: PregnancyMemoryRecord) -> String {
        let trimmed = memory.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? L10n.memoryDefaultTitle : trimmed
    }

    /// "1/3/2026 – 20/11/2026", or just the end day without a start.
    static func dates(_ content: PregnancyMemoryContent) -> String {
        let end = Formatting.dayMonthYear(content.end)
        guard let start = content.start, start < content.end else { return end }
        return L10n.memoryDates(Formatting.dayMonthYear(start), end)
    }
}
