import SwiftUI
import AppKit

public struct GameView: View {
    var viewModel: GameViewModel

    // The toolbar stays fixed size regardless of the board's scale; only the board below
    // it scales to fit the window.
    private static let toolbarHeight: CGFloat = 85

    // Hard floor the window can be dragged down to — the board's own scale (see
    // recomputeScale()) does all the work of fitting content to whatever size the window
    // actually is, so this only needs to keep the toolbar legible and a sliver of the
    // board visible; it's no longer tied to zoom or board content at all. If the player
    // drags the window down near this floor, cards may clip as the tableau grows deeper
    // during play — an accepted tradeoff of sizing the window down.
    static let minWindowSize = NSSize(width: 600, height: 330)
    // The size the window opens at when there's no saved "make current size the default"
    // preference — numerically the same generous, fully-cascaded-board size this app has
    // always opened at (previously computed as 85 + 950 + 24 + 28 height, max(1050,
    // boardWidth) width, both at the old zoom=1 baseline).
    static let defaultOpeningSize = NSSize(width: 1050, height: 1087)
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
    @State private var dragSnapshot: NSImage? = nil
    @State private var dragSourcePile: Pile? = nil
    @State private var dragOffset: CGSize = .zero
    @State private var dragLocation: CGPoint = .zero
    // pileFrames and dragLocation/dragOffset must both use .global coordinate space —
    // pileFrames is populated from GeometryReader's geo.frame(in: .global) below, and
    // every DragGesture feeding dragLocation/dragOffset is declared with
    // coordinateSpace: .global to match. Mismatched spaces silently break drop
    // hit-testing and the dragged-card overlay's positioning (same pattern as
    // Honeycomb's boardCellFrames — see HoneycombView.swift).
    @State private var pileFrames: [String: CGRect] = [:]
    @State private var isShuffling: Bool = false
    @State private var isDrawInFlight: Bool = false
    @State private var showIdleStockHint: Bool = false
    @State private var idleStockHintTask: DispatchWorkItem? = nil
    @State private var showNoHintsBanner: Bool = false
    @State private var noHintsBannerTask: DispatchWorkItem? = nil
    // Milestone/loading banners (viewModel.bannerQueue) — separate state from the
    // no-hints banner above since these are queued (possibly several in a row) rather
    // than a single fire-and-forget notice.
    @State private var showQueuedBanner: Bool = false
    @State private var queuedBannerText: String = ""
    @State private var queuedBannerTask: DispatchWorkItem? = nil
    @State private var isShowingOptions: Bool = false
    @State private var isShowingStats: Bool = false
    @State private var isShowingNewGameConfirm: Bool = false
    @State private var isShowingRestartConfirm: Bool = false
    @State private var dismissedAutocompleteBanner: Bool = false
    @State private var dismissedStuckBanner: Bool = false
    @State private var dismissedWinBanner: Bool = false
    @State private var winPulse: Bool = false
    @State private var showParticles: Bool = false
    @State private var pendingDrawMode: GameState.DrawMode? = nil
    @State private var hostingWindow: NSWindow? = nil
    @State private var zoomController: WindowZoomController? = nil
    @FocusState private var isBoardFocused: Bool
    @State private var keyMonitor: Any? = nil
    // DragGesture only tracks the primary (left) button — pressing right/middle mouse
    // mid-drag doesn't cancel it, but it also doesn't call .onEnded (AppKit swallows the
    // left-button event stream), leaving draggedCards stuck non-nil forever just like the
    // window-losing-key-status case cancelDrag() already guards against (see its comment).
    @State private var dragCancelMonitor: Any? = nil

    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator

