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

    private static let boardSpace = "klondikeBoard"
    private static let columnSpacing: CGFloat = 6

    // MARK: Drag state (same shape as the mac view's)

    @State private var pileFrames: [String: CGRect] = [:]
    @State private var draggedCards: [Card] = []
    @State private var dragSourcePile: Pile? = nil
    @State private var dragLocation: CGPoint = .zero
    @State private var dragOffset: CGSize = .zero

    @State private var isMenuOpen = false
    @State private var showingStats = false
    @State private var dismissedStuckBanner = false
    @State private var isDrawInFlight = false

    private let placementHaptic = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        GeometryReader { geo in
            let cardW = min((geo.size.width - 16 - 6 * Self.columnSpacing) / 7, 110)
            let cardH = cardW * 181.0 / 128.0

            ZStack {
                coordinator.currentFeltColor.ignoresSafeArea()

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

                SlideDownMenu(isOpen: $isMenuOpen, coordinator: coordinator) {
                    showingStats = true
                } gameSettings: {
                    KlondikeSettingsSection(viewModel: viewModel)
                }
            }
            .coordinateSpace(name: Self.boardSpace)
        }
        .sheet(isPresented: $showingStats) { KlondikeStatsSheet(stats: viewModel.statistics) }
        .onAppear { viewModel.startTimerIfNeeded() }
        .onChange(of: viewModel.state.hasWon) { dismissedStuckBanner = false }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
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

            Spacer()

            statusCapsule

            Spacer()

            Button {
                dismissedStuckBanner = false
                viewModel.startNewGame()
            } label: {
                Label("New", systemImage: "play.fill")
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
            // here, per the agreed mobile layout. Right-aligned so the waste's sliver
            // fan never sits under them.
            VStack(spacing: 6) {
                controlCircle(systemImage: "arrow.uturn.backward", label: "Undo",
                              diameter: min(40, cardW * 0.8)) {
                    viewModel.undoLastAction()
                }
                .disabled(!viewModel.canUndo)
                .opacity(viewModel.canUndo ? 1 : 0.35)

                if !viewModel.options.hideHintButton {
                    controlCircle(systemImage: "lightbulb", label: "Hint",
                                  diameter: min(40, cardW * 0.8)) {
                        viewModel.findHint()
                    }
                }
            }
            .frame(width: cardW, height: cardH, alignment: .trailing)
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
                Text("Done")
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
        let suitString = pile.id.components(separatedBy: "_").last ?? "hearts"
        return ZStack {
            emptySlot(cardW: cardW, cardH: cardH, symbol: foundationSymbol(suitString))
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
                    .modifier(TouchHintHighlight(isHighlighted: viewModel.activeHint?.card.id == card.id))
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

    private func emptySlot(cardW: CGFloat, cardH: CGFloat, symbol: String?) -> some View {
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
            }
        }
        .frame(width: cardW, height: cardH)
    }

    private func foundationSymbol(_ suit: String) -> String {
        switch suit {
        case "spades": return "suit.spade.fill"
        case "hearts": return "suit.heart.fill"
        case "diamonds": return "suit.diamond.fill"
        default: return "suit.club.fill"
        }
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
        viewModel.activeHint?.sourcePileId == pileId || viewModel.activeHint?.targetPileId == pileId
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
                Label("Autocomplete", systemImage: "wand.and.stars")
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
            ? "Bankroll: \(viewModel.vegasBankrollString)"
            : "Score: \(viewModel.scoreString)"
        guard !viewModel.options.noStressMode else { return scorePart }
        return "\(scorePart)  •  Time: \(formatTime(viewModel.state.timerSeconds))"
    }

    private var winOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("You Win!")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.yellow)
                Text(winSummaryText)
                    .foregroundColor(.white)
                Button {
                    viewModel.startNewGame()
                } label: {
                    Label("New Game", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: 240)
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private var stuckOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("Game Over")
                    .font(.system(size: 34, weight: .black))
                    .foregroundColor(.yellow)
                Text("No moves remaining.")
                    .foregroundColor(.white)
                Button {
                    dismissedStuckBanner = true
                    viewModel.undoLastAction()
                } label: {
                    Label("Undo Last Move", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.white)
                Button {
                    dismissedStuckBanner = false
                    viewModel.startNewGame()
                } label: {
                    Label("New Game", systemImage: "play.fill")
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("KLONDIKE")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Picker("Draw Mode", selection: $viewModel.options.drawMode) {
                Text("Draw One").tag(GameState.DrawMode.drawOne)
                Text("Draw Three").tag(GameState.DrawMode.drawThree)
            }
            .pickerStyle(.segmented)

            Toggle("Vegas Scoring", isOn: $viewModel.options.isVegasScoring)
            Toggle("Timed", isOn: $viewModel.options.isTimed)
            Toggle("Sound", isOn: $viewModel.options.isSoundEnabled)
            Toggle("No Stress Mode", isOn: $viewModel.options.noStressMode)
            Toggle("Hide Hint Button", isOn: $viewModel.options.hideHintButton)
        }
    }
}

// MARK: - Stats sheet

struct KlondikeStatsSheet: View {
    let stats: GameStatistics
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                row("Games Played", "\(stats.gamesPlayed)")
                row("Games Won", "\(stats.gamesWon)")
                row("Win Rate", String(format: "%.0f%%", stats.winPercentage))
                row("Current Streak", "\(stats.currentStreak)")
                row("Longest Streak", "\(stats.longestStreak)")
                if stats.shortestWinTime > 0 {
                    row("Fastest Win", String(format: "%02d:%02d", stats.shortestWinTime / 60, stats.shortestWinTime % 60))
                }
            }
            .navigationTitle("Klondike Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
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
