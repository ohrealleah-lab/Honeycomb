import SwiftUI
import UIKit

/// Touch-first Spider board for iPhone/iPad, driven by the shared SpiderViewModel.
/// Same interaction pattern as KlondikeTouchView (the drag feel the user picked):
/// custom DragGesture + pile-frame hit testing. Spider-specific bits: only same-suit
/// descending runs can be picked up (isValidDragSequence), tapping the stock deals a
/// row, and completed runs sweep themselves — foundations are a progress indicator,
/// not a drop target.
struct SpiderTouchView: View {
    @Bindable var viewModel: SpiderViewModel
    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator

    private static let boardSpace = "spiderBoard"
    private static let columnSpacing: CGFloat = 4

    @State private var pileFrames: [String: CGRect] = [:]
    @State private var draggedCards: [Card] = []
    @State private var dragSourcePile: Pile? = nil
    @State private var dragLocation: CGPoint = .zero
    @State private var dragOffset: CGSize = .zero

    @State private var isMenuOpen = false
    @State private var showingStats = false
    @State private var dismissedStuckBanner = false
    @State private var isDealInFlight = false

    private let placementHaptic = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        GeometryReader { geo in
            let cardW = min((geo.size.width - 16 - 9 * Self.columnSpacing) / 10, 90)
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
                    SpiderSettingsSection(viewModel: viewModel)
                }
            }
            .coordinateSpace(name: Self.boardSpace)
        }
        .sheet(isPresented: $showingStats) { SpiderStatsSheet(viewModel: viewModel) }
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
    }

    // MARK: Top row: stock (deal), undo/hint, completed-runs indicator

    private var completedRunCount: Int {
        viewModel.state.foundations.filter { !$0.cards.isEmpty }.count
    }

    private func topRow(cardW: CGFloat, cardH: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 12) {
            stockView(cardW: cardW, cardH: cardH)

            Spacer()

            controlCircle(systemImage: "arrow.uturn.backward", label: "Undo") {
                viewModel.undoLastAction()
            }
            .disabled(!viewModel.canUndo)
            .opacity(viewModel.canUndo ? 1 : 0.35)

            if !viewModel.options.hideHintButton {
                controlCircle(systemImage: "lightbulb", label: "Hint") {
                    viewModel.findHint()
                }
            }

            Spacer()

            runsIndicator(cardW: cardW, cardH: cardH)
        }
        .frame(height: cardH)
    }

    private func stockView(cardW: CGFloat, cardH: CGFloat) -> some View {
        let dealsLeft = viewModel.state.stock.cards.count / max(viewModel.state.tableau.count, 1)
        return ZStack(alignment: .topLeading) {
            if viewModel.state.stock.isEmpty {
                RoundedRectangle(cornerRadius: cardW * 0.07)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
                    .frame(width: cardW, height: cardH)
            } else {
                // One back per remaining deal, slightly fanned like the mac view.
                ForEach(0..<max(dealsLeft, 1), id: \.self) { i in
                    HoneycombSimpleCardBack()
                        .frame(width: cardW, height: cardH)
                        .offset(x: CGFloat(i) * 6)
                }
            }
        }
        .frame(width: cardW + CGFloat(max(dealsLeft - 1, 0)) * 6, height: cardH, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture { performDeal() }
        .accessibilityLabel("Deal")
    }

    private func runsIndicator(cardW: CGFloat, cardH: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cardW * 0.07)
                .fill(Color.black.opacity(0.18))
            RoundedRectangle(cornerRadius: cardW * 0.07)
                .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
            VStack(spacing: 2) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(completedRunCount > 0 ? .yellow : .white.opacity(0.35))
                Text("\(completedRunCount)/\(viewModel.state.foundations.count)")
                    .font(.system(size: cardW * 0.28, weight: .bold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .frame(width: cardW * 1.4, height: cardH)
        .accessibilityLabel("Completed runs")
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
            RoundedRectangle(cornerRadius: cardW * 0.07)
                .fill(Color.black.opacity(0.18))
                .frame(width: cardW, height: cardH)
            ForEach(Array(pile.cards.enumerated()), id: \.element.id) { i, card in
                let stack = Array(pile.cards[i...])
                TouchCardView(card: card, width: cardW)
                    .offset(y: offsets[i])
                    .opacity(draggedCards.contains(where: { $0.id == card.id }) ? 0 : 1)
                    .modifier(TouchHintHighlight(isHighlighted: viewModel.activeHint?.card.id == card.id))
                    .onTapGesture(count: 2) {
                        viewModel.doubleClickMove(card: card, from: pile)
                    }
                    .gesture(
                        (card.faceUp && viewModel.isValidDragSequence(stack))
                            ? cardDragGesture(pile: pile, stack: stack) : nil
                    )
            }
        }
        .frame(width: cardW, height: columnHeight, alignment: .top)
        .modifier(TouchHintHighlight(isHighlighted: pile.cards.isEmpty && hintTouches(pile.id)))
        .background(frameTracker(id: pile.id))
    }

    // MARK: Shared pieces

    private func controlCircle(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
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

    // MARK: Drag handling (Klondike pattern; tableau-only targets)

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

        struct Candidate {
            let pile: Pile
            let accepts: Bool
            let distanceX: CGFloat
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
                        distanceX: abs(releaseLocation.x - frame.midX)))
                }
            }
        }
        if let best = candidates.sorted(by: { c1, c2 in
            if c1.accepts != c2.accepts { return c1.accepts && !c2.accepts }
            return c1.distanceX < c2.distanceX
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

    private func performDeal() {
        guard !viewModel.state.stock.isEmpty, !isDealInFlight, !viewModel.state.hasWon else { return }
        viewModel.clearHint()
        isDealInFlight = true
        withAnimation(.easeInOut(duration: 0.25)) {
            viewModel.drawFromStock()
        }
        placementHaptic.impactOccurred(intensity: 0.7)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isDealInFlight = false
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

struct SpiderSettingsSection: View {
    @Bindable var viewModel: SpiderViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SPIDER")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Picker("Difficulty", selection: $viewModel.options.suitCount) {
                Text("1 Suit").tag(1)
                Text("2 Suits").tag(2)
                Text("4 Suits").tag(4)
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

struct SpiderStatsSheet: View {
    @Bindable var viewModel: SpiderViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                row("Games Played", "\(viewModel.gamesPlayed)")
                row("Games Won", "\(viewModel.gamesWon)")
                row("High Score", viewModel.highScoreString)
            }
            .navigationTitle("Spider Stats (\(viewModel.options.suitCount) Suit)")
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
