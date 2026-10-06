import SwiftUI
import UIKit

extension View {
    /// A "Done" button above the keyboard: number pads have no return key.
    func keyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L10n.commonDone) {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .font(.luna(.button))
                .accessibilityIdentifier("keyboardDone")
            }
        }
    }
}
