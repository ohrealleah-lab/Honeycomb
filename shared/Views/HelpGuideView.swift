import SwiftUI

// MARK: - Shared Help UI

private struct RuleSection: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ShortcutRow: View {
    let action: String
    let shortcut: String

    var body: some View {
        HStack(alignment: .top) {
            Text(action)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(shortcut)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

private struct HelpShell<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content
    @Environment(\.dismiss) private var dismiss
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.largeTitle).bold()
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(coordinator.L(.done)) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding([.top, .horizontal], 24)
            .padding(.bottom, 16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    content()
                }
                .padding(24)
            }
        }
        .frame(width: 520, height: 560)
    }
}

// MARK: - Klondike Guide

struct KlondikeHelpView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        HelpShell(title: coordinator.L(.helpKlondikeTitle), subtitle: coordinator.L(.helpKlondikeSubtitle)) {
            RuleSection(title: coordinator.L(.helpOverviewObjectiveTitle),
                        text: coordinator.L(.helpKlondikeObjective))

            RuleSection(title: coordinator.L(.helpSetupLayoutTitle),
                        text: coordinator.L(.helpKlondikeLayout))

            RuleSection(title: coordinator.L(.helpRulesHowToPlayTitle),
                        text: coordinator.L(.helpKlondikeRules))

            VStack(alignment: .leading, spacing: 6) {
                Text(coordinator.L(.helpControlsShortcutsTitle))
                    .font(.headline)
                VStack(alignment: .leading, spacing: 4) {
                    ShortcutRow(action: coordinator.L(.helpShortcutNavigateBoardCursor), shortcut: coordinator.L(.helpShortcutArrowKeys))
                    ShortcutRow(action: coordinator.L(.helpShortcutSelectPlaceCard), shortcut: coordinator.L(.helpShortcutSpaceEnter))
                    ShortcutRow(action: coordinator.L(.helpShortcutClearSelection), shortcut: "Escape")
                    ShortcutRow(action: coordinator.L(.helpShortcutDrawCards), shortcut: "D")
                    ShortcutRow(action: coordinator.L(.helpShortcutAutoMoveFoundation), shortcut: "F")
                    ShortcutRow(action: coordinator.L(.autocompleteGame), shortcut: "A")
                    ShortcutRow(action: coordinator.L(.helpShortcutNewGameRestartDeal), shortcut: coordinator.L(.helpShortcutCmdNR))
                    ShortcutRow(action: coordinator.L(.helpShortcutUndoMove), shortcut: coordinator.L(.helpShortcutCmdZ))
                    ShortcutRow(action: coordinator.L(.helpShortcutToggleDraw), shortcut: "⌥⌘1 / ⌥⌘3")
                    ShortcutRow(action: coordinator.L(.helpShortcutCycleHints), shortcut: coordinator.L(.helpShortcutHintButton))
                }
            }

            RuleSection(title: coordinator.L(.helpStrategyProTipsTitle),
                        text: coordinator.L(.helpKlondikeStrategy))

            RuleSection(title: coordinator.L(.helpNoStressModeTitle),
                        text: coordinator.L(.helpKlondikeNoStress))
        }
    }
}

// MARK: - Beecell Guide

struct BeecellHelpView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        HelpShell(title: coordinator.L(.helpBeecellTitle), subtitle: coordinator.L(.helpBeecellSubtitle)) {
            RuleSection(title: coordinator.L(.helpOverviewObjectiveTitle),
                        text: coordinator.L(.helpBeecellObjective))

            RuleSection(title: coordinator.L(.helpSetupLayoutTitle),
                        text: coordinator.L(.helpBeecellLayout))

            RuleSection(title: coordinator.L(.helpRulesHowToPlayTitle),
                        text: coordinator.L(.helpBeecellRules))

            VStack(alignment: .leading, spacing: 6) {
                Text(coordinator.L(.helpControlsShortcutsTitle))
                    .font(.headline)
                VStack(alignment: .leading, spacing: 4) {
                    ShortcutRow(action: coordinator.L(.helpShortcutNavigateSelect), shortcut: "Arrow Keys + Space / Enter")
                    ShortcutRow(action: coordinator.L(.helpShortcutAutoParkFreeCell), shortcut: "C")
                    ShortcutRow(action: coordinator.L(.helpShortcutAutoMoveFoundation), shortcut: "F")
                    ShortcutRow(action: coordinator.L(.autocompleteGame), shortcut: "A")
                    ShortcutRow(action: coordinator.L(.helpShortcutNewGameRestartDeal), shortcut: coordinator.L(.helpShortcutCmdNR))
                    ShortcutRow(action: coordinator.L(.helpShortcutUndoMove), shortcut: coordinator.L(.helpShortcutCmdZ))
                    ShortcutRow(action: coordinator.L(.hint), shortcut: coordinator.L(.helpShortcutHintButton))
                }
            }

