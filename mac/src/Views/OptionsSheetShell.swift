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
    var showLanguage: Bool
    // Optional — the Honeycomb Rules sheet (a second, separate OptionsSheetShell user
    // from HoneycombRulesView, not to be confused with Honeycomb's own Options sheet,
    // which does show stats) has no stats view of its own to jump to, so it omits this
    // entirely rather than wiring a dead `{}` closure to a link that did nothing.
    var onViewStats: (() -> Void)?
    var onOK: () -> Void
    // Solibee watermark's max width/height, shared across every sheet built on this shell
    // but overridable per-caller — the Honeycomb Rules sheet (HoneycombRulesView) wants a
    // noticeably bigger one than the plain per-game Preferences sheets.
    var watermarkMaxSize: CGFloat
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
        showLanguage: Bool = true,
        onViewStats: (() -> Void)? = nil,
        watermarkMaxSize: CGFloat = 220,
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
        self.showLanguage = showLanguage
        self.onViewStats = onViewStats
        self.watermarkMaxSize = watermarkMaxSize
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
                // No caller currently overrides `title` — it's always the "Preferences"
                // default — so that default is the one localized case; a future custom
                // title passes through as-is rather than being silently dropped.
                Text(title == "Preferences" ? coordinator.L(.preferences) : title)
                    .font(.system(size: 16, weight: .bold))
                    .padding(.top, 12)

                Divider()

                if useScrollView {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 12) {
                            if showLanguage {
                                languageSection
                            }
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
                        if showLanguage {
                            languageSection
                        }
                        content()
                        if showThemes {
                            visualThemesSection
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Divider()

                HStack {
                    Button(coordinator.L(.cancel)) {
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

                    if let onViewStats {
                        Button(action: {
                            isPresented = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                onViewStats()
                            }
                        }) {
                            Text(coordinator.L(.viewStats))
                                .underline()
                                .foregroundColor(.blue)
                                .font(.system(.body))
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }

                    Button(coordinator.L(.ok)) {
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
            .background {
                // Matches the Stats/Rules panels' watermark treatment — fixed max size (not
                // left to scale with the sheet) so it sits behind the content instead of
                // overpowering it. Shared here (not per-game) since every game's Preferences
                // sheet, plus the Honeycomb Rules sheet, is built on this one shell.
                if !coordinator.hideBee, let image = NSImage(named: "Solibee") {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: watermarkMaxSize, maxHeight: watermarkMaxSize)
                        .opacity(0.15)
                }
            }
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
                // Re-injected explicitly rather than relying on inheriting them from
                // whatever presents this shell (an inline .overlay in every game's own
                // view, or a .sheet for Honeycomb) — empirically, CardView's
                // @Environment(\.activeCardBackTheme) reads inside this panel's hero
                // preview were still resolving to ActiveCardBackThemeKey's default
                // ("Solibee") even though the presenting game view sets the real value
                // earlier in its own modifier chain, and even though the live
                // cardBackTheme *binding* passed into ThemesOptionsView was correct the
                // whole time. Scoped to just this view (not the whole shell) so it can't
                // affect the always-visible Preferences panel's own layout/animation.
                .environment(\.feltColor, coordinator.feltColor)
                .environment(\.activeCardBackTheme, coordinator.cardBackTheme)
                .environment(\.activeCustomCardColors, coordinator.customCardColors)
                .transition(.move(edge: .trailing))
            }
        } // ZStack
        // ThemesOptionsView itself needs up to 1240 (see its own comment: 390+32+410+48
        // content + 344 sidebar) now that the persistent Saved Themes sidebar lives
        // alongside the settings columns — this used to be 880, the pre-sidebar
        // content-only width, which left the shell's own layout/hit-testing bounds
        // narrower than what ThemesOptionsView actually renders. That mismatch let the
        // panel's real (visually correct) content spill outside the width this
        // container thought it occupied, which desynced hit-testing from what's drawn —
        // most visibly, clicking the Themes panel's own "Done" button (out past the
        // stale 880 edge) instead landed on whatever sat underneath at that screen
        // position.
        .frame(maxWidth: showingThemes ? 1240 : 440)
        .animation(.easeInOut(duration: 0.2), value: showingThemes)
    }

    // Global setting (not per-game), so it lives here in the shared shell rather than
    // in each game's own `content` — every game's Options sheet gets it automatically.
    // Placed above `content()` per product decision: it's always the same regardless
    // of which game you opened Options from, so it reads as app-level, not game-level.
    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(coordinator.L(.language))
                .font(.system(size: 13, weight: .semibold))
            Picker(coordinator.L(.language), selection: $coordinator.language) {
                ForEach(AppLanguage.allCases, id: \.self) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Divider()
        }
    }

    private var visualThemesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showingThemes = true } }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(coordinator.L(.visualThemes))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.primary)
                        Text(coordinator.L(.visualThemesSubtitle))
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
        }
    }
}
