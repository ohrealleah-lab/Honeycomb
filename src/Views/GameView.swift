import SwiftUI
import AppKit

public struct GameView: View {
    var viewModel: GameViewModel
    
    // Drag-and-drop state
    @State private var draggedCards: [Card] = []
    @State private var dragSnapshot: NSImage? = nil
    @State private var dragSourcePile: Pile? = nil
    @State private var dragOffset: CGSize = .zero
    @State private var dragLocation: CGPoint = .zero
    @State private var pileFrames: [String: CGRect] = [:]
    @State private var isShuffling: Bool = false
    @State private var isShowingOptions: Bool = false
    @State private var isShowingStats: Bool = false
    @State private var isShowingNewGameConfirm: Bool = false
    @State private var pendingDrawMode: GameState.DrawMode? = nil
    @State private var hostingWindow: NSWindow? = nil
    @State private var zoomController: WindowZoomController? = nil

    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator?
    
    public init(viewModel: GameViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        let stackSpacing = viewModel.zoomScale > 1.0 ? max(4.0, 18.0 - 14.0 * (viewModel.zoomScale - 1.0)) : 18.0
        let columnCount = viewModel.state.tableau.count > 0 ? viewModel.state.tableau.count : 7
        let boardWidth = CGFloat(columnCount) * 128.0 + CGFloat(columnCount - 1) * stackSpacing + 40.0
        
        return ZStack {
            // Felt Board Background
            viewModel.options.feltColor.primaryColor
                .ignoresSafeArea()

            if viewModel.options.showFeltVignette { FeltVignetteView(intensity: 0.34) }

            VStack(spacing: 0) {
                // Stationary Top Control and Status Panel (1.0x Scale)
                HStack(spacing: 20) {
                    // Game Selection Dropdown
                    Menu {
                        Button(GameMode.klondike.rawValue) {
                            if let coordinator = coordinator, coordinator.gameMode != .klondike {
                                coordinator.gameMode = .klondike
                                coordinator.startNewGame()
                            }
                        }
                        Button(GameMode.beecell.rawValue) {
                            if let coordinator = coordinator, coordinator.gameMode != .beecell {
                                coordinator.gameMode = .beecell
                                coordinator.startNewGame()
                            }
                        }
                        Button(GameMode.spider.rawValue) {
                            if let coordinator = coordinator, coordinator.gameMode != .spider {
                                coordinator.gameMode = .spider
                                coordinator.startNewGame()
                            }
                        }
                        Button(GameMode.videoPoker.rawValue) {
                            if let coordinator = coordinator, coordinator.gameMode != .videoPoker {
                                coordinator.gameMode = .videoPoker
                            }
                        }
                        Button(GameMode.blackjack.rawValue) {
                            if let coordinator = coordinator, coordinator.gameMode != .blackjack {
                                coordinator.gameMode = .blackjack
                            }
                        }
                    } label: {
                        Text("Game Selection")
                            .font(.display(16))
                            .foregroundColor(.white)
                    }
                    .menuStyle(.borderlessButton)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white, lineWidth: 1))
                    .focusable(false)

                    // Options Button
                    Button(action: { isShowingOptions = true }) {
                        Text("Options")
                            .font(.display(16))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(4)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white, lineWidth: 1))
                    }
                    .buttonStyle(HoverToolbarButtonStyle())
                    .focusable(false)

