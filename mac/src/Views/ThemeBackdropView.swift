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

    // Unlike the main board's BackgroundLayerView, this preview isn't guaranteed the
    // active background is already synchronously cached (AppCoordinator only warms that
    // for the one background active at app launch — flipping through other saved
    // Themes/backgrounds here can hit an uncached one). CustomBackgroundManager.image(for:)
    // returns nil on a cache miss and loads it async, so without subscribing to its
    // completion notification this view would flash the felt-color fallback and then
    // just stay on it — nothing else here forces a re-render once the load finishes.
    @State private var loadTrigger: UUID = UUID()

    var body: some View {
        ZStack {
            if let name = customBackgroundName,
               let background = CustomBackgroundManager.shared.customBackgrounds.first(where: { $0.name == name }),
               let image = CustomBackgroundManager.shared.image(for: background.relativePath) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if coordinator.feltColor == .transparent {
                // Preview-only: a clear table shows as a checkerboard so it reads as see-through.
                CheckerboardView()
            } else {
                coordinator.currentFeltColor
            }
        }
        .id(loadTrigger)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CustomBackgroundLoaded"))) { _ in
            loadTrigger = UUID()
        }
    }
}


/// Grey checkerboard used by theme previews to show a see-through table.
struct CheckerboardView: View {
    var cell: CGFloat = 10
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(white: 0.9)))
            let dark = Color(white: 0.74)
            var y: CGFloat = 0, row = 0
            while y < size.height {
                var x: CGFloat = row % 2 == 0 ? 0 : cell
                while x < size.width {
                    ctx.fill(Path(CGRect(x: x, y: y, width: cell, height: cell)), with: .color(dark))
                    x += cell * 2
                }
                y += cell; row += 1
            }
        }
    }
}