    public init(viewModel: GameViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        let stackSpacing = viewModel.zoomScale > 1.0 ? max(4.0, 18.0 - 14.0 * (viewModel.zoomScale - 1.0)) : 18.0
        let columnCount = viewModel.state.tableau.count > 0 ? viewModel.state.tableau.count : 7
        let boardWidth = CGFloat(columnCount) * 128.0 + CGFloat(columnCount - 1) * stackSpacing + 40.0
        let boardHeight = currentIntrinsicBoardHeight()
        let scaledBoardWidth = boardWidth * viewModel.zoomScale
        let scaledBoardHeight = boardHeight * viewModel.zoomScale
        let resolvedFeltColorTheme: FeltColorTheme = coordinator.feltColor
        let resolvedShowFeltVignette: Bool = coordinator.showFeltVignette
        let resolvedCardBackTheme: String = coordinator.cardBackTheme
        let resolvedCustomCardColors: CustomCardColorGroup = coordinator.customCardColors

        return ZStack {
            // Board Background — a custom image if one's active, otherwise the app-wide
            // shared felt color on AppCoordinator (not per-game options).
            BackgroundLayerView()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            if resolvedShowFeltVignette { FeltVignetteView() }

            VStack(spacing: 0) {
                // Stationary Top Control and Status Panel (1.0x Scale)
                HStack(spacing: 20) {
                    // Game Selection Dropdown
                    GameSelectionDropdown(coordinator: coordinator)

                    // New Game Button
                    GameToolbarButton(
                        label: coordinator.L(.newGame), systemImage: "arrow.triangle.2.circlepath",
                        isCompact: toolbarWidth < Self.compactToolbarWidthThreshold
                    ) { requestNewGame() }

                    // Restart Button
                    GameToolbarButton(
                        label: coordinator.L(.restart), systemImage: "arrow.counterclockwise",
                        isCompact: toolbarWidth < Self.compactToolbarWidthThreshold
                    ) { isShowingRestartConfirm = true }

                    // Options Button
                    GameToolbarButton(
                        label: coordinator.L(.options), systemImage: "gearshape",
                        isCompact: toolbarWidth < Self.compactToolbarWidthThreshold
                    ) { isShowingOptions = true }

                    // Hint Button
                    if !coordinator.hideHintButton {
                        GameToolbarButton(
                            label: coordinator.L(.hint), systemImage: "lightbulb",
                            isCompact: toolbarWidth < Self.compactToolbarWidthThreshold,
                            disabled: viewModel.state.hasWon
                        ) {
                            if !viewModel.findHint() {
                                flashNoHintsBanner()
                            }
                        }
                        .keyboardShortcut("h", modifiers: .command)
                    }

                    // Undo Button
                    let canUndo = viewModel.canUndo && !viewModel.state.hasWon
                    GameToolbarButton(
                        label: coordinator.L(.undo), systemImage: "arrow.uturn.backward",
                        isCompact: toolbarWidth < Self.compactToolbarWidthThreshold,
                        disabled: !canUndo
                    ) { viewModel.undoLastAction() }
                    .keyboardShortcut("z", modifiers: .command)

                    Spacer()

                    if viewModel.options.isStatusBarVisible && !coordinator.noStressMode {
                        HStack(alignment: .bottom, spacing: 20) {
                            // Score / Bankroll
                            if viewModel.options.isVegasScoring {
                                StatusItemView(label: coordinator.L(.statusBankroll), value: viewModel.vegasBankrollString)
                            } else {
                                StatusItemView(label: coordinator.L(.scoreLabel), value: viewModel.scoreString)
                            }

                            // Moves
                            StatusItemView(label: coordinator.L(.movesLabel), value: String(viewModel.state.movesCount))

                            // Timer
                            StatusItemView(label: coordinator.L(.timeLabel), value: formatTime(viewModel.state.timerSeconds))
                        }
                    }
                    
                    Button(action: { requestNewGame(mode: .drawOne) }) { EmptyView() }
                        .keyboardShortcut("1", modifiers: .command).frame(width: 0, height: 0).opacity(0)

                    Button(action: { requestNewGame(mode: .drawThree) }) { EmptyView() }
                        .keyboardShortcut("3", modifiers: .command).frame(width: 0, height: 0).opacity(0)

                    Button(action: { requestNewGame() }) { EmptyView() }
                        .keyboardShortcut("n", modifiers: .command).frame(width: 0, height: 0).opacity(0)
                }
                .padding(.horizontal, 16)
                .padding(.top, 36) // Clear the macOS traffic light window controls
                .padding(.bottom, 6)
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
                            Text(coordinator.L(.stockExhausted))
                                .font(.system(size: 17, weight: .bold))
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(width: CardDimensions.width, height: CardDimensions.height)
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
                            draggedCardIDs: Set(draggedCards.map { $0.id }),
                            isFocused: viewModel.activeCursor?.pileId == pile.id,
                            isSelected: viewModel.selectedCardsSource == pile.id,
                            pointPopup: viewModel.pointPopup,
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
                            pointPopup: viewModel.pointPopup,
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
            .background(alignment: .center) {
                // Watermark anchored to the board VStack (piles row + tableau row)
                // instead of as a top-level layer over the whole window — that old layer
                // never tracked viewModel.zoomScale, so it drifted off the board at any
                // window size other than the one it was calibrated at. This VStack sits
                // inside the .scaleEffect(zoomScale) coordinate space applied below, so
                // the watermark now scales and repositions with the board automatically
                // on every resize. .background() doesn't propagate this Image's frame
                // size back into the VStack's own layout, so the 600x600 base has no
                // effect on surrounding layout. klondikeWatermarkScale/OffsetX/OffsetY
                // (mac only) reset to 1.0/0/0 pending a fresh eyeball pass against this
                // new anchor — same fix already applied to Blackjack/Video Poker/Honeycomb.
                if !coordinator.hideBee, let image = NSImage(named: "hcblack") {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 600, height: 600)
                        .scaleEffect(coordinator.klondikeWatermarkScale)
                        .offset(x: coordinator.klondikeWatermarkOffsetX, y: coordinator.klondikeWatermarkOffsetY)
                        .opacity(0.15)
                        .allowsHitTesting(false)
                }
            }
            .disabled(viewModel.isAutoplayRunning)
            .padding(.top, 20)

            }
            .frame(width: boardWidth, height: boardHeight, alignment: .topLeading)
            .scaleEffect(viewModel.zoomScale, anchor: .topLeading)
            // minHeight: 0 (instead of a rigid fixed height) lets this subtree actually
            // compress when the window is smaller than the toolbar + this board's full
            // scaled height combined — a hard fixed frame here reports zero flexibility to
            // the parent VStack, forcing 100% of any space deficit onto the toolbar
            // regardless of its layoutPriority(1), which is what was making the toolbar
            // shrink away below ~950pt of window height. Cards inside aren't clipped by
            // this frame's allocated size either way (no .clipped() here), so this only
            // changes how much space gets reserved for layout purposes, not how anything
            // actually renders.
            .frame(width: scaledBoardWidth, alignment: .topLeading)
            .frame(minHeight: 0, idealHeight: scaledBoardHeight, maxHeight: scaledBoardHeight, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Game-over overlay (both Vegas and non-Vegas) — a top-level sibling (not
            // nested inside the scaled board area) so its scrim spans the whole window
            // rather than being confined to the board's own reserved bounds. Matches the
            // victory overlay below.
            if viewModel.isStuck && !viewModel.state.hasWon && !dismissedStuckBanner {
                Color.black.opacity(0.45)

                VStack {
                    Spacer(minLength: 8)
                    ZStack(alignment: .topTrailing) {
                        VStack(spacing: 12) {
                            Text(coordinator.L(.gameOver))
                                .font(.system(size: 36, weight: .black))
                                .foregroundColor(.yellow)
                                .shadow(radius: 3)

                            Text(coordinator.L(.noMovesRemaining))
                                .font(.system(.headline))
                                .foregroundColor(.white)

                            if viewModel.options.isVegasScoring {
                                Text(coordinator.L(.finalBankrollFmt, viewModel.vegasBankrollString))
                                    .font(.system(.body))
                                    .foregroundColor(.yellow)
                            }

                            HStack(spacing: 12) {
                                Button(coordinator.L(.newGame)) {
                                    viewModel.startNewGame()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)
                                .buttonBorderShape(.capsule)

                                Button(coordinator.L(.restartGame)) {
                                    viewModel.restartCurrentGame()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)
                                .buttonBorderShape(.capsule)
                            }
                        }
                        .padding(.horizontal, 12)
                    .padding(.vertical, 24)
                        .frame(minWidth: 280)
                        .fixedSize(horizontal: true, vertical: true)
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

            // Autocomplete overlay — a top-level sibling, same reasoning as above.
            if viewModel.isAutocompleteAvailable && !viewModel.isAutoplayRunning && !dismissedAutocompleteBanner {
                Color.black.opacity(0.45)

                VStack {
                    Spacer(minLength: 8)
                    ZStack(alignment: .topTrailing) {
                        VStack(spacing: 12) {
                            Text(coordinator.L(.victoryGuaranteed))
                                .font(.system(size: 36, weight: .black))
                                .foregroundColor(.yellow)
                                .multilineTextAlignment(.center)
                            Text(coordinator.L(.autocompleteBodyKlondike))
                                .font(.system(.body))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            Button(coordinator.L(.autocompleteGame)) {
                                viewModel.runAutocomplete()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .buttonBorderShape(.capsule)
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

            // Victory overlay (Classic Bouncing Card Cascade) — a top-level sibling (not
            // nested inside the scaled board area) so it spans the whole window rather
            // than being confined to the board's own reserved bounds.
            if viewModel.state.hasWon {
                WinAnimationView(foundations: viewModel.state.foundations, pileFrames: pileFrames, zoomScale: viewModel.zoomScale) {
                    // Optional finish callback (e.g. log win)
                }
                .ignoresSafeArea()

                if !dismissedWinBanner {
                    Color.black.opacity(0.45)

                    VStack {
                        Spacer(minLength: 8)
                        ZStack(alignment: .topTrailing) {
                            VStack(spacing: 12) {
                                Text(coordinator.L(.youWin))
                                    .font(.system(size: 40, weight: .black))
                                    .foregroundColor(.yellow)
                                    .scaleEffect(winPulse ? 1.06 : 1.0)
                                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: winPulse)
                                    .onAppear { winPulse = true }
                                    .onDisappear { winPulse = false }

                                Text(winSummaryText)
                                    .font(.system(.body))
                                    .foregroundColor(.white)

                                Button(coordinator.L(.playAgain)) {
                                    viewModel.startNewGame()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)
                                .buttonBorderShape(.capsule)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 24)
                            .frame(maxWidth: 360)
                            .fixedSize(horizontal: false, vertical: true)
                            .background(Color.black.opacity(0.75))
                            .cornerRadius(12)
                            .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.5), radius: 16)

                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(10)
                                .onTapGesture {
                                    dismissedWinBanner = true
                                }
                        }
                        Spacer(minLength: 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // On top of the banner (not behind it) — matches the Blackjack/Video
                // Poker confetti ordering.
                WinParticleView(active: showParticles)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }
            if isShowingRestartConfirm {
                Color.black.opacity(0.45)

                VStack {
                    Spacer(minLength: 8)
                    ZStack(alignment: .topTrailing) {
                        VStack(spacing: 12) {
                            Text(coordinator.L(.restartConfirmTitle))
                                .font(.system(size: 36, weight: .black))
                                .foregroundColor(.yellow)
                                .shadow(radius: 3)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 12) {
                                Button(coordinator.L(.restartGame)) {
                                    isShowingRestartConfirm = false
                                    viewModel.restartCurrentGame()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)
                                .buttonBorderShape(.capsule)

                                Button(coordinator.L(.cancel)) {
                                    isShowingRestartConfirm = false
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.gray)
                                .buttonBorderShape(.capsule)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 24)
                        .frame(maxWidth: 420)
                        .fixedSize(horizontal: false, vertical: true)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(12)
                        .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.5), radius: 16)

                        Button(action: { isShowingRestartConfirm = false }) {
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

            if isShowingNewGameConfirm {
                Color.black.opacity(0.45)

                VStack {
                    Spacer(minLength: 8)
                    ZStack(alignment: .topTrailing) {
                        VStack(spacing: 12) {
                            Text(coordinator.L(.newGameConfirmTitle))
                                .font(.system(size: 36, weight: .black))
                                .foregroundColor(.yellow)
                                .shadow(radius: 3)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 12) {
                                Button(coordinator.L(.newGame)) {
                                    isShowingNewGameConfirm = false
                                    if let mode = pendingDrawMode {
                                        viewModel.state.drawMode = mode
                                        pendingDrawMode = nil
                                    }
                                    viewModel.startNewGame()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)
                                .buttonBorderShape(.capsule)

                                Button(coordinator.L(.cancel)) {
                                    isShowingNewGameConfirm = false
                                    pendingDrawMode = nil
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.gray)
                                .buttonBorderShape(.capsule)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 24)
                        .frame(maxWidth: 420)
                        .fixedSize(horizontal: false, vertical: true)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(12)
                        .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.5), radius: 16)

                        Button(action: {
                            isShowingNewGameConfirm = false
                            pendingDrawMode = nil
                        }) {
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

            if showNoHintsBanner {
                FlashBannerView(message: coordinator.L(.noHintsAvailable))
            }

            if showQueuedBanner {
                FlashBannerView(
                    message: queuedBannerText,
                    onDismiss: dismissQueuedBanner
                )
            }

            // Board-wide tap-catcher: while a manually-dismissed banner is up, the game
            // is "paused" — this transparent layer sits above every pile/card and turns
            // any board click (not just the banner itself) into a dismiss instead of
            // forwarding it to the card underneath. Kept permanently in the view tree
            // (never inserted/removed via `if`) and gated purely by allowsHitTesting —
            // conditionally inserting/removing an interactive view here left its hit-test
            // region stuck active after the animated removal (only a forced relayout,
            // like opening/closing Options, cleared it), blocking every card click.
            Color.clear
                .contentShape(Rectangle())
                .allowsHitTesting(showQueuedBanner)
                .onTapGesture { dismissQueuedBanner() }

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

            // HotkeyLegendView(text: coordinator.L(.hotkeyLegendKlondike))
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
            dragCancelMonitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .otherMouseDown]) { event in
                if !draggedCards.isEmpty {
                    cancelDrag()
                }
                return event
            }
        }
        .onDisappear {
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
                keyMonitor = nil
            }
            if let monitor = dragCancelMonitor {
                NSEvent.removeMonitor(monitor)
                dragCancelMonitor = nil
            }
            idleStockHintTask?.cancel()
            idleStockHintTask = nil
            noHintsBannerTask?.cancel()
            noHintsBannerTask = nil
        }
        .onChange(of: viewModel.state.movesCount) {
            scheduleIdleStockHint()
            viewModel.scheduleIdleActionCheck()
        }
        .onChange(of: coordinator.hideHintButton) {
            scheduleIdleStockHint()
        }
        .onChange(of: viewModel.gameGeneration) {
            scheduleIdleStockHint()
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
                        OptionsView(viewModel: viewModel, isPresented: $isShowingOptions, coordinator: coordinator, availableWidth: toolbarWidth, availableHeight: windowContentHeight, onViewStats: {
                            isShowingStats = true
                        })
                    )
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $isShowingStats) {
            StatsView(viewModel: viewModel)
        }

        .onChange(of: viewModel.isAutocompleteAvailable) { _, newVal in if newVal { dismissedAutocompleteBanner = false } }
        .onChange(of: viewModel.isStuck) { _, newVal in if newVal { dismissedStuckBanner = false } }
        .onChange(of: viewModel.state.hasWon) { _, newVal in
            if newVal {
                dismissedWinBanner = false
                showParticles = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { showParticles = false }
            }
        }
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
            case .same, .plus, .suddenDeath:
                break
            }
        }
        .onChange(of: viewModel.flashBannerTrigger) { _, _ in
            guard let text = viewModel.flashBanner else { return }
            flashQueuedBanner(text)
        }
        .onAppear {
            applyInitialWindowSize()
            viewModel.checkLoadingBanner()
        }
        .background(WindowAccessor(callback: { window in
            self.hostingWindow = window
            self.zoomController = WindowZoomController(window: window)
            coordinator.activeWindow = window
            applyInitialWindowSize()
        }, onResize: recomputeScale))
        .onChange(of: viewModel.state.tableau.count) { recomputeScale() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { note in
            guard (note.object as? NSWindow) == hostingWindow, !draggedCards.isEmpty else { return }
            cancelDrag()
        }
        // The board already has its own selection/hint highlighting (KeyboardFocusHighlightModifier);
        // the system's automatic focus ring is redundant and recomputes an expensive blurred bitmap
        // (rips_f_BlurRingRoundedDilation) every time the board redraws, which shows up as a
        // main-thread stall on toolbar controls like the game-selection dropdown.
        .focusEffectDisabled()
    }

    private func scheduleIdleStockHint() {
        let eligible = !coordinator.hideHintButton
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
            guard !coordinator.hideHintButton,
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

    private func flashNoHintsBanner() {
        noHintsBannerTask?.cancel()
        withAnimation(.easeIn(duration: 0.15)) { showNoHintsBanner = true }
        let task = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.3)) { showNoHintsBanner = false }
        }
        noHintsBannerTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: task)
    }

    // Shared by the auto-dismiss timer and the manual-dismiss tap handlers (banner tap,
    // board tap-catcher) so both paths hide the banner and resume the queue identically.
    private func dismissQueuedBanner() {
        queuedBannerTask?.cancel()
        queuedBannerTask = nil
        withAnimation(.easeOut(duration: 0.3)) { showQueuedBanner = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            viewModel.advanceBannerQueue()
        }
    }

    private func flashQueuedBanner(_ text: String) {
        queuedBannerTask?.cancel()
        queuedBannerText = text
        withAnimation(.easeIn(duration: 0.15)) { showQueuedBanner = true }
        // Manually Dismiss Banners: the game is "paused" on this banner — no timer, it
        // stays up until the player taps it or a card (see the board tap-catcher above).
        guard !coordinator.manuallyDismissBanners else {
            queuedBannerTask = nil
            return
        }
        let task = DispatchWorkItem { [self] in dismissQueuedBanner() }
        queuedBannerTask = task
        // The very first loading banner of an app session gets extra time to actually be
        // read — see BannerCatalog.consumeAppLaunchLoadingFlag().
        let duration = BannerCatalog.consumeAppLaunchLoadingFlag() ? 3.0 : 2.0
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: task)
    }

    private func requestNewGame(mode: GameState.DrawMode? = nil) {
        if let mode { pendingDrawMode = mode }
        if viewModel.state.movesCount == 0 {
            if let mode = pendingDrawMode {
                viewModel.state.drawMode = mode
                pendingDrawMode = nil
            }
            viewModel.startNewGame()
        } else {
            isShowingNewGameConfirm = true
        }
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
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
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
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                isDrawInFlight = false
            }
        }
    }

    // Continuously refits the board's scale to the window's current content size — called
    // on every window resize (via WindowAccessor's onResize) and whenever the board's own
    // intrinsic size changes without the window moving (tableau column count). Toolbar
    // height is excluded from the height side of the fit so the board never scales large
    // enough to push itself under the toolbar. Never touches the window frame itself —
    // this is a pure property write, which is what keeps this loop-safe (see GameView's
    // WindowAccessor usage: nothing observes zoomScale to trigger a resize anymore).
    private func recomputeScale() {
        guard let window = hostingWindow else { return }
        let contentSize = window.contentView?.frame.size ?? window.frame.size
        toolbarWidth = contentSize.width
        windowContentHeight = contentSize.height
        let cols = CGFloat(max(viewModel.state.tableau.count, 7))
        let intrinsicWidth = cols * 128.0 + (cols - 1) * 18.0 + 40.0
        let intrinsicHeight = currentIntrinsicBoardHeight()
        viewModel.zoomScale = WindowFit.scale(
            contentSize: contentSize,
            intrinsicSize: CGSize(width: intrinsicWidth, height: intrinsicHeight),
            heightInset: Self.toolbarHeight)
    }

    // The board's true current height: the piles row (181) + row spacing (16) + the
    // deepest tableau column's actual stacked height. A flat worst-case constant here
    // (previously 950, sized for a maximally deep 13-card cascade) leaves most real
    // games with much shorter tableaus under-scaled, wasting available window height
    // instead of letting cards grow into it — matches the same per-card offsets
    // (`offsetForCard`) TableauPileView already uses for its own layout, in PileView.swift.
    private func currentIntrinsicBoardHeight() -> CGFloat {
        let deepestColumn = viewModel.state.tableau.map { pile -> CGFloat in
            guard !pile.cards.isEmpty else { return 181 }
            var offset: CGFloat = 0
            for card in pile.cards.dropLast() {
                offset += card.faceUp ? 32 : 20
            }
            return offset + 181
        }.max() ?? 181
        return 20 + 181 + 16 + deepestColumn
    }

    // Applies the window's opening size — called at app launch and every time this game
    // becomes active again. Only actually snaps the window to this game's default size
    // once, on the very first launch ever (HasLaunchedBefore); after that, switching
    // games never resizes the window, so manual resizing stays seamless across games.
    private func applyInitialWindowSize() {
        guard let window = hostingWindow else { return }
        window.applyInitialSize(minSize: Self.minWindowSize, defaultOpeningSize: Self.defaultOpeningSize)
        recomputeScale()
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

        // Smart Drop Detection: a candidate "accepts" the drag if the full dragged stack, or
        // some trimmed suffix of it (grabbed-end cards peeled off), forms a legal move.
        func accepts(_ pile: Pile) -> Bool {
            SmartDrop.resolve(cards: draggedCards, isValidMove: { viewModel.isValidMove(cards: $0, to: pile) }) != nil
        }

        // 1. Check Tableau piles first (using horizontal alignment, open vertical bottoms, and prioritizing columns that accept the cards)
        struct CandidateTableau {
            let pile: Pile
            let accepts: Bool
            let distanceX: CGFloat
        }

        var tableauCandidates: [CandidateTableau] = []
        // Iterate the ordered tableau array, not pileFrames, so candidate order is
        // deterministic regardless of Dictionary iteration order — the sort below still
        // picks a winner by accepts/distanceX, but building the candidate list itself
        // from pileFrames directly would make ties depend on undefined dict ordering.
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
                        let dx = releaseLocation.x - frame.midX
                        let dy = releaseLocation.y - frame.midY
                        let dist = sqrt(dx*dx + dy*dy)
                        topCandidates.append(CandidateTopRow(pile: foundation, accepts: accepts(foundation), distance: dist))
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
                        let dx = releaseLocation.x - frame.midX
                        let dy = releaseLocation.y - frame.midY
                        let dist = sqrt(dx*dx + dy*dy)
                        topCandidates.append(CandidateTopRow(pile: pile, accepts: accepts(pile), distance: dist))
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
        
        if let target = dropTarget, let source = dragSourcePile,
           let resolved = SmartDrop.resolve(cards: draggedCards, isValidMove: { viewModel.isValidMove(cards: $0, to: target) }) {
            viewModel.clearHint()
            viewModel.moveCards(resolved, from: source, to: target)
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
            ? coordinator.L(.bankrollFmt, viewModel.vegasBankrollString)
            : coordinator.L(.scoreFmt, viewModel.scoreString)
        guard !coordinator.noStressMode else { return scorePart }
        return coordinator.L(.winSummaryWithTimeFmt, scorePart, formatTime(viewModel.state.timerSeconds))
    }
}

// MARK: - UI Subviews

struct StatusItemView: View {
    let label: String
    let value: String

    var body: some View {
        // fixedSize forces each Text to claim its true natural width rather than being
        // negotiated down when the toolbar HStack is squeezed — without it, SwiftUI
        // doesn't split any shortfall evenly across SCORE/MOVES/TIME, it takes it out of
        // whichever needs the most room (TIME's "00:00" is the widest of the three), so
        // TIME alone would truncate even while there's visible slack elsewhere in the row.
        VStack(spacing: 2) {
            Text(label)
                .font(.display(13))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundColor(.white.opacity(0.6))
            Text(value)
                .font(.system(size: 20, weight: .black))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundColor(.white)
        }

    }
}

struct HintHighlightModifier: ViewModifier {
    var isHighlighted: Bool
    @State private var phase: Double = 0.0
    
    func body(content: Content) -> some View {
        content
            .modifier(HintHighlightAnimatable(isHighlighted: isHighlighted, phase: phase))
            .onChange(of: isHighlighted) {
                if isHighlighted {
                    phase = 0.0
                    withAnimation(.linear(duration: 1.8)) {
                        phase = 1.0
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.1)) {
                        phase = 0.0
                    }
                }
            }
    }
}

struct HintHighlightAnimatable: AnimatableModifier {
    @Environment(AppCoordinator.self) private var coordinator
    var isHighlighted: Bool
    var phase: Double

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func body(content: Content) -> some View {
        // 2 full flashes requires 2 full cycles (4 * pi).
        let opacity = isHighlighted ? (1 - cos(phase * .pi * 4)) / 2 : 0.0
        let highlightColor = coordinator.customCardColors.hintHighlightColor

        return content
            .overlay(
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(highlightColor, lineWidth: 4)
                        .shadow(color: highlightColor, radius: 4)
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(highlightColor, lineWidth: 4)
                        .shadow(color: highlightColor, radius: 4)
                }
                .opacity(opacity)
            )
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
    @State private var honeyMode: Bool
    @State private var manuallyDismissBanners: Bool
    @State private var hideBee: Bool

    let onViewStats: (() -> Void)?
    let availableWidth: CGFloat
    let availableHeight: CGFloat

    init(viewModel: GameViewModel, isPresented: Binding<Bool>, coordinator: AppCoordinator, availableWidth: CGFloat = 2000, availableHeight: CGFloat = 900, onViewStats: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self._isPresented = isPresented
        self.coordinator = coordinator
        self.onViewStats = onViewStats
        self.availableWidth = availableWidth
        self.availableHeight = availableHeight
        _isStatusBarVisible = State(initialValue: viewModel.options.isStatusBarVisible)
        _isSoundEnabled = State(initialValue: coordinator.isSoundEnabled)
        _isVegasScoring = State(initialValue: viewModel.options.isVegasScoring)
        _drawMode = State(initialValue: viewModel.state.drawMode)
        _hideHintButton = State(initialValue: coordinator.hideHintButton)
        _noStressMode = State(initialValue: coordinator.noStressMode)
        _honeyMode = State(initialValue: coordinator.honeyMode)
        _manuallyDismissBanners = State(initialValue: coordinator.manuallyDismissBanners)
        _hideBee = State(initialValue: coordinator.hideBee)
    }

    var body: some View {
        OptionsSheetShell(
            isPresented: $isPresented,
            coordinator: coordinator,
            availableWidth: availableWidth,
            availableHeight: availableHeight,
            onViewStats: { onViewStats?() },
            onOK: {
                var updatedOpts = viewModel.options
                updatedOpts.isStatusBarVisible = isStatusBarVisible
                updatedOpts.isVegasScoring = isVegasScoring

                updatedOpts.drawMode = drawMode
                if viewModel.state.drawMode != drawMode {
                    viewModel.state.drawMode = drawMode
                    viewModel.startNewGame()
                }

                viewModel.options = updatedOpts
                // Sound/No Stress Mode are app-wide now (AppCoordinator) — pushing the
                // edit there (rather than leaving it only on this game's own options)
                // is what makes it actually apply everywhere instead of getting quietly
                // reverted the next time any game switch reasserts the coordinator's
                // value over this one.
                coordinator.isSoundEnabled = isSoundEnabled
                coordinator.noStressMode = noStressMode
                coordinator.honeyMode = honeyMode
                coordinator.manuallyDismissBanners = manuallyDismissBanners
                coordinator.hideHintButton = hideHintButton
                coordinator.hideBee = hideBee
            }
        ) {
            Picker(coordinator.L(.drawModeLabel), selection: $drawMode) {
                Text(coordinator.L(.drawOne)).tag(GameState.DrawMode.drawOne)
                Text(coordinator.L(.drawThree)).tag(GameState.DrawMode.drawThree)
            }
            .pickerStyle(.segmented)

            Divider()

            Toggle(coordinator.L(.soundEffects), isOn: $isSoundEnabled)
                .font(.system(.body))

            Toggle(coordinator.L(.vegasScoringMode), isOn: $isVegasScoring)
                .font(.system(.body))

            Toggle(coordinator.L(.hideHintButton), isOn: $hideHintButton)
                .font(.system(.body))

            Toggle(coordinator.L(.manuallyDismissBanners), isOn: $manuallyDismissBanners)
                .font(.system(.body))

            Toggle(coordinator.L(.noStressMode), isOn: $noStressMode)
                .help(coordinator.L(.noStressModeTooltip))
                .font(.system(.body))

            Toggle(coordinator.L(.honeyMode), isOn: $honeyMode)
                .help(coordinator.L(.honeyModeTooltip))
                .font(.system(.body))

            Toggle(coordinator.L(.hideBee), isOn: $hideBee)
                .font(.system(.body))

            // Live-updating (bound directly to coordinator, not local @State + onOK) so
            // the bee visibly resizes on the board behind this sheet while dragging —
            // matches how the watermark's own scale is stored/persisted (didSet ->
            // UserDefaults), unlike every other control on this sheet which stages its
            // edit in @State until OK. Only shown when the bee isn't hidden.
            if !hideBee {
                Slider(value: $coordinator.klondikeWatermarkScale, in: 0.5...4.0) {
                    Text(coordinator.L(.beeSize))
                }
                .font(.system(.body))
            }
        }
    }
}

struct StatsView: View {
    let viewModel: GameViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(AppCoordinator.self) private var coordinator
    @State private var showingResetConfirmation = false

    var body: some View {
        let stats = viewModel.statistics

        VStack(spacing: 20) {
            Text(coordinator.L(.klondikeStatisticsTitle))
                .font(.system(size: 16, weight: .bold))
                .padding(.top, 12)

            Divider()

            VStack(spacing: 0) {
                statPairRow(coordinator.L(.gamesPlayedColon), "\(stats.gamesPlayed)",
                            coordinator.L(.currentStreakColon), "\(stats.currentStreak)")
                Divider()
                statPairRow(coordinator.L(.gamesWonColon), "\(stats.gamesWon)",
                            coordinator.L(.longestStreakColon), "\(stats.longestStreak)")
                Divider()
                statPairRow(coordinator.L(.highScoreColon), viewModel.highScoreString,
                            coordinator.L(.avgWinningTimeColon), stats.winningGamesCount > 0 ? String(format: "%.0fs", stats.averageWinningTime) : "--")
                Divider()
                statPairRow(coordinator.L(.winPercentageColon), String(format: "%.1f%%", stats.winPercentage),
                            coordinator.L(.fastestWinColon), stats.shortestWinTime > 0 ? "\(stats.shortestWinTime)s" : "--")

                // Vegas bankroll doesn't pair with anything else in the grid above, so it
                // gets its own full-width row rather than forcing a lopsided 5th pair.
                if viewModel.options.isVegasScoring {
                    Divider()
                    HStack {
                        Text(coordinator.L(.vegasBankrollLabel))
                        Spacer()
                        Text(viewModel.vegasBankrollString)
                            .foregroundColor(viewModel.vegasBankroll >= 0 ? .green : .red)
                    }
                    .font(.system(.body))
                    .padding(.vertical, 10)
                }
            }
            .padding(.horizontal, 24)

            Divider()

            HStack {
                Button(coordinator.L(.resetStats)) {
                    showingResetConfirmation = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .alert(coordinator.L(.resetStatisticsTitle), isPresented: $showingResetConfirmation) {
                    Button(coordinator.L(.reset), role: .destructive) {
                        let emptyStats = GameStatistics()
                        viewModel.statistics = emptyStats
                        viewModel.resetStatistics()
                    }
                    Button(coordinator.L(.cancel), role: .cancel) {}
                } message: {
                    Text(coordinator.L(.resetStatisticsBodyGeneric))
                }

                Spacer()

                Button(coordinator.L(.close)) {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(width: 440)
        .background {
            // Fixed max size (not left to scale with the frame) — the panel just widened
            // for the two-column stat grid above, and an unconstrained .scaledToFit grows
            // to fill that extra width, overpowering the stat text instead of sitting
            // behind it as a watermark.
            if !coordinator.hideBee, let image = NSImage(named: "Solibee") {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 220, maxHeight: 220)
                    .opacity(0.15)
            }
        }
        .background(
            Color(NSColor.windowBackgroundColor)
                .overlay(Color.primary.opacity(0.04))
        )
    }

    // One grid row: two StatRowViews side by side, each taking equal width so the
    // divider rules above/below line up across both columns.
    @ViewBuilder
    private func statPairRow(_ label1: String, _ value1: String, _ label2: String, _ value2: String) -> some View {
        HStack(alignment: .top, spacing: 24) {
            StatRowView(label: label1, value: value1, emphasized: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            StatRowView(label: label2, value: value2, emphasized: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10)
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

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Always win the hit-test so no NSView-backed child (e.g. AnimatedGIFView)
        // can intercept clicks before us.
        return bounds.contains(point) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        action?()
        super.mouseDown(with: event)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

