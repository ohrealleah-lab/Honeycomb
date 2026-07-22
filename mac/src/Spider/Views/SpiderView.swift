import SwiftUI
import AppKit

public struct SpiderView: View {
    var viewModel: SpiderViewModel

    // The toolbar stays fixed size regardless of the board's scale; only the board below
    // it scales to fit the window.
    private static let toolbarHeight: CGFloat = 89

    // Hard floor the window can be dragged down to — the board's own scale (see
    // recomputeScale()) fits content to whatever size the window actually is, so this
    // only needs to keep the toolbar legible and a sliver of the board visible. If the
    // player drags the window down near this floor, cards may clip as the tableau grows
    // during play — an accepted tradeoff of sizing the window down.
    static let minWindowSize = NSSize(width: 600, height: 330)
    // The size the window opens at when there's no saved "make current size the default"
    // preference — numerically the same generous size this app has always opened at
    // (previously 89 + 1120 + 24 + 28 height, boardWidth width, at the old zoom=1 baseline).
    static let defaultOpeningSize = NSSize(width: 1482, height: 1261)
    // Below this measured toolbar width, buttons swap their text label for an icon-only
    // SF Symbol to save space. Text is protected by lineLimit(1) (truncates rather than
    // wraps) down to this point, so the threshold only needs to sit just above the hard
    // window floor — text stays the default look across nearly the whole resizable range,
    // icons kick in only once the window is genuinely narrow.
    private static let compactToolbarWidthThreshold: CGFloat = 830

    // Measured width of the top toolbar row — drives the icon-only compact button swap.
    // Starts generous so buttons show full text before the first layout pass measures it.
    @State private var toolbarWidth: CGFloat = 2000
    @State private var windowContentHeight: CGFloat = 900

    // Drag-and-drop state
    @State private var draggedCards: [Card] = []
    @State private var dragSourcePile: Pile? = nil
    @State private var dragOffset: CGSize = .zero
    @State private var dragLocation: CGPoint = .zero
    @State private var pileFrames: [String: CGRect] = [:]
    @State private var isShowingOptions: Bool = false
    @State private var isShowingStats: Bool = false
    @State private var isShowingEmptyStockWarning: Bool = false
    @State private var isShowingNewGameConfirm: Bool = false
    @State private var dismissedAutocompleteBanner: Bool = false
    @State private var dismissedStuckBanner: Bool = false
    @State private var winPulse: Bool = false
    @State private var showNoHintsBanner: Bool = false
    @State private var noHintsBannerTask: DispatchWorkItem? = nil
    @State private var hostingWindow: NSWindow? = nil
    @State private var zoomController: WindowZoomController? = nil
    @FocusState private var isBoardFocused: Bool
    @State private var keyMonitor: Any? = nil

    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator
    
