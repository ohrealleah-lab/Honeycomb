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

    // The real current window content width, supplied by the hosting game view (it
    // already tracks this reactively via WindowAccessor's onResize, for the toolbar's
    // own icon/text compacting). Deliberately NOT measured with a local GeometryReader:
    // a GeometryReader wrapping this whole panel would report whatever size it's
    // *proposed* as its own ideal size, which forces the panel to always claim the
    // entire overlay/window rather than shrink-wrapping its actual content — that was
    // the cause of the panel filling the whole screen with empty space above/below it.
    let availableWidth: CGFloat

    // The real current window content height, supplied by the hosting game view (same
    // source as availableWidth). Used to cap how tall the panel is allowed to get —
    // capping against the physical screen instead of the actual (possibly much smaller)
    // game window let the panel be taller than the window itself, which combined with
    // the overlay's automatic centering pushed the header off the top edge on a small window.
    let availableHeight: CGFloat

    // Below this width, the two columns (390 + 410 + 32 spacing + 48 padding = 880
    // exact need) stack vertically instead of sitting side-by-side, so the panel
    // never gets clipped by a game window narrower than 880pt.
    private static let sideBySideMinWidth: CGFloat = 870

    @State private var contentHeight: CGFloat = 0

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
            .padding(.top, 36) // Clear the macOS traffic light window controls
            .padding(.bottom, 12)

            Divider()

            // Only wrap in a ScrollView once content is actually taller than the room
            // available — a ScrollView vertically *centers* content that's shorter than
            // its own given height (a well-known SwiftUI quirk), which produced a big
            // empty gap above/below the list even after the height was correctly capped.
            // A plain VStack has no such quirk: it just naturally hugs/top-aligns its
            // content, so we use one whenever there's no need to scroll.
            Group {
                if contentHeight > maxPanelContentHeight {
                    ScrollView(.vertical, showsIndicators: true) {
                        panelContent
                    }
                    .frame(height: maxPanelContentHeight)
                } else {
                    panelContent
                }
            }
        }
        .frame(maxWidth: 880)
        .background(
            Color(NSColor.windowBackgroundColor)
                .overlay(Color.primary.opacity(0.04))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onChange(of: cardBackTheme) { _, _ in onCommit(false) }
        .onChange(of: showFeltVignette) { _, _ in onCommit(false) }
        .onChange(of: customCardColors) { _, _ in onCommit(false) }
        .onChange(of: customBackgroundName) { _, _ in onCommit(false) }
    }

    private var panelContent: some View {
        Group {
            if availableWidth >= Self.sideBySideMinWidth {
                HStack(alignment: .top, spacing: 32) {
                    leftColumn
                    rightColumn
                }
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    leftColumn
                    rightColumn
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { contentHeight = geo.size.height }
                    .onChange(of: geo.size.height) { _, h in contentHeight = h }
            }
        )
    }

    // Caps the panel's content area so it never grows taller than either the physical
    // screen or (more commonly the binding constraint) the actual game window's own
    // current content height, leaving room for the header/divider above and some margin.
    private var maxPanelContentHeight: CGFloat {
        let screenHeight = NSScreen.main?.visibleFrame.height ?? 800
        return max(300, min(availableHeight - 140, screenHeight - 160))
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            ThemesSectionView(
                isOptionsPresented: $isOptionsPresented
            )

            Divider()

            HStack(spacing: 8) {
                Text("Felt Color:")
                    .font(.system(.body).bold())

                Picker("", selection: Binding(
                    get: { feltColor },
                    set: { newValue in
                        feltColor = newValue
                        // Only fires for an actual manual pick from this control — programmatic
                        // writes to coordinator.feltColor (e.g. AppCoordinator.applyTheme) go
                        // through the plain property setter and never touch this closure, so a
                        // theme's own felt color no longer clobbers its own background.
                        if customBackgroundName != nil { customBackgroundName = nil }
                        onCommit(false)
                    }
                )) {
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
    }

    private var rightColumn: some View {
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

    private func cancel() {
        coordinator.customFeltRed   = originalRed
        coordinator.customFeltGreen = originalGreen
        coordinator.customFeltBlue  = originalBlue
        customCardColors = originalCustomCardColors
        isShowing = false
    }
}