            RuleSection(title: coordinator.L(.helpStrategyProTipsTitle),
                        text: coordinator.L(.helpBeecellStrategy))

            RuleSection(title: coordinator.L(.helpNoStressModeTitle),
                        text: coordinator.L(.helpKlondikeNoStress))
        }
    }
}

// MARK: - Spider Solibee Guide

struct SpiderHelpView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        HelpShell(title: coordinator.L(.helpSpiderTitle), subtitle: coordinator.L(.helpSpiderSubtitle)) {
            RuleSection(title: coordinator.L(.helpOverviewObjectiveTitle),
                        text: coordinator.L(.helpSpiderObjective))

            RuleSection(title: coordinator.L(.helpSetupLayoutTitle),
                        text: coordinator.L(.helpSpiderLayout))

            RuleSection(title: coordinator.L(.helpRulesHowToPlayTitle),
                        text: coordinator.L(.helpSpiderRules))

            VStack(alignment: .leading, spacing: 6) {
                Text(coordinator.L(.helpControlsShortcutsTitle))
                    .font(.headline)
                VStack(alignment: .leading, spacing: 4) {
                    ShortcutRow(action: coordinator.L(.helpShortcutDeal10Cards), shortcut: "D")
                    ShortcutRow(action: coordinator.L(.helpShortcutSelectPlaceSequence), shortcut: coordinator.L(.helpShortcutSpaceEnter))
                    ShortcutRow(action: coordinator.L(.helpShortcut1suit2suitMode), shortcut: "⌥⌘1 / ⌥⌘2")
                    ShortcutRow(action: coordinator.L(.helpShortcutAutocomplete), shortcut: "A")
                    ShortcutRow(action: coordinator.L(.helpShortcutUndoMove), shortcut: coordinator.L(.helpShortcutCmdZ))
                }
            }

            RuleSection(title: coordinator.L(.helpStrategyProTipsTitle),
                        text: coordinator.L(.helpSpiderStrategy))

            RuleSection(title: coordinator.L(.helpNoStressModeTitle),
                        text: coordinator.L(.helpKlondikeNoStress))
        }
    }
}

// MARK: - Video Poker Guide

struct VideoPokerHelpView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        HelpShell(title: coordinator.L(.helpVideopokerTitle), subtitle: coordinator.L(.helpVideopokerSubtitle)) {
            RuleSection(title: coordinator.L(.helpOverviewObjectiveTitle),
                        text: coordinator.L(.helpVideopokerObjective))

            RuleSection(title: coordinator.L(.helpHowToPlayVariantsTitle),
                        text: coordinator.L(.helpVideopokerHowToPlay))

            VStack(alignment: .leading, spacing: 6) {
                Text(coordinator.L(.helpControlsShortcutsTitle))
                    .font(.headline)
                VStack(alignment: .leading, spacing: 4) {
                    ShortcutRow(action: coordinator.L(.helpShortcutDealDraw), shortcut: coordinator.L(.helpShortcutSpaceEnter))
                    ShortcutRow(action: coordinator.L(.helpShortcutHoldCard12345), shortcut: coordinator.L(.helpShortcut12345))
                    ShortcutRow(action: coordinator.L(.helpShortcutHoldAllCards), shortcut: "H")
                    ShortcutRow(action: coordinator.L(.helpShortcutClearAllHolds), shortcut: coordinator.L(.helpShortcutCQ))
                    ShortcutRow(action: coordinator.L(.helpShortcutBetMaxDeal), shortcut: "M")
                }
            }

            RuleSection(title: coordinator.L(.helpStrategyProTipsTitle),
                        text: coordinator.L(.helpVideopokerStrategy))

            RuleSection(title: coordinator.L(.helpNoStressModeTitle),
                        text: coordinator.L(.helpVideopokerNoStress))
        }
    }
}

