import SwiftUI

public struct HoneycombView: View {
    @Bindable var viewModel: HoneycombViewModel
    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator
    
    public static let minWindowSize = NSSize(width: 700, height: 500)
    private static let toolbarHeight: CGFloat = 90
    // Hands sit on either side of the board, each arranged as a 2-2-1 pyramid, so a
    // hand column is only ever 2 cards wide. Sized up to use more of the side margin
    // between the board and the window edge.
    private static let handCardSize = CGSize(width: 195, height: 195 * 181.0 / 128.0)
    private static let boardCardSize = handCardSize
    private static let handGridSpacing: CGFloat = 4
    private static let boardGridSpacing: CGFloat = 10
    private static let handColumnWidth = 2 * handCardSize.width + handGridSpacing
    // Approximate rendered height of the rules banner above the board — used to nudge
    // the hand columns down so their top row lines up with the board's top row instead
    // of the banner's.
    private static let rulesBannerHeight: CGFloat = 120
    private static let handTopOffset: CGFloat = rulesBannerHeight + 12
    // "PLAYER"/"DEALER" labels sit inside that same top-offset space, above the hand
    // grid, so the grid's first row still lands in the same place as before — this is
    // subtracted from handTopOffset rather than added on top of it.
    private static let handLabelBlockHeight: CGFloat = 34
    // Honeycomb's setup toolbar carries more buttons + a picker than the other games'
    // (Manage Decks, Rules, Stats, Start Match, sometimes Save Deck), so it needs more
    // room before it can afford full labels than their shared 830pt threshold.
    private static let compactToolbarWidthThreshold: CGFloat = 1100

    @State private var toolbarWidth: CGFloat = 2000
    @State private var windowContentHeight: CGFloat = 900

    @State private var showingDecks = false
    @State private var showingRules = false
    @State private var showingStats = false
    @State private var showingOptions = false

    @State private var draggingOpponentCardIndex: Int? = nil

    // Custom drag state for playing cards — keyed by the card's own stable id
    // (not array position), since playerHand/opponentHand shrink as cards are
    // played, and a stale positional index can point past the end of the
    // array mid-removal-animation (crash).
    @State private var draggingHandCardId: String? = nil

    // Banner state
    @State private var showingRuleBanner = false
    @State private var bannerText = ""
    @State private var bannerTask: DispatchWorkItem? = nil

    @State private var isShowingSaveDeckConfirm = false

    // Shared across both hand columns so a Swap trade's two cards can visually slide
    // from one hand to the other — SwiftUI interpolates a matchedGeometryEffect'd
    // view's frame across any parent within the same namespace.
    @Namespace private var swapAnimationNamespace

    // "Steal Card" click-to-select flow: pick an opponent card on the board, then
    // one of your own hand cards to replace with it.
    @State private var isStealingCard = false
    @State private var stealBoardIndex: Int? = nil

    @State private var hostingWindow: NSWindow? = nil
    @State private var zoomController: WindowZoomController? = nil

