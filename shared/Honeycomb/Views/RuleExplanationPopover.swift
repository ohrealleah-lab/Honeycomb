import SwiftUI

public struct RuleExplanationPopover: View {
    var viewModel: HoneycombViewModel
    let isRoulette: Bool
    let effectiveRules: [HoneycombRule]

    public init(viewModel: HoneycombViewModel, isRoulette: Bool, effectiveRules: [HoneycombRule]) {
        self.viewModel = viewModel
        self.isRoulette = isRoulette
        self.effectiveRules = effectiveRules
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isRoulette {
                Group {
                    Text("Roulette: ")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.yellow)
                    +
                    Text("Rules are randomized at the start of the match.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
            } else {
                ForEach(effectiveRules, id: \.self) { rule in
                    Group {
                        Text("\(rule.rawValue): ")
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(.yellow)
                        +
                        Text(rule.explanation(activeSuits: viewModel.ascensionDescensionSuits))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 300)
        .presentationBackground(Color.black.opacity(0.75))
        .environment(\.colorScheme, .dark)
    }
}
