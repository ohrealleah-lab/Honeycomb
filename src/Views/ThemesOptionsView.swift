import SwiftUI

/// Themes sub-panel that slides over any game's OptionsView.
/// All theme-related controls live here: vignette, saved themes,
/// felt color, custom color, card deck + face art.
struct ThemesOptionsView: View {
    @Binding var isShowing: Bool
    @Binding var isOptionsPresented: Bool
    @Binding var feltColor: FeltColorTheme
    @Binding var cardBackTheme: String
    @Binding var showFeltVignette: Bool
    @Binding var customSelectedColor: Color
    @Binding var customCardColors: CustomCardColorGroup

    let originalRed: Double
    let originalGreen: Double
    let originalBlue: Double
    let originalCustomCardColors: CustomCardColorGroup
    // Pushes the current selections into the game's live options. Called on every
    // change (not just on Done) so edits preview immediately on the board behind.
    // `bumpFeltRevision` should only be true when the custom felt color's raw RGB
    // changed — that's the one case SwiftUI can't detect via normal diffing (the
    // colors live in UserDefaults, not in any Equatable option field), so the board
    // needs the manual customFeltColorRevision nudge to redraw. Bumping it on every
    // commit would reset unrelated @State (like which Themes screen is showing)
    // any time the board's `.id(customFeltColorRevision)` view gets recreated.
    let onCommit: (_ bumpFeltRevision: Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: cancel) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Back")
                    }
                    .font(.system(.body))
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)

                Spacer()

                Text("Themes")
                    .font(.system(size: 16, weight: .bold))

                Spacer()

                Button("Done") { onCommit(false); isShowing = false; isOptionsPresented = false }
                    .font(.system(.body))
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            ScrollView(.vertical, showsIndicators: true) {
            HStack(alignment: .top, spacing: 32) {
                // Left Column
                VStack(alignment: .leading, spacing: 16) {
                    ThemesSectionView(
                        currentCardBackTheme: cardBackTheme,
                        currentFeltColor: feltColor,
                        currentCustomCardColors: customCardColors,
                        isOptionsPresented: $isOptionsPresented
                    )

                    Divider()

                    HStack(spacing: 8) {
                        Text("Felt Color:")
                            .font(.system(.body).bold())

                        Picker("", selection: $feltColor) {
                            Text("Felt Green").tag(FeltColorTheme.feltGreen)
                            Text("Crimson").tag(FeltColorTheme.crimson)
                            Text("Royal Blue").tag(FeltColorTheme.royalBlue)
                            Text("Charcoal").tag(FeltColorTheme.charcoal)
                            Text("Desert").tag(FeltColorTheme.desert)
                            Text("Colorblind").tag(FeltColorTheme.colorblind)
                            Text("Custom").tag(FeltColorTheme.custom)
                        }
                        .font(.system(.body))
                        .fixedSize()

                        if feltColor == .custom {
                            ColorPicker("", selection: $customSelectedColor)
                                .labelsHidden()
                                .onChange(of: customSelectedColor) { _, newColor in
                                    let nsColor = NSColor(newColor)
                                    if let rgb = nsColor.usingColorSpace(.deviceRGB) {
                                        UserDefaults.standard.set(Double(rgb.redComponent),   forKey: "custom_felt_red")
                                        UserDefaults.standard.set(Double(rgb.greenComponent), forKey: "custom_felt_green")
                                        UserDefaults.standard.set(Double(rgb.blueComponent),  forKey: "custom_felt_blue")
                                    }
                                    ThemeManager.shared.activeThemeId = nil
                                    onCommit(true)
                                }
                        }
                    }

                    Toggle("Felt Vignette", isOn: $showFeltVignette)
                        .font(.system(.body))

                    Divider()

                    CardDeckSelectorView(cardBackTheme: $cardBackTheme, feltColor: $feltColor)

                    Divider()

                    CustomCardColorSectionView(customCardColors: $customCardColors)
                }
                .frame(width: 390)

                // Right Column
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 4) {
                        Text("Add Custom Card Art")
                            .font(.system(.body).bold())
                        Text("(.jpg or .png accepted):")
                            .font(.system(.body))
                    }
                    .foregroundColor(.primary)

                    FaceCardArtSectionView()
                }
                .frame(width: 410)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            }
            .frame(maxHeight: maxPanelContentHeight)
        }
        .frame(width: 880)
        .fixedSize(horizontal: true, vertical: false)
        .background(Color(NSColor.windowBackgroundColor))
        .onChange(of: feltColor) { _, _ in ThemeManager.shared.activeThemeId = nil; onCommit(false) }
        .onChange(of: cardBackTheme) { _, _ in ThemeManager.shared.activeThemeId = nil; onCommit(false) }
        .onChange(of: showFeltVignette) { _, _ in onCommit(false) }
        .onChange(of: customCardColors) { _, _ in ThemeManager.shared.activeThemeId = nil; onCommit(false) }
    }

    // Caps the scrollable content area so the panel never grows taller than the
    // screen it's on (leaving room for the header/divider above and some margin),
    // regardless of how short the presenting game window currently is.
    private var maxPanelContentHeight: CGFloat {
        let screenHeight = NSScreen.main?.visibleFrame.height ?? 800
        return max(300, screenHeight - 160)
    }

    private func cancel() {
        UserDefaults.standard.set(originalRed,   forKey: "custom_felt_red")
        UserDefaults.standard.set(originalGreen, forKey: "custom_felt_green")
        UserDefaults.standard.set(originalBlue,  forKey: "custom_felt_blue")
        customCardColors = originalCustomCardColors
        isShowing = false
    }
}