                    // Stats Button
                    if !viewModel.options.hideStatsButton {
                        Button(action: { isShowingStats = true }) {
                            Text("Stats")
                                .font(.display(16))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(4)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white, lineWidth: 1))
                        }
                        .buttonStyle(HoverToolbarButtonStyle())
                        .focusable(false)
                    }

                    // Hint Button
                    if !viewModel.options.hideHintButton {
                        Button(action: { viewModel.findHint() }) {
                            Text("Hint")
                                .font(.display(16))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(4)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white, lineWidth: 1))
                        }
                        .buttonStyle(HoverToolbarButtonStyle())
                        .disabled(viewModel.state.hasWon)
                        .focusable(false)
                        .keyboardShortcut("h", modifiers: .command)
                    }

                    // Undo Button
                    let canUndo = viewModel.canUndo && !viewModel.state.hasWon
                    Button(action: { viewModel.undoLastAction() }) {
                        Text("Undo")
                            .font(.display(16))
                            .foregroundColor(canUndo ? .white : .white.opacity(0.4))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(canUndo ? Color.white : Color.white.opacity(0.4), lineWidth: 1)
                            )
                    }
                    .buttonStyle(HoverToolbarButtonStyle())
                    .disabled(!canUndo)
                    .focusable(false)
                    .keyboardShortcut("z", modifiers: .command)
                    
                    Spacer()
                    
                    if viewModel.options.isStatusBarVisible {
                        HStack(alignment: .bottom, spacing: 20) {
                            // Games Played
                            StatusItemView(label: "PLAYED", value: String(viewModel.gamesPlayed))

                            // Games Won
                            StatusItemView(label: "WON", value: String(viewModel.gamesWon))
                            
                            // Score / Bankroll
                            if viewModel.options.isVegasScoring {
                                StatusItemView(label: "BANKROLL", value: viewModel.vegasBankrollString)
                            } else {
                                StatusItemView(label: "SCORE", value: viewModel.scoreString)
                            }
                            
                            // Moves
                            StatusItemView(label: "MOVES", value: String(viewModel.state.movesCount))

                            // Timer
                            if viewModel.options.isTimed {
                                StatusItemView(label: "TIME", value: formatTime(viewModel.state.timerSeconds))
                            }
                        }
                    }
                    
                    Button(action: { pendingDrawMode = .drawOne; isShowingNewGameConfirm = true }) { EmptyView() }
                        .keyboardShortcut("1", modifiers: .command).frame(width: 0, height: 0).opacity(0)

                    Button(action: { pendingDrawMode = .drawThree; isShowingNewGameConfirm = true }) { EmptyView() }
                        .keyboardShortcut("3", modifiers: .command).frame(width: 0, height: 0).opacity(0)

                    Button(action: { isShowingNewGameConfirm = true }) { EmptyView() }
                        .keyboardShortcut("n", modifiers: .command).frame(width: 0, height: 0).opacity(0)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.vertical, 6)
                .layoutPriority(1)

                // Visual Divider line
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 1)
                
                // Scaled Board Area
                ZStack {
                    VStack(spacing: 16) {
                        // Display current active hint
                if viewModel.activeHint != nil {
                    HStack {
                        Text("💡")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(4)

                        Button("Dismiss") {
                            viewModel.clearHint()
                        }
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .transition(.slide)
                }
                
                // Piles Row (Stock + Waste + Col 2 Blank + 4 Foundations)
                HStack(alignment: .top, spacing: stackSpacing) {
                    ZStack {
                        StockPileView(pile: viewModel.state.stock, stackSpacing: stackSpacing, canRecycle: viewModel.canRecycleStock)
                            .offset(x: isShuffling ? -6 : 0, y: isShuffling ? -2 : 0)
                            .rotationEffect(.degrees(isShuffling ? -4 : 0))
                        if viewModel.isStockExhausted {
                            Text("Stock\nExhausted")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Color.orange.opacity(0.85))
                                .cornerRadius(6)
                        }
                    }
                    .frame(width: 128, height: 181)
                    .contentShape(Rectangle())
                    .modifier(HintHighlightModifier(isHighlighted: viewModel.activeHint?.sourcePileId == viewModel.state.stock.id || viewModel.activeHint?.targetPileId == viewModel.state.stock.id))
                    .background(GeometryReader { geo in
                        Color.clear
                            .onAppear {
                                pileFrames[viewModel.state.stock.id] = geo.frame(in: .global)
                            }
                            .onChange(of: geo.frame(in: .global)) { _, newFrame in
                                pileFrames[viewModel.state.stock.id] = newFrame
                            }
                    })
                    .overlay(
                        ClickReceiver {
                            if viewModel.state.hasWon { return }
                            if viewModel.state.stock.isEmpty && !viewModel.canRecycleStock {
                                return
                            }
                            viewModel.clearHint()
                            let wasEmpty = viewModel.state.stock.isEmpty
                            if wasEmpty && !viewModel.state.waste.isEmpty {
                                // Recycle animation: cards slide back to stock
                                withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                                    viewModel.drawCard()
                                }
                                // Play a quick physical wiggle on the stock pile
                                withAnimation(.spring(response: 0.15, dampingFraction: 0.35)) {
                                    isShuffling = true
                                }
                                // Center wiggle back
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    withAnimation(.spring(response: 0.22, dampingFraction: 0.45)) {
                                        isShuffling = false
                                    }
                                }
                            } else {
                                // Draw animation: cards slide to waste
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    viewModel.drawCard()
                                }
                            }
                        }
                    )
                    
                    // Waste
                    WastePileView(
                        pile: viewModel.state.waste,
                        isDrawThree: viewModel.state.drawMode == .drawThree,
                        wasteDisplayCount: viewModel.state.wasteDisplayCount,
                        stackSpacing: stackSpacing,
                        draggedCardIDs: Set(draggedCards.map { $0.id }),
                        onDragStarted: { card, stack, startLoc in
                            viewModel.clearHint()
                            if draggedCards.isEmpty {
                                draggedCards = stack
                                dragSourcePile = viewModel.state.waste
                                dragLocation = startLoc
                                makeDragSnapshot(cards: stack)
                            }
                        },
                        onDragChanged: { translation in
                            dragOffset = translation
                        },
                        onDragEnded: {
                            handleDragEnded()
                        },
                        onDoubleClick: { card in
                            viewModel.doubleClickMoveToFoundation(card: card, from: viewModel.state.waste)
                        }
                    )
                    .modifier(HintHighlightModifier(isHighlighted: viewModel.activeHint?.sourcePileId == viewModel.state.waste.id || viewModel.activeHint?.targetPileId == viewModel.state.waste.id))
                    .background(GeometryReader { geo in
                        Color.clear
                            .onAppear {
                                pileFrames[viewModel.state.waste.id] = geo.frame(in: .global)
                            }
                            .onChange(of: geo.frame(in: .global)) { _, newFrame in
                                pileFrames[viewModel.state.waste.id] = newFrame
                            }
                    })
                    
                    // Blank spacer representing Tableau column 2 to lock grid alignment
                    Spacer()
                        .frame(width: viewModel.state.drawMode == .drawThree ? 44 : 128)
                    
                    // 4 Foundations
                    ForEach(viewModel.state.foundations) { pile in
                        let suitString = pile.id.components(separatedBy: "_").last ?? "hearts"
                        let suit = Card.Suit(rawValue: suitString) ?? .hearts
                        
                        FoundationPileView(
                            pile: pile,
                            suit: suit,
                            onDragStarted: { card, stack, startLoc in
                                viewModel.clearHint()
                                if draggedCards.isEmpty {
                                    draggedCards = stack
                                    dragSourcePile = pile
                                    dragLocation = startLoc
                                    makeDragSnapshot(cards: stack)
                                }
                            },
                            onDragChanged: { translation in
                                dragOffset = translation
                            },
                            onDragEnded: {
                                handleDragEnded()
                            }
                        )
                        .modifier(HintHighlightModifier(isHighlighted: viewModel.activeHint?.sourcePileId == pile.id || viewModel.activeHint?.targetPileId == pile.id))
                        .background(GeometryReader { geo in
                            Color.clear
                                .onAppear {
                                    pileFrames[pile.id] = geo.frame(in: .global)
                                }
                                .onChange(of: geo.frame(in: .global)) { _, newFrame in
                                    pileFrames[pile.id] = newFrame
                                }
                        })
                    }
                }
                .padding(.horizontal, 20)

                // Tableau Row (7 Piles)
                HStack(alignment: .top, spacing: stackSpacing) {
                    ForEach(viewModel.state.tableau) { pile in
                        TableauPileView(
                            pile: pile,
                            draggedCardIDs: Set(draggedCards.map { $0.id }),
                            onDragStarted: { card, stack, startLoc in
                                viewModel.clearHint()
                                if draggedCards.isEmpty {
                                    draggedCards = stack
                                    dragSourcePile = pile
                                    dragLocation = startLoc
                                    makeDragSnapshot(cards: stack)
                                }
                            },
                            onDragChanged: { translation in
                                dragOffset = translation
                            },
                            onDragEnded: {
                                handleDragEnded()
                            },
                            onDoubleClick: { card in
                                viewModel.doubleClickMoveToFoundation(card: card, from: pile)
                            }
                        )
                        .modifier(HintHighlightModifier(isHighlighted: viewModel.activeHint?.sourcePileId == pile.id || viewModel.activeHint?.targetPileId == pile.id))
                        .background(GeometryReader { geo in
                            Color.clear
                                .onAppear {
                                    pileFrames[pile.id] = geo.frame(in: .global)
                                }
                                .onChange(of: geo.frame(in: .global)) { _, newFrame in
                                    pileFrames[pile.id] = newFrame
                                }
                        })
                    }
                }
                .padding(.horizontal, 20)

                // Stuck Banner (non-Vegas)
                if viewModel.isStuck && !viewModel.state.hasWon && !viewModel.options.isVegasScoring {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No moves remaining.")
                                .font(.system(.headline, design: .monospaced))
                                .foregroundColor(.white)
                            Text("There are no valid moves remaining.")
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        Spacer()
                        HStack(spacing: 8) {
                            Button("Restart Game") { viewModel.restartCurrentGame() }
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.yellow)
                                .cornerRadius(6)
                                .shadow(radius: 2)
                                .buttonStyle(.plain)
                            Button("New Game") { viewModel.startNewGame() }
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.yellow)
                                .cornerRadius(6)
                                .shadow(radius: 2)
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                    .background(Color.blue.opacity(0.9))
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .shadow(radius: 5)
                }

                // Autocomplete Banner — inline below the tableau so it sits under the lowest cards
                if viewModel.isAutocompleteAvailable && !viewModel.isAutoplayRunning {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Victory is guaranteed!")
                                .font(.system(.headline, design: .monospaced))
                                .foregroundColor(.white)
                            Text("All remaining cards can be moved to foundations.")
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        Spacer()
                        Button("Autocomplete Game") {
                            viewModel.runAutocomplete()
                        }
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.yellow)
                        .cornerRadius(6)
                        .shadow(radius: 2)
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                    .background(Color.blue.opacity(0.9))
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .shadow(radius: 5)
                }

                Spacer()
            }
            .disabled(viewModel.isAutoplayRunning)
            .padding(.top, 20)
            
            // Vegas game-over overlay
            if viewModel.isStuck && !viewModel.state.hasWon && viewModel.options.isVegasScoring {
                VStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Text("GAME OVER")
                            .font(.system(size: 36, weight: .black, design: .monospaced))
                            .foregroundColor(.yellow)
                            .shadow(radius: 3)

                        Text("No moves remaining.")
                            .font(.system(.headline, design: .monospaced))
                            .foregroundColor(.white)

                        Text("Final bankroll: \(viewModel.vegasBankrollString)")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.yellow)

                        HStack(spacing: 12) {
                            Button("Restart Game") {
                                viewModel.restartCurrentGame()
                            }
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .cornerRadius(6)
                            .buttonStyle(.plain)

                            Button("New Game") {
                                viewModel.startNewGame()
                            }
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .cornerRadius(6)
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: 420)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow, lineWidth: 1.5))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Victory overlay (Classic Bouncing Card Cascade)
            if viewModel.state.hasWon {
                WinAnimationView(foundations: viewModel.state.foundations) {
                    // Optional finish callback (e.g. log win)
                }
                .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Text("YOU WIN!")
                            .font(.system(size: 40, weight: .black, design: .monospaced))
                            .foregroundColor(.yellow)
                            .shadow(radius: 3)

                        Text(viewModel.options.isVegasScoring
                             ? "Bankroll: \(viewModel.vegasBankrollString) | Time: \(formatTime(viewModel.state.timerSeconds))"
                             : "Score: \(viewModel.scoreString) | Time: \(formatTime(viewModel.state.timerSeconds))")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.white)

                        Button("Play Again") {
                            viewModel.startNewGame()
                        }
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(6)
                        .buttonStyle(.plain)
                    }
                    .padding(24)
                    .frame(maxWidth: 420)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow, lineWidth: 1.5))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            }
            .frame(width: boardWidth, height: 950, alignment: .topLeading)
            .scaleEffect(viewModel.zoomScale, anchor: .topLeading)
            .frame(width: boardWidth * viewModel.zoomScale, height: 950 * viewModel.zoomScale, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            
            // Drag overlay representation (positioned globally, scaled to match board)
            if !draggedCards.isEmpty {
                let cardCount = CGFloat(draggedCards.count)
                let stackHeight = 181.0 + (cardCount - 1.0) * 32.0
                Group {
                    if let snapshot = dragSnapshot {
                        Image(nsImage: snapshot)
                            .resizable()
                            .frame(width: 128, height: stackHeight)
                    } else {
                        VStack(spacing: 32 - 181) {
                            ForEach(draggedCards) { card in
                                CardView(card: card)
                            }
                        }
                    }
                }
                .scaleEffect(viewModel.zoomScale)
                .position(
                    x: dragLocation.x + dragOffset.width,
                    y: dragLocation.y + dragOffset.height
                )
                .shadow(color: .black.opacity(0.4), radius: 5, x: 0, y: 5)
                .allowsHitTesting(false)
        }
        }
        .environment(\.feltColor, viewModel.options.feltColor)
        .environment(\.activeCardBackTheme, viewModel.options.cardBackTheme)
        .environment(\.activeCustomCardColors, viewModel.options.customCardColors)
        .id(viewModel.options.customFeltColorRevision)
        .frame(minWidth: boardWidth * viewModel.zoomScale,
               maxWidth: .infinity,
               minHeight: 73 + 950 * viewModel.zoomScale,
               maxHeight: .infinity)
        .sheet(isPresented: $isShowingOptions) {
            OptionsView(viewModel: viewModel, onViewStats: {
                isShowingStats = true
            })
        }
        .sheet(isPresented: $isShowingStats) {
            StatsView(viewModel: viewModel)
        }
        .confirmationDialog("Start a new game?", isPresented: $isShowingNewGameConfirm) {
            Button("New Game", role: .destructive) {
                if let mode = pendingDrawMode { viewModel.state.drawMode = mode; pendingDrawMode = nil }
                viewModel.startNewGame()
            }
            Button("Cancel", role: .cancel) { pendingDrawMode = nil }
        }
        .onAppear { snapToMinSize() }
        .background(WindowAccessor { window in
            self.hostingWindow = window
            self.zoomController = WindowZoomController(window: window)
            snapToMinSize()
        })
        .onChange(of: viewModel.zoomScale) { updateMinSize() }
        .onChange(of: viewModel.state.tableau.count) { updateMinSize() }
    }

    private func updateMinSize() {
        guard let window = hostingWindow else { return }
        let z = viewModel.zoomScale
        let spacing = z > 1.0 ? max(4.0, 18.0 - 14.0 * (z - 1.0)) : 18.0
        let cols = CGFloat(max(viewModel.state.tableau.count, 7))
        let minW = (cols * 128.0 + (cols - 1) * spacing + 40.0) * z + 24
        let minH = 73.0 + 950.0 * z + 24
        DispatchQueue.main.async {
            window.contentMinSize = NSSize(width: minW, height: minH)
        }
    }

    private func snapToMinSize() {
        guard let window = hostingWindow else { return }
        let z = viewModel.zoomScale
        let spacing = z > 1.0 ? max(4.0, 18.0 - 14.0 * (z - 1.0)) : 18.0
        let cols = CGFloat(max(viewModel.state.tableau.count, 7))
        let minW = (cols * 128.0 + (cols - 1) * spacing + 40.0) * z + 24
        let minH = 73.0 + 950.0 * z + 24
        let size = NSSize(width: minW, height: minH)
        DispatchQueue.main.async {
            window.contentMinSize = size
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                window.animator().setContentSize(size)
            }
        }
    }

    private func makeDragSnapshot(cards: [Card]) {
        let cardCount = CGFloat(cards.count)
        let stackHeight = 181.0 + (cardCount - 1.0) * 32.0
        let content = VStack(spacing: -149) {
            ForEach(cards) { card in
                CardView(card: card)
            }
        }
        .frame(width: 128, height: stackHeight)
        .environment(\.activeCardBackTheme, viewModel.options.cardBackTheme)
        .environment(\.activeCustomCardColors, viewModel.options.customCardColors)
        let renderer = ImageRenderer(content: content)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
        dragSnapshot = renderer.nsImage
    }

    private func handleDragEnded() {
        let releaseLocation = CGPoint(
            x: dragLocation.x + dragOffset.width,
            y: dragLocation.y + dragOffset.height
        )
        
        var dropTarget: Pile? = nil
        
        // 1. Check Tableau piles first (using horizontal alignment, open vertical bottoms, and prioritizing columns that accept the cards)
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
                    let accepts = viewModel.isValidMove(cards: draggedCards, to: tab)
                    let distanceX = abs(releaseLocation.x - frame.midX)
                    tableauCandidates.append(CandidateTableau(pile: tab, accepts: accepts, distanceX: distanceX))
                }
            }
        }
        
        if !tableauCandidates.isEmpty {
            let sorted = tableauCandidates.sorted { (c1, c2) in
                if c1.accepts != c2.accepts {
                    return c1.accepts && !c2.accepts
                }
                return c1.distanceX < c2.distanceX
            }
            dropTarget = sorted.first?.pile
        }
        
        // 2. Check Foundations and other top-row piles if no Tableau was targetable
        if dropTarget == nil {
            struct CandidateTopRow {
                let pile: Pile
                let accepts: Bool
                let distance: CGFloat
            }
            
            var topCandidates: [CandidateTopRow] = []
            
            // Check foundations
            for foundation in viewModel.state.foundations {
                if let frame = pileFrames[foundation.id] {
                    let margin: CGFloat = 16
                    let inX = releaseLocation.x >= frame.minX - margin && releaseLocation.x <= frame.maxX + margin
                    let inY = releaseLocation.y >= frame.minY - margin && releaseLocation.y <= frame.maxY + margin
                    
                    if inX && inY {
                        let accepts = viewModel.isValidMove(cards: draggedCards, to: foundation)
                        let dx = releaseLocation.x - frame.midX
                        let dy = releaseLocation.y - frame.midY
                        let dist = sqrt(dx*dx + dy*dy)
                        topCandidates.append(CandidateTopRow(pile: foundation, accepts: accepts, distance: dist))
                    }
                }
            }
            
            // Check stock/waste (though normally non-targetable, kept for state integrity)
            for pile in [viewModel.state.stock, viewModel.state.waste] {
                if let frame = pileFrames[pile.id] {
                    let margin: CGFloat = 16
                    let inX = releaseLocation.x >= frame.minX - margin && releaseLocation.x <= frame.maxX + margin
                    let inY = releaseLocation.y >= frame.minY - margin && releaseLocation.y <= frame.maxY + margin
                    
                    if inX && inY {
                        let accepts = viewModel.isValidMove(cards: draggedCards, to: pile)
                        let dx = releaseLocation.x - frame.midX
                        let dy = releaseLocation.y - frame.midY
                        let dist = sqrt(dx*dx + dy*dy)
                        topCandidates.append(CandidateTopRow(pile: pile, accepts: accepts, distance: dist))
                    }
                }
            }
            
            if !topCandidates.isEmpty {
                let sorted = topCandidates.sorted { (c1, c2) in
                    if c1.accepts != c2.accepts {
                        return c1.accepts && !c2.accepts
                    }
                    return c1.distance < c2.distance
                }
                dropTarget = sorted.first?.pile
            }
        }
        
        if let target = dropTarget, let source = dragSourcePile {
            viewModel.clearHint()
            viewModel.moveCards(draggedCards, from: source, to: target)
        }

        viewModel.clearHint()
        // Reset states
        draggedCards = []
        dragSnapshot = nil
        dragSourcePile = nil
        dragOffset = .zero
    }
    
    private func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - UI Subviews

