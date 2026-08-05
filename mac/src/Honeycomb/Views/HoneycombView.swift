import SwiftUI

// Deal-flip: reuses the exact same 3D flip mechanism as HoneycombCardView's own
// ownership/reveal flips (rotate 180° over HoneycombFlipTiming.duration, swap
// content at the edge-on midpoint, un-mirror the second half) rather than a
// separate SwiftUI transition — so every "a Honeycomb card turns over" moment in
// the app shares one implementation. `front` is the face-down placeholder shown
// before `isRevealed` flips true; `back` is the real, face-up interactive card.
fileprivate struct HoneycombFlipContainer<Front: View, Back: View>: View {
    let isRevealed: Bool
    @ViewBuilder let front: () -> Front
    @ViewBuilder let back: () -> Back

    @State private var flipDegrees: Double = 0
    @State private var isPastMidpoint: Bool = false
    @State private var displayedRevealed: Bool

    init(isRevealed: Bool, @ViewBuilder front: @escaping () -> Front, @ViewBuilder back: @escaping () -> Back) {
        self.isRevealed = isRevealed
        self.front = front
        self.back = back
        _displayedRevealed = State(initialValue: isRevealed)
    }

    var body: some View {
        Group {
            if displayedRevealed { back() } else { front() }
        }
        .scaleEffect(x: isPastMidpoint ? -1 : 1, y: 1)
        .rotation3DEffect(.degrees(flipDegrees), axis: (x: 0, y: 1, z: 0))
        .onChange(of: isRevealed) { oldValue, newValue in
            guard oldValue != newValue else { return }
            withAnimation(.easeInOut(duration: HoneycombFlipTiming.duration)) {
                flipDegrees += 180
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + HoneycombFlipTiming.midpointDelay) {
                displayedRevealed = newValue
                isPastMidpoint.toggle()
            }
        }
    }
}

// Nectar Exchange's Lift/Touchdown scale+shadow — 1.75x scale and a deep shadow
// while lifting/moving, smoothly back to 1.0x/no shadow on landing. zIndex lifts
// the animating card above the board cells its interpolated position passes over
// mid-flight (the hand columns sit either side of the board in the same HStack,
// so without this the card would render underneath the board during the cross).
fileprivate struct SwapLiftEffect: ViewModifier {
    let isAnimating: Bool
    let phase: HoneycombViewModel.SwapAnimationPhase

    private var isElevated: Bool {
        isAnimating && (phase == .lifting || phase == .moving)
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(isElevated ? 1.75 : 1.0)
            .shadow(color: .black.opacity(isElevated ? 0.5 : 0), radius: isElevated ? 20 : 0)
            .zIndex(isAnimating ? 100 : 0)
    }
}

public struct HoneycombView: View {
    @Bindable var viewModel: HoneycombViewModel
    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator
    
    public static let minWindowSize = NSSize(width: 700, height: 500)
    private static let toolbarHeight: CGFloat = 90
    // Hands sit on either side of the board, each arranged as a 2-2-1 pyramid, so a
    // hand column is only ever 2 cards wide. Sized up to use more of the side margin
    // between the board and the window edge.
    private static let handCardSize = CGSize(width: 195, height: 195 * CardDimensions.aspectRatio)
    private static let boardCardSize = handCardSize
    private static let handGridSpacing: CGFloat = 4
    private static let boardGridSpacing: CGFloat = 10
    private static let handColumnWidth = 2 * handCardSize.width + handGridSpacing
    // Shown face-down in both hand columns before a match starts (.setup) — a preview
    // that 5 cards are loaded and ready on each side, rather than leaving the columns
    // looking broken/empty. Content is irrelevant (never flipped face-up), so a single
    // fixed placeholder repeated 5x is enough; ids are fixed strings (not the default
    // random-UUID init) so SwiftUI's ForEach identity stays stable across re-renders
    // instead of reshuffling/re-animating every frame.
    private static let placeholderHand: [HoneycombCard] = (0..<5).map { i in
        HoneycombCard(
            data: HoneycombCardData(id: -1, name: "", stars: 1, stats: [1, 1, 1, 1], suit: "S"),
            owner: .player,
            id: "placeholder-\(i)"
        )
    }
    // Approximate rendered height of the rules banner above the board — used to nudge
    // the hand columns down so their top row lines up with the board's top row instead
    // of the banner's.
    private static let rulesBannerHeight: CGFloat = 120
    private static let handTopOffset: CGFloat = rulesBannerHeight + 12
    // "PLAYER"/"DEALER" labels sit inside that same top-offset space, above the hand
    // grid, so the grid's first row still lands in the same place as before — this is
    // subtracted from handTopOffset rather than added on top of it.
    private static let handLabelBlockHeight: CGFloat = 34
    // Side padding for the hand/board row, matching Klondike's card rows
    // (GameView's `.padding(.horizontal, 20)` on its piles/tableau HStacks).
    private static let boardRowHorizontalPadding: CGFloat = 40
    private static let boardRowVerticalPadding: CGFloat = 20
    // Space below the hand columns/board down to the window's bottom edge — kept
    // separate from boardRowVerticalPadding (which still governs the top) since the
    // two edges don't need to match.
    private static let boardRowBottomPadding: CGFloat = 40
    // Spacing between the hand columns, board, and the Spacers separating them —
    // the HStack has 5 children (hand, Spacer, board, Spacer, hand), so 4 gaps.
    private static let boardRowSpacing: CGFloat = 16
    // Mid-match (.playing/.suddenDeath) the toolbar only ever shows Quit Match/
    // Options/Undo — no more buttons than Klondike's — so it uses that same shared
    // 830pt threshold. Outside a match, the button count varies (Start Match, Options,
    // Manage Decks, plus Rematch when available), so only bump up to the wider 1100pt
    // threshold when that extra button is actually showing — otherwise it's no busier
    // than the in-match toolbar and 830 is just as accurate, instead of staying
    // needlessly compact at widths that fit fine.
    private var compactToolbarWidthThreshold: CGFloat {
        switch viewModel.gameState {
        case .playing, .suddenDeath:
            return 830
        case .gameOver:
            return viewModel.canRematch ? 1100 : 830
        default: // .setup
            return 830
        }
    }

