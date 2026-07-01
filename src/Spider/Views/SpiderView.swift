import SwiftUI
import AppKit

public struct SpiderView: View {
    var viewModel: SpiderViewModel
    
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
    @State private var hostingWindow: NSWindow? = nil
    @State private var zoomController: WindowZoomController? = nil

    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator?
    
    public init(viewModel: SpiderViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        let stackSpacing = viewModel.zoomScale > 1.0 ? max(4.0, 18.0 - 14.0 * (viewModel.zoomScale - 1.0)) : 18.0
        let numCols: Double = 10.0
        let boardWidth = numCols * 128.0 + (numCols - 1) * stackSpacing + 40.0
        let boardHeight: CGFloat = 1120
        
        return ZStack {
            // Felt Board Background
            viewModel.options.feltColor.primaryColor
                .ignoresSafeArea()

            if viewModel.options.showFeltVignette { FeltVignetteView(intensity: 0.34) }

            
            VStack(spacing: 0) {
                // Top Control Row
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

                    // Stats
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
                        .disabled(viewModel.state.hasWon)
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
                    
                    Button(action: { isShowingNewGameConfirm = true }) { EmptyView() }
                        .keyboardShortcut("n", modifiers: .command).frame(width: 0, height: 0).opacity(0)

                    Spacer()

                    HStack(alignment: .bottom, spacing: 20) {
                        StatusItemView(label: "SCORE", value: viewModel.scoreString)
                        StatusItemView(label: "MOVES", value: String(viewModel.state.movesCount))
                        if viewModel.options.isTimed {
                            StatusItemView(label: "TIME", value: formatTime(viewModel.state.timerSeconds))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
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
                            SpiderStockView(cardCount: viewModel.state.stock.cards.count)
                                .modifier(HintHighlightModifier(isHighlighted: viewModel.activeHint?.sourcePileId == viewModel.state.stock.id))
                                .background(GeometryReader { geo in
                                    Color.clear
                                        .onAppear { pileFrames[viewModel.state.stock.id] = geo.frame(in: .global) }
                                        .onChange(of: geo.frame(in: .global)) { _, newFrame in pileFrames[viewModel.state.stock.id] = newFrame }
                                })
                                .overlay(
                                    ClickReceiver {
                                        viewModel.clearHint()
                                        if viewModel.hasEmptyTableauColumn {
                                            isShowingEmptyStockWarning = true
                                        } else {
                                            viewModel.drawFromStock()
                                        }
                                    }
                                )
                            
                            Spacer()
                            
                            // 8 Foundation columns showing completed runs
                            ForEach(viewModel.state.foundations) { pile in
                                ZStack {
                                    EmptyPileView(symbol: "K")
                                    
                                    if let topCard = pile.topCard {
                                        CardView(card: topCard)
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
                                    onDragStarted: { card, stack, startLoc in
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
                    
                    // Stuck Banner
                    if viewModel.isStuck && !viewModel.state.hasWon {
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
                        .padding(16)
                        .background(Color.orange.opacity(0.9))
                        .cornerRadius(8)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .shadow(radius: 5)
                    }

                    // Autocomplete Banner
                    if viewModel.isAutocompleteAvailable && !viewModel.isAutoplayRunning {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Victory is guaranteed!")
                                    .font(.system(.headline, design: .monospaced))
                                    .foregroundColor(.white)
                                Text("All remaining cards can be sorted into foundations.")
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

                    // Empty column Stock deal warning
                    if isShowingEmptyStockWarning {
                        VStack(spacing: 12) {
                            Text("Empty Column Warning")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Text("All tableau columns must contain at least one card before dealing from the Stock.")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                            
                            Button("OK") {
                                isShowingEmptyStockWarning = false
                            }
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.yellow)
                            .cornerRadius(6)
                            .buttonStyle(.plain)
                        }
                        .padding(24)
                        .background(Color.black.opacity(0.85))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow, lineWidth: 1.5))
                        .frame(width: 440)
                    }
                    
                    // Victory Cascade Overlay
                    if viewModel.state.hasWon {
                        WinAnimationView(foundations: viewModel.state.foundations) {
                            // finish win
                        }
                        .ignoresSafeArea()
                        
                        VStack {
                            Spacer()
                            VStack(spacing: 12) {
                                Text("YOU WIN!")
                                    .font(.system(size: 40, weight: .black, design: .monospaced))
                                    .foregroundColor(.yellow)
                                    .shadow(radius: 3)

                                Text("Score: \(viewModel.scoreString) | Time: \(formatTime(viewModel.state.timerSeconds))")
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
                            .background(Color.black.opacity(0.75))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow, lineWidth: 1.5))
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            }
                .frame(width: boardWidth, height: boardHeight, alignment: .topLeading)
                .scaleEffect(viewModel.zoomScale, anchor: .topLeading)
                .frame(width: boardWidth * viewModel.zoomScale, height: boardHeight * viewModel.zoomScale, alignment: .topLeading)
            }
            .frame(minWidth: boardWidth * viewModel.zoomScale, maxHeight: .infinity, alignment: .topLeading)
                } // ScrollView

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
        }
        .environment(\.feltColor, viewModel.options.feltColor)
        .environment(\.activeCardBackTheme, viewModel.options.cardBackTheme)
        .environment(\.activeCustomCardColors, viewModel.options.customCardColors)
        .id(viewModel.options.customFeltColorRevision)
        .frame(minWidth: boardWidth * viewModel.zoomScale,
               maxWidth: .infinity,
               minHeight: 73 + boardHeight * viewModel.zoomScale,
               maxHeight: .infinity)
        .sheet(isPresented: $isShowingOptions) {
            SpiderOptionsView(viewModel: viewModel, isShowingStats: $isShowingStats)
        }
        .sheet(isPresented: $isShowingStats) {
            SpiderStatsView(viewModel: viewModel)
        }
        .confirmationDialog("Start a new game? Your current game will end.", isPresented: $isShowingNewGameConfirm) {
            Button("New Game", role: .destructive) { viewModel.startNewGame() }
            Button("Cancel", role: .cancel) { }
        }
        .onAppear { snapToMinSize() }
        .background(WindowAccessor { window in
            self.hostingWindow = window
            self.zoomController = WindowZoomController(window: window)
            snapToMinSize()
        })
        .onChange(of: viewModel.zoomScale) { updateMinSize() }
    }

    private func updateMinSize() {
        guard let window = hostingWindow else { return }
        let z = viewModel.zoomScale
        let spacing = z > 1.0 ? max(4.0, 18.0 - 14.0 * (z - 1.0)) : 18.0
        let cols: Double = 10.0
        let minW = (cols * 128.0 + (cols - 1) * spacing + 40.0) * z + 24
        let minH = 73.0 + 1120.0 * z + 24
        DispatchQueue.main.async {
            window.contentMinSize = NSSize(width: minW, height: minH)
        }
    }

    private func snapToMinSize() {
        guard let window = hostingWindow else { return }
        let z = viewModel.zoomScale
        let spacing = z > 1.0 ? max(4.0, 18.0 - 14.0 * (z - 1.0)) : 18.0
        let cols: Double = 10.0
        let minW = (cols * 128.0 + (cols - 1) * spacing + 40.0) * z + 24
        let minH = 73.0 + 1120.0 * z + 24
        let size = NSSize(width: minW, height: minH)
        DispatchQueue.main.async {
            window.contentMinSize = size
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                window.animator().setContentSize(size)
            }
        }
    }

    private func handleDragEnded() {
        let releaseLocation = CGPoint(
            x: dragLocation.x + dragOffset.width,
            y: dragLocation.y + dragOffset.height
        )
        
        var dropTarget: Pile? = nil
        
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
        
        if let target = dropTarget, let source = dragSourcePile {
            viewModel.moveCards(draggedCards, from: source, to: target)
        }
        
        // Reset states
        draggedCards = []
        dragSourcePile = nil
        dragOffset = .zero
    }
    
    private func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
}

// MARK: - Options Preference Dialog
struct SpiderOptionsView: View {
    @Bindable var viewModel: SpiderViewModel
    @Binding var isShowingStats: Bool
    @Environment(\.dismiss) private var dismiss
    
    @State private var feltColor: FeltColorTheme
    @State private var cardBackTheme: String
    @State private var suitCount: Int
    @State private var isTimed: Bool
    @State private var isSoundEnabled: Bool
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

    init(viewModel: SpiderViewModel, isShowingStats: Binding<Bool>) {
        self.viewModel = viewModel
        self._isShowingStats = isShowingStats
        _feltColor = State(initialValue: viewModel.options.feltColor)
        _cardBackTheme = State(initialValue: viewModel.options.cardBackTheme)
        _suitCount = State(initialValue: viewModel.options.suitCount)
        _isTimed = State(initialValue: viewModel.options.isTimed)
        _isSoundEnabled = State(initialValue: viewModel.options.isSoundEnabled)
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
                    Picker("Suits:", selection: $suitCount) {
                        Text("1 (Spades)").tag(1)
                        Text("2 (♠♥)").tag(2)
                        Text("4 (Standard)").tag(4)
                    }
                    .pickerStyle(.segmented)
                    .font(.system(.body, design: .monospaced))
                    
                    Divider()

                    Toggle("Timed Game", isOn: $isTimed)
                        .font(.system(.body, design: .monospaced))

                    Toggle("Sound Effects", isOn: $isSoundEnabled)
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
                        isShowingStats = true
                    }
                }) {
                    Text("View Stats")
                        .foregroundColor(.blue)
                        .underline()
                }
                .buttonStyle(.plain)
                .font(.system(.body, design: .monospaced))
                
                Spacer()
                
                Button("OK") {
                    var updatedOpts = viewModel.options
                    updatedOpts.feltColor = feltColor
                    updatedOpts.cardBackTheme = cardBackTheme
                    updatedOpts.suitCount = suitCount
                    updatedOpts.isTimed = isTimed
                    updatedOpts.isSoundEnabled = isSoundEnabled
                    updatedOpts.hideHintButton = hideHintButton
                    updatedOpts.hideStatsButton = hideStatsButton
                    updatedOpts.showFeltVignette = showFeltVignette
                    updatedOpts.customCardColors = customCardColors
                    updatedOpts.customFeltColorRevision += 1
                    
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

// MARK: - Statistics View
struct SpiderStatsView: View {
    let viewModel: SpiderViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingResetConfirmation = false

    var body: some View {
        let stats = viewModel.currentModeStats
        
        VStack(spacing: 20) {
            Text("Spider Statistics (\(viewModel.options.suitCount) \(viewModel.options.suitCount == 1 ? "Suit" : "Suits"))")
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
        .background(Color(NSColor.windowBackgroundColor))
    }
}
