import KickCore
import SwiftUI

struct CounterView: View {
    @Environment(KickCoordinator.self) private var coordinator
    @AppStorage(SettingsKey.dueDate, store: AppGroup.defaults) private var dueDate: Double = 0
    @State private var confirmingCancel = false

    private var count: Int { coordinator.activeSession?.count ?? 0 }

    private var gestationalWeekText: String? {
        guard dueDate > 0,
              let timeline = PregnancyTimeline(dueDate: Date(timeIntervalSince1970: dueDate), now: AppClock.now())
        else { return nil }
        return L10n.counterWeek(timeline.week)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let gestationalWeekText {
                        Text(gestationalWeekText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        if coordinator.isOverdue(at: context.date) {
                            OverdueBanner()
                        }
                    }

                    KickButton(
                        count: count,
                        target: SessionRules.targetCount,
                        isActive: coordinator.activeSession != nil
                    ) {
                        Task { await coordinator.recordKick() }
                    }
                    .padding(.horizontal, 24)

                    if let session = coordinator.activeSession {
                        VStack(spacing: 4) {
                            Text(L10n.counterElapsed).font(.caption).foregroundStyle(.secondary)
                            Text(session.startedAt, style: .timer)
                                .font(.title2.monospacedDigit())
                        }
                        HStack(spacing: 16) {
                            Button {
                                Task { await coordinator.undo() }
                            } label: {
                                Label(L10n.counterUndo, systemImage: "arrow.uturn.backward")
                            }
                            .disabled(session.count == 0)
                            .accessibilityIdentifier("undoButton")

                            Button(role: .destructive) {
                                confirmingCancel = true
                            } label: {
                                Label(L10n.counterCancel, systemImage: "xmark")
                            }
                            .accessibilityIdentifier("cancelSessionButton")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    } else {
                        Text(L10n.counterTapHint)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
            }
            .navigationTitle(L10n.counterTitle)
            .toolbar {
                // History lives inside the Kicks tab (spec §2.3).
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        HistoryView()
                    } label: {
                        Label(L10n.historyTitle, systemImage: "chart.bar.fill")
                    }
                    .accessibilityIdentifier("kicksHistoryButton")
                }
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: count)
            .confirmationDialog(L10n.counterCancelConfirmTitle, isPresented: $confirmingCancel, titleVisibility: .visible) {
                Button(L10n.counterCancel, role: .destructive) {
                    Task { await coordinator.cancelSession() }
                }
                Button(L10n.counterKeepCounting, role: .cancel) {}
            } message: {
                Text(L10n.counterCancelConfirmMessage)
            }
            .sheet(isPresented: completionBinding) {
                if let session = coordinator.completedSession {
                    CompletionView(session: session) { coordinator.dismissCompletion() }
                        .presentationDetents([.medium, .large])
                }
            }
            .alert(failureMessage ?? "", isPresented: failureBinding) {
                Button(L10n.commonOK) { coordinator.clearFailure() }
            }
        }
    }

    private var completionBinding: Binding<Bool> {
        Binding(
            get: { coordinator.completedSession != nil },
            set: { if !$0 { coordinator.dismissCompletion() } }
        )
    }

    private var failureMessage: String? {
        switch coordinator.failure {
        case .saveFailed: L10n.errorSave
        case .loadFailed: L10n.errorLoad
        case nil: nil
        }
    }

    private var failureBinding: Binding<Bool> {
        Binding(
            get: { coordinator.failure != nil },
            set: { if !$0 { coordinator.clearFailure() } }
        )
    }
}
