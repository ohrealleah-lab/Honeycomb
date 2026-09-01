import SwiftUI
import AppKit

public struct BeecellView: View {
    var viewModel: BeecellViewModel

    // The toolbar stays fixed size regardless of the board's scale; only the board below
    // it scales to fit the window.
    private static let toolbarHeight: CGFloat = 89

    // Hard floor the window can be dragged down to — the board's own scale (see
    // recomputeScale()) fits content to whatever size the window actually is, so this
    // only needs to keep the toolbar legible and a sliver of the board visible; no longer
    // tied to zoom, deck count, or board content. If the player drags the window down
    // near this floor, cards may clip as the tableau grows during play — an accepted
    // tradeoff of sizing the window down.
    static let minWindowSize = NSSize(width: 600, height: 330)
    // The size the window opens at when there's no saved "make current size the default"
    // preference — numerically the same generous size this app has always opened at for
    // the default 1-deck game (previously 89 + 950 + 24 + 28 height, boardWidth width, at
    // the old zoom=1 baseline).
    static let defaultOpeningSize = NSSize(width: 1190, height: 1091)
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
    // pileFrames and dragLocation/dragOffset must both use .global coordinate space —
    // pileFrames is populated from GeometryReader's geo.frame(in: .global), and every
    // DragGesture feeding dragLocation/dragOffset must use coordinateSpace: .global to
    // match. Mismatched spaces silently break drop hit-testing and the dragged-card
    // overlay's positioning (same pattern as Klondike's GameView.swift and Honeycomb's
    // boardCellFrames in HoneycombView.swift).
    @State private var pileFrames: [String: CGRect] = [:]
    @State private var isShowingOptions: Bool = false
    @State private var isShowingStats: Bool = false
    @State private var isShowingNewGameConfirm: Bool = false
    @State private var pendingDeckCount: Int? = nil
    @State private var dismissedAutocompleteBanner: Bool = false
    @State private var dismissedStuckBanner: Bool = false
    @State private var dismissedWinBanner: Bool = false
    @State private var winPulse: Bool = false
    @State private var showParticles: Bool = false
    @State private var showNoHintsBanner: Bool = false
    @State private var noHintsBannerTask: DispatchWorkItem? = nil
    // Milestone/loading banners (viewModel.bannerQueue) — separate state from the
    // no-hints banner above since these are queued (possibly several in a row) rather
    // than a single fire-and-forget notice.
    @State private var showQueuedBanner: Bool = false
    @State private var queuedBannerText: String = ""
    @State private var queuedBannerTask: DispatchWorkItem? = nil
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

