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
    private static let opponentCardSize = CGSize(width: 96, height: 96 * cardAspect)
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
        ZStack {
            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    // The pre-game "Start" button (borderedProminent + icon label) is
                    // taller than the other topBar controls, so left unclipped it
                    // overflows this fixed frame and bleeds into the board below —
                    // clip so every topBar state stays confined to its 44pt band.
                    .clipped()

                GeometryReader { geo in
                    let isLandscape = geo.size.width > geo.size.height
                    let intrinsic = intrinsicSize(landscape: isLandscape)
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
                    gameContent(landscape: isLandscape)
                        // No explicit alignment — matches the original ZStack's default
                        // (.center) exactly. An earlier version of this fix added
                        // alignment: .topLeading here, which changed how any mismatch
                        // between gameContent's actual rendered size and intrinsicSize()'s
                        // formula-based estimate gets distributed (all to bottom/right
                        // instead of split evenly) — that's what pushed the setup screen's
                        // placeholder hand up into the topBar after quitting a match.
                        .frame(width: intrinsic.width, height: intrinsic.height)
                        .overlay(dragGhost)
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
                    .clipped()
                }
            }

            // Matches mac's HoneycombView: two independent FlashBannerView render sites
            // (not a combined container) — mutually exclusive in practice, and each one
            // centers itself via FlashBannerView's own symmetric Spacers.
            if showingRuleBanner {
                FlashBannerView(message: ruleBannerText, onDismiss: dismissRuleBanner)
                    .zIndex(100)
            }
            if showNoHintsBanner {
                FlashBannerView(message: coordinator.L(.noHintsBanner))
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

            if isStealingCard {
                stealInstructionBar
            }

            if viewModel.showPostGamePrompt && !isStealingCard && !showingRuleBanner {
                postGameOverlay
            }
        }
        .sheet(isPresented: $showingDecks) { HoneycombDecksSheet(viewModel: viewModel) }
        .environment(\.activeCardBackTheme, coordinator.cardBackTheme)
        .environment(\.activeCustomCardColors, coordinator.customCardColors)
        .sheet(isPresented: $isMenuOpen) { GameSelectionFullScreenView(coordinator: coordinator) }
        .sheet(isPresented: $showingStats) { HoneycombStatsSheet(stats: viewModel.stats) }
        .sheet(isPresented: $showingThemes) { ThemesFullScreenView(coordinator: coordinator) }
        .sheet(isPresented: $showingOptions) {
            OptionsFullScreenView(coordinator: coordinator, onShowStats: { showingStats = true }) {
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

    // MARK: Top bar

    private var topBar: some View {
        // scoreBadge is an overlay, not a third HStack element flanked by Spacers —
        // the leading (menu/decks) and trailing (Quit/Start) button groups aren't the
        // same width, so centering it "between" two Spacers actually centered it in
        // whatever space was left over, not on the bar itself. An overlay centers it
        // on the full bar width regardless of how wide either button group is.
        HStack(spacing: 12) {
            menuBarButtons(isMenuOpen: $isMenuOpen, showingOptions: $showingOptions, showingThemes: $showingThemes, coordinator: coordinator)

            topBarIconButton(systemImage: "rectangle.stack", accessibilityLabel: coordinator.L(.manageDecks)) {
                showingDecks = true
            }
            .disabled(isMidMatch)

            // No onChange(of: viewModel.debugBannerRequest) needed here — unlike the
            // other five games, HoneycombViewModel's debugBannerRequest didSet (shared/
            // Honeycomb/ViewModels/HoneycombViewModel.swift) is fully self-contained and
            // already fires on iOS for free.
            debugMenuButton(
                items: [
                    ("Win", .win), ("Loss", .loss),
                    ("Same", .same), ("Plus", .plus), ("Sudden Death", .suddenDeath)
                ],
                catalogSections: DebugBannerCatalogMenu.sections,
                onSelect: { viewModel.debugBannerRequest = $0 },
                onSelectCatalog: { viewModel.debugFireCatalogBanner($0) }
            )

            Spacer()

            if isMidMatch {
                Button(coordinator.L(.quitButton)) { viewModel.gameState = .setup }
                    .buttonStyle(.bordered)
                    .tint(.white)
            } else {
                Button {
                    viewModel.startNewGame()
                } label: {
                    Label(coordinator.L(.startButton), systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .overlay {
            if viewModel.gameState != .setup {
                scoreBadge
            }
        }
    }

    private var scoreBadge: some View {
        // Matches the rules banner's yellow-on-black styling instead of cyan/pink —
        // consistent with every other Honeycomb banner in the app.
        HStack(spacing: 10) {
            Text(coordinator.L(.scoreYouFmt, viewModel.board.playerScore + viewModel.playerHand.count))
            Text("–")
            // Not "DEALER" — shows the opponent's actual name (e.g. "Baby Bee"), same
            // fix as the hand-side label above the opponent's cards.
            Text(coordinator.L(.scoreDealerFmt, viewModel.board.opponentScore + viewModel.opponentHand.count,
                                honeycombLocalizedDifficultyName(viewModel.options.difficulty, language: coordinator.language)))
        }
        .foregroundStyle(.yellow)
        .font(.subheadline.weight(.bold))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        // Matches the rules banner's card styling (solid black.opacity(0.75) +
        // cornerRadius 16) instead of the lighter, more-transparent capsule this had
        // before, so the two banners read as a consistent pair.
        .background(Color.black.opacity(0.75))
        .cornerRadius(16)
    }

    // MARK: Scaled game content

    // These formulas mirror gameContent(landscape:)'s actual view tree (spacing,
    // padding, bannerRow's height, boardGrid's own .padding(.vertical, 4)) term for
    // term, rather than approximating — a computed scale even a few points too
    // generous makes the *real* rendered content taller than the box it's fit into,
    // and since the GeometryReader below now clips to that box (so the overflow
    // can't bleed into the topBar above it), an underestimate here means real
    // content — the pre-game placeholder hand, most visibly — gets its top cropped
    // instead. The 1.04x pads against anything not perfectly predictable from this
    // static formula (SwiftUI's own text line-height rounding, etc.) by leaving a
    // little unused margin instead of risking that same crop. Both branches reference
    // Self.bannerRowHeight rather than a hardcoded copy of bannerRow's own .frame
    // height, so the two can't silently drift apart the way two literal numbers would.
    private func intrinsicSize(landscape: Bool) -> CGSize {
        if landscape {
            let handColumnWidth = 2 * Self.playerCardSize.width + Self.handSpacing
            let boardWidth = 3 * Self.boardCardSize.width + 2 * Self.boardSpacing
            let width = handColumnWidth * 2 + boardWidth + 2 * 24 + 32
            let boardHeight = 3 * Self.boardCardSize.height + 2 * Self.boardSpacing
            // Board column: VStack(spacing: 8) { bannerRow; boardGrid } = boardHeight + 8 + bannerRowHeight,
            // plus the outer HStack's .padding(16) top+bottom = 32.
            let height = boardHeight + 8 + Self.bannerRowHeight + 32
            return CGSize(width: width * 1.02, height: height * 1.04)
        } else {
            let width = 5 * Self.playerCardSize.width + 4 * Self.handSpacing + 16
            let boardHeight = 3 * Self.boardCardSize.height + 2 * Self.boardSpacing
            // VStack(spacing: 8) { oppRow; bannerRow; boardGrid.padding(.vertical,4); playerRow }
            // .padding(8) = oppRow + boardHeight + playerRow + (3 gaps*8 + bannerRowHeight +
            // boardGrid's own vertical padding 8 + outer padding 16).
            let height = Self.opponentCardSize.height + Self.playerCardSize.height + boardHeight + 48 + Self.bannerRowHeight
            return CGSize(width: width * 1.02, height: height * 1.04)
        }
    }

    @ViewBuilder
    private func gameContent(landscape: Bool) -> some View {
        if landscape {
            HStack(alignment: .center, spacing: 24) {
                VStack(spacing: 6) {
                    handLabel(coordinator.L(.handLabelYou))
                    pyramidHand(cards: playerDisplayHand, size: Self.playerCardSize) { i, card in
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
                }
                .zIndex(viewModel.swapAnimationPhase == .idle ? 0 : 100)

                VStack(spacing: 8) {
                    bannerRow
                    boardGrid
                }

                VStack(spacing: 6) {
                    // Not "Dealer" — Honeycomb's opponent is a named AI difficulty
                    // (e.g. "Baby Bee"), not a card-game dealer role like Blackjack's.
                    handLabel(honeycombLocalizedDifficultyName(viewModel.options.difficulty, language: coordinator.language))
                    pyramidHand(cards: opponentDisplayHand, size: Self.playerCardSize) { i, card in
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
                }
                .zIndex(viewModel.swapAnimationPhase == .idle ? 0 : 100)
            }
            .padding(16)
        } else {
            VStack(spacing: 8) {
                rowHand(cards: opponentDisplayHand, size: Self.opponentCardSize) { i, card in
                    HoneycombFlipContainer(isRevealed: isOpponentCardRevealed[i]) {
                        HoneycombCardView(card: card, size: Self.opponentCardSize, isFlipped: true)
                    } back: {
                        opponentHandCard(card, size: Self.opponentCardSize)
                            .id(card.id)
                    }
                    .id(handIdentityToken)
                    .matchedGeometryEffect(id: card.id, in: animationSpace)
                    .modifier(SwapLiftEffect(isAnimating: viewModel.swapAnimationPhase != .idle && viewModel.swapHighlightCardIds.contains(card.id), phase: viewModel.swapAnimationPhase))
                }
                .zIndex(viewModel.swapAnimationPhase == .idle ? 0 : 100)

                bannerRow

                boardGrid
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
            HStack(spacing: Self.handSpacing) { ForEach(0..<min(2, cards.count), id: \.self) { i in content(i, cards[i]) } }
            if cards.count > 2 {
                HStack(spacing: Self.handSpacing) { ForEach(2..<min(4, cards.count), id: \.self) { i in content(i, cards[i]) } }
            }
            if cards.count > 4 {
                HStack(spacing: Self.handSpacing) { ForEach(4..<cards.count, id: \.self) { i in content(i, cards[i]) } }
            }
        }
        .frame(width: 2 * size.width + Self.handSpacing)
    }

    // MARK: Banner row (rules text + undo/hint in the free space beside it)

    private var bannerRow: some View {
        // Mirrors mac's HoneycombView dense-mode banner scaling: with 3+ active rules
        // (now reachable since Hard/UltraHard roulette scaling lives in shared/ and
        // already applies here), the joined rules string is long enough to clip against
        // this row's fixed 38pt height at the normal font size — shrink it instead of
        // letting it truncate. minimumScaleFactor is a safety net on top, not a
        // substitute, since it only shrinks as a last resort and can't be relied on
        // alone to keep 3-4 rule names legible within 2 lines.
        let isDense = rulesBannerLines.count > 2
        // Matches mac's HoneycombView rules banner treatment exactly: a "Rules:" title
        // over the rule name(s), yellow/.black weight, on a solid black.opacity(0.75)
        // rounded card — not bare text floating in the row. Sizes are smaller than
        // mac's literal 20-28pt titles/16-22pt lines since mac has a dedicated floating
        // box while this sits in a compact row alongside the hint/undo buttons.
        return HStack(spacing: 10) {
            hintButton
            VStack(spacing: isDense ? 1 : 2) {
                Text(coordinator.L(.rulesBannerTitle))
                    .font(.system(size: isDense ? 10 : 12, weight: .black))
                Text(rulesBannerLines.joined(separator: "  •  "))
                    .font(.system(size: isDense ? 13 : 16, weight: .black))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.yellow)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.75))
            .cornerRadius(16)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle()) // Make the whole area tappable
                .onTapGesture {
                    isShowingRulesTooltip = true
                }
                .popover(isPresented: $isShowingRulesTooltip, attachmentAnchor: .point(.bottom), arrowEdge: .bottom) {
                    let isPreGame = viewModel.gameState != .playing && viewModel.gameState != .suddenDeath
                    let isRoulette = isPreGame && !viewModel.options.forceNormalMode && viewModel.options.selectedRules.isEmpty
                    let effectiveRules: [HoneycombRule] = isPreGame && !isRoulette ? Array(viewModel.options.selectedRules) : viewModel.activeRules
                    RuleExplanationPopover(viewModel: viewModel, isRoulette: isRoulette, effectiveRules: effectiveRules)
                        .presentationCompactAdaptation(.popover)
                }
            undoButton
        }
        .frame(height: Self.bannerRowHeight)
        .padding(.horizontal, 4)
    }

    // Bumped to fit the boxed title+value rules banner above (was 46, a single text
    // line) — intrinsicSize(landscape:) below references this same constant rather
    // than a second hardcoded copy, so the two can't drift out of sync.
    private static let bannerRowHeight: CGFloat = 58

    @ViewBuilder
    private var hintButton: some View {
        // Hidden (not just disabled) when unavailable — small screens shouldn't spend
        // space on a button that can't do anything right now.
        if isMidMatch, !viewModel.options.hideHintButton, viewModel.options.difficulty != .ultraHard,
           viewModel.isPlayerTurn {
            roundButton(systemImage: "lightbulb") {
                if viewModel.hasHintsAvailable {
                    viewModel.findHint()
                } else {
                    flashNoHintsBanner()
                }
            }
            .accessibilityLabel(coordinator.L(.hint))
        } else {
            Color.clear.frame(width: 44, height: 44)
        }
    }

    @ViewBuilder
    private var undoButton: some View {
        if isMidMatch {
            roundButton(systemImage: "arrow.uturn.backward") {
                viewModel.undoLastAction()
            }
            .disabled(!viewModel.canUndo)
            .opacity(viewModel.canUndo ? 1 : 0.35)
            .accessibilityLabel(coordinator.L(.undo))
        } else {
            Color.clear.frame(width: 44, height: 44)
        }
    }

    private func roundButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.35), in: Circle())
        }
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

    private var boardGrid: some View {
        VStack(spacing: Self.boardSpacing) {
            ForEach(0..<3) { row in
                HStack(spacing: Self.boardSpacing) {
                    ForEach(0..<3) { col in
                        boardCell(index: row * 3 + col)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func boardCell(index: Int) -> some View {
        let cell = viewModel.board.cells[index]
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.2))
                .frame(width: Self.boardCardSize.width, height: Self.boardCardSize.height)

            if let card = cell.card {
                let stealEligible = isStealingCard && viewModel.isStealEligible(card)
                let highlightIndices: Set<Int> = viewModel.pointHighlight?.cardId == card.id
                    ? viewModel.pointHighlight!.statIndices
                    : []
                HoneycombCardView(card: card, size: Self.boardCardSize, isFlipped: false,
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
    private func playerHandCard(_ card: HoneycombCard) -> some View {
        let handIndex = viewModel.playerHand.firstIndex(where: { $0.id == card.id })
        let isMandated = viewModel.gameState == .playing
            && viewModel.mandatedPlayerHandIndex != nil
            && viewModel.mandatedPlayerHandIndex == handIndex
        let isLegalToPlay = viewModel.mandatedPlayerHandIndex == nil || viewModel.mandatedPlayerHandIndex == handIndex

        HoneycombCardView(card: card, size: Self.playerCardSize, isFlipped: false)
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
    private var dragGhost: some View {
        if let card = dragHandCard {
            HoneycombCardView(card: card, size: Self.playerCardSize, isFlipped: false)
                .position(x: dragLocation.x + dragOffset.width,
                          y: dragLocation.y + dragOffset.height - Self.playerCardSize.height * 0.25)
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
        guard !viewModel.options.manuallyDismissBanners else {
            ruleBannerTask = nil
            return
        }
        let task = DispatchWorkItem { [self] in dismissRuleBanner() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: task)
        ruleBannerTask = task
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

    // MARK: Post-game

    private var canStealCard: Bool {
        viewModel.matchOutcome == .win
            && !viewModel.options.noStressMode
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

                if viewModel.matchOutcome == .win && !viewModel.options.noStressMode {
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
                        Text(coordinator.L(.rematchToTakeAnother))
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
            .background(Color.black.opacity(0.8))
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

// MARK: - Settings section shown inside the slide-down menu

struct HoneycombSettingsSection: View {
    @Bindable var viewModel: HoneycombViewModel
    let isMidMatch: Bool
    // @Bindable, not @Environment — Sound/No Stress Mode/Honey Mode/Manually Dismiss
    // Banners bind directly to the coordinator (see AppCoordinator's "single source of
    // truth" fields) so a change here live-propagates to every other game via their
    // own didSet, instead of only updating this one game's local options copy.
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
            // Extra .padding(.bottom, 8) on this row and the two nav rows below it (on
            // top of the VStack's own spacing: 8) — Toggle's default style carries its
            // own built-in vertical padding that these plain HStack/Button rows don't
            // have, so matching Toggle's visual row-to-row gap needs more than the flat
            // 8 that's already correct between the toggles themselves.
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
            // Opponent — the other game-relevant setting, and should read together above
            // the general toggles (Sound, No Stress Mode, etc.).
            rulesNavRow
                .disabled(isMidMatch)
                .opacity(isMidMatch ? 0.5 : 1)
                .padding(.bottom, 8)

            Group {
                Toggle(coordinator.L(.soundShort), isOn: $coordinator.isSoundEnabled)
                Toggle(coordinator.L(.noStressMode), isOn: $coordinator.noStressMode)
                    .onChange(of: viewModel.options.noStressMode) { _, _ in viewModel.startNewGame() }
                Toggle(coordinator.L(.honeyMode), isOn: $coordinator.honeyMode)
                Toggle(coordinator.L(.hideHintButton), isOn: $viewModel.options.hideHintButton)
                Toggle(coordinator.L(.manuallyDismissBanners), isOn: $coordinator.manuallyDismissBanners)
            }
            // Options only take effect on the next match — same mid-match gate as mac.
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

    private var winRate: Double {
        let decisiveGames = stats.gamesPlayed - stats.matchesDrawn
        return decisiveGames > 0 ? Double(stats.matchesWon) / Double(decisiveGames) * 100 : 0
    }

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
                    Text(String(format: "%.1f%%", winRate)).foregroundStyle(.secondary)
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
