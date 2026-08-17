import SwiftUI

/// Match Rules + Ban List, split out of Options into their own full-screen sheet
/// (matches ThemesFullScreenView / OptionsFullScreenView's styling) so rule/ban editing
/// isn't buried two disclosure groups deep inside general Options — opened directly from
/// the top bar's Rules icon.
struct HoneycombRulesSheet: View {
    @Bindable var viewModel: HoneycombViewModel
    let isMidMatch: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    opponentSection
                        .disabled(isMidMatch)
                        .opacity(isMidMatch ? 0.5 : 1)

                    VStack(alignment: .leading, spacing: 24) {
                        matchRulesSection
                        banListSection
                    }
                    .disabled(isMidMatch)
                    .opacity(isMidMatch ? 0.5 : 1)

                    if isMidMatch {
                        Text(coordinator.L(.settingsUnlockNote))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
            }
            .navigationTitle(coordinator.L(.toolbarRules))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(coordinator.L(.done)) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var opponentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading(coordinator.L(.opponentPickerLabel))
            Picker(coordinator.L(.opponentPickerLabel), selection: $viewModel.options.difficulty) {
                ForEach(HoneycombDifficulty.allCases, id: \.self) { d in
                    Text(honeycombLocalizedDifficultyName(d, language: coordinator.language)).tag(d)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }

    private var matchRulesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading(coordinator.L(.matchRulesDisclosure))
            Text(coordinator.L(.matchRulesHint))
                .font(.caption)
                .foregroundColor(.secondary)

            // Mirrors mac: forcing Normal Rules clears any selected rules, and picking
            // a rule turns Force Normal back off — the two are mutually exclusive, not
            // independent toggles.
            Toggle(coordinator.L(.forceNormalRulesToggle), isOn: .init(
                get: { viewModel.options.forceNormalMode },
                set: { on in
                    viewModel.options.forceNormalMode = on
                    if on { viewModel.options.selectedRules.removeAll() }
                }
            ))

            ForEach(HoneycombRule.allCases.filter { $0 != .reverse }, id: \.self) { rule in
                Toggle(honeycombLocalizedRuleName(rule.rawValue, language: coordinator.language), isOn: .init(
                    get: { viewModel.options.selectedRules.contains(rule) },
                    set: { on in
                        if on {
                            // Remove the exclusive partner (if any) BEFORE the cap
                            // check — selecting a rule whose partner is already
                            // selected is a net-zero swap, not an addition, so it
                            // must never be blocked just because the cap is full.
                            var updated = viewModel.options.selectedRules
                            if rule == .ascension { updated.remove(.descension) }
                            if rule == .descension { updated.remove(.ascension) }
                            if rule == .order { updated.remove(.chaos) }
                            if rule == .chaos { updated.remove(.order) }
                            if rule == .allOpen { updated.remove(.threeOpen) }
                            if rule == .threeOpen { updated.remove(.allOpen) }
                            // Bomb Shelter's hidden card doesn't work when All
                            // Open/Three Open reveals every card anyway.
                            if rule == .allOpen || rule == .threeOpen { updated.remove(.bombShelter) }
                            if rule == .bombShelter { updated.remove(.allOpen); updated.remove(.threeOpen) }

                            guard updated.count < 4 else { return }
                            updated.insert(rule)
                            viewModel.options.selectedRules = updated
                            viewModel.options.forceNormalMode = false
                        } else {
                            viewModel.options.selectedRules.remove(rule)
                        }
                    }
                ))
                .disabled(viewModel.options.forceNormalMode)
            }
        }
    }

    private var banListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading(coordinator.L(.banListDisclosure))
            let allBanItems = ["Normal Mode"] + HoneycombRule.allCases.map { $0.rawValue }
            ForEach(allBanItems, id: \.self) { ruleName in
                Toggle(honeycombLocalizedRuleName(ruleName, language: coordinator.language), isOn: .init(
                    get: { viewModel.options.bannedRules.contains(ruleName) },
                    set: { on in
                        if on {
                            // "Silly bee" guard — mirrors mac: never allow every item
                            // (including Normal Mode) to be banned at once, since
                            // roulette would have nothing left to pick.
                            if viewModel.options.bannedRules.count < allBanItems.count - 1 {
                                viewModel.options.bannedRules.insert(ruleName)
                            }
                        } else {
                            viewModel.options.bannedRules.remove(ruleName)
                        }
                    }
                ))
            }
            if viewModel.options.bannedRules.count == allBanItems.count - 1 {
                Text(coordinator.L(.sillyBeeWarning))
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
    }

    private func sectionHeading(_ text: String) -> some View {
        Text(text).font(.title3.weight(.bold))
    }
}
