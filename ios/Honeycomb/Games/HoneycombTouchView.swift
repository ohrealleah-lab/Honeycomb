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
    // ForEach identity stays stable across re-renders.
    private static let placeholderHand: [HoneycombCard] = (0..<5).map { i in
        HoneycombCard(
            data: HoneycombCardData(id: -1, name: "", stars: 1, stats: [1, 1, 1, 1], suit: "S"),
            owner: .player,
            id: "placeholder-\(i)"
        )
    }

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
            IOSBackgroundLayer()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 12)
                    .frame(height: 44)

                GeometryReader { geo in
                    let isLandscape = geo.size.width > geo.size.height
                    let intrinsic = intrinsicSize(landscape: isLandscape)
                    let scale = min(2.0, max(0.2, min(geo.size.width / intrinsic.width,
                                                      geo.size.height / intrinsic.height)))

                    ZStack(alignment: .topLeading) {
                        gameContent(landscape: isLandscape)
                        dragGhost
                    }
                    .frame(width: intrinsic.width, height: intrinsic.height)
                    // Anchors dragSpace — every cellFrames GeometryReader and DragGesture
                    // .named(Self.dragSpace) reference (see dropCellIndex() below) depends
                    // on this exact container. Moving this modifier elsewhere, or applying
                    // it after .scaleEffect, breaks drop hit-testing silently.
                    .coordinateSpace(name: Self.dragSpace)
                    .scaleEffect(scale)
                    .frame(width: geo.size.width, height: geo.size.height)
                }
            }

            flashBanners

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

            SlideDownMenu(isOpen: $isMenuOpen, coordinator: coordinator) {
                showingStats = true
            } gameSettings: {
                HoneycombSettingsSection(viewModel: viewModel, isMidMatch: isMidMatch) {
                    isMenuOpen = false
                    showingDecks = true
                }
            }
        }
        .sheet(isPresented: $showingDecks) { HoneycombDecksSheet(viewModel: viewModel) }
        .environment(\.activeCardBackTheme, coordinator.cardBackTheme)
        .environment(\.activeCustomCardColors, coordinator.customCardColors)
        .sheet(isPresented: $showingStats) { HoneycombStatsSheet(stats: viewModel.stats) }
        // Headless-testing hook: `simctl launch ... -honeycombAutostart 1` starts a match
        // immediately, so match-state rendering can be screenshotted without tap input.
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-honeycombAutostart"),
               viewModel.gameState == .setup {
                viewModel.startNewGame()
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
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                isMenuOpen = true
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(coordinator.L(.menuHeaderTitle))

            Spacer()

            if viewModel.gameState != .setup {
                scoreBadge
            }

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
    }

    private var scoreBadge: some View {
        HStack(spacing: 10) {
            Text(coordinator.L(.scoreYouFmt, viewModel.board.playerScore + viewModel.playerHand.count))
                .foregroundStyle(.cyan)
            Text("–").foregroundStyle(.white.opacity(0.6))
            Text(coordinator.L(.scoreDealerFmt, viewModel.board.opponentScore + viewModel.opponentHand.count))
                .foregroundStyle(.pink)
        }
        .font(.subheadline.weight(.bold))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.black.opacity(0.35), in: Capsule())
    }

    // MARK: Scaled game content

    private func intrinsicSize(landscape: Bool) -> CGSize {
        if landscape {
            let handColumnWidth = 2 * Self.playerCardSize.width + Self.handSpacing
            let boardWidth = 3 * Self.boardCardSize.width + 2 * Self.boardSpacing
            let width = handColumnWidth * 2 + boardWidth + 2 * 24 + 32
            let boardHeight = 3 * Self.boardCardSize.height + 2 * Self.boardSpacing
            return CGSize(width: width, height: boardHeight + 46 + 24)
        } else {
            let width = 5 * Self.playerCardSize.width + 4 * Self.handSpacing + 16
            let height = Self.opponentCardSize.height + 8
                + 38 + 8
                + 3 * Self.boardCardSize.height + 2 * Self.boardSpacing
                + 12 + Self.playerCardSize.height + 16
            return CGSize(width: width, height: height)
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
                    handLabel(coordinator.L(.dealerLabel))
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
        viewModel.gameState == .setup ? Self.placeholderHand
            : (viewModel.gameState == .gameOver ? viewModel.playerStartingDeck : viewModel.playerHand)
    }

    private var opponentDisplayHand: [HoneycombCard] {
        viewModel.gameState == .setup ? Self.placeholderHand : viewModel.opponentHand
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
        return HStack(spacing: 10) {
            hintButton
            Text(rulesBannerLines.joined(separator: "  •  "))
                .font((isDense ? Font.caption2 : Font.footnote).weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)
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
        .frame(height: 38)
        .padding(.horizontal, 4)
    }

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

    // MARK: Flash banners

    private var flashBanners: some View {
        VStack {
            if showingRuleBanner {
                bannerCapsule(ruleBannerText, color: .yellow, onDismiss: dismissRuleBanner)
            }
            if showNoHintsBanner {
                bannerCapsule(coordinator.L(.noHintsBanner), color: .orange)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 60)
        .allowsHitTesting(showingRuleBanner)
    }

    // Always clickable to dismiss when a dismiss handler is provided — not gated on the
    // "Manually Dismiss Banners" option's *current* value, so a banner shown while the
    // option was on can never get stuck if the player turns it off before it closes
    // (nothing else would ever dismiss it, since no auto-dismiss timer was scheduled).
    private func bannerCapsule(_ text: String, color: Color, onDismiss: (() -> Void)? = nil) -> some View {
        Text(text)
            .font(.title3.weight(.black))
            .foregroundStyle(color)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.black.opacity(0.75), in: Capsule())
            .transition(.scale.combined(with: .opacity))
            .onTapGesture { onDismiss?() }
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
                        .foregroundColor(viewModel.matchOutcome == .win ? .yellow : .white)
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
                    } else if viewModel.stealProtectionActive {
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
                            Label(coordinator.L(.takeACardButton), systemImage: "hand.point.up.left")
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
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            // Dismiss lives on the overlay card itself (not the screen corner) so it
            // never stacks on top of the top bar's Start/Quit button.
            .overlay(alignment: .topTrailing) {
                Button {
                    viewModel.showPostGamePrompt = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
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
    var onManageDecks: () -> Void
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(coordinator.L(.settingsHeader))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Button(action: onManageDecks) {
                Label(coordinator.L(.manageDecks), systemImage: "square.grid.2x2")
            }
            .buttonStyle(.bordered)
            .disabled(isMidMatch)

            Group {
                Toggle(coordinator.L(.soundShort), isOn: $viewModel.options.isSoundEnabled)
                Toggle(coordinator.L(.noStressMode), isOn: $viewModel.options.noStressMode)
                    .onChange(of: viewModel.options.noStressMode) { _, _ in viewModel.startNewGame() }
                Toggle(coordinator.L(.honeyMode), isOn: $viewModel.options.honeyMode)
                Toggle(coordinator.L(.hideHintButton), isOn: $viewModel.options.hideHintButton)
                Toggle(coordinator.L(.manuallyDismissBanners), isOn: $viewModel.options.manuallyDismissBanners)

                Picker(coordinator.L(.opponentPickerLabel), selection: $viewModel.options.difficulty) {
                    ForEach(HoneycombDifficulty.allCases, id: \.self) { d in
                        Text(honeycombLocalizedDifficultyName(d, language: coordinator.language)).tag(d)
                    }
                }
                .pickerStyle(.menu)

                Toggle(coordinator.L(.forceNormalRulesToggle), isOn: $viewModel.options.forceNormalMode)

                DisclosureGroup(coordinator.L(.matchRulesDisclosure)) {
                    Text(coordinator.L(.matchRulesHint))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(HoneycombRule.allCases.filter { $0 != .reverse }, id: \.self) { rule in
                        Toggle(honeycombLocalizedRuleName(rule.rawValue, language: coordinator.language), isOn: .init(
                            get: { viewModel.options.selectedRules.contains(rule) },
                            set: { on in
                                if on {
                                    // Remove the exclusive partner (if any) BEFORE the cap
                                    // check — selecting a rule whose partner is already
                                    // selected is a net-zero swap, not an addition, so it
                                    // must never be blocked just because the cap is full.
                                    var updated = viewModel.options.selectedRules
                                    if rule == .ascension { updated.remove(.descension) }
                                    if rule == .descension { updated.remove(.ascension) }
                                    if rule == .order { updated.remove(.chaos) }
                                    if rule == .chaos { updated.remove(.order) }
                                    if rule == .allOpen { updated.remove(.threeOpen) }
                                    if rule == .threeOpen { updated.remove(.allOpen) }
                                    // Bomb Shelter's hidden card doesn't work when All
                                    // Open/Three Open reveals every card anyway.
                                    if rule == .allOpen || rule == .threeOpen { updated.remove(.bombShelter) }
                                    if rule == .bombShelter { updated.remove(.allOpen); updated.remove(.threeOpen) }

                                    guard updated.count < 4 else { return }
                                    updated.insert(rule)
                                    viewModel.options.selectedRules = updated
                                } else {
                                    viewModel.options.selectedRules.remove(rule)
                                }
                            }
                        ))
                    }
                }

                DisclosureGroup(coordinator.L(.banListDisclosure)) {
                    let allBanItems = ["Normal Mode"] + HoneycombRule.allCases.map { $0.rawValue }
                    ForEach(allBanItems, id: \.self) { ruleName in
                        Toggle(honeycombLocalizedRuleName(ruleName, language: coordinator.language), isOn: .init(
                            get: { viewModel.options.bannedRules.contains(ruleName) },
                            set: { on in
                                if on {
                                    // "Silly bee" guard — mirrors mac: never allow every
                                    // item (including Normal Mode) to be banned at once,
                                    // since roulette would have nothing left to pick.
                                    if viewModel.options.bannedRules.count < allBanItems.count - 1 {
                                        viewModel.options.bannedRules.insert(ruleName)
                                    }
                                } else {
                                    viewModel.options.bannedRules.remove(ruleName)
                                }
                            }
                        ))
                    }
                    if viewModel.options.bannedRules.count == allBanItems.count - 1 {
                        Text(coordinator.L(.sillyBeeWarning))
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
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
                statRow(coordinator.L(.statCardsCaptured), stats.cardsCaptured)
                statRow(coordinator.L(.statCardsStolen), stats.cardsStolen)
                statRow(coordinator.L(.statCurrentWinStreak), stats.currentWinStreak)
                statRow(coordinator.L(.statLongestWinStreak), stats.longestWinStreak)
                statRow(coordinator.L(.statFlawlessVictoriesIos), stats.flawlessVictories)
                statRow(coordinator.L(.statSamePlusTriggers), stats.samePlusTriggers)
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
