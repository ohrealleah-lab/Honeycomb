import SwiftUI

/// Themes sub-panel that slides over any game's OptionsView.
/// All theme-related controls live here: vignette, saved themes,
/// felt color, custom color, card deck + face art.
struct ThemesOptionsView: View {
    @Binding var isShowing: Bool
    @Binding var feltColor: FeltColorTheme
    @Binding var cardBackTheme: String
    @Binding var showFeltVignette: Bool
    @Binding var customSelectedColor: Color
    @Binding var customCardColors: CustomCardColorGroup

    let originalRed: Double
    let originalGreen: Double
    let originalBlue: Double
    let originalCustomCardColors: CustomCardColorGroup
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss

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
                    .font(.system(.body, design: .monospaced))
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)

                Spacer()

                Text("Themes")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))

                Spacer()

                Button("Done") { onDone(); isShowing = false; dismiss() }
                    .font(.system(.body, design: .monospaced))
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            HStack(alignment: .top, spacing: 32) {
                // Left Column
                VStack(alignment: .leading, spacing: 16) {
                    ThemesSectionView(
                        currentCardBackTheme: cardBackTheme,
                        currentFeltColor: feltColor,
                        currentCustomCardColors: customCardColors
                    )

                    Divider()

                    HStack(spacing: 8) {
                        Text("Felt Color:")
                            .font(.system(.body, design: .monospaced).bold())

                        Picker("", selection: $feltColor) {
                            Text("Felt Green").tag(FeltColorTheme.feltGreen)
                            Text("Crimson").tag(FeltColorTheme.crimson)
                            Text("Royal Blue").tag(FeltColorTheme.royalBlue)
                            Text("Charcoal").tag(FeltColorTheme.charcoal)
                            Text("Desert").tag(FeltColorTheme.desert)
                            Text("Custom").tag(FeltColorTheme.custom)
                        }
                        .font(.system(.body, design: .monospaced))
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
                                }
                        }
                    }

                    Divider()

                    CardDeckSelectorView(cardBackTheme: $cardBackTheme, feltColor: $feltColor)

                    Divider()

                    Toggle("Felt Vignette", isOn: $showFeltVignette)
                        .font(.system(.body, design: .monospaced))

                    Divider()

                    CustomCardColorSectionView(customCardColors: $customCardColors)
                }
                .frame(width: 390)

                // Right Column
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 4) {
                        Text("Add Custom Card Art")
                            .font(.system(.body, design: .monospaced).bold())
                        Text("(.jpg or .png accepted):")
                            .font(.system(.body, design: .monospaced))
                    }
                    .foregroundColor(.primary)

                    FaceCardArtSectionView()
                }
                .frame(width: 410)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 880)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func cancel() {
        UserDefaults.standard.set(originalRed,   forKey: "custom_felt_red")
        UserDefaults.standard.set(originalGreen, forKey: "custom_felt_green")
        UserDefaults.standard.set(originalBlue,  forKey: "custom_felt_blue")
        customCardColors = originalCustomCardColors
        isShowing = false
    }
}
