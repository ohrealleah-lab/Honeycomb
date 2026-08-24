import SwiftUI
import UIKit

/// Touch-first BeeCell (Freecell) board for iPhone/iPad, driven by the shared
/// BeecellViewModel. Klondike drag pattern throughout. Top row: free cells, then
/// undo/hint in the gap (the spot the user picked), then foundations. Pile counts are
/// dynamic — 4/4/8 in single-deck, 8/8/10 in double-deck — so all sizing derives from
/// the live state.
struct BeecellTouchView: View {
    @Bindable var viewModel: BeecellViewModel
    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator
    @Environment(\.scenePhase) private var scenePhase

    private static let boardSpace = "beecellBoard"
    private static let columnSpacing: CGFloat = 4

    @State private var pileFrames: [String: CGRect] = [:]
    @State private var draggedCards: [Card] = []
    @State private var dragSourcePile: Pile? = nil
    @State private var dragLocation: CGPoint = .zero
    @State private var dragOffset: CGSize = .zero

    @State private var isMenuOpen = false
    @State private var showingOptions = false
    @State private var showingThemes = false
    @State private var showingStats = false
    @State private var dismissedStuckBanner = false
    @State private var dismissedAutocompleteBanner = false
    @State private var showParticles = false
    @State private var showNoHintsBanner = false
    @State private var noHintsBannerTask: DispatchWorkItem? = nil

