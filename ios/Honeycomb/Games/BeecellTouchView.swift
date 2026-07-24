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

    private static let boardSpace = "beecellBoard"
    private static let columnSpacing: CGFloat = 4

    @State private var pileFrames: [String: CGRect] = [:]
    @State private var draggedCards: [Card] = []
    @State private var dragSourcePile: Pile? = nil
    @State private var dragLocation: CGPoint = .zero
    @State private var dragOffset: CGSize = .zero

    @State private var isMenuOpen = false
    @State private var showingStats = false
    @State private var dismissedStuckBanner = false

    private let placementHaptic = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        GeometryReader { geo in
            let columns = CGFloat(max(viewModel.state.tableau.count, 8))
            let cardW = min((geo.size.width - 16 - (columns - 1) * Self.columnSpacing) / columns, 100)
            let cardH = cardW * 181.0 / 128.0
            let topSlots = CGFloat(viewModel.state.freeCells.count + viewModel.state.foundations.count)
            // Free cells + foundations share the top row with a control gap; shrink the
            // slot size when double-deck doubles the slot count.
            let topCardW = min(cardW, (geo.size.width - 16 - 52 - (topSlots - 1) * Self.columnSpacing) / topSlots)
            let topCardH = topCardW * 181.0 / 128.0

            ZStack {
                coordinator.currentFeltColor.ignoresSafeArea()

                VStack(spacing: 10) {
                    topBar
                        .padding(.horizontal, 12)
                        .frame(height: 44)

                    topRow(cardW: topCardW, cardH: topCardH)
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
                    BeecellSettingsSection(viewModel: viewModel)
                }
            }
            .coordinateSpace(name: Self.boardSpace)
        }
        .sheet(isPresented: $showingStats) { BeecellStatsSheet(viewModel: viewModel) }
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

            HStack(spacing: 10) {
                Text(viewModel.scoreString)
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

    // MARK: Top row: free cells | undo/hint | foundations

    private func topRow(cardW: CGFloat, cardH: CGFloat) -> some View {
        HStack(alignment: .center, spacing: Self.columnSpacing) {
            ForEach(viewModel.state.freeCells) { pile in
                freeCellView(pile: pile, cardW: cardW, cardH: cardH)
            }

            // Undo/hint in the free-cell/foundation gap, per the agreed layout.
            VStack(spacing: 4) {
                controlCircle(systemImage: "arrow.uturn.backward", label: "Undo",
                              diameter: min(36, cardH * 0.45)) {
                    viewModel.undoLastAction()
                }
                .disabled(!viewModel.canUndo)
                .opacity(viewModel.canUndo ? 1 : 0.35)

                if !viewModel.options.hideHintButton {
                    controlCircle(systemImage: "lightbulb", label: "Hint",
                                  diameter: min(36, cardH * 0.45)) {
                        viewModel.findHint()
                    }
                }
            }
            .frame(width: 44, height: cardH)

            ForEach(viewModel.state.foundations) { pile in
                foundationView(pile: pile, cardW: cardW, cardH: cardH)
            }
        }
    }

    private func freeCellView(pile: Pile, cardW: CGFloat, cardH: CGFloat) -> some View {
        ZStack {
            emptySlot(cardW: cardW, cardH: cardH, symbol: "hexagon")
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
        let suitString = pile.id.components(separatedBy: "_").last ?? "hearts"
        return ZStack {
            emptySlot(cardW: cardW, cardH: cardH, symbol: foundationSymbol(suitString))
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

    private func tableauColumn(pile: Pile, cardW: CGFloat, cardH: CGFloat) -> some View {
        let upStep = cardH * 0.24
        let columnHeight = pile.cards.isEmpty ? cardH : CGFloat(pile.cards.count - 1) * upStep + cardH

        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: cardW * 0.07)
                .fill(Color.black.opacity(0.18))
                .frame(width: cardW, height: cardH)
            ForEach(Array(pile.cards.enumerated()), id: \.element.id) { i, card in
                let stack = Array(pile.cards[i...])
                TouchCardView(card: card, width: cardW)
                    .offset(y: CGFloat(i) * upStep)
                    .opacity(draggedCards.contains(where: { $0.id == card.id }) ? 0 : 1)
                    .modifier(TouchHintHighlight(isHighlighted: viewModel.activeHint?.card.id == card.id))
                    .onTapGesture(count: 2) {
                        viewModel.doubleClickMove(card: card, from: pile)
                    }
                    .gesture(isDraggableSequence(stack) ? cardDragGesture(pile: pile, stack: stack) : nil)
            }
        }
        .frame(width: cardW, height: columnHeight, alignment: .top)
        .modifier(TouchHintHighlight(isHighlighted: pile.cards.isEmpty && hintTouches(pile.id)))
        .background(frameTracker(id: pile.id))
    }

    /// A grabbable stack must be a descending, alternating-color run (Freecell rule).
    /// Move-count limits are enforced by the ViewModel on drop.
    private func isDraggableSequence(_ cards: [Card]) -> Bool {
        guard !cards.isEmpty else { return false }
        for i in 0..<(cards.count - 1) {
            let upper = cards[i]
            let lower = cards[i + 1]
            guard lower.rank == upper.rank - 1, lower.isRed != upper.isRed else { return false }
        }
        return true
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
        case "clubs": return "suit.club.fill"
        // BeeCell foundation ids aren't suit-keyed (suits claim foundations as aces
        // land), so show a neutral ace marker instead of a wrong suit.
        default: return "a.circle"
        }
    }

    private func controlCircle(systemImage: String, label: String, diameter: CGFloat,
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

    private var winOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("You Win!")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.yellow)
                Text("Score: \(viewModel.scoreString)")
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

struct BeecellSettingsSection: View {
    @Bindable var viewModel: BeecellViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BEECELL")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Picker("Decks", selection: $viewModel.options.deckCount) {
                Text("Single Deck").tag(1)
                Text("Double Deck").tag(2)
            }
            .pickerStyle(.segmented)

            Toggle("Timed", isOn: $viewModel.options.isTimed)
            Toggle("Sound", isOn: $viewModel.options.isSoundEnabled)
            Toggle("No Stress Mode", isOn: $viewModel.options.noStressMode)
            Toggle("Hide Hint Button", isOn: $viewModel.options.hideHintButton)
        }
    }
}

// MARK: - Stats sheet

struct BeecellStatsSheet: View {
    @Bindable var viewModel: BeecellViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                row("Games Played", "\(viewModel.currentModeStats.gamesPlayed)")
                row("Games Won", "\(viewModel.currentModeStats.gamesWon)")
                row("Current Streak", "\(viewModel.currentModeStats.currentStreak)")
                row("Longest Streak", "\(viewModel.currentModeStats.longestStreak)")
                row("High Score", viewModel.highScoreString)
            }
            .navigationTitle("BeeCell Stats (\(viewModel.options.deckCount == 1 ? "1 Deck" : "2 Decks"))")
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