struct StatusItemView: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.display(13))
                .foregroundColor(.white.opacity(0.6))
            Text(value)
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundColor(.white)
        }
    }
}

struct HintHighlightModifier: ViewModifier {
    let isHighlighted: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isHighlighted ? Color.yellow : Color.clear, lineWidth: 3.5)
                    .shadow(color: isHighlighted ? .yellow : .clear, radius: 4)
            )
            .animation(isHighlighted ? Animation.easeInOut(duration: 0.5).repeatCount(4, autoreverses: true) : nil, value: isHighlighted)
    }
}

extension FeltColorTheme {
    var primaryColor: Color {
        switch self {
        case .feltGreen:
            return Color(red: 0.0, green: 0.5, blue: 0.0)
        case .crimson:
            return Color(red: 0.55, green: 0.05, blue: 0.15)
        case .royalBlue:
            return Color(red: 0.1, green: 0.2, blue: 0.5)
        case .charcoal:
            return Color(red: 0.18, green: 0.18, blue: 0.18)
        case .desert:
            return Color(red: 0.76, green: 0.59, blue: 0.48)
        case .custom:
            let r = UserDefaults.standard.double(forKey: "custom_felt_red")
            let g = UserDefaults.standard.double(forKey: "custom_felt_green")
            let b = UserDefaults.standard.double(forKey: "custom_felt_blue")
            if r == 0 && g == 0 && b == 0 {
                return Color(red: 0.35, green: 0.15, blue: 0.45)
            }
            return Color(red: r, green: g, blue: b)
        }
    }
    