    @State private var toolbarWidth: CGFloat = 2000
    @State private var windowContentHeight: CGFloat = 900

    @State private var showingDecks = false
    @State private var showingStats = false
    @State private var showingOptions = false
    @State private var showingRules = false

    // Drag-and-drop for playing a hand card onto the board uses a custom DragGesture
    // (matching every other mac game — see PileView/GameView) rather than SwiftUI's
    // system .onDrag/.onDrop. System drag-and-drop hands the drag off to AppKit, which
    // is free to let it leave the window into other apps or the desktop; a DragGesture
    // is just view state, so the dragged card can never render outside this view.
    //
    // dragLocation/dragOffset are captured in .global coordinate space (see the
    // DragGesture below) and boardCellFrames is populated from GeometryReader's
    // .global frame too — both must stay in the same space, since drop hit-testing
    // and the floating overlay's .position(...) both mix values from each.
    @State private var draggedHandCard: HoneycombCard? = nil
    @State private var dragLocation: CGPoint = .zero
    @State private var dragOffset: CGSize = .zero
    @State private var boardCellFrames: [Int: CGRect] = [:]

    // Banner state
    @State private var showingRuleBanner = false
    @State private var bannerText = ""
    @State private var bannerTask: DispatchWorkItem? = nil

    @State private var showNoHintsBanner = false
    @State private var noHintsBannerTask: DispatchWorkItem? = nil

    @State private var isShowingNewGameConfirm = false
    @State private var isShowingRematchConfirm = false
    @State private var isHoveringRules = false

    // Deal-flip: both hand columns show face-down placeholders during .setup, then
    // flip to reveal the freshly dealt hands one card at a time once a match actually
    // starts — mirrors the Windows port's sequential per-card reveal (HoneycombView's
    // Refresh() awaits each hand slot's RenderCard/PlayRevealAnimation in turn: all 5
    // player cards, then all 5 opponent cards), which mac previously had no equivalent
    // animation for at all (the ForEach identity swap from placeholder ids to the real
    // per-card ids happened instantly, with no transition, all at once). Indexed 0..4
    // per hand; starts all-false to match gameState's own initial .setup value.
    @State private var isPlayerCardRevealed: [Bool] = Array(repeating: false, count: 5)
    @State private var isOpponentCardRevealed: [Bool] = Array(repeating: false, count: 5)
    // Bumped every time gameState returns to .setup (see the gameState onChange below)
    // and applied as .id() on each hand grid — forces a clean teardown/recreation of
    // every HoneycombFlipContainer at that exact boundary instead of letting one
    // linger mid-flip. Without this, quitting/finishing a match while a container's
    // displayedRevealed hadn't yet caught up to isPlayerCardRevealed's instant reset
    // could render playerHandCardView/opponentHandCardView (whose
    // matchedGeometryEffect keys off card.id) against placeholder data for one frame —
    // and since both hands' placeholders share the same 5 fixed ids, SwiftUI would try
    // to interpolate that id's geometry between the player's and dealer's hand
    // columns, producing a huge, rotated, screen-filling card.
    @State private var handIdentityToken: Int = 0
    // Time between each card's flip starting — matches HoneycombFlipTiming.duration so
    // cards flip one after another with no overlap, like the Windows port's own
    // sequential (awaited) deal-flip, rather than the staggered/overlapping cadence
    // this used before. Must stay in sync with the ViewModel's dealFlipTotalDuration
    // (shared/Honeycomb/ViewModels/HoneycombViewModel.swift), which the Nectar
    // Exchange trade's own start delay is derived from.
    private static let dealFlipStagger: Double = HoneycombFlipTiming.duration

    // Shared across both hand columns so a Swap trade's two cards can visually slide
    // from one hand to the other — SwiftUI interpolates a matchedGeometryEffect'd
    // view's frame across any parent within the same namespace.
    @Namespace private var swapAnimationNamespace

    // "Steal Card" mode: double-click an eligible captured opponent card on the board
    // to steal it straight into the card bank.
    @State private var isStealingCard = false

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
                    // Also shown for .gameOver, not just .setup — the match is already
                    // over at that point, so "Quit Match" would be a no-op relabeled as
                    // a way to reach Start Match, and dismissing the post-game banner's
                    // "x" (which only clears showPostGamePrompt, not gameState) would
                    // otherwise leave no obvious way to start a new one.
                    if viewModel.gameState != .playing && viewModel.gameState != .suddenDeath {
                        GameToolbarButton(
                            label: "Start Match", systemImage: "play.fill",
                            isCompact: toolbarWidth < compactToolbarWidthThreshold
                        ) { viewModel.startNewGame() }

                        // Mirrors the post-game overlay's Rematch button, for whenever
                        // that overlay's been dismissed (its "x") to look at the
                        // finished board — otherwise the toolbar's only path back in
                        // was Start Match, silently losing the option to replay the
                        // same opponent instead of rolling a fresh one.
                        if viewModel.gameState == .gameOver && viewModel.canRematch {
                            GameToolbarButton(
                                label: "Rematch", systemImage: "arrow.counterclockwise",
                                isCompact: toolbarWidth < compactToolbarWidthThreshold
                            ) { viewModel.rematch() }
                        }
                    } else {
                        GameToolbarButton(
                            label: "Quit Match", systemImage: "flag.fill",
                            isCompact: toolbarWidth < compactToolbarWidthThreshold
                        ) { viewModel.quitMatch() }
                    }