    public var body: some View {
        ZStack {
            BackgroundLayerView()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // Placed behind the toolbar/board/hands (declared before them in this
            // ZStack, and ZStack draws later children on top), so it can never cover
            // any cards regardless of the vignette's own shape — same ordering every
            // other game uses.
            if coordinator.showFeltVignette { FeltVignetteView(intensity: 0.34) }

            VStack {
                // Top Control Row
                HStack(spacing: 20) {
                    // Game Selection Dropdown
                    GameSelectionDropdown(coordinator: coordinator)

                    // Start Match / Quit Match share this one slot (where the old,
                    // redundant "New Game" button used to sit — .setup already had
                    // Start Match, and gameOver's post-game overlay has its own New
                    // Game button, so the toolbar-level one never did anything unique).
                    if viewModel.gameState == .setup {
                        GameToolbarButton(
                            label: "Start Match", systemImage: "play.fill",
                            isCompact: toolbarWidth < Self.compactToolbarWidthThreshold
                        ) { viewModel.startNewGame() }
                    } else {
                        GameToolbarButton(
                            label: "Quit Match", systemImage: "flag.fill",
                            isCompact: toolbarWidth < Self.compactToolbarWidthThreshold
                        ) { viewModel.gameState = .setup }
                    }

                    GameToolbarButton(
                        label: "Options", systemImage: "gearshape",
                        isCompact: toolbarWidth < Self.compactToolbarWidthThreshold
                    ) { showingOptions = true }

                    if viewModel.gameState == .setup {
                        GameToolbarButton(
                            label: "Game Rules", systemImage: "list.bullet.clipboard",
                            isCompact: toolbarWidth < Self.compactToolbarWidthThreshold
                        ) { showingRules = true }

                        GameToolbarButton(
                            label: "Manage Decks", systemImage: "square.grid.2x2",
                            isCompact: toolbarWidth < Self.compactToolbarWidthThreshold
                        ) { showingDecks = true }

                        if viewModel.hasUnsavedActiveDeck && !viewModel.options.noStressMode {
                            GameToolbarButton(
                                label: "Save Deck", systemImage: "tray.and.arrow.down",
                                isCompact: toolbarWidth < Self.compactToolbarWidthThreshold
                            ) { isShowingSaveDeckConfirm = true }
                        }
                    } else {
                        GameToolbarButton(
                            label: "Undo", systemImage: "arrow.uturn.backward",
                            isCompact: toolbarWidth < Self.compactToolbarWidthThreshold,
                            disabled: !viewModel.canUndo
                        ) { viewModel.undoLastAction() }
                    }
                    
                    Spacer()

                    if viewModel.gameState != .setup {
                        HStack {
                            StatusItemView(label: "YOU", value: "\(viewModel.board.playerScore + viewModel.playerHand.count)")
                            StatusItemView(label: "OPPONENT", value: "\(viewModel.board.opponentScore + viewModel.opponentHand.count)")
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 36) // Clear the macOS traffic light window controls
                .padding(.bottom, 6)
                .layoutPriority(1)

                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 1)
                
                Spacer()
                
                // Game Area — hands sit on either side of the board, each arranged as a
                // 2-2-1 pyramid (2 top, 2 middle, 1 bottom centered).
                HStack(alignment: .top, spacing: 16) {
                    // Player Hand (Left) — nudged down to align with the board's top
                    // row rather than the rules banner above it.
                    let displayHand = viewModel.gameState == .gameOver ? viewModel.playerStartingDeck : viewModel.playerHand
                    VStack(spacing: 6) {
                        handSideLabel("PLAYER")
                        handGrid(hand: displayHand) { card in
                            playerHandCardView(card: card)
                        }
                    }
                    .padding(.top, Self.handTopOffset - Self.handLabelBlockHeight)
                    .frame(width: Self.handColumnWidth)

                    Spacer()

                    // Board (Center), with the rules banner above it
                    VStack(spacing: 12) {
                        rulesBanner

                        VStack(spacing: Self.boardGridSpacing) {
                            ForEach(0..<3) { row in
                                HStack(spacing: Self.boardGridSpacing) {
                                    ForEach(0..<3) { col in
                                        let index = row * 3 + col
                                        let cell = viewModel.board.cells[index]

                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.black.opacity(0.2))
                                                .frame(width: Self.boardCardSize.width, height: Self.boardCardSize.height)

                                            if let card = cell.card {
                                                // Steal-eligible = the opponent originally played this card
                                                // (regardless of who currently holds it — a card you captured
                                                // back doesn't unlock via winning either, since that requires
                                                // originalOwner == .player, so it'd otherwise be permanently
                                                // stuck outside your collection) AND not already in your Card
                                                // Bank (stealing it wouldn't gain anything new).
                                                let stealEligible = isStealingCard
                                                    && card.originalOwner == .opponent
                                                    && !HoneycombProfileManager.shared.unlockedCardIds.contains(card.data.id)
                                                HoneycombCardView(card: card, size: Self.boardCardSize, isFlipped: false, stealHighlight: stealEligible)
                                                    // Post-game Swap Drag Source
                                                    .onDrag {
                                                        if viewModel.showPostGamePrompt, card.originalOwner == .opponent {
                                                            draggingOpponentCardIndex = index
                                                            return NSItemProvider(object: "\(index)" as NSString)
                                                        }
                                                        return NSItemProvider()
                                                    }
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 10)
                                                            .stroke(Color.white, lineWidth: stealBoardIndex == index ? 4 : 0)
                                                    )
                                            }
                                        }
                                        .onTapGesture {
                                            if viewModel.gameState == .playing && viewModel.isPlayerTurn,
                                               let cardId = selectedHandCardId,
                                               let handIdx = viewModel.playerHand.firstIndex(where: { $0.id == cardId }) {
                                                viewModel.playerPlayCard(handIndex: handIdx, boardIndex: index)
                                                selectedHandCardId = nil
                                            } else if isStealingCard, viewModel.showPostGamePrompt, viewModel.gameState == .gameOver,
                                                      cell.card?.originalOwner == .opponent {
                                                stealBoardIndex = index
                                            }
                                        }
                                        .onDrop(of: [.plainText], isTargeted: nil) { providers in
                                            if viewModel.gameState == .playing && viewModel.isPlayerTurn,
                                               let cardId = draggingHandCardId,
                                               let handIdx = viewModel.playerHand.firstIndex(where: { $0.id == cardId }) {
                                                viewModel.playerPlayCard(handIndex: handIdx, boardIndex: index)
                                                draggingHandCardId = nil
                                                selectedHandCardId = nil
                                                return true
                                            }
                                            return false
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Spacer()

                    // Opponent Hand (Right) — same top offset as the player's hand.
                    VStack(spacing: 6) {
                        handSideLabel("DEALER")
                        handGrid(hand: viewModel.opponentHand) { card in
                            opponentHandCardView(card: card)
                        }
                    }
                    .padding(.top, Self.handTopOffset - Self.handLabelBlockHeight)
                    .frame(width: Self.handColumnWidth)
                }
                .padding()
                // Pin this content to its true native (unscaled) size *before*
                // scaleEffect — scaleEffect passes proposed sizes straight through
                // unchanged to its subject, so without this, the later "reserve the
                // scaled size" frame below (needed to keep the toolbar from being pushed
                // off-window) was also shrinking what's *offered* to this content during
                // layout. With hand columns hard-sized and Spacers already at zero, the
                // entire deficit was landing on the one truly flexible thing left — the
                // rules banner's Text — which truncated it ("R…"/"Th…").
                .frame(width: intrinsicContentSize.width, height: intrinsicContentSize.height, alignment: .top)
                .scaleEffect(viewModel.zoomScale, anchor: .top)
                // Re-constrain the layout footprint to the *scaled* size — scaleEffect
                // alone only changes rendering, not how much space the parent reserves,
                // which is what was letting this view's full native (pre-scale) size
                // force the toolbar off the top of the window. minHeight: 0 (rather than
                // a rigid fixed height) still lets this compress further if the window
                // is smaller than even the scaled minimum.
                .frame(width: intrinsicContentSize.width * viewModel.zoomScale, alignment: .top)
                .frame(minHeight: 0,
                       idealHeight: intrinsicContentSize.height * viewModel.zoomScale,
                       maxHeight: intrinsicContentSize.height * viewModel.zoomScale,
                       alignment: .top)

                Spacer()
            }
            
            // Post Game Overlay — hidden while actively picking cards to steal, so the
            // board and hands underneath are clickable.
            if viewModel.showPostGamePrompt && !isStealingCard {
                ZStack(alignment: .topTrailing) {
                    VStack {
                        if viewModel.matchResult == "You Lose" {
                            // Exact match to Video Poker's loss banner (VideoPokerView.swift).
                            Text("Not today, partner!")
                                .font(.system(size: 36, weight: .black))
                                .foregroundColor(.yellow)
                        } else {
                            Text(viewModel.matchResult).font(.system(size: 60, weight: .bold)).foregroundColor(.white)
                        }

                        if viewModel.matchResult == "You Win!" && !viewModel.options.noStressMode {
                            Text("Take a Card! Drag an opponent's card from the board onto your hand to swap it, or start a New Game.")
                                .foregroundColor(.white).padding()
                        }

                        HStack {
                            Button("New Game") {
                                viewModel.startNewGame()
                            }.buttonStyle(.borderedProminent)

                            // No Stress Mode always deals a fresh random overpowered
                            // deck — stealing a card in would let the player curate a
                            // deck in a mode whose whole point is not choosing one.
                            if viewModel.matchResult == "You Win!" && !viewModel.options.noStressMode {
                                Button("Steal Card") {
                                    isStealingCard = true
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.yellow)
                                .foregroundColor(.black)
                            }
                        }
                    }
                    .padding(40)

                    // Dismiss the banner without starting a new game, so the finished
                    // board stays visible (e.g. to still drag-steal a card afterward).
                    Button {
                        viewModel.showPostGamePrompt = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .padding(12)
                }
                .background(Color.black.opacity(0.8))
                .cornerRadius(16)
                .shadow(radius: 20)
            }

            // Steal Card mode — replaces the full overlay with a slim instruction bar
            // so the board and hands stay visible and tappable.
            if isStealingCard {
                VStack {
                    Text(stealBoardIndex == nil
                         ? "Tap an opponent's card on the board to steal it."
                         : "Now tap one of your own cards to replace with the stolen card.")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(10)
                        .shadow(radius: 10)

                    Button("Cancel") {
                        isStealingCard = false
                        stealBoardIndex = nil
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundColor(.black)
                    .padding(.top, 6)
                }
                .padding(.top, 60)
                .frame(maxHeight: .infinity, alignment: .top)
            }
            
            // Banner Overlay — shared by Ascension/Descension/Same/Plus/Sudden Death.
            if showingRuleBanner {
                FlashBannerView(message: bannerText)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .onChange(of: viewModel.gameState) { _, newState in
            // Safety net: however the match ends up leaving .gameOver (New Game
            // button, surrender, etc.), don't leave steal-card mode stuck active.
            if newState != .gameOver {
                isStealingCard = false
                stealBoardIndex = nil
            }
        }
        .onChange(of: viewModel.flashRuleBanner) { _, newVal in
            guard let text = newVal else { return }
            viewModel.flashRuleBanner = nil // clear it
            bannerTask?.cancel()
            bannerText = text
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                showingRuleBanner = true
            }
            let task = DispatchWorkItem {
                withAnimation(.easeOut(duration: 0.3)) {
                    showingRuleBanner = false
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: task)
            bannerTask = task
        }
        .alert(
            "Swap Cards?",
            isPresented: Binding(
                get: { viewModel.pendingSwap != nil },
                set: { if !$0 { viewModel.cancelPendingSwap(); stealBoardIndex = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { viewModel.cancelPendingSwap(); stealBoardIndex = nil }
            Button("Swap") {
                viewModel.confirmPendingSwap()
                isStealingCard = false
                stealBoardIndex = nil
            }
        } message: {
            Text("You will replace the card from your active deck with a stolen card, and a new game will start.")
        }
        .alert(
            "Can't Steal That Card",
            isPresented: Binding(
                get: { viewModel.swapValidationError != nil },
                set: { if !$0 { viewModel.swapValidationError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.swapValidationError = nil }
        } message: {
            Text(viewModel.swapValidationError ?? "")
        }
        .alert("Save Active Deck?", isPresented: $isShowingSaveDeckConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Save") { viewModel.persistActiveDeckToSlot(index: viewModel.options.activeDeckIndex) }
        } message: {
            Text("This will overwrite your active saved deck slot with the cards you currently have, including any swaps from post-match rewards.")
        }
        .sheet(isPresented: $showingDecks) {
            HoneycombDecksView(activeDeckIndex: $viewModel.options.activeDeckIndex)
        }
        .sheet(isPresented: $showingRules) {
            HoneycombRulesView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingStats) {
            HoneycombStatsView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingOptions) {
            HoneycombOptionsView(viewModel: viewModel, isPresented: $showingOptions, isShowingStats: $showingStats, coordinator: coordinator, availableWidth: toolbarWidth, availableHeight: windowContentHeight)
        }
        .environment(\.activeCardBackTheme, coordinator.cardBackTheme)
        .environment(\.activeCustomCardColors, coordinator.customCardColors)
        .frame(minWidth: Self.minWindowSize.width,
               maxWidth: .infinity,
               minHeight: Self.minWindowSize.height,
               maxHeight: .infinity)
        .onAppear { applyInitialWindowSize() }
        .background(WindowAccessor(callback: { window in
            self.hostingWindow = window
            self.zoomController = WindowZoomController(window: window)
            coordinator.activeWindow = window
            applyInitialWindowSize()
        }, onResize: recomputeScale))
    }

    // Continuously refits the hand/board layout's scale to the window's current content
    // size, the same way every other game does — called on every window resize (via
    // WindowAccessor's onResize) so the fixed 128×181 card metrics never overflow the window.
    // The Game Area's true (unscaled) size — shared by recomputeScale (to derive the
    // fit-to-window scale) and the body (to re-constrain the layout footprint to the
    // *scaled* size after .scaleEffect, the same way every other game's board does).
    // .scaleEffect only changes how a view renders, not the space its parent reserves
    // for it — without this, the outer ZStack centers this view at its full native
    // size, and once that's taller than the window (as it now easily is, with the
    // board's much larger cards), it overflows equally above and below, pushing the
    // toolbar off the top of the window.
    private var intrinsicContentSize: CGSize {
        // Each hand column is a 2-2-1 pyramid (3 rows tall, 2 cards wide), nudged down
        // by handTopOffset to align its top row with the board's top row.
        let handColHeight: CGFloat = Self.handTopOffset + 3 * Self.handCardSize.height + 2 * Self.handGridSpacing

        // Center column: rules banner above the board.
        let boardWidth: CGFloat = 3 * Self.boardCardSize.width + 2 * Self.boardGridSpacing
        let boardHeight: CGFloat = 3 * Self.boardCardSize.height + 2 * Self.boardGridSpacing
        let centerHeight: CGFloat = Self.rulesBannerHeight + 12 + boardHeight

        let width: CGFloat = Self.handColumnWidth * 2 + boardWidth + 32 + 40
        let height: CGFloat = max(handColHeight, centerHeight) + 40
        return CGSize(width: width, height: height)
    }

    private func recomputeScale() {
        guard let window = hostingWindow else { return }
        let contentSize = window.contentView?.frame.size ?? window.frame.size
        toolbarWidth = contentSize.width
        windowContentHeight = contentSize.height

        let size = intrinsicContentSize
        let scaleX = contentSize.width / size.width
        let scaleY = (contentSize.height - Self.toolbarHeight) / size.height
        viewModel.zoomScale = min(2.0, max(0.3, min(scaleX, scaleY)))
    }

    // Applies the window's opening size and refits the scale — called at app launch and
    // every time this game becomes active again.
    private func applyInitialWindowSize() {
        guard let window = hostingWindow else { return }
        window.contentMinSize = Self.minWindowSize
        recomputeScale()
    }

    // Rules text shown in the banner: once a match is actually playing (or in Sudden
    // Death), this is the real `activeRules` that were rolled/locked in for it. Before
    // that (setup, or sitting on the post-game prompt) `activeRules` is just whatever
    // was left over from the last match, which used to make this banner show "Normal"
    // even with rules selected — so pre-game it instead previews what Start Match will
    // actually use: the manual selection, force-Normal, or "Roulette" when neither is
    // set and the rules will be randomized when the match starts.
    private var rulesBannerLines: [String] {
        if viewModel.gameState == .playing || viewModel.gameState == .suddenDeath {
            return viewModel.activeRules.isEmpty ? ["Normal"] : viewModel.activeRules.map(\.rawValue)
        }
        if viewModel.options.forceNormalMode {
            return ["Normal"]
        }
        if !viewModel.options.selectedRules.isEmpty {
            return HoneycombRule.allCases
                .filter { viewModel.options.selectedRules.contains($0) }
                .map(\.rawValue)
        }
        return ["Roulette"]
    }

    // Active-rules banner shown above the board. Every Text here is .fixedSize() —
    // same reasoning as StatusItemView elsewhere in the app — so it always claims its
    // true natural width instead of being squeezed/truncated when the row is tight.
    private var rulesBanner: some View {
        VStack(spacing: 6) {
            Text("Rules:")
                .font(.system(size: 28, weight: .black))
                .foregroundColor(.yellow)
                .fixedSize()
            ForEach(rulesBannerLines, id: \.self) { line in
                Text(line)
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(.yellow)
                    .fixedSize()
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .background(Color.black.opacity(0.75))
        .cornerRadius(16)
    }

    // "PLAYER"/"DEALER" label above each hand column.
    private func handSideLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 20, weight: .heavy, design: .rounded))
            .kerning(1.5)
            .foregroundColor(.white.opacity(0.85))
            .frame(height: Self.handLabelBlockHeight - 6)
    }

    // Arranges up to 5 cards as a 2-2-1 pyramid (2 top, 2 middle, 1 bottom, centered).
    // Iterates the cards themselves (by their own stable `id`) rather than a positional
    // index range — the backing arrays shrink as cards are played, and a positional
    // ForEach can briefly hand the content closure a now-out-of-bounds index
    // mid-removal-animation.
    @ViewBuilder
    private func handGrid<Content: View>(hand: [HoneycombCard], @ViewBuilder content: @escaping (HoneycombCard) -> Content) -> some View {
        VStack(spacing: Self.handGridSpacing) {
            HStack(spacing: Self.handGridSpacing) {
                ForEach(Array(hand.prefix(2))) { card in content(card) }
            }
            if hand.count > 2 {
                HStack(spacing: Self.handGridSpacing) {
                    ForEach(Array(hand.dropFirst(2).prefix(2))) { card in content(card) }
                }
            }
            if hand.count > 4 {
                HStack(spacing: Self.handGridSpacing) {
                    ForEach(Array(hand.dropFirst(4))) { card in content(card) }
                }
            }
        }
    }

    @ViewBuilder
    private func playerHandCardView(card: HoneycombCard) -> some View {
        // Under Order/Chaos, only one card in hand is legal to play this turn —
        // highlighted with the same thick ownership-border treatment the board uses,
        // in the player's own highlight color, and every other card is inert.
        let handIndex = viewModel.playerHand.firstIndex(where: { $0.id == card.id })
        let isMandated = viewModel.gameState == .playing
            && viewModel.mandatedPlayerHandIndex != nil
            && viewModel.mandatedPlayerHandIndex == handIndex
        let isLegalToPlay = viewModel.mandatedPlayerHandIndex == nil || viewModel.mandatedPlayerHandIndex == handIndex

        HoneycombCardView(card: card, size: Self.handCardSize, isFlipped: false)
            .matchedGeometryEffect(id: card.id, in: swapAnimationNamespace)
            .onTapGesture {
                if viewModel.gameState == .playing && viewModel.isPlayerTurn && isLegalToPlay {
                    selectedHandCardId = card.id
                } else if isStealingCard, viewModel.showPostGamePrompt, viewModel.gameState == .gameOver,
                          let boardIdx = stealBoardIndex,
                          let replaceIdx = viewModel.playerStartingDeck.firstIndex(where: { $0.id == card.id }) {
                    viewModel.requestSwap(boardIndex: boardIdx, replaceHandIndex: replaceIdx)
                }
            }
            .onDrag {
                if viewModel.gameState == .playing && viewModel.isPlayerTurn && isLegalToPlay {
                    draggingHandCardId = card.id
                    return NSItemProvider(object: card.id as NSString)
                }
                return NSItemProvider()
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.blue, lineWidth: selectedHandCardId == card.id ? 4 : 0)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(coordinator.honeycombPlayerHighlightColor, lineWidth: isMandated ? 14 : 0)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.yellow, lineWidth: viewModel.swapHighlightCardIds.contains(card.id) ? 14 : 0)
            )
            // Post-game Swap Drop Target
            .onDrop(of: [.plainText], isTargeted: nil) { providers in
                guard viewModel.showPostGamePrompt, viewModel.gameState == .gameOver else { return false }
                guard let opponentIdx = draggingOpponentCardIndex,
                      let replaceIdx = viewModel.playerStartingDeck.firstIndex(where: { $0.id == card.id }) else { return false }
                viewModel.requestSwap(boardIndex: opponentIdx, replaceHandIndex: replaceIdx)
                draggingOpponentCardIndex = nil
                return true
            }
    }

    @ViewBuilder
    private func opponentHandCardView(card: HoneycombCard) -> some View {
        // Face-up only for the deliberate post-win "Take a Card" reveal, or when a rule
        // (All Open/Three Open) specifically uncovers this card — any other non-.playing
        // state (idle .setup between matches, or a loss/draw's gameOver) previously fell
        // through to "reveal everything" too, since the check was just `!= .playing`
        // rather than the specific win-reveal condition.
        let isPostWinReveal = viewModel.gameState == .gameOver && viewModel.showPostGamePrompt && viewModel.matchResult == "You Win!"
        let flipped = !isPostWinReveal && !viewModel.isOpponentCardVisible(cardId: card.id)
        // Same Order/Chaos highlight as the player's hand, but in the opponent's own
        // highlight color — shown as soon as it's decided (Order: always; Chaos:
        // re-rolled the instant their turn starts), which is before the opponentMoveDelay
        // pause elapses and the AI actually plays it, so the player gets advance notice.
        let handIndex = viewModel.opponentHand.firstIndex(where: { $0.id == card.id })
        let isMandated = viewModel.gameState == .playing
            && !viewModel.isPlayerTurn
            && viewModel.mandatedOpponentHandIndex != nil
            && viewModel.mandatedOpponentHandIndex == handIndex

        HoneycombCardView(card: card, size: Self.handCardSize, isFlipped: flipped)
            .matchedGeometryEffect(id: card.id, in: swapAnimationNamespace)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(coordinator.honeycombOpponentHighlightColor, lineWidth: isMandated ? 14 : 0)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.yellow, lineWidth: viewModel.swapHighlightCardIds.contains(card.id) ? 14 : 0)
            )
    }

    @State private var selectedHandCardId: String? = nil
}

// MARK: - Options Preference Dialog
struct HoneycombOptionsView: View {
    @Bindable var viewModel: HoneycombViewModel
    @Binding var isPresented: Bool
    @Binding var isShowingStats: Bool
    @Bindable var coordinator: AppCoordinator

    @State private var isSoundEnabled: Bool
    @State private var noStressMode: Bool
    let availableWidth: CGFloat
    let availableHeight: CGFloat

    init(viewModel: HoneycombViewModel, isPresented: Binding<Bool>, isShowingStats: Binding<Bool>, coordinator: AppCoordinator, availableWidth: CGFloat = 2000, availableHeight: CGFloat = 900) {
        self.viewModel = viewModel
        self._isPresented = isPresented
        self._isShowingStats = isShowingStats
        self.coordinator = coordinator
        self.availableWidth = availableWidth
        self.availableHeight = availableHeight
        _isSoundEnabled = State(initialValue: viewModel.options.isSoundEnabled)
        _noStressMode = State(initialValue: viewModel.options.noStressMode)
    }

    var body: some View {
        OptionsSheetShell(
            isPresented: $isPresented,
            coordinator: coordinator,
            availableWidth: availableWidth,
            availableHeight: availableHeight,
            onViewStats: { isShowingStats = true },
            onOK: {
                var updatedOpts = viewModel.options
                updatedOpts.isSoundEnabled = isSoundEnabled
                updatedOpts.noStressMode = noStressMode
                viewModel.options = updatedOpts
            }
        ) {
            Toggle("Sound Effects", isOn: $isSoundEnabled)
                .font(.system(.body))

            Toggle("No Stress Mode", isOn: $noStressMode)
                .font(.system(.body))
        }
    }
}

struct HoneycombRulesView: View {
    @Bindable var viewModel: HoneycombViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Difficulty", selection: $viewModel.options.difficulty) {
                        ForEach(HoneycombDifficulty.allCases, id: \.self) { diff in
                            Text(diff.rawValue).tag(diff)
                        }
                    }
                }

                Section {
                    Toggle("Normal Mode (Force Zero Rules)", isOn: Binding(
                        get: { viewModel.options.forceNormalMode },
                        set: { isOn in
                            viewModel.options.forceNormalMode = isOn
                            if isOn {
                                // Locking in "definitely zero rules" is exclusive with
                                // any manual rule picks below.
                                viewModel.options.selectedRules.removeAll()
                            }
                        }
                    ))
                } footer: {
                    Text("Guarantees a plain match with no active rules, instead of leaving it up to roulette.")
                        .font(.caption)
                }

                Section {
                    ForEach(HoneycombRule.allCases, id: \.self) { rule in
                        Toggle(rule.rawValue, isOn: Binding(
                            get: { viewModel.options.selectedRules.contains(rule) },
                            set: { isOn in
                                if isOn {
                                    // Max 2 rules
                                    if viewModel.options.selectedRules.count < 2 {
                                        viewModel.options.selectedRules.insert(rule)
                                        // Mutually exclusive logic
                                        if rule == .ascension { viewModel.options.selectedRules.remove(.descension) }
                                        if rule == .descension { viewModel.options.selectedRules.remove(.ascension) }
                                        if rule == .order { viewModel.options.selectedRules.remove(.chaos) }
                                        if rule == .chaos { viewModel.options.selectedRules.remove(.order) }
                                        if rule == .allOpen { viewModel.options.selectedRules.remove(.threeOpen) }
                                        if rule == .threeOpen { viewModel.options.selectedRules.remove(.allOpen) }
                                        // Picking an actual rule overrides forced Normal Mode.
                                        viewModel.options.forceNormalMode = false
                                    }
                                } else {
                                    viewModel.options.selectedRules.remove(rule)
                                }
                            }
                        ))
                        .disabled(viewModel.options.forceNormalMode)
                    }
                } footer: {
                    Text("Select up to 2 rules. Leave empty (and Normal Mode off) to let roulette decide each match — including occasionally rolling no rules at all.")
                        .font(.caption)
                }
            }
            .navigationTitle("Match Rules")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(width: 420, height: 480)
    }
}
