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
    @State private var hostingWindow: NSWindow? = nil
    
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

            FeltVignetteView()

            
            VStack(spacing: 0) {
                // Top Control Row
                HStack(spacing: 20) {
                    // New Game
                    Button(action: {
                        viewModel.startNewGame()
                    }) {
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
                    .keyboardShortcut("n", modifiers: .command)

                    // Restart Game
                    Button(action: {
                        viewModel.restartCurrentGame()
                    }) {
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

                    // Undo
                    Button(action: {
                        viewModel.undoLastAction()
                    }) {
                        Text("Undo")
                            .font(.display(16))
                            .foregroundColor(viewModel.canUndo ? .white : .white.opacity(0.4))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(viewModel.canUndo ? Color.white : Color.white.opacity(0.4), lineWidth: 1)
                            )
                    }
                    .buttonStyle(HoverToolbarButtonStyle())
                    .disabled(!viewModel.canUndo)
                    .focusable(false)
                    .keyboardShortcut("z", modifiers: .command)

                    // Options
                    Button(action: {
                        isShowingOptions = true
                    }) {
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

                    // Stats
                    if !viewModel.options.hideStatsButton {
                        Button(action: {
                            isShowingStats = true
                        }) {
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
                        Button(action: {
                            viewModel.findHint()
                        }) {
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
                        .focusable(false)
                        .keyboardShortcut("h", modifiers: .command)
                    }
                    
                    Spacer()
                    
                    HStack(alignment: .bottom, spacing: 20) {
                        StatusItemView(label: "SCORE", value: viewModel.scoreString)
                        StatusItemView(label: "MOVES", value: String(viewModel.state.movesCount))
                        StatusItemView(label: "TIME", value: formatTime(viewModel.state.timerSeconds))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 6)
                .background(viewModel.options.feltColor.statusBarColor)
                .layoutPriority(1)
                
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 1)
                
                // Game Board Area
                ZStack {
                    viewModel.options.feltColor.primaryColor
                    
                    VStack(spacing: 16) {
                        // Hint Banner
                        if let hint = viewModel.activeHint {
                            HStack {
                                Text("💡 \(hint.description)")
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
                                .modifier(HintHighlightModifier(isHighlighted: viewModel.activeHint?.sourcePileId == pile.id || viewModel.activeHint?.targetPileId == pile.id))
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
                                Text("No moves available.")
                                    .font(.system(.headline, design: .monospaced))
                                    .foregroundColor(.white)
                                Text("No valid moves remain and the stock is empty.")
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
                        .frame(width: 380)
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
        }
        .environment(\.feltColor, viewModel.options.feltColor)
        .id(viewModel.options.customFeltColorRevision)
        .frame(minWidth: boardWidth * viewModel.zoomScale,
               idealWidth: boardWidth * viewModel.zoomScale,
               maxWidth: .infinity,
               minHeight: 73 + boardHeight * viewModel.zoomScale,
               idealHeight: 73 + boardHeight * viewModel.zoomScale,
               maxHeight: .infinity)
        .sheet(isPresented: $isShowingOptions) {
            SpiderOptionsView(viewModel: viewModel, isShowingStats: $isShowingStats)
        }
        .sheet(isPresented: $isShowingStats) {
            SpiderStatsView(viewModel: viewModel)
        }
        .background(WindowAccessor { window in
            self.hostingWindow = window
            resizeWindow(zoomScale: viewModel.zoomScale)
        })
        .onChange(of: viewModel.zoomScale) { _, newValue in
            resizeWindow(zoomScale: newValue)
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
            dropTarget = sorted.first?.pile
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
    
    private func resizeWindow(zoomScale: CGFloat) {
        guard let window = hostingWindow else { return }
        
        let stackSpacing = zoomScale > 1.0 ? max(4.0, 18.0 - 14.0 * (zoomScale - 1.0)) : 18.0
        let numCols: Double = 10.0
        let boardWidth = numCols * 128.0 + (numCols - 1) * stackSpacing + 40.0
        let boardHeight: CGFloat = 1120
        
        let newWidth = boardWidth * zoomScale
        let newHeight = 73.0 + boardHeight * zoomScale
        
        DispatchQueue.main.async {
            let currentFrame = window.frame
            let newContentSize = NSSize(width: newWidth, height: newHeight)
            let newFrame = window.frameRect(forContentRect: NSRect(origin: .zero, size: newContentSize))
            
            let yOffset = currentFrame.height - newFrame.height
            let updatedFrame = NSRect(
                x: currentFrame.origin.x,
                y: currentFrame.origin.y + yOffset,
                width: newFrame.width,
                height: newFrame.height
            )
            
            window.contentMinSize = newContentSize
            window.setFrame(updatedFrame, display: true, animate: true)
        }
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
    @State private var isDarkMode: Bool
    @State private var customSelectedColor: Color

    let originalRed: Double
    let originalGreen: Double
    let originalBlue: Double

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
        _isDarkMode = State(initialValue: viewModel.options.isDarkMode)
        
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
        VStack(spacing: 20) {
            Text("Preferences")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .padding(.top, 12)
            
            Divider()
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Difficulty / Suits:", selection: $suitCount) {
                        Text("1 Suit (Spades)").tag(1)
                        Text("2 Suits (♠️❤️)").tag(2)
                        Text("4 Suits (Standard)").tag(4)
                    }
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

                    Toggle("Dark Mode Cards", isOn: $isDarkMode)
                        .font(.system(.body, design: .monospaced))

                    Divider()

                    ThemesSectionView(
                        currentCardBackTheme: cardBackTheme,
                        currentIsDarkMode: isDarkMode,
                        currentFeltColor: feltColor
                    )

                    Divider()

                    Picker("Felt Color:", selection: $feltColor) {
                        Text("Felt Green").tag(FeltColorTheme.feltGreen)
                        Text("Crimson").tag(FeltColorTheme.crimson)
                        Text("Royal Blue").tag(FeltColorTheme.royalBlue)
                        Text("Charcoal").tag(FeltColorTheme.charcoal)
                        Text("Desert").tag(FeltColorTheme.desert)
                        Text("Custom").tag(FeltColorTheme.custom)
                    }
                    .font(.system(.body, design: .monospaced))

                    if feltColor == .custom {
                        ColorPicker("Custom Color:", selection: $customSelectedColor)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: customSelectedColor) { _, newColor in
                                let nsColor = NSColor(newColor)
                                if let rgbColor = nsColor.usingColorSpace(.deviceRGB) {
                                    UserDefaults.standard.set(Double(rgbColor.redComponent), forKey: "custom_felt_red")
                                    UserDefaults.standard.set(Double(rgbColor.greenComponent), forKey: "custom_felt_green")
                                    UserDefaults.standard.set(Double(rgbColor.blueComponent), forKey: "custom_felt_blue")
                                }
                            }
                    }

                    Divider()

                    CustomArtPanelView(cardBackTheme: $cardBackTheme, feltColor: $feltColor)
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
                    updatedOpts.isDarkMode = isDarkMode
                    updatedOpts.customFeltColorRevision += 1
                    
                    viewModel.options = updatedOpts
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(width: 380)
        .background(Color(NSColor.windowBackgroundColor))
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
            Text("Statistics (\(viewModel.options.suitCount) \(viewModel.options.suitCount == 1 ? "Suit" : "Suits"))")
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
        .frame(width: 320)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
