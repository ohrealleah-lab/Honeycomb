import SwiftUI
import UIKit

/// Touch-first Klondike board for iPhone/iPad, driven by the shared GameViewModel.
/// Interactions mirror the mac GameView: tap the stock to draw, drag cards/sequences
/// with smart-drop resolution (SmartDrop + pile-frame hit testing, ported from the mac
/// view), and double-tap a card to send it to a foundation. Undo/hint live in the empty
/// grid slot between the waste and the foundations.
struct KlondikeTouchView: View {
    @Bindable var viewModel: GameViewModel
    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator
    @Environment(\.scenePhase) private var scenePhase

    private static let boardSpace = "klondikeBoard"
    private static let columnSpacing: CGFloat = 6

    // MARK: Drag state (same shape as the mac view's)

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
    @State private var isDrawInFlight = false
    @State private var showNoHintsBanner = false
    @State private var noHintsBannerTask: DispatchWorkItem? = nil

    private let placementHaptic = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        GeometryReader { geo in
            // Width-fit first (unchanged from the original, always exactly fills the
            // available width, spacing/padding included). Then, if the deepest tableau
            // column at that size would run past the available height — landscape's
            // extra width alone doesn't buy any extra height, and there's no scroll view
            // here — shrink further so nothing overflows. Never grows past the width fit.
            let widthCardW = min((geo.size.width - 16 - 6 * Self.columnSpacing) / 7, 110)
            let widthCardH = widthCardW * CardDimensions.aspectRatio
            let neededHeight = 54 + widthCardH + 10 + deepestColumnHeight(cardH: widthCardH) + 20
            let heightShrink = neededHeight > geo.size.height ? geo.size.height / neededHeight : 1.0
            let cardW = widthCardW * heightShrink
            let cardH = cardW * CardDimensions.aspectRatio

            ZStack {
                IOSBackgroundLayer()

                VStack(spacing: 10) {
                    topBar
                        .padding(.horizontal, 12)
                        .frame(height: 44)

                    topRow(cardW: cardW, cardH: cardH)
                        .padding(.horizontal, 8)

                    tableauRow(cardW: cardW, cardH: cardH)
                        .padding(.horizontal, 8)

                    Spacer(minLength: 0)
                }

                dragOverlay(cardW: cardW, cardH: cardH)

                if viewModel.isAutocompleteAvailable && !viewModel.state.hasWon {
                    autocompleteButton
                }

                if viewModel.state.hasWon {
                    winOverlay
                }

                if viewModel.isStuck && !viewModel.state.hasWon && !dismissedStuckBanner {
                    stuckOverlay
                }

                if showNoHintsBanner {
                    noHintsBanner
                }

                SlideDownMenu(isOpen: $isMenuOpen, coordinator: coordinator)
            }
            // Anchors boardSpace — every pileFrames GeometryReader and DragGesture
            // .named(Self.boardSpace) reference below depends on this exact container.
            // Moving this modifier to a different view breaks drop hit-testing silently.
            .coordinateSpace(name: Self.boardSpace)
        }
        .environment(\.feltColor, coordinator.feltColor)
        .environment(\.activeCardBackTheme, coordinator.cardBackTheme)
        .environment(\.activeCustomCardColors, coordinator.customCardColors)
        .sheet(isPresented: $showingStats) { KlondikeStatsSheet(stats: viewModel.statistics) }
        .sheet(isPresented: $showingThemes) { ThemesFullScreenView(coordinator: coordinator) }
        .sheet(isPresented: $showingOptions) {
            OptionsFullScreenView(coordinator: coordinator, onShowStats: { showingStats = true }) {
                KlondikeSettingsSection(viewModel: viewModel)
            }
        }
        .onAppear { viewModel.startTimerIfNeeded() }
        .onChange(of: viewModel.state.hasWon) { dismissedStuckBanner = false }
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
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            menuBarButtons(isMenuOpen: $isMenuOpen, showingOptions: $showingOptions, showingThemes: $showingThemes, coordinator: coordinator)

            Spacer()

            statusCapsule

            Spacer()