                    GameToolbarButton(
                        label: "Options", systemImage: "gearshape",
                        isCompact: toolbarWidth < compactToolbarWidthThreshold
                    ) { showingOptions = true }

                    GameToolbarButton(
                        label: "Rules", systemImage: "checklist",
                        isCompact: toolbarWidth < compactToolbarWidthThreshold
                    ) { showingRules = true }

                    // Manage Decks is shown for .setup *and* .gameOver — the match is
                    // already over at that point, so there's no more Undo to offer and
                    // it becomes relevant again rather than staying hidden until the
                    // player explicitly quits back to .setup.
                    if viewModel.gameState == .playing || viewModel.gameState == .suddenDeath {
                        // Never shown on Ultra Hard — that difficulty is meant to stay
                        // fully self-directed, no optimal-move assistance.
                        if !viewModel.options.hideHintButton && viewModel.options.difficulty != .ultraHard {
                        GameToolbarButton(
                            label: "Hint", systemImage: "lightbulb",
                            isCompact: toolbarWidth < compactToolbarWidthThreshold,
                            disabled: !viewModel.isPlayerTurn || viewModel.isAnimatingPlacement
                        ) {
                            if viewModel.hasHintsAvailable {
                                viewModel.findHint()
                            } else {
                                flashNoHintsBanner()
                            }
                        }
                        .keyboardShortcut("h", modifiers: .command)
                        }

                        GameToolbarButton(
                            label: "Undo", systemImage: "arrow.uturn.backward",
                            isCompact: toolbarWidth < compactToolbarWidthThreshold,
                            disabled: !viewModel.canUndo
                        ) { viewModel.undoLastAction() }
                        .keyboardShortcut("z", modifiers: .command)
                    } else if !viewModel.options.noStressMode {
                        // Manage Decks edits the player's active deck composition —
                        // meaningless under No Stress Mode, which always deals a
                        // fixed/random hand instead of that deck.
                        GameToolbarButton(
                            label: "Manage Decks", systemImage: "square.grid.2x2",
                            isCompact: toolbarWidth < compactToolbarWidthThreshold
                        ) { showingDecks = true }
                    }
                    
                    Spacer()

