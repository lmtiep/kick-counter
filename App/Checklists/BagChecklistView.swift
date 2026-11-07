import KickCore
import KickData
import SwiftData
import SwiftUI

/// The hospital bag (1.1 spec): four groups of built-in items plus her own, ticked as
/// they are packed. Reached from Profile (any week) and from the Today card (week 32 on).
struct BagChecklistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChecklistItem.createdAt) private var items: [ChecklistItem]
    @State private var addingTo: BagGroup?
    @State private var confirmingReset = false
    @State private var saveFailed = false

    private var overrides: [ChecklistItemRecord] { items.map(\.record) }

    var body: some View {
        let sections = BagList.sections(overrides: overrides)
        let progress = BagList.progress(sections)
        let hidden = BagList.hiddenCount(overrides: overrides)
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.bagProgress(progress.done, progress.total))
                        .font(.luna(.cardTitle))
                        .foregroundStyle(.luna(.textPrimary))
                        .accessibilityIdentifier("bagProgress")
                    ChecklistProgressBar(fraction: progress.fraction)
                    Text(L10n.bagHint)
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.textSecondary))
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.luna(.card))
            }
            ForEach(sections) { section in
                Section {
                    ForEach(section.entries) { entry in
                        row(for: entry)
                            .listRowBackground(Color.luna(.card))
                    }
                    Button { addingTo = section.group } label: {
                        Label(L10n.bagAdd, systemImage: "plus")
                            .font(.luna(.bodyStrong))
                            .foregroundStyle(.luna(.pregText))
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .accessibilityIdentifier("bagAdd-\(section.group.rawValue)")
                    .listRowBackground(Color.luna(.card))
                } header: {
                    Text(L10n.bagGroup(section.group))
                        .font(.luna(.captionStrong))
                        .foregroundStyle(.luna(.textSecondary))
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("bagGroup-\(section.group.rawValue)")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .lunaStatusBarBackdrop()
        .lunaBackground()
        .tint(.luna(.pregText))
        .navigationTitle(L10n.bagTitle)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(L10n.bagMenuReset) { confirmingReset = true }
                        .accessibilityIdentifier("bagReset")
                    if hidden > 0 {
                        Button(L10n.bagMenuUnhide(hidden)) { write { try $0.unhideAllBuiltIns() } }
                            .accessibilityIdentifier("bagUnhide")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel(L10n.bagMenuLabel)
                .accessibilityIdentifier("bagMenu")
            }
        }
        .confirmationDialog(L10n.bagResetTitle, isPresented: $confirmingReset, titleVisibility: .visible) {
            Button(L10n.bagResetAction, role: .destructive) { write { try $0.resetBagTicks() } }
            Button(L10n.commonCancel, role: .cancel) {}
        }
        .sheet(item: $addingTo) { group in
            AddBagItemSheet(group: group)
                .lunaSheetPresentation(detents: [.medium, .large])
        }
        .checklistSaveAlert($saveFailed)
    }

    @ViewBuilder
    private func row(for entry: BagEntry) -> some View {
        let text = entry.builtInID.map(L10n.bagItem) ?? entry.text
        ChecklistRow(text: text, isDone: entry.isDone, identifier: "bagItem-\(entry.builtInID ?? "custom")") {
            write { store in
                if let builtInID = entry.builtInID {
                    try store.setBuiltInDone(builtInID, done: !entry.isDone)
                } else if let id = entry.itemID {
                    try store.setDone(id: id, done: !entry.isDone)
                }
            }
        }
        .swipeActions(edge: .trailing) {
            if let builtInID = entry.builtInID {
                Button { write { try $0.setBuiltInHidden(builtInID, hidden: true) } } label: {
                    Label(L10n.bagHide, systemImage: "eye.slash")
                }
                .tint(.luna(.buttonDark))
            } else if let id = entry.itemID {
                Button(role: .destructive) { write { try $0.delete(id: id) } } label: {
                    Label(L10n.commonDelete, systemImage: "trash")
                }
            }
        }
    }

    private func write(_ change: (ChecklistStore) throws -> Void) {
        do {
            try change(ChecklistStore(context: modelContext))
        } catch {
            saveFailed = true
        }
    }
}