            Button {
                dismissedStuckBanner = false
                viewModel.startNewGame()
            } label: {
                Label(coordinator.L(.touchNewDealLabel), systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var statusCapsule: some View {
        HStack(spacing: 10) {
            Text(viewModel.options.isVegasScoring ? viewModel.vegasBankrollString : viewModel.scoreString)
                .foregroundStyle(.yellow)
            if viewModel.options.isTimed && !viewModel.options.noStressMode {
                Text(formatTime(viewModel.state.timerSeconds))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .font(.subheadline.weight(.bold).monospacedDigit())
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.black.opacity(0.35), in: Capsule())
    }

    // MARK: Top row: stock, waste, undo/hint slot, foundations

    private func topRow(cardW: CGFloat, cardH: CGFloat) -> some View {
        HStack(alignment: .top, spacing: Self.columnSpacing) {
            stockView(cardW: cardW, cardH: cardH)

            wasteView(cardW: cardW, cardH: cardH)

            // The empty grid slot between waste and foundations — undo and hint live
            // here, per the agreed mobile layout, centered in the gap between the
            // stock/waste pair and the foundations.
            VStack(spacing: 6) {
                controlCircle(systemImage: "arrow.uturn.backward", label: coordinator.L(.undo),
                              diameter: min(40, cardW * 0.8)) {
                    viewModel.undoLastAction()
                }
                .disabled(!viewModel.canUndo)
                .opacity(viewModel.canUndo ? 1 : 0.35)

                if !viewModel.options.hideHintButton {
                    controlCircle(systemImage: "lightbulb", label: coordinator.L(.hint),
                                  diameter: min(40, cardW * 0.8)) {
                        if !viewModel.findHint() {
                            flashNoHintsBanner()
                        }
                    }
                }
            }
            .frame(width: cardW, height: cardH, alignment: .center)
            .zIndex(3)

            ForEach(viewModel.state.foundations) { pile in
                foundationView(pile: pile, cardW: cardW, cardH: cardH)
            }
        }
    }

    private func stockView(cardW: CGFloat, cardH: CGFloat) -> some View {
        ZStack {
            emptySlot(cardW: cardW, cardH: cardH,
                      symbol: viewModel.canRecycleStock ? "arrow.2.circlepath" : nil)
            if let top = viewModel.state.stock.cards.last {
                TouchCardView(card: Card(suit: top.suit, rank: top.rank, faceUp: false), width: cardW)
            }
            if viewModel.isStockExhausted {
                Text(coordinator.L(.done))
                    .font(.system(size: cardW * 0.18, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: cardW, height: cardH)
        .contentShape(Rectangle())
        .modifier(TouchHintHighlight(isHighlighted: viewModel.activeHint?.sourcePileId == viewModel.state.stock.id))
        .onTapGesture { performStockDraw() }
        .background(frameTracker(id: viewModel.state.stock.id))
    }

    private func wasteView(cardW: CGFloat, cardH: CGFloat) -> some View {
        let fanCount = max(1, min(viewModel.state.wasteDisplayCount, 3))
        let visible = Array(viewModel.state.waste.cards.suffix(fanCount))
        // Tight sliver fan — just enough to read the buried ranks without spilling into
        // the undo/hint slot next door.
        let fanStep = cardW * 0.16

        return ZStack(alignment: .topLeading) {
            emptySlot(cardW: cardW, cardH: cardH, symbol: nil)
            ForEach(Array(visible.enumerated()), id: \.element.id) { i, card in
                let isTop = i == visible.count - 1
                TouchCardView(card: card, width: cardW)
                    .offset(x: CGFloat(i) * fanStep)
                    .opacity(draggedCards.contains(where: { $0.id == card.id }) ? 0 : 1)
                    .gesture(isTop ? cardDragGesture(pile: viewModel.state.waste, stack: [card]) : nil)
                    .onTapGesture(count: 2) {
                        if isTop { viewModel.doubleClickMoveToFoundation(card: card, from: viewModel.state.waste) }
                    }
            }
        }
        .frame(width: cardW, height: cardH, alignment: .topLeading)
        .modifier(TouchHintHighlight(isHighlighted: hintTouches(viewModel.state.waste.id)))
        .background(frameTracker(id: viewModel.state.waste.id))
        .zIndex(2)
    }

    private func foundationView(pile: Pile, cardW: CGFloat, cardH: CGFloat) -> some View {
        return ZStack {
            emptySlot(cardW: cardW, cardH: cardH, letterSymbol: "A")
            if let top = pile.cards.last {
                TouchCardView(card: top, width: cardW)
                    .opacity(draggedCards.contains(where: { $0.id == top.id }) ? 0 : 1)
                    .gesture(cardDragGesture(pile: pile, stack: [top]))
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
    /// the same per-card offsets tableauColumn uses to render, so the fit-to-screen
    /// scale computed from this always matches what's actually drawn.
    private func deepestColumnHeight(cardH: CGFloat) -> CGFloat {
        let upStep = cardH * 0.24
        let downStep = cardH * 0.12
        return viewModel.state.tableau.map { pile -> CGFloat in
            guard !pile.cards.isEmpty else { return cardH }
            var running: CGFloat = 0
            for card in pile.cards.dropLast() {
                running += card.faceUp ? upStep : downStep
            }
            return running + cardH
        }.max() ?? cardH
    }

    private func tableauColumn(pile: Pile, cardW: CGFloat, cardH: CGFloat) -> some View {
        let upStep = cardH * 0.24
        let downStep = cardH * 0.12

        var offsets: [CGFloat] = []
        var running: CGFloat = 0
        for card in pile.cards {
            offsets.append(running)
            running += card.faceUp ? upStep : downStep
        }
        let columnHeight = (pile.cards.isEmpty ? cardH : (offsets.last ?? 0) + cardH)

        return ZStack(alignment: .top) {
            emptySlot(cardW: cardW, cardH: cardH, symbol: nil)
            ForEach(Array(pile.cards.enumerated()), id: \.element.id) { i, card in
                TouchCardView(card: card, width: cardW)
                    .offset(y: offsets[i])
                    .opacity(draggedCards.contains(where: { $0.id == card.id }) ? 0 : 1)
                    .modifier(TouchHintHighlight(isHighlighted: hintTouches(pile.id) && viewModel.activeHint?.card.id == card.id))
                    .onTapGesture(count: 2) {
                        viewModel.doubleClickMoveToFoundation(card: card, from: pile)
                    }
                    .gesture(card.faceUp ? cardDragGesture(pile: pile, stack: Array(pile.cards[i...])) : nil)
            }
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
                // Matches mac/iOS's EmptyPileView(symbol: "A", ...) — an empty foundation
                // shows the rank it's waiting for (an Ace), not a suit icon, since a
                // foundation isn't suit-locked until its first card lands.
                Text(letterSymbol)
                    .font(.system(size: cardW * 0.35, weight: .bold))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .frame(width: cardW, height: cardH)
    }

    private func controlCircle(systemImage: String, label: String, diameter: CGFloat = 40,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: diameter * 0.42, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: diameter, height: diameter)
                .background(.black.opacity(0.35), in: Circle())
        }
        .accessibilityLabel(label)
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

    // MARK: Drag handling (ported from the mac GameView)

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

        var dropTarget: Pile? = nil

        func accepts(_ pile: Pile) -> Bool {
            SmartDrop.resolve(cards: draggedCards, isValidMove: { viewModel.isValidMove(cards: $0, to: pile) }) != nil
        }

        // 1. Tableau piles: horizontal alignment with open vertical bottoms, preferring
        // columns that actually accept the cards.
        struct CandidateTableau {
            let pile: Pile
            let accepts: Bool
            let distanceX: CGFloat
        }
        var tableauCandidates: [CandidateTableau] = []
        for tab in viewModel.state.tableau {
            if let frame = pileFrames[tab.id] {
                let margin: CGFloat = 16
                let inX = releaseLocation.x >= frame.minX - margin && releaseLocation.x <= frame.maxX + margin
                let inY = releaseLocation.y >= frame.minY - margin
                if inX && inY {
                    tableauCandidates.append(CandidateTableau(
                        pile: tab, accepts: accepts(tab),
                        distanceX: abs(releaseLocation.x - frame.midX)))
                }
            }
        }
        if let best = tableauCandidates.sorted(by: { c1, c2 in
            if c1.accepts != c2.accepts { return c1.accepts && !c2.accepts }
            return c1.distanceX < c2.distanceX
        }).first, best.accepts {
            dropTarget = best.pile
        }

        // 2. Foundations if no tableau matched.
        if dropTarget == nil {
            struct CandidateTop {
                let pile: Pile
                let accepts: Bool
                let distance: CGFloat
            }
            var topCandidates: [CandidateTop] = []
            for foundation in viewModel.state.foundations {
                if let frame = pileFrames[foundation.id] {
                    let margin: CGFloat = 16
                    let inX = releaseLocation.x >= frame.minX - margin && releaseLocation.x <= frame.maxX + margin
                    let inY = releaseLocation.y >= frame.minY - margin && releaseLocation.y <= frame.maxY + margin
                    if inX && inY {
                        let dx = releaseLocation.x - frame.midX
                        let dy = releaseLocation.y - frame.midY
                        topCandidates.append(CandidateTop(
                            pile: foundation, accepts: accepts(foundation),
                            distance: (dx * dx + dy * dy).squareRoot()))
                    }
                }
            }
            if let best = topCandidates.sorted(by: { c1, c2 in
                if c1.accepts != c2.accepts { return c1.accepts && !c2.accepts }
                return c1.distance < c2.distance
            }).first, best.accepts {
                dropTarget = best.pile
            }
        }

        if let target = dropTarget, let source = dragSourcePile,
           let resolved = SmartDrop.resolve(cards: draggedCards, isValidMove: { viewModel.isValidMove(cards: $0, to: target) }) {
            viewModel.clearHint()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                viewModel.moveCards(resolved, from: source, to: target)
            }
            placementHaptic.impactOccurred()
        }

        viewModel.clearHint()
        cancelDrag()
    }

    private func performStockDraw() {
        if viewModel.state.hasWon { return }
        if viewModel.state.stock.isEmpty && !viewModel.canRecycleStock { return }
        guard !isDrawInFlight else { return }
        viewModel.clearHint()
        isDrawInFlight = true
        withAnimation(.easeInOut(duration: 0.22)) {
            viewModel.drawCard()
        }
        placementHaptic.impactOccurred(intensity: 0.7)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            isDrawInFlight = false
        }
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    // MARK: Overlays

    private var autocompleteButton: some View {
        VStack {
            Spacer()
            Button {
                viewModel.runAutocomplete()
            } label: {
                Label(coordinator.L(.helpShortcutAutocomplete), systemImage: "wand.and.stars")
                    .font(.headline)
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.yellow)
            .foregroundStyle(.black)
            .padding(.bottom, 24)
        }
    }

    private var winSummaryText: String {
        let scorePart = viewModel.options.isVegasScoring
            ? coordinator.L(.bankrollFmt, viewModel.vegasBankrollString)
            : coordinator.L(.scoreFmt, viewModel.scoreString)
        guard !viewModel.options.noStressMode else { return scorePart }
        return coordinator.L(.winSummaryWithTimeFmt, scorePart, formatTime(viewModel.state.timerSeconds))
    }

    private var winOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 16) {
                Text(coordinator.L(.youWin))
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.yellow)
                Text(winSummaryText)
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
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
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
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 60)
        .allowsHitTesting(false)
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
                    viewModel.undoLastAction()
                } label: {
                    Label(coordinator.L(.touchUndoLastMoveLabel), systemImage: "arrow.uturn.backward")
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
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(alignment: .topTrailing) {
                Button {
                    dismissedStuckBanner = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
            }
        }
    }
}

// MARK: - Settings section shown inside the slide-down menu

struct KlondikeSettingsSection: View {
    @Bindable var viewModel: GameViewModel
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(coordinator.L(.touchKlondikeBanner))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Picker(coordinator.L(.drawModeLabel), selection: $viewModel.options.drawMode) {
                Text(coordinator.L(.drawOne)).tag(GameState.DrawMode.drawOne)
                Text(coordinator.L(.drawThree)).tag(GameState.DrawMode.drawThree)
            }
            .pickerStyle(.segmented)

            Toggle(coordinator.L(.vegasScoring), isOn: $viewModel.options.isVegasScoring)
            Toggle(coordinator.L(.timed), isOn: $viewModel.options.isTimed)
            Toggle(coordinator.L(.soundShort), isOn: $viewModel.options.isSoundEnabled)
            Toggle(coordinator.L(.noStressMode), isOn: $viewModel.options.noStressMode)
                .onChange(of: viewModel.options.noStressMode) { _, _ in viewModel.startNewGame() }
            Toggle(coordinator.L(.hideHintButton), isOn: $viewModel.options.hideHintButton)
            Toggle(coordinator.L(.honeyMode), isOn: $viewModel.options.honeyMode)
            Toggle(coordinator.L(.manuallyDismissBanners), isOn: $viewModel.options.manuallyDismissBanners)
        }
    }
}

// MARK: - Stats sheet

struct KlondikeStatsSheet: View {
    let stats: GameStatistics
    @Environment(\.dismiss) private var dismiss
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        NavigationStack {
            List {
                row(coordinator.L(.gamesPlayed), "\(stats.gamesPlayed)")
                row(coordinator.L(.gamesWon), "\(stats.gamesWon)")
                row(coordinator.L(.winRate), String(format: "%.0f%%", stats.winPercentage))
                row(coordinator.L(.currentStreak), "\(stats.currentStreak)")
                row(coordinator.L(.longestStreak), "\(stats.longestStreak)")
                if stats.shortestWinTime > 0 {
                    row(coordinator.L(.fastestWin), String(format: "%02d:%02d", stats.shortestWinTime / 60, stats.shortestWinTime % 60))
                }
            }
            .navigationTitle(coordinator.L(.klondikeStatisticsTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(coordinator.L(.done)) { dismiss() }
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