                    if viewModel.gameState != .setup {
                        HStack {
                            StatusItemView(label: "You", value: "\(viewModel.board.playerScore + viewModel.playerHand.count)")
                            StatusItemView(label: viewModel.options.difficulty.displayName, value: "\(viewModel.board.opponentScore + viewModel.opponentHand.count)")
                        }
                    }
                }
                // Pinned to a fixed content height so the row never grows/shrinks as its
                // children change — the YOU/OPPONENT StatusItemView (two stacked lines)
                // only appears once gameState != .setup and is taller than the single-line
                // buttons/dropdown, so without this the whole row (and everything below
                // it: divider, board, hands) visibly shifted by a few px the moment a
                // match started. Matches the height already assumed by toolbarHeight
                // (90 = this 48 + the 36/6 top/bottom padding below) that recomputeScale
                // uses for its own fit-to-window math.
                .frame(height: 48)
                .padding(.horizontal, 16)
                .padding(.top, 36) // Clear the macOS traffic light window controls
                .padding(.bottom, 6)
                .layoutPriority(1)

                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 1)

                // Game Area — hands sit on either side of the board, each arranged as a
                // 2-2-1 pyramid (2 top, 2 middle, 1 bottom centered).
                HStack(alignment: .top, spacing: Self.boardRowSpacing) {
                    // Player Hand (Left) — nudged down to align with the board's top
                    // row rather than the rules banner above it.
                    let displayHand: [HoneycombCard] = viewModel.gameState == .setup ? Self.placeholderHand
                        : (viewModel.gameState == .gameOver ? viewModel.playerStartingDeck : viewModel.playerHand)
                    VStack(spacing: 6) {
                        handSideLabel("PLAYER")
                        handGrid(hand: displayHand) { i, card in
                            HoneycombFlipContainer(isRevealed: isPlayerCardRevealed[i]) {
                                HoneycombCardView(card: card, size: Self.handCardSize, isFlipped: true)
                            } back: {
                                // Re-keyed by card.id (unlike the container/ForEach
                                // row, which are position-keyed for the deal-flip's
                                // sake — see handGrid) so a Nectar Exchange trade
                                // reads as a genuine remove-here/insert-there to
                                // SwiftUI, which matchedGeometryEffect needs to
                                // detect the relocation and slide it; a persisting
                                // view whose card.id merely changes value doesn't
                                // trigger that interpolation, and the trade "bounces
                                // back" to its old spot instead of visibly moving.
                                playerHandCardView(card: card)
                                    .id(card.id)
                            }
                            .id(handIdentityToken)
                        }
                    }
                    .padding(.top, Self.handTopOffset - Self.handLabelBlockHeight)
                    .frame(width: Self.handColumnWidth)
                    // Nectar Exchange's ballooned Lift/Flight card overflows well past
                    // this column's own frame width toward the board — without this,
                    // the Board VStack (a sibling in this same HStack, declared after
                    // this column) draws on top of it and clips it visually at the
                    // column boundary. Raised only during the animation so normal play
                    // (drag-to-board, etc.) keeps its usual layering.
                    .zIndex(viewModel.swapAnimationPhase == .idle ? 0 : 100)

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
                                                // Steal-eligible = the opponent originally played this card AND
                                                // the player actually captured it this round (owner == .player
                                                // at match end — a card the opponent still holds was never
                                                // captured, so it isn't stealable) AND not already in your Card
                                                // Bank (stealing it wouldn't gain anything new).
                                                let stealEligible = isStealingCard
                                                    && card.originalOwner == .opponent
                                                    && card.owner == .player
                                                    && !HoneycombProfileManager.shared.unlockedCardIds.contains(card.data.id)
                                                let highlightIndices: Set<Int> = viewModel.pointHighlight?.cardId == card.id
                                                    ? viewModel.pointHighlight!.statIndices
                                                    : []
                                                HoneycombCardView(card: card, size: Self.boardCardSize, isFlipped: false, stealHighlight: stealEligible, highlightedStatIndices: highlightIndices)
                                            }
                                        }
                                        .modifier(HintHighlightModifier(isHighlighted: viewModel.activeHint?.boardIndex == index))
                                        .onTapGesture {
                                            if viewModel.gameState == .playing && viewModel.isPlayerTurn,
                                               let cardId = selectedHandCardId,
                                               let handIdx = viewModel.playerHand.firstIndex(where: { $0.id == cardId }) {
                                                // Only clear the selection if the card actually got placed — a tap
                                                // that lands in the brief isAnimatingPlacement window right as the
                                                // player's turn starts is a legitimate no-op, and deselecting
                                                // anyway would silently drop the tap and make it look broken.
                                                if viewModel.playerPlayCard(handIndex: handIdx, boardIndex: index) {
                                                    selectedHandCardId = nil
                                                }
                                            }
                                        }
                                        // Steal mode: double-click an eligible captured opponent card to
                                        // steal it straight into the card bank — a single step to the
                                        // confirmation alert, no hand-slot target needed.
                                        .onTapGesture(count: 2) {
                                            if isStealingCard, viewModel.showPostGamePrompt, viewModel.gameState == .gameOver,
                                               cell.card?.originalOwner == .opponent, cell.card?.owner == .player,
                                               let cardId = cell.card?.data.id, !HoneycombProfileManager.shared.unlockedCardIds.contains(cardId) {
                                                viewModel.requestSteal(boardIndex: index)
                                            }
                                        }
                                        .background(GeometryReader { geo in
                                            let frame = geo.frame(in: .global)
                                            Color.clear
                                                .onAppear { boardCellFrames[index] = frame }
                                                .onChange(of: frame) { _, newFrame in
                                                    boardCellFrames[index] = newFrame
                                                }
                                        })
                                    }
                                }
                            }
                        }
                    }

                    Spacer()

                    // Opponent Hand (Right) — same top offset as the player's hand.
                    let opponentDisplayHand = viewModel.gameState == .setup ? Self.placeholderHand : viewModel.opponentHand
                    VStack(spacing: 6) {
                        handSideLabel("DEALER")
                        handGrid(hand: opponentDisplayHand) { i, card in
                            HoneycombFlipContainer(isRevealed: isOpponentCardRevealed[i]) {
                                HoneycombCardView(card: card, size: Self.handCardSize, isFlipped: true)
                            } back: {
                                // See the player hand's matching .id(card.id) above.
                                opponentHandCardView(card: card)
                                    .id(card.id)
                            }
                            .id(handIdentityToken)
                        }
                    }
                    .padding(.top, Self.handTopOffset - Self.handLabelBlockHeight)
                    .frame(width: Self.handColumnWidth)
                    // See the matching comment on the player hand's own .zIndex above.
                    .zIndex(viewModel.swapAnimationPhase == .idle ? 0 : 100)
                }
                .padding(.horizontal, Self.boardRowHorizontalPadding)
                .padding(.top, Self.boardRowVerticalPadding)
                .padding(.bottom, Self.boardRowBottomPadding)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            // Post Game Overlay — hidden while actively picking cards to steal, so the
            // board and hands underneath are clickable. Also held back while a rule
            // banner (Combo/Same/Plus/Ascension/Descension) is still visibly on screen,
            // regardless of which move it fired on — a banner from the move just before
            // the winning one can still be animating when the match ends, and gating on
            // showingRuleBanner (this view's own source of truth for "is one currently
            // shown") catches that case that a same-move-only check would miss. Once
            // showingRuleBanner flips back to false, this condition re-evaluates on its
            // own and the overlay appears — no extra plumbing needed.
            if viewModel.showPostGamePrompt && !isStealingCard && !showingRuleBanner {
                ZStack(alignment: .topTrailing) {
                    VStack {
                        if viewModel.matchResult == "You Lose" {
                            // Exact match to Video Poker's loss banner (VideoPokerView.swift).
                            Text("Not today, partner!")
                                .font(.system(size: 36, weight: .black))
                                .foregroundColor(.yellow)
                        } else if viewModel.matchResult == "You Win!" {
                            // The win overlay reappears after a steal is confirmed (Steal
                            // Card is now gone, since hasStolenThisMatch is true) — a
                            // repeat "You Win!" would read as stale, so it confirms what
                            // just happened instead.
                            Text(viewModel.hasStolenThisMatch ? "Card added to card bank." : viewModel.matchResult)
                                .font(.system(size: 60, weight: .bold)).foregroundColor(.yellow)
                        } else if viewModel.matchResult == "Tie!" {
                            // Same styling as "You Win!" — Sudden Death is now opt-in, so an
                            // unresolved tie is a final result like a win/loss, not a lesser
                            // outcome. No Steal Card here: every steal conditional below is
                            // already scoped to "You Win!" specifically, so it's excluded for
                            // free.
                            Text(viewModel.matchResult)
                                .font(.system(size: 60, weight: .bold)).foregroundColor(.yellow)
                        } else {
                            Text(viewModel.matchResult).font(.system(size: 60, weight: .bold)).foregroundColor(.white)
                        }

                        if viewModel.matchResult == "You Win!" && !viewModel.options.noStressMode
                            && HoneycombProfileManager.shared.isCardBankFull {
                            Text("Your card bank is full. Start over in manage decks to steal again.")
                                .foregroundColor(.white).padding()
                        } else if viewModel.matchResult == "You Win!" && !viewModel.options.noStressMode
                            && viewModel.hasStolenThisMatch {
                            Text("Rematch to take another.")
                                .foregroundColor(.white).padding()
                        }

                        HStack {
                            Button("New Game") {
                                viewModel.startNewGame()
                            }.buttonStyle(.borderedProminent)

                            // Only available once a match has actually started this
                            // session — nothing to replay before that.
                            if viewModel.canRematch {
                                Button("Rematch") {
                                    viewModel.rematch()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)
                            }

                            // No Stress Mode always deals a fresh random overpowered
                            // deck — stealing a card in would let the player curate a
                            // deck in a mode whose whole point is not choosing one.
                            // Hidden once the card bank is full (nothing left to steal)
                            // or once this match's one steal has already been spent —
                            // Rematch is required to steal again.
                            if viewModel.matchResult == "You Win!" && !viewModel.options.noStressMode
                                && !HoneycombProfileManager.shared.isCardBankFull
                                && !viewModel.hasStolenThisMatch
                                && viewModel.hasStealableCard {
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


            // Floating drag overlay for a hand card being dragged onto the board — a plain
            // SwiftUI view positioned within this ZStack (not a system drag session), so
            // it's structurally confined to the window and can never render into another
            // app or the desktop.
            if let draggedHandCard {
                HoneycombCardView(card: draggedHandCard, size: Self.boardCardSize, isFlipped: false)
                    .position(x: dragLocation.x + dragOffset.width, y: dragLocation.y + dragOffset.height)
                    .allowsHitTesting(false)
                    .zIndex(200)
            }

            // Steal Card mode instruction bar has been moved to rulesBanner

            // Banner Overlay — shared by Ascension/Descension/Same/Plus/Sudden Death.
            if showingRuleBanner {
                FlashBannerView(message: bannerText)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(100)
            }

            if showNoHintsBanner {
                FlashBannerView(message: "Sorry! No hints available.")
                    .zIndex(100)
            }
            
            Button(action: {
                if viewModel.gameState == .playing || viewModel.gameState == .suddenDeath {
                    isShowingNewGameConfirm = true
                } else {
                    viewModel.startNewGame()
                }
            }) { EmptyView() }
            .keyboardShortcut("n", modifiers: .command).frame(width: 0, height: 0).opacity(0)
            
            Button(action: {
                if viewModel.canRematch {
                    if viewModel.gameState == .playing || viewModel.gameState == .suddenDeath {
                        isShowingRematchConfirm = true
                    } else {
                        viewModel.rematch()
                    }
                }
            }) { EmptyView() }
            .keyboardShortcut("r", modifiers: .command).frame(width: 0, height: 0).opacity(0)
        }
        .sheet(isPresented: $showingRules) {
            HoneycombRulesView(
                viewModel: viewModel,
                isPresented: $showingRules,
                coordinator: coordinator,
                availableWidth: windowContentHeight * 1.5,
                availableHeight: windowContentHeight
            )
        }
        .onChange(of: viewModel.gameState) { oldState, newState in
            // Safety net: however the match ends up leaving .gameOver (New Game
            // button, surrender, etc.), don't leave steal-card mode stuck active.
            if newState != .gameOver {
                isStealingCard = false
            }
            if newState == .setup {
                // Reset with no animation so the next match's deal starts from
                // placeholders again, ready to flip once more. Bumping
                // handIdentityToken forces every HoneycombFlipContainer to be torn
                // down and rebuilt fresh right here — see its declaration for why.
                isPlayerCardRevealed = Array(repeating: false, count: 5)
                isOpponentCardRevealed = Array(repeating: false, count: 5)
                handIdentityToken += 1
            } else if oldState == .setup {
                // Opponent cards only actually flip face-up during the opening
                // sequence when a rule (Clear Skies/Scouting Party) makes them
                // visible — otherwise they should just quietly appear face-down with
                // no animation, since there's nothing being "revealed." Pre-seed
                // those hidden slots as already-revealed (bumping handIdentityToken
                // so the flip container captures this as its *initial* state,
                // before ever rendering false) so triggerDealFlip's later
                // true-assignment for them is a no-op instead of a real transition
                // — only genuinely visible slots go through the animated flip.
                isOpponentCardRevealed = viewModel.opponentHand.map { !viewModel.isOpponentCardVisible(cardId: $0.id) }
                handIdentityToken += 1
                triggerDealFlip()
            }
        }
        .onChange(of: viewModel.flashRuleBannerTrigger) { _, _ in
            guard let text = viewModel.flashRuleBanner else { return }
            bannerTask?.cancel()
            bannerText = text
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                showingRuleBanner = true
            }
            let task = DispatchWorkItem {
                withAnimation(.easeOut(duration: 0.3)) {
                    showingRuleBanner = false
                }
                // Reveal whatever's queued behind this banner (if anything) once this
                // one has actually finished fading out, instead of a second event
                // silently overwriting it mid-display — see HoneycombViewModel's
                // bannerQueue/advanceBannerQueue().
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    viewModel.advanceBannerQueue()
                }
            }
            let duration = text.hasPrefix("First Move:") ? 2.0 : 1.2
            DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: task)
            bannerTask = task
        }
        .alert(
            "Are you sure you want to steal this card?",
            isPresented: Binding(
                get: { viewModel.pendingSteal != nil },
                set: { if !$0 { viewModel.cancelPendingSteal() } }
            )
        ) {
            Button("Cancel", role: .cancel) { viewModel.cancelPendingSteal() }
            Button("OK") {
                viewModel.confirmPendingSteal()
                isStealingCard = false
                // Falls straight back to the win overlay (still gameOver/showPostGamePrompt,
                // nothing else hides it) rather than a separate Rematch/New Game prompt —
                // its title switches to the steal confirmation since Steal Card is now gone.
            }
        }
        .confirmationDialog("Start a new match? Your current match will end.", isPresented: $isShowingNewGameConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("New Match", role: .destructive) { viewModel.startNewGame() }
        }
        .confirmationDialog("Rematch? Your current match will end.", isPresented: $isShowingRematchConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Rematch", role: .destructive) { viewModel.rematch() }
        }
        .sheet(isPresented: $showingDecks) {
            HoneycombDecksView(activeDeckIndex: $viewModel.options.activeDeckIndex, viewModel: viewModel)
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

        // 5 children (hand, Spacer, board, Spacer, hand) => 4 gaps of boardRowSpacing,
        // plus the row's own horizontal/vertical padding.
        let width: CGFloat = Self.handColumnWidth * 2 + boardWidth
            + 4 * Self.boardRowSpacing + 2 * Self.boardRowHorizontalPadding
        let height: CGFloat = max(handColHeight, centerHeight) + Self.boardRowVerticalPadding + Self.boardRowBottomPadding
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

    private func flashNoHintsBanner() {
        noHintsBannerTask?.cancel()
        withAnimation(.easeIn(duration: 0.15)) { showNoHintsBanner = true }
        let task = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.3)) { showNoHintsBanner = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: task)
        noHintsBannerTask = task
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
            if viewModel.activeRules.isEmpty { return ["Normal"] }
            return viewModel.activeRules.map { rule in
                // Ascension/Descension only affects the 2 suits rolled for this match
                // (setupRules) — call that out here rather than the plain rule name,
                // since which suits are favored/penalized isn't otherwise visible
                // until the player notices it in play.
                if rule == .ascension || rule == .descension, !viewModel.ascensionDescensionSuits.isEmpty {
                    let suitNames = viewModel.ascensionDescensionSuits.sorted()
                        .map { HoneycombCardData.suitDisplayName($0) }
                    return "\(rule.rawValue) Suit: \(suitNames.joined(separator: ", "))"
                }
                return rule.rawValue
            }
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
    @ViewBuilder
    private var rulesBanner: some View {
        if isStealingCard {
            VStack(spacing: 16) {
                Text("Double-click a captured opponent's card\non the board to steal it.")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Button("Cancel") {
                    isStealingCard = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color.black.opacity(0.8))
            .cornerRadius(16)
            .shadow(radius: 20)
            .frame(height: Self.rulesBannerHeight, alignment: .bottom)
        } else {
            let isDense = rulesBannerLines.count > 2
            let titleSize: CGFloat = isDense ? 20 : 28
            let textSize: CGFloat = isDense ? 16 : 22
            let lineSpacing: CGFloat = isDense ? 2 : 6

            VStack(spacing: lineSpacing) {
                Text("Rules:")
                    .font(.system(size: titleSize, weight: .black))
                    .foregroundColor(.yellow)
                    .fixedSize()
                ForEach(rulesBannerLines, id: \.self) { line in
                    Text(line)
                        .font(.system(size: textSize, weight: .black))
                        .foregroundColor(.yellow)
                        .fixedSize()
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 18)
            .background(Color.black.opacity(0.75))
            .cornerRadius(16)
            .onHover { hovering in
                isHoveringRules = hovering
            }
            .popover(isPresented: $isHoveringRules, attachmentAnchor: .point(.bottom), arrowEdge: .bottom) {
                let isPreGame = viewModel.gameState != .playing && viewModel.gameState != .suddenDeath
                let isRoulette = isPreGame && !viewModel.options.forceNormalMode && viewModel.options.selectedRules.isEmpty
                let effectiveRules: [HoneycombRule] = isPreGame && !isRoulette ? Array(viewModel.options.selectedRules) : viewModel.activeRules
                RuleExplanationPopover(viewModel: viewModel, isRoulette: isRoulette, effectiveRules: effectiveRules)
            }
            // A second rule line makes this taller than the reserved rulesBannerHeight —
            // bottom-align it in that reserved box so the extra height grows upward into
            // the empty space above instead of pushing the board down below it.
            .frame(height: Self.rulesBannerHeight, alignment: .bottom)
        }
    }

    // Flips all 10 hand-slot cards one after another — every player card first, then
    // every opponent card — matching the Windows port's own sequential order
    // (HoneycombView.Refresh awaits each player hand slot's RenderCard in turn, then
    // each opponent slot, rather than animating both hands in parallel). The flip
    // itself is driven by HoneycombFlipContainer's own onChange(of: isRevealed), so
    // this just needs to toggle the flags — no withAnimation wrapping needed here.
    private func triggerDealFlip() {
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * Self.dealFlipStagger) {
                isPlayerCardRevealed[i] = true
            }
        }
        for i in 0..<5 {
            let delay = Double(5 + i) * Self.dealFlipStagger
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                isOpponentCardRevealed[i] = true
            }
        }
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
    private func handGrid<Content: View>(hand: [HoneycombCard], @ViewBuilder content: @escaping (Int, HoneycombCard) -> Content) -> some View {
        // Keyed by slot position, not card identity — the deal-flip needs the same
        // HoneycombFlipContainer instance (and its @State) to persist across the
        // placeholder-hand -> real-hand swap, which a card.id-keyed ForEach would
        // instead treat as a remove+insert, resetting the flip mid-animation.
        VStack(spacing: Self.handGridSpacing) {
            HStack(spacing: Self.handGridSpacing) {
                ForEach(Array(hand.prefix(2).enumerated()), id: \.offset) { i, card in content(i, card) }
            }
            if hand.count > 2 {
                HStack(spacing: Self.handGridSpacing) {
                    ForEach(Array(hand.dropFirst(2).prefix(2).enumerated()), id: \.offset) { offset, card in content(offset + 2, card) }
                }
            }
            if hand.count > 4 {
                HStack(spacing: Self.handGridSpacing) {
                    ForEach(Array(hand.dropFirst(4).enumerated()), id: \.offset) { offset, card in content(offset + 4, card) }
                }
            }
        }
    }

    @ViewBuilder
    private func playerHandCardView(card: HoneycombCard) -> some View {
        // Under Order/Chaos, only one card in hand is legal to play this turn —
        // highlighted with a thick yellow border, and every other card is inert.
        let handIndex = viewModel.playerHand.firstIndex(where: { $0.id == card.id })
        let isMandated = viewModel.gameState == .playing
            && viewModel.mandatedPlayerHandIndex != nil
            && viewModel.mandatedPlayerHandIndex == handIndex
        let isLegalToPlay = viewModel.mandatedPlayerHandIndex == nil || viewModel.mandatedPlayerHandIndex == handIndex

        HoneycombCardView(card: card, size: Self.handCardSize, isFlipped: false)
            .matchedGeometryEffect(id: card.id, in: swapAnimationNamespace)
            // Nectar Exchange's Lift/Touchdown scale+shadow — applied *outside*
            // matchedGeometryEffect (as a later modifier) so the card visually
            // balloons while its tracked frame (what matchedGeometryEffect
            // interpolates across the hand columns) stays at normal size.
            .modifier(SwapLiftEffect(isAnimating: viewModel.swapHighlightCardIds.contains(card.id), phase: viewModel.swapAnimationPhase))
            .opacity(draggedHandCard?.id == card.id ? 0.0 : 1.0)
            .onTapGesture {
                if viewModel.gameState == .playing && viewModel.isPlayerTurn && isLegalToPlay {
                    selectedHandCardId = card.id
                }
            }
            .gesture(
                DragGesture(minimumDistance: 5, coordinateSpace: .global)
                    .onChanged { val in
                        guard viewModel.gameState == .playing && viewModel.isPlayerTurn && isLegalToPlay else { return }
                        if draggedHandCard?.id != card.id {
                            draggedHandCard = card
                            dragLocation = val.startLocation
                        }
                        dragOffset = val.translation
                    }
                    .onEnded { val in
                        defer {
                            draggedHandCard = nil
                            dragOffset = .zero
                        }
                        guard viewModel.gameState == .playing && viewModel.isPlayerTurn && isLegalToPlay,
                              let handIdx = viewModel.playerHand.firstIndex(where: { $0.id == card.id }) else { return }
                        let dropPoint = val.location
                        // .first(where:) is safe despite Dictionary's undefined iteration
                        // order only because the 9 board cell frames never overlap — if
                        // that ever changes (e.g. a cell grows to cover a neighbor), this
                        // needs a defined priority instead of picking whichever comes first.
                        if let boardIndex = boardCellFrames.first(where: { $0.value.contains(dropPoint) })?.key,
                           viewModel.playerPlayCard(handIndex: handIdx, boardIndex: boardIndex) {
                            selectedHandCardId = nil
                        }
                    }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.blue, lineWidth: selectedHandCardId == card.id ? 4 : 0)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.yellow, lineWidth: isMandated ? 14 : 0)
            )
            // handIndex is nil once the match ends (displayHand switches to
            // playerStartingDeck, whose card ids no longer appear in the now-empty
            // playerHand) — guarded explicitly rather than just comparing Optionals,
            // since activeHint is also nil post-game and `nil == nil` would otherwise
            // highlight every card in the hand instead of none of them.
            .modifier(HintHighlightModifier(isHighlighted: handIndex != nil && viewModel.activeHint?.handIndex == handIndex))
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
        // Same Order/Chaos highlight as the player's hand — shown as soon as it's
        // decided (Order: always; Chaos: re-rolled the instant their turn starts),
        // which is before the opponentMoveDelay pause elapses and the AI actually
        // plays it, so the player gets advance notice.
        let handIndex = viewModel.opponentHand.firstIndex(where: { $0.id == card.id })
        let isMandated = viewModel.gameState == .playing
            && !viewModel.isPlayerTurn
            && viewModel.mandatedOpponentHandIndex != nil
            && viewModel.mandatedOpponentHandIndex == handIndex

        HoneycombCardView(card: card, size: Self.handCardSize, isFlipped: flipped)
            .matchedGeometryEffect(id: card.id, in: swapAnimationNamespace)
            .modifier(SwapLiftEffect(isAnimating: viewModel.swapHighlightCardIds.contains(card.id), phase: viewModel.swapAnimationPhase))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.yellow, lineWidth: isMandated ? 14 : 0)
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
    @State private var showPointHighlights: Bool
    @State private var hideHintButton: Bool
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
        _showPointHighlights = State(initialValue: viewModel.options.showPointHighlights)
        _hideHintButton = State(initialValue: viewModel.options.hideHintButton)
    }

    var body: some View {
        OptionsSheetShell(
            isPresented: $isPresented,
            coordinator: coordinator,
            availableWidth: availableWidth,
            availableHeight: availableHeight,
            onViewStats: { isShowingStats = true },
            onOK: {
                let wasNoStressMode = viewModel.options.noStressMode
                var updatedOpts = viewModel.options
                updatedOpts.isSoundEnabled = isSoundEnabled
                updatedOpts.noStressMode = noStressMode
                updatedOpts.showPointHighlights = showPointHighlights
                updatedOpts.hideHintButton = hideHintButton
                viewModel.options = updatedOpts
                // Sound/No Stress Mode are app-wide now (AppCoordinator) — pushing the
                // edit there (rather than leaving it only on this game's own options)
                // is what makes it actually apply everywhere instead of getting quietly
                // reverted the next time any game switch reasserts the coordinator's
                // value over this one.
                coordinator.isSoundEnabled = isSoundEnabled
                coordinator.noStressMode = noStressMode
                // No Stress Mode's deck composition is only decided at match start, so
                // toggling it on mid-match has no visible effect until the next deal —
                // silently deal fresh instead of leaving a stale, unapplied setting.
                if noStressMode && !wasNoStressMode && (viewModel.gameState == .playing || viewModel.gameState == .suddenDeath) {
                    viewModel.startNewGame()
                }
            }
        ) {
            Toggle("Sound Effects", isOn: $isSoundEnabled)
                .font(.system(.body))

            Toggle("No Stress Mode", isOn: $noStressMode)
                .font(.system(.body))

            Toggle("Point Highlights", isOn: $showPointHighlights)
                .font(.system(.body))

            Toggle("Hide Hint button", isOn: $hideHintButton)
                .font(.system(.body))

            Divider()
        }
    }
}