    private let placementHaptic = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        GeometryReader { geo in
            let columns = CGFloat(max(viewModel.state.tableau.count, 8))
            // Fit to both width and height (see KlondikeTouchView for why: landscape's
            // extra width alone would hand out cards too tall for the deepest column to
            // actually fit, with no scroll view to fall back on).
            let widthCardW = (geo.size.width - 16 - (columns - 1) * Self.columnSpacing) / columns
            let designCardW = min(widthCardW, 100)
            let designCardH = designCardW * CardDimensions.aspectRatio
            let intrinsicHeight = 54 + designCardH + 10 + deepestColumnHeight(cardH: designCardH) + 20
            let heightScale = min(1.0, geo.size.height / intrinsicHeight)
            let cardW = designCardW * heightScale
            let cardH = designCardW * heightScale * CardDimensions.aspectRatio
            let topSlots = CGFloat(viewModel.state.freeCells.count + viewModel.state.foundations.count)
            // Free cells + foundations share the top row with a control gap; shrink the
            // slot size when double-deck doubles the slot count.
            let topCardW = min(cardW, (geo.size.width - 16 - 52 - (topSlots - 1) * Self.columnSpacing) / topSlots)
            let topCardH = topCardW * CardDimensions.aspectRatio
            let isLandscape = geo.size.width > geo.size.height

            ZStack {
                VStack(spacing: 10) {
                    topBar(isLandscape: isLandscape)
                        .padding(.horizontal, 8)
                        .frame(height: 44)

                    if !isLandscape {
                        statusCapsule
                    }

                    topRow(cardW: topCardW, cardH: topCardH)
                        .padding(.horizontal, 8)

                    tableauRow(cardW: cardW, cardH: cardH)
                        .padding(.horizontal, 8)

                    Spacer(minLength: 0)
                }

                dragOverlay(cardW: cardW, cardH: cardH)

                if viewModel.state.hasWon {
                    WinAnimationView(foundations: viewModel.state.foundations, pileFrames: pileFrames, cardWidth: cardW) {}

                    // On top of the banner (not behind it) — matches the Blackjack/
                    // Video Poker confetti ordering.
                    WinParticleView(active: showParticles)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)
                }

                if showNoHintsBanner {
                    noHintsBanner
                }
            }
            // Anchors boardSpace — every pileFrames GeometryReader and DragGesture
            // .named(Self.boardSpace) reference below depends on this exact container.
            // Moving this modifier to a different view breaks drop hit-testing silently.
            .coordinateSpace(name: Self.boardSpace)
            // winOverlay/stuckOverlay both call .ignoresSafeArea() internally. As plain
            // ZStack siblings (like IOSBackgroundLayer used to be — see its own fix
            // elsewhere in this file), that would make the ZStack itself adopt the
            // full-bleed, notch-including size and propose it to every other sibling
            // too, shifting the whole board out past the safe area right as the win/
            // stuck banner appears. .overlay() doesn't feed size back up the way a
            // ZStack sibling does, so it can bleed edge-to-edge without dragging the
            // board's own size out with it.
            .overlay {
                if viewModel.isAutocompleteAvailable && !viewModel.state.hasWon && !dismissedAutocompleteBanner {
                    autocompleteBanner
                }
            }
            .overlay {
                if viewModel.state.hasWon {
                    winOverlay
                }
            }
            .overlay {
                if viewModel.isStuck && !viewModel.state.hasWon && !dismissedStuckBanner {
                    stuckOverlay
                }
            }
        }
        .environment(\.feltColor, coordinator.feltColor)
        .environment(\.activeCardBackTheme, coordinator.cardBackTheme)
        .environment(\.activeCustomCardColors, coordinator.customCardColors)
        .sheet(isPresented: $isMenuOpen) { GameSelectionFullScreenView(coordinator: coordinator) }
        .sheet(isPresented: $showingStats) { BeecellStatsSheet(viewModel: viewModel) }
        .sheet(isPresented: $showingThemes) { ThemesFullScreenView(coordinator: coordinator) }
        .sheet(isPresented: $showingOptions) {
            OptionsFullScreenView(
                coordinator: coordinator,
                onShowStats: { showingStats = true },
                hideHintBinding: $viewModel.options.hideHintButton,
                onNoStressModeChange: { viewModel.startNewGame() },
                showsGameSection: false
            ) {
                EmptyView()
            }
        }
        .onAppear {
            // Two-deck Beecell is mac-only — 104 cards across 10 tableau columns don't
            // fit a phone/tablet screen at a readable size. If a synced options value
            // ever comes in as 2 (e.g. from mac), fall back to a fresh 1-deck game
            // rather than trying to render an unsupported board.
            if viewModel.options.deckCount != 1 {
                viewModel.options.deckCount = 1
                viewModel.startNewGame()
            }
            viewModel.startTimerIfNeeded()
            viewModel.checkLoadingBanner()
        }
        // Re-arms the idle-nudge timer on every move, matching mac
        // (BeecellView.swift:731-732) — previously only armed once via startNewGame().
        .onChange(of: viewModel.state.movesCount) {
            viewModel.scheduleIdleActionCheck()
        }
        .onChange(of: viewModel.state.hasWon) { _, newVal in
            dismissedStuckBanner = false
            if newVal {
                showParticles = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { showParticles = false }
            }
        }
        // Mirrors mac's BeecellView.swift onChange(of: viewModel.isAutocompleteAvailable)
        // — a fresh autocomplete opportunity always re-shows the banner even if the last
        // one was dismissed.
        .onChange(of: viewModel.isAutocompleteAvailable) { _, newVal in
            if newVal { dismissedAutocompleteBanner = false }
        }
        // Debug-only trigger handler — mirrors mac's BeecellView.swift onChange(of:
        // viewModel.debugBannerRequest), minus dismissedWinBanner (this view doesn't
        // have that flag — its win UI shows unconditionally off hasWon).
        .onChange(of: viewModel.debugBannerRequest) { _, kind in
            guard let kind else { return }
            viewModel.debugBannerRequest = nil
            switch kind {
            case .win:
                let suits: [Card.Suit] = [.spades, .clubs, .diamonds, .hearts]
                let count = max(viewModel.state.foundations.count, 4)
                viewModel.state.foundations = (0..<count).map { i in
                    let suit = suits[i % suits.count]
                    let cards = (1...13).map { Card(suit: suit, rank: $0, faceUp: true) }
                    return Pile(id: "foundation_\(i)", type: .foundation, cards: cards)
                }
                viewModel.state.hasWon = true
            case .stuck:
                viewModel.state.hasWon = false
                dismissedStuckBanner = false
                viewModel.isStuck = true
            case .autocomplete:
                viewModel.state.hasWon = false
                dismissedAutocompleteBanner = false
                viewModel.isAutocompleteAvailable = true
            case .loss, .same, .plus, .suddenDeath:
                break
            }
        }
        // Mirrors the mac view's NSWindow.didResignKeyNotification safety net: SwiftUI's
        // DragGesture has no "cancelled" callback, so a drag interrupted by the app
        // backgrounding (Control Center, an incoming call, the home gesture, etc.) never
        // fires .onEnded — without this, the floating drag overlay would keep rendering
        // forever and the source pile would stay hidden its dragged card.
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase != .active, !draggedCards.isEmpty else { return }
            cancelDrag()
        }
        .queuedFlashBanner(
            trigger: viewModel.flashBannerTrigger,
            latestMessage: viewModel.flashBanner,
            manuallyDismissBanners: viewModel.options.manuallyDismissBanners,
            onAdvanceQueue: viewModel.advanceBannerQueue
        )
        .background(IOSBackgroundLayer())
    }

    // MARK: Top bar

    private func topBar(isLandscape: Bool) -> some View {
        // Landscape only: statusCapsule is an overlay, not a third HStack element
        // flanked by Spacers — the leading (menu) and trailing (New Deal) content
        // aren't the same width, so centering it "between" two Spacers actually
        // centered it in whatever space was left over, not on the bar itself. An
        // overlay centers it on the full bar width regardless of how wide either side
        // is. Portrait has height to spare, so statusCapsule instead renders as its own
        // row below topBar (see body) rather than overlapping the menu icons.
        // Tightened from spacing:10 — six 44pt icon buttons (menu/options/palette/
        // debug/undo/hint) plus the New Deal/Quit button no longer fit an iPhone's
        // width at the old spacing once undo/hint moved up here from the board; the
        // bar's own ideal width exceeding the screen made it the VStack's widest
        // child, silently pulling every other (exactly screen-width) row a few points
        // off-center along with it — this is what looked like an asymmetric left/
        // right margin on the whole board, not just the top bar.
        HStack(spacing: 6) {
            menuBarButtons(isMenuOpen: $isMenuOpen, showingOptions: $showingOptions, showingThemes: $showingThemes, coordinator: coordinator)
            debugMenuButton(items: [("Win", .win), ("Loss (Stuck)", .stuck), ("Autocomplete", .autocomplete)]) {
                viewModel.debugBannerRequest = $0
            }

            Spacer()

            // Moved up from the board's free-cell/foundation gap into the menu bar,
            // grouped with New Deal on the trailing side rather than the leading icon
            // cluster — keeps the leading cluster narrow (avoiding the Score badge
            // overlay, which centers on the whole bar) and reads as "the game
            // actions" grouped together.
            topBarIconButton(systemImage: "arrow.uturn.backward", accessibilityLabel: coordinator.L(.undo)) {
                viewModel.undoLastAction()
            }
            .disabled(!viewModel.canUndo)
            .opacity(viewModel.canUndo ? 1 : 0.35)

            if !viewModel.options.hideHintButton {
                topBarIconButton(systemImage: "lightbulb", accessibilityLabel: coordinator.L(.hint)) {
                    if !viewModel.findHint() {
                        flashNoHintsBanner()
                    }
                }
            }

            Button {
                dismissedStuckBanner = false
                viewModel.startNewGame()
            } label: {
                Label(coordinator.L(.touchNewDealLabel), systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .overlay {
            if isLandscape {
                statusCapsule
            }
        }
    }

    private var statusCapsule: some View {
        HStack(spacing: 14) {
            statusStat(coordinator.L(.scoreLabel), viewModel.scoreString, color: .yellow)
            if viewModel.options.isTimed && !viewModel.options.noStressMode {
                statusStat(coordinator.L(.timeLabel), formatTime(viewModel.state.timerSeconds), color: .white.opacity(0.85))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(.black.opacity(0.35), in: Capsule())
    }

    // MARK: Top row: free cells | gap | foundations

    private func topRow(cardW: CGFloat, cardH: CGFloat) -> some View {
        HStack(alignment: .center, spacing: Self.columnSpacing) {
            ForEach(viewModel.state.freeCells) { pile in
                freeCellView(pile: pile, cardW: cardW, cardH: cardH)
            }

            // Undo/hint used to live in this free-cell/foundation gap; they've moved
            // up into the menu bar (topBar), but the gap itself stays so the
            // foundations keep their usual column position.
            Color.clear
                .frame(width: 44, height: cardH)

            ForEach(viewModel.state.foundations) { pile in
                foundationView(pile: pile, cardW: cardW, cardH: cardH)
            }
        }
    }

    private func freeCellView(pile: Pile, cardW: CGFloat, cardH: CGFloat) -> some View {
        ZStack {
            emptySlot(cardW: cardW, cardH: cardH)
            if let card = pile.cards.last {
                TouchCardView(card: card, width: cardW)
                    .opacity(draggedCards.contains(where: { $0.id == card.id }) ? 0 : 1)
                    .gesture(cardDragGesture(pile: pile, stack: [card]))
                    .onTapGesture(count: 2) {
                        viewModel.doubleClickMove(card: card, from: pile)
                    }
            }
        }
        .frame(width: cardW, height: cardH)
        .modifier(TouchHintHighlight(isHighlighted: hintTouches(pile.id)))
        .background(frameTracker(id: pile.id))
    }

    private func foundationView(pile: Pile, cardW: CGFloat, cardH: CGFloat) -> some View {
        return ZStack {
            emptySlot(cardW: cardW, cardH: cardH, letterSymbol: "A")
            if let top = pile.cards.last {
                TouchCardView(card: top, width: cardW)
            }
        }
        .frame(width: cardW, height: cardH)
        .modifier(TouchHintHighlight(isHighlighted: hintTouches(pile.id)))
        .background(frameTracker(id: pile.id))
    }

    // MARK: Tableau

    private func tableauRow(cardW: CGFloat, cardH: CGFloat) -> some View {
        HStack(alignment: .top, spacing: Self.columnSpacing) {
            ForEach(viewModel.state.tableau) { pile in
                tableauColumn(pile: pile, cardW: cardW, cardH: cardH)
            }
        }
    }

    /// The deepest tableau column's actual stacked height at the given card height —
    /// same per-card offset tableauColumn renders with, so the fit-to-screen scale
    /// computed from this always matches what's actually drawn.
    private func deepestColumnHeight(cardH: CGFloat) -> CGFloat {
        let upStep = cardH * 0.24
        return viewModel.state.tableau.map { pile -> CGFloat in
            pile.cards.isEmpty ? cardH : CGFloat(pile.cards.count - 1) * upStep + cardH
        }.max() ?? cardH
    }

    private func tableauColumn(pile: Pile, cardW: CGFloat, cardH: CGFloat) -> some View {
        let upStep = cardH * 0.24
        let columnHeight = pile.cards.isEmpty ? cardH : CGFloat(pile.cards.count - 1) * upStep + cardH
        let hintIndex = hintTouches(pile.id)
            ? pile.cards.firstIndex(where: { $0.id == viewModel.activeHint?.card.id })
            : nil

        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: cardW * 0.07)
                .fill(Color.black.opacity(0.18))
                .frame(width: cardW, height: cardH)
            ForEach(Array(pile.cards.enumerated()), id: \.element.id) { i, card in
                let stack = Array(pile.cards[i...])
                TouchCardView(card: card, width: cardW)
                    .offset(y: CGFloat(i) * upStep)
                    .opacity(draggedCards.contains(where: { $0.id == card.id }) ? 0 : 1)
                    .onTapGesture(count: 2) {
                        viewModel.doubleClickMove(card: card, from: pile)
                    }
                    .gesture(viewModel.isValidDragSequence(stack) ? cardDragGesture(pile: pile, stack: stack) : nil)
            }
            // Drawn as its own sibling, positioned with the exact same offset formula
            // as the matched card, rather than attached via modifier chaining on the
            // card itself — the per-card modifier version was reported visually
            // landing above the actual hinted card instead of tightly bordering it,
            // which this sidesteps entirely by computing the ring's position
            // independently, from the same source of truth.
            //
            // Always mounted (not `if let hintIndex { ... }`) — TouchHintHighlight's
            // pulse only starts on an isHighlighted false->true *transition* (it's
            // driven by .onChange). A conditionally-inserted view is born with
            // isHighlighted already true, so there's no transition to observe: phase
            // never leaves 0 and the ring's opacity formula ((1-cos(phase*pi*4))/2)
            // stays permanently 0 — invisible. Foundation/free-cell rings never hit
            // this because they're unconditional siblings that see the real
            // false->true edge when a hint lands on them.
            Color.clear
                .frame(width: cardW, height: cardH)
                // TouchHintHighlight's pulse modifier conforms to AnimatableModifier —
                // it receives its content as an opaque view and animates only its own
                // `phase` property. Proven via direct instrumentation that the offset
                // math itself is correct (computedOffset lands exactly on the hinted
                // card's position every time) while the ring still rendered at the
                // wrong screen position, matching a known AnimatableModifier pitfall:
                // once its animation is running, it can keep presenting geometry from
                // whenever that animation started rather than picking up a same-frame
                // change to *content* (here, a new .offset() from hintIndex changing).
                // Moving .offset() to apply AFTER (outside) the animated modifier,
                // instead of before/inside it, means it's shifting the whole already-
                // rendered bordered box from the outside every frame — nothing for the
                // animator to cache stale.
                .modifier(TouchHintHighlight(isHighlighted: hintIndex != nil))
                .offset(y: CGFloat(hintIndex ?? 0) * upStep)
                .allowsHitTesting(false)
        }
        .frame(width: cardW, height: columnHeight, alignment: .top)
        .modifier(TouchHintHighlight(isHighlighted: pile.cards.isEmpty && hintTouches(pile.id)))
        .background(frameTracker(id: pile.id))
    }

    // MARK: Shared pieces

    private func emptySlot(cardW: CGFloat, cardH: CGFloat, symbol: String? = nil, letterSymbol: String? = nil) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cardW * 0.07)
                .fill(Color.black.opacity(0.18))
            RoundedRectangle(cornerRadius: cardW * 0.07)
                .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
            if let symbol {
                Image(systemName: symbol)
                    .resizable().aspectRatio(contentMode: .fit)
                    .frame(width: cardW * 0.35)
                    .foregroundStyle(.white.opacity(0.35))
            } else if let letterSymbol {
                // Matches mac's EmptyPileView(symbol: "A", ...) — an empty foundation
                // shows the rank it's waiting for (an Ace), not a suit icon, since
                // BeeCell foundations aren't suit-keyed until a card actually lands.
                Text(letterSymbol)
                    .font(.system(size: cardW * 0.35, weight: .bold))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .frame(width: cardW, height: cardH)
    }

    private func frameTracker(id: String) -> some View {
        GeometryReader { geo in
            Color.clear
                .onAppear { pileFrames[id] = geo.frame(in: .named(Self.boardSpace)) }
                .onChange(of: geo.frame(in: .named(Self.boardSpace))) { _, newFrame in
                    pileFrames[id] = newFrame
                }
        }
    }

    private func hintTouches(_ pileId: String) -> Bool {
        (viewModel.activeHint?.sourcePileId == pileId) || 
        (viewModel.activeHint?.targetPileId == pileId)
    }

    // MARK: Drag handling

    private func cardDragGesture(pile: Pile, stack: [Card]) -> some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .named(Self.boardSpace))
            .onChanged { val in
                if draggedCards.isEmpty {
                    viewModel.clearHint()
                    draggedCards = stack
                    dragSourcePile = pile
                    dragLocation = val.startLocation
                }
                dragOffset = val.translation
            }
            .onEnded { _ in handleDragEnded() }
    }

    @ViewBuilder
    private func dragOverlay(cardW: CGFloat, cardH: CGFloat) -> some View {
        if !draggedCards.isEmpty {
            let upStep = cardH * 0.24
            let stackH = cardH + CGFloat(draggedCards.count - 1) * upStep
            ZStack(alignment: .top) {
                ForEach(Array(draggedCards.enumerated()), id: \.element.id) { i, card in
                    TouchCardView(card: card, width: cardW)
                        .offset(y: CGFloat(i) * upStep)
                }
            }
            .frame(width: cardW, height: stackH, alignment: .top)
            .position(x: dragLocation.x + dragOffset.width,
                      y: dragLocation.y + dragOffset.height + stackH / 2 - cardH * 0.4)
            .shadow(radius: 8, y: 4)
            .allowsHitTesting(false)
            .zIndex(10)
        }
    }

    private func cancelDrag() {
        draggedCards = []
        dragSourcePile = nil
        dragOffset = .zero
    }

    private func handleDragEnded() {
        let releaseLocation = CGPoint(
            x: dragLocation.x + dragOffset.width,
            y: dragLocation.y + dragOffset.height
        )

        func accepts(_ pile: Pile) -> Bool {
            SmartDrop.resolve(cards: draggedCards, isValidMove: { viewModel.isValidMove(cards: $0, to: pile) }) != nil
        }

        // Tableau: column alignment with open bottoms. Free cells and foundations:
        // rectangular hit boxes. All prefer piles that actually accept.
        struct Candidate {
            let pile: Pile
            let accepts: Bool
            let distance: CGFloat
            let isTableau: Bool
        }
        var candidates: [Candidate] = []

        for tab in viewModel.state.tableau {
            if let frame = pileFrames[tab.id] {
                let margin: CGFloat = 12
                let inX = releaseLocation.x >= frame.minX - margin && releaseLocation.x <= frame.maxX + margin
                let inY = releaseLocation.y >= frame.minY - margin
                if inX && inY {
                    candidates.append(Candidate(
                        pile: tab, accepts: accepts(tab),
                        distance: abs(releaseLocation.x - frame.midX), isTableau: true))
                }
            }
        }
        for pile in viewModel.state.freeCells + viewModel.state.foundations {
            if let frame = pileFrames[pile.id] {
                let margin: CGFloat = 10
                if frame.insetBy(dx: -margin, dy: -margin).contains(releaseLocation) {
                    let dx = releaseLocation.x - frame.midX
                    let dy = releaseLocation.y - frame.midY
                    candidates.append(Candidate(
                        pile: pile, accepts: accepts(pile),
                        distance: (dx * dx + dy * dy).squareRoot(), isTableau: false))
                }
            }
        }

        if let best = candidates.sorted(by: { c1, c2 in
            if c1.accepts != c2.accepts { return c1.accepts && !c2.accepts }
            if c1.isTableau != c2.isTableau { return !c1.isTableau && c2.isTableau }
            return c1.distance < c2.distance
        }).first, best.accepts,
           let source = dragSourcePile,
           let resolved = SmartDrop.resolve(cards: draggedCards, isValidMove: { viewModel.isValidMove(cards: $0, to: best.pile) }) {
            viewModel.clearHint()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                viewModel.moveCards(resolved, from: source, to: best.pile)
            }
            placementHaptic.impactOccurred()
        }

        viewModel.clearHint()
        cancelDrag()
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    // Matches mac's StatusItemView (label above, value below) rather than an unlabeled
    // capsule of raw numbers — a player glancing at "-$52.00  00:00" has no way to tell
    // which is score/bankroll and which is the timer without already knowing the format.
    private func statusStat(_ label: String, _ value: String, color: Color) -> some View {
        VStack(spacing: 0) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
        }
    }

    // MARK: Overlays

    // Matches Klondike's autocompleteBanner exactly (shared banner design across
    // Klondike/Beecell/Spider), swapping in autocompleteBodyOther for the generic
    // "sorted into foundations" wording instead of Klondike's own body text.
    private var autocompleteBanner: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 12) {
                    Text(coordinator.L(.victoryGuaranteed))
                        .font(.system(size: 30, weight: .black))
                        .foregroundColor(.yellow)
                        .multilineTextAlignment(.center)
                    Text(coordinator.L(.autocompleteBodyOther))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Button {
                        viewModel.runAutocomplete()
                    } label: {
                        Label(coordinator.L(.autocompleteGame), systemImage: "wand.and.stars")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .buttonBorderShape(.capsule)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .frame(maxWidth: 320)
                .background(Color.black.opacity(0.75))
                .cornerRadius(12)
                .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.5), radius: 16)

                Button {
                    dismissedAutocompleteBanner = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .padding(10)
            }
        }
    }

    private var winOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 16) {
                Text(coordinator.L(.youWin))
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.yellow)
                Text(coordinator.L(.scoreFmt, viewModel.scoreString))
                    .foregroundColor(.white)
                Button {
                    viewModel.startNewGame()
                } label: {
                    Label(coordinator.L(.newGame), systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: 240)
            }
            .padding(28)
            // Matches mac's BeecellView win overlay exactly (solid dark card + yellow-
            // glow shadow) rather than the frosted .ultraThinMaterial look this had
            // before, which let the board show through and didn't match any other banner.
            .background(Color.black.opacity(0.75))
            .cornerRadius(12)
            .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.5), radius: 16)
        }
    }

    private var noHintsBanner: some View {
        VStack {
            Text(coordinator.L(.noHintsAvailable))
                .font(.title3.weight(.black))
                .foregroundStyle(Color.yellow)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.black.opacity(0.75), in: Capsule())
                .transition(.scale.combined(with: .opacity))
                .contentShape(Capsule())
                .onTapGesture { dismissNoHintsBanner() }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 60)
    }

    private func dismissNoHintsBanner() {
        noHintsBannerTask?.cancel()
        noHintsBannerTask = nil
        withAnimation(.easeOut(duration: 0.3)) { showNoHintsBanner = false }
    }

    private func flashNoHintsBanner() {
        noHintsBannerTask?.cancel()
        withAnimation(.easeIn(duration: 0.15)) { showNoHintsBanner = true }
        let task = DispatchWorkItem { dismissNoHintsBanner() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: task)
        noHintsBannerTask = task
    }

    private var stuckOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 14) {
                Text(coordinator.L(.gameOver))
                    .font(.system(size: 34, weight: .black))
                    .foregroundColor(.yellow)
                Text(coordinator.L(.noMovesRemaining))
                    .foregroundColor(.white)
                Button {
                    dismissedStuckBanner = true
                    viewModel.restartCurrentGame()
                } label: {
                    Label(coordinator.L(.restartGame), systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.white)
                Button {
                    dismissedStuckBanner = false
                    viewModel.startNewGame()
                } label: {
                    Label(coordinator.L(.newGame), systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: 260)
            .padding(24)
            // Matches mac's BeecellView stuck overlay exactly — see winOverlay above.
            .background(Color.black.opacity(0.75))
            .cornerRadius(12)
            .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.5), radius: 16)
            .overlay(alignment: .topTrailing) {
                Button {
                    dismissedStuckBanner = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(8)
            }
        }
    }
}