    public init(viewModel: BeecellViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        let stackSpacing = viewModel.zoomScale > 1.0 ? max(4.0, 18.0 - 14.0 * (viewModel.zoomScale - 1.0)) : 18.0
        let numCols = Double(viewModel.options.deckCount == 1 ? 8 : 10)
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

            GameWatermarkView()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            if coordinator.showFeltVignette { FeltVignetteView() }


            VStack(spacing: 0) {
                // Top Control and Status Panel
                HStack(spacing: 20) {
                    // Game Selection Dropdown
                    GameSelectionDropdown(coordinator: coordinator)

                    // New Game Button
                    GameToolbarButton(
                        label: coordinator.L(.newGame), systemImage: "arrow.triangle.2.circlepath",
                        isCompact: toolbarWidth < Self.compactToolbarWidthThreshold
                    ) { requestNewGame() }

                    // Options
                    GameToolbarButton(
                        label: coordinator.L(.options), systemImage: "gearshape",
                        isCompact: toolbarWidth < Self.compactToolbarWidthThreshold
                    ) { isShowingOptions = true }

                    // Hint
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

                    // Undo
                    let canUndo = viewModel.canUndo && !viewModel.state.hasWon
                    GameToolbarButton(
                        label: coordinator.L(.undo), systemImage: "arrow.uturn.backward",
                        isCompact: toolbarWidth < Self.compactToolbarWidthThreshold,
                        disabled: !canUndo
                    ) { viewModel.undoLastAction() }
                    .keyboardShortcut("z", modifiers: .command)

                    Spacer()
                    
                    if !coordinator.noStressMode {
                        HStack(alignment: .bottom, spacing: 20) {
                            StatusItemView(label: coordinator.L(.scoreLabel), value: viewModel.scoreString)
                            StatusItemView(label: coordinator.L(.movesLabel), value: String(viewModel.state.movesCount))
                            StatusItemView(label: coordinator.L(.timeLabel), value: formatTime(viewModel.state.timerSeconds))
                        }
                    }
                    
                    Button(action: { requestNewGame() }) { EmptyView() }
                        .keyboardShortcut("n", modifiers: .command).frame(width: 0, height: 0).opacity(0)

                    Button(action: { requestNewGame(deckCount: 1) }) { EmptyView() }
                        .keyboardShortcut("1", modifiers: .command).frame(width: 0, height: 0).opacity(0)

                    Button(action: { requestNewGame(deckCount: 2) }) { EmptyView() }
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
                                            pointPopup: viewModel.pointPopup,
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
                                            pointPopup: viewModel.pointPopup,
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
                                            pointPopup: viewModel.pointPopup,
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
                    .disabled(viewModel.isAutoplayRunning)
                    .padding(.top, 20)
                    
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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Stuck overlay — a top-level sibling (not nested inside the scaled board
            // area) so its scrim spans the whole window rather than being confined to
            // the board's own reserved bounds. Matches the victory overlay below.
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
                            Text(coordinator.L(.autocompleteBodyOther))
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

            // Victory Cascade Overlay (reusing SoliBee's bouncing card animation) — a
            // top-level sibling (not nested inside the scaled board area) so it spans the
            // whole window rather than being confined to the board's own reserved bounds.
            if viewModel.state.hasWon {
                WinAnimationView(foundations: viewModel.state.foundations, pileFrames: pileFrames, zoomScale: viewModel.zoomScale) {
                    // Optional finish callback
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

            if showNoHintsBanner {
                FlashBannerView(message: coordinator.L(.noHintsAvailable))
            }

            if showQueuedBanner {
                FlashBannerView(
                    message: queuedBannerText,
                    onDismiss: dismissQueuedBanner
                )
            }

            // Kept permanently in the tree, gated by allowsHitTesting only — see
            // GameView.swift's matching comment for why conditional insert/remove here
            // left the hit-test region stuck active.
            Color.clear
                .contentShape(Rectangle())
                .allowsHitTesting(showQueuedBanner)
                .onTapGesture { dismissQueuedBanner() }

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

            // HotkeyLegendView(text: coordinator.L(.hotkeyLegendBeecell))
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
                        BeecellOptionsView(viewModel: viewModel, isShowingStats: $isShowingStats, isPresented: $isShowingOptions, coordinator: coordinator, availableWidth: toolbarWidth, availableHeight: windowContentHeight)
                    )
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $isShowingStats) {
            BeecellStatsView(viewModel: viewModel)
        }
        .confirmationDialog(coordinator.L(.newGameConfirmTitle), isPresented: $isShowingNewGameConfirm) {
            Button(coordinator.L(.cancel), role: .cancel) { pendingDeckCount = nil }
            Button(coordinator.L(.newGame), role: .destructive) {
                if let deck = pendingDeckCount { viewModel.options.deckCount = deck; pendingDeckCount = nil }
                viewModel.startNewGame()
            }
        }
        .onChange(of: viewModel.state.movesCount) {
            viewModel.scheduleIdleActionCheck()
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
        .onChange(of: viewModel.options.deckCount) { withAnimation(.easeInOut(duration: 0.2)) { recomputeScale() } }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { note in
            guard (note.object as? NSWindow) == hostingWindow, !draggedCards.isEmpty else { return }
            cancelDrag()
        }
        // See GameView.swift: the system focus ring recomputes an expensive blurred
        // bitmap on every board redraw, which happens on every state mutation.
        .focusEffectDisabled()
    }

    // Continuously refits the board's scale to the window's current content size — called
    // on every window resize (via WindowAccessor's onResize) and whenever deckCount
    // changes without the window moving. Never touches the window frame itself — a pure
    // property write, which is what keeps this loop-safe.
    private func recomputeScale() {
        guard let window = hostingWindow else { return }
        let contentSize = window.contentView?.frame.size ?? window.frame.size
        toolbarWidth = contentSize.width
        windowContentHeight = contentSize.height
        let cols = Double(viewModel.options.deckCount == 1 ? 8 : 10)
        let intrinsicWidth = cols * 128.0 + (cols - 1) * 18.0 + 40.0
        let intrinsicHeight = currentIntrinsicBoardHeight()
        viewModel.zoomScale = WindowFit.scale(
            contentSize: contentSize,
            intrinsicSize: CGSize(width: intrinsicWidth, height: intrinsicHeight),
            heightInset: Self.toolbarHeight)
    }

    // The board's true current height: the top row (freecells/foundations — a single
    // 181pt row for 1 deck, two 181pt rows plus 8pt spacing for 2 decks) + row spacing
    // (16) + the deepest tableau column's actual stacked height (all Beecell cards are
    // face-up, 32pt per card). A flat worst-case constant here (previously 950/1120 by
    // deck count) leaves shallower tableaus under-scaled, wasting available window
    // height instead of letting cards grow into it.
    private func currentIntrinsicBoardHeight() -> CGFloat {
        let topRowHeight: CGFloat = viewModel.options.deckCount == 1 ? 181 : (181 * 2 + 8)
        let deepestColumn = viewModel.state.tableau.map { pile -> CGFloat in
            guard !pile.cards.isEmpty else { return 181 }
            return CGFloat(pile.cards.count - 1) * 32 + 181
        }.max() ?? 181
        return 20 + topRowHeight + 16 + deepestColumn
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

    private func requestNewGame(deckCount: Int? = nil) {
        if let count = deckCount { pendingDeckCount = count }
        if viewModel.state.movesCount == 0 {
            if let count = pendingDeckCount {
                viewModel.options.deckCount = count
                pendingDeckCount = nil
            }
            viewModel.startNewGame()
        } else {
            isShowingNewGameConfirm = true
        }
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

        // 1. Check Tableau piles first
        struct CandidateTableau {
            let pile: Pile
            let accepts: Bool
            let distanceX: CGFloat
        }

        var tableauCandidates: [CandidateTableau] = []
        // Iterate the ordered tableau array, not pileFrames, so candidate order is
        // deterministic regardless of Dictionary iteration order (see GameView.swift).
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
                        let dx = releaseLocation.x - frame.midX
                        let dy = releaseLocation.y - frame.midY
                        let dist = sqrt(dx*dx + dy*dy)
                        topCandidates.append(CandidateTopRow(pile: cell, accepts: accepts(cell), distance: dist))
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
                        let dx = releaseLocation.x - frame.midX
                        let dy = releaseLocation.y - frame.midY
                        let dist = sqrt(dx*dx + dy*dy)
                        topCandidates.append(CandidateTopRow(pile: foundation, accepts: accepts(foundation), distance: dist))
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
        let scorePart = coordinator.L(.scoreFmt, viewModel.scoreString)
        guard !coordinator.noStressMode else { return scorePart }
        return coordinator.L(.winSummaryWithTimeFmt, scorePart, formatTime(viewModel.state.timerSeconds))
    }

}

// MARK: - Options Preference Dialog
struct BeecellOptionsView: View {
    @Bindable var viewModel: BeecellViewModel
    @Binding var isShowingStats: Bool
    @Binding var isPresented: Bool
    @Bindable var coordinator: AppCoordinator

    @State private var deckCount: Int
    // noStressMode stays locally buffered (unlike Sound/Honey Mode/Manually Dismiss
    // Banners/Hide Hint Button, which OptionsSheetShell now live-binds+reverts) —
    // see OptionsSheetShell's comment on originalIsSoundEnabled for why.
    @State private var noStressMode: Bool
    @State private var hideBee: Bool
    let availableWidth: CGFloat
    let availableHeight: CGFloat

    init(viewModel: BeecellViewModel, isShowingStats: Binding<Bool>, isPresented: Binding<Bool>, coordinator: AppCoordinator, availableWidth: CGFloat = 2000, availableHeight: CGFloat = 900) {
        self.viewModel = viewModel
        self._isShowingStats = isShowingStats
        self._isPresented = isPresented
        self.coordinator = coordinator
        self.availableWidth = availableWidth
        self.availableHeight = availableHeight
        _deckCount = State(initialValue: viewModel.options.deckCount)
        _noStressMode = State(initialValue: coordinator.noStressMode)
        _hideBee = State(initialValue: coordinator.hideBee)
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
                updatedOpts.deckCount = deckCount

                viewModel.options = updatedOpts
                // No Stress Mode is app-wide now (AppCoordinator) — pushing the edit
                // there is what makes it actually apply everywhere. Sound/Honey Mode/
                // Manually Dismiss Banners/Hide Hint Button/hideBee are already live via
                // OptionsSheetShell's direct $coordinator.X bindings below.
                coordinator.noStressMode = noStressMode
                coordinator.hideBee = hideBee
            }
        ) {
            Picker(coordinator.L(.toggleGameModeLabel), selection: $deckCount) {
                Text(coordinator.L(.option1deck)).tag(1)
                Text(coordinator.L(.option2deck)).tag(2)
            }
            .pickerStyle(.segmented)

            Divider()

            Toggle(coordinator.L(.soundEffects), isOn: $coordinator.isSoundEnabled)
                .font(.system(.body))

            Toggle(coordinator.L(.hideHintButton), isOn: $coordinator.hideHintButton)
                .font(.system(.body))

            Toggle(coordinator.L(.manuallyDismissBanners), isOn: $coordinator.manuallyDismissBanners)
                .font(.system(.body))

            Toggle(coordinator.L(.noStressMode), isOn: $noStressMode)
                .help(coordinator.L(.noStressModeTooltip))
                .font(.system(.body))

            Toggle(coordinator.L(.honeyMode), isOn: $coordinator.honeyMode)
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
                Slider(value: $coordinator.beecellWatermarkScale, in: 0.5...4.0) {
                    Text(coordinator.L(.beeSize))
                }
                .font(.system(.body))
            }
        }
    }
}

// MARK: - Statistics Modal
struct BeecellStatsView: View {
    let viewModel: BeecellViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(AppCoordinator.self) private var coordinator
    @State private var showingResetConfirmation = false

    var body: some View {
        let stats = viewModel.currentModeStats

        VStack(spacing: 20) {
            Text(coordinator.L(.freecellStatisticsFmt, viewModel.options.deckCount == 1 ? coordinator.L(.deckCount1) : coordinator.L(.deckCount2)))
                .font(.system(size: 14, weight: .bold))
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
                    Button(coordinator.L(.reset), role: .destructive) { viewModel.resetStatistics() }
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
            // See Klondike's matching StatsView — fixed max size so the watermark sits
            // behind the stat text instead of scaling up with the panel width.
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