// MARK: - Rules Sheet
struct HoneycombRulesView: View {
    @Environment(\.openWindow) private var openWindow
    @Bindable var viewModel: HoneycombViewModel
    @Binding var isPresented: Bool
    @Bindable var coordinator: AppCoordinator

    @State private var difficulty: HoneycombDifficulty
    @State private var forceNormalMode: Bool
    @State private var selectedRules: Set<HoneycombRule>
    @State private var bannedRules: Set<String>
    
    let availableWidth: CGFloat
    let availableHeight: CGFloat

    init(viewModel: HoneycombViewModel, isPresented: Binding<Bool>, coordinator: AppCoordinator, availableWidth: CGFloat = 2000, availableHeight: CGFloat = 900) {
        self.viewModel = viewModel
        self._isPresented = isPresented
        self.coordinator = coordinator
        self.availableWidth = availableWidth
        self.availableHeight = availableHeight
        
        _difficulty = State(initialValue: viewModel.options.difficulty)
        _forceNormalMode = State(initialValue: viewModel.options.forceNormalMode)
        _selectedRules = State(initialValue: viewModel.options.selectedRules)
        _bannedRules = State(initialValue: viewModel.options.bannedRules)
    }

    var body: some View {
        OptionsSheetShell(
            isPresented: $isPresented,
            coordinator: coordinator,
            availableWidth: availableWidth,
            availableHeight: availableHeight,
            title: "Rules",
            showThemes: false,
            onViewStats: {},
            onOK: {
                var updatedOpts = viewModel.options
                updatedOpts.difficulty = difficulty
                updatedOpts.forceNormalMode = forceNormalMode
                updatedOpts.selectedRules = selectedRules
                updatedOpts.bannedRules = bannedRules
                viewModel.options = updatedOpts
            }
        ) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Picker("Opponent", selection: $difficulty) {
                        ForEach(HoneycombDifficulty.allCases, id: \.self) { diff in
                            Text(diff.displayName).tag(diff)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(minWidth: 120)

                    Spacer()

                    Button("Honeycomb Help") { openWindow(id: "honeycomb-help") }
                        .buttonStyle(.bordered)
                }
                .padding(.top, 16)

                Divider()
                
                HStack(alignment: .top, spacing: 40) {
                    // Left Column: Game Choice
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Game Choice")
                            .font(.title2).bold()
                    
                    Text("Select up to 4 rules. Leave empty to let roulette decide each match rules.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Toggle("Normal Mode (Force Zero Rules)", isOn: Binding(
                        get: { forceNormalMode },
                        set: { isOn in
                            forceNormalMode = isOn
                            if isOn {
                                selectedRules.removeAll()
                            }
                        }
                    ))
                    
                    ForEach(HoneycombRule.allCases.filter { $0 != .reverse }, id: \.self) { rule in
                        Toggle(rule.rawValue, isOn: Binding(
                            get: { selectedRules.contains(rule) },
                            set: { isOn in
                                if isOn {
                                    // Remove the exclusive partner (if any) BEFORE the cap
                                    // check — selecting a rule whose partner is already
                                    // selected is a net-zero swap, not an addition, so it
                                    // must never be blocked just because the cap is full.
                                    var updated = selectedRules
                                    if rule == .ascension { updated.remove(.descension) }
                                    if rule == .descension { updated.remove(.ascension) }
                                    if rule == .order { updated.remove(.chaos) }
                                    if rule == .chaos { updated.remove(.order) }
                                    if rule == .allOpen { updated.remove(.threeOpen) }
                                    if rule == .threeOpen { updated.remove(.allOpen) }
                                    // Bomb Shelter's hidden card doesn't work when
                                    // All Open/Three Open reveals every card anyway.
                                    if rule == .allOpen || rule == .threeOpen { updated.remove(.bombShelter) }
                                    if rule == .bombShelter { updated.remove(.allOpen); updated.remove(.threeOpen) }

                                    if updated.count < 4 {
                                        updated.insert(rule)
                                        selectedRules = updated
                                        forceNormalMode = false
                                    }
                                } else {
                                    selectedRules.remove(rule)
                                }
                            }
                        ))
                        .font(.system(.body))
                        .disabled(forceNormalMode)
                        .help(rule.explanation())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Right Column: Ban List
                VStack(alignment: .leading, spacing: 10) {
                    Text("Ban List")
                        .font(.title2).bold()
                    
                    Text("Select games to ban from roulettes.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    let allBanItems = ["Normal Mode"] + HoneycombRule.allCases.map { $0.rawValue }

                    ForEach(allBanItems, id: \.self) { ruleName in
                        HStack {
                            Toggle(ruleName, isOn: Binding(
                                get: { bannedRules.contains(ruleName) },
                                set: { isOn in
                                    if isOn {
                                        // "Silly bee" guard
                                        if bannedRules.count == allBanItems.count - 1 {
                                            // Do nothing, but maybe we can show a warning?
                                            // The prompt says "don't allow the last checkbox to check, and warn user"
                                            // We will handle the warning inline below.
                                        } else {
                                            bannedRules.insert(ruleName)
                                        }
                                    } else {
                                        bannedRules.remove(ruleName)
                                    }
                                }
                            ))
                            .font(.system(.body))
                            .help(HoneycombRule(rawValue: ruleName)?.explanation() ?? "Forces a match with no active rules, skipping roulette.")

                            if bannedRules.count == allBanItems.count - 1 && !bannedRules.contains(ruleName) {
                                Text("You cannot blacklist every game, silly bee.")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            }
        }
    }
}