    public init(viewModel: SpiderViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        let stackSpacing = viewModel.zoomScale > 1.0 ? max(4.0, 18.0 - 14.0 * (viewModel.zoomScale - 1.0)) : 18.0
        let numCols: Double = 10.0
        let boardWidth = numCols * 128.0 + (numCols - 1) * stackSpacing + 40.0
        let boardHeight: CGFloat = currentIntrinsicBoardHeight()
        let scaledBoardWidth = boardWidth * viewModel.zoomScale
        let scaledBoardHeight = boardHeight * viewModel.zoomScale

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
                // Top Control Row
                HStack(spacing: 20) {
                    // Game Selection Dropdown
                    GameSelectionDropdown(coordinator: coordinator)

                    // New Game Button
                    GameToolbarButton(
                        label: "New Game", systemImage: "arrow.triangle.2.circlepath",
                        isCompact: toolbarWidth < Self.compactToolbarWidthThreshold
                    ) { isShowingNewGameConfirm = true }

                    // Options
                    GameToolbarButton(
                        label: "Options", systemImage: "gearshape",
                        isCompact: toolbarWidth < Self.compactToolbarWidthThreshold
                    ) { isShowingOptions = true }

                    // Hint
                    if !viewModel.options.hideHintButton {
                        GameToolbarButton(
                            label: "Hint", systemImage: "lightbulb",
                            isCompact: toolbarWidth < Self.compactToolbarWidthThreshold,
                            disabled: viewModel.state.hasWon
                        ) {
                            if viewModel.hasHintsAvailable {
                                viewModel.findHint()
                            } else {
                                flashNoHintsBanner()
                            }
                        }
                        .keyboardShortcut("h", modifiers: .command)
                    }

                    // Undo
                    let canUndo = viewModel.canUndo && !viewModel.state.hasWon
                    GameToolbarButton(
                        label: "Undo", systemImage: "arrow.uturn.backward",
                        isCompact: toolbarWidth < Self.compactToolbarWidthThreshold,
                        disabled: !canUndo
                    ) { viewModel.undoLastAction() }
                    .keyboardShortcut("z", modifiers: .command)

                    Button(action: { isShowingNewGameConfirm = true }) { EmptyView() }
                        .keyboardShortcut("n", modifiers: .command).frame(width: 0, height: 0).opacity(0)

                    Spacer()

                    if !viewModel.options.noStressMode {
                        HStack(alignment: .bottom, spacing: 20) {
                            StatusItemView(label: "SCORE", value: viewModel.scoreString)
                            StatusItemView(label: "MOVES", value: String(viewModel.state.movesCount))
                            StatusItemView(label: "TIME", value: formatTime(viewModel.state.timerSeconds))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 36) // Clear the macOS traffic light window controls
                .padding(.bottom, 6)
                .layoutPriority(1)

                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 1)

                // Game Board Area
                ScrollView(.horizontal, showsIndicators: false) {
                ZStack {
                    VStack(spacing: 16) {
                        
                        // Top Row: Stock (left) and 8 Completed Foundations (right)
                        HStack(alignment: .top, spacing: stackSpacing) {
                            // Stock Pile View
                            SpiderStockView(
                                cardCount: viewModel.state.stock.cards.count,
                                isFocused: viewModel.activeCursor?.pileId == viewModel.state.stock.id,
                                isSelected: viewModel.selectedCardsSource == viewModel.state.stock.id
                            )
                                .modifier(HintHighlightModifier(isHighlighted: viewModel.activeHint?.sourcePileId == viewModel.state.stock.id))
                                .background(GeometryReader { geo in
                                    Color.clear
                                        .onAppear { pileFrames[viewModel.state.stock.id] = geo.frame(in: .global) }
                                        .onChange(of: geo.frame(in: .global)) { _, newFrame in pileFrames[viewModel.state.stock.id] = newFrame }
                                 })
                                .overlay(
                                    ClickReceiver {
                                        viewModel.clearKeyboardCursor()
                                        isBoardFocused = true
                                        attemptStockDraw()
                                    }
                                )
                            
                            Spacer()
                            
                            // 8 Foundation columns showing completed runs
                            ForEach(viewModel.state.foundations) { pile in
                                ZStack {
                                    EmptyPileView(symbol: "K")

                                    if let topCard = pile.topCard {
                                        CardView(
                                            card: topCard,
                                            pointPopupText: viewModel.pointPopup?.cardId == topCard.id ? viewModel.pointPopup?.displayText : nil
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Bottom Row: Tableau columns (10 columns)
                        HStack(alignment: .top, spacing: stackSpacing) {
                            ForEach(viewModel.state.tableau) { pile in
                                SpiderTableauView(
                                    pile: pile,
                                    draggedCardIDs: Set(draggedCards.map { $0.id }),
                                    activeHint: viewModel.activeHint,
                                    isFocused: viewModel.activeCursor?.pileId == pile.id,
                                    focusedCardIndex: viewModel.activeCursor?.pileId == pile.id ? viewModel.activeCursor?.cardIndex : nil,
                                    isSelected: viewModel.selectedCardsSource == pile.id,
                                    selectedCardIndex: viewModel.selectedCardsSource == pile.id ? viewModel.selectedCardsIndex : nil,
                                    pointPopup: viewModel.pointPopup,
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
                    .padding(.top, 20)
                    
                    // Empty column Stock deal warning
                    if isShowingEmptyStockWarning {
                        VStack(spacing: 12) {
                            Text("Empty Column Warning")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            Text("All tableau columns must contain at least one card before dealing from the Stock.")
                                .font(.system(.body))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                            
                            Button("OK") {
                                isShowingEmptyStockWarning = false
                            }
                            .font(.system(.body))
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.yellow)
                            .cornerRadius(6)
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                    .padding(.vertical, 24)
                        .background(Color.black.opacity(0.85))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow, lineWidth: 1.5))
                        .frame(width: 440)
                    }
                    
                    // Stuck overlay — centered
                    if viewModel.isStuck && !viewModel.state.hasWon && !dismissedStuckBanner {
                        VStack {
                            Spacer(minLength: 8)
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
                            Spacer(minLength: 8)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    // Autocomplete overlay — centered
                    if viewModel.isAutocompleteAvailable && !viewModel.isAutoplayRunning && !dismissedAutocompleteBanner {
                        VStack {
                            Spacer(minLength: 8)
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
                            Spacer(minLength: 8)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

            }
                .frame(width: boardWidth, height: boardHeight, alignment: .topLeading)
                .scaleEffect(viewModel.zoomScale, anchor: .topLeading)
                // minHeight: 0 (instead of a rigid fixed height) lets this subtree actually
                // compress when the window is smaller than the toolbar + this board's full
                // scaled height combined — a hard fixed frame here reports zero flexibility
                // to the parent VStack, forcing 100% of any space deficit onto the toolbar
                // regardless of its layoutPriority. Cards inside aren't clipped by this
                // frame's allocated size either way (no .clipped() here), so this only
                // changes how much space gets reserved for layout, not how anything renders.
                .frame(width: scaledBoardWidth, alignment: .topLeading)
                .frame(minHeight: 0, idealHeight: scaledBoardHeight, maxHeight: scaledBoardHeight, alignment: .topLeading)
            }
            .frame(minWidth: boardWidth * viewModel.zoomScale, maxHeight: .infinity, alignment: .topLeading)
                } // ScrollView

            // Victory Cascade Overlay — a top-level sibling (not nested inside the scaled
            // board area or its horizontal ScrollView) so it spans the whole window rather
            // than being confined to the board's own reserved/scrollable bounds.
            if viewModel.state.hasWon {
                WinAnimationView(foundations: viewModel.state.foundations, pileFrames: pileFrames, zoomScale: viewModel.zoomScale) {
                    // finish win
                }
                .ignoresSafeArea()

                VStack {
                    Spacer(minLength: 8)
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
                    Spacer(minLength: 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if showNoHintsBanner {
                FlashBannerView(message: "Sorry! No hints available.")
            }

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

            HotkeyLegendView(text: "Arrows=Move Cursor   Space/Return=Select or Move   D=Deal   A=Autocomplete   Esc=Clear Cursor")
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
                    viewModel.enableKeyboardCursorIfNeeded()
                    if viewModel.selectedCardsSource == nil && viewModel.activeCursor?.pileId == viewModel.state.stock.id {
                        attemptStockDraw()
                    } else {
                        viewModel.performSpaceAction()
                    }
                    return nil
                case 53: // Escape
                    viewModel.clearKeyboardCursor()
                    return nil
                default:
                    if let chars = event.charactersIgnoringModifiers?.lowercased() {
                        if chars == "d" {
                            viewModel.enableKeyboardCursorIfNeeded()
                            attemptStockDraw()
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
            noHintsBannerTask?.cancel()
            noHintsBannerTask = nil
        }
        .frame(minWidth: Self.minWindowSize.width,
               maxWidth: .infinity,
               minHeight: Self.minWindowSize.height,
               maxHeight: .infinity)
        .overlay {
            if isShowingOptions {
                Color.clear
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .overlay(
                        SpiderOptionsView(viewModel: viewModel, isShowingStats: $isShowingStats, isPresented: $isShowingOptions, coordinator: coordinator, availableWidth: toolbarWidth, availableHeight: windowContentHeight)
                    )
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $isShowingStats) {
            SpiderStatsView(viewModel: viewModel)
        }
        .confirmationDialog("Start a new game? Your current game will end.", isPresented: $isShowingNewGameConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("New Game", role: .destructive) { viewModel.startNewGame() }
        }
        .onChange(of: viewModel.isAutocompleteAvailable) { _, newVal in if newVal { dismissedAutocompleteBanner = false } }
        .onChange(of: viewModel.isStuck) { _, newVal in if newVal { dismissedStuckBanner = false } }
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
        .onAppear { applyInitialWindowSize() }
        .background(WindowAccessor(callback: { window in
            self.hostingWindow = window
            self.zoomController = WindowZoomController(window: window)
            coordinator.activeWindow = window
            applyInitialWindowSize()
        }, onResize: recomputeScale))
        .onChange(of: viewModel.gameGeneration) { recomputeScale() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { note in
            guard (note.object as? NSWindow) == hostingWindow, !draggedCards.isEmpty else { return }
            cancelDrag()
        }
    }

    // Single choke point for every input path that can try to deal from the stock
    // (mouse click, 'd' hotkey, Space/Return via the keyboard cursor) so they all give
    // identical feedback. Checks stock emptiness FIRST — mirroring drawFromStock()'s own
    // internal order — so an exhausted stock is never misreported as "fill the empty
    // column first" when a tableau column also happens to be empty.
    private func attemptStockDraw() {
        viewModel.clearHint()
        guard !viewModel.state.stock.isEmpty else { return }
        if viewModel.hasEmptyTableauColumn {
            isShowingEmptyStockWarning = true
        } else {
            viewModel.drawFromStock()
        }
    }

    // Continuously refits the board's scale to the window's current content size — called
    // on every window resize (via WindowAccessor's onResize) and on every fresh deal (since
    // tableau.count never changes for Spider, gameGeneration is the signal that a new
    // deal's column depths need re-fitting). Never touches the window frame itself — a
    // pure property write, which is what keeps this loop-safe.
    private func recomputeScale() {
        guard let window = hostingWindow else { return }
        let contentSize = window.contentView?.frame.size ?? window.frame.size
        toolbarWidth = contentSize.width
        windowContentHeight = contentSize.height
        let cols: Double = 10.0
        let intrinsicWidth = cols * 128.0 + (cols - 1) * 18.0 + 40.0
        let intrinsicHeight = currentIntrinsicBoardHeight()
        let scaleX = contentSize.width / intrinsicWidth
        let scaleY = (contentSize.height - Self.toolbarHeight) / intrinsicHeight
        viewModel.zoomScale = min(2.0, max(0.3, min(scaleX, scaleY)))
    }

    // The board's true current height: the top row (181) + row spacing (16) + the
    // deepest tableau column's actual stacked height, replicating SpiderTableauView's
    // own per-column compression (offset shrinks toward a 12pt floor past 10 cards —
    // see `totalHeight(offset:)` in SpiderViews.swift). A flat worst-case constant here
    // (previously 1120, sized for a maximally deep column) leaves most real games —
    // which start much shallower — under-scaled, wasting available window height
    // instead of letting cards grow into it.
    private func currentIntrinsicBoardHeight() -> CGFloat {
        let deepestColumn = viewModel.state.tableau.map { pile -> CGFloat in
            guard !pile.cards.isEmpty else { return 181 }
            let cardCount = pile.cards.count
            let offset: CGFloat = cardCount > 10 ? max(12.0, 32.0 - CGFloat(cardCount - 10) * 1.5) : 32.0
            return CGFloat(cardCount - 1) * offset + 181
        }.max() ?? 181
        return 20 + 181 + 16 + deepestColumn
    }

    // Applies the window's opening size — called at app launch and every time this game
    // becomes active again. Only actually snaps the window to this game's default size
    // once, on the very first launch ever (HasLaunchedBefore); after that, switching
    // games never resizes the window, so manual resizing stays seamless across games.
    private func applyInitialWindowSize() {
        guard let window = hostingWindow else { return }
        window.contentMinSize = Self.minWindowSize

        if !UserDefaults.standard.bool(forKey: "HasLaunchedBefore") {
            UserDefaults.standard.set(true, forKey: "HasLaunchedBefore")
            let target = Self.defaultOpeningSize
            var newFrame = window.frameRect(forContentRect: NSRect(origin: .zero, size: target))
            if let visible = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame {
                newFrame.origin.x = visible.midX - newFrame.width / 2
                newFrame.origin.y = visible.midY - newFrame.height / 2
            }
            window.setFrame(newFrame, display: true)
        }

        recomputeScale()
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

    private func flashNoHintsBanner() {
        noHintsBannerTask?.cancel()
        withAnimation(.easeIn(duration: 0.15)) { showNoHintsBanner = true }
        let task = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.3)) { showNoHintsBanner = false }
        }
        noHintsBannerTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: task)
    }

    private func handleDragEnded() {
        let releaseLocation = CGPoint(
            x: dragLocation.x + dragOffset.width,
            y: dragLocation.y + dragOffset.height
        )

        var dropTarget: Pile? = nil

        // Smart Drop Detection: a candidate "accepts" the drag if the full dragged stack, or
        // some trimmed suffix of it (grabbed-end cards peeled off), forms a legal move. Spider
        // additionally requires the moved group to be a same-suit descending run
        // (isValidDragSequence) — a mixed-suit column slice is legal to look at but never
        // legal to drag as a group.
        func accepts(_ pile: Pile) -> Bool {
            SmartDrop.resolve(cards: draggedCards, isValidMove: { candidate in
                viewModel.isValidDragSequence(candidate) && viewModel.isValidMove(cards: candidate, to: pile)
            }) != nil
        }

        // Check Tableau piles first (only valid target columns in Spider)
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
                    let distanceX = abs(releaseLocation.x - frame.midX)
                    tableauCandidates.append(CandidateTableau(pile: tab, accepts: accepts(tab), distanceX: distanceX))
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

        if let target = dropTarget, let source = dragSourcePile,
           let resolved = SmartDrop.resolve(cards: draggedCards, isValidMove: { candidate in
               viewModel.isValidDragSequence(candidate) && viewModel.isValidMove(cards: candidate, to: target)
           }) {
            viewModel.moveCards(resolved, from: source, to: target)
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

// MARK: - Options Preference Dialog
struct SpiderOptionsView: View {
    @Bindable var viewModel: SpiderViewModel
    @Binding var isShowingStats: Bool
    @Binding var isPresented: Bool
    @Bindable var coordinator: AppCoordinator

    @State private var suitCount: Int
    @State private var isSoundEnabled: Bool
    @State private var hideHintButton: Bool
    @State private var noStressMode: Bool
    @State private var showPointHighlights: Bool
    let availableWidth: CGFloat
    let availableHeight: CGFloat

    init(viewModel: SpiderViewModel, isShowingStats: Binding<Bool>, isPresented: Binding<Bool>, coordinator: AppCoordinator, availableWidth: CGFloat = 2000, availableHeight: CGFloat = 900) {
        self.viewModel = viewModel
        self._isShowingStats = isShowingStats
        self._isPresented = isPresented
        self.coordinator = coordinator
        self.availableWidth = availableWidth
        self.availableHeight = availableHeight
        _suitCount = State(initialValue: viewModel.options.suitCount)
        _isSoundEnabled = State(initialValue: viewModel.options.isSoundEnabled)
        _hideHintButton = State(initialValue: viewModel.options.hideHintButton)
        _noStressMode = State(initialValue: viewModel.options.noStressMode)
        _showPointHighlights = State(initialValue: viewModel.options.showPointHighlights)
    }

    var body: some View {
        OptionsSheetShell(
            isPresented: $isPresented,
            coordinator: coordinator,
            availableWidth: availableWidth,
            availableHeight: availableHeight,
            onViewStats: { isShowingStats = true },
            onOK: {
                var updatedOpts = viewModel.options
                updatedOpts.suitCount = suitCount
                updatedOpts.isSoundEnabled = isSoundEnabled
                updatedOpts.hideHintButton = hideHintButton
                updatedOpts.noStressMode = noStressMode
                updatedOpts.showPointHighlights = showPointHighlights

                viewModel.options = updatedOpts
            }
        ) {
            Picker("Suits:", selection: $suitCount) {
                Text("1 (Spades)").tag(1)
                Text("2 (♠♥)").tag(2)
                Text("4 (Standard)").tag(4)
            }
            .pickerStyle(.segmented)
            .font(.system(.body))

            Divider()

            Toggle("Sound Effects", isOn: $isSoundEnabled)
                .font(.system(.body))

            Toggle("Hide Hint button", isOn: $hideHintButton)
                .font(.system(.body))

            Toggle("No Stress Mode", isOn: $noStressMode)
                .font(.system(.body))

            Toggle("Point Highlights", isOn: $showPointHighlights)
                .font(.system(.body))
        }
    }
}

// MARK: - Statistics View
struct SpiderStatsView: View {
    let viewModel: SpiderViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingResetConfirmation = false

    var body: some View {
        let stats = viewModel.currentModeStats
        
        VStack(spacing: 20) {
            Text("Spider Statistics (\(viewModel.options.suitCount) \(viewModel.options.suitCount == 1 ? "Suit" : "Suits"))")
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
                        var stats = viewModel.statistics
                        stats.statsBySuits[viewModel.options.suitCount] = SpiderModeStats()
                        viewModel.statistics = stats
                    }
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
        .frame(width: 360)
        .background(
            Color(NSColor.windowBackgroundColor)
                .overlay(Color.primary.opacity(0.04))
        )
    }
}
