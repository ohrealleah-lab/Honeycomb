import SwiftUI
import AppKit

public struct BlackjackView: View {
    var viewModel: BlackjackViewModel
    @State private var isShowingOptions = false
    @State private var isShowingStats   = false
    @State private var isShowingNewGameConfirm = false
    @State private var showResultBanner  = false
    @State private var cardsVisible           = true
    @State private var showCardBackPlaceholders = false
    @State private var dealerFlipped          = false  // triggers hole-card flip animation
    @State private var resultHideTask:   DispatchWorkItem? = nil
    @State private var showIdlePrompt    = false
    @State private var hostingWindow: NSWindow? = nil
    @State private var zoomController: WindowZoomController? = nil
    @State private var idlePromptTask:   DispatchWorkItem? = nil
    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator?

    private let cardScale: CGFloat = 1.4
    private var cardW: CGFloat { 128 * cardScale }  // ≈179
    private var cardH: CGFloat { 181 * cardScale }  // ≈253

    public init(viewModel: BlackjackViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            viewModel.options.feltColor.primaryColor
                .ignoresSafeArea()

            if viewModel.options.showFeltVignette { FeltVignetteView() }

            VStack(spacing: 0) {
                toolbarView
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                Divider().overlay(Color.white.opacity(0.2))

                VStack(spacing: 12) {
                    creditDisplay

                    VStack(spacing: 12) {
                        dealerArea
                            .padding(.horizontal, 24)

                        vsLabel

                        playerArea
                            .padding(.horizontal, 24)
                    }
                    .overlay {
                        if viewModel.state.phase == .result {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { viewModel.deal() }
                        }
                    }

                    actionButtons
                }
                .padding(.vertical, 16)

                Spacer()
            }
            .frame(width: 905, height: 950, alignment: .topLeading)
            .scaleEffect(viewModel.zoomScale, anchor: .topLeading)
            .frame(width: 905 * viewModel.zoomScale, height: 950 * viewModel.zoomScale, alignment: .topLeading)

            // Idle prompt overlay
            if showIdlePrompt {
                Text("Hit Space to Deal")
                    .font(.display(28, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.55))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.25), lineWidth: 1))
                    .opacity(showIdlePrompt ? 1 : 0)
                    .animation(.easeInOut(duration: 0.6), value: showIdlePrompt)
            }

            // Result banner overlay
            if showResultBanner && !viewModel.state.lastResultSummary.isEmpty {
                resultBanner
            }

            // Keyboard shortcuts
            keyboardShortcuts
                .opacity(0)
                .frame(width: 0, height: 0)
                .clipped()
        }
        .frame(minWidth: 905 * viewModel.zoomScale, maxWidth: .infinity,
               minHeight: 950 * viewModel.zoomScale, maxHeight: .infinity)
        .onAppear { snapToMinSize() }
        .background(WindowAccessor { window in
            self.hostingWindow = window
            self.zoomController = WindowZoomController(window: window)
            snapToMinSize()
        })
        .onChange(of: viewModel.zoomScale) { snapToMinSize() }
        .environment(\.activeCardBackTheme, viewModel.options.cardBackTheme)
        .environment(\.activeCustomCardColors, viewModel.options.customCardColors)
        .sheet(isPresented: $isShowingOptions) {
            BlackjackOptionsView(viewModel: viewModel, isShowingStats: $isShowingStats)
        }
        .sheet(isPresented: $isShowingStats) {
            BlackjackStatsView(viewModel: viewModel)
        }
        .confirmationDialog("Start a new game?", isPresented: $isShowingNewGameConfirm) {
            Button("New Game", role: .destructive) { viewModel.startNewGame() }
            Button("Cancel", role: .cancel) { }
        }
        .onAppear {
            if viewModel.state.phase == .betting && viewModel.state.playerHands.isEmpty {
                withAnimation(.easeInOut(duration: 0.6)) { showIdlePrompt = true }
            }
        }
        .onChange(of: viewModel.state.phase) { _, newPhase in
            if newPhase == .result {
                idlePromptTask?.cancel()
                withAnimation(.easeInOut(duration: 0.4)) { showIdlePrompt = false }
                dealerFlipped = true
                showResultBanner = true
                withAnimation(.easeIn(duration: 0.3)) { cardsVisible = true }
                let bannerTask = DispatchWorkItem {
                    showResultBanner = false
                    let hideTask = DispatchWorkItem {
                        withAnimation(.easeOut(duration: 0.4)) { cardsVisible = false }
                        // Cards fully faded — show card backs then schedule idle prompt
                        let promptTask = DispatchWorkItem {
                            showCardBackPlaceholders = true
                            withAnimation(.easeIn(duration: 0.3)) { cardsVisible = true }
                            withAnimation(.easeInOut(duration: 0.6)) { showIdlePrompt = true }
                        }
                        idlePromptTask = promptTask
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: promptTask)
                    }
                    resultHideTask = hideTask
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: hideTask)
                }
                resultHideTask = bannerTask
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: bannerTask)
            }
            if newPhase == .betting || newPhase == .playing {
                resultHideTask?.cancel()
                resultHideTask = nil
                idlePromptTask?.cancel()
                idlePromptTask = nil
                withAnimation(.easeInOut(duration: 0.3)) { showIdlePrompt = false }
                dealerFlipped = false
                showResultBanner = false
                showCardBackPlaceholders = false
                withAnimation(.easeIn(duration: 0.2)) { cardsVisible = true }
            }
            if newPhase == .dealerTurn {
                dealerFlipped = true
            }
        }
    }

    // MARK: - Toolbar

    private var toolbarView: some View {
        HStack(spacing: 20) {
            gameModeMenu
            toolbarButton("Options")  { isShowingOptions = true }
            if !viewModel.options.hideStatsButton {
                toolbarButton("Stats") { isShowingStats = true }
            }
            Spacer()
        }
    }

    private func toolbarButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
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

    private var gameModeMenu: some View {
        Menu {
            Button(GameMode.klondike.rawValue) {
                if let c = coordinator, c.gameMode != .klondike { c.gameMode = .klondike; c.startNewGame() }
            }
            Button(GameMode.beecell.rawValue) {
                if let c = coordinator, c.gameMode != .beecell { c.gameMode = .beecell; c.startNewGame() }
            }
            Button(GameMode.spider.rawValue) {
                if let c = coordinator, c.gameMode != .spider { c.gameMode = .spider; c.startNewGame() }
            }
            Button(GameMode.videoPoker.rawValue) {
                if let c = coordinator, c.gameMode != .videoPoker { c.gameMode = .videoPoker }
            }
            Button(GameMode.blackjack.rawValue) {
                if let c = coordinator, c.gameMode != .blackjack { c.gameMode = .blackjack }
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
    }

    // MARK: - Credit Display

    private var creditDisplay: some View {
        HStack(spacing: 32) {
            VStack(spacing: 2) {
                Text("CREDITS")
                    .font(.display(10))
                    .foregroundColor(.white.opacity(0.6))
                Text("\(viewModel.state.sessionCredits)")
                    .font(.display(28, weight: .black))
                    .foregroundColor(.yellow)
            }

            VStack(spacing: 2) {
                Text("BET")
                    .font(.display(10))
                    .foregroundColor(.white.opacity(0.6))
                Text("\(viewModel.state.currentBet)")
                    .font(.display(28, weight: .black))
                    .foregroundColor(viewModel.state.currentBet == 5 ? .orange : .white)
            }

            VStack(spacing: 2) {
                Text("HANDS")
                    .font(.display(10))
                    .foregroundColor(.white.opacity(0.6))
                Text("\(viewModel.state.handsDealt)")
                    .font(.display(28, weight: .black))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.5), radius: 6, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.clear],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Dealer Area

    private var dealerArea: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("DEALER")
                    .font(.display(12, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                if viewModel.state.phase != .betting {
                    let val = viewModel.state.phase == .playing
                        ? viewModel.state.dealerVisibleValue
                        : viewModel.state.dealerValue
                    Text("\(val)")
                        .font(.display(14, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                }
            }

            HStack(spacing: 16) {
                if viewModel.state.dealerCards.isEmpty || showCardBackPlaceholders {
                    ForEach(0..<2, id: \.self) { _ in
                        CardView(card: Card(suit: .spades, rank: 1, faceUp: false))
                            .scaleEffect(cardScale)
                            .frame(width: cardW, height: cardH)
                    }
                } else {
                    ForEach(Array(viewModel.state.dealerCards.enumerated()), id: \.offset) { idx, card in
                        CardView(card: card)
                            .scaleEffect(cardScale)
                            .frame(width: cardW, height: cardH)
                            .opacity(cardsVisible ? 1 : 0)
                            .animation(.easeIn(duration: 0.15).delay(Double(idx) * 0.08), value: cardsVisible)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: cardH, alignment: .center)
        }
    }

    // MARK: - VS Label

    private var vsLabel: some View {
        HStack {
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)
            Text("VS")
                .font(.display(11, weight: .black))
                .foregroundColor(.white.opacity(0.4))
                .padding(.horizontal, 10)
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Player Area

    // Scale cards down in split mode so even 5-card hands fit in one grid column.
    // Base card is 128×181 pt; cardScale (1.4) applies on top for the normal single-hand view.
    private var splitCardScale: CGFloat {
        let maxCards = viewModel.state.playerHands.map { $0.cards.count }.max() ?? 2
        switch maxCards {
        case ..<3: return cardScale       // 2 cards — full size
        case 3:    return 1.0
        case 4:    return 0.78
        default:   return 0.65            // 5+
        }
    }
    private var splitCardW: CGFloat { 128 * splitCardScale }
    private var splitCardH: CGFloat { 181 * splitCardScale }

    private var playerArea: some View {
        let isSplit = viewModel.state.playerHands.count > 1
        let scale  = isSplit ? splitCardScale : cardScale
        let width  = isSplit ? splitCardW     : cardW
        let height = isSplit ? splitCardH     : cardH
        let spacing: CGFloat = isSplit ? 8 : 16
        let columns = isSplit
            ? [GridItem(.flexible()), GridItem(.flexible())]
            : [GridItem(.flexible())]

        return VStack(spacing: 8) {
            Text("PLAYER")
                .font(.display(12, weight: .bold))
                .foregroundColor(.white.opacity(0.6))

            if viewModel.state.playerHands.isEmpty || showCardBackPlaceholders {
                HStack(spacing: 16) {
                    ForEach(0..<2, id: \.self) { _ in
                        CardView(card: Card(suit: .spades, rank: 1, faceUp: false))
                            .scaleEffect(cardScale)
                            .frame(width: cardW, height: cardH)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: cardH + 40)
            } else {

            LazyVGrid(columns: columns, alignment: .center, spacing: 16) {
                ForEach(Array(viewModel.state.playerHands.enumerated()), id: \.offset) { handIdx, hand in
                    let isActive = handIdx == viewModel.state.activeHandIndex && viewModel.state.phase == .playing
                    VStack(spacing: 8) {
                        HStack(spacing: spacing) {
                            ForEach(Array(hand.cards.enumerated()), id: \.offset) { cardIdx, card in
                                CardView(card: card)
                                    .scaleEffect(scale)
                                    .frame(width: width, height: height)
                                    .opacity(cardsVisible ? 1 : 0)
                                    .animation(.easeIn(duration: 0.15).delay(Double(cardIdx) * 0.08), value: cardsVisible)
                            }
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isActive ? Color.yellow.opacity(0.85) : Color.clear, lineWidth: 2)
                        )

                        HStack(spacing: 6) {
                            Text("\(hand.value)")
                                .font(.display(16, weight: .black))
                                .foregroundColor(hand.isBust ? .red : .white)
                            if isSplit {
                                Text("BET \(hand.bet)")
                                    .font(.display(11, weight: .bold))
                                    .foregroundColor(.yellow.opacity(0.8))
                            }
                            if let result = hand.result {
                                resultBadge(result)
                            }
                        }
                        .opacity(cardsVisible ? 1 : 0)
                        .animation(.easeOut(duration: 0.4), value: cardsVisible)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: cardH + 40)
            } // end else (playerHands non-empty)
        }
    }

    private func resultBadge(_ result: BlackjackHandResult) -> some View {
        let (text, color): (String, Color) = {
            switch result {
            case .blackjack: return ("BJ", .yellow)
            case .win:       return ("WIN", .green)
            case .loss:      return ("LOSS", .red)
            case .push:      return ("PUSH", .white)
            case .bust:      return ("BUST", .red)
            }
        }()
        return Text(text)
            .font(.display(10, weight: .black))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .cornerRadius(4)
    }

    // MARK: - Result Banner

    private var resultBanner: some View {
        let net = viewModel.state.lastNetResult
        let anyBJ = viewModel.state.playerHands.contains { $0.result == .blackjack }
        let anyWin = viewModel.state.playerHands.contains { $0.result == .win || $0.result == .blackjack }
        let allPush = !viewModel.state.playerHands.isEmpty && viewModel.state.playerHands.allSatisfy { $0.result == .push }
        
        let headline: String
        let subline: String
        let isWin: Bool
        
        if anyBJ {
            headline = "BLACKJACK!"
            subline = net > 0 ? "+\(net) credits" : net < 0 ? "\(net) credits" : "Even"
            isWin = true
        } else if anyWin {
            headline = "YOU WIN!"
            subline = net > 0 ? "+\(net) credits" : net < 0 ? "\(net) credits" : "Even"
            isWin = true
        } else if allPush {
            headline = "PUSH"
            subline = "Bets returned"
            isWin = false
        } else {
            headline = "DEALER WINS"
            subline = net > 0 ? "+\(net) credits" : net < 0 ? "\(net) credits" : "Even"
            isWin = false
        }
        
        let streak = viewModel.consecutiveWins
        let streakText: String?
        if streak >= 2 && isWin {
            streakText = streak >= 5 ? "*** \(streak) WIN STREAK ***"
                       : streak >= 3 ? "** \(streak) WIN STREAK **"
                       :               "\(streak) wins in a row!"
        } else {
            streakText = nil
        }
        
        return VStack(spacing: 6) {
            Text(headline)
                .font(.system(size: 32, weight: .black))
                .foregroundColor(isWin ? Color(red: 1.0, green: 0.84, blue: 0.0) : .white)
                .multilineTextAlignment(.center)
            
            Text(subline)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
            
            if let streakText = streakText {
                Text(streakText)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.9))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 16)
        .background(Color(red: 26/255.0, green: 68/255.0, blue: 204/255.0))
        .cornerRadius(8)
        .shadow(color: isWin ? Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.56) : .clear, radius: 14)
        .shadow(color: .black.opacity(0.66), radius: 9, x: 0, y: 4)
        .transition(.opacity)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            switch viewModel.state.phase {
            case .betting, .result:
                casinoButton("-", color: .white.opacity(0.2)) { viewModel.decreaseBet() }
                casinoButton("BET MAX  [M]", color: .orange.opacity(0.85)) { viewModel.maxBet() }
                casinoButton("+", color: .white.opacity(0.2)) { viewModel.increaseBet() }
                Divider().frame(height: 36).overlay(Color.white.opacity(0.3))
                casinoButton("DEAL  [Space]", color: .yellow,
                             disabled: viewModel.state.sessionCredits < viewModel.state.currentBet) {
                    viewModel.deal()
                }

            case .playing:
                casinoButton("HIT  [H]",       color: .green.opacity(0.85))  { viewModel.hit() }
                casinoButton("STAND  [S]",     color: .red.opacity(0.75))    { viewModel.stand() }
                if viewModel.canDouble {
                    casinoButton("DOUBLE  [D]", color: .blue.opacity(0.75)) { viewModel.doubleDown() }
                }
                if viewModel.canSplit {
                    casinoButton("SPLIT  [P]", color: .purple.opacity(0.75)) { viewModel.split() }
                }

            case .dealerTurn:
                casinoButton("HIT  [H]",       color: .green.opacity(0.3), disabled: true) {}
                casinoButton("STAND  [S]",     color: .red.opacity(0.3),   disabled: true) {}
            }

            if viewModel.state.sessionCredits < viewModel.state.currentBet
                && viewModel.state.phase != .playing
                && viewModel.state.phase != .dealerTurn {
                casinoButton("REBUY", color: .red.opacity(0.8)) { viewModel.rebuy() }
            }
        }
    }

    private func stackedButton(_ label: String, hotkey: String, color: Color,
                               textColor: Color = .white, disabled: Bool = false,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(label)
                    .font(.display(14, weight: .black))
                    .foregroundColor(disabled ? textColor.opacity(0.4) : textColor)
                Text("[\(hotkey)]")
                    .font(.display(10, weight: .bold))
                    .foregroundColor((disabled ? textColor.opacity(0.4) : textColor).opacity(0.6))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(disabled ? Color.gray.opacity(0.3) : color)
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(PressButtonStyle())
        .focusable(false)
        .disabled(disabled)
    }

    private func casinoButton(_ label: String, color: Color, textColor: Color = .white,
                               disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.display(14, weight: .black))
                .foregroundColor(disabled ? textColor.opacity(0.4) : textColor)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(disabled ? Color.gray.opacity(0.3) : color)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(PressButtonStyle())
        .disabled(disabled)
        .focusable(false)
    }

    // MARK: - Keyboard shortcuts

    private var keyboardShortcuts: some View {
        Group {
            // Space — deal only
            Button("") {
                switch viewModel.state.phase {
                case .betting, .result: viewModel.deal()
                case .playing, .dealerTurn: break
                }
            }
            .keyboardShortcut(.space, modifiers: [])

            // H — hit
            Button("") { if viewModel.state.phase == .playing { viewModel.hit() } }
                .keyboardShortcut("h", modifiers: [])

            Button("") { viewModel.stand() }
                .keyboardShortcut("s", modifiers: [])

            Button("") { if viewModel.canDouble { viewModel.doubleDown() } }
                .keyboardShortcut("d", modifiers: [])

            Button("") { if viewModel.canSplit { viewModel.split() } }
                .keyboardShortcut("p", modifiers: [])
        }
    }

    // MARK: - Helpers

    private func updateMinSize() {
        guard let window = hostingWindow else { return }
        let z = viewModel.zoomScale
        let size = NSSize(width: 905 * z, height: 950 * z)
        DispatchQueue.main.async {
            window.contentMinSize = size
        }
    }

    private func snapToMinSize() {
        guard let window = hostingWindow else { return }
        let z = viewModel.zoomScale
        let size = NSSize(width: 905 * z, height: 950 * z)
        DispatchQueue.main.async {
            window.contentMinSize = size
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                window.animator().setContentSize(size)
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - Options View

struct BlackjackOptionsView: View {
    @Bindable var viewModel: BlackjackViewModel
    @Binding var isShowingStats: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var startingCredits: Int
    @State private var betPerHand: Int
    @State private var isSoundEnabled: Bool
    @State private var hideStatsButton: Bool
    @State private var showFeltVignette: Bool
    @State private var feltColor: FeltColorTheme
    @State private var cardBackTheme: String
    @State private var customSelectedColor: Color
    @State private var customCardColors: CustomCardColorGroup
    @State private var showingThemes: Bool = false

    let originalRed: Double
    let originalGreen: Double
    let originalBlue: Double
    let originalCustomCardColors: CustomCardColorGroup

    init(viewModel: BlackjackViewModel, isShowingStats: Binding<Bool>) {
        self.viewModel = viewModel
        self._isShowingStats = isShowingStats
        _startingCredits = State(initialValue: viewModel.options.startingCredits)
        _betPerHand      = State(initialValue: viewModel.options.betPerHand)
        _isSoundEnabled  = State(initialValue: viewModel.options.isSoundEnabled)
        _hideStatsButton = State(initialValue: viewModel.options.hideStatsButton)
        _showFeltVignette = State(initialValue: viewModel.options.showFeltVignette)
        _feltColor       = State(initialValue: viewModel.options.feltColor)
        _cardBackTheme   = State(initialValue: viewModel.options.cardBackTheme)
        _customCardColors = State(initialValue: viewModel.options.customCardColors)
        self.originalCustomCardColors = viewModel.options.customCardColors

        let r = UserDefaults.standard.double(forKey: "custom_felt_red")
        let g = UserDefaults.standard.double(forKey: "custom_felt_green")
        let b = UserDefaults.standard.double(forKey: "custom_felt_blue")
        self.originalRed = r; self.originalGreen = g; self.originalBlue = b
        let initColor: Color = (r == 0 && g == 0 && b == 0)
            ? Color(red: 0.35, green: 0.15, blue: 0.45)
            : Color(red: r, green: g, blue: b)
        _customSelectedColor = State(initialValue: initColor)
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
                    Stepper("Starting Credits: \(startingCredits)", value: $startingCredits, in: 10...10000, step: 10)
                        .font(.system(.body, design: .monospaced))

                    Picker("Default Bet:", selection: $betPerHand) {
                        ForEach(1...5, id: \.self) { n in Text("\(n) coin\(n == 1 ? "" : "s")").tag(n) }
                    }
                    .font(.system(.body, design: .monospaced))

                    Divider()

                    Toggle("Sound Effects",     isOn: $isSoundEnabled).font(.system(.body, design: .monospaced))
                    Toggle("Hide Stats button", isOn: $hideStatsButton).font(.system(.body, design: .monospaced))

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
            .frame(maxHeight: 560)

            Divider()

            HStack {
                Button("Cancel") {
                    UserDefaults.standard.set(originalRed,   forKey: "custom_felt_red")
                    UserDefaults.standard.set(originalGreen, forKey: "custom_felt_green")
                    UserDefaults.standard.set(originalBlue,  forKey: "custom_felt_blue")
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(action: {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { isShowingStats = true }
                }) {
                    Text("View Stats").foregroundColor(.blue).underline()
                }
                .buttonStyle(.plain)
                .font(.system(.body, design: .monospaced))

                Spacer()

                Button("OK") {
                    var o = viewModel.options
                    o.startingCredits = startingCredits
                    o.betPerHand      = betPerHand
                    o.isSoundEnabled  = isSoundEnabled
                    o.hideStatsButton   = hideStatsButton
                    o.showFeltVignette  = showFeltVignette
                    o.feltColor         = feltColor
                    o.cardBackTheme   = cardBackTheme
                    o.customCardColors = customCardColors
                    o.customFeltColorRevision += 1
                    viewModel.options = o
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
                    var o = viewModel.options
                    o.showFeltVignette   = showFeltVignette
                    o.feltColor          = feltColor
                    o.cardBackTheme      = cardBackTheme
                    o.customCardColors   = customCardColors
                    o.customFeltColorRevision += 1
                    viewModel.options = o
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

// MARK: - Stats View

struct BlackjackStatsView: View {
    var viewModel: BlackjackViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingResetConfirmation = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Blackjack Statistics")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .padding(.top, 16)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                statRow("Hands Played",  "\(viewModel.statistics.handsPlayed)")
                statRow("Hands Won",     "\(viewModel.statistics.handsWon)")
                statRow("Hands Lost",    "\(viewModel.statistics.handsLost)")
                statRow("Pushes",        "\(viewModel.statistics.pushes)")
                statRow("Blackjacks",    "\(viewModel.statistics.blackjacks)")
                statRow("Win Rate",      String(format: "%.1f%%", viewModel.statistics.winRate * 100))
                statRow("Total Wagered", "\(viewModel.statistics.totalWagered)")
                statRow("Total Paid",    "\(viewModel.statistics.totalPaidOut)")
                statRow("Biggest Pay",   "\(viewModel.statistics.biggestPayout)")
                statRow("RTP",           String(format: "%.1f%%", viewModel.statistics.returnToPlayer * 100))
                statRow("Rebuys",        "\(viewModel.statistics.rebuyCount)")
            }
            .padding(.horizontal, 24)

            Divider()

            HStack {
                Button("Reset Stats") { showingResetConfirmation = true }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                    .font(.system(.body, design: .monospaced))
                    .alert("Reset Statistics?", isPresented: $showingResetConfirmation) {
                        Button("Reset", role: .destructive) { viewModel.resetStatistics() }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will permanently clear all Blackjack statistics. This cannot be undone.")
                    }
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .font(.system(.body, design: .monospaced))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(width: 340)
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(.body, design: .monospaced))
            Spacer()
            Text(value).font(.system(.body, design: .monospaced)).fontWeight(.bold)
        }
    }
}
