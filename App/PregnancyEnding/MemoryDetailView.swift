import KickCore
import SwiftUI

/// One kept journey (1.1 item 4, spec §4.3, §4.6). It opens with her title (or
/// "Your journey") and the dates, then her own words, then the check-ups,
/// weights, movements and contractions. No fruit art on either branch (one
/// calm style); only the birth branch adds the week the baby was born.
/// Rename and delete live in the toolbar menu.
struct MemoryDetailView: View {
    let memoryID: UUID

    @Environment(PregnancyEnding.self) private var ending
    @Environment(\.dismiss) private var dismiss
    @State private var renaming = false
    @State private var draftTitle = ""
    @State private var confirmingDelete = false

    private var memory: PregnancyMemoryRecord? {
        ending.memories.first { $0.id == memoryID }
    }

    var body: some View {
        ScrollView {
            if let memory {
                VStack(alignment: .leading, spacing: 12) {
                    header(memory)
                    let content = memory.content
                    if content.isEmpty {
                        Text(L10n.memoryEmpty)
                            .font(.luna(.body))
                            .foregroundStyle(.luna(.textSecondary))
                            .fixedSize(horizontal: false, vertical: true)
                            .lunaCard()
                    }
                    if !content.notes.isEmpty { notes(content.notes) }
                    if !content.appointments.isEmpty { appointments(content.appointments) }
                    if !content.weights.isEmpty { weights(content.weights) }
                    if !content.kickDays.isEmpty { kicks(content.kickDays) }
                    if !content.contractionEpisodes.isEmpty { contractions(content.contractionEpisodes) }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .lunaBackground()
        .navigationTitle(L10n.memoryTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        draftTitle = memory?.title ?? ""
                        renaming = true
                    } label: {
                        Label(L10n.memoryRename, systemImage: "pencil")
                    }
                    .accessibilityIdentifier("memoryRename")
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Label(L10n.memoryDelete, systemImage: "trash")
                    }
                    .accessibilityIdentifier("memoryDelete")
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel(L10n.memoryActions)
                .accessibilityIdentifier("memoryActions")
            }
        }
        .alert(L10n.memoryRenameTitle, isPresented: $renaming) {
            TextField(L10n.memoryTitlePlaceholder, text: $draftTitle)
                .accessibilityIdentifier("memoryRenameField")
            Button(L10n.commonSave) { ending.rename(id: memoryID, title: draftTitle) }
                .accessibilityIdentifier("memoryRenameSave")
            Button(L10n.commonCancel, role: .cancel) {}
        }
        .confirmationDialog(L10n.memoryDeleteConfirm, isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button(L10n.memoryDelete, role: .destructive) {
                if ending.delete(id: memoryID) { dismiss() }
            }
            Button(L10n.commonCancel, role: .cancel) {}
        }
    }

    // MARK: - Header

    private func header(_ memory: PregnancyMemoryRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(MemoryTexts.title(memory))
                .font(.luna(.screenTitle))
                .foregroundStyle(.luna(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("memoryDetailTitle")
            Text(MemoryTexts.dates(memory.content))
                .font(.luna(.body))
                .foregroundStyle(.luna(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("memoryDetailDates")
            if memory.branch == .birth, let week = memory.content.furthestWeek {
                Text(L10n.memoryBirthWeek(week))
                    .font(.luna(.body))
                    .foregroundStyle(.luna(.textSecondary))
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Sections

    private func section<Rows: View>(_ title: String, identifier: String, @ViewBuilder rows: () -> Rows) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.luna(.cardTitle))
                .foregroundStyle(.luna(.textPrimary))
                .accessibilityAddTraits(.isHeader)
            rows()
        }
        .lunaCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    private func row(_ leading: String, _ trailing: String? = nil, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    rowLeading(leading)
                    if let trailing { rowTrailing(trailing) }
                }
                VStack(alignment: .leading, spacing: 2) {
                    rowLeading(leading)
                    if let trailing { rowTrailing(trailing) }
                }
            }
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.luna(.body))
                    .foregroundStyle(.luna(.articleText))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func rowLeading(_ text: String) -> some View {
        Text(text)
            .font(.luna(.captionStrong))
            .foregroundStyle(.luna(.textSecondary))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rowTrailing(_ text: String) -> some View {
        Text(text)
            .font(.luna(.body))
            .foregroundStyle(.luna(.textPrimary))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func notes(_ notes: [MemoryNote]) -> some View {
        section(L10n.memorySectionNotes, identifier: "memoryNotes") {
            ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                let tags = note.moods.compactMap(Mood.init(rawValue:)).map(L10n.mood)
                    + note.pregnancySymptoms.compactMap(Symptom.init(rawValue:)).map(L10n.symptom)
                row(
                    Formatting.dayMonthYear(note.day),
                    detail: [note.text, tags.joined(separator: " · ")].filter { !$0.isEmpty }.joined(separator: "\n")
                )
            }
        }
    }

    private func appointments(_ appointments: [MemoryAppointment]) -> some View {
        section(L10n.memorySectionAppointments, identifier: "memoryAppointments") {
            ForEach(Array(appointments.enumerated()), id: \.offset) { _, appointment in
                row(Formatting.dayMonthYear(appointment.date), appointment.title, detail: appointment.note)
            }
        }
    }

    private func weights(_ weights: [MemoryWeight]) -> some View {
        section(L10n.memorySectionWeights, identifier: "memoryWeights") {
            ForEach(Array(weights.enumerated()), id: \.offset) { _, weight in
                row(Formatting.dayMonthYear(weight.day), Formatting.kilograms(weight.kg))
            }
        }
    }

    private func kicks(_ days: [KickDay]) -> some View {
        section(L10n.memorySectionKicks, identifier: "memoryKicks") {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                row(Formatting.dayMonthYear(day.day), L10n.memoryKickDay(sessions: day.sessionCount, kicks: day.totalKicks))
            }
        }
    }

    private func contractions(_ episodes: [ContractionEpisodeSummary]) -> some View {
        section(L10n.memorySectionContractions, identifier: "memoryContractions") {
            ForEach(Array(episodes.enumerated()), id: \.offset) { _, episode in
                row(Formatting.dateTime(episode.start), L10n.memoryContractionEpisode(episode.count))
            }
        }
    }
}
