import SwiftUI
import UIKit

/// Touch-first Honeycomb board for iPhone/iPad. Reuses the shared HoneycombViewModel and
/// HoneycombCardView; layout is a fixed intrinsic design scaled to fit the screen (the
/// same fit-to-window approach the mac view uses, driven by GeometryReader instead of
/// NSWindow). Portrait stacks opponent hand / board / player hand vertically; landscape
/// mirrors the mac's hands-beside-board arrangement.
struct HoneycombTouchView: View {
    @Bindable var viewModel: HoneycombViewModel
    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator

    // MARK: Intrinsic layout constants (pre-scale units)

    private static let cardAspect: CGFloat = 181.0 / 128.0
    private static let boardCardSize = CGSize(width: 150, height: 150 * cardAspect)
    private static let playerCardSize = CGSize(width: 116, height: 116 * cardAspect)
    private static let opponentCardSize = CGSize(width: 96, height: 96 * cardAspect)
    private static let boardSpacing: CGFloat = 10
    private static let handSpacing: CGFloat = 6

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
    @State private var handFrames: [String: CGRect] = [:]
    @State private var dragHandCard: HoneycombCard? = nil
    @State private var dragStealBoardIndex: Int? = nil
    @State private var dragLocation: CGPoint = .zero
    @State private var dragOffset: CGSize = .zero

    @State private var selectedHandCardId: String? = nil
    @State private var isStealingCard = false
    @State private var stealBoardIndex: Int? = nil
    @State private var showRematchPrompt = false
    @State private var isMenuOpen = false
    @State private var showingStats = false
    @State private var showNoHintsBanner = false
    @State private var noHintsBannerTask: DispatchWorkItem? = nil
    @State private var showingRuleBanner = false
    @State private var ruleBannerText = ""
    @State private var ruleBannerTask: DispatchWorkItem? = nil

    private var isMidMatch: Bool {
        viewModel.gameState == .playing || viewModel.gameState == .suddenDeath
    }

    // MARK: Haptics — light tick on selection, solid thump on placement.