    var statusBarColor: Color {
        switch self {
        case .feltGreen:
            return Color(red: 0.0, green: 0.45, blue: 0.0)
        case .crimson:
            return Color(red: 0.48, green: 0.03, blue: 0.12)
        case .royalBlue:
            return Color(red: 0.08, green: 0.16, blue: 0.42)
        case .charcoal:
            return Color(red: 0.14, green: 0.14, blue: 0.14)
        case .desert:
            return Color(red: 0.71, green: 0.54, blue: 0.43)
        case .custom:
            let r = UserDefaults.standard.double(forKey: "custom_felt_red")
            let g = UserDefaults.standard.double(forKey: "custom_felt_green")
            let b = UserDefaults.standard.double(forKey: "custom_felt_blue")
            if r == 0 && g == 0 && b == 0 {
                return Color(red: 0.3, green: 0.12, blue: 0.38)
            }
            return Color(red: max(0, r - 0.05), green: max(0, g - 0.05), blue: max(0, b - 0.05))
        }
    }
}

struct OptionsView: View {
    @Bindable var viewModel: GameViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var feltColor: FeltColorTheme
    @State private var cardBackTheme: String
    @State private var isTimed: Bool
    @State private var isStatusBarVisible: Bool
    @State private var isSoundEnabled: Bool
    @State private var isVegasScoring: Bool
    @State private var drawMode: GameState.DrawMode
    @State private var hideHintButton: Bool
    @State private var hideStatsButton: Bool
    @State private var showFeltVignette: Bool
    @State private var customSelectedColor: Color
    @State private var customCardColors: CustomCardColorGroup
    @State private var showingThemes: Bool = false

