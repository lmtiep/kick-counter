import KickCore
import KickData
import SwiftData
import SwiftUI

/// Profile → "Xuất báo cáo cho bác sĩ": choose the period and the sections, type
/// an optional name (kept only in this screen's state), and share a PDF made on
/// the phone. Nothing leaves the phone until the mother shares the file herself.
struct DoctorReportView: View {
    @Environment(CycleCoordinator.self) private var cycle
    @Environment(WeightCoordinator.self) private var weight
    @Environment(AppointmentCoordinator.self) private var appointments
    @Environment(ContractionCoordinator.self) private var contractions
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \KickSession.startedAt) private var sessions: [KickSession]
    @AppStorage(SettingsKey.appMode, store: AppGroup.defaults) private var appMode = AppMode.pregnant.rawValue
    @AppStorage(SettingsKey.dueDate, store: AppGroup.defaults) private var dueDate: Double = 0

    @State private var rangeIndex = 0
    @State private var excluded: Set<ReportSectionKind> = []
    /// Typed at export time and never stored: this state dies with the screen.
    @State private var name = ""
    @State private var failed = false
    #if DEBUG
    @State private var preview: ReportPreview?
    #endif

    private var mode: AppMode { AppMode(rawValue: appMode) == .tryingToConceive ? .tryingToConceive : .pregnant }
    private var accent: LunaToken { mode == .pregnant ? .pregStrong : .cycleStrong }

    private var ranges: [ReportRange] {
        mode == .pregnant ? [.weeks(2), .weeks(4), .wholePregnancy] : [.cycles(3), .cycles(6)]
    }

    private var range: ReportRange { ranges[min(rangeIndex, ranges.count - 1)] }
    private var kinds: [ReportSectionKind] { ReportSectionKind.kinds(for: mode) }

    private func makeReport(now: Date) -> DoctorReport {
        let input = DoctorReportInput(
            sessions: sessions.map(\.state),
            contractions: contractions.contractions,
            weights: weight.entries,
            logs: cycle.logs,
            appointments: appointments.upcoming + appointments.past,
            periods: cycle.periods,
            dueDate: dueDate > 0 ? Date(timeIntervalSince1970: dueDate) : nil
        )
        return DoctorReport.make(
            mode: mode, range: range, include: Set(kinds).subtracting(excluded), input: input, name: name, now: now
        )
    }

    var body: some View {
        let isEmpty = makeReport(now: AppClock.now()).isEmpty
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.reportIntro)
                    .font(.luna(.body))
                    .foregroundStyle(.luna(.articleText))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("reportIntro")
                    .padding(.horizontal, 4)

                sectionTitle(L10n.reportRangeTitle)
                rangePicker
                sectionTitle(L10n.reportSectionsTitle)
                sectionToggles
                sectionTitle(L10n.reportNameTitle)
                nameField

                if isEmpty {
                    Text(L10n.reportEmpty)
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("reportEmptyHint")
                        .padding(.horizontal, 4)
                }
                Button(action: export) {
                    Text(L10n.reportExport)
                }
                .buttonStyle(.pill(.dark))
                .disabled(isEmpty)
                .padding(.top, 8)
                .accessibilityIdentifier("reportExport")
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .lunaStatusBarBackdrop()
        .lunaBackground()
        .navigationTitle(L10n.reportRow)
        .navigationBarTitleDisplayMode(.inline)
        .alert(L10n.reportFailed, isPresented: $failed) {
            Button(L10n.commonOK) {}
        }
        #if DEBUG
        .fullScreenCover(item: $preview) { preview in
            ReportPreviewCover(preview: preview)
        }
        #endif
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.luna(.captionStrong))
            .foregroundStyle(.luna(.textSecondary))
            .padding(.horizontal, 4)
            .padding(.top, 6)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var rangePicker: some View {
        if dynamicTypeSize.isAccessibilitySize {
            // Three segments do not fit at the largest sizes: one choice per line.
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(ranges.enumerated()), id: \.offset) { index, option in
                    if index > 0 { LunaDivider() }
                    Button { rangeIndex = index } label: {
                        HStack(spacing: 12) {
                            Text(L10n.reportRange(option))
                                .font(.luna(.body))
                                .foregroundStyle(.luna(.textPrimary))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if index == rangeIndex {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.luna(accent))
                                    .accessibilityHidden(true)
                            }
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(index == rangeIndex ? .isSelected : [])
                    .accessibilityIdentifier("reportRange-\(index)")
                }
            }
            .lunaCard(padding: 0)
        } else {
            SegmentedPill(
                options: ranges.enumerated().map {
                    SegmentedOption(value: $0.offset, title: L10n.reportRange($0.element), identifier: "reportRange-\($0.offset)")
                },
                selection: $rangeIndex,
                selectedFill: mode == .pregnant ? .segmentSelectedPreg : .segmentSelected
            )
        }
    }

    private var sectionToggles: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(kinds.enumerated()), id: \.element) { index, kind in
                if index > 0 { LunaDivider() }
                Toggle(isOn: Binding(
                    get: { !excluded.contains(kind) },
                    set: { isOn in
                        if isOn { excluded.remove(kind) } else { excluded.insert(kind) }
                    }
                )) {
                    Text(L10n.reportSection(kind))
                        .font(.luna(.body))
                        .foregroundStyle(.luna(.textPrimary))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .tint(.luna(accent))
                .padding(.vertical, 10)
                .padding(.horizontal, 18)
                .frame(minHeight: 44)
                .accessibilityIdentifier("reportSection-\(kind.rawValue)")
            }
        }
        .lunaCard(padding: 0)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(L10n.reportNameTitle, text: $name, prompt: Text(L10n.reportNamePlaceholder))
                .font(.luna(.body))
                .foregroundStyle(.luna(.textPrimary))
                .textContentType(.name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .frame(minHeight: 44)
                .accessibilityIdentifier("reportName")
            Text(L10n.reportNameFootnote)
                .font(.luna(.caption))
                .foregroundStyle(.luna(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
        }
        .lunaCard(padding: 16)
    }

    // MARK: - Export

    private func export() {
        let now = AppClock.now()
        let report = makeReport(now: now)
        guard !report.isEmpty else { return }
        let data = DoctorReportPDF.render(ReportContent(report))
        #if DEBUG
        if AppClock.launchOptions.reportPreview {
            showPreview(of: data, now: now)
            return
        }
        #endif
        guard let url = try? DoctorReportPDF.write(data, now: now) else {
            failed = true
            return
        }
        // The file holds health data: `BackupSharePresenter` deletes its folder
        // whether the sheet completes or is cancelled.
        BackupSharePresenter.present(url) { _ in }
    }

    #if DEBUG
    /// `-uiTesting -uiTestingReportPreview`: the PDF is written to a known path
    /// and its first page is shown full screen with the page count, so a UI test
    /// can assert the pages and a screenshot can show the render.
    private func showPreview(of data: Data, now: Date) {
        let path = NSTemporaryDirectory() + "LunaMom-report-uitest.pdf"
        try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
        preview = ReportPreview(pageCount: DoctorReportPDF.pageCount(of: data), image: DoctorReportPDF.firstPageImage(of: data))
    }
    #endif
}

#if DEBUG
struct ReportPreview: Identifiable {
    let id = UUID()
    let pageCount: Int
    let image: UIImage?
}

private struct ReportPreviewCover: View {
    let preview: ReportPreview
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(verbatim: "pages: \(preview.pageCount)")
                    .font(.caption)
                    .accessibilityIdentifier("reportPageCount")
                Spacer()
                Button(L10n.commonClose) { dismiss() }
                    .accessibilityIdentifier("reportPreviewClose")
            }
            .padding(8)
            if let image = preview.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}
#endif
