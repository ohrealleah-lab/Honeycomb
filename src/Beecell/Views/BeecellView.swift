import SwiftUI
import AppKit

public struct BeecellView: View {
    var viewModel: BeecellViewModel
    
    // Drag-and-drop state
    @State private var draggedCards: [Card] = []
    @State private var dragSourcePile: Pile? = nil
    @State private var dragOffset: CGSize = .zero
    @State private var dragLocation: CGPoint = .zero
    @State private var pileFrames: [String: CGRect] = [:]
    @State private var isShowingOptions: Bool = false
    @State private var isShowingStats: Bool = false
    @State private var isShowingNewGameConfirm: Bool = false
    @State private var pendingDeckCount: Int? = nil
    @State private var dismissedAutocompleteBanner: Bool = false
    @State private var dismissedStuckBanner: Bool = false
    @State private var dismissedWinBanner: Bool = false
    @State private var winPulse: Bool = false
    @State private var hostingWindow: NSWindow? = nil
    @State private var zoomController: WindowZoomController? = nil
    @FocusState private var isBoardFocused: Bool
    @State private var keyMonitor: Any? = nil

    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator

    public init(viewModel: BeecellViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        let stackSpacing = viewModel.zoomScale > 1.0 ? max(4.0, 18.0 - 14.0 * (viewModel.zoomScale - 1.0)) : 18.0
        let numCols = Double(viewModel.options.deckCount == 1 ? 8 : 10)
        let boardWidth = numCols * 128.0 + (numCols - 1) * stackSpacing + 40.0
        
        let boardHeight: CGFloat = viewModel.options.deckCount == 1 ? 950 : 1120
        
        return ZStack {
            // Board Background — a custom image if one's active, otherwise the app-wide
            // shared felt color on AppCoordinator (not per-game options).
            BackgroundLayerView()
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.clearKeyboardCursor()
                    isBoardFocused = true
                }

            if coordinator.showFeltVignette { FeltVignetteView(intensity: 0.34) }


            VStack(spacing: 0) {
                // Top Control and Status Panel
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

                    // Options
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

                    // Hint
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

                    // Undo
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
                    
                    if !viewModel.options.noStressMode {
                        HStack(alignment: .bottom, spacing: 20) {
                            StatusItemView(label: "SCORE", value: viewModel.scoreString)
                            StatusItemView(label: "MOVES", value: String(viewModel.state.movesCount))
                            StatusItemView(label: "TIME", value: formatTime(viewModel.state.timerSeconds))
                        }
                    }
                    
                    Button(action: { isShowingNewGameConfirm = true }) { EmptyView() }
                        .keyboardShortcut("n", modifiers: .command).frame(width: 0, height: 0).opacity(0)

                    Button(action: { pendingDeckCount = 1; isShowingNewGameConfirm = true }) { EmptyView() }
                        .keyboardShortcut("1", modifiers: .command).frame(width: 0, height: 0).opacity(0)

                    Button(action: { pendingDeckCount = 2; isShowingNewGameConfirm = true }) { EmptyView() }
                        .keyboardShortcut("2", modifiers: .command).frame(width: 0, height: 0).opacity(0)
                }
                .padding(.horizontal, 16)
                .padding(.top, 36) // Clear the macOS traffic light window controls
                .padding(.bottom, 6)
                .layoutPriority(1)

                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 1)
                