    let originalRed: Double
    let originalGreen: Double
    let originalBlue: Double
    let originalCustomCardColors: CustomCardColorGroup
    
    let onViewStats: (() -> Void)?
    
    init(viewModel: GameViewModel, onViewStats: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onViewStats = onViewStats
        _feltColor = State(initialValue: viewModel.options.feltColor)
        _cardBackTheme = State(initialValue: viewModel.options.cardBackTheme)
        _isTimed = State(initialValue: viewModel.options.isTimed)
        _isStatusBarVisible = State(initialValue: viewModel.options.isStatusBarVisible)
        _isSoundEnabled = State(initialValue: viewModel.options.isSoundEnabled)
        _isVegasScoring = State(initialValue: viewModel.options.isVegasScoring)
        _drawMode = State(initialValue: viewModel.state.drawMode)
        _hideHintButton = State(initialValue: viewModel.options.hideHintButton)
        _hideStatsButton = State(initialValue: viewModel.options.hideStatsButton)
        _showFeltVignette = State(initialValue: viewModel.options.showFeltVignette)
        _customCardColors = State(initialValue: viewModel.options.customCardColors)
        self.originalCustomCardColors = viewModel.options.customCardColors

        let r = UserDefaults.standard.double(forKey: "custom_felt_red")
        let g = UserDefaults.standard.double(forKey: "custom_felt_green")
        let b = UserDefaults.standard.double(forKey: "custom_felt_blue")
        self.originalRed = r
        self.originalGreen = g
        self.originalBlue = b
        let initialColor: Color
        if r == 0 && g == 0 && b == 0 {
            initialColor = Color(red: 0.35, green: 0.15, blue: 0.45)
        } else {
            initialColor = Color(red: r, green: g, blue: b)
        }
        _customSelectedColor = State(initialValue: initialColor)
    }
    
