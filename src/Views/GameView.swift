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
    @State private var isDrawInFlight: Bool = false
    @State private var showIdleStockHint: Bool = false
    @State private var idleStockHintTask: DispatchWorkItem? = nil
    @State private var isShowingOptions: Bool = false
    @State private var isShowingStats: Bool = false
    @State private var isShowingNewGameConfirm: Bool = false
    @State private var isShowingRestartConfirm: Bool = false
    @State private var dismissedAutocompleteBanner: Bool = false
    @State private var dismissedStuckBanner: Bool = false
    @State private var dismissedWinBanner: Bool = false
    @State private var winPulse: Bool = false
    @State private var pendingDrawMode: GameState.DrawMode? = nil
    @State private var hostingWindow: NSWindow? = nil
    @State private var zoomController: WindowZoomController? = nil
    @FocusState private var isBoardFocused: Bool
    @State private var keyMonitor: Any? = nil

    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator

    public init(viewModel: GameViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        let stackSpacing = viewModel.zoomScale > 1.0 ? max(4.0, 18.0 - 14.0 * (viewModel.zoomScale - 1.0)) : 18.0
        let columnCount = viewModel.state.tableau.count > 0 ? viewModel.state.tableau.count : 7
        let boardWidth = CGFloat(columnCount) * 128.0 + CGFloat(columnCount - 1) * stackSpacing + 40.0
        let resolvedFeltColorTheme: FeltColorTheme = coordinator.feltColor
        let resolvedShowFeltVignette: Bool = coordinator.showFeltVignette
        let resolvedCardBackTheme: String = coordinator.cardBackTheme
        let resolvedCustomCardColors: CustomCardColorGroup = coordinator.customCardColors

        return ZStack {
            // Board Background — a custom image if one's active, otherwise the app-wide
            // shared felt color on AppCoordinator (not per-game options).
            BackgroundLayerView()
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.clearKeyboardCursor()
                    isBoardFocused = true
                }

            if resolvedShowFeltVignette { FeltVignetteView(intensity: 0.34) }

            VStack(spacing: 0) {
                // Stationary Top Control and Status Panel (1.0x Scale)
                HStack(spacing: 20) {
                    // Game Selection Dropdown
                    Menu {
                        Button(GameMode.klondike.rawValue) {
                            if coordinator.gameMode != .klondike {
                                coordinator.gameMode = .klondike
                                coordinator.startNewGame()
                            }
                        }
                        Button(GameMode.beecell.rawValue) {
                            if coordinator.gameMode != .beecell {
                                coordinator.gameMode = .beecell
                                coordinator.startNewGame()
                            }
                        }
                        Button(GameMode.spider.rawValue) {
                            if coordinator.gameMode != .spider {
                                coordinator.gameMode = .spider
                                coordinator.startNewGame()
                            }
                        }
                        Button(GameMode.videoPoker.rawValue) {
                            if coordinator.gameMode != .videoPoker {
                                coordinator.gameMode = .videoPoker
                            }
                        }
                        Button(GameMode.blackjack.rawValue) {
                            if coordinator.gameMode != .blackjack {
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

                    // New Game Button
                    Button(action: { isShowingNewGameConfirm = true }) {
                        Text("New Game")
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

                    // Restart Button
                    Button(action: { isShowingRestartConfirm = true }) {
                        Text("Restart")
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
                        .disabled(viewModel.state.hasWon || !viewModel.hasHintsAvailable)
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
                    
                    if viewModel.options.isStatusBarVisible && !viewModel.options.noStressMode {
                        HStack(alignment: .bottom, spacing: 20) {
                            // Score / Bankroll
                            if viewModel.options.isVegasScoring {
                                StatusItemView(label: "BANKROLL", value: viewModel.vegasBankrollString)
                            } else {
                                StatusItemView(label: "SCORE", value: viewModel.scoreString)
                            }

                            // Moves
                            StatusItemView(label: "MOVES", value: String(viewModel.state.movesCount))

                            // Timer
                            StatusItemView(label: "TIME", value: formatTime(viewModel.state.timerSeconds))
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
                
                // Piles Row (Stock + Waste + Col 2 Blank + 4 Foundations)
                HStack(alignment: .top, spacing: stackSpacing) {
                    ZStack {
                        StockPileView(
                            pile: viewModel.state.stock,
                            stackSpacing: stackSpacing,
                            canRecycle: viewModel.canRecycleStock,
                            isFocused: viewModel.activeCursor?.pileId == viewModel.state.stock.id,
                            isSelected: viewModel.selectedCardsSource == viewModel.state.stock.id
                        )
                        .offset(x: isShuffling ? -6 : 0, y: isShuffling ? -2 : 0)
                            .rotationEffect(.degrees(isShuffling ? -4 : 0))
                        if viewModel.isStockExhausted {
                            Text("Stock\nExhausted")
                                .font(.system(size: 17, weight: .bold))
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(width: 128, height: 181)
                    .contentShape(Rectangle())
                    .modifier(HintHighlightModifier(isHighlighted: viewModel.activeHint?.sourcePileId == viewModel.state.stock.id || viewModel.activeHint?.targetPileId == viewModel.state.stock.id || showIdleStockHint))
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
                            viewModel.clearKeyboardCursor()
                            isBoardFocused = true
                            performStockDraw()
                        }
                    )
                    
                    // Waste
                    WastePileView(
                        pile: viewModel.state.waste,
                        isDrawThree: viewModel.state.drawMode == .drawThree,
                        wasteDisplayCount: viewModel.state.wasteDisplayCount,
                        stackSpacing: stackSpacing,
                        draggedCardIDs: Set(draggedCards.map { $0.id }),
                        isHinted: (viewModel.activeHint?.sourcePileId == viewModel.state.waste.id || viewModel.activeHint?.targetPileId == viewModel.state.waste.id) && viewModel.activeHint?.sourcePileId != viewModel.state.stock.id && viewModel.activeHint?.targetPileId != viewModel.state.stock.id,
                        isFocused: viewModel.activeCursor?.pileId == viewModel.state.waste.id,
                        isSelected: viewModel.selectedCardsSource == viewModel.state.waste.id,
                        onDragStarted: { card, stack, startLoc in
                            viewModel.clearKeyboardCursor()
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
                            isFocused: viewModel.activeCursor?.pileId == pile.id,
                            isSelected: viewModel.selectedCardsSource == pile.id,
                            onDragStarted: { card, stack, startLoc in
                                viewModel.clearKeyboardCursor()
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
                            activeHint: viewModel.activeHint,
                            isFocused: viewModel.activeCursor?.pileId == pile.id,
                            focusedCardIndex: viewModel.activeCursor?.pileId == pile.id ? viewModel.activeCursor?.cardIndex : nil,
                            isSelected: viewModel.selectedCardsSource == pile.id,
                            selectedCardIndex: viewModel.selectedCardsSource == pile.id ? viewModel.selectedCardsIndex : nil,
                            onDragStarted: { card, stack, startLoc in
                                viewModel.clearKeyboardCursor()
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

                Spacer()
            }
            .disabled(viewModel.isAutoplayRunning)
            .padding(.top, 20)
            
            // Game-over overlay (both Vegas and non-Vegas)
            if viewModel.isStuck && !viewModel.state.hasWon && !dismissedStuckBanner {
                VStack {
                    Spacer()
                    ZStack(alignment: .topTrailing) {
                        VStack(spacing: 12) {
                            Text("Game Over")
                                .font(.system(size: 36, weight: .black))
                                .foregroundColor(.yellow)
                                .shadow(radius: 3)

                            Text("No moves remaining.")
                                .font(.system(.headline))
                                .foregroundColor(.white)

                            if viewModel.options.isVegasScoring {
                                Text("Final bankroll: \(viewModel.vegasBankrollString)")
                                    .font(.system(.body))
                                    .foregroundColor(.yellow)
                            }

                            HStack(spacing: 12) {
                                Button("New Game") {
                                    viewModel.startNewGame()
                                }
                                .font(.system(.body))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .cornerRadius(6)
                                .buttonStyle(.plain)

                                Button("Restart Game") {
                                    viewModel.restartCurrentGame()
                                }
                                .font(.system(.body))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .cornerRadius(6)
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                    .padding(.vertical, 24)
                        .frame(maxWidth: 280)
                        .fixedSize(horizontal: false, vertical: true)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(12)
                        .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.5), radius: 16)

                        Button(action: { dismissedStuckBanner = true }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .padding(10)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Autocomplete overlay — centered
            if viewModel.isAutocompleteAvailable && !viewModel.isAutoplayRunning && !dismissedAutocompleteBanner {
                VStack {
                    Spacer()
                    ZStack(alignment: .topTrailing) {
                        VStack(spacing: 12) {
                            Text("Victory is guaranteed!")
                                .font(.system(size: 36, weight: .black))
                                .foregroundColor(.yellow)
                                .multilineTextAlignment(.center)
                            Text("All remaining cards can be moved to foundations.")
                                .font(.system(.body))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            Button("Autocomplete Game") {
                                viewModel.runAutocomplete()
                            }
                            .font(.system(.body))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .cornerRadius(6)
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                    .padding(.vertical, 24)
                        .frame(maxWidth: 280)
                        .fixedSize(horizontal: false, vertical: true)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(12)
                        .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.5), radius: 16)

                        Button(action: { dismissedAutocompleteBanner = true }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .padding(10)
                    }
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

                if !dismissedWinBanner {
                    VStack {
                        Spacer()
                        ZStack(alignment: .topTrailing) {
                            VStack(spacing: 12) {
                                Text("You win!")
                                    .font(.system(size: 40, weight: .black))
                                    .foregroundColor(.yellow)
                                    .scaleEffect(winPulse ? 1.06 : 1.0)
                                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: winPulse)
                                    .onAppear { winPulse = true }
                                    .onDisappear { winPulse = false }

                                Text(winSummaryText)
                                    .font(.system(.body))
                                    .foregroundColor(.white)

                                Button("Play Again") {
                                    viewModel.startNewGame()
                                }
                                .font(.system(.body))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .cornerRadius(6)
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 24)
                            .frame(maxWidth: 360)
                            .fixedSize(horizontal: false, vertical: true)
                            .background(Color.black.opacity(0.75))
                            .cornerRadius(12)
                            .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.5), radius: 16)

                            Button(action: { dismissedWinBanner = true }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                            .padding(10)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
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

            HotkeyLegendView(text: "Arrows=Move Cursor   Space/Return=Select or Move   D=Draw   F=Auto-Foundation   A=Autocomplete   Esc=Clear Cursor")
        }
        .environment(\.feltColor, resolvedFeltColorTheme)
        .environment(\.activeCardBackTheme, resolvedCardBackTheme)
        .environment(\.activeCustomCardColors, resolvedCustomCardColors)
        .focusable()
        .focused($isBoardFocused)
        .onAppear {
            isBoardFocused = true
            scheduleIdleStockHint()
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                guard !isShowingOptions && !isShowingStats else { return event }
                if let firstResponder = NSApp.keyWindow?.firstResponder,
                   firstResponder.isKind(of: NSText.self) || String(describing: type(of: firstResponder)).contains("TextView") {
                    return event
                }
                // Arrow/function keys always carry .numericPad and .function in modifierFlags
                // even with no modifier held, so only guard against real modifier keys.
                let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
                guard modifiers.isEmpty else { return event }

                switch event.keyCode {
                case 123: // Left Arrow
                    viewModel.moveCursorLeft()
                    return nil
                case 124: // Right Arrow
                    viewModel.moveCursorRight()
                    return nil
                case 126: // Up Arrow
                    viewModel.moveCursorUp()
                    return nil
                case 125: // Down Arrow
                    viewModel.moveCursorDown()
                    return nil
                case 49, 36: // Space, Return
                    viewModel.performSpaceAction()
                    return nil
                case 53: // Escape
                    viewModel.clearKeyboardCursor()
                    return nil
                default:
                    if let chars = event.charactersIgnoringModifiers?.lowercased() {
                        if chars == "d" {
                            viewModel.enableKeyboardCursorIfNeeded()
                            performStockDraw()
                            return nil
                        } else if chars == "f" {
                            viewModel.autoMoveFocusedCardToFoundations()
                            return nil
                        } else if chars == "a" {
                            viewModel.runAutocomplete()
                            return nil
                        }
                    }
                }
                return event
            }
        }
        .onDisappear {
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
                keyMonitor = nil
            }
            idleStockHintTask?.cancel()
            idleStockHintTask = nil
        }
        .onChange(of: viewModel.state.movesCount) {
            scheduleIdleStockHint()
        }
        .onChange(of: viewModel.options.hideHintButton) {
            scheduleIdleStockHint()
        }
        .onChange(of: viewModel.gameGeneration) {
            scheduleIdleStockHint()
        }
        .frame(minWidth: boardWidth * viewModel.zoomScale,
               maxWidth: .infinity,
               minHeight: 73 + 950 * viewModel.zoomScale,
               maxHeight: .infinity)
        .overlay {
            if isShowingOptions {
                Color.clear
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .overlay(
                        OptionsView(viewModel: viewModel, isPresented: $isShowingOptions, coordinator: coordinator, onViewStats: {
                            isShowingStats = true
                        })
                    )
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $isShowingStats) {
            StatsView(viewModel: viewModel)
        }
        .confirmationDialog("Restart this game from the beginning?", isPresented: $isShowingRestartConfirm) {
            Button("Restart Game", role: .destructive) { viewModel.restartCurrentGame() }
            Button("Cancel", role: .cancel) { }
        }
        .confirmationDialog("Start a new game? Your current game will end.", isPresented: $isShowingNewGameConfirm) {
            Button("Cancel", role: .cancel) { pendingDrawMode = nil }
            Button("New Game", role: .destructive) {
                if let mode = pendingDrawMode { viewModel.state.drawMode = mode; pendingDrawMode = nil }
                viewModel.startNewGame()
            }
        }
        .onChange(of: viewModel.isAutocompleteAvailable) { _, newVal in if newVal { dismissedAutocompleteBanner = false } }
        .onChange(of: viewModel.isStuck) { _, newVal in if newVal { dismissedStuckBanner = false } }
        .onChange(of: viewModel.state.hasWon) { _, newVal in if newVal { dismissedWinBanner = false } }
        .onChange(of: viewModel.debugBannerRequest) { _, kind in
            guard let kind else { return }
            viewModel.debugBannerRequest = nil
            switch kind {
            case .win:
                let suits: [Card.Suit] = [.spades, .clubs, .diamonds, .hearts]
                viewModel.state.foundations = suits.map { suit in
                    let cards = (1...13).map { Card(suit: suit, rank: $0, faceUp: true) }
                    return Pile(id: "foundation_\(suit.rawValue)", type: .foundation, cards: cards)
                }
                viewModel.state.hasWon = true
                dismissedWinBanner = false
            case .stuck:
                viewModel.state.hasWon = false
                dismissedStuckBanner = false
                viewModel.isStuck = true
            case .autocomplete:
                viewModel.state.hasWon = false
                dismissedAutocompleteBanner = false
                viewModel.isAutocompleteAvailable = true
            case .loss:
                break
            }
        }
        .onAppear { snapToMinSize() }
        .background(WindowAccessor { window in
            self.hostingWindow = window
            self.zoomController = WindowZoomController(window: window)
            coordinator.activeWindow = window
            if let saved = viewModel.defaultWindowSize {
                snapToMinSize(overrideSize: NSSize(width: saved.width, height: saved.height))
            } else {
                snapToMinSize()
            }
        })
        .onChange(of: viewModel.zoomScale) { snapToMinSize() }
        .onChange(of: viewModel.state.tableau.count) { updateMinSize() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { note in
            guard (note.object as? NSWindow) == hostingWindow, !draggedCards.isEmpty else { return }
            cancelDrag()
        }
    }

    private func scheduleIdleStockHint() {
        let eligible = !viewModel.options.hideHintButton
            && !viewModel.hasDrawnFromStockThisGame
            && !viewModel.hasShownIdleStockHintThisGame
        guard eligible else {
            // Already permanently ineligible for the rest of this game — once any
            // pending task/visible hint has been cleared, further calls (e.g. from
            // movesCount changing on every move) are true no-ops instead of redoing
            // the cancel/animate work every time.
            guard idleStockHintTask != nil || showIdleStockHint else { return }
            idleStockHintTask?.cancel()
            idleStockHintTask = nil
            withAnimation { showIdleStockHint = false }
            return
        }
        idleStockHintTask?.cancel()
        withAnimation { showIdleStockHint = false }
        let task = DispatchWorkItem {
            guard !viewModel.options.hideHintButton,
                  !viewModel.hasDrawnFromStockThisGame,
                  !viewModel.hasShownIdleStockHintThisGame else { return }
            viewModel.hasShownIdleStockHintThisGame = true
            withAnimation { showIdleStockHint = true }
            // Auto-dismiss after a brief moment rather than lingering indefinitely.
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { showIdleStockHint = false }
            }
        }
        idleStockHintTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: task)
    }

    private func performStockDraw() {
        if viewModel.state.hasWon { return }
        if viewModel.state.stock.isEmpty && !viewModel.canRecycleStock { return }
        guard !isDrawInFlight else { return }
        viewModel.clearHint()
        let wasEmpty = viewModel.state.stock.isEmpty
        isDrawInFlight = true
        if wasEmpty && !viewModel.state.waste.isEmpty {
            // Recycle animation: cards slide back to stock
            withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                viewModel.drawCard()
            } completion: {
                isDrawInFlight = false
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
            } completion: {
                isDrawInFlight = false
            }
        }
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

    private func snapToMinSize(overrideSize: NSSize? = nil) {
        guard let window = hostingWindow else { return }
        let z = viewModel.zoomScale
        let spacing = z > 1.0 ? max(4.0, 18.0 - 14.0 * (z - 1.0)) : 18.0
        let cols = CGFloat(max(viewModel.state.tableau.count, 7))
        let minW = (cols * 128.0 + (cols - 1) * spacing + 40.0) * z + 24
        let minH = 73.0 + 950.0 * z + 24
        let minSize = NSSize(width: minW, height: minH)
        let size = overrideSize.map { NSSize(width: max($0.width, minW), height: max($0.height, minH)) } ?? minSize
        DispatchQueue.main.async {
            window.contentMinSize = minSize

            // Grow/shrink anchored to the window's top-left corner (not NSWindow's default
            // bottom-left anchor) so a height change never pushes the toolbar/title bar off
            // the top of the screen.
            var newFrame = window.frameRect(forContentRect: NSRect(origin: .zero, size: size))
            let currentFrame = window.frame
            newFrame.origin.x = currentFrame.origin.x
            newFrame.origin.y = currentFrame.maxY - newFrame.height
            if let visible = window.screen?.visibleFrame {
                newFrame.origin.y = min(newFrame.origin.y, visible.maxY - newFrame.height)
                newFrame.origin.y = max(newFrame.origin.y, visible.minY)
            }

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                window.animator().setFrame(newFrame, display: true)
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
        .environment(\.activeCardBackTheme, coordinator.cardBackTheme)
        .environment(\.activeCustomCardColors, coordinator.customCardColors)
        let renderer = ImageRenderer(content: content)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
        dragSnapshot = renderer.nsImage
    }

    // Clears drag state without attempting a move — used both by a normal drop (after
    // handleDragEnded resolves a target, or finds none) and as a safety net when the
    // window loses key status mid-drag (Cmd+Tab, a system dialog, Mission Control, etc.).
    // SwiftUI's DragGesture has no distinct "cancelled" callback, so a gesture interrupted
    // that way never fires .onEnded/handleDragEnded at all — without this, the floating
    // drag overlay (driven by draggedCards/dragOffset) is left rendering forever, exactly
    // like a stack of cards stuck hovering mid-board.
    private func cancelDrag() {
        draggedCards = []
        dragSnapshot = nil
        dragSourcePile = nil
        dragOffset = .zero
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
            if let best = sorted.first, best.accepts {
                dropTarget = best.pile
            }
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
                if let best = sorted.first, best.accepts {
                    dropTarget = best.pile
                }
            }
        }
        
        if let target = dropTarget, let source = dragSourcePile {
            viewModel.clearHint()
            viewModel.moveCards(draggedCards, from: source, to: target)
        }

        viewModel.clearHint()
        cancelDrag()
    }
    
    private func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var winSummaryText: String {
        let scorePart = viewModel.options.isVegasScoring
            ? "Bankroll: \(viewModel.vegasBankrollString)"
            : "Score: \(viewModel.scoreString)"
        guard !viewModel.options.noStressMode else { return scorePart }
        return "\(scorePart) | Time: \(formatTime(viewModel.state.timerSeconds))"
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
                .font(.system(size: 20, weight: .black))
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
    @Binding var isPresented: Bool
    @Bindable var coordinator: AppCoordinator

    @State private var isStatusBarVisible: Bool
    @State private var isSoundEnabled: Bool
    @State private var isVegasScoring: Bool
    @State private var drawMode: GameState.DrawMode
    @State private var hideHintButton: Bool
    @State private var noStressMode: Bool
    @State private var customSelectedColor: Color
    @State private var showingThemes: Bool = false

    let originalRed: Double
    let originalGreen: Double
    let originalBlue: Double
    let originalFeltColor: FeltColorTheme
    let originalCardBackTheme: String
    let originalShowFeltVignette: Bool
    let originalCustomCardColors: CustomCardColorGroup
    let originalCustomBackgroundName: String?

    let onViewStats: (() -> Void)?

    init(viewModel: GameViewModel, isPresented: Binding<Bool>, coordinator: AppCoordinator, onViewStats: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self._isPresented = isPresented
        self.coordinator = coordinator
        self.onViewStats = onViewStats
        _isStatusBarVisible = State(initialValue: viewModel.options.isStatusBarVisible)
        _isSoundEnabled = State(initialValue: viewModel.options.isSoundEnabled)
        _isVegasScoring = State(initialValue: viewModel.options.isVegasScoring)
        _drawMode = State(initialValue: viewModel.state.drawMode)
        _hideHintButton = State(initialValue: viewModel.options.hideHintButton)
        _noStressMode = State(initialValue: viewModel.options.noStressMode)
        self.originalFeltColor = coordinator.feltColor
        self.originalCardBackTheme = coordinator.cardBackTheme
        self.originalShowFeltVignette = coordinator.showFeltVignette
        self.originalCustomCardColors = coordinator.customCardColors
        self.originalCustomBackgroundName = coordinator.customBackgroundName

        let r = coordinator.customFeltRed
        let g = coordinator.customFeltGreen
        let b = coordinator.customFeltBlue
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
                .font(.system(size: 16, weight: .bold))
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

                    Toggle("Sound Effects", isOn: $isSoundEnabled)
                        .font(.system(.body))

                    Toggle("Vegas Scoring Mode", isOn: $isVegasScoring)
                        .font(.system(.body))

                    Toggle("Hide Hint button", isOn: $hideHintButton)
                        .font(.system(.body))

                    Toggle("No Stress Mode", isOn: $noStressMode)
                        .font(.system(.body))

                    Divider()

                    Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showingThemes = true } }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Visual Themes")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.primary)
                                Text("Felt, card back, face card art, colors")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
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
                    // Revert any theme changes that were live-previewed via the Themes sub-panel.
                    coordinator.customFeltRed = originalRed
                    coordinator.customFeltGreen = originalGreen
                    coordinator.customFeltBlue = originalBlue
                    coordinator.feltColor = originalFeltColor
                    coordinator.cardBackTheme = originalCardBackTheme
                    coordinator.showFeltVignette = originalShowFeltVignette
                    coordinator.customCardColors = originalCustomCardColors
                    coordinator.customBackgroundName = originalCustomBackgroundName
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(action: {
                    isPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        onViewStats?()
                    }
                }) {
                    Text("View Stats")
                        .underline()
                        .foregroundColor(.blue)
                        .font(.system(.body))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button("OK") {
                    var updatedOpts = viewModel.options
                    updatedOpts.isStatusBarVisible = isStatusBarVisible
                    updatedOpts.isSoundEnabled = isSoundEnabled
                    updatedOpts.isVegasScoring = isVegasScoring
                    updatedOpts.hideHintButton = hideHintButton
                    updatedOpts.noStressMode = noStressMode

                    updatedOpts.drawMode = drawMode
                    if viewModel.state.drawMode != drawMode {
                        viewModel.state.drawMode = drawMode
                        viewModel.startNewGame()
                    }

                    viewModel.options = updatedOpts
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(width: 440)
        .fixedSize(horizontal: true, vertical: true)
        .background(Color(NSColor.windowBackgroundColor))

        if showingThemes {
            ThemesOptionsView(
                isShowing: $showingThemes,
                isOptionsPresented: $isPresented,
                feltColor: $coordinator.feltColor,
                cardBackTheme: $coordinator.cardBackTheme,
                showFeltVignette: $coordinator.showFeltVignette,
                customSelectedColor: $customSelectedColor,
                customCardColors: $coordinator.customCardColors,
                customBackgroundName: $coordinator.customBackgroundName,
                originalRed: originalRed,
                originalGreen: originalGreen,
                originalBlue: originalBlue,
                originalCustomCardColors: originalCustomCardColors,
                onCommit: { _ in }
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
                .font(.system(size: 16, weight: .bold))
                .padding(.top, 12)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Games Played:")
                    Spacer()
                    Text("\(stats.gamesPlayed)")
                }
                .font(.system(.body))

                HStack {
                    Text("Games Won:")
                    Spacer()
                    Text("\(stats.gamesWon)")
                }
                .font(.system(.body))

                HStack {
                    Text("High Score:")
                    Spacer()
                    Text(viewModel.highScoreString)
                }
                .font(.system(.body))

                HStack {
                    Text("Win Percentage:")
                    Spacer()
                    Text(String(format: "%.1f%%", stats.winPercentage))
                }
                .font(.system(.body))

                if viewModel.options.isVegasScoring {
                    HStack {
                        Text("Vegas Bankroll:")
                        Spacer()
                        Text(viewModel.vegasBankrollString)
                            .foregroundColor(viewModel.vegasBankroll >= 0 ? .green : .red)
                    }
                    .font(.system(.body))
                }

                HStack {
                    Text("Current Streak:")
                    Spacer()
                    Text("\(stats.currentStreak)")
                }
                .font(.system(.body))

                HStack {
                    Text("Longest Streak:")
                    Spacer()
                    Text("\(stats.longestStreak)")
                }
                .font(.system(.body))

                HStack {
                    Text("Avg Winning Time:")
                    Spacer()
                    Text(stats.winningGamesCount > 0 ? String(format: "%.0fs", stats.averageWinningTime) : "--")
                }
                .font(.system(.body))

                HStack {
                    Text("Fastest Win:")
                    Spacer()
                    Text(stats.shortestWinTime > 0 ? "\(stats.shortestWinTime)s" : "--")
                }
                .font(.system(.body))
            }
            .padding(.horizontal, 36)

            Divider()

            HStack {
                Button("Reset Stats") {
                    showingResetConfirmation = true
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
                .font(.system(.body))
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
                        .font(.system(.body))
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

