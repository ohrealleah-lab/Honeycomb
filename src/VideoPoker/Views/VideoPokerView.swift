import SwiftUI
import AppKit

public struct VideoPokerView: View {
    var viewModel: VideoPokerViewModel
    @State private var isShowingOptions = false
    @State private var isShowingStats   = false
    @State private var isShowingNewGameConfirm = false
    @State private var winFlash         = false
    @State private var cardVisible: [Bool] = Array(repeating: false, count: 5)
    @State private var cardRotation: [Double] = Array(repeating: 0, count: 5)
    @State private var showParticles    = false
    @State private var showResultBanner = false
    @State private var cardsVisible     = true
    @State private var showIdlePrompt   = false
    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator?

    public init(viewModel: VideoPokerViewModel) {
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

                payTableGrid
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 6)

                Divider().overlay(Color.white.opacity(0.1))

                VStack(spacing: 16) {
                    creditDisplay
                    resultLabel
                    handArea
                    holdLabels
                    actionButtons
                }
                .padding(24)

                Spacer()
            }

            // Idle prompt
            if showIdlePrompt {
                Text("Hit Space to Deal")
                    .font(.display(28, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 8)
                    .animation(.easeInOut(duration: 0.6), value: showIdlePrompt)
            }

            // Keyboard shortcut buttons (invisible, zero-size)
            keyboardShortcuts
                .opacity(0)
                .frame(width: 0, height: 0)
                .clipped()
        }
        .frame(minWidth: 720, minHeight: 660)
        .sheet(isPresented: $isShowingOptions) {
            VideoPokerOptionsView(viewModel: viewModel, isShowingStats: $isShowingStats)
        }
        .sheet(isPresented: $isShowingStats) {
            VideoPokerStatsView(viewModel: viewModel)
        }
        .confirmationDialog("Start a new game?", isPresented: $isShowingNewGameConfirm) {
            Button("New Game", role: .destructive) { viewModel.startNewGame() }
            Button("Cancel", role: .cancel) { }
        }
        .onAppear {
            if viewModel.state.phase == .deal {
                withAnimation(.easeInOut(duration: 0.6)) { showIdlePrompt = true }
            }
        }
        .onChange(of: viewModel.state.phase) { _, newPhase in
            if newPhase == .result {
                showResultBanner = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showResultBanner = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeOut(duration: 0.4)) { cardsVisible = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            withAnimation(.easeInOut(duration: 0.6)) { showIdlePrompt = true }
                        }
                    }
                }
                if viewModel.state.lastPayout > 0 {
                    winFlash = true
                    showParticles = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { winFlash = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { showParticles = false }
                }
            }
            if newPhase == .holding {
                withAnimation(.easeInOut(duration: 0.3)) { showIdlePrompt = false }
                showResultBanner = false
                cardsVisible = true
                animateDeal()
            }
            if newPhase == .deal {
                withAnimation(.easeInOut(duration: 0.6)) { showIdlePrompt = true }
            }
        }
    }

    // MARK: - Toolbar

    private var toolbarView: some View {
        HStack(spacing: 20) {
            gameModeMenu
            toolbarButton("Options") { isShowingOptions = true }
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

    // MARK: - Pay Table Grid

    private var payTableGrid: some View {
        let entries = viewModel.payTable
        let half = (entries.count + 1) / 2
        let firstHalf  = Array(entries.prefix(half))
        let secondHalf = Array(entries.dropFirst(half))

        return VStack(spacing: 0) {
            Text(viewModel.options.variant.rawValue.uppercased())
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundColor(.yellow)
                .padding(.vertical, 5)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.55))

            HStack(alignment: .top, spacing: 0) {
                payHalfGrid(entries: firstHalf)
                Divider().overlay(Color.white.opacity(0.12))
                payHalfGrid(entries: secondHalf)
            }
        }
        .fixedSize()
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.15), lineWidth: 1))
        .animation(.easeInOut(duration: 0.15), value: viewModel.state.phase)
    }

    private func payHalfGrid(entries: [VideoPokerPayEntry]) -> some View {
        VStack(spacing: 0) {
            // Coin column headers
            HStack(spacing: 0) {
                Text("").frame(width: 118, alignment: .leading)
                ForEach(1...5, id: \.self) { coins in
                    Text(coins == 5 ? "MAX" : "\(coins)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(coins == viewModel.state.currentBet ? .orange : .white.opacity(0.45))
                        .frame(width: 34, alignment: .center)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.4))

            // Pay rows
            ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                let isWinner = viewModel.state.phase == .result && entry.handName == viewModel.state.lastHandName
                HStack(spacing: 0) {
                    Text(entry.handName)
                        .font(.system(size: 10, weight: isWinner ? .black : .regular, design: .monospaced))
                        .foregroundColor(isWinner ? .black : .white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(width: 118, alignment: .leading)
                    ForEach(0..<5, id: \.self) { i in
                        let total = entry.multipliers[i] * (i + 1)
                        Text("\(total)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(isWinner ? .black : (i + 1 == viewModel.state.currentBet ? .yellow : .white.opacity(0.65)))
                            .frame(width: 34, alignment: .center)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(isWinner
                    ? Color.yellow.opacity(winFlash ? 1.0 : 0.7)
                    : Color.black.opacity(0.2))
                .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true), value: winFlash)
            }
        }
    }

    // MARK: - Result Label

    private var resultLabel: some View {
        Color.clear.frame(height: 52)
    }

    // MARK: - Hand Area

    private let cardScale: CGFloat = 1.4
    private var scaledCardW: CGFloat { 77 * cardScale }   // ≈108
    private var scaledCardH: CGFloat { 122 * cardScale }  // ≈171

    private var handArea: some View {
        HStack(spacing: 16) {
            if viewModel.state.hand.isEmpty {
                // Placeholder slots before first deal
                ForEach(0..<5, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        .frame(width: scaledCardW, height: scaledCardH)
                        .overlay(
                            Image(systemName: "suit.spade.fill")
                                .foregroundColor(.white.opacity(0.08))
                                .font(.system(size: 36))
                        )
                }
            } else {
                ForEach(Array(viewModel.state.hand.enumerated()), id: \.offset) { idx, card in
                    let isHeld = viewModel.state.heldIndices.contains(idx)
                    let lifting = isHeld && viewModel.state.phase == .holding
                    let visible = idx < cardVisible.count && cardVisible[idx]
                    let wobble = idx < cardRotation.count ? cardRotation[idx] : 0.0
                    CardView(card: card)
                        .scaleEffect(cardScale)
                        .frame(width: scaledCardW, height: scaledCardH)
                        .rotationEffect(.degrees(wobble))
                        .offset(y: lifting ? -18 : (visible ? 0 : 40))
                        .opacity(visible ? 1 : 0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.5).delay(Double(idx) * 0.06), value: visible)
                        .animation(.spring(response: 0.2, dampingFraction: 0.4).delay(Double(idx) * 0.06), value: wobble)
                        .animation(.easeInOut(duration: 0.15), value: lifting)
                        .onTapGesture {
                            if viewModel.state.phase == .holding {
                                viewModel.toggleHold(at: idx)
                            }
                        }
                        .shadow(color: .black.opacity(0.3), radius: 4)
                }
            }
        }
        .opacity(cardsVisible ? 1 : 0)
        .frame(height: scaledCardH + 24)
        .overlay {
            WinParticleView(active: showParticles)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay {
            if showResultBanner && !viewModel.state.hand.isEmpty {
                if viewModel.state.lastPayout > 0 {
                    VStack(spacing: 6) {
                        Text(viewModel.state.lastHandName)
                            .font(.display(26, weight: .black))
                            .foregroundColor(.yellow)
                            .shadow(color: winFlash ? .yellow.opacity(0.85) : .clear, radius: winFlash ? 18 : 0)
                            .scaleEffect(winFlash ? 1.1 : 1.0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.45), value: winFlash)
                        Text("WIN  \(viewModel.state.lastPayout)  credits")
                            .font(.display(16, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                            .scaleEffect(winFlash ? 1.08 : 1.0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.45).delay(0.05), value: winFlash)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)
                    .background(Color.blue.opacity(0.9))
                    .cornerRadius(8)
                    .shadow(radius: 5)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                } else {
                    VStack(spacing: 6) {
                        Text("Not today, partner!")
                            .font(.display(26, weight: .black))
                            .foregroundColor(.white)
                        Text("Ante up!")
                            .font(.display(16, weight: .bold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)
                    .background(Color.blue.opacity(0.9))
                    .cornerRadius(8)
                    .shadow(radius: 5)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.state.phase)
    }

    // MARK: - Hold / New Labels

    private var holdLabels: some View {
        HStack(spacing: 16) {
            ForEach(0..<5, id: \.self) { idx in
                Text("")
                    .font(.display(11, weight: .black))
                    .frame(width: scaledCardW, alignment: .center)
            }
        }
        .frame(height: 16)
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
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.8), radius: 6, x: 0, y: 3)
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

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            switch viewModel.state.phase {
            case .deal, .result:
                casinoButton("-", color: .white.opacity(0.2)) { viewModel.decreaseBet() }
                casinoButton("BET MAX", color: .orange.opacity(0.85)) { viewModel.maxBet() }
                casinoButton("+", color: .white.opacity(0.2)) { viewModel.increaseBet() }

                Divider().frame(height: 36).overlay(Color.white.opacity(0.3))

                casinoButton("DEAL", color: .yellow, textColor: .black,
                             disabled: viewModel.state.sessionCredits < viewModel.state.currentBet) {
                    viewModel.deal()
                }

            case .holding:
                casinoButton("HOLD ALL  [H]", color: .white.opacity(0.2)) { holdAll() }
                casinoButton("CLEAR  [C]",    color: .white.opacity(0.2)) { clearHolds() }

                Divider().frame(height: 36).overlay(Color.white.opacity(0.3))

                casinoButton("DRAW", color: .green.opacity(0.85)) { viewModel.draw() }
            }

            if viewModel.state.sessionCredits < viewModel.state.currentBet && viewModel.state.phase != .holding {
                casinoButton("REBUY", color: .red.opacity(0.8)) { viewModel.rebuy() }
            }
        }
    }

    private func casinoButton(
        _ label: String,
        color: Color,
        textColor: Color = .white,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
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

    // MARK: - Keyboard Shortcuts

    private var keyboardShortcuts: some View {
        Group {
            // Space — deal or draw
            Button("") { handleSpace() }
                .keyboardShortcut(.space, modifiers: [])
            // 1–5 — toggle hold for that card position
            Button("") { toggleHoldKey(at: 0) }.keyboardShortcut("1", modifiers: [])
            Button("") { toggleHoldKey(at: 1) }.keyboardShortcut("2", modifiers: [])
            Button("") { toggleHoldKey(at: 2) }.keyboardShortcut("3", modifiers: [])
            Button("") { toggleHoldKey(at: 3) }.keyboardShortcut("4", modifiers: [])
            Button("") { toggleHoldKey(at: 4) }.keyboardShortcut("5", modifiers: [])
            // H / C — hold all / clear
            Button("") { holdAll()    }.keyboardShortcut("h", modifiers: [])
            Button("") { clearHolds() }.keyboardShortcut("c", modifiers: [])
        }
    }

    // MARK: - Keyboard Actions

    private func animateDeal() {
        let startAngles: [Double] = [-8, -5, 0, 5, 8]
        cardVisible  = Array(repeating: false, count: 5)
        cardRotation = startAngles
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.06) {
                cardVisible[i]  = true
                cardRotation[i] = 0
            }
        }
    }

    private func handleSpace() {
        switch viewModel.state.phase {
        case .deal, .result:
            guard viewModel.state.sessionCredits >= viewModel.state.currentBet else { return }
            viewModel.deal()
        case .holding:
            viewModel.draw()
        }
    }

    private func toggleHoldKey(at index: Int) {
        guard viewModel.state.phase == .holding else { return }
        viewModel.toggleHold(at: index)
    }

    private func holdAll() {
        guard viewModel.state.phase == .holding else { return }
        for i in 0..<5 { viewModel.state.heldIndices.insert(i) }
    }

    private func clearHolds() {
        guard viewModel.state.phase == .holding else { return }
        viewModel.state.heldIndices.removeAll()
    }

    private func formatTime(_ s: Int) -> String {
        String(format: "%02d:%02d", s / 60, s % 60)
    }
}

// MARK: - Options View

struct VideoPokerOptionsView: View {
    @Bindable var viewModel: VideoPokerViewModel
    @Binding var isShowingStats: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var variant: VideoPokerVariant
    @State private var startingCredits: Int
    @State private var betPerHand: Int
    @State private var isSoundEnabled: Bool
    @State private var hideHintButton: Bool
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

    init(viewModel: VideoPokerViewModel, isShowingStats: Binding<Bool>) {
        self.viewModel = viewModel
        self._isShowingStats = isShowingStats
        _variant         = State(initialValue: viewModel.options.variant)
        _startingCredits = State(initialValue: viewModel.options.startingCredits)
        _betPerHand      = State(initialValue: viewModel.options.betPerHand)
        _isSoundEnabled  = State(initialValue: viewModel.options.isSoundEnabled)
        _hideHintButton  = State(initialValue: viewModel.options.hideHintButton)
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
        let init_c: Color = (r == 0 && g == 0 && b == 0)
            ? Color(red: 0.35, green: 0.15, blue: 0.45)
            : Color(red: r, green: g, blue: b)
        _customSelectedColor = State(initialValue: init_c)
    }

    var body: some View {
        ZStack {
        VStack(spacing: 20) {
            Text("Video Poker Preferences")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .padding(.top, 12)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                    Picker("Variant:", selection: $variant) {
                        ForEach(VideoPokerVariant.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .font(.system(.body, design: .monospaced))

                    Stepper("Starting Credits: \(startingCredits)", value: $startingCredits, in: 100...10000, step: 100)
                        .font(.system(.body, design: .monospaced))

                    Picker("Default Bet:", selection: $betPerHand) {
                        ForEach(1...5, id: \.self) { n in Text("\(n) coin\(n == 1 ? "" : "s")").tag(n) }
                    }
                    .font(.system(.body, design: .monospaced))

                    Divider()

                    Toggle("Sound Effects",    isOn: $isSoundEnabled).font(.system(.body, design: .monospaced))
                    Toggle("Hide Stats button",isOn: $hideStatsButton).font(.system(.body, design: .monospaced))

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
                    let variantChanged = variant != viewModel.options.variant
                    var o = viewModel.options
                    o.variant         = variant
                    o.startingCredits = startingCredits
                    o.betPerHand      = betPerHand
                    o.isSoundEnabled  = isSoundEnabled
                    o.hideHintButton  = hideHintButton
                    o.hideStatsButton    = hideStatsButton
                    o.showFeltVignette   = showFeltVignette
                    o.feltColor          = feltColor
                    o.cardBackTheme   = cardBackTheme
                    o.customCardColors = customCardColors
                    o.customFeltColorRevision += 1
                    viewModel.options = o
                    if variantChanged { viewModel.startNewGame() }
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

struct VideoPokerStatsView: View {
    var viewModel: VideoPokerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingResetConfirmation = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Video Poker Statistics")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .padding(.top, 16)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                statRow("Hands Played",  "\(viewModel.statistics.handsPlayed)")
                statRow("Hands Won",     "\(viewModel.statistics.handsWon)")
                statRow("Win Rate",      String(format: "%.1f%%", viewModel.statistics.winRate * 100))
                statRow("Biggest Pay",   "\(viewModel.statistics.biggestPayout)")
                statRow("Total Wagered", "\(viewModel.statistics.totalWagered)")
                statRow("Total Paid",    "\(viewModel.statistics.totalPaidOut)")
                statRow("RTP",           String(format: "%.1f%%", viewModel.statistics.returnToPlayer * 100))
                statRow("Royal Flushes", "\(viewModel.statistics.royalFlushCount)")
                statRow("Rebuys",        "\(viewModel.statistics.rebuyCount)")
            }
            .padding(.horizontal, 24)

            Divider()

            HStack {
                Button("Reset Stats") { showingResetConfirmation = true }
                    .foregroundColor(.red)
                    .font(.system(.body, design: .monospaced))
                    .alert("Reset Statistics?", isPresented: $showingResetConfirmation) {
                        Button("Reset", role: .destructive) { viewModel.resetStatistics() }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will permanently clear all statistics. This cannot be undone.")
                    }
                Spacer()
                Button("Done") { dismiss() }
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
