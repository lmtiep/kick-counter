import KickCore
import KickData
import SwiftData
import SwiftUI

/// "Đồ đi sinh · 12/30" on pregnancy Today from week 32 (1.1 spec); opens the bag.
struct BagTodayCard: View {
    @Query(sort: \ChecklistItem.createdAt) private var items: [ChecklistItem]

    var body: some View {
        let progress = BagList.progress(BagList.sections(overrides: items.map(\.record)))
        NavigationLink {
            BagChecklistView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "bag")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.luna(.pregOnSoft))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.luna(.pregSoft)))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.bagCardTitle(progress.done, progress.total))
                        .font(.luna(.cardTitleSmall))
                        .foregroundStyle(.luna(.textPrimary))
                        .multilineTextAlignment(.leading)
                    Text(L10n.bagCardSubtitle)
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.textSecondary))
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.luna(.chevron))
                    .accessibilityHidden(true)
            }
            .lunaCard(padding: 16)
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("bagTodayCard")
    }
}
