import SwiftUI
import UIKit

// HoneycombFlipContainer and SwapLiftEffect live in shared/Honeycomb/Views/
// HoneycombFlipAnimation.swift now — shared with mac's HoneycombView.swift so
// the two platforms can't drift out of sync.

/// HoneycombCardView; layout is a fixed intrinsic design scaled to fit the screen (the
/// same fit-to-window approach the mac view uses, driven by GeometryReader instead of
/// NSWindow). Portrait stacks opponent hand / board / player hand vertically; landscape
/// mirrors the mac's hands-beside-board arrangement.
struct HoneycombTouchView: View {
    @Bindable var viewModel: HoneycombViewModel
    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator

    // MARK: Intrinsic layout constants (pre-scale units)

    private static let cardAspect: CGFloat = CardDimensions.aspectRatio
    private static let boardCardSize = CGSize(width: 150, height: 150 * cardAspect)
    private static let playerCardSize = CGSize(width: 116, height: 116 * cardAspect)
    private static let boardSpacing: CGFloat = 10
    private static let handSpacing: CGFloat = 6
    private static let dealFlipStagger: Double = HoneycombFlipTiming.duration

    // Face-down placeholders shown pre-match, same trick as the mac view: fixed ids so
    // ForEach identity stays stable across re-renders. Player and opponent get their
    // own id namespace (was one shared array before) — every hand card here also
    // carries .matchedGeometryEffect(id: card.id, in: animationSpace), and reusing the
    // same ids for both rows put two views in that Namespace under the same (id,
    // namespace) pair simultaneously, both marked isSource: true. SwiftUI logs that as
    // "results are undefined" and it manifested as the placeholder cards rendering at
    // an inconsistent, wrong size compared to the real dealt hand.
    private static func placeholderHand(prefix: String) -> [HoneycombCard] {
        (0..<5).map { i in
            HoneycombCard(
                data: HoneycombCardData(id: -1, name: "", stars: 1, stats: [1, 1, 1, 1], suit: "S"),
                owner: .player,
                id: "placeholder-\(prefix)-\(i)"
            )
        }
    }
    private static let playerPlaceholderHand = placeholderHand(prefix: "player")
    private static let opponentPlaceholderHand = placeholderHand(prefix: "opponent")

    // MARK: Interaction state

    // Custom drag (Klondike pattern — the drag feel the user picked over system onDrag).
    // All coordinates live in the pre-scale "board space" declared inside scaleEffect,
    // so gesture locations and tracked frames stay consistent in intrinsic units.
    private static let dragSpace = "honeycombDragSpace"
    @State private var cellFrames: [Int: CGRect] = [:]
    @State private var dragHandCard: HoneycombCard? = nil
    @State private var dragLocation: CGPoint = .zero
    @State private var dragOffset: CGSize = .zero

    @State private var selectedHandCardId: String? = nil

    // Deal-flip and Nectar Exchange animation state
    @State private var isPlayerCardRevealed = [Bool](repeating: false, count: 5)
    @State private var isOpponentCardRevealed = [Bool](repeating: false, count: 5)
    @State private var handIdentityToken = 0
    @Namespace private var animationSpace

    // "Steal Card" mode: double-tap an eligible captured opponent card on the board
    // to steal it straight into the card bank.
    @State private var isStealingCard = false
    @State private var isMenuOpen = false
    @State private var showingOptions = false
    @State private var showingThemes = false
    @State private var showingStats = false
    @State private var showingDecks = false
    @State private var isShowingQuitMatchConfirm = false
    @State private var showNoHintsBanner = false
    @State private var noHintsBannerTask: DispatchWorkItem? = nil
    @State private var showingRuleBanner = false
    @State private var ruleBannerText = ""
    @State private var ruleBannerTask: DispatchWorkItem? = nil
    @State private var isShowingRulesTooltip = false

    private var isMidMatch: Bool {
        viewModel.gameState == .playing || viewModel.gameState == .suddenDeath
    }

    // MARK: Haptics — light tick on selection, solid thump on placement.

