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

    // Below this width, the two settings columns (390 + 410 + 32 spacing + 48 padding =
    // 880 exact need) stack vertically instead of sitting side-by-side, so the panel
    // never gets clipped by a game window narrower than that — plus the ~284pt the
    // persistent Themes sidebar always occupies alongside them.
    private static let sideBySideMinWidth: CGFloat = 1150

    @State private var contentHeight: CGFloat = 0
    // The 16-slot face card grid and the 3-mock-card color preview both need full panel
    // width, not squeezed into a column alongside everything else — each pushed to its
    // own sub-screen, same Back-header pattern as this panel itself.
    @State private var showingFaceCards = false
    @State private var showingCardColors = false
    // Owned here (not inside BackgroundSelectorView) so the hero preview's double-tap
    // can drive the same edit sheet as BackgroundSelectorView's own picker/delete flow.
    @State private var backgroundEditorMode: BackgroundEditorMode? = nil
    // Card-back equivalent — tapping the card in the hero preview opens the same
    // scale/position editor CardDeckSelectorView uses for a new import, pre-filled with
    // the currently-active custom deck's existing values (see CustomCardBackEditorView's
    // existingCardBack parameter). Only reachable for custom decks — bundled/default
    // card backs have no scale/offset to adjust.
    @State private var cardBackEditTarget: CardBackEditTarget? = nil

    private struct CardBackEditTarget: Identifiable {
        let id: UUID
        let cardBack: CustomCardBack
        let image: NSImage
    }

    private var subScreenTitle: String? {
        if showingFaceCards { return "Face Cards" }
        if showingCardColors { return "Card Colors" }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: {
                    if showingFaceCards { showingFaceCards = false }
                    else if showingCardColors { showingCardColors = false }
                    else { cancel() }
                }) {
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

                Text(subScreenTitle ?? "Themes")
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

            if showingFaceCards {
                faceCardsContent
            } else if showingCardColors {
                cardColorsContent
            } else {
                // Sidebar: Saved Themes gets its own persistent column (matching Windows'
                // ThemesPanel layout) instead of scrolling away with the rest of the
                // settings — it stays visible as a picker no matter how far down you've
                // scrolled the felt/background/card-deck controls.
                HStack(alignment: .top, spacing: 0) {
                    themesSidebar
                        .padding(.leading, 24)
                        .padding(.top, 16)

                    // Only wrap in a ScrollView once content is actually taller than the
                    // room available — a ScrollView vertically *centers* content that's
                    // shorter than its own given height (a well-known SwiftUI quirk),
                    // which produced a big empty gap above/below the list even after the
                    // height was correctly capped. A plain VStack has no such quirk: it
                    // just naturally hugs/top-aligns its content, so we use one whenever
                    // there's no need to scroll.
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
            }
        }
        // 880 (leftColumn 390 + spacing 32 + rightColumn 410 + 48 padding, the panel's
        // pre-sidebar exact-fit width) + 284 (sidebar 240 + its own leading/trailing
        // padding) = 1164, rounded up slightly for breathing room.
        .frame(maxWidth: 1180)
        .background(
            Color(NSColor.windowBackgroundColor)
                .overlay(Color.primary.opacity(0.04))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onChange(of: cardBackTheme) { _, _ in onCommit(false) }
        .onChange(of: feltColor) { _, _ in onCommit(false) }
        .onChange(of: showFeltVignette) { _, _ in onCommit(false) }
        .onChange(of: customCardColors) { _, _ in onCommit(false) }
        .onChange(of: customBackgroundName) { _, _ in onCommit(false) }
    }

    private var faceCardsContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Text("Add Custom Card Art")
                        .font(.system(.body).bold())
                    Text("(.jpg or .png accepted):")
                        .font(.system(.body))
                }
                .foregroundColor(.primary)

                FaceCardArtSectionView()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
        }
        .frame(height: maxPanelContentHeight)
    }

    private var panelContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            deckBackgroundPreview

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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 24)
        .padding(.vertical, 16)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { contentHeight = geo.size.height }
                    .onChange(of: geo.size.height) { _, h in contentHeight = h }
            }
        )
    }

    // Hero preview: the real configured card back rendered on the real configured
    // backdrop (felt color, or the actual background image when one's set) — merges
    // what used to be two separate small thumbnails (a card-back preview next to Card
    // Deck, a felt/background swatch next to Background) into one larger, always-visible
    // mockup, live-updating as either control changes since CardView/ThemeBackdropView
    // both read straight off AppCoordinator. The card and the backdrop are separate tap
    // targets (a ZStack, not one .overlay-combined view+gesture) so each opens its own
    // editor: clicking the card opens the card-back editor, double-clicking the backdrop
    // opens the background editor (matching Windows' DeckBackgroundBackdrop_DoubleTapped)
    // — both no-op when there's nothing custom to adjust (a bundled card back, or plain
    // felt color with no background image).
    private var deckBackgroundPreview: some View {
        ZStack {
            ThemeBackdropView(customBackgroundName: customBackgroundName)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { openBackgroundEditor() }
                .help(customBackgroundName != nil ? "Double-click to adjust the background" : "")

            CardView(card: Card(suit: .spades, rank: 1, faceUp: false))
                .contentShape(Rectangle())
                .onTapGesture { openCardBackEditor() }
                .help(!CustomCardBackManager.shared.isDefaultTheme(cardBackTheme) ? "Click to adjust the card back" : "")
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.12), lineWidth: 1))
        .sheet(item: $cardBackEditTarget) { target in
            CustomCardBackEditorView(image: target.image, existingCardBack: target.cardBack) { _, scale, offsetX, offsetY in
                var updated = target.cardBack
                updated.scale = scale
                updated.offsetX = offsetX
                updated.offsetY = offsetY
                CustomCardBackManager.shared.updateCustomCardBack(updated)
                cardBackEditTarget = nil
            } onCancel: {
                cardBackEditTarget = nil
            }
        }
    }

    private func openBackgroundEditor() {
        guard let name = customBackgroundName,
              let background = CustomBackgroundManager.shared.customBackgrounds.first(where: { $0.name == name }),
              let image = CustomBackgroundManager.shared.image(for: background.relativePath)
        else { return }
        backgroundEditorMode = .editingExisting(background, image)
    }

    private func openCardBackEditor() {
        guard !CustomCardBackManager.shared.isDefaultTheme(cardBackTheme),
              let cardBack = CustomCardBackManager.shared.customCardBacks.first(where: { $0.name == cardBackTheme }),
              let image = CustomCardBackManager.shared.image(for: cardBack.relativePath)
        else { return }
        cardBackEditTarget = CardBackEditTarget(id: cardBack.id, cardBack: cardBack, image: image)
    }

    // Caps the panel's content area so it never grows taller than either the physical
    // screen or (more commonly the binding constraint) the actual game window's own
    // current content height, leaving room for the header/divider above and some margin.
    private var maxPanelContentHeight: CGFloat {
        let screenHeight = NSScreen.main?.visibleFrame.height ?? 800
        return max(300, min(availableHeight - 140, screenHeight - 160))
    }

    // Fixed-width persistent column, own tinted/bordered background so it reads as a
    // distinct panel instead of blending into the settings — same visual role as
    // Windows' #ECECEC sidebar `Border`. Own ScrollView (rather than relying on the
    // caller to cap it) so a long theme list scrolls independently of the settings
    // column beside it, matching Windows' "stays visible as a picker while the rest of
    // the panel scrolls independently" behavior.
    private var themesSidebar: some View {
        ScrollView(.vertical, showsIndicators: true) {
            ThemesSectionView(isOptionsPresented: $isOptionsPresented)
                .padding(10)
        }
        .frame(width: 240)
        .frame(maxHeight: maxPanelContentHeight)
        .background(Color.primary.opacity(0.05))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.15), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.trailing, 20)
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Card Deck's carousel leads — it's the more visually engaging of the two
            // controls, and doesn't need to sit below Background just because that's
            // the order they were originally added in.
            CardDeckSelectorView(cardBackTheme: $cardBackTheme, feltColor: $feltColor)

            Divider()

            BackgroundSelectorView(customBackgroundName: $customBackgroundName, feltColor: $feltColor, showFeltVignette: $showFeltVignette, editorMode: $backgroundEditorMode)

            if feltColor == .custom && customBackgroundName == nil {
                HStack(spacing: 8) {
                    Text("Custom Felt Color:")
                        .font(.system(.body).bold())
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
                    Spacer()
                }
            }
        }
        .frame(width: 390)
    }

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            navRowButton(
                title: "Customize Face Cards for Theme",
                subtitle: "16 slots — Aces, Jacks, Queens, Kings per suit"
            ) { showingFaceCards = true }

            navRowButton(
                title: "Custom Card Colors for Theme",
                subtitle: "Background, outline, suit text, hint highlight"
            ) { showingCardColors = true }
        }
        .frame(width: 410)
    }

    private func navRowButton(title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(.body).bold())
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var cardColorsContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Live preview — edits below apply to these cards immediately.")
                    .font(.system(.body))
                    .foregroundColor(.secondary)

                cardColorsMockPreview

                CustomCardColorSectionView(customCardColors: $customCardColors)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(height: maxPanelContentHeight)
    }

    // 3 mock cards on the theme's real backdrop: black-suit ace, red-suit ace, and the
    // real configured card back with a permanent hint-highlight-colored ring (not
    // CardView's own transient hint-pulse mechanism — the ask here is "always on," so
    // this is a separate static overlay).
    // Scaled to 80% of native card size — scaleEffect alone only shrinks the rendering,
    // not the space it reserves in the HStack, so the frame afterward is what actually
    // shrinks its layout footprint too (otherwise the 3 cards would still claim
    // full-size width and either overflow or get clipped by the frame below).
    private static let cardColorsPreviewScale: CGFloat = 0.8

    private var cardColorsMockPreview: some View {
        ThemeBackdropView(customBackgroundName: customBackgroundName)
            .overlay {
                HStack(spacing: 20) {
                    CardView(card: Card(suit: .clubs, rank: 1, faceUp: true))
                        .scaleEffect(Self.cardColorsPreviewScale)
                        .frame(width: CardDimensions.width * Self.cardColorsPreviewScale,
                               height: CardDimensions.height * Self.cardColorsPreviewScale)
                    CardView(card: Card(suit: .hearts, rank: 1, faceUp: true))
                        .scaleEffect(Self.cardColorsPreviewScale)
                        .frame(width: CardDimensions.width * Self.cardColorsPreviewScale,
                               height: CardDimensions.height * Self.cardColorsPreviewScale)
                    CardView(card: Card(suit: .spades, rank: 1, faceUp: false))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(customCardColors.hintHighlightColor, lineWidth: 3)
                        )
                        .scaleEffect(Self.cardColorsPreviewScale)
                        .frame(width: CardDimensions.width * Self.cardColorsPreviewScale,
                               height: CardDimensions.height * Self.cardColorsPreviewScale)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.12), lineWidth: 1))
    }

    private func cancel() {
        coordinator.customFeltRed   = originalRed
        coordinator.customFeltGreen = originalGreen
        coordinator.customFeltBlue  = originalBlue
        customCardColors = originalCustomCardColors
        isShowing = false
    }
}
