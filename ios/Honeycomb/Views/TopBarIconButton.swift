import SwiftUI

/// Small square icon button — used for every direct entry point into a top-level
/// full-screen sheet (Game Selection / Options / Themes / Rules) instead of a single
/// generic hamburger that always lands on Games.
func topBarIconButton(systemImage: String, accessibilityLabel: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Image(systemName: systemImage)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }
    .accessibilityLabel(accessibilityLabel)
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
