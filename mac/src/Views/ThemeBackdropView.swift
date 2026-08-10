import SwiftUI

/// Renders whatever the active theme's backdrop actually is — the real configured
/// background image when one's set, otherwise the resolved felt color — for both the
/// hero card-on-backdrop preview (ThemesOptionsView) and the Custom Card Colors mock
/// cards (CardColorsOptionsView). Factored into one shared view (rather than duplicating
/// the felt/background-image branch in both places, the way Windows' code-behind kept
/// them separate) since both call sites need exactly the same branching logic.
struct ThemeBackdropView: View {
    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator
    let customBackgroundName: String?

    var body: some View {
        ZStack {
            if let name = customBackgroundName,
               let background = CustomBackgroundManager.shared.customBackgrounds.first(where: { $0.name == name }),
               let image = CustomBackgroundManager.shared.image(for: background.relativePath) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                coordinator.currentFeltColor
            }
        }
    }
}
