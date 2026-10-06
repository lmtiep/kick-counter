import Accessibility
import KickCore
import SwiftUI

/// Pre-pregnancy weight (30–200 kg) and height (120–220 cm, optional): the
/// Weight screen's setup card and Profile's sheet (phase 5 spec §3.3, §3.5).
struct MaternalProfileForm: View {
    /// The setup card needs a weight; Profile may clear both.
    let requiresPreWeight: Bool
    let onSaved: () -> Void

    @Environment(WeightCoordinator.self) private var weight
    @State private var weightText = ""
    @State private var heightText = ""
    @State private var weightInvalid = false
    @State private var heightInvalid = false
    @State private var filled = false
    @State private var failure: WeightFailure?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            field(L10n.weightSetupPreWeight, text: $weightText, identifier: "weightSetupPreWeight")
                .onChange(of: weightText) { weightInvalid = false }
            if weightInvalid {
                error(L10n.weightInvalidKg, identifier: "weightSetupPreWeightError")
            }
            field(L10n.weightSetupHeight, text: $heightText, identifier: "weightSetupHeight")
                .onChange(of: heightText) { heightInvalid = false }
                .padding(.top, 6)
            if heightInvalid {
                error(L10n.weightInvalidHeight, identifier: "weightSetupHeightError")
            }
            Button(L10n.commonSave, action: save)
                .buttonStyle(.pill(.filled(.pregStrong)))
                .padding(.top, 10)
                .accessibilityIdentifier("weightSetupSave")
        }
        .onAppear(perform: fill)
        .alert(failure.map(L10n.weightFailure) ?? "", isPresented: Binding(
            get: { failure != nil },
            set: { if !$0 { failure = nil } }
        )) {
            Button(L10n.commonOK) {}
        }
    }

    private func field(_ title: String, text: Binding<String>, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.luna(.captionStrong))
                .foregroundStyle(.luna(.textSecondary))
                .accessibilityHidden(true)
            TextField(title, text: text)
                .keyboardType(.decimalPad)
                .font(.luna(.body))
                .foregroundStyle(.luna(.textPrimary))
                .padding(14)
                .background(.luna(.surface), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityLabel(title)
                .accessibilityIdentifier(identifier)
        }
    }

    private func error(_ message: String, identifier: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.luna(.caption))
            .foregroundStyle(.luna(.warningText))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(identifier)
    }

    private func fill() {
        guard !filled else { return }
        filled = true
        weightText = weight.profile.preWeightKg.map(format) ?? ""
        heightText = weight.profile.heightCm.map(format) ?? ""
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)).grouping(.never).locale(Formatting.locale))
    }

    private func save() {
        let preWeight = DecimalEntry(text: weightText, range: MaternalProfile.preWeightRange)
        let height = DecimalEntry(text: heightText, range: MaternalProfile.heightRange)
        weightInvalid = preWeight == .invalid || (requiresPreWeight && preWeight == .empty)
        heightInvalid = height == .invalid
        guard !weightInvalid, !heightInvalid else {
            AccessibilityNotification.Announcement(weightInvalid ? L10n.weightInvalidKg : L10n.weightInvalidHeight).post()
            return
        }
        let profile = MaternalProfile(preWeightKg: value(of: preWeight), heightCm: value(of: height))
        if let error = weight.updateProfile(profile) {
            weight.clearFailure()
            failure = error
        } else {
            onSaved()
        }
    }

    private func value(of entry: DecimalEntry) -> Double? {
        if case .valid(let value) = entry { return value }
        return nil
    }
}

/// Profile → "Pre-pregnancy weight · Height".
struct MaternalProfileSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // A stack only for the keyboard's "Done" toolbar; its bar stays hidden.
        NavigationStack {
            LunaSheet(title: L10n.maternalTitle, titleIdentifier: "maternalSheetTitle") {
                Text(L10n.weightSetupBody)
                    .font(.luna(.body))
                    .foregroundStyle(.luna(.articleText))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
                    .padding(.bottom, 18)
                MaternalProfileForm(requiresPreWeight: false) { dismiss() }
                Button(L10n.commonCancel) { dismiss() }
                    .buttonStyle(.pill(.text(.textSecondary), height: 44))
                    .padding(.top, 8)
                    .accessibilityIdentifier("maternalCancel")
            }
            .toolbar(.hidden, for: .navigationBar)
            .keyboardDoneButton()
        }
        .lunaSheetPresentation()
    }
}
