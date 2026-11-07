import KickCore
import KickData
import SwiftData
import SwiftUI

/// Adds her own item to a bag group.
struct AddBagItemSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var group: BagGroup
    @State private var text = ""
    @State private var saveFailed = false
    @FocusState private var focused: Bool

    init(group: BagGroup) {
        _group = State(initialValue: group)
    }

    private var canSave: Bool { ChecklistText.clean(text) != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.bagAddField, text: $text)
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit(save)
                        .accessibilityIdentifier("bagAddField")
                    Picker(L10n.bagAddGroup, selection: $group) {
                        ForEach(BagGroup.allCases) { group in
                            Text(L10n.bagGroup(group)).tag(group)
                        }
                    }
                    .accessibilityIdentifier("bagAddGroup")
                }
            }
            .scrollContentBackground(.hidden)
            .lunaBackground()
            .tint(.luna(.pregText))
            .navigationTitle(L10n.bagAdd)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.commonCancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.commonSave, action: save)
                        .disabled(!canSave)
                        .accessibilityIdentifier("bagAddSave")
                }
            }
            .checklistSaveAlert($saveFailed)
            .onAppear { focused = true }
        }
    }

    private func save() {
        guard canSave else { return }
        do {
            try ChecklistStore(context: modelContext).addBagItem(text, group: group)
            dismiss()
        } catch {
            saveFailed = true
        }
    }
}