                // Game Board Area
                ZStack {
                    VStack(spacing: 16) {

                        // Top Row: Freecells (left) and Foundations (right)
                        if viewModel.options.deckCount == 1 {
                            HStack(spacing: 0) {
                                HStack(spacing: stackSpacing) {
                                    // 4 Freecells
                                    ForEach(viewModel.state.freeCells) { cell in
                                        FreeCellView(
                                            pile: cell,
                                            draggedCardIDs: Set(draggedCards.map { $0.id }),
                                            isFocused: viewModel.activeCursor?.pileId == cell.id,
                                            isSelected: viewModel.selectedCardsSource == cell.id,
                                            onDragStarted: { card, stack, startLoc in
                                                viewModel.clearKeyboardCursor()
                                                viewModel.clearHint()
                                                if draggedCards.isEmpty {
                                                    draggedCards = stack
                                                    dragSourcePile = cell
                                                    dragLocation = startLoc
                                                }
                                            },
                                            onDragChanged: { trans in
                                                dragOffset = trans
                                            },
                                            onDragEnded: {
                                                handleDragEnded()
                                            },
                                            onDoubleClick: { card in
                                                viewModel.doubleClickMove(card: card, from: cell)
                                            }
                                        )
                                        .modifier(HintHighlightModifier(isHighlighted: viewModel.activeHint?.sourcePileId == cell.id || viewModel.activeHint?.targetPileId == cell.id))
                                        .background(GeometryReader { geo in
                                            Color.clear
                                                .onAppear { pileFrames[cell.id] = geo.frame(in: .global) }
                                                .onChange(of: geo.frame(in: .global)) { _, newFrame in pileFrames[cell.id] = newFrame }
                                        })
                                    }
                                }
                                
                                Spacer(minLength: 0)
                                
                                HStack(spacing: stackSpacing) {
                                    // 4 Foundations
                                    ForEach(viewModel.state.foundations) { foundation in
                                        BeecellFoundationView(
                                            pile: foundation,
                                            draggedCardIDs: Set(draggedCards.map { $0.id }),
                                            isFocused: viewModel.activeCursor?.pileId == foundation.id,
                                            isSelected: viewModel.selectedCardsSource == foundation.id,
                                            onDragStarted: { card, stack, startLoc in
                                                viewModel.clearKeyboardCursor()
                                                viewModel.clearHint()
                                                if draggedCards.isEmpty {
                                                    draggedCards = stack
                                                    dragSourcePile = foundation
                                                    dragLocation = startLoc
                                                }
                                            },
                                            onDragChanged: { trans in
                                                dragOffset = trans
                                            },
                                            onDragEnded: {
                                                handleDragEnded()
                                            }
                                        )
                                        .modifier(HintHighlightModifier(isHighlighted: viewModel.activeHint?.sourcePileId == foundation.id || viewModel.activeHint?.targetPileId == foundation.id))
                                        .background(GeometryReader { geo in
                                            Color.clear
                                                .onAppear { pileFrames[foundation.id] = geo.frame(in: .global) }
                                                .onChange(of: geo.frame(in: .global)) { _, newFrame in pileFrames[foundation.id] = newFrame }
                                        })
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        } else {
                            // Two-deck layout top rows (renders 2 rows of 4 Freecells/Foundations to fit board nicely)
                            VStack(spacing: 8) {
                                // Row 1: Freecells 0-3 and Foundations 0-3
                                HStack(alignment: .top, spacing: stackSpacing) {
                                    ForEach(Array(viewModel.state.freeCells[0..<4])) { cell in
                                        FreeCellView(
                                            pile: cell,
                                            draggedCardIDs: Set(draggedCards.map { $0.id }),
                                            isFocused: viewModel.activeCursor?.pileId == cell.id,
                                            isSelected: viewModel.selectedCardsSource == cell.id,
                                            onDragStarted: { card, stack, startLoc in
                                                viewModel.clearKeyboardCursor()
                                                viewModel.clearHint()
                                                if draggedCards.isEmpty {
                                                    draggedCards = stack
                                                    dragSourcePile = cell
                                                    dragLocation = startLoc
                                                }
                                            },
                                            onDragChanged: { trans in dragOffset = trans },
                                            onDragEnded: { handleDragEnded() },
                                            onDoubleClick: { card in viewModel.doubleClickMove(card: card, from: cell) }
                                        )
                                        .modifier(HintHighlightModifier(isHighlighted: viewModel.activeHint?.sourcePileId == cell.id || viewModel.activeHint?.targetPileId == cell.id))
                                        .background(GeometryReader { geo in
                                            Color.clear
                                                .onAppear { pileFrames[cell.id] = geo.frame(in: .global) }
                                                .onChange(of: geo.frame(in: .global)) { _, newFrame in pileFrames[cell.id] = newFrame }
                                        })
                                    }

                                    Spacer()
                                        .frame(width: 256 + stackSpacing)

                                    ForEach(Array(viewModel.state.foundations[0..<4])) { foundation in
                                        BeecellFoundationView(
                                            pile: foundation,
                                            draggedCardIDs: Set(draggedCards.map { $0.id }),
                                            isFocused: viewModel.activeCursor?.pileId == foundation.id,
                                            isSelected: viewModel.selectedCardsSource == foundation.id,
                                            onDragStarted: { card, stack, startLoc in
                                                viewModel.clearKeyboardCursor()
                                                viewModel.clearHint()
                                                if draggedCards.isEmpty {
                                                    draggedCards = stack
                                                    dragSourcePile = foundation
                                                    dragLocation = startLoc
                                                }
                                            },
                                            onDragChanged: { trans in dragOffset = trans },
                                            onDragEnded: { handleDragEnded() }
                                        )
                                        .modifier(HintHighlightModifier(isHighlighted: viewModel.activeHint?.sourcePileId == foundation.id || viewModel.activeHint?.targetPileId == foundation.id))
                                        .background(GeometryReader { geo in
                                            Color.clear
                                                .onAppear { pileFrames[foundation.id] = geo.frame(in: .global) }
                                                .onChange(of: geo.frame(in: .global)) { _, newFrame in pileFrames[foundation.id] = newFrame }
                                        })
                                    }
                                }

                                // Row 2: Freecells 4-7 and Foundations 4-7
                                HStack(alignment: .top, spacing: stackSpacing) {
                                    ForEach(Array(viewModel.state.freeCells[4..<8])) { cell in
                                        FreeCellView(
                                            pile: cell,
                                            draggedCardIDs: Set(draggedCards.map { $0.id }),
                                            isFocused: viewModel.activeCursor?.pileId == cell.id,
                                            isSelected: viewModel.selectedCardsSource == cell.id,
                                            onDragStarted: { card, stack, startLoc in
                                                viewModel.clearKeyboardCursor()
                                                viewModel.clearHint()
                                                if draggedCards.isEmpty {
                                                    draggedCards = stack
                                                    dragSourcePile = cell
                                                    dragLocation = startLoc
                                                }
                                            },
                                            onDragChanged: { trans in dragOffset = trans },
                                            onDragEnded: { handleDragEnded() },
                                            onDoubleClick: { card in viewModel.doubleClickMove(card: card, from: cell) }
                                        )
                                        .modifier(HintHighlightModifier(isHighlighted: viewModel.activeHint?.sourcePileId == cell.id || viewModel.activeHint?.targetPileId == cell.id))
                                        .background(GeometryReader { geo in
                                            Color.clear
                                                .onAppear { pileFrames[cell.id] = geo.frame(in: .global) }
                                                .onChange(of: geo.frame(in: .global)) { _, newFrame in pileFrames[cell.id] = newFrame }
                                        })
                                    }

                                    Spacer()
                                        .frame(width: 256 + stackSpacing)

                                    ForEach(Array(viewModel.state.foundations[4..<8])) { foundation in
                                        BeecellFoundationView(
                                            pile: foundation,
                                            draggedCardIDs: Set(draggedCards.map { $0.id }),
                                            isFocused: viewModel.activeCursor?.pileId == foundation.id,
                                            isSelected: viewModel.selectedCardsSource == foundation.id,
                                            onDragStarted: { card, stack, startLoc in
                                                viewModel.clearKeyboardCursor()
                                                viewModel.clearHint()
                                                if draggedCards.isEmpty {
                                                    draggedCards = stack
                                                    dragSourcePile = foundation
                                                    dragLocation = startLoc
                                                }
                                            },
                                            onDragChanged: { trans in dragOffset = trans },
                                            onDragEnded: { handleDragEnded() }
                                        )
                                        .modifier(HintHighlightModifier(isHighlighted: viewModel.activeHint?.sourcePileId == foundation.id || viewModel.activeHint?.targetPileId == foundation.id))
                                        .background(GeometryReader { geo in
                                            Color.clear
                                                .onAppear { pileFrames[foundation.id] = geo.frame(in: .global) }
                                                .onChange(of: geo.frame(in: .global)) { _, newFrame in pileFrames[foundation.id] = newFrame }
                                        })
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Bottom Row: Tableau columns
                        HStack(alignment: .top, spacing: stackSpacing) {
                            ForEach(viewModel.state.tableau) { pile in
                                BeecellTableauView(
                                    pile: pile,
                                    draggedCardIDs: Set(draggedCards.map { $0.id }),
                                    activeHint: viewModel.activeHint,
                                    isFocused: viewModel.activeCursor?.pileId == pile.id,
                                    isSelected: viewModel.selectedCardsSource == pile.id,
                                    onDragStarted: { card, stack, startLoc in
                                        viewModel.clearKeyboardCursor()
                                        viewModel.clearHint()
                                        if draggedCards.isEmpty {
                                            draggedCards = stack
                                            dragSourcePile = pile
                                            dragLocation = startLoc
                                        }
                                    },
                                    onDragChanged: { trans in
                                        dragOffset = trans
                                    },
                                    onDragEnded: {
                                        handleDragEnded()
                                    },
                                    onDoubleClick: { card in
                                        viewModel.doubleClickMove(card: card, from: pile)
                                    }
                                )
                                .background(GeometryReader { geo in
                                    Color.clear
                                        .onAppear { pileFrames[pile.id] = geo.frame(in: .global) }
                                        .onChange(of: geo.frame(in: .global)) { _, newFrame in pileFrames[pile.id] = newFrame }
                                })
                            }
                        }
                        .padding(.horizontal, 20)

                        Spacer()
                    }
                    .disabled(viewModel.isAutoplayRunning)
                    .padding(.top, 20)
                    
                    // Stuck overlay — centered
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
                                    Text("All remaining cards can be sorted into foundations.")
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

                    // Victory Cascade Overlay (reusing SoliBee's bouncing card animation)
                    if viewModel.state.hasWon {
                        WinAnimationView(foundations: viewModel.state.foundations) {
                            // Win recorded inside VM checkWinState
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
                .frame(width: boardWidth, height: boardHeight, alignment: .topLeading)
                .scaleEffect(viewModel.zoomScale, anchor: .topLeading)
                .frame(width: boardWidth * viewModel.zoomScale, height: boardHeight * viewModel.zoomScale, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            
            // Drag overlay representation (positioned globally, scaled to match board)
            if !draggedCards.isEmpty {
                VStack(spacing: 20 - 181) {
                    ForEach(draggedCards) { card in
                        CardView(card: card)
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

            HotkeyLegendView(text: "Arrows=Move Cursor   Space/Return=Select or Move   C=Free Cell   F=Auto-Foundation   A=Autocomplete   Esc=Clear Cursor")
        }
        .environment(\.feltColor, coordinator.feltColor)
        .environment(\.activeCardBackTheme, coordinator.cardBackTheme)
        .environment(\.activeCustomCardColors, coordinator.customCardColors)
        .focusable()
        .focused($isBoardFocused)
        .onAppear {
            isBoardFocused = true
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
                        if chars == "c" {
                            viewModel.autoMoveFocusedCardToFreeCell()
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
        }
        .frame(minWidth: boardWidth * viewModel.zoomScale,
               maxWidth: .infinity,
               minHeight: 89 + boardHeight * viewModel.zoomScale,
               maxHeight: .infinity)
        .overlay {
            if isShowingOptions {
                Color.clear
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .overlay(
                        BeecellOptionsView(viewModel: viewModel, isShowingStats: $isShowingStats, isPresented: $isShowingOptions, coordinator: coordinator)
                    )
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $isShowingStats) {
            BeecellStatsView(viewModel: viewModel)
        }
        .confirmationDialog("Start a new game? Your current game will end.", isPresented: $isShowingNewGameConfirm) {
            Button("Cancel", role: .cancel) { pendingDeckCount = nil }
            Button("New Game", role: .destructive) {
                if let deck = pendingDeckCount { viewModel.options.deckCount = deck; pendingDeckCount = nil }
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
                let count = max(viewModel.state.foundations.count, 4)
                viewModel.state.foundations = (0..<count).map { i in
                    let suit = suits[i % suits.count]
                    let cards = (1...13).map { Card(suit: suit, rank: $0, faceUp: true) }
                    return Pile(id: "foundation_\(i)", type: .foundation, cards: cards)
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
        .onChange(of: viewModel.options.deckCount) { snapToMinSize() }
        .onChange(of: viewModel.zoomScale) { snapToMinSize() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { note in
            guard (note.object as? NSWindow) == hostingWindow, !draggedCards.isEmpty else { return }
            cancelDrag()
        }
    }

    private func updateMinSize() {
        guard let window = hostingWindow else { return }
        let z = viewModel.zoomScale
        let spacing = z > 1.0 ? max(4.0, 18.0 - 14.0 * (z - 1.0)) : 18.0
        let cols = Double(viewModel.options.deckCount == 1 ? 8 : 10)
        let boardH: CGFloat = viewModel.options.deckCount == 1 ? 950 : 1120
        let minW = (cols * 128.0 + (cols - 1) * spacing + 40.0) * z + 24
        let minH = 89.0 + boardH * z + 24
        DispatchQueue.main.async {
            window.contentMinSize = NSSize(width: minW, height: minH)
        }
    }

    private func snapToMinSize(overrideSize: NSSize? = nil) {
        guard let window = hostingWindow else { return }
        
        var z = viewModel.zoomScale
        let boardH: CGFloat = viewModel.options.deckCount == 1 ? 950 : 1120
        if let screen = window.screen ?? NSScreen.main {
            let maxH = screen.visibleFrame.height - 40
            let reqH = 89.0 + boardH * z + 24 + 28
            if reqH > maxH {
                z = (maxH - 89.0 - 24 - 28) / boardH
                z = max(0.5, z)
                if z < viewModel.zoomScale {
                    viewModel.zoomScale = z
                    return
                }
            }
        }
        
        let spacing = z > 1.0 ? max(4.0, 18.0 - 14.0 * (z - 1.0)) : 18.0
        let cols = Double(viewModel.options.deckCount == 1 ? 8 : 10)
        let minW = (cols * 128.0 + (cols - 1) * spacing + 40.0) * z + 24
        let minH = 89.0 + boardH * z + 24 + 28
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

    // Clears drag state without attempting a move — used both by a normal drop (after
    // handleDragEnded resolves a target, or finds none) and as a safety net when the
    // window loses key status mid-drag (Cmd+Tab, a system dialog, Mission Control, etc.).
    // SwiftUI's DragGesture has no distinct "cancelled" callback, so a gesture interrupted
    // that way never fires .onEnded/handleDragEnded at all — without this, the floating
    // drag overlay (driven by draggedCards/dragOffset) is left rendering forever, exactly
    // like a stack of cards stuck hovering mid-board.
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
        
        // 1. Check Tableau piles first
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
        
        // 2. Check Free Cells and Foundations if no Tableau was targetable
        if dropTarget == nil {
            struct CandidateTopRow {
                let pile: Pile
                let accepts: Bool
                let distance: CGFloat
            }
            
            var topCandidates: [CandidateTopRow] = []
            
            // Check free cells
            for cell in viewModel.state.freeCells {
                if let frame = pileFrames[cell.id] {
                    let margin: CGFloat = 16
                    let inX = releaseLocation.x >= frame.minX - margin && releaseLocation.x <= frame.maxX + margin
                    let inY = releaseLocation.y >= frame.minY - margin && releaseLocation.y <= frame.maxY + margin
                    
                    if inX && inY {
                        let accepts = viewModel.isValidMove(cards: draggedCards, to: cell)
                        let dx = releaseLocation.x - frame.midX
                        let dy = releaseLocation.y - frame.midY
                        let dist = sqrt(dx*dx + dy*dy)
                        topCandidates.append(CandidateTopRow(pile: cell, accepts: accepts, distance: dist))
                    }
                }
            }
            
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
            viewModel.moveCards(draggedCards, from: source, to: target)
        }

        cancelDrag()
    }
    
    private func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var winSummaryText: String {
        guard !viewModel.options.noStressMode else { return "Score: \(viewModel.scoreString)" }
        return "Score: \(viewModel.scoreString) | Time: \(formatTime(viewModel.state.timerSeconds))"
    }

}

// Window Accessor and Detecting View helpers for resizing the macOS window to match the board size
struct WindowAccessor: NSViewRepresentable {
    var callback: (NSWindow) -> Void
    
    func makeNSView(context: Context) -> WindowDetectingView {
        WindowDetectingView(onWindowDetected: callback)
    }
    
    func updateNSView(_ nsView: WindowDetectingView, context: Context) {}
}

class WindowDetectingView: NSView {
    var onWindowDetected: (NSWindow) -> Void
    
    init(onWindowDetected: @escaping (NSWindow) -> Void) {
        self.onWindowDetected = onWindowDetected
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window = self.window {
            onWindowDetected(window)
        }
    }
}

class WindowZoomController {
    private weak var window: NSWindow?
    private var previousFrame: NSRect?
    private var eventMonitor: Any?

    init(window: NSWindow) {
        self.window = window
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self, let win = self.window, event.window === win, event.clickCount == 2 else { return event }
            let contentHeight = win.contentView?.frame.height ?? 0
            if event.locationInWindow.y > contentHeight {
                self.toggleZoom()
                return nil
            }
            return event
        }
    }

    deinit {
        if let monitor = eventMonitor { NSEvent.removeMonitor(monitor) }
    }

    func toggleZoom() {
        guard let window, let screen = window.screen ?? NSScreen.main else { return }
        if let prev = previousFrame {
            window.setFrame(prev, display: true, animate: true)
            previousFrame = nil
        } else {
            previousFrame = window.frame
            window.setFrame(screen.visibleFrame, display: true, animate: true)
        }
    }

    func clearZoomState() {
        previousFrame = nil
    }
}

// MARK: - Options Preference Dialog
struct BeecellOptionsView: View {
    @Bindable var viewModel: BeecellViewModel
    @Binding var isShowingStats: Bool
    @Binding var isPresented: Bool
    @Bindable var coordinator: AppCoordinator

    @State private var deckCount: Int
    @State private var isSoundEnabled: Bool
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

    init(viewModel: BeecellViewModel, isShowingStats: Binding<Bool>, isPresented: Binding<Bool>, coordinator: AppCoordinator) {
        self.viewModel = viewModel
        self._isShowingStats = isShowingStats
        self._isPresented = isPresented
        self.coordinator = coordinator
        _deckCount = State(initialValue: viewModel.options.deckCount)
        _isSoundEnabled = State(initialValue: viewModel.options.isSoundEnabled)
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
                    Picker("Game Mode:", selection: $deckCount) {
                        Text("Standard (1-Deck)").tag(1)
                        Text("Two Decks (2-Decks)").tag(2)
                    }
                    .pickerStyle(.segmented)
                    
                    Divider()

                    Toggle("Sound Effects", isOn: $isSoundEnabled)
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
                        isShowingStats = true
                    }
                }) {
                    Text("View Stats")
                        .foregroundColor(.blue)
                        .underline()
                }
                .buttonStyle(.plain)
                .font(.system(.body))
                
                Spacer()
                
                Button("OK") {
                    var updatedOpts = viewModel.options
                    updatedOpts.deckCount = deckCount
                    updatedOpts.isSoundEnabled = isSoundEnabled
                    updatedOpts.hideHintButton = hideHintButton
                    updatedOpts.noStressMode = noStressMode

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

// MARK: - Statistics Modal
struct BeecellStatsView: View {
    let viewModel: BeecellViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingResetConfirmation = false

    var body: some View {
        let stats = viewModel.currentModeStats
        
        VStack(spacing: 20) {
            Text("Freecell Statistics (\(viewModel.options.deckCount == 1 ? "1-Deck" : "2-Decks"))")
                .font(.system(size: 14, weight: .bold))
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
                    Button("Reset", role: .destructive) { viewModel.resetStatistics() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will permanently clear all statistics. This cannot be undone.")
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
        .frame(width: 440)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