    private let selectionHaptic = UIImpactFeedbackGenerator(style: .light)
    private let placementHaptic = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        ZStack {
            coordinator.currentFeltColor.ignoresSafeArea()

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
                    .coordinateSpace(name: Self.dragSpace)
                    .scaleEffect(scale)
                    .frame(width: geo.size.width, height: geo.size.height)
                }
            }

            flashBanners

            if viewModel.showPostGamePrompt && !isStealingCard && !showingRuleBanner && !showRematchPrompt {
                postGameOverlay
            }

            if showRematchPrompt {
                rematchPrompt
            }

            SlideDownMenu(isOpen: $isMenuOpen, coordinator: coordinator) {
                showingStats = true
            } gameSettings: {
                HoneycombSettingsSection(viewModel: viewModel, isMidMatch: isMidMatch)
            }
        }
        .sheet(isPresented: $showingStats) { HoneycombStatsSheet(stats: viewModel.stats) }
        // Headless-testing hook: `simctl launch ... -honeycombAutostart 1` starts a match
        // immediately, so match-state rendering can be screenshotted without tap input.
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-honeycombAutostart"),
               viewModel.gameState == .setup {
                viewModel.startNewGame()
            }
        }
        .onChange(of: viewModel.flashRuleBannerTrigger) {
            guard let text = viewModel.flashRuleBanner else { return }
            flashRuleBanner(text)
        }
        .alert("Swap Not Allowed", isPresented: .init(
            get: { viewModel.swapValidationError != nil },
            set: { if !$0 { viewModel.swapValidationError = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.swapValidationError = nil }
        } message: {
            Text(viewModel.swapValidationError ?? "")
        }
        .alert("Take This Card?", isPresented: .init(
            get: { viewModel.pendingSwap != nil },
            set: { if !$0 { viewModel.cancelPendingSwap() } }
        )) {
            Button("Take \(viewModel.pendingSwap?.incomingCardName ?? "Card")") {
                viewModel.confirmPendingSwap()
                isStealingCard = false
                stealBoardIndex = nil
                showRematchPrompt = true
            }
            Button("Cancel", role: .cancel) { viewModel.cancelPendingSwap() }
        } message: {
            if let swap = viewModel.pendingSwap {
                Text("Trade \(swap.outgoingCardName) for \(swap.incomingCardName)?")
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
            .accessibilityLabel("Menu")
            // Options only take effect on the next match (same gating as mac).
            .disabled(isMidMatch && viewModel.showPostGamePrompt)

            Spacer()

            if viewModel.gameState != .setup {
                scoreBadge
            }

            Spacer()

            if isMidMatch {
                Button("Quit") { viewModel.gameState = .setup }
                    .buttonStyle(.bordered)
                    .tint(.white)
            } else {
                Button {
                    viewModel.startNewGame()
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var scoreBadge: some View {
        HStack(spacing: 10) {
            Text("YOU \(viewModel.board.playerScore + viewModel.playerHand.count)")
                .foregroundStyle(.cyan)
            Text("–").foregroundStyle(.white.opacity(0.6))
            Text("\(viewModel.board.opponentScore + viewModel.opponentHand.count) DEALER")
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
                    handLabel("YOU")
                    pyramidHand(cards: playerDisplayHand, size: Self.playerCardSize) { playerHandCard($0) }
                }
                VStack(spacing: 8) {
                    bannerRow
                    boardGrid
                }
                VStack(spacing: 6) {
                    handLabel("DEALER")
                    pyramidHand(cards: opponentDisplayHand, size: Self.playerCardSize) { opponentHandCard($0, size: Self.playerCardSize) }
                }
            }
            .padding(16)
        } else {
            VStack(spacing: 8) {
                rowHand(cards: opponentDisplayHand, size: Self.opponentCardSize) { opponentHandCard($0, size: Self.opponentCardSize) }
                bannerRow
                boardGrid
                    .padding(.vertical, 4)
                rowHand(cards: playerDisplayHand, size: Self.playerCardSize) { playerHandCard($0) }
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
                                        @ViewBuilder content: @escaping (HoneycombCard) -> Content) -> some View {
        HStack(spacing: Self.handSpacing) {
            ForEach(cards) { card in content(card) }
        }
        .frame(height: size.height)
    }

    private func pyramidHand<Content: View>(cards: [HoneycombCard], size: CGSize,
                                            @ViewBuilder content: @escaping (HoneycombCard) -> Content) -> some View {
        VStack(spacing: Self.handSpacing) {
            HStack(spacing: Self.handSpacing) { ForEach(cards.prefix(2)) { content($0) } }
            HStack(spacing: Self.handSpacing) { ForEach(Array(cards.dropFirst(2).prefix(2))) { content($0) } }
            HStack(spacing: Self.handSpacing) { ForEach(Array(cards.dropFirst(4))) { content($0) } }
        }
        .frame(width: 2 * size.width + Self.handSpacing)
    }

    // MARK: Banner row (rules text + undo/hint in the free space beside it)

    private var bannerRow: some View {
        HStack(spacing: 10) {
            hintButton
            Text(rulesBannerLines.joined(separator: "  •  "))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
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
            .accessibilityLabel("Hint")
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
            .accessibilityLabel("Undo")
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
            if viewModel.activeRules.isEmpty { return ["Normal"] }
            return viewModel.activeRules.map { rule in
                if rule == .ascension || rule == .descension, !viewModel.ascensionDescensionSuits.isEmpty {
                    let suitNames = viewModel.ascensionDescensionSuits.sorted()
                        .map { HoneycombCardData.suitDisplayName($0) }
                    return "\(rule.rawValue) Suit: \(suitNames.joined(separator: ", "))"
                }
                return rule.rawValue
            }
        }
        if viewModel.options.forceNormalMode { return ["Normal"] }
        if !viewModel.options.selectedRules.isEmpty {
            return HoneycombRule.allCases
                .filter { viewModel.options.selectedRules.contains($0) }
                .map(\.rawValue)
        }
        return ["Roulette"]
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
                let stealEligible = isStealingCard
                    && card.originalOwner == .opponent
                    && card.owner == .player
                    && !HoneycombProfileManager.shared.unlockedCardIds.contains(card.data.id)
                let highlightIndices: Set<Int> = viewModel.pointHighlight?.cardId == card.id
                    ? viewModel.pointHighlight!.statIndices
                    : []
                let stealDraggable = viewModel.showPostGamePrompt
                    && card.originalOwner == .opponent && card.owner == .player
                    && !HoneycombProfileManager.shared.unlockedCardIds.contains(card.data.id)
                HoneycombCardView(card: card, size: Self.boardCardSize, isFlipped: false,
                                  stealHighlight: stealEligible, highlightedStatIndices: highlightIndices)
                    .opacity(dragStealBoardIndex == index ? 0 : 1)
                    .gesture(stealDraggable ? stealDragGesture(index: index) : nil)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white, lineWidth: stealBoardIndex == index ? 4 : 0)
                    )
            }
        }
        .modifier(TouchHintHighlight(isHighlighted: viewModel.activeHint?.boardIndex == index))
        .onTapGesture { handleBoardTap(index: index, cell: cell) }
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
        } else if isStealingCard, viewModel.showPostGamePrompt, viewModel.gameState == .gameOver,
                  cell.card?.originalOwner == .opponent, cell.card?.owner == .player,
                  let cardId = cell.card?.data.id, !HoneycombProfileManager.shared.unlockedCardIds.contains(cardId) {
            stealBoardIndex = index
        }
    }

    // MARK: Hand cards

    @ViewBuilder
    private func playerHandCard(_ card: HoneycombCard) -> some View {
        if viewModel.gameState == .setup {
            HoneycombCardView(card: card, size: Self.playerCardSize, isFlipped: true)
        } else {
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
                    } else if isStealingCard, viewModel.showPostGamePrompt, viewModel.gameState == .gameOver,
                              let boardIdx = stealBoardIndex,
                              let replaceIdx = viewModel.playerStartingDeck.firstIndex(where: { $0.id == card.id }) {
                        viewModel.requestSwap(boardIndex: boardIdx, replaceHandIndex: replaceIdx)
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
                        .stroke(Color.yellow, lineWidth: isMandated ? 8 : 0)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.yellow, lineWidth: viewModel.swapHighlightCardIds.contains(card.id) ? 8 : 0)
                )
                .modifier(TouchHintHighlight(isHighlighted: handIndex != nil && viewModel.activeHint?.handIndex == handIndex))
                // Lift the selected card slightly so the two-tap flow reads clearly.
                .offset(y: selectedHandCardId == card.id ? -10 : 0)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: selectedHandCardId)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { handFrames[card.id] = geo.frame(in: .named(Self.dragSpace)) }
                            .onChange(of: geo.frame(in: .named(Self.dragSpace))) { _, newFrame in
                                handFrames[card.id] = newFrame
                            }
                    }
                )
        }
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

    private func stealDragGesture(index: Int) -> some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .named(Self.dragSpace))
            .onChanged { val in
                if dragStealBoardIndex == nil {
                    dragStealBoardIndex = index
                    dragLocation = val.startLocation
                    selectionHaptic.impactOccurred()
                }
                dragOffset = val.translation
            }
            .onEnded { _ in
                defer { clearDrag() }
                guard let boardIdx = dragStealBoardIndex,
                      viewModel.showPostGamePrompt, viewModel.gameState == .gameOver else { return }
                let release = CGPoint(x: dragLocation.x + dragOffset.width,
                                      y: dragLocation.y + dragOffset.height)
                guard let (cardId, _) = handFrames.first(where: { $0.value.insetBy(dx: -10, dy: -10).contains(release) }),
                      let replaceIdx = viewModel.playerStartingDeck.firstIndex(where: { $0.id == cardId }) else { return }
                viewModel.requestSwap(boardIndex: boardIdx, replaceHandIndex: replaceIdx)
                placementHaptic.impactOccurred()
            }
    }

    private func dropCellIndex() -> Int? {
        let release = CGPoint(x: dragLocation.x + dragOffset.width,
                              y: dragLocation.y + dragOffset.height)
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
        dragStealBoardIndex = nil
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
        } else if let index = dragStealBoardIndex, let card = viewModel.board.cells[index].card {
            HoneycombCardView(card: card, size: Self.boardCardSize, isFlipped: false)
                .position(x: dragLocation.x + dragOffset.width,
                          y: dragLocation.y + dragOffset.height - Self.boardCardSize.height * 0.25)
                .shadow(radius: 10, y: 5)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func opponentHandCard(_ card: HoneycombCard, size: CGSize) -> some View {
        if viewModel.gameState == .setup {
            HoneycombCardView(card: card, size: size, isFlipped: true)
        } else {
            let isPostWinReveal = viewModel.gameState == .gameOver && viewModel.showPostGamePrompt && viewModel.matchResult == "You Win!"
            let flipped = !isPostWinReveal && !viewModel.isOpponentCardVisible(cardId: card.id)
            let handIndex = viewModel.opponentHand.firstIndex(where: { $0.id == card.id })
            let isMandated = viewModel.gameState == .playing
                && !viewModel.isPlayerTurn
                && viewModel.mandatedOpponentHandIndex != nil
                && viewModel.mandatedOpponentHandIndex == handIndex

            HoneycombCardView(card: card, size: size, isFlipped: flipped)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.yellow, lineWidth: isMandated ? 8 : 0)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.yellow, lineWidth: viewModel.swapHighlightCardIds.contains(card.id) ? 8 : 0)
                )
        }
    }

    // MARK: Flash banners

    private var flashBanners: some View {
        VStack {
            if showingRuleBanner {
                bannerCapsule(ruleBannerText, color: .yellow)
            }
            if showNoHintsBanner {
                bannerCapsule("No hints for this one!", color: .orange)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 60)
        .allowsHitTesting(false)
    }

    private func bannerCapsule(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.title3.weight(.black))
            .foregroundStyle(color)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.black.opacity(0.75), in: Capsule())
            .transition(.scale.combined(with: .opacity))
    }

    private func flashRuleBanner(_ text: String) {
        ruleBannerTask?.cancel()
        ruleBannerText = text
        withAnimation(.easeIn(duration: 0.15)) { showingRuleBanner = true }
        let task = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.3)) { showingRuleBanner = false }
        }
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
        viewModel.matchResult == "You Win!"
            && !viewModel.options.noStressMode
            && !viewModel.hasStolenThisMatch
            && !HoneycombProfileManager.shared.isCardBankFull
    }

    private var postGameOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 16) {
                if viewModel.matchResult == "You Lose" {
                    Text("Not today, partner!")
                        .font(.system(size: 30, weight: .black))
                        .foregroundColor(.yellow)
                } else {
                    Text(viewModel.matchResult)
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(viewModel.matchResult == "You Win!" ? .yellow : .white)
                }

                if viewModel.matchResult == "You Win!" && !viewModel.options.noStressMode {
                    if HoneycombProfileManager.shared.isCardBankFull {
                        Text("Your card bank is full. Start over in manage decks to steal again.")
                            .font(.footnote).foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    } else if viewModel.hasStolenThisMatch {
                        Text("You've already taken a card this match. Rematch to take another.")
                            .font(.footnote).foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                }

                VStack(spacing: 10) {
                    if canStealCard {
                        Button {
                            isStealingCard = true
                        } label: {
                            Label("Take a Card", systemImage: "hand.point.up.left")
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
                            Label("Rematch", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Button {
                        viewModel.startNewGame()
                    } label: {
                        Label("New Match", systemImage: "play.fill")
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
                .accessibilityLabel("Dismiss")
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var rematchPrompt: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Card taken!")
                    .font(.title.bold())
                    .foregroundStyle(.yellow)
                Button {
                    showRematchPrompt = false
                    viewModel.rematch()
                } label: {
                    Label("Rematch", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button {
                    showRematchPrompt = false
                    viewModel.startNewGame()
                } label: {
                    Label("New Match", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.white)
            }
            .frame(maxWidth: 260)
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }
}

// MARK: - Settings section shown inside the slide-down menu

struct HoneycombSettingsSection: View {
    @Bindable var viewModel: HoneycombViewModel
    let isMidMatch: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HONEYCOMB")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Group {
                Toggle("Sound", isOn: $viewModel.options.isSoundEnabled)
                Toggle("No Stress Mode", isOn: $viewModel.options.noStressMode)
                Toggle("Point Highlights", isOn: $viewModel.options.showPointHighlights)
                Toggle("Hide Hint Button", isOn: $viewModel.options.hideHintButton)

                Picker("Difficulty", selection: $viewModel.options.difficulty) {
                    ForEach(HoneycombDifficulty.allCases, id: \.self) { d in
                        Text(d.displayName).tag(d)
                    }
                }
                .pickerStyle(.menu)

                Toggle("Force Normal Rules", isOn: $viewModel.options.forceNormalMode)

                DisclosureGroup("Match Rules") {
                    ForEach(HoneycombRule.allCases, id: \.self) { rule in
                        Toggle(rule.rawValue, isOn: .init(
                            get: { viewModel.options.selectedRules.contains(rule) },
                            set: { on in
                                if on { viewModel.options.selectedRules.insert(rule) }
                                else { viewModel.options.selectedRules.remove(rule) }
                            }
                        ))
                    }
                }
            }
            // Options only take effect on the next match — same mid-match gate as mac.
            .disabled(isMidMatch)
            .opacity(isMidMatch ? 0.5 : 1)

            if isMidMatch {
                Text("Settings unlock when the match ends.")
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

    var body: some View {
        NavigationStack {
            List {
                statRow("Matches Played", stats.gamesPlayed)
                statRow("Matches Won", stats.matchesWon)
                statRow("Matches Lost", stats.matchesLost)
                statRow("Matches Drawn", stats.matchesDrawn)
                statRow("Cards Captured", stats.cardsCaptured)
                statRow("Cards Stolen", stats.cardsStolen)
                statRow("Current Win Streak", stats.currentWinStreak)
                statRow("Longest Win Streak", stats.longestWinStreak)
                statRow("Flawless Victories", stats.flawlessVictories)
                statRow("Same/Plus Triggers", stats.samePlusTriggers)
                Section("Wins by Difficulty") {
                    statRow("Baby Bee", stats.easyWins)
                    statRow("Honey Bee", stats.mediumWins)
                    statRow("Queen Bee", stats.hardWins)
                    statRow("Killer Bee", stats.ultraHardWins)
                }
            }
            .navigationTitle("Honeycomb Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
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
