import KickCore
import SwiftUI

/// "Hôm nay bạn thế nào?" on the cycle Today (1.1 item 4, spec §4.5): from day
/// 21 after the end, at most weekly, for about 12 weeks. A tap gets one short
/// warm reply and one small tip; two low answers in a row add the "share it
/// with someone close" line. No hotline, no medical words. The answers stay in
/// `AppGroup.defaults` on this phone.
struct CareCheckInCard: View {
    @Environment(CycleCoordinator.self) private var cycle
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var state = CareCheckInState.load(from: AppGroup.defaults)
    /// The answer just given: the reply stays until "Đóng".
    @State private var answer: CareFeeling?

    var body: some View {
        Group {
            if let end = cycle.endState {
                if let answer {
                    reply(answer, branch: end.branch)
                } else if CareCheckInPolicy.isDue(end: end, state: state, now: AppClock.now(), calendar: .current) {
                    question
                }
            }
        }
        .onAppear { state = CareCheckInState.load(from: AppGroup.defaults) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { state = CareCheckInState.load(from: AppGroup.defaults) }
        }
    }

    // MARK: - The question

    private var question: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.careTitle)
                .font(.luna(.cardTitle))
                .foregroundStyle(.luna(.textPrimary))
                .accessibilityAddTraits(.isHeader)
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    ForEach(CareFeeling.allCases, id: \.self) { feeling in
                        feelingButton(feeling, vertical: false)
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 6) {
                    ForEach(CareFeeling.allCases, id: \.self) { feeling in
                        feelingButton(feeling, vertical: true)
                    }
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { skipButton; Spacer(minLength: 0); stopButton }
                VStack(alignment: .leading, spacing: 4) { skipButton; stopButton }
            }
        }
        .lunaCard(.cycleSoft)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("careCheckInCard")
    }

    private func feelingButton(_ feeling: CareFeeling, vertical: Bool) -> some View {
        Button { answer(feeling) } label: {
            let icon = Image(systemName: Self.symbol(feeling))
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.luna(.cycleOnSoft))
                .frame(width: 44, height: 44)
                .background(Circle().fill(.luna(.card)))
                .accessibilityHidden(true)
            let label = Text(L10n.careFeeling(feeling))
                .font(.luna(.small))
                .foregroundStyle(.luna(.textPrimary))
                .multilineTextAlignment(vertical ? .center : .leading)
                .fixedSize(horizontal: false, vertical: true)
            if vertical {
                VStack(spacing: 6) { icon; label }
                    .frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 12) { icon; label.frame(maxWidth: .infinity, alignment: .leading) }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.careFeeling(feeling))
        .accessibilityIdentifier("careFeeling-\(feeling.rawValue)")
    }

    private var skipButton: some View {
        Button(L10n.careSkip) { skip() }
            .buttonStyle(.pill(.text(.cycleOnSoft), fullWidth: false, height: 44))
            .accessibilityIdentifier("careSkip")
    }

    private var stopButton: some View {
        Button(L10n.careStop) { stop() }
            .buttonStyle(.pill(.text(.cycleOnSoft), fullWidth: false, height: 44))
            .accessibilityIdentifier("careStop")
    }

    /// Soft symbols: weather for the mood, nothing clinical.
    static func symbol(_ feeling: CareFeeling) -> String {
        switch feeling {
        case .good: "sun.max"
        case .okay: "cloud.sun"
        case .tired: "moon.zzz"
        case .sad: "cloud.drizzle"
        case .heavy: "cloud.rain"
        }
    }

    // MARK: - The reply

    private func reply(_ feeling: CareFeeling, branch: PregnancyEndBranch) -> some View {
        let tip = CareCheckInPolicy.tipIndex(now: AppClock.now(), calendar: .current, count: L10n.careTipCount)
        return VStack(alignment: .leading, spacing: 12) {
            Text(L10n.careReply(feeling, branch: branch))
                .font(.luna(.bodyStrong))
                .foregroundStyle(.luna(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("careReply")
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.careTipTitle)
                    .font(.luna(.captionStrong))
                    .foregroundStyle(.luna(.cycleOnSoft))
                Text(L10n.careTip(tip))
                    .font(.luna(.body))
                    .foregroundStyle(.luna(.textPrimary))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("careTip")
            }
            if CareCheckInPolicy.showsShareLine(state) {
                Text(L10n.careShare)
                    .font(.luna(.body))
                    .foregroundStyle(.luna(.textPrimary))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("careShareLine")
            }
            Button(L10n.commonClose) { answer = nil }
                .buttonStyle(.pill(.text(.cycleOnSoft), fullWidth: false, height: 44))
                .accessibilityIdentifier("careClose")
        }
        .lunaCard(.cycleSoft)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("careCheckInReply")
    }

    // MARK: - Actions

    private func answer(_ feeling: CareFeeling) {
        update(CareCheckInPolicy.record(feeling, state: state, now: AppClock.now()))
        answer = feeling
    }

    private func skip() {
        update(CareCheckInPolicy.record(nil, state: state, now: AppClock.now()))
    }

    /// "Cảm ơn, mình ổn rồi": no more check-ins, and no more notification.
    private func stop() {
        var stopped = state
        stopped.stopped = true
        update(stopped)
    }

    private func update(_ newState: CareCheckInState) {
        state = newState
        newState.save(to: AppGroup.defaults)
        Task { await CareCheckInNotifications.sync() }
    }
}
