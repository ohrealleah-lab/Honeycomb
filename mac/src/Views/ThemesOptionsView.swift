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
    // never gets clipped by a game window narrower than that — plus the ~344pt the
    // persistent Themes sidebar always occupies alongside them.
    private static let sideBySideMinWidth: CGFloat = 1210

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
        if showingFaceCards { return coordinator.L(.faceCardsTitle) }
        if showingCardColors { return coordinator.L(.cardColorsTitle) }
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
                        Text(coordinator.L(.back))
                    }
                    .font(.system(.body))
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                // .buttonStyle(.plain) shrinks the hit area down to the rendered
                // glyphs/text rather than the button's full layout frame — a click
                // near the edge of "Back" (its padding, or the gap next to the
                // chevron) could miss it entirely and fall through to whatever's
                // behind. Restoring a rectangular hit region over the button's own
                // frame makes the whole visible tap target clickable.
                .contentShape(Rectangle())

                Spacer()

                Text(subScreenTitle ?? coordinator.L(.themesPanelTitle))
                    .font(.system(size: 16, weight: .bold))

                Spacer()

                Button(coordinator.L(.done)) {
                    onCommit(false)
                    isShowing = false
                    isOptionsPresented = false
                    clearPendingEditors()
                }
                    .font(.system(.body))
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    // Same fix as "Back" above — same .buttonStyle(.plain) hit-area
                    // shrinkage.
                    .contentShape(Rectangle())
            }
            .padding(.horizontal, 24)
            .padding(.top, 36) // Clear the macOS traffic light window controls
            .padding(.bottom, 12)
            // Defensive backstop alongside the deckBackgroundPreview gesture fix
            // below: guarantees the header always wins hit-testing over anything
            // rendered later in this VStack, regardless of any future gesture added
            // further down the panel.
            .zIndex(1)

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
        // pre-sidebar exact-fit width) + 344 (sidebar 300 + its own leading/trailing
        // padding) = 1224, rounded up slightly for breathing room.
        .frame(maxWidth: 1240)
        .background(
            Color(NSColor.windowBackgroundColor)
                .overlay(Color.primary.opacity(0.04))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        // OptionsSheetShell's `if showingThemes { ThemesOptionsView(...) }` keeps this
        // view around (and, by default, still hit-testable) for the full 0.2s
        // move/width-collapse transition after Done/Back flips isShowing to false — a
        // second click landing in that window (a habitual double-click on Done, or just
        // a fast follow-up click) can hit this still-animating-out panel, including the
        // hero preview's double-tap-to-edit-background gesture, before it's actually
        // gone. Tying hit-testing directly to isShowing means the instant dismissal is
        // requested, nothing in here can be clicked again, regardless of how long the
        // disappearing animation visually takes.
        .allowsHitTesting(isShowing)
        .onChange(of: cardBackTheme) { _, _ in onCommit(false) }
        .onChange(of: feltColor) { _, _ in onCommit(false) }
        .onChange(of: showFeltVignette) { _, _ in onCommit(false) }
        .onChange(of: customCardColors) { _, _ in onCommit(false) }
        .onChange(of: customBackgroundName) { _, _ in onCommit(false) }
        // Belt-and-suspenders alongside the Done/cancel resets above: catches this
        // panel disappearing through any other route (e.g. the outer Options sheet
        // getting dismissed while an editor sheet was still up) that would otherwise
        // leave backgroundEditorMode/cardBackEditTarget stuck non-nil for next time.
        .onDisappear { clearPendingEditors() }
    }

    private var faceCardsContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Text(coordinator.L(.addCustomCardArtHeading))
                        .font(.system(.body).bold())
                    Text(coordinator.L(.jpgPngAcceptedSuffix))
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
                // Pin the size directly on this view, before defining its hit-test
                // shape, rather than relying on the outer ZStack's frame (applied
                // after both children) to constrain it indirectly.
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .contentShape(Rectangle())
                // A lone .onTapGesture(count: 2) with no matching single-tap handler
                // on the same view is a known SwiftUI-on-macOS gesture bug: confirmed
                // here by debug logging showing this double-tap action firing when the
                // physical click was on the Done button's header, ~200pt away — the
                // gesture wasn't scoped to its own view's bounds. Pairing it with an
                // explicit no-op single-tap gesture makes SwiftUI disambiguate 1-vs-2
                // taps locally on this view instead of it leaking elsewhere.
                .onTapGesture(count: 1) {}
                .onTapGesture(count: 2) { openBackgroundEditor() }
                .help(customBackgroundName != nil ? coordinator.L(.doubleClickAdjustBackgroundTooltip) : "")

            CardView(card: Card(suit: .spades, rank: 1, faceUp: false))
                .contentShape(Rectangle())
                .onTapGesture { openCardBackEditor() }
                .help(!CustomCardBackManager.shared.isDefaultTheme(cardBackTheme) ? coordinator.L(.clickAdjustCardBackTooltip) : "")
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
        // Belt-and-suspenders alongside .allowsHitTesting(isShowing) above: SwiftUI's
        // gesture recognizers on a transitioning-out view can still fire a phantom tap
        // during the exit animation even with hit-testing disabled (e.g. a double-click
        // on Done — the first click starts the slide-out, the second lands on the
        // still-animating hero preview underneath). Guarding here at the call site
        // can't be bypassed by that timing gap the way the hit-testing tree can.
        guard isShowing else { return }
        guard let name = customBackgroundName,
              let background = CustomBackgroundManager.shared.customBackgrounds.first(where: { $0.name == name }),
              let image = CustomBackgroundManager.shared.image(for: background.relativePath)
        else { return }
        backgroundEditorMode = .editingExisting(background, image)
    }

    private func openCardBackEditor() {
        guard isShowing else { return }
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

    // Fixed-width persistent column. No ScrollView/background chrome of its own —
    // ThemesSectionView's own list box already provides both (it fills whatever height
    // this frame constrains it to, and scrolls its own rows independently), so wrapping
    // it in another ScrollView here just prevented that inner box from ever actually
    // expanding to fill the sidebar (ScrollView content always sizes to itself), which
    // is what left a visible gap of bare sidebar background below a short theme list —
    // a box nested inside an emptier box instead of one filled panel.
    private var themesSidebar: some View {
        ThemesSectionView()
            .padding(10)
            .frame(width: 300)
            .frame(maxHeight: maxPanelContentHeight)
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
                    Text(coordinator.L(.customFeltColorLabel))
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
                title: coordinator.L(.customizeFaceCardsTitle),
                subtitle: coordinator.L(.customizeFaceCardsSubtitle)
            ) { showingFaceCards = true }

            navRowButton(
                title: coordinator.L(.customCardColorsTitle),
                subtitle: coordinator.L(.customCardColorsSubtitleMac)
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
                Text(coordinator.L(.livePreviewNotice))
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
        clearPendingEditors()
    }

    // .sheet(isPresented:) content (this whole Options flow, for Honeycomb) can retain
    // its @State across a dismiss/re-present instead of resetting fresh each time — so
    // if backgroundEditorMode/cardBackEditTarget ever end up non-nil when this panel
    // closes (e.g. the outer Options sheet got dismissed some other way while one of
    // these editor sheets was still up, bypassing its own onCancel), that stale non-nil
    // value survives and immediately re-presents the editor the next time this panel
    // reappears — looking exactly like tapping Done "opens the background/card-back
    // resize editor" on a totally unrelated later visit. Clearing both on every exit
    // path (Done and Back/cancel) guarantees neither can carry over.
    private func clearPendingEditors() {
        backgroundEditorMode = nil
        cardBackEditTarget = nil
    }
}
