import KickCore
import SwiftUI

/// "Thai kỳ của tôi đã kết thúc" (1.1 item 4, spec §4.1, §4.3): two equal
/// choices, then the branch's own words and an optional date, then whether to
/// keep the journey as a memory. Nothing changes before "Xác nhận"; "Hủy"
/// closes it at every step. Never asks for notification permission.
struct PregnancyEndingSheet: View {
    /// Called after the ending succeeded (the sheet is already closing). A birth
    /// passes its recap.
    var onEnded: (PregnancyRecap?) -> Void = { _ in }

    @Environment(PregnancyEnding.self) private var ending
    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar

    private enum Step: Equatable {
        case choose
        case opener(PregnancyEndBranch)
        case keep(PregnancyEndBranch)
    }

    private enum KeepChoice: Equatable {
        case memory
        case noMemory
    }

    @State private var step: Step
    @State private var endDate = AppClock.now()
    @State private var keepChoice: KeepChoice?
    @State private var memoryTitle = ""
    @State private var deleteData = false
    @State private var working = false
    @State private var failed = false
    @State private var showingDatePicker = false

    private var today: Date { AppClock.now() }

    /// `initialBranch` opens on that branch's date step instead of the two choices
    /// (the Today "Has your baby arrived?" card starts on `.birth`).
    init(initialBranch: PregnancyEndBranch? = nil, onEnded: @escaping (PregnancyRecap?) -> Void = { _ in }) {
        self.onEnded = onEnded
        _step = State(initialValue: initialBranch.map(Step.opener) ?? .choose)
    }