// MARK: - Video Blackjack Guide

struct BlackjackHelpView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        HelpShell(title: coordinator.L(.helpBlackjackTitle), subtitle: coordinator.L(.helpBlackjackSubtitle)) {
            RuleSection(title: coordinator.L(.helpOverviewObjectiveTitle),
                        text: coordinator.L(.helpBlackjackObjective))

            RuleSection(title: coordinator.L(.helpRulesOptionsTitle),
                        text: coordinator.L(.helpBlackjackRules))

            VStack(alignment: .leading, spacing: 6) {
                Text(coordinator.L(.helpControlsShortcutsTitle))
                    .font(.headline)
                VStack(alignment: .leading, spacing: 4) {
                    ShortcutRow(action: coordinator.L(.helpShortcutDealBuyIn), shortcut: coordinator.L(.helpShortcutSpaceEnter))
                    ShortcutRow(action: coordinator.L(.helpShortcutHit), shortcut: "H")
                    ShortcutRow(action: coordinator.L(.helpShortcutStand), shortcut: "S")
                    ShortcutRow(action: coordinator.L(.helpShortcutDoubleDown), shortcut: "D")
                    ShortcutRow(action: coordinator.L(.helpShortcutSplitPairs), shortcut: "P")
                    ShortcutRow(action: coordinator.L(.helpShortcutBetMaxDeal), shortcut: "M")
                }
            }

            RuleSection(title: coordinator.L(.helpStrategyProTipsTitle),
                        text: coordinator.L(.helpBlackjackStrategy))

            RuleSection(title: coordinator.L(.helpNoStressModeTitle),
                        text: coordinator.L(.helpBlackjackNoStress))
        }
    }
}

// MARK: - Honeycomb Guide

struct HoneycombHelpView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        HelpShell(title: coordinator.L(.appName), subtitle: coordinator.L(.helpHoneycombSubtitle)) {
            RuleSection(title: coordinator.L(.helpOverviewObjectiveTitle),
                        text: coordinator.L(.helpHoneycombObjective))

            RuleSection(title: coordinator.L(.helpCoreGameplayMechanicsTitle),
                        text: coordinator.L(.helpHoneycombMechanics))

            RuleSection(title: coordinator.L(.helpMatchModifiersTitle),
                        text: HoneycombRule.allCases.map {
                            "• \(honeycombLocalizedRuleName($0.rawValue, language: coordinator.language)): \(honeycombLocalizedRuleExplanation($0, language: coordinator.language))"
                        }.joined(separator: "\n"))

            RuleSection(title: coordinator.L(.helpCardBankStealingTitle),
                        text: coordinator.L(.helpHoneycombCardBank))

            VStack(alignment: .leading, spacing: 6) {
                Text(coordinator.L(.helpControlsShortcutsTitle))
                    .font(.headline)
                VStack(alignment: .leading, spacing: 4) {
                    ShortcutRow(action: coordinator.L(.helpShortcutSelectPlaceCard), shortcut: coordinator.L(.helpShortcutClickDragTap))
                    ShortcutRow(action: coordinator.L(.helpShortcutShowBestAiMove), shortcut: coordinator.L(.helpShortcutHintButton))
                }
            }

            RuleSection(title: coordinator.L(.helpNoStressModeTitle),
                        text: coordinator.L(.helpHoneycombNoStress))
        }
    }
}

// MARK: - Themes Help Guide

struct ThemesHelpView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        HelpShell(title: coordinator.L(.helpThemesTitle), subtitle: coordinator.L(.helpThemesSubtitle)) {
            RuleSection(title: coordinator.L(.helpThemesCustomizationTitle),
                        text: coordinator.L(.helpCustomizationThemes))

            RuleSection(title: coordinator.L(.helpOptionsTitle),
                        text: coordinator.L(.helpCustomizationOptions))
        }
    }
}

// MARK: - Previews

#Preview("Klondike Help") { KlondikeHelpView() }
#Preview("Beecell Help") { BeecellHelpView() }
#Preview("Spider Help") { SpiderHelpView() }
#Preview("Video Poker Help") { VideoPokerHelpView() }
#Preview("Blackjack Help") { BlackjackHelpView() }
#Preview("Honeycomb Help") { HoneycombHelpView() }
#Preview("Themes Help") { ThemesHelpView() }