    var body: some View {
        ZStack {
        VStack(spacing: 20) {
            Text("Preferences")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .padding(.top, 12)
            
            Divider()
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Draw Mode:", selection: $drawMode) {
                        Text("Draw One").tag(GameState.DrawMode.drawOne)
                        Text("Draw Three").tag(GameState.DrawMode.drawThree)
                    }
                    .pickerStyle(.segmented)
                    
                    Divider()

                    Toggle("Timed Game", isOn: $isTimed)
                        .font(.system(.body, design: .monospaced))

                    Toggle("Sound Effects", isOn: $isSoundEnabled)
                        .font(.system(.body, design: .monospaced))

                    Toggle("Vegas Scoring Mode", isOn: $isVegasScoring)
                        .font(.system(.body, design: .monospaced))

                    Toggle("Hide Hint button", isOn: $hideHintButton)
                        .font(.system(.body, design: .monospaced))

                    Toggle("Hide Stats button", isOn: $hideStatsButton)
                        .font(.system(.body, design: .monospaced))

                    Divider()

                    Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showingThemes = true } }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Visual Themes")
                                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                                    .foregroundColor(.primary)
                                Text("Felt, card back, face card art, colors")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.primary.opacity(0.02))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    Divider()
                }
                .padding(.horizontal, 24)
            }
            .frame(maxHeight: 680)

            Divider()
            
            HStack {
                Button("Cancel") {
                    UserDefaults.standard.set(originalRed, forKey: "custom_felt_red")
                    UserDefaults.standard.set(originalGreen, forKey: "custom_felt_green")
                    UserDefaults.standard.set(originalBlue, forKey: "custom_felt_blue")
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button(action: {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        onViewStats?()
                    }
                }) {
                    Text("View Stats")
                        .underline()
                        .foregroundColor(.blue)
                        .font(.system(.body, design: .monospaced))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button("OK") {
                    var updatedOpts = viewModel.options
                    updatedOpts.feltColor = feltColor
                    updatedOpts.cardBackTheme = cardBackTheme
                    updatedOpts.isTimed = isTimed
                    updatedOpts.isStatusBarVisible = isStatusBarVisible
                    updatedOpts.isSoundEnabled = isSoundEnabled
                    updatedOpts.isVegasScoring = isVegasScoring
                    updatedOpts.hideHintButton = hideHintButton
                    updatedOpts.hideStatsButton = hideStatsButton
                    updatedOpts.showFeltVignette = showFeltVignette
                    updatedOpts.customCardColors = customCardColors
                    updatedOpts.customFeltColorRevision += 1

                    updatedOpts.drawMode = drawMode
                    if viewModel.state.drawMode != drawMode {
                        viewModel.state.drawMode = drawMode
                        viewModel.startNewGame()
                    }

                    viewModel.options = updatedOpts
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(width: 440)
        .background(Color(NSColor.windowBackgroundColor))

        if showingThemes {
            ThemesOptionsView(
                isShowing: $showingThemes,
                feltColor: $feltColor,
                cardBackTheme: $cardBackTheme,
                showFeltVignette: $showFeltVignette,
                customSelectedColor: $customSelectedColor,
                customCardColors: $customCardColors,
                originalRed: originalRed,
                originalGreen: originalGreen,
                originalBlue: originalBlue,
                originalCustomCardColors: originalCustomCardColors,
                onDone: {
                    var updatedOpts = viewModel.options
                    updatedOpts.feltColor = feltColor
                    updatedOpts.cardBackTheme = cardBackTheme
                    updatedOpts.showFeltVignette = showFeltVignette
                    updatedOpts.customCardColors = customCardColors
                    updatedOpts.customFeltColorRevision += 1
                    viewModel.options = updatedOpts
                }
            )
            .transition(.move(edge: .trailing))
            .frame(width: 880)
        }
        } // ZStack
        .frame(width: showingThemes ? 880 : 440)
        .animation(.easeInOut(duration: 0.2), value: showingThemes)
    }
}

