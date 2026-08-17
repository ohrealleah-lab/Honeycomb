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
                VStack(alignment: .leading, spacing: 10) {
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
            HStack {
                Text(mode.localizedDisplayName(language: coordinator.language))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
            .padding(12)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func sectionHeading(_ text: String) -> some View {
        Text(text).font(.title3.weight(.bold))
    }
}
