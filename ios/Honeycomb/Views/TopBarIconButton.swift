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

/// Debug-only trigger menu for the current game's banners/toasts/animations — the
/// in-app counterpart to mac's native-menu-bar DebugBannerCommands (mac/src/Debug/
/// DebugBannerMenu.swift), which has no iOS equivalent since there's no menu bar here.
/// Each game's top bar passes its own available DebugBannerKinds; tapping one just sets
/// that game's `debugBannerRequest`, which its own onChange handler (or, for Honeycomb,
/// HoneycombViewModel itself) picks up. Debug-only — will be removed before TestFlight,
/// so labels are intentionally plain English, not run through L() (matches mac's own
/// "Debug-only — intentionally kept in English" precedent).
@ViewBuilder
func debugMenuButton(
    items: [(label: String, kind: DebugBannerKind)],
    // Honeycomb-only: BannerCatalog's full flavor-text catalog (DebugBannerCatalogMenu),
    // nested under its own "Toasts" sub-menu since it's ~65 entries grouped into 5
    // categories — the other five games leave this empty and only get `items` above.
    catalogSections: [(title: String, items: [(label: String, id: BannerID)])] = [],
    onSelect: @escaping (DebugBannerKind) -> Void,
    onSelectCatalog: @escaping (BannerID) -> Void = { _ in }
) -> some View {
    Menu {
        ForEach(items, id: \.label) { item in
            Button(item.label) { onSelect(item.kind) }
        }
        if !catalogSections.isEmpty {
            Divider()
            Menu("Toasts") {
                ForEach(catalogSections, id: \.title) { section in
                    Menu(section.title) {
                        ForEach(section.items, id: \.label) { item in
                            Button(item.label) { onSelectCatalog(item.id) }
                        }
                    }
                }
            }
        }
    } label: {
        Image(systemName: "ladybug.fill")
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }
    .accessibilityLabel("Debug Menu")
}