// Beecell has no settings of its own beyond Sound/No Stress Mode/Honey Mode/Hide
// Hint/Manually Dismiss Banners, which all now live in OptionsFullScreenView's own
// Global section (see BeecellTouchView's showsGameSection: false) — no per-game
// section struct needed anymore. Two-deck Beecell isn't offered on iOS either way
// (see the deckCount clamp in BeecellTouchView's onAppear); mac keeps its 1/2-deck
// picker.

// MARK: - Stats sheet

struct BeecellStatsSheet: View {
    @Bindable var viewModel: BeecellViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        NavigationStack {
            List {
                let stats = viewModel.currentModeStats
                row(coordinator.L(.gamesPlayed), "\(stats.gamesPlayed)")
                row(coordinator.L(.gamesWon), "\(stats.gamesWon)")
                row(coordinator.L(.highScore), viewModel.highScoreString)
                row(coordinator.L(.winRate), String(format: "%.0f%%", stats.winPercentage))
                row(coordinator.L(.currentStreak), "\(stats.currentStreak)")
                row(coordinator.L(.longestStreak), "\(stats.longestStreak)")
                if stats.winningGamesCount > 0 {
                    row(coordinator.L(.avgWinningTimeColon), String(format: "%02d:%02d", Int(stats.averageWinningTime) / 60, Int(stats.averageWinningTime) % 60))
                }
                if stats.shortestWinTime > 0 {
                    row(coordinator.L(.fastestWin), String(format: "%02d:%02d", stats.shortestWinTime / 60, stats.shortestWinTime % 60))
                }
            }
            .navigationTitle(coordinator.L(.freecellStatisticsFmt, viewModel.options.deckCount == 1 ? coordinator.L(.deckCount1) : coordinator.L(.deckCount2)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(coordinator.L(.done)) { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}
