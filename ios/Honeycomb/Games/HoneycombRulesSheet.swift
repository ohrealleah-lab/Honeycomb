import SwiftUI

/// Opponent + Rules — its own top-bar icon and full-screen sheet, only ever reachable
/// out of play (the icon that opens this is hidden mid-match, same as Manage Decks), so
/// nothing in here needs its own mid-match disabled/dimmed state the way it did for the
/// brief period both lived inside Options instead. Opponent sits at the top, above the
/// existing rules content (game choice + ban list merged into one screen). Each rule
/// gets one Auto/Pick/Ban control instead of two separate toggles (Game Choice's Toggle
/// + Ban List's Toggle) living in two separate screens — mirrors mac's
/// HoneycombRulesView, sharing its validation via HoneycombRuleSelection.
struct HoneycombRulesSheet: View {
    @Bindable var viewModel: HoneycombViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    // .pickerStyle(.menu) outside a Form/List only renders the selected
                    // value + chevron as a button — the Picker's own label text is
                    // silently dropped (same issue found and fixed in Video Poker's
                    // Variant/Default Bet pickers).
                    HStack {
                        Text(coordinator.L(.opponentPickerLabel))
                        Spacer()
                        Picker(coordinator.L(.opponentPickerLabel), selection: $viewModel.options.difficulty) {
                            ForEach(HoneycombDifficulty.allCases, id: \.self) { d in
                                Text(honeycombLocalizedDifficultyName(d, language: coordinator.language)).tag(d)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    // Matches ruleRow's own .padding(.horizontal, 12) below — without
                    // this, Opponent's label sits flush with the outer VStack's edge
                    // while every rule row's label is inset an extra 12pt, reading as
                    // misaligned against the card directly beneath it.
                    .padding(.horizontal, 12)

                    VStack(spacing: 0) {
                        ForEach(HoneycombRuleRowID.banListOrder, id: \.self) { id in
                            ruleRow(id)
                            if id != HoneycombRuleRowID.banListOrder.last {
                                Divider()
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))

                    Text(coordinator.L(.matchRulesHint))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Visible explanation of what each rule/Normal Mode does — every row
                    // above already has this text via rowExplanation(id), but on mac
                    // that's only ever surfaced as a .help() hover tooltip, which has no
                    // touch equivalent, so iOS never showed it anywhere. Same "• Name:
                    // explanation" format as HoneycombHelpView's own Match Modifiers
                    // section (shared/Views/HelpGuideView.swift) for consistency.
                    Text(HoneycombRuleRowID.banListOrder.map { id in
                        "• \(rowTitle(id)): \(rowExplanation(id))"
                    }.joined(separator: "\n"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if viewModel.options.bannedRules.count == HoneycombRuleRowID.banListOrder.count - 1 {
                        Text(coordinator.L(.sillyBeeWarning))
                            .font(.caption2)
                            .foregroundStyle(.red)
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
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func rowState(_ id: HoneycombRuleRowID) -> HoneycombRuleState {
        HoneycombRuleSelection.state(
            of: id,
            selectedRules: viewModel.options.selectedRules,
            forceNormalMode: viewModel.options.forceNormalMode,
            bannedRules: viewModel.options.bannedRules
        )
    }

    private func setRowState(_ newState: HoneycombRuleState, for id: HoneycombRuleRowID) {
        var selected = viewModel.options.selectedRules
        var force = viewModel.options.forceNormalMode
        var banned = viewModel.options.bannedRules
        HoneycombRuleSelection.setState(newState, for: id, selectedRules: &selected, forceNormalMode: &force, bannedRules: &banned)
        viewModel.options.selectedRules = selected
        viewModel.options.forceNormalMode = force
        viewModel.options.bannedRules = banned
    }

    private func rowTitle(_ id: HoneycombRuleRowID) -> String {
        switch id {
        case .normalMode: return coordinator.L(.forceNormalRulesToggle)
        case .rule(let rule): return honeycombLocalizedRuleName(rule.rawValue, language: coordinator.language)
        }
    }

    private func rowExplanation(_ id: HoneycombRuleRowID) -> String {
        switch id {
        case .normalMode: return coordinator.L(.normalModeBanListTooltip)
        case .rule(let rule): return honeycombLocalizedRuleExplanation(rule, language: coordinator.language)
        }
    }

    @ViewBuilder
    private func ruleRow(_ id: HoneycombRuleRowID) -> some View {
        let state = rowState(id)
        HStack(spacing: 10) {
            Text(rowTitle(id))
                .font(.subheadline.weight(.semibold))
                .strikethrough(state == .banned)
                .foregroundColor(state == .banned ? .secondary : .primary)
            Spacer(minLength: 8)
            HStack(spacing: 0) {
                stateSegment(coordinator.L(.ruleStateBan), isSelected: state == .banned, fill: .red, textColor: .white, corner: .leading) { setRowState(.banned, for: id) }
                Divider().frame(height: 14)
                stateSegment("–", isSelected: state == .auto, fill: Color(uiColor: .secondarySystemGroupedBackground), textColor: .primary, corner: .none) { setRowState(.auto, for: id) }
                    .accessibilityLabel(coordinator.L(.ruleStateAuto))
                Divider().frame(height: 14)
                    .opacity(id.isPickable ? 1 : 0)
                // Inversion (not pickable) still renders this segment — invisible and
                // inert — rather than omitting it, so its row's track is the same width
                // as every other row's instead of shrinking and drifting off the
                // shared left-aligned Ban position.
                stateSegment(coordinator.L(.ruleStatePick), isSelected: state == .picked, fill: .accentColor, textColor: .white, corner: .trailing) { setRowState(.picked, for: id) }
                    .opacity(id.isPickable ? 1 : 0)
                    .disabled(!id.isPickable)
            }
            .padding(2)
            .background(Color.primary.opacity(0.08))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        // Inert on a plain touch (no true hover on iPhone), but surfaces on iPadOS
        // with a trackpad/mouse's pointer hover, matching mac's .help() on this row.
        .help(rowExplanation(id))
    }

    private enum SegmentCorner { case leading, trailing, none }

    private func stateSegment(_ label: String, isSelected: Bool, fill: Color, textColor: Color, corner: SegmentCorner, action: @escaping () -> Void) -> some View {
        // Rounding each end segment's own fill (rather than relying only on the
        // group's outer .clipShape) — a plain Button's background can otherwise
        // render in its own compositing layer that ignores an ancestor's clip,
        // leaving the trailing (Play) corner looking squared-off instead of capped.
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: corner == .leading ? 11 : 0,
            bottomLeadingRadius: corner == .leading ? 11 : 0,
            bottomTrailingRadius: corner == .trailing ? 11 : 0,
            topTrailingRadius: corner == .trailing ? 11 : 0
        )
        return Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(isSelected ? textColor : .secondary)
                .frame(minWidth: 34)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(isSelected ? fill : Color.clear)
                .clipShape(shape)
                // Without this, the button's tap target is just the Text's own tight
                // glyph bounds, not the padded pill around it.
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