    private let selectionHaptic = UIImpactFeedbackGenerator(style: .light)
    private let placementHaptic = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        // Landscape-vs-portrait is needed before topBar renders (to decide whether
        // rulesCapsule joins it or stays its own row below), earlier than the inner
        // GeometryReader below — which exists only to scale the board — computes its
        // own copy of the same thing.
        GeometryReader { outerGeo in
        let isLandscape = outerGeo.size.width > outerGeo.size.height
        ZStack {
            VStack(spacing: 0) {
                topBar(isLandscape: isLandscape)
                    .padding(.horizontal, 8)
                    .frame(height: 44)
                    // The pre-game "Start" button (borderedProminent + icon label) is
                    // taller than the other topBar controls, so left unclipped it
                    // overflows this fixed frame and bleeds into the board below —
                    // clip so every topBar state stays confined to its 44pt band.
                    .clipped()

                // Fixed row, not scaled with the board — rules text stays legible
                // regardless of screen size. Sits directly below topBar in normal
                // flow (no overlap with the menu bar, unlike an earlier version that
                // floated it as an overlay reaching up into topBar's icons). Score
                // renders separately, in scoreCapsule below the board, so it can no
                // longer drag this row's height up and risk that same overlap.
                // Landscape instead shows a compact version inside topBar itself (see
                // rulesCapsuleCompact) — landscape's shorter height has the least room
                // to spare, so freeing up this whole row matters more there than it
                // does in portrait.
                if !isLandscape {
                    rulesCapsule
                        .padding(.top, 6)
                        .padding(.bottom, 8)
                }

                GeometryReader { geo in
                    let isLandscape = geo.size.width > geo.size.height
                    let landscapeHandSize = isLandscape ? computeLandscapeHandCardSize(availableSize: geo.size) : Self.boardCardSize
                    let intrinsic = intrinsicSize(landscape: isLandscape, landscapeHandCardSize: landscapeHandSize)
                    let scale = min(2.0, max(0.2, min(geo.size.width / intrinsic.width,
                                                      geo.size.height / intrinsic.height)))

                    // dragGhost is rendered via .overlay(), not as a ZStack sibling —
                    // its .position() modifier's absolute placement, computed from live
                    // touch coordinates, was found to transiently perturb the ZStack's
                    // own size negotiation for the render that introduces the ghost
                    // (confirmed via a video showing the whole board's scaled content
                    // jump by a fixed vertical offset for the exact duration a drag was
                    // active, snapping back the instant the finger lifted — isolated to
                    // dragHandCard becoming non-nil, since a same-frame tap-select with
                    // no drag never reproduced it). .overlay()'s content is documented
                    // to never affect the base view's reported size, unlike a plain
                    // ZStack sibling, which removes that risk entirely.
                    gameContent(landscape: isLandscape, landscapeHandCardSize: landscapeHandSize)
                        // No explicit alignment — matches the original ZStack's default
                        // (.center) exactly. An earlier version of this fix added
                        // alignment: .topLeading here, which changed how any mismatch
                        // between gameContent's actual rendered size and intrinsicSize()'s
                        // formula-based estimate gets distributed (all to bottom/right
                        // instead of split evenly) — that's what pushed the setup screen's
                        // placeholder hand up into the topBar after quitting a match.
                        .frame(width: intrinsic.width, height: intrinsic.height)
                        .overlay(dragGhost(landscape: isLandscape, landscapeHandCardSize: landscapeHandSize))
                    // Anchors dragSpace — every cellFrames GeometryReader and DragGesture
                    // .named(Self.dragSpace) reference (see dropCellIndex() below) depends
                    // on this exact container. Moving this modifier elsewhere, or applying
                    // it after .scaleEffect, breaks drop hit-testing silently.
                    .coordinateSpace(name: Self.dragSpace)
                    .scaleEffect(scale)
                    .frame(width: geo.size.width, height: geo.size.height)
                    // Neither GeometryReader nor .frame() clip overflowing content by
                    // default — if the pre-game placeholder hand's actual rendered size
                    // doesn't perfectly match intrinsicSize's assumption, the scaled
                    // content can bleed outside this box in any direction, including
                    // upward into the topBar above (same root cause as the "Start"
                    // button overflow fixed earlier). Clip so the board never visually
                    // escapes its allocated space regardless of scale-math precision.
                    //
                    // Suspended during a Nectar Exchange swap — intrinsicSize's formulas
                    // budget essentially no slack (1-4%) for SwapLiftEffect's 1.5x scale,
                    // so a lifted hand card sitting near the top or bottom edge of this
                    // box (the opponent/player rows are the outermost content, right
                    // against this box's own top/bottom) got its enlarged portion sliced
                    // off exactly at those edges — visually right at the board's own top/
                    // bottom border, since the board sits flush between the two rows.
                    // Swaps never happen outside an active match, so there's no risk of
                    // this reintroducing the placeholder-hand overflow the clip guards
                    // against.
                    .modifier(ConditionalClip(isClipped: viewModel.swapAnimationPhase == .idle))
                }

                // Fixed row, like rulesCapsule — living inside gameContent meant this
                // text rode along with the board's .scaleEffect(scale) above, which is
                // usually well under 1 on a phone, so a font size matching rulesCapsule
                // numerically still rendered visibly smaller on screen. Sitting here
                // instead (right after GeometryReader, so still directly below the
                // player's cards) renders at true point size like rulesCapsule does.
                scoreCapsule
                    .padding(.bottom, 4)
            }

            // Matches mac's HoneycombView: two independent FlashBannerView render sites
            // (not a combined container) — mutually exclusive in practice, and each one
            // centers itself via FlashBannerView's own symmetric Spacers.
            if showingRuleBanner {
                FlashBannerView(message: ruleBannerText, onDismiss: dismissRuleBanner)
                    .zIndex(100)
            }
            if showNoHintsBanner {
                FlashBannerView(message: coordinator.L(.noHintsBanner), onDismiss: dismissNoHintsBanner)
                    .zIndex(100)
            }

            // Board-wide tap-catcher: while a banner is up, the game is "paused" — any
            // board tap (not just the banner itself) dismisses it instead of forwarding
            // the tap to the card underneath. Kept permanently in the tree, gated by
            // allowsHitTesting only — conditionally inserting/removing an interactive
            // view here left its hit-test region stuck active after the animated
            // removal, blocking every card tap until a forced relayout (e.g. opening/
            // closing Options) cleared it. Gated purely on showingRuleBanner, not on the
            // "Manually Dismiss Banners" option's current value — a banner shown while
            // the option was on must still be dismissable even if the option gets
            // turned off before it closes on its own.
            Color.clear
                .contentShape(Rectangle())
                .allowsHitTesting(showingRuleBanner)
                .onTapGesture { dismissRuleBanner() }

            // Hidden once a steal is staged (pendingSteal != nil) — the confirmation
            // alert ("Are you sure you want to steal this card?") takes over from here,
            // and leaving this instruction toast up underneath it stacked two banners
            // on screen at once. Matches mac's rulesBanner (HoneycombView.swift).
            if isStealingCard && viewModel.pendingSteal == nil {
                stealInstructionBar
            }

            if viewModel.showPostGamePrompt && !isStealingCard && !showingRuleBanner {
                postGameOverlay
            }
        }
        // Matches mac's Cmd+N confirmation (HoneycombView.swift) — mac's own toolbar
        // "Quit Match" button skips this and only its keyboard shortcut confirms, but
        // iOS has no keyboard-shortcut escape hatch, so the toolbar button here is the
        // only path and should confirm before discarding an in-progress match.
        .alert(coordinator.L(.newMatchConfirmTitle), isPresented: $isShowingQuitMatchConfirm) {
            Button(coordinator.L(.cancel), role: .cancel) {}
            Button(coordinator.L(.newMatch), role: .destructive) {
                viewModel.gameState = .setup
            }
        }
        .sheet(isPresented: $showingDecks) { HoneycombDecksSheet(viewModel: viewModel) }
        .environment(\.activeCardBackTheme, coordinator.cardBackTheme)
        .environment(\.activeCustomCardColors, coordinator.customCardColors)
        .sheet(isPresented: $isMenuOpen) { GameSelectionFullScreenView(coordinator: coordinator) }
        .sheet(isPresented: $showingStats) { HoneycombStatsSheet(stats: viewModel.stats) }
        .sheet(isPresented: $showingThemes) { ThemesFullScreenView(coordinator: coordinator) }
        .sheet(isPresented: $showingOptions) {
            OptionsFullScreenView(
                coordinator: coordinator,
                onShowStats: { showingStats = true },
                hideHintBinding: Bindable(coordinator).hideHintButton,
                onNoStressModeChange: { viewModel.startNewGame() },
                isGlobalSectionDisabled: isMidMatch,
                globalSectionUnlockNote: coordinator.L(.settingsUnlockNote)
            ) {
                HoneycombSettingsSection(viewModel: viewModel, isMidMatch: isMidMatch, coordinator: coordinator)
            }
        }
        // Headless-testing hook: `simctl launch ... -honeycombAutostart 1` starts a match
        // immediately, so match-state rendering can be screenshotted without tap input.
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-honeycombAutostart"),
               viewModel.gameState == .setup {
                viewModel.startNewGame()
            }
            viewModel.checkLoadingBanner()
            // Resync flip state with reality — IOSRouterView's `switch` on gameMode
            // unmounts this view entirely when the player switches to a different game
            // (unlike mac's AppCoordinator, which keeps every game's view alive at
            // once), so returning to Honeycomb creates a brand-new HoneycombTouchView
            // with isPlayerCardRevealed/isOpponentCardRevealed reset to their all-false
            // defaults. viewModel.honeycombViewModel itself isn't reset (same instance,
            // still mid-match), so the .onChange(of: viewModel.gameState) below never
            // fires — nothing else was restoring these, leaving every card stuck
            // showing its face-down back with no flip in sight and no way to play.
            // Bumping handIdentityToken makes the freshly-created HoneycombFlipContainers
            // pick these values up as their *initial* state, not something to animate.
            if viewModel.gameState == .playing || viewModel.gameState == .suddenDeath {
                isPlayerCardRevealed = [Bool](repeating: true, count: viewModel.playerHand.count)
                isOpponentCardRevealed = viewModel.opponentHand.map { viewModel.isOpponentCardVisible(cardId: $0.id) }
                handIdentityToken += 1
            }
        }
        .onChange(of: viewModel.gameState) { oldValue, newValue in
            if newValue == .setup {
                isPlayerCardRevealed = [Bool](repeating: false, count: 5)
                isOpponentCardRevealed = [Bool](repeating: false, count: 5)
            } else if newValue == .playing && (oldValue == .setup || oldValue == .gameOver) {
                // Both hands start fully unrevealed here (not pre-seeded from the
                // underlying game-rule visibility) so every card genuinely animates
                // in via triggerDealFlip() below — pre-seeding a card's reveal flag
                // to its final value before handIdentityToken creates the fresh
                // HoneycombFlipContainer made that container start already "revealed"
                // (see HoneycombFlipContainer's `_displayedRevealed = State(initialValue:
                // isRevealed)`), skipping the flip animation entirely. Excludes
                // .suddenDeath -> .playing: that path can rebuild hands larger than 5
                // cards, which these fixed-size-5 arrays aren't sized for.
                isPlayerCardRevealed = [Bool](repeating: false, count: 5)
                isOpponentCardRevealed = [Bool](repeating: false, count: 5)
                handIdentityToken += 1
                triggerDealFlip()
            } else if newValue == .playing && oldValue == .suddenDeath {
                // triggerSuddenDeath() rebuilds both hands from every card each side
                // currently owns (across the whole board plus any leftover hand cards) —
                // commonly more than 5, which the fixed-size-5 arrays above aren't sized
                // for; indexing past 5 here would crash. These are already-known cards
                // moving back into hand, not new mystery cards, so size the arrays to the
                // actual new hand counts and mark every slot already revealed. Bumping
                // handIdentityToken creates fresh HoneycombFlipContainers that pick up
                // `true` as their initial displayedRevealed value (no flip animation) —
                // reusing the existing containers instead would hit their onChange-
                // triggered flip path and animate a reveal that shouldn't happen.
                isPlayerCardRevealed = [Bool](repeating: true, count: viewModel.playerHand.count)
                isOpponentCardRevealed = [Bool](repeating: true, count: viewModel.opponentHand.count)
                handIdentityToken += 1
            }
        }
        .onChange(of: viewModel.flashRuleBannerTrigger) { _, _ in
            guard let text = viewModel.flashRuleBanner else { return }
            flashRuleBanner(text)
        }
        .alert(coordinator.L(.confirmStealTitle), isPresented: .init(
            get: { viewModel.pendingSteal != nil },
            set: { if !$0 { viewModel.cancelPendingSteal() } }
        )) {
            Button(coordinator.L(.cancel), role: .cancel) { viewModel.cancelPendingSteal() }
            Button(coordinator.L(.ok)) {
                viewModel.confirmPendingSteal()
                isStealingCard = false
                // Falls straight back to the win overlay (still gameOver/
                // showPostGamePrompt, nothing else hides it) rather than a separate
                // Rematch/New Game prompt — its title switches to the steal
                // confirmation since Take a Card is now gone.
            }
        }
        .background(IOSBackgroundLayer())
        }
    }

    // MARK: Top bar

    private func topBar(isLandscape: Bool) -> some View {
        // Tightened from spacing: 12 — up to seven 44pt icon buttons (menu/options/
        // palette/manage decks/debug/undo/hint) plus the Quit/Start button no longer
        // fit an iPhone's width at the old spacing once undo/hint moved up here from
        // the board; the bar's own ideal width exceeding the screen made it the
        // VStack's widest child, silently pulling every other (exactly screen-width)
        // row a few points off-center along with it.
        HStack(spacing: 6) {
            menuBarButtons(isMenuOpen: $isMenuOpen, showingOptions: $showingOptions, showingThemes: $showingThemes, coordinator: coordinator)

            // Hidden (not just disabled) mid-match — meaningless once a match is under
            // way, matching mac's HoneycombView (Manage Decks sits in the else-if branch
            // of the .playing/.suddenDeath check, not merely grayed out).
            if !isMidMatch {
                topBarIconButton(systemImage: "rectangle.stack", accessibilityLabel: coordinator.L(.manageDecks)) {
                    showingDecks = true
                }
            }

            Spacer()

            // Moved up from flanking the Rules banner into the menu bar, grouped with
            // Quit on the trailing side rather than the leading icon cluster. Same
            // availability rules as before (hint additionally hides on Ultra Hard/
            // off-turn/when disabled in Options; undo just dims when there's nothing
            // to undo).
            if isMidMatch {
                topBarIconButton(systemImage: "arrow.uturn.backward", accessibilityLabel: coordinator.L(.undo)) {
                    viewModel.undoLastAction()
                }
                .disabled(!viewModel.canUndo)
                .opacity(viewModel.canUndo ? 1 : 0.35)

                if !coordinator.hideHintButton, viewModel.options.difficulty != .ultraHard, viewModel.isPlayerTurn {
                    topBarIconButton(systemImage: "lightbulb", accessibilityLabel: coordinator.L(.hint)) {
                        if viewModel.hasHintsAvailable {
                            viewModel.findHint()
                        } else {
                            flashNoHintsBanner()
                        }
                    }
                }

                Button(coordinator.L(.quitButton)) { isShowingQuitMatchConfirm = true }
                    .buttonStyle(.bordered)
                    .tint(.white)
            } else {
                // Mirrors mac's toolbar Rematch button — same availability
                // (gameOver + canRematch) — for whenever the post-game overlay's been
                // dismissed (its "x") to look at the finished board, so there's still a
                // way back to the same opponent instead of only Start Match rolling a
                // fresh one.
                if viewModel.gameState == .gameOver && viewModel.canRematch {
                    Button(coordinator.L(.rematch)) { viewModel.rematch() }
                        .buttonStyle(.bordered)
                        .tint(.white)
                }

                Button {
                    viewModel.startNewGame()
                } label: {
                    Label(coordinator.L(.startButton), systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        // Landscape only — see rulesCapsuleCompact for why this is a distinct, shorter
        // variant rather than reusing rulesCapsule directly: topBar's frame is clipped
        // to 44pt (to contain the pre-game Start button), so anything placed here has
        // to actually fit within that band, not just overflow into it the way
        // Blackjack/Video Poker's credit-panel overlay does.
        .overlay {
            if isLandscape {
                rulesCapsuleCompact
            }
        }
    }

    // MARK: Scaled game content

    // These formulas mirror gameContent(landscape:)'s actual view tree (spacing,
    // padding, boardGrid's own .padding(.vertical, 4)) term for term, rather than
    // approximating — a computed scale even a few points too generous makes the
    // *real* rendered content taller than the box it's fit into, and since the
    // GeometryReader below now clips to that box (so the overflow can't bleed into
    // the topBar above it), an underestimate here means real content — the pre-game
    // placeholder hand, most visibly — gets its top cropped instead. The 1.04x pads
    // against anything not perfectly predictable from this static formula (SwiftUI's
    // own text line-height rounding, etc.) by leaving a little unused margin instead
    // of risking that same crop. Neither branch includes the rules banner or the
    // score line — rulesCapsule and scoreCapsule are both fixed rows outside this
    // scaled content now (see body), not part of gameContent's own tree.
    // boardSpacing (10pt) was tuned for the fixed 150pt boardCardSize — kept as an
    // absolute constant, it reads as proportionally too wide once the board shrinks to
    // fit a landscape iPhone (10pt between ~90pt cells looks far more spread out than
    // 10pt between 150pt ones). Scaling it down with the card size keeps the same
    // visual tightness at any size.
    private static func boardSpacing(for cardWidth: CGFloat) -> CGFloat {
        cardWidth * Self.boardSpacing / Self.boardCardSize.width
    }

    private func intrinsicSize(landscape: Bool, landscapeHandCardSize: CGSize = HoneycombTouchView.boardCardSize) -> CGSize {
        if landscape {
            // Board cells match landscapeHandCardSize now (see computeLandscapeHandCardSize),
            // so boardWidth/boardHeight use it too instead of the fixed boardCardSize
            // constant — otherwise this and computeLandscapeHandCardSize would disagree
            // about how tall the board is and the solved-for scale would be wrong.
            let spacing = Self.boardSpacing(for: landscapeHandCardSize.width)
            let handColumnWidth = 3 * landscapeHandCardSize.width + 2 * Self.handSpacing
            let boardWidth = 3 * landscapeHandCardSize.width + 2 * spacing
            let width = handColumnWidth * 2 + boardWidth + 2 * 24 + 32
            let boardHeight = 3 * landscapeHandCardSize.height + 2 * spacing
            // Removed vertical padding from gameContent, so height is just boardHeight.
            let height = boardHeight
            return CGSize(width: width * 1.01, height: height * 1.01)
        } else {
            let width = 5 * Self.playerCardSize.width + 4 * Self.handSpacing + 16
            let boardHeight = 3 * Self.boardCardSize.height + 2 * Self.boardSpacing
            // VStack(spacing: 8) { oppRow; boardGrid.padding(.vertical,4); playerRow }
            // .padding(8) = oppRow + boardHeight + playerRow + (2 gaps*8 +
            // boardGrid's own vertical padding 8 + outer padding 16). oppRow now
            // uses playerCardSize too (matched sizes per request), hence the *2.
            let height = Self.playerCardSize.height * 2 + boardHeight + 40
            return CGSize(width: width * 1.02, height: height * 1.04)
        }
    }

    // Landscape's shared card size — used for the board cells AND the hand cards, so
    // they read as the same size (previously the board stayed pinned at a fixed 150pt
    // while hands grew independently, leaving the board looking undersized next to
    // them). Solved directly from the available window: the board's 3-row grid is
    // always the taller of the two (hands are only a 2-row 3/2 pyramid), so it's the
    // binding constraint on height; width is bounded by fitting both hand columns plus
    // the board side by side. The card size used everywhere is the smaller of what
    // each dimension allows.
    private func computeLandscapeHandCardSize(availableSize: CGSize) -> CGSize {
        guard availableSize.width > 0, availableSize.height > 0 else { return Self.boardCardSize }

        // boardSpacing itself scales with the card width being solved for here (see
        // Self.boardSpacing(for:)) — spacingRatio substitutes that relationship into
        // both constraints below algebraically instead of assuming a fixed 10pt gap.
        let spacingRatio = Self.boardSpacing / Self.boardCardSize.width

        // Must match intrinsicSize(landscape: true)'s formulas exactly (boardWidth/
        // boardHeight there are also 3 * this same card size + spacing), or the scale
        // solved there won't match the size actually used here.
        // boardHeight = 3*(w*aspect) + 2*(spacingRatio*w) = w*(3*aspect + 2*spacingRatio)
        let widthFromHeight = (availableSize.height / 1.01) / (3 * Self.cardAspect + 2 * spacingRatio)

        // Total width = 2 hand columns (3 cards + 2 gaps each) + board (3 cards + 2
        // gaps) + 2*24 gaps between columns/board + 32 outer horizontal padding.
        // 2*(3w + 2*handSpacing) + (3w + 2*spacingRatio*w) + 48 + 32 = availableWidth/1.01
        let widthFromWidth = (availableSize.width / 1.01 - 4 * Self.handSpacing - 80) / (9 + 2 * spacingRatio)

        let width = max(min(widthFromHeight, widthFromWidth), 40)
        return CGSize(width: width, height: width * Self.cardAspect)
    }

    @ViewBuilder
    private func gameContent(landscape: Bool, landscapeHandCardSize: CGSize = HoneycombTouchView.boardCardSize) -> some View {
        if landscape {
            HStack(alignment: .center, spacing: 24) {
                VStack(spacing: 6) {
                    handLabel(honeycombLocalizedPlayerRankName(
                        cardsCollected: HoneycombProfileManager.shared.unlockedCardIds.count,
                        totalCards: HoneycombDatabase.shared.allCards.count,
                        language: coordinator.language))
                    pyramidHand(cards: playerDisplayHand, size: landscapeHandCardSize) { i, card in
                        HoneycombFlipContainer(isRevealed: isPlayerCardRevealed[i]) {
                            HoneycombCardView(card: card, size: landscapeHandCardSize, isFlipped: true)
                        } back: {
                            playerHandCard(card, size: landscapeHandCardSize)
                                .id(card.id)
                        }
                        .id(handIdentityToken)
                        .matchedGeometryEffect(id: card.id, in: animationSpace)
                        .modifier(SwapLiftEffect(isAnimating: viewModel.swapAnimationPhase != .idle && viewModel.swapHighlightCardIds.contains(card.id), phase: viewModel.swapAnimationPhase))
                    }
                }
                .zIndex(viewModel.swapAnimationPhase == .idle ? 0 : 100)

                // Permanently recessed below both hand rows (whose own zIndex only
                // toggles 0<->100 during a swap) rather than relying on that dynamic
                // toggle to reliably out-rank boardGrid's implicit 0 every time — see
                // the identical fix in the portrait branch below for why.
                boardGrid(cardSize: landscapeHandCardSize)
                    .zIndex(-1)

                VStack(spacing: 6) {
                    // Not "Dealer" — Honeycomb's opponent is a named AI difficulty
                    // (e.g. "Baby Bee"), not a card-game dealer role like Blackjack's.
                    handLabel(honeycombLocalizedDifficultyName(viewModel.options.difficulty, language: coordinator.language))
                    pyramidHand(cards: opponentDisplayHand, size: landscapeHandCardSize) { i, card in
                        HoneycombFlipContainer(isRevealed: isOpponentCardRevealed[i]) {
                            HoneycombCardView(card: card, size: landscapeHandCardSize, isFlipped: true)
                        } back: {
                            opponentHandCard(card, size: landscapeHandCardSize)
                                .id(card.id)
                        }
                        .id(handIdentityToken)
                        .matchedGeometryEffect(id: card.id, in: animationSpace)
                        .modifier(SwapLiftEffect(isAnimating: viewModel.swapAnimationPhase != .idle && viewModel.swapHighlightCardIds.contains(card.id), phase: viewModel.swapAnimationPhase))
                    }
                }
                .zIndex(viewModel.swapAnimationPhase == .idle ? 0 : 100)
            }
            .padding(.horizontal, 16)
        } else {
            VStack(spacing: 8) {
                // Matches playerCardSize per request — was a smaller, distinct
                // opponentCardSize before.
                rowHand(cards: opponentDisplayHand, size: Self.playerCardSize) { i, card in
                    HoneycombFlipContainer(isRevealed: isOpponentCardRevealed[i]) {
                        HoneycombCardView(card: card, size: Self.playerCardSize, isFlipped: true)
                    } back: {
                        opponentHandCard(card, size: Self.playerCardSize)
                            .id(card.id)
                    }
                    .id(handIdentityToken)
                    .matchedGeometryEffect(id: card.id, in: animationSpace)
                    .modifier(SwapLiftEffect(isAnimating: viewModel.swapAnimationPhase != .idle && viewModel.swapHighlightCardIds.contains(card.id), phase: viewModel.swapAnimationPhase))
                }
                .zIndex(viewModel.swapAnimationPhase == .idle ? 0 : 100)

                // Permanently recessed below both hand rows during a Nectar Exchange
                // swap — a Nectar Exchange card flying between hand and board otherwise
                // got visually clipped behind board cells mid-flight, since boardGrid
                // sat at the implicit default zIndex 0 and had to rely on the hand
                // rows' dynamic 0<->100 toggle to reliably out-rank it on every frame
                // instead of always sitting beneath them.
                boardGrid()
                    .zIndex(-1)
                    .padding(.vertical, 4)

                rowHand(cards: playerDisplayHand, size: Self.playerCardSize) { i, card in
                    HoneycombFlipContainer(isRevealed: isPlayerCardRevealed[i]) {
                        HoneycombCardView(card: card, size: Self.playerCardSize, isFlipped: true)
                    } back: {
                        playerHandCard(card)
                            .id(card.id)
                    }
                    .id(handIdentityToken)
                    .matchedGeometryEffect(id: card.id, in: animationSpace)
                    .modifier(SwapLiftEffect(isAnimating: viewModel.swapAnimationPhase != .idle && viewModel.swapHighlightCardIds.contains(card.id), phase: viewModel.swapAnimationPhase))
                }
                .zIndex(viewModel.swapAnimationPhase == .idle ? 0 : 100)
            }
            .padding(8)
        }
    }

    private var playerDisplayHand: [HoneycombCard] {
        viewModel.gameState == .setup ? Self.playerPlaceholderHand
            : (viewModel.gameState == .gameOver ? viewModel.playerStartingDeck : viewModel.playerHand)
    }

    private var opponentDisplayHand: [HoneycombCard] {
        viewModel.gameState == .setup ? Self.opponentPlaceholderHand : viewModel.opponentHand
    }

    private func handLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white.opacity(0.7))
    }

    private func rowHand<Content: View>(cards: [HoneycombCard], size: CGSize,
                                        @ViewBuilder content: @escaping (Int, HoneycombCard) -> Content) -> some View {
        HStack(spacing: Self.handSpacing) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { i, card in content(i, card) }
        }
        .frame(height: size.height)
    }

    private func pyramidHand<Content: View>(cards: [HoneycombCard], size: CGSize,
                                            @ViewBuilder content: @escaping (Int, HoneycombCard) -> Content) -> some View {
        VStack(spacing: Self.handSpacing) {
            HStack(spacing: Self.handSpacing) { ForEach(0..<min(3, cards.count), id: \.self) { i in content(i, cards[i]) } }
            if cards.count > 3 {
                HStack(spacing: Self.handSpacing) { ForEach(3..<cards.count, id: \.self) { i in content(i, cards[i]) } }
            }
        }
        .frame(width: 3 * size.width + 2 * Self.handSpacing)
    }

    // MARK: Rules + score (undo/hint moved up into the menu bar)

    // Fixed row, not scaled with the board — rules text stays legible regardless of
    // screen size. Sits directly below topBar in normal flow (no overlap with the
    // menu bar by construction, unlike an earlier version that floated over topBar as
    // an overlay). Score renders separately — see scoreCapsule below the board — so
    // it can no longer drag this row's height up and risk that same overlap.
    private var rulesCapsule: some View {
        let isDense = rulesBannerLines.count > 2
        return Text(rulesBannerLines.joined(separator: "  •  "))
            .font(.system(size: isDense ? 13 : 16, weight: .black))
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .multilineTextAlignment(.center)
            // Fixed regardless of actual line count — pre-game shows one short word
            // ("Roulette"), in-game shows the real rules list which can wrap to 2
            // lines. This is a normal flow row above GeometryReader, so if its height
            // tracked the text exactly, GeometryReader's available height — and the
            // board's scale/position within it — would visibly shift the moment a
            // match starts and the text changes. Reserves 2-line-at-16pt worth of
            // space always instead.
            .frame(minHeight: 40)
            .contentShape(Rectangle())
            .onTapGesture {
                isShowingRulesTooltip = true
            }
            // Anchored/arrowed from the top, not the bottom — this row sits right
            // below topBar with no room above it for a popover to open upward into;
            // .bottom used to push the popover up against (and get clipped by) the
            // status bar/notch. Opening downward into the board has plenty of room.
            .popover(isPresented: $isShowingRulesTooltip, attachmentAnchor: .point(.top), arrowEdge: .top) {
                let isPreGame = viewModel.gameState != .playing && viewModel.gameState != .suddenDeath
                let isRoulette = isPreGame && !viewModel.options.forceNormalMode && viewModel.options.selectedRules.isEmpty
                let effectiveRules: [HoneycombRule] = isPreGame && !isRoulette ? Array(viewModel.options.selectedRules) : viewModel.activeRules
                RuleExplanationPopover(viewModel: viewModel, isRoulette: isRoulette, effectiveRules: effectiveRules)
                    .presentationCompactAdaptation(.popover)
            }
            .foregroundStyle(.yellow)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.75))
            .cornerRadius(16)
    }

    // Landscape's topBar overlay version of rulesCapsule — same tap-to-explain
    // popover and content, but sized to actually fit inside topBar's clipped 44pt
    // band instead of rulesCapsule's own fixed 40pt-minimum, two-line, generously-
    // padded pill, which would just get clipped off here. Single line, smaller font,
    // truncates rather than wrapping — landscape's shorter screen has the least
    // vertical room to spare, so this trades some horizontal legibility for not
    // needing its own row at all.
    private var rulesCapsuleCompact: some View {
        Text(rulesBannerLines.joined(separator: "  •  "))
            .font(.system(size: 13, weight: .black))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .truncationMode(.tail)
            .frame(maxWidth: 240)
            .contentShape(Rectangle())
            .onTapGesture {
                isShowingRulesTooltip = true
            }
            // See rulesCapsule's identical comment — this sits even closer to the true
            // top of the screen (inside topBar itself), so the same top-edge/notch
            // clipping problem is worse here if left anchored/arrowed from the bottom.
            .popover(isPresented: $isShowingRulesTooltip, attachmentAnchor: .point(.top), arrowEdge: .top) {
                let isPreGame = viewModel.gameState != .playing && viewModel.gameState != .suddenDeath
                let isRoulette = isPreGame && !viewModel.options.forceNormalMode && viewModel.options.selectedRules.isEmpty
                let effectiveRules: [HoneycombRule] = isPreGame && !isRoulette ? Array(viewModel.options.selectedRules) : viewModel.activeRules
                RuleExplanationPopover(viewModel: viewModel, isRoulette: isRoulette, effectiveRules: effectiveRules)
                    .presentationCompactAdaptation(.popover)
            }
            .foregroundStyle(.yellow)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.75))
            .cornerRadius(14)
    }

    // Score only shows once a match exists — matches the old scoreBadge's gating —
    // but always RENDERS (hidden via opacity, not removed via `if`) so its footprint
    // is constant, same reasoning as rulesCapsule's fixed .frame(minHeight:) above:
    // this is a fixed row in body (right after GeometryReader, below the scaled
    // board), so an `if`-gated version popping in/out would change that row's own
    // height and shift the board itself. Plain text (no pill background) — sized to
    // match rulesCapsule's isDense logic, just .bold instead of rulesCapsule's
    // .black weight.
    private var scoreCapsule: some View {
        let isDense = rulesBannerLines.count > 2
        // Wide fixed gap (not a "–" separator) per request — reads as two distinct
        // "label: score" stats rather than one "X – Y" scoreline.
        return HStack(spacing: 28) {
            // Rank name (not a static "You"), same source as the landscape hand-side
            // label — mac's equivalent score row had the identical gap, fixed alongside
            // this. Reuses scoreDealerFmt's "%@ %d" shape (name, score), same as the
            // opponent side below, rather than the old count-only scoreYouFmt.
            Text(coordinator.L(.scoreDealerFmt,
                                honeycombLocalizedPlayerRankName(
                                    cardsCollected: HoneycombProfileManager.shared.unlockedCardIds.count,
                                    totalCards: HoneycombDatabase.shared.allCards.count,
                                    language: coordinator.language),
                                viewModel.board.playerScore + viewModel.playerHand.count))
            // Not "DEALER" — shows the opponent's actual name (e.g. "Baby Bee"), same
            // fix as the hand-side label above the opponent's cards. Name comes first
            // to match "You: N" on the left — scoreDealerFmt is "%@ %d" to match this
            // call's (name, score) argument order; a stale "%d %@" here crashed on
            // every Honeycomb match (the %@ tried to message the Int score as if it
            // were an object).
            Text(coordinator.L(.scoreDealerFmt,
                                honeycombLocalizedDifficultyName(viewModel.options.difficulty, language: coordinator.language),
                                viewModel.board.opponentScore + viewModel.opponentHand.count))
        }
        .opacity(viewModel.gameState != .setup ? 1 : 0)
        .font(.system(size: isDense ? 13 : 16, weight: .bold))
        .foregroundStyle(.yellow)
    }

    private var rulesBannerLines: [String] {
        if isMidMatch {
            if viewModel.activeRules.isEmpty { return [coordinator.L(.ruleLineNormal)] }
            return viewModel.activeRules.map { rule in
                if rule == .ascension || rule == .descension, !viewModel.ascensionDescensionSuits.isEmpty {
                    let suitNames = viewModel.ascensionDescensionSuits.sorted()
                        .map { HoneycombCardData.localizedSuitName($0, language: coordinator.language) }
                    return coordinator.L(.ruleLineSuitFmt, honeycombLocalizedRuleName(rule.rawValue, language: coordinator.language), suitNames.joined(separator: ", "))
                }
                return honeycombLocalizedRuleName(rule.rawValue, language: coordinator.language)
            }
        }
        if viewModel.options.forceNormalMode { return [coordinator.L(.ruleLineNormal)] }
        if !viewModel.options.selectedRules.isEmpty {
            return HoneycombRule.allCases
                .filter { viewModel.options.selectedRules.contains($0) }
                .map { honeycombLocalizedRuleName($0.rawValue, language: coordinator.language) }
        }
        return [coordinator.L(.ruleLineRoulette)]
    }

    // MARK: Board

    private func boardGrid(cardSize: CGSize = HoneycombTouchView.boardCardSize) -> some View {
        let spacing = Self.boardSpacing(for: cardSize.width)
        return VStack(spacing: spacing) {
            ForEach(0..<3) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<3) { col in
                        boardCell(index: row * 3 + col, cardSize: cardSize)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func boardCell(index: Int, cardSize: CGSize) -> some View {
        let cell = viewModel.board.cells[index]
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.2))
                .frame(width: cardSize.width, height: cardSize.height)

            if let card = cell.card {
                let stealEligible = isStealingCard && viewModel.isStealEligible(card)
                let highlightIndices: Set<Int> = viewModel.pointHighlight?.cardId == card.id
                    ? viewModel.pointHighlight!.statIndices
                    : []
                HoneycombCardView(card: card, size: cardSize, isFlipped: false,
                                  stealHighlight: stealEligible, highlightedStatIndices: highlightIndices)
            }
        }
        .modifier(TouchHintHighlight(isHighlighted: viewModel.activeHint?.boardIndex == index))
        .onTapGesture { handleBoardTap(index: index, cell: cell) }
        // Steal mode: double-tap an eligible captured opponent card to steal it
        // straight into the card bank — a single step to the confirmation alert, no
        // hand-slot target needed.
        .onTapGesture(count: 2) { handleBoardDoubleTap(index: index, cell: cell) }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { cellFrames[index] = geo.frame(in: .named(Self.dragSpace)) }
                    .onChange(of: geo.frame(in: .named(Self.dragSpace))) { _, newFrame in
                        cellFrames[index] = newFrame
                    }
            }
        )
    }

    private func handleBoardTap(index: Int, cell: HoneycombCell) {
        if viewModel.gameState == .playing && viewModel.isPlayerTurn,
           let cardId = selectedHandCardId,
           let handIdx = viewModel.playerHand.firstIndex(where: { $0.id == cardId }) {
            if viewModel.playerPlayCard(handIndex: handIdx, boardIndex: index) {
                selectedHandCardId = nil
                placementHaptic.impactOccurred()
            }
        }
    }

    private func handleBoardDoubleTap(index: Int, cell: HoneycombCell) {
        guard isStealingCard, viewModel.showPostGamePrompt, viewModel.gameState == .gameOver,
              let card = cell.card, viewModel.isStealEligible(card) else { return }
        viewModel.requestSteal(boardIndex: index)
    }

    // MARK: Hand cards

    @ViewBuilder
    private func playerHandCard(_ card: HoneycombCard, size: CGSize = Self.playerCardSize) -> some View {
        let handIndex = viewModel.playerHand.firstIndex(where: { $0.id == card.id })
        let isMandated = viewModel.gameState == .playing
            && viewModel.mandatedPlayerHandIndex != nil
            && viewModel.mandatedPlayerHandIndex == handIndex
        let isLegalToPlay = viewModel.mandatedPlayerHandIndex == nil || viewModel.mandatedPlayerHandIndex == handIndex

        HoneycombCardView(card: card, size: size, isFlipped: false)
            .onTapGesture {
                if viewModel.gameState == .playing && viewModel.isPlayerTurn && isLegalToPlay {
                    selectedHandCardId = selectedHandCardId == card.id ? nil : card.id
                    selectionHaptic.impactOccurred()
                }
            }
            .opacity(dragHandCard?.id == card.id ? 0 : 1)
            .gesture(
                (viewModel.gameState == .playing && viewModel.isPlayerTurn && isLegalToPlay)
                    ? handDragGesture(card: card) : nil
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.blue, lineWidth: selectedHandCardId == card.id ? 4 : 0)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(coordinator.customCardColors.hintHighlightColor, lineWidth: isMandated ? 8 : 0)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.yellow, lineWidth: viewModel.swapHighlightCardIds.contains(card.id) ? 8 : 0)
            )
            .modifier(TouchHintHighlight(isHighlighted: handIndex != nil && viewModel.activeHint?.handIndex == handIndex))
            // Lift the selected card slightly so the two-tap flow reads clearly.
            .offset(y: selectedHandCardId == card.id ? -10 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: selectedHandCardId)
    }

    // MARK: Custom drag gestures (Klondike pattern, in pre-scale board space)

    private func handDragGesture(card: HoneycombCard) -> some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .named(Self.dragSpace))
            .onChanged { val in
                if dragHandCard == nil {
                    dragHandCard = card
                    dragLocation = val.startLocation
                    selectionHaptic.impactOccurred()
                }
                dragOffset = val.translation
            }
            .onEnded { _ in
                defer { clearDrag() }
                guard let card = dragHandCard,
                      viewModel.gameState == .playing, viewModel.isPlayerTurn,
                      let handIdx = viewModel.playerHand.firstIndex(where: { $0.id == card.id }),
                      let target = dropCellIndex() else { return }
                if viewModel.playerPlayCard(handIndex: handIdx, boardIndex: target) {
                    selectedHandCardId = nil
                    placementHaptic.impactOccurred()
                }
            }
    }

    private func dropCellIndex() -> Int? {
        let release = CGPoint(x: dragLocation.x + dragOffset.width,
                              y: dragLocation.y + dragOffset.height)
        // insetBy(-10, -10) intentionally makes neighboring cell frames overlap in the
        // ~20pt gutter between them, so a release near a shared edge still counts as a
        // drop rather than falling into the gap. min(by: distance) below breaks the
        // resulting ties by nearest cell center — this assumes no two cells can ever be
        // exactly equidistant from a release point given the fixed board layout; if the
        // grid spacing/geometry changes, that assumption needs re-checking.
        return cellFrames
            .filter { $0.value.insetBy(dx: -10, dy: -10).contains(release) }
            .min(by: { lhs, rhs in
                let l = CGPoint(x: lhs.value.midX - release.x, y: lhs.value.midY - release.y)
                let r = CGPoint(x: rhs.value.midX - release.x, y: rhs.value.midY - release.y)
                return (l.x * l.x + l.y * l.y) < (r.x * r.x + r.y * r.y)
            })?
            .key
    }

    private func clearDrag() {
        dragHandCard = nil
        dragOffset = .zero
    }

    @ViewBuilder
    private func dragGhost(landscape: Bool, landscapeHandCardSize: CGSize) -> some View {
        if let card = dragHandCard {
            let size = landscape ? landscapeHandCardSize : Self.playerCardSize
            HoneycombCardView(card: card, size: size, isFlipped: false)
                .position(x: dragLocation.x + dragOffset.width,
                          y: dragLocation.y + dragOffset.height - size.height * 0.25)
                .shadow(radius: 10, y: 5)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func opponentHandCard(_ card: HoneycombCard, size: CGSize) -> some View {
        let isPostWinReveal = viewModel.gameState == .gameOver && viewModel.showPostGamePrompt && viewModel.matchOutcome == .win
        let flipped = !isPostWinReveal && !viewModel.isOpponentCardVisible(cardId: card.id)
        let handIndex = viewModel.opponentHand.firstIndex(where: { $0.id == card.id })
        let isMandated = viewModel.gameState == .playing
            && !viewModel.isPlayerTurn
            && viewModel.mandatedOpponentHandIndex != nil
            && viewModel.mandatedOpponentHandIndex == handIndex

        HoneycombCardView(card: card, size: size, isFlipped: flipped)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                        .stroke(coordinator.customCardColors.hintHighlightColor, lineWidth: isMandated ? 8 : 0)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.yellow, lineWidth: viewModel.swapHighlightCardIds.contains(card.id) ? 8 : 0)
                )
        }


    private func dismissRuleBanner() {
        ruleBannerTask?.cancel()
        ruleBannerTask = nil
        withAnimation(.easeOut(duration: 0.3)) { showingRuleBanner = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            viewModel.advanceBannerQueue()
        }
    }

    private func flashRuleBanner(_ text: String) {
        ruleBannerTask?.cancel()
        ruleBannerText = text
        withAnimation(.easeIn(duration: 0.15)) { showingRuleBanner = true }
        guard !coordinator.manuallyDismissBanners else {
            ruleBannerTask = nil
            return
        }
        let task = DispatchWorkItem { [self] in dismissRuleBanner() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: task)
        ruleBannerTask = task
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

    // MARK: Post-game

    private var canStealCard: Bool {
        viewModel.matchOutcome == .win
            && !coordinator.noStressMode
            && !viewModel.hasStolenThisMatch
            && !HoneycombProfileManager.shared.isCardBankFull
            && viewModel.hasStealableCard
    }

    private var postGameOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 16) {
                if viewModel.matchOutcome == .loss {
                    Text(coordinator.L(.notTodayPartner))
                        .font(.system(size: 30, weight: .black))
                        .foregroundColor(.yellow)
                } else {
                    // The win overlay reappears after a steal is confirmed (Take a
                    // Card is now gone, since hasStolenThisMatch is true) — a repeat
                    // "You Win!" would read as stale, so it confirms what just
                    // happened instead.
                    let title = (viewModel.matchOutcome == .win && viewModel.hasStolenThisMatch)
                        ? coordinator.L(.cardAddedToBank) : viewModel.matchResult
                    Text(title)
                        .font(.system(size: 44, weight: .bold))
                        // Tie is styled exactly like a win on mac (a final result, not a
                        // lesser outcome) — this used to fall through to the else branch's
                        // white text since only .win was checked here.
                        .foregroundColor(viewModel.matchOutcome == .win || viewModel.matchOutcome == .tie ? .yellow : .white)
                }

                if viewModel.matchOutcome == .win && !coordinator.noStressMode {
                    if HoneycombProfileManager.shared.isCardBankFull {
                        VStack(spacing: 4) {
                            Text(coordinator.L(.cardBankFullLine1))
                            Text(coordinator.L(.cardBankFullLine2))
                        }
                        .font(.footnote).foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    } else if viewModel.hasObtainedAllOpponentCards {
                        Text(coordinator.L(.obtainedAllCardsFmt, honeycombLocalizedDifficultyName(viewModel.options.difficulty, language: coordinator.language)))
                            .font(.footnote).foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    } else if viewModel.hasStolenThisMatch {
                        VStack(spacing: 4) {
                            Text(coordinator.L(.rematchToTakeAnother))
                            let remaining = viewModel.opponentCardsRemainingCount
                            Text(remaining == 1 ? coordinator.L(.cardToSteal) : coordinator.L(.cardsToStealFmt, remaining))
                        }
                        .font(.footnote).foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    } else if viewModel.stealProtectionActive && viewModel.hasStealableCard {
                        // Matches mac's own guard (HoneycombView.swift) — only claims a
                        // card is available when one actually is. stealProtectionActive
                        // alone doesn't guarantee that (it widens eligibility to any
                        // not-yet-unlocked board card, but if every card left on this
                        // board is already unlocked, there's still nothing to offer).
                        // iOS was missing this second half of the check.
                        Text(coordinator.L(.stealProtectionLine))
                            .font(.footnote).foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                }

                VStack(spacing: 10) {
                    if canStealCard {
                        Button {
                            isStealingCard = true
                        } label: {
                            Label(coordinator.L(.stealCard), systemImage: "hand.point.up.left")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.yellow)
                        .foregroundStyle(.black)
                    }
                    if viewModel.canRematch {
                        Button {
                            viewModel.rematch()
                        } label: {
                            Label(coordinator.L(.rematch), systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Button {
                        viewModel.startNewGame()
                    } label: {
                        Label(coordinator.L(.newMatch), systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                }
                .frame(maxWidth: 280)
            }
            .padding(28)
            .padding(.top, 8)
            // Matches mac's HoneycombView post-game overlay exactly (solid dark card +
            // shadow) rather than the frosted .ultraThinMaterial look this had before —
            // that translucent glass let the board show through and didn't match any
            // other banner in the app.
            // 0.75 matches mac/Windows and the other five games' win banners (mac
            // normalized all of them from a mix of 0.5/0.8 to 0.75 — see
            // HoneycombView.swift).
            .background(Color.black.opacity(0.75))
            .cornerRadius(16)
            .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.5), radius: 16)
            // Dismiss lives on the overlay card itself (not the screen corner) so it
            // never stacks on top of the top bar's Start/Quit button.
            .overlay(alignment: .topTrailing) {
                Button {
                    viewModel.showPostGamePrompt = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                .padding(12)
                .accessibilityLabel(coordinator.L(.dismissA11y))
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var stealInstructionBar: some View {
        VStack(spacing: 12) {
            Text(coordinator.L(.stealInstructionTap))
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Button(coordinator.L(.cancel)) {
                isStealingCard = false
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 60)
    }

    private func triggerDealFlip() {
        // Capture the current deal's identity so a stale closure from an interrupted
        // deal (quit + restart within the stagger window) can detect it's no longer
        // current and no-op instead of flipping cards that belong to a different deal.
        let generation = handIdentityToken
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * Self.dealFlipStagger) {
                guard handIdentityToken == generation else { return }
                isPlayerCardRevealed[i] = true
            }
        }
        // Interleaved with the player's stagger (not offset to start after it finishes)
        // — the two hands are independent, so there's no reason dealing should take 2x
        // as long as a single hand's reveal.
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * Self.dealFlipStagger) {
                guard handIdentityToken == generation else { return }
                isOpponentCardRevealed[i] = true
            }
        }
    }
}

// Applies .clipped() only when isClipped is true — lets a caller suspend clipping
// conditionally (e.g. while an oversized animated child would otherwise get sliced
// at the container's edge) without duplicating the whole modifier chain in an
// if/else at the call site.
private struct ConditionalClip: ViewModifier {
    let isClipped: Bool

    func body(content: Content) -> some View {
        if isClipped {
            content.clipped()
        } else {
            content
        }
    }
}

// MARK: - Settings section shown inside the slide-down menu

struct HoneycombSettingsSection: View {
    @Bindable var viewModel: HoneycombViewModel
    let isMidMatch: Bool
    @Bindable var coordinator: AppCoordinator

    @State private var showingRules = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Opponent, Match Rules, and Ban List used to live in their own sheet behind
            // a dedicated top-bar "Rules" icon. They're game options like any other
            // per-game setting, so they moved into Options instead — the top-bar icon is
            // gone, and the rules banner's own tap-for-explanation popover (unaffected by
            // this move) is still how a mid-match player reads the active rules, without
            // needing to come into Options at all.
            // .pickerStyle(.menu) outside a Form/List only renders the selected value
            // + chevron as a button — the Picker's own label text is silently dropped
            // (same issue found and fixed in Video Poker's Variant/Default Bet pickers).
            //
            // Extra .padding(.bottom, 8) on this row (on top of the VStack's own
            // spacing: 8) — Toggle's default style carries its own built-in vertical
            // padding that this plain HStack row doesn't have, so matching Toggle's
            // visual row-to-row gap needs more than the flat 8 that's already correct
            // between toggles.
            HStack {
                Text(coordinator.L(.opponentPickerLabel))
                Spacer()
                Picker(coordinator.L(.opponentPickerLabel), selection: $viewModel.options.difficulty) {
                    ForEach(HoneycombDifficulty.allCases, id: \.self) { d in
                        Text(honeycombLocalizedDifficultyName(d, language: coordinator.language)).tag(d)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            .disabled(isMidMatch)
            .opacity(isMidMatch ? 0.5 : 1)
            .padding(.bottom, 8)

            // Rules (game choice + ban list, merged into one screen) sits directly under
            // Opponent — the other game-relevant setting. Sound/No Stress Mode/Honey
            // Mode/Hide Hint/Manually Dismiss Banners live in OptionsFullScreenView's
            // own Global section now, not here — this card is Honeycomb-specific only.
            rulesNavRow
                .disabled(isMidMatch)
                .opacity(isMidMatch ? 0.5 : 1)

            if isMidMatch {
                Text(coordinator.L(.settingsUnlockNote))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showingRules) { HoneycombRulesSheet(viewModel: viewModel) }
    }

    private var rulesNavRow: some View {
        Button {
            showingRules = true
        } label: {
            HStack {
                Text(coordinator.L(.toolbarRules))
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stats sheet

struct HoneycombStatsSheet: View {
    let stats: HoneycombStats
    @Environment(\.dismiss) private var dismiss
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        NavigationStack {
            List {
                statRow(coordinator.L(.statMatchesPlayed), stats.gamesPlayed)
                statRow(coordinator.L(.statMatchesWon), stats.matchesWon)
                statRow(coordinator.L(.statMatchesLost), stats.matchesLost)
                statRow(coordinator.L(.statMatchesDrawn), stats.matchesDrawn)
                HStack {
                    Text(coordinator.L(.winRate))
                    Spacer()
                    Text(String(format: "%.1f%%", stats.winRate)).foregroundStyle(.secondary)
                }
                statRow(coordinator.L(.statCardsCaptured), stats.cardsCaptured)
                statRow(coordinator.L(.statCardsStolen), stats.cardsStolen)
                statRow(coordinator.L(.statFallenAcesIos), stats.fallenAces)
                statRow(coordinator.L(.statCurrentWinStreak), stats.currentWinStreak)
                statRow(coordinator.L(.statLongestWinStreak), stats.longestWinStreak)
                statRow(coordinator.L(.statFlawlessVictoriesIos), stats.flawlessVictories)
                statRow(coordinator.L(.statSamePlusTriggers), stats.samePlusTriggers)
                statRow(coordinator.L(.statSuddenDeathCountIos), stats.suddenDeathCount)
                statRow(coordinator.L(.statTimesStartedOver), stats.timesStartedOver)
                Section(coordinator.L(.statWinsByDifficultySection)) {
                    statRow(coordinator.L(.statBabyBee), stats.easyWins)
                    statRow(coordinator.L(.statHoneyBee), stats.mediumWins)
                    statRow(coordinator.L(.statQueenBee), stats.hardWins)
                    statRow(coordinator.L(.statKillerBee), stats.ultraHardWins)
                }
            }
            .navigationTitle(coordinator.L(.statsSheetTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(coordinator.L(.done)) { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func statRow(_ label: String, _ value: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(value)").foregroundStyle(.secondary)
        }
    }
}
