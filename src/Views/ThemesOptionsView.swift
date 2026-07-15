import SwiftUI

/// Themes sub-panel that slides over any game's OptionsView.
/// All theme-related controls live here: vignette, saved themes,
/// felt color, custom color, card deck + face art.
struct ThemesOptionsView: View {
    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator

    @Binding var isShowing: Bool
    @Binding var isOptionsPresented: Bool
    @Binding var feltColor: FeltColorTheme
    @Binding var cardBackTheme: String
    @Binding var showFeltVignette: Bool
    @Binding var customSelectedColor: Color
    @Binding var customCardColors: CustomCardColorGroup
    @Binding var customBackgroundName: String?

    let originalRed: Double
    let originalGreen: Double
    let originalBlue: Double
    let originalCustomCardColors: CustomCardColorGroup
    // Theme fields are bound straight through to AppCoordinator now, so edits are
    // already live on the board the instant they're made. This hook only remains for
    // any non-theme reconciliation a hosting Options sheet still wants on change.
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
                                        coordinator.customFeltRed   = Double(rgb.redComponent)
                                        coordinator.customFeltGreen = Double(rgb.greenComponent)
                                        coordinator.customFeltBlue  = Double(rgb.blueComponent)
                                    }
                                    ThemeManager.shared.invalidateActiveTheme()
                                    onCommit(true)
                                }
                        }

                        Spacer()

                        Toggle("Felt Vignette", isOn: $showFeltVignette)
                            .font(.system(.body))
                    }

                    BackgroundSelectorView(customBackgroundName: $customBackgroundName)

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
        .onChange(of: feltColor) { _, _ in
            // Switching to a felt color deactivates any custom background, so the
            // Background dropdown resets to "None (Felt Color)" automatically.
            if customBackgroundName != nil { customBackgroundName = nil }
            ThemeManager.shared.invalidateActiveTheme()
            onCommit(false)
        }
        .onChange(of: cardBackTheme) { _, _ in ThemeManager.shared.invalidateActiveTheme(); onCommit(false) }
        .onChange(of: showFeltVignette) { _, _ in onCommit(false) }
        .onChange(of: customCardColors) { _, _ in ThemeManager.shared.invalidateActiveTheme(); onCommit(false) }
        .onChange(of: customBackgroundName) { _, _ in ThemeManager.shared.invalidateActiveTheme(); onCommit(false) }
    }

    // Caps the scrollable content area so the panel never grows taller than the
    // screen it's on (leaving room for the header/divider above and some margin),
    // regardless of how short the presenting game window currently is.
    private var maxPanelContentHeight: CGFloat {
        let screenHeight = NSScreen.main?.visibleFrame.height ?? 800
        return max(300, screenHeight - 160)
    }

    private func cancel() {
        coordinator.customFeltRed   = originalRed
        coordinator.customFeltGreen = originalGreen
        coordinator.customFeltBlue  = originalBlue
        customCardColors = originalCustomCardColors
        isShowing = false
    }
}
