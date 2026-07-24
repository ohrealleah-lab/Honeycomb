import SwiftUI

// Environment keys card views read for theming. Shared because HoneycombCardView (and
// eventually the other card renderers) draw with them on every platform; each platform's
// game views inject the values from AppCoordinator.

private struct FeltColorKey: EnvironmentKey {
    static let defaultValue: FeltColorTheme = .feltGreen
}

private struct ActiveCardBackThemeKey: EnvironmentKey {
    static let defaultValue: String = "Moogle"
}

private struct ActiveCustomCardColorsKey: EnvironmentKey {
    static let defaultValue: CustomCardColorGroup = CustomCardColorGroup()
}

extension EnvironmentValues {
    public var feltColor: FeltColorTheme {
        get { self[FeltColorKey.self] }
        set { self[FeltColorKey.self] = newValue }
    }
    public var activeCardBackTheme: String {
        get { self[ActiveCardBackThemeKey.self] }
        set { self[ActiveCardBackThemeKey.self] = newValue }
    }
    public var activeCustomCardColors: CustomCardColorGroup {
        get { self[ActiveCustomCardColorsKey.self] }
        set { self[ActiveCustomCardColorsKey.self] = newValue }
    }
}
