import SwiftUI

/// Small square icon button — used for every direct entry point into a top-level
/// full-screen sheet (Game Selection / Options / Themes / Rules) instead of a single
/// generic hamburger that always lands on Games.
func topBarIconButton(systemImage: String, accessibilityLabel: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        TopBarIcon(systemImage: systemImage)
    }
    .accessibilityLabel(accessibilityLabel)
}

// Icon glyph in the Custom Card Colors "Top Bar Buttons" color (white by default).
private struct TopBarIcon: View {
    let systemImage: String
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        Image(systemName: systemImage)
            .font(.title3.weight(.semibold))
            .foregroundStyle(coordinator.customCardColors.toolbarButtonColor)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }
}

extension View {
    /// Top-bar `.bordered` buttons (Quit, Rematch): tinted with the "Top Bar Buttons" color.
    func topBarOutlinedTint() -> some View { modifier(TopBarOutlinedTint()) }
    /// Top-bar `.borderedProminent` button (New Deal / Start): filled with the "Top Bar
    /// Buttons" color when custom colors are on — label flips to black on light colors so
    /// it stays readable — otherwise the normal accent fill.
    func topBarFilledTint() -> some View { modifier(TopBarFilledTint()) }
}

private struct TopBarOutlinedTint: ViewModifier {
    @Environment(AppCoordinator.self) private var coordinator
    func body(content: Content) -> some View {
        content.tint(coordinator.customCardColors.toolbarButtonColor)
    }
}

private struct TopBarFilledTint: ViewModifier {
    @Environment(AppCoordinator.self) private var coordinator
    func body(content: Content) -> some View {
        let colors = coordinator.customCardColors
        if colors.isEnabled {
            let isLight = 0.299 * colors.buttonRed + 0.587 * colors.buttonGreen + 0.114 * colors.buttonBlue > 0.6
            content
                .tint(colors.buttonColor)
                .foregroundStyle(isLight ? Color.black : Color.white)
        } else {
            content
        }
    }
}

/// The three entry points every game's top bar exposes, replacing the single generic
/// hamburger icon it used to be — matches mac's toolbar exposing Game Selection and
/// Options as their own buttons. Game Selection, Options, and Themes each open their
/// own full-screen sheet directly.
@ViewBuilder
func menuBarButtons(isMenuOpen: Binding<Bool>, showingOptions: Binding<Bool>, showingThemes: Binding<Bool>, coordinator: AppCoordinator) -> some View {
    topBarIconButton(systemImage: "square.grid.2x2", accessibilityLabel: coordinator.L(.menuTabGameSelection)) {
        isMenuOpen.wrappedValue = true
    }
    topBarIconButton(systemImage: "gearshape", accessibilityLabel: coordinator.L(.options)) {
        showingOptions.wrappedValue = true
    }
    topBarIconButton(systemImage: "paintpalette", accessibilityLabel: coordinator.L(.themesPanelTitle)) {
        showingThemes.wrappedValue = true
    }
}
