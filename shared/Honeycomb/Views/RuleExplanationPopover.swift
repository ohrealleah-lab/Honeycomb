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
                }
            }
        }
        .padding(16)
        .frame(width: 300)
        // Matches the rules banner's own box treatment (Color.black.opacity(0.75) +
        // cornerRadius 16) so the popover reads as the same surface instead of a
        // lighter, system-chromed popover with its own default corner radius.
        .presentationBackground(Color.black.opacity(0.75))
        .presentationCornerRadius(16)
        .environment(\.colorScheme, .dark)
    }
}
