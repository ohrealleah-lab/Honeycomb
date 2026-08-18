import SwiftUI

/// Match Rules, its own full-screen sheet — opened from a nav row inside
/// HoneycombSettingsSection (Options), not from a dedicated top-bar icon. Rules/Ban
/// List/Opponent are game options like any other, so they live in Options like every
/// other per-game setting; the row itself is disabled mid-match (mac's mid-match lock),
/// same as this sheet's own content used to be when it still opened directly.
struct HoneycombMatchRulesSheet: View {
    @Bindable var viewModel: HoneycombViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    // A little breathing room between rows — spacing: 0 packed each
                    // toggle's tap target flush against its neighbor's.
                    VStack(alignment: .leading, spacing: 8) {
                        // Mirrors mac: forcing Normal Rules clears any selected rules, and
                        // picking a rule turns Force Normal back off — the two are
                        // mutually exclusive, not independent toggles.
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
                                        // Remove the exclusive partner (if any) BEFORE the
                                        // cap check — selecting a rule whose partner is
                                        // already selected is a net-zero swap, not an
                                        // addition, so it must never be blocked just
                                        // because the cap is full.
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
                    .padding(12)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))

                    Text(coordinator.L(.matchRulesHint))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
            }
            .navigationTitle(coordinator.L(.matchRulesDisclosure))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(coordinator.L(.done)) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

/// Ban List, its own full-screen sheet — see HoneycombMatchRulesSheet's header comment
/// for why this is reached from Options now instead of a dedicated top-bar icon.
struct HoneycombBanListSheet: View {
    @Bindable var viewModel: HoneycombViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        let allBanItems = ["Normal Mode"] + HoneycombRule.allCases.map { $0.rawValue }
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    // A little breathing room between rows — spacing: 0 packed each
                    // toggle's tap target flush against its neighbor's.
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(allBanItems, id: \.self) { ruleName in
                            Toggle(honeycombLocalizedRuleName(ruleName, language: coordinator.language), isOn: .init(
                                get: { viewModel.options.bannedRules.contains(ruleName) },
                                set: { on in
                                    if on {
                                        // "Silly bee" guard — mirrors mac: never allow
                                        // every item (including Normal Mode) to be banned
                                        // at once, since roulette would have nothing left
                                        // to pick.
                                        if viewModel.options.bannedRules.count < allBanItems.count - 1 {
                                            viewModel.options.bannedRules.insert(ruleName)
                                        }
                                    } else {
                                        viewModel.options.bannedRules.remove(ruleName)
                                    }
                                }
                            ))
                        }
                    }
                    .padding(12)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))

                    if viewModel.options.bannedRules.count == allBanItems.count - 1 {
                        Text(coordinator.L(.sillyBeeWarning))
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
                .padding(16)
            }
            .navigationTitle(coordinator.L(.banListDisclosure))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(coordinator.L(.done)) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
