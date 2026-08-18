import SwiftUI

public struct RuleExplanationPopover: View {
    var viewModel: HoneycombViewModel
    let isRoulette: Bool
    let effectiveRules: [HoneycombRule]
    @Environment(AppCoordinator.self) private var coordinator

    public init(viewModel: HoneycombViewModel, isRoulette: Bool, effectiveRules: [HoneycombRule]) {
        self.viewModel = viewModel
        self.isRoulette = isRoulette
        self.effectiveRules = effectiveRules
    }

    public var body: some View {
        // With 3-4 active rules, the stacked explanations can exceed the popover's
        // available height — a bare VStack has no scroll fallback, so the system
        // popover just clips whatever doesn't fit (mid-sentence, no indication more
        // content exists). ScrollView + a height cap lets it scroll instead.
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if isRoulette {
                    Group {
                        Text(coordinator.L(.rouletteColonPrefix))
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(.yellow)
                        +
                        Text(coordinator.L(.rulesRandomizedAtStart))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                    // Without this, the popover's own sizing pass measures concatenated Text
                    // (built with `+`, which loses the normal per-Text line-wrapping info a
                    // popover uses to compute its content height) as if it fit on one line,
                    // then truncates whatever doesn't — forcing an explicit wrap-to-width
                    // height calculation here instead of leaving it to the popover's default.
                    .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(effectiveRules, id: \.self) { rule in
                        Group {
                            Text(coordinator.L(.ruleNameColonFmt, honeycombLocalizedRuleName(rule.rawValue, language: coordinator.language)))
                                .font(.system(size: 14, weight: .black))
                                .foregroundColor(.yellow)
                            +
                            Text(honeycombLocalizedRuleExplanation(rule, activeSuits: viewModel.ascensionDescensionSuits, language: coordinator.language))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(16)
        }
        .frame(width: 300)
        .frame(maxHeight: 400)
        // Matches the rules banner's own box treatment (Color.black.opacity(0.75) +
        // cornerRadius 16) so the popover reads as the same surface instead of a
        // lighter, system-chromed popover with its own default corner radius.
        .presentationBackground(Color.black.opacity(0.75))
        .presentationCornerRadius(16)
        .environment(\.colorScheme, .dark)
    }
}
