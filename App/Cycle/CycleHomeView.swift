import KickCore
import SwiftUI

/// A calendar day picked for the day log sheet.
struct CycleDaySelection: Identifiable {
    let date: Date
    var id: Date { date }
}

/// Trying-to-conceive mode, tab 1 (default): where the cycle stands today,
/// the next period, the fertile window, quick logging and — once the period
/// is 3 days late — "I'm pregnant".
struct CycleHomeView: View {
    @Environment(CycleCoordinator.self) private var cycle
    @State private var showingLastPeriodSheet = false
    @State private var logDay: CycleDaySelection?
    @State private var actionFailure: CycleFailure?
    @State private var working = false
    @State private var showingImPregnant = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(L10n.cycleTitle)
                .sheet(isPresented: $showingLastPeriodSheet) { LastPeriodSheet() }
                .sheet(item: $logDay) { selection in
                    CycleDayLogSheet(day: selection.date, existing: cycle.log(on: selection.date))
                }
                .sheet(isPresented: $showingImPregnant) {
                    ImPregnantSheet(lastPeriodStart: cycle.forecast?.currentPeriodStart)
                }
                .alert(failureMessage ?? "", isPresented: failureBinding) {
                    Button(L10n.commonOK) {}
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let forecast = cycle.forecast {
            ScrollView {
                cards(for: forecast)
                    .padding()
            }
        } else {
            ContentUnavailableView {
                Label(L10n.cycleEmptyTitle, systemImage: "drop.circle")
            } description: {
                Text(L10n.cycleEmptyBody)
            } actions: {
                Button(L10n.cycleEmptyAction) { showingLastPeriodSheet = true }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("cycleAddPeriodButton")
            }
        }
    }

    private func cards(for forecast: CycleForecast) -> some View {
        VStack(spacing: 16) {
            CycleStatusCard(forecast: forecast)
            if forecast.isLongOpenPeriod {
                CycleNoticeCard(
                    symbol: "drop.triangle.fill",
                    title: L10n.cycleLongPeriodTitle(forecast.cycleDay),
                    message: L10n.cycleLongPeriodBody,
                    identifier: "cycleLongPeriodCard"
                )
            }
            if forecast.isNoticeablyLate {
                lateCard(forecast)
            }
            if forecast.irregularWarning {
                CycleNoticeCard(
                    symbol: "stethoscope",
                    title: L10n.cycleIrregularTitle,
                    message: L10n.cycleIrregularBody,
                    identifier: "cycleIrregularCard"
                )
            }
            NextPeriodCard(forecast: forecast)
            // While late the window has passed; showing it beside "low chance" confuses.
            if forecast.daysLate <= 0 {
                FertileWindowCard(forecast: forecast)
            }
            quickActions(for: forecast)
            if cycle.notificationsDenied {
                Text(L10n.cycleNotificationsOff)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(L10n.cycleDisclaimer)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func lateCard(_ forecast: CycleForecast) -> some View {
        CycleNoticeCard(
            symbol: "calendar.badge.exclamationmark",
            title: L10n.cycleLateTitle(forecast.daysLate),
            message: L10n.cycleLateBody,
            identifier: "cycleLateCard"
        ) {
            Button { showingImPregnant = true } label: {
                Label(L10n.cycleImPregnant, systemImage: "heart.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("imPregnantButton")
        }
    }

    private func quickActions(for forecast: CycleForecast) -> some View {
        // A period open for weeks was never ended: offer to start the new one
        // (the coordinator closes the old one); its real end goes in the day log.
        let open = forecast.isLongOpenPeriod ? nil : forecast.openPeriod
        return VStack(spacing: 12) {
            Button {
                Task { await togglePeriod(open: open) }
            } label: {
                Label(
                    open == nil ? L10n.cycleStartPeriod : L10n.cycleEndPeriod,
                    systemImage: open == nil ? "drop.fill" : "drop"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(working)
            .accessibilityIdentifier("cyclePeriodButton")

            Button {
                logDay = CycleDaySelection(date: Calendar.current.startOfDay(for: AppClock.now()))
            } label: {
                Label(L10n.cycleLogToday, systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityIdentifier("cycleLogTodayButton")
        }
    }

    private func togglePeriod(open: PeriodRecord?) async {
        working = true
        defer { working = false }
        let failure: CycleFailure?
        if let open {
            failure = await cycle.endPeriod(id: open.id, on: AppClock.now())
        } else {
            failure = await cycle.startPeriod(on: AppClock.now())
        }
        if let failure {
            cycle.clearFailure()
            actionFailure = failure
        }
    }

    private var failureMessage: String? {
        (actionFailure ?? cycle.failure).map(L10n.cycleFailure)
    }

    /// Only while no sheet is open: the sheets report their own errors.
    private var failureBinding: Binding<Bool> {
        Binding(
            get: { failureMessage != nil && logDay == nil && !showingLastPeriodSheet && !showingImPregnant },
            set: { if !$0 { actionFailure = nil; cycle.clearFailure() } }
        )
    }
}
