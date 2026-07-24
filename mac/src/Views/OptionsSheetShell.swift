import SwiftUI

// Shared chrome for every game's "Preferences" sheet: the Preferences/Divider header, the
// Visual Themes button + its ThemesOptionsView sub-panel (with theme-revert-on-Cancel state),
// and the Cancel / View Stats / OK button row. Each game supplies its own per-game controls
// (Pickers, Steppers, Toggles) via `content`, and its own OK-button side effects via `onOK`.
struct OptionsSheetShell<Content: View>: View {
    @Binding var isPresented: Bool
    @Bindable var coordinator: AppCoordinator
    var availableWidth: CGFloat
    var availableHeight: CGFloat
    var useScrollView: Bool
    var maxContentHeight: CGFloat
    var fixedSizeHorizontal: Bool
    var title: String
    var showThemes: Bool
    var onViewStats: () -> Void
    var onOK: () -> Void
    @ViewBuilder var content: () -> Content

    @State private var customSelectedColor: Color
    @State private var showingThemes: Bool = false

    let originalRed: Double
    let originalGreen: Double
    let originalBlue: Double
    let originalFeltColor: FeltColorTheme
    let originalCardBackTheme: String
    let originalShowFeltVignette: Bool
    let originalCustomCardColors: CustomCardColorGroup
    let originalCustomBackgroundName: String?

    init(
        isPresented: Binding<Bool>,
        coordinator: AppCoordinator,
        availableWidth: CGFloat = 2000,
        availableHeight: CGFloat = 900,
        useScrollView: Bool = true,
        maxContentHeight: CGFloat = 680,
        fixedSizeHorizontal: Bool = true,
        title: String = "Preferences",
        showThemes: Bool = true,
        onViewStats: @escaping () -> Void,
        onOK: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._isPresented = isPresented
        self.coordinator = coordinator
        self.availableWidth = availableWidth
        self.availableHeight = availableHeight
        self.useScrollView = useScrollView
        self.maxContentHeight = maxContentHeight
        self.fixedSizeHorizontal = fixedSizeHorizontal
        self.title = title
        self.showThemes = showThemes
        self.onViewStats = onViewStats
        self.onOK = onOK
        self.content = content

        self.originalFeltColor = coordinator.feltColor
        self.originalCardBackTheme = coordinator.cardBackTheme
        self.originalShowFeltVignette = coordinator.showFeltVignette
        self.originalCustomCardColors = coordinator.customCardColors
        self.originalCustomBackgroundName = coordinator.customBackgroundName

        let r = coordinator.customFeltRed
        let g = coordinator.customFeltGreen
        let b = coordinator.customFeltBlue
        self.originalRed = r
        self.originalGreen = g
        self.originalBlue = b
        let initialColor: Color
        if r == 0 && g == 0 && b == 0 {
            initialColor = Color(red: 0.35, green: 0.15, blue: 0.45)
        } else {
            initialColor = Color(red: r, green: g, blue: b)
        }
        _customSelectedColor = State(initialValue: initialColor)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .padding(.top, 12)

                Divider()

                if useScrollView {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 12) {
                            content()
                            if showThemes {
                                visualThemesSection
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .frame(maxHeight: maxContentHeight)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        content()
                        if showThemes {
                            visualThemesSection
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Divider()

                HStack {
                    Button("Cancel") {
                        // Revert any theme changes that were live-previewed via the Themes sub-panel.
                        coordinator.customFeltRed = originalRed
                        coordinator.customFeltGreen = originalGreen
                        coordinator.customFeltBlue = originalBlue
                        coordinator.feltColor = originalFeltColor
                        coordinator.cardBackTheme = originalCardBackTheme
                        coordinator.showFeltVignette = originalShowFeltVignette
                        coordinator.customCardColors = originalCustomCardColors
                        coordinator.customBackgroundName = originalCustomBackgroundName
                        isPresented = false
                    }
                    .keyboardShortcut(.cancelAction)

                    Spacer()

                    Button(action: {
                        isPresented = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            onViewStats()
                        }
                    }) {
                        Text("View Stats")
                            .underline()
                            .foregroundColor(.blue)
                            .font(.system(.body))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button("OK") {
                        onOK()
                        isPresented = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .frame(width: 440)
            .fixedSize(horizontal: fixedSizeHorizontal, vertical: true)
            .background(
                Color(NSColor.windowBackgroundColor)
                    .overlay(Color.primary.opacity(0.04))
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))

            if showingThemes {
                ThemesOptionsView(
                    isShowing: $showingThemes,
                    isOptionsPresented: $isPresented,
                    feltColor: $coordinator.feltColor,
                    cardBackTheme: $coordinator.cardBackTheme,
                    showFeltVignette: $coordinator.showFeltVignette,
                    customSelectedColor: $customSelectedColor,
                    customCardColors: $coordinator.customCardColors,
                    customBackgroundName: $coordinator.customBackgroundName,
                    originalRed: originalRed,
                    originalGreen: originalGreen,
                    originalBlue: originalBlue,
                    originalCustomCardColors: originalCustomCardColors,
                    onCommit: { _ in },
                    availableWidth: availableWidth,
                    availableHeight: availableHeight
                )
                .transition(.move(edge: .trailing))
            }
        } // ZStack
        .frame(maxWidth: showingThemes ? 880 : 440)
        .animation(.easeInOut(duration: 0.2), value: showingThemes)
    }

    private var visualThemesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showingThemes = true } }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Visual Themes")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.primary)
                        Text("Felt, card back, face card art, colors")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.primary.opacity(0.02))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Divider()
        }
    }
}
