import SwiftUI

// HoneycombFlipContainer and SwapLiftEffect live in shared/Honeycomb/Views/
// HoneycombFlipAnimation.swift now — shared with iOS's HoneycombTouchView.swift
// so the two platforms can't drift out of sync.

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
    private static let boardRowHorizontalPadding: CGFloat = 80
    private static let boardRowVerticalPadding: CGFloat = 20
    // Space below the hand columns/board down to the window's bottom edge — kept
    // separate from boardRowVerticalPadding (which still governs the top) since the
    // two edges don't need to match. Large enough to hold the bottom-row hand card's
    // 1.75x Nectar Exchange Lift/Flight balloon (SwapLiftEffect) plus its shadow blur —
    // that balloon overflows ~104pt below the card's own unscaled box (0.375 *
    // handCardSize.height) — since this padding is inside intrinsicContentSize, whose
    // scaled height is exactly what recomputeScale fits to the window, anything less
    // left the balloon rendering past the window's bottom edge and visibly clipped.
    private static let boardRowBottomPadding: CGFloat = 150
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
    // DragGesture only tracks the primary (left) button — pressing right/middle mouse
    // mid-drag doesn't cancel it, but it also doesn't call .onEnded (AppKit swallows the
    // left-button event stream), so draggedHandCard was left stuck non-nil forever: the
    // hand card stayed hidden (opacity 0) and its floating ghost froze in place. This
    // monitor is a safety net that resets drag state the instant another button goes down.
    @State private var dragCancelMonitor: Any? = nil
    @State private var animatingBoardIndices: Set<Int> = []

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

            GameWatermarkView()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // Placed behind the toolbar/board/hands (declared before them in this
            // ZStack, and ZStack draws later children on top), so it can never cover
            // any cards regardless of the vignette's own shape — same ordering every
            // other game uses.
            if coordinator.showFeltVignette { FeltVignetteView() }

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
                            label: coordinator.L(.toolbarStartMatch), systemImage: "play.fill",
                            isCompact: toolbarWidth < compactToolbarWidthThreshold
                        ) { viewModel.startNewGame() }

                        // Mirrors the post-game overlay's Rematch button, for whenever
                        // that overlay's been dismissed (its "x") to look at the
                        // finished board — otherwise the toolbar's only path back in
                        // was Start Match, silently losing the option to replay the
                        // same opponent instead of rolling a fresh one.
                        if viewModel.gameState == .gameOver && viewModel.canRematch {
                            GameToolbarButton(
                                label: coordinator.L(.rematch), systemImage: "arrow.counterclockwise",
                                isCompact: toolbarWidth < compactToolbarWidthThreshold
                            ) { viewModel.rematch() }
                        }
                    } else {
                        GameToolbarButton(
                            label: coordinator.L(.toolbarQuitMatch), systemImage: "flag.fill",
                            isCompact: toolbarWidth < compactToolbarWidthThreshold
                        ) { viewModel.quitMatch() }
                    }

                    GameToolbarButton(
                        label: coordinator.L(.options), systemImage: "gearshape",
                        isCompact: toolbarWidth < compactToolbarWidthThreshold
                    ) { showingOptions = true }

                    GameToolbarButton(
                        label: coordinator.L(.toolbarRules), systemImage: "checklist",
                        isCompact: toolbarWidth < compactToolbarWidthThreshold
                    ) { showingRules = true }

                    // Manage Decks is shown for .setup *and* .gameOver — the match is
                    // already over at that point, so there's no more Undo to offer and
                    // it becomes relevant again rather than staying hidden until the
                    // player explicitly quits back to .setup.
                    if viewModel.gameState == .playing || viewModel.gameState == .suddenDeath {
                        // Never shown on Ultra Hard — that difficulty is meant to stay
                        // fully self-directed, no optimal-move assistance.
                        if !coordinator.hideHintButton && viewModel.options.difficulty != .ultraHard {
                        GameToolbarButton(
                            label: coordinator.L(.hint), systemImage: "lightbulb",
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
                            label: coordinator.L(.undo), systemImage: "arrow.uturn.backward",
                            isCompact: toolbarWidth < compactToolbarWidthThreshold,
                            disabled: !viewModel.canUndo
                        ) { viewModel.undoLastAction() }
                        .keyboardShortcut("z", modifiers: .command)
                    } else if !coordinator.noStressMode {
                        // Manage Decks edits the player's active deck composition —
                        // meaningless under No Stress Mode, which always deals a
                        // fixed/random hand instead of that deck.
                        GameToolbarButton(
                            label: coordinator.L(.manageDecks), systemImage: "square.grid.2x2",
                            isCompact: toolbarWidth < compactToolbarWidthThreshold
                        ) { showingDecks = true }
                    }

                    Spacer()

                    if viewModel.gameState != .setup {
                        HStack {
                            StatusItemView(label: coordinator.L(.statusYouLabel), value: "\(viewModel.board.playerScore + viewModel.playerHand.count)")
                            StatusItemView(label: honeycombLocalizedDifficultyName(viewModel.options.difficulty, language: coordinator.language), value: "\(viewModel.board.opponentScore + viewModel.opponentHand.count)")
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
                        handSideLabel(honeycombLocalizedPlayerRankName(
                            cardsCollected: HoneycombProfileManager.shared.unlockedCardIds.count,
                            totalCards: HoneycombDatabase.shared.allCards.count,
                            language: coordinator.language))
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
                                                // Steal-eligible normally means the opponent originally played
                                                // this card AND the player actually captured it this round AND
                                                // it isn't already in your Card Bank. Under Steal Protection,
                                                // isStealEligible waives the capture requirement — see its doc
                                                // comment in HoneycombViewModel.
                                                let stealEligible = isStealingCard && viewModel.isStealEligible(card)
                                                let highlightIndices: Set<Int> = viewModel.pointHighlight?.cardId == card.id
                                                    ? viewModel.pointHighlight!.statIndices
                                                    : []
                                                HoneycombCardView(card: card, size: Self.boardCardSize, isFlipped: false, stealHighlight: stealEligible, highlightedStatIndices: highlightIndices, isCaptureAttacker: viewModel.captureAttackerIds.contains(card.id))
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
                                               let card = cell.card, viewModel.isStealEligible(card) {
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
                                        // zIndex bump for whichever card just did the capturing (see
                                        // HoneycombCardView's own isCaptureAttacker/ruleTriggerScale) —
                                        // not the card it captured, which doesn't enlarge at all
                                        // anymore. `.onChange` catches a Hive Swarm reveal (this same
                                        // cell was already mounted before its own capture resolves);
                                        // `.onAppear` catches the far more common case of a freshly
                                        // placed card that captures immediately, which mounts already
                                        // flagged as the attacker — too late for `.onChange` to see a
                                        // false -> true transition.
                                        .onChange(of: viewModel.captureAttackerIds.contains(cell.card?.id ?? "")) { _, isAttacker in
                                            if isAttacker {
                                                animatingBoardIndices.insert(index)
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                                    animatingBoardIndices.remove(index)
                                                }
                                            }
                                        }
                                        .onAppear {
                                            if viewModel.captureAttackerIds.contains(cell.card?.id ?? "") {
                                                animatingBoardIndices.insert(index)
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                                    animatingBoardIndices.remove(index)
                                                }
                                            }
                                        }
                                        .zIndex(animatingBoardIndices.contains(index) ? 100 : 0)
                                    }
                                }
                                .zIndex(animatingBoardIndices.contains(where: { $0 / 3 == row }) ? 100 : 0)
                            }
                        }
                    }

                    Spacer()

                    // Opponent Hand (Right) — same top offset as the player's hand.
                    let opponentDisplayHand = viewModel.gameState == .setup ? Self.placeholderHand : viewModel.opponentHand
                    VStack(spacing: 6) {
                        // Not "Dealer" — Honeycomb's opponent is a named AI difficulty
                        // (e.g. "Baby Bee"), not a card-game dealer role like Blackjack's.
                        handSideLabel(honeycombLocalizedDifficultyName(viewModel.options.difficulty, language: coordinator.language))
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
                Color.black.opacity(0.45)

                ZStack(alignment: .topTrailing) {
                    VStack {
                        if viewModel.matchOutcome == .loss {
                            // Exact match to Video Poker's loss banner (VideoPokerView.swift).
                            Text(coordinator.L(.notTodayPartner))
                                .font(.system(size: 36, weight: .black))
                                .foregroundColor(.yellow)
                        } else if viewModel.matchOutcome == .win {
                            // The win overlay reappears after a steal is confirmed (Steal
                            // Card is now gone, since hasStolenThisMatch is true) — a
                            // repeat "You Win!" would read as stale, so it confirms what
                            // just happened instead.
                            Text(viewModel.hasStolenThisMatch ? coordinator.L(.cardAddedToBank) : viewModel.matchResult)
                                .font(.system(size: 60, weight: .bold)).foregroundColor(.yellow)
                        } else if viewModel.matchOutcome == .tie {
                            // Same styling as "You Win!" — Sudden Death is now opt-in, so an
                            // unresolved tie is a final result like a win/loss, not a lesser
                            // outcome. No Steal Card here: every steal conditional below is
                            // already scoped to .win specifically, so it's excluded for free.
                            Text(viewModel.matchResult)
                                .font(.system(size: 60, weight: .bold)).foregroundColor(.yellow)
                        } else {
                            Text(viewModel.matchResult).font(.system(size: 60, weight: .bold)).foregroundColor(.white)
                        }

                        if let flavorText = viewModel.matchResultFlavorText {
                            Text(flavorText)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.top, 4)
                        }

                        if viewModel.matchOutcome == .win && !coordinator.noStressMode
                            && HoneycombProfileManager.shared.isCardBankFull {
                            VStack {
                                Text(coordinator.L(.cardBankFullLine1))
                                Text(coordinator.L(.cardBankFullLine2))
                            }
                            .foregroundColor(.white).padding()
                        } else if viewModel.matchOutcome == .win && !coordinator.noStressMode
                            && viewModel.hasObtainedAllOpponentCards {
                            Text(coordinator.L(.obtainedAllCardsFmt, honeycombLocalizedDifficultyName(viewModel.options.difficulty, language: coordinator.language)))
                                .foregroundColor(.white).padding()
                        } else if viewModel.matchOutcome == .win && !coordinator.noStressMode
                            && viewModel.hasStolenThisMatch {
                            Text(coordinator.L(.rematchToTakeAnother))
                                .foregroundColor(.white).padding()
                        } else if viewModel.matchOutcome == .win && !coordinator.noStressMode
                            && viewModel.stealProtectionActive && viewModel.hasStealableCard {
                            // Only claims a card is available when one actually is —
                            // stealProtectionActive alone doesn't guarantee that (it
                            // widens eligibility to any not-yet-unlocked board card,
                            // but if every card left on this board is already
                            // unlocked, there's still nothing to offer).
                            Text(coordinator.L(.stealProtectionLine))
                                .foregroundColor(.white).padding()
                        }

                        HStack {
                            Button(coordinator.L(.newGame)) {
                                viewModel.startNewGame()
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.capsule)

                            // Only available once a match has actually started this
                            // session — nothing to replay before that.
                            if viewModel.canRematch {
                                Button(coordinator.L(.rematch)) {
                                    viewModel.rematch()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)
                                .buttonBorderShape(.capsule)
                            }

                            // No Stress Mode always deals a fresh random overpowered
                            // deck — stealing a card in would let the player curate a
                            // deck in a mode whose whole point is not choosing one.
                            // Hidden once the card bank is full (nothing left to steal)
                            // or once this match's one steal has already been spent —
                            // Rematch is required to steal again.
                            if viewModel.matchOutcome == .win && !coordinator.noStressMode
                                && !HoneycombProfileManager.shared.isCardBankFull
                                && !viewModel.hasStolenThisMatch
                                && viewModel.hasStealableCard {
                                Button(coordinator.L(.stealCard)) {
                                    isStealingCard = true
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.yellow)
                                .foregroundColor(.black)
                                .buttonBorderShape(.capsule)
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
                .background(Color.black.opacity(0.75))
                .cornerRadius(16)
                .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.5), radius: 16)
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
                FlashBannerView(
                    message: bannerText,
                    onDismiss: dismissRuleBanner
                )
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(100)
            }

            // Kept permanently in the tree, gated by allowsHitTesting only — see
            // GameView.swift's matching comment for why conditional insert/remove here
            // left the hit-test region stuck active.
            Color.clear
                .contentShape(Rectangle())
                .allowsHitTesting(showingRuleBanner)
                .onTapGesture { dismissRuleBanner() }
                .zIndex(99)

            if showNoHintsBanner {
                FlashBannerView(message: coordinator.L(.noHintsAvailable))
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
            // Manually Dismiss Banners: stays up until the player taps it or a card
            // (see the board tap-catcher above) — no auto-dismiss timer in that mode.
            guard !coordinator.manuallyDismissBanners else {
                bannerTask = nil
                return
            }
            let task = DispatchWorkItem { [self] in dismissRuleBanner() }
            // All toasts are a uniform 2s now (flashRuleBannerIsLongDuration no longer
            // distinguishes anything display-wise — kept on the queue only because
            // removing it would mean touching every enqueueBanner call site for no
            // behavioral gain). The one exception: the very first loading banner of an
            // app session gets extra time to actually be read — see
            // BannerCatalog.consumeAppLaunchLoadingFlag().
            let duration = BannerCatalog.consumeAppLaunchLoadingFlag() ? 3.0 : 2.0
            DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: task)
            bannerTask = task
        }
        .alert(
            coordinator.L(.confirmStealTitle),
            isPresented: Binding(
                get: { viewModel.pendingSteal != nil },
                set: { if !$0 { viewModel.cancelPendingSteal() } }
            )
        ) {
            Button(coordinator.L(.cancel), role: .cancel) { viewModel.cancelPendingSteal() }
            Button(coordinator.L(.ok)) {
                viewModel.confirmPendingSteal()
                isStealingCard = false
                // Falls straight back to the win overlay (still gameOver/showPostGamePrompt,
                // nothing else hides it) rather than a separate Rematch/New Game prompt —
                // its title switches to the steal confirmation since Steal Card is now gone.
            }
        }
        .confirmationDialog(coordinator.L(.newMatchConfirmTitle), isPresented: $isShowingNewGameConfirm) {
            Button(coordinator.L(.cancel), role: .cancel) { }
            Button(coordinator.L(.newMatch), role: .destructive) { viewModel.startNewGame() }
        }
        .confirmationDialog(coordinator.L(.rematchConfirmTitle), isPresented: $isShowingRematchConfirm) {
            Button(coordinator.L(.cancel), role: .cancel) { }
            Button(coordinator.L(.rematch), role: .destructive) { viewModel.rematch() }
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
        .onAppear {
            applyInitialWindowSize()
            viewModel.checkLoadingBanner()
            // Resync flip state with reality — AppRouterView's `switch` on gameMode
            // (each case carrying its own .id()) fully unmounts this view when the
            // player switches to a different game, same as iOS's IOSRouterView, despite
            // AppCoordinator keeping the underlying viewModel (and its mid-match data)
            // alive the whole time. Returning here creates a brand-new HoneycombView
            // with isPlayerCardRevealed/isOpponentCardRevealed reset to their all-false
            // defaults, and nothing else restores them — .onChange(of: viewModel.gameState)
            // below only fires on a genuine state *transition*, which doesn't happen
            // when re-mounting mid-match. Left alone, every hand card stays stuck
            // showing its face-down front(), including the player's own — unplayable.
            // All-true (not matching each opponent card's real visibility) mirrors the
            // .setup-transition handler below: opponentHandCardView already computes
            // real face-up/down per card internally, so the outer flag only chooses
            // between that and the generic animated-placeholder — no deal-flip
            // animation should replay here, so every slot skips straight to "settled".
            if viewModel.gameState == .playing || viewModel.gameState == .suddenDeath {
                isPlayerCardRevealed = Array(repeating: true, count: 5)
                isOpponentCardRevealed = Array(repeating: true, count: 5)
                handIdentityToken += 1
            }
            dragCancelMonitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .otherMouseDown]) { event in
                if draggedHandCard != nil {
                    draggedHandCard = nil
                    dragOffset = .zero
                }
                return event
            }
        }
        .onDisappear {
            if let monitor = dragCancelMonitor {
                NSEvent.removeMonitor(monitor)
                dragCancelMonitor = nil
            }
        }
        .background(WindowAccessor(callback: { window in
            self.hostingWindow = window
            self.zoomController = WindowZoomController(window: window)
            coordinator.activeWindow = window
            applyInitialWindowSize()
        }, onResize: recomputeScale))
        // See GameView.swift: the system focus ring recomputes an expensive blurred
        // bitmap on every board redraw, which happens on every state mutation.
        .focusEffectDisabled()
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

        viewModel.zoomScale = WindowFit.scale(
            contentSize: contentSize,
            intrinsicSize: intrinsicContentSize,
            heightInset: Self.toolbarHeight)
    }

    // Applies the window's opening size and refits the scale — called at app launch and
    // every time this game becomes active again.
    private func applyInitialWindowSize() {
        guard let window = hostingWindow else { return }
        window.applyInitialSize(minSize: Self.minWindowSize, defaultOpeningSize: nil)
        recomputeScale()
    }

    private func dismissRuleBanner() {
        bannerTask?.cancel()
        bannerTask = nil
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
            if viewModel.activeRules.isEmpty { return [coordinator.L(.ruleLineNormal)] }
            return viewModel.activeRules.map { rule in
                // Ascension/Descension only affects the 2 suits rolled for this match
                // (setupRules) — call that out here rather than the plain rule name,
                // since which suits are favored/penalized isn't otherwise visible
                // until the player notices it in play.
                if rule == .ascension || rule == .descension, !viewModel.ascensionDescensionSuits.isEmpty {
                    let suitNames = viewModel.ascensionDescensionSuits.sorted()
                        .map { HoneycombCardData.localizedSuitName($0, language: coordinator.language) }
                    return coordinator.L(.ruleLineSuitFmt, honeycombLocalizedRuleName(rule.rawValue, language: coordinator.language), suitNames.joined(separator: ", "))
                }
                return honeycombLocalizedRuleName(rule.rawValue, language: coordinator.language)
            }
        }
        if viewModel.options.forceNormalMode {
            return [coordinator.L(.ruleLineNormal)]
        }
        if !viewModel.options.selectedRules.isEmpty {
            return HoneycombRule.allCases
                .filter { viewModel.options.selectedRules.contains($0) }
                .map { honeycombLocalizedRuleName($0.rawValue, language: coordinator.language) }
        }
        return [coordinator.L(.ruleLineRoulette)]
    }

    // Active-rules banner shown above the board. Every Text here is .fixedSize() —
    // same reasoning as StatusItemView elsewhere in the app — so it always claims its
    // true natural width instead of being squeezed/truncated when the row is tight.
    @ViewBuilder
    private var rulesBanner: some View {
        // Hidden once a steal is staged (pendingSteal != nil) — the confirmation
        // alert ("Are you sure you want to steal this card?") takes over from here,
        // and leaving this instruction toast up underneath it stacked two banners
        // on screen at once.
        if isStealingCard && viewModel.pendingSteal == nil {
            VStack(spacing: 16) {
                Text(coordinator.L(.stealInstruction))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Button(coordinator.L(.cancel)) {
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
        } else if isStealingCard {
            // pendingSteal != nil here (see the guard above) — the confirmation
            // alert is up, so render nothing rather than letting the unrelated
            // Rules banner flash in underneath it for the moment before OK/Cancel.
            Color.clear
                .frame(height: Self.rulesBannerHeight, alignment: .bottom)
        } else {
            let isDense = rulesBannerLines.count > 2
            let titleSize: CGFloat = isDense ? 20 : 28
            let textSize: CGFloat = isDense ? 16 : 22
            let lineSpacing: CGFloat = isDense ? 2 : 6

            VStack(spacing: lineSpacing) {
                Text(coordinator.L(.rulesBannerTitle))
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
            let row0 = Array(hand.prefix(2).enumerated())
            HStack(spacing: Self.handGridSpacing) {
                ForEach(row0, id: \.offset) { i, card in
                    content(i, card)
                        .zIndex(viewModel.swapHighlightCardIds.contains(card.id) ? 100 : 0)
                }
            }
            .zIndex(row0.contains(where: { viewModel.swapHighlightCardIds.contains($0.element.id) }) ? 100 : 0)

            if hand.count > 2 {
                let row1 = Array(hand.dropFirst(2).prefix(2).enumerated())
                HStack(spacing: Self.handGridSpacing) {
                    ForEach(row1, id: \.offset) { offset, card in
                        content(offset + 2, card)
                            .zIndex(viewModel.swapHighlightCardIds.contains(card.id) ? 100 : 0)
                    }
                }
                .zIndex(row1.contains(where: { viewModel.swapHighlightCardIds.contains($0.element.id) }) ? 100 : 0)
            }
            if hand.count > 4 {
                let row2 = Array(hand.dropFirst(4).enumerated())
                HStack(spacing: Self.handGridSpacing) {
                    ForEach(row2, id: \.offset) { offset, card in
                        content(offset + 4, card)
                            .zIndex(viewModel.swapHighlightCardIds.contains(card.id) ? 100 : 0)
                    }
                }
                .zIndex(row2.contains(where: { viewModel.swapHighlightCardIds.contains($0.element.id) }) ? 100 : 0)
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
                    .stroke(coordinator.customCardColors.hintHighlightColor, lineWidth: isMandated ? 14 : 0)
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
        let isPostWinReveal = viewModel.gameState == .gameOver && viewModel.showPostGamePrompt && viewModel.matchOutcome == .win
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
                    .stroke(coordinator.customCardColors.hintHighlightColor, lineWidth: isMandated ? 14 : 0)
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

    // noStressMode stays locally buffered (unlike Sound/Honey Mode/Manually Dismiss
    // Banners/Hide Hint Button, which OptionsSheetShell now live-binds+reverts) —
    // see OptionsSheetShell's comment on originalIsSoundEnabled for why.
    @State private var noStressMode: Bool
    @State private var hideBee: Bool
    let availableWidth: CGFloat
    let availableHeight: CGFloat

    init(viewModel: HoneycombViewModel, isPresented: Binding<Bool>, isShowingStats: Binding<Bool>, coordinator: AppCoordinator, availableWidth: CGFloat = 2000, availableHeight: CGFloat = 900) {
        self.viewModel = viewModel
        self._isPresented = isPresented
        self._isShowingStats = isShowingStats
        self.coordinator = coordinator
        self.availableWidth = availableWidth
        self.availableHeight = availableHeight
        _noStressMode = State(initialValue: coordinator.noStressMode)
        _hideBee = State(initialValue: coordinator.hideBee)
    }

    var body: some View {
        OptionsSheetShell(
            isPresented: $isPresented,
            coordinator: coordinator,
            availableWidth: availableWidth,
            availableHeight: availableHeight,
            onViewStats: { isShowingStats = true },
            onOK: {
                let wasNoStressMode = coordinator.noStressMode
                // No Stress Mode is app-wide now (AppCoordinator) — pushing the edit
                // there is what makes it actually apply everywhere. Sound/Honey Mode/
                // Manually Dismiss Banners/Hide Hint Button/hideBee are already live via
                // OptionsSheetShell's direct $coordinator.X bindings below.
                coordinator.noStressMode = noStressMode
                coordinator.hideBee = hideBee
                // No Stress Mode's deck composition is only decided at match start, so
                // toggling it on mid-match has no visible effect until the next deal —
                // silently deal fresh instead of leaving a stale, unapplied setting.
                if noStressMode && !wasNoStressMode && (viewModel.gameState == .playing || viewModel.gameState == .suddenDeath) {
                    viewModel.startNewGame()
                }
            }
        ) {
            Toggle(coordinator.L(.soundEffects), isOn: $coordinator.isSoundEnabled)
                .font(.system(.body))

            Toggle(coordinator.L(.noStressMode), isOn: $noStressMode)
                .help(coordinator.L(.noStressModeTooltip))
                .font(.system(.body))

            Toggle(coordinator.L(.honeyMode), isOn: $coordinator.honeyMode)
                .help(coordinator.L(.honeyModeTooltip))
                .font(.system(.body))

            Toggle(coordinator.L(.hideHintButton), isOn: $coordinator.hideHintButton)
                .font(.system(.body))

            Toggle(coordinator.L(.manuallyDismissBanners), isOn: $coordinator.manuallyDismissBanners)
                .font(.system(.body))

            Toggle(coordinator.L(.hideBee), isOn: $hideBee)
                .font(.system(.body))

            // Live-updating (bound directly to coordinator, not local @State + onOK) so
            // the bee visibly resizes on the board behind this sheet while dragging —
            // matches how the watermark's own scale is stored/persisted (didSet ->
            // UserDefaults), unlike every other control on this sheet which stages its
            // edit in @State until OK. Only shown when the bee isn't hidden.
            if !hideBee {
                Slider(value: $coordinator.honeycombWatermarkScale, in: 0.5...4.0) {
                    Text(coordinator.L(.beeSize))
                }
                .font(.system(.body))
            }
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
            title: coordinator.L(.toolbarRules),
            showThemes: false,
            showLanguage: false,
            watermarkMaxSize: 412.5,
            onOK: {
                var updatedOpts = viewModel.options
                updatedOpts.difficulty = difficulty
                updatedOpts.forceNormalMode = forceNormalMode
                updatedOpts.selectedRules = selectedRules
                updatedOpts.bannedRules = bannedRules
                viewModel.options = updatedOpts
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Picker(coordinator.L(.opponentPickerLabel), selection: $difficulty) {
                        ForEach(HoneycombDifficulty.allCases, id: \.self) { diff in
                            Text(honeycombLocalizedDifficultyName(diff, language: coordinator.language)).tag(diff)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(minWidth: 120)

                    Spacer()

                    Button(coordinator.L(.helpHoneycomb)) { openWindow(id: "honeycomb-help") }
                        .buttonStyle(.bordered)
                }
                .padding(.top, 16)

                Divider()

                HStack {
                    Text(coordinator.L(.rulesColumnTitle))
                        .font(.title2).bold()
                    Spacer()
                    Text(coordinator.L(.rulesSelectedCountFmt, selectedRules.count))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(coordinator.L(.matchRulesHint))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if bannedRules.count == HoneycombRuleRowID.banListOrder.count - 1 {
                    Text(coordinator.L(.sillyBeeWarning))
                        .font(.caption)
                        .foregroundColor(.red)
                }

                VStack(spacing: 0) {
                    ForEach(HoneycombRuleRowID.banListOrder, id: \.self) { id in
                        ruleRow(id)
                        if id != HoneycombRuleRowID.banListOrder.last {
                            Divider()
                        }
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.15), lineWidth: 1))
            }
            // Watermark now comes from OptionsSheetShell itself (watermarkMaxSize: 550
            // passed above) rather than a second one layered on just this VStack — this
            // used to duplicate the shell's own watermark once that was added.
        }
    }

    private func rowState(_ id: HoneycombRuleRowID) -> HoneycombRuleState {
        HoneycombRuleSelection.state(of: id, selectedRules: selectedRules, forceNormalMode: forceNormalMode, bannedRules: bannedRules)
    }

    private func setRowState(_ state: HoneycombRuleState, for id: HoneycombRuleRowID) {
        HoneycombRuleSelection.setState(state, for: id, selectedRules: &selectedRules, forceNormalMode: &forceNormalMode, bannedRules: &bannedRules)
    }

    private func rowTitle(_ id: HoneycombRuleRowID) -> String {
        switch id {
        case .normalMode: return coordinator.L(.toggleNormalModeMac)
        case .rule(let rule): return localizedRuleName(rule.rawValue)
        }
    }

    private func rowExplanation(_ id: HoneycombRuleRowID) -> String {
        switch id {
        case .normalMode: return coordinator.L(.normalModeBanListTooltip)
        case .rule(let rule): return localizedRuleExplanation(rule)
        }
    }

    @ViewBuilder
    private func ruleRow(_ id: HoneycombRuleRowID) -> some View {
        let state = rowState(id)
        HStack(spacing: 12) {
            Text(rowTitle(id))
                .font(.system(size: 13, weight: .semibold))
                .strikethrough(state == .banned)
                .foregroundColor(state == .banned ? .secondary : .primary)
            Spacer(minLength: 8)
            HStack(spacing: 0) {
                stateSegment(coordinator.L(.ruleStateBan), isSelected: state == .banned, fill: .red, textColor: .white, corner: .leading) { setRowState(.banned, for: id) }
                Divider().frame(height: 14)
                stateSegment("–", isSelected: state == .auto, fill: Color(nsColor: .controlBackgroundColor), textColor: .primary, corner: .none) { setRowState(.auto, for: id) }
                    .accessibilityLabel(coordinator.L(.ruleStateAuto))
                Divider().frame(height: 14)
                    .opacity(id.isPickable ? 1 : 0)
                // Inversion (not pickable) still renders this segment — invisible and
                // inert — rather than omitting it, so its row's track is the same width
                // as every other row's instead of shrinking and drifting off the
                // shared left-aligned Ban position (a fixed guess-width here would
                // either clip a longer translation or leave a dead gray tail after
                // Play on every ordinary 3-segment row).
                stateSegment(coordinator.L(.ruleStatePick), isSelected: state == .picked, fill: .accentColor, textColor: .white, corner: .trailing) { setRowState(.picked, for: id) }
                    .opacity(id.isPickable ? 1 : 0)
                    .disabled(!id.isPickable)
            }
            .padding(2)
            .background(Color.primary.opacity(0.16))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        // No row-wide state tint here — it used to add a lighter halo spanning the
        // full row width (including the padding past the segmented control), which
        // visually looked like color bleeding out past the Play/Ban pill itself. The
        // segmented control's own fill already fully communicates the row's state.
        .help(rowExplanation(id))
    }

    private enum SegmentCorner { case leading, trailing, none }

    private func stateSegment(_ label: String, isSelected: Bool, fill: Color, textColor: Color, corner: SegmentCorner, action: @escaping () -> Void) -> some View {
        // Rounding each end segment's own fill (rather than relying only on the
        // group's outer .clipShape) — a plain Button's background can otherwise
        // render in its own compositing layer that ignores an ancestor's clip,
        // leaving the trailing (Play) corner looking squared-off instead of capped.
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: corner == .leading ? 11 : 0,
            bottomLeadingRadius: corner == .leading ? 11 : 0,
            bottomTrailingRadius: corner == .trailing ? 11 : 0,
            topTrailingRadius: corner == .trailing ? 11 : 0
        )
        return Button(action: action) {
            Text(label)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundColor(isSelected ? textColor : .primary)
                .frame(minWidth: 34)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(isSelected ? fill : Color.clear)
                .clipShape(shape)
                // Without this, the button's tap target is just the Text's own tight
                // glyph bounds, not the padded pill around it — background() draws
                // behind the padding but doesn't extend hit-testing into it, so most
                // clicks on the pill (anywhere but right on the letters) silently miss.
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func localizedRuleName(_ ruleName: String) -> String {
        honeycombLocalizedRuleName(ruleName, language: coordinator.language)
    }

    private func localizedRuleExplanation(_ rule: HoneycombRule) -> String {
        honeycombLocalizedRuleExplanation(rule, language: coordinator.language)
    }
}
