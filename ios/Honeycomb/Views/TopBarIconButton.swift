import SwiftUI

/// Small square icon button — used for every direct entry point into SlideDownMenu
/// (Game Selection / Options / Themes / Rules), each opening it pre-set to a specific
/// tab instead of a single generic hamburger that always lands on Games.
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

/// The three entry points every game's top bar exposes into SlideDownMenu, replacing
/// the single generic hamburger icon it used to be — matches mac's toolbar exposing
/// Game Selection and Options as their own buttons (mac has no separate Themes button;
/// iOS gets one anyway since Themes is otherwise two taps deep on a touch device).
@ViewBuilder
func menuBarButtons(menuTab: Binding<MenuTab>, isMenuOpen: Binding<Bool>, coordinator: AppCoordinator) -> some View {
    topBarIconButton(systemImage: "square.grid.2x2", accessibilityLabel: coordinator.L(.menuTabGameSelection)) {
        menuTab.wrappedValue = .games
        isMenuOpen.wrappedValue = true
    }
    topBarIconButton(systemImage: "gearshape", accessibilityLabel: coordinator.L(.options)) {
        menuTab.wrappedValue = .options
        isMenuOpen.wrappedValue = true
    }
    topBarIconButton(systemImage: "paintpalette", accessibilityLabel: coordinator.L(.themesPanelTitle)) {
        menuTab.wrappedValue = .themes
        isMenuOpen.wrappedValue = true
    }
}