struct StatsView: View {
    let viewModel: GameViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingResetConfirmation = false

    var body: some View {
        let stats = viewModel.statistics
        
        VStack(spacing: 20) {
            Text("Klondike Statistics")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .padding(.top, 12)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Games Played:")
                    Spacer()
                    Text("\(stats.gamesPlayed)")
                }
                .font(.system(.body, design: .monospaced))

                HStack {
                    Text("Games Won:")
                    Spacer()
                    Text("\(stats.gamesWon)")
                }
                .font(.system(.body, design: .monospaced))

                HStack {
                    Text("High Score:")
                    Spacer()
                    Text(viewModel.highScoreString)
                }
                .font(.system(.body, design: .monospaced))

                HStack {
                    Text("Win Percentage:")
                    Spacer()
                    Text(String(format: "%.1f%%", stats.winPercentage))
                }
                .font(.system(.body, design: .monospaced))

                if viewModel.options.isVegasScoring {
                    HStack {
                        Text("Vegas Bankroll:")
                        Spacer()
                        Text(viewModel.vegasBankrollString)
                            .foregroundColor(viewModel.vegasBankroll >= 0 ? .green : .red)
                    }
                    .font(.system(.body, design: .monospaced))
                }

                HStack {
                    Text("Current Streak:")
                    Spacer()
                    Text("\(stats.currentStreak)")
                }
                .font(.system(.body, design: .monospaced))

                HStack {
                    Text("Longest Streak:")
                    Spacer()
                    Text("\(stats.longestStreak)")
                }
                .font(.system(.body, design: .monospaced))

                HStack {
                    Text("Avg Winning Time:")
                    Spacer()
                    Text(stats.winningGamesCount > 0 ? String(format: "%.0fs", stats.averageWinningTime) : "--")
                }
                .font(.system(.body, design: .monospaced))

                HStack {
                    Text("Fastest Win:")
                    Spacer()
                    Text(stats.shortestWinTime > 0 ? "\(stats.shortestWinTime)s" : "--")
                }
                .font(.system(.body, design: .monospaced))
            }
            .padding(.horizontal, 36)

            Divider()

            HStack {
                Button("Reset Stats") {
                    showingResetConfirmation = true
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
                .font(.system(.body, design: .monospaced))
                .alert("Reset Statistics?", isPresented: $showingResetConfirmation) {
                    Button("Reset", role: .destructive) {
                        let emptyStats = GameStatistics()
                        viewModel.statistics = emptyStats
                        viewModel.resetStatistics()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will permanently clear all statistics. This cannot be undone.")
                }

                if viewModel.options.isVegasScoring {
                    Button("Reset Bankroll") { viewModel.resetVegasBankroll() }
                        .buttonStyle(.borderless)
                        .foregroundColor(.red)
                        .font(.system(.body, design: .monospaced))
                }

                Spacer()

                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(width: 360)
        .background(Color(NSColor.windowBackgroundColor))
    }
}



struct ClickReceiver: NSViewRepresentable {
    var action: () -> Void

    func makeNSView(context: Context) -> InstantClickNSView {
        let view = InstantClickNSView()
        view.action = action
        return view
    }

    func updateNSView(_ nsView: InstantClickNSView, context: Context) {
        nsView.action = action
    }
}

class InstantClickNSView: NSView {
    var action: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        action?()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

