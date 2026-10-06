import KickCore
import SwiftUI

/// "Your weight" on pregnancy Today (phase 5 spec §3.4), after the baby's
/// size: the latest weight and gain with its status, and "Talk to your doctor
/// at your next visit" when out of range. Nothing logged → "Log weight".
struct WeightTodayCard: View {
    let dueDate: Date

    @Environment(WeightCoordinator.self) private var weight
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let latest = WeightStats.points(weight.entries, profile: weight.profile, dueDate: dueDate).last
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.weightCardTitle)
                    .lunaLabelStyle()
                Text(latest.map(WeightTexts.line) ?? L10n.weightAdd)
                    .font(.luna(.cardTitle))
                    .foregroundStyle(.luna(.textPrimary))
                    .fixedSize(horizontal: false, vertical: true)
                // At accessibility sizes the pill goes under the figures, not beside them.
                if dynamicTypeSize.isAccessibilitySize, let status = latest?.status {
                    WeightStatusPill(status: status)
                        .padding(.top, 4)
                }
                if let status = latest?.status, status != .inRange {
                    Text(L10n.weightStatusTalk)
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !dynamicTypeSize.isAccessibilitySize, let status = latest?.status {
                WeightStatusPill(status: status)
            }
            Image(systemName: "chevron.right")
                .foregroundStyle(.luna(.chevron))
                .accessibilityHidden(true)
        }
        .lunaCard(padding: 16)
    }
}
