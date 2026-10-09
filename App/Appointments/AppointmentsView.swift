import KickCore
import SwiftUI

/// Upcoming and past check-ups plus the suggested milestones still ahead.
struct AppointmentsView: View {
    @Environment(AppointmentCoordinator.self) private var appointments
    @Environment(\.contentLibrary) private var library
    @Environment(\.openURL) private var openURL
    @AppStorage(SettingsKey.dueDate, store: AppGroup.defaults) private var dueDate: Double = 0
    @State private var editor: AppointmentEditorMode?
    @State private var pendingDelete: AppointmentRecord?

    private let language = ContentLanguage.current

    private var dueDateValue: Date? {
        dueDate > 0 ? Date(timeIntervalSince1970: dueDate) : nil
    }

    private var currentWeek: Int {
        guard let dueDateValue, let timeline = PregnancyTimeline(dueDate: dueDateValue, now: AppClock.now()) else { return 0 }
        return timeline.week.weeks
    }

    /// Milestones still ahead that the mother hasn't added yet.
    private func loadSuggestedMilestones(excluding addedMilestoneIDs: Set<String>) -> [Milestone] {
        library?.suggestedMilestones(atWeek: currentWeek, visibility: BuildFlags.contentVisibility, excluding: addedMilestoneIDs) ?? []
    }

    var body: some View {
        let addedMilestoneIDs = Set((appointments.upcoming + appointments.past).compactMap(\.milestoneID))
        let suggestedMilestones = loadSuggestedMilestones(excluding: addedMilestoneIDs)
        List {
            if appointments.notificationsDenied {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.appointmentsNotificationsOff)
                            .font(.luna(.caption))
                            .foregroundStyle(.luna(.textPrimary))
                        Button(L10n.settingsOpenSettings) {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                        .font(.luna(.captionStrong))
                        .tint(.luna(.pregStrong))
                    }
                    .listRowBackground(Color.luna(.card))
                }
            }

            Section {
                if appointments.upcoming.isEmpty {
                    Text(L10n.appointmentsEmpty)
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.textSecondary))
                        .listRowBackground(Color.luna(.card))
                }
                ForEach(appointments.upcoming) { record in
                    row(for: record)
                }
            } header: {
                Text(L10n.appointmentsUpcoming)
                    .font(.luna(.captionStrong))
                    .foregroundStyle(.luna(.textSecondary))
                    .accessibilityIdentifier("upcomingHeader")
            }

            if !suggestedMilestones.isEmpty {
                Section {
                    ForEach(suggestedMilestones) { milestone in
                        MilestoneRow(milestone: milestone, language: language) {
                            editor = .new(
                                date: AppointmentPrefill.suggestedDate(for: milestone, dueDate: dueDateValue, now: AppClock.now()),
                                title: milestone.title.text(language),
                                milestoneID: milestone.id
                            )
                        }
                        .listRowBackground(Color.luna(.card))
                    }
                } header: {
                    Text(L10n.appointmentsMilestones)
                        .font(.luna(.captionStrong))
                        .foregroundStyle(.luna(.textSecondary))
                        .accessibilityIdentifier("milestonesHeader")
                }
            }

            if !appointments.past.isEmpty {
                Section {
                    ForEach(appointments.past) { record in
                        row(for: record)
                    }
                } header: {
                    Text(L10n.appointmentsPast)
                        .font(.luna(.captionStrong))
                        .foregroundStyle(.luna(.textSecondary))
                        .accessibilityIdentifier("pastHeader")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        // Content scrolled up stays out from under the status bar.
        .lunaStatusBarBackdrop()
        .lunaBackground()
        .tint(.luna(.pregStrong))
        .navigationTitle(L10n.appointmentsTitle)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editor = .new(date: AppointmentPrefill.nextDefaultDate(now: AppClock.now()), title: "", milestoneID: nil)
                } label: {
                    Label(L10n.appointmentsAdd, systemImage: "plus")
                }
                .accessibilityIdentifier("addAppointmentButton")
            }
        }
        .sheet(item: $editor) { mode in
            AppointmentEditorSheet(mode: mode)
                .lunaSheetPresentation()
        }
        .confirmationDialog(
            L10n.appointmentsDeleteConfirmTitle,
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button(L10n.commonDelete, role: .destructive) {
                if let record = pendingDelete {
                    Task { await appointments.delete(id: record.id) }
                }
                pendingDelete = nil
            }
            Button(L10n.commonCancel, role: .cancel) { pendingDelete = nil }
        }
        .alert(failureMessage ?? "", isPresented: failureBinding) {
            Button(L10n.commonOK) { appointments.clearFailure() }
        }
        .task { await appointments.load() }
    }

    private func row(for record: AppointmentRecord) -> some View {
        Button {
            editor = .edit(record)
        } label: {
            AppointmentRow(record: record)
        }
        .tint(.primary)
        .accessibilityIdentifier("appointmentRow")
        .listRowBackground(Color.luna(.card))
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                pendingDelete = record
            } label: {
                Label(L10n.commonDelete, systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            if !record.isDone {
                Button {
                    Task { await appointments.markDone(id: record.id) }
                } label: {
                    Label(L10n.appointmentsMarkDone, systemImage: "checkmark")
                }
                .tint(.luna(.tealStrong))
            }
        }
    }

    private var failureMessage: String? {
        switch appointments.failure {
        case .saveFailed: L10n.errorSave
        case .loadFailed: L10n.errorLoad
        case nil: nil
        }
    }

    /// Only while no editor sheet is open: the sheet reports its own save errors.
    private var failureBinding: Binding<Bool> {
        Binding(
            get: { appointments.failure != nil && editor == nil },
            set: { if !$0 { appointments.clearFailure() } }
        )
    }
}
