import SwiftUI

/// Full-screen Game Selection sheet — matches ThemesFullScreenView / OptionsFullScreenView
/// / HoneycombRulesSheet's styling (solid NavigationStack, Done button, section heading)
/// rather than the earlier half-height slide-down panel this replaced.
struct GameSelectionFullScreenView: View {
    @Bindable var coordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeading(coordinator.L(.menuSectionGame))
                    ForEach(GameMode.allCases) { mode in
                        gameRow(mode)
                    }
                }
                .padding(16)
            }
            .navigationTitle(coordinator.L(.menuTabGameSelection))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(coordinator.L(.done)) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func gameRow(_ mode: GameMode) -> some View {
        let isSelected = coordinator.gameMode == mode
        return Button {
            coordinator.gameMode = mode
            dismiss()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon(for: mode))
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.localizedDisplayName(language: coordinator.language))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    // Reuses the Help guide's own one-line subtitle for each game
                    // (help*Subtitle) rather than new copy — same description a
                    // player already sees in Help, just surfaced here too.
                    Text(description(for: mode))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tint)
                }
            }
            .padding(12)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func icon(for mode: GameMode) -> String {
        switch mode {
        case .klondike:   return "suit.spade.fill"
        case .beecell:    return "square.grid.2x2.fill"
        case .spider:     return "suit.club.fill"
        case .videoPoker: return "die.face.5.fill"
        case .blackjack:  return "creditcard.fill"
        case .honeycomb:  return "hexagon.fill"
        }
    }

    private func description(for mode: GameMode) -> String {
        switch mode {
        case .klondike:   return coordinator.L(.helpKlondikeSubtitle)
        case .beecell:    return coordinator.L(.helpBeecellSubtitle)
        case .spider:     return coordinator.L(.helpSpiderSubtitle)
        case .videoPoker: return coordinator.L(.helpVideopokerSubtitle)
        case .blackjack:  return coordinator.L(.helpBlackjackSubtitle)
        case .honeycomb:  return coordinator.L(.helpHoneycombSubtitle)
        }
    }

    private func sectionHeading(_ text: String) -> some View {
        Text(text).font(.title3.weight(.bold))
    }
}
