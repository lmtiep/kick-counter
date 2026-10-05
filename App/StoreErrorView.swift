import KickCore
import SwiftUI

/// Shown when the data store can't be opened (spec §4.9, new style).
struct StoreErrorView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.luna(.warningText))
                .accessibilityHidden(true)
            Text(L10n.errorStoreTitle)
                .font(.luna(.sheetTitle))
                .foregroundStyle(.luna(.textPrimary))
                .multilineTextAlignment(.center)
            Text(L10n.errorStoreBody)
                .font(.luna(.body))
                .foregroundStyle(.luna(.textSecondary))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .lunaCard(padding: 24)
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.luna(.background))
    }
}
