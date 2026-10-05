import KickCore
import SwiftUI

/// Bottom-sheet content of the redesign: `background` page, 40×5 handle,
/// 22/700 title, 22 pt side padding. Present it with `.sheet` and
/// `.lunaSheetPresentation()` (radius 28; the system dims what is behind).
struct LunaSheet<Content: View>: View {
    let title: String
    var titleIdentifier = "lunaSheetTitle"
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Capsule()
                    .fill(.luna(.chevron))
                    .frame(width: 40, height: 5)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 16)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.luna(.sheetTitle))
                    .foregroundStyle(.luna(.textPrimary))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier(titleIdentifier)
                content
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, 34)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(.luna(.background))
    }
}

/// A small section title inside a sheet ("Mood", "LH test"…): 13/600, secondary.
struct LunaSheetSectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.luna(.captionStrong))
            .foregroundStyle(.luna(.textSecondary))
            .padding(.top, 18)
            .padding(.bottom, 8)
            .accessibilityAddTraits(.isHeader)
    }
}

extension View {
    func lunaSheetPresentation(detents: Set<PresentationDetent> = [.large]) -> some View {
        presentationDetents(detents)
            .presentationBackground(.luna(.background))
            .presentationCornerRadius(28)
            .presentationDragIndicator(.hidden)
    }
}

#Preview {
    Color.luna(.background)
        .sheet(isPresented: .constant(true)) {
            LunaSheet(title: "Hôm nay, 4 tháng 10") {
                LunaSheetSectionTitle(title: "Que thử rụng trứng (LH)")
                Text(verbatim: "…").lunaCard()
            }
            .lunaSheetPresentation(detents: [.medium, .large])
        }
}