    var body: some View {
        LunaSheet(title: L10n.pregnancyEndTitle, titleIdentifier: "pregnancyEndTitle") {
            switch step {
            case .choose: chooseStep
            case .opener(let branch): openerStep(branch)
            case .keep(let branch): keepStep(branch)
            }
            Button(L10n.commonCancel) { dismiss() }
                .buttonStyle(.pill(.text(.textSecondary), height: 44))
                .padding(.top, 6)
                .disabled(working)
                .accessibilityIdentifier("pregnancyEndCancel")
        }
        .interactiveDismissDisabled(working)
        .sheet(isPresented: $showingDatePicker) {
            NavigationStack {
                DatePicker("", selection: $endDate, in: ...today, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(.luna(.cycleText))
                    .padding(.horizontal)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(L10n.completionDone) { showingDatePicker = false }
                        }
                    }
            }
            .lunaSheetPresentation(detents: [.medium, .large])
        }
        .alert(L10n.pregnancyEndFailed, isPresented: $failed) {
            Button(L10n.commonOK) {}
        }
    }

    // MARK: - Steps

    private var chooseStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            bodyText(L10n.pregnancyEndIntro)
                .padding(.bottom, 6)
            // The same quiet style for both: neither is the default or highlighted.
            ForEach(PregnancyEndBranch.allCases, id: \.self) { branch in
                Button { step = .opener(branch) } label: {
                    HStack(spacing: 12) {
                        Text(L10n.pregnancyEndChoice(branch))
                            .font(.luna(.bodyStrong))
                            .foregroundStyle(.luna(.textPrimary))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.luna(.chevron))
                            .accessibilityHidden(true)
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 52)
                    .lunaCard(padding: 0)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("pregnancyEnd-\(branch.rawValue)")
            }
        }
        .padding(.top, 8)
    }

    private func openerStep(_ branch: PregnancyEndBranch) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            bodyText(L10n.pregnancyEndOpener(branch))
                .accessibilityIdentifier("pregnancyEndOpener")
                .padding(.top, 8)
            // The date as a button opening a calendar (as "I'm pregnant" does): an
            // inline compact picker cannot shrink at accessibility sizes and
            // pushed the whole sheet past the screen edge.
            VStack(alignment: .leading, spacing: 6) {
                Button { showingDatePicker = true } label: {
                    HStack(spacing: 12) {
                        Text(L10n.pregnancyEndDateLabel(branch))
                            .font(.luna(.body))
                            .foregroundStyle(.luna(.textPrimary))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(Formatting.dayMonthYear(endDate))
                            .font(.luna(.bodyStrong))
                            .foregroundStyle(.luna(.textPrimary))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("pregnancyEndDate")
                Text(L10n.pregnancyEndDateHint)
                    .font(.luna(.caption))
                    .foregroundStyle(.luna(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .lunaCard()
            .padding(.top, 18)
            Button(L10n.pregnancyEndContinue) { step = .keep(branch) }
                .buttonStyle(.pill(.dark))
                .padding(.top, 20)
                .accessibilityIdentifier("pregnancyEndContinue")
        }
    }

    private func keepStep(_ branch: PregnancyEndBranch) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.pregnancyEndKeepQuestion)
                .font(.luna(.cardTitle))
                .foregroundStyle(.luna(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 10) {
                keepRow(L10n.pregnancyEndKeepYes, choice: .memory, identifier: "pregnancyEndKeepYes")
                keepRow(L10n.pregnancyEndKeepNo, choice: .noMemory, identifier: "pregnancyEndKeepNo")
            }
            .padding(.top, 14)
            switch keepChoice {
            case .memory:
                VStack(alignment: .leading, spacing: 10) {
                    TextField(L10n.memoryTitlePlaceholder, text: $memoryTitle)
                        .font(.luna(.body))
                        .foregroundStyle(.luna(.textPrimary))
                        .padding(.horizontal, 14)
                        .frame(minHeight: 48)
                        .lunaGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .submitLabel(.done)
                        .accessibilityIdentifier("memoryTitleField")
                    Text(L10n.pregnancyEndKeepYesNote)
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 16)
            case .noMemory:
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: $deleteData) {
                        Text(L10n.pregnancyEndDeleteData)
                            .font(.luna(.body))
                            .foregroundStyle(.luna(.textPrimary))
                    }
                    .tint(.luna(.cycleStrong))
                    .accessibilityIdentifier("pregnancyEndDeleteData")
                    Text(L10n.pregnancyEndDeleteDataNote)
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .lunaCard()
                .padding(.top, 16)
            case nil:
                EmptyView()
            }
            Button {
                Task { await confirm(branch) }
            } label: {
                HStack(spacing: 8) {
                    if working { ProgressView().tint(.luna(.onAccent)) }
                    Text(L10n.pregnancyEndConfirm)
                }
            }
            .buttonStyle(.pill(.dark))
            .disabled(keepChoice == nil || working)
            .padding(.top, 20)
            .accessibilityIdentifier("pregnancyEndConfirm")
        }
    }

    private func keepRow(_ title: String, choice: KeepChoice, identifier: String) -> some View {
        let isSelected = keepChoice == choice
        return Button { keepChoice = choice } label: {
            HStack(spacing: 12) {
                Text(title)
                    .font(.luna(.body))
                    .foregroundStyle(.luna(.textPrimary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.luna(.textPrimary))
                    .opacity(isSelected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 13)
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .background(.luna(.surfaceAlt), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? Color.luna(.textSecondary) : Color.clear, lineWidth: 1.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }

    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(.luna(.body))
            .foregroundStyle(.luna(.articleText))
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Confirm

    private func confirm(_ branch: PregnancyEndBranch) async {
        guard let keepChoice, !working else { return }
        let keep: PregnancyEndingKeep = switch keepChoice {
        case .memory: .memory(title: memoryTitle)
        case .noMemory: deleteData ? .noMemoryDeleteData : .noMemoryKeepData
        }
        working = true
        defer { working = false }
        let recap: PregnancyRecap?
        do {
            recap = try await ending.end(branch: branch, endDate: endDate, keep: keep)
        } catch {
            failed = true
            return
        }
        dismiss()
        onEnded(recap)
        if let recap {
            // RootView presents the cover; let this sheet finish closing first, or
            // the presentation is dropped.
            let ending = ending
            Task {
                try? await Task.sleep(for: .milliseconds(LunaMotion.isEnabled ? 600 : 250))
                ending.pendingCelebration = recap
            }
        }
    }
}
