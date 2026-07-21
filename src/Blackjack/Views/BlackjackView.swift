import SwiftUI
import AppKit

public struct BlackjackView: View {
    var viewModel: BlackjackViewModel
    @State private var isShowingOptions = false
    @State private var isShowingStats   = false
    @State private var isShowingNewGameConfirm = false
    @State private var showResultBanner  = false
    @State private var bannerWinFlash    = false
    @State private var cardsVisible           = true
    @State private var showCardBackPlaceholders = false
    @State private var dealerFlipped          = false  // triggers hole-card flip animation
    @State private var resultBannerShowTask: DispatchWorkItem? = nil
    @State private var resultHideTask:       DispatchWorkItem? = nil
    @State private var resultCardHideTask:   DispatchWorkItem? = nil
    @State private var showIdlePrompt    = false
    @State private var hostingWindow: NSWindow? = nil
    @State private var zoomController: WindowZoomController? = nil
    @State private var idlePromptTask:   DispatchWorkItem? = nil
    // Measured width of the top toolbar row — drives the icon-only compact button swap.
    // Starts generous so buttons show full text before the first layout pass measures it.
    @State private var toolbarWidth: CGFloat = 2000
    @State private var windowContentHeight: CGFloat = 900
    // Same idea, for the in-game action button row (Hit/Stand/Double/Split/etc.).
    @State private var actionButtonsWidth: CGFloat = 2000
    // Measured natural (unscaled) height of the board content — drives the fit-to-window
    // scale math. Replaces a hand-estimated constant that drifted out of sync with the
    // real content and let the action buttons get clipped by the window's bottom edge.
    // Starts generous (more than any real mode needs) so the first-frame scale is an
    // underestimate rather than an overflow before the first real measurement lands.
    @State private var measuredBoardHeight: CGFloat = 900
    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator

    private let cardScale: CGFloat = 1.4
    private var cardW: CGFloat { 128 * cardScale }  // ≈179
    private var cardH: CGFloat { 181 * cardScale }  // ≈253

    // Card overlap: light for the dealer/single-hand row, tight once a hand is split
    // so both hands can grow without shrinking (shrinking stays as a fallback for very long hands).
    private let lightOverlapFraction: CGFloat = 0.3
    private let tightOverlapFraction: CGFloat = 0.55
    private let tightestOverlapFraction: CGFloat = 0.75

    // The toolbar stays fixed size regardless of the board's scale; only the board below
    // it scales to fit the window.
    static let toolbarHeight: CGFloat = 85
    // The hotkey legend sits below the scaled board and never scales — reserve fixed room
    // for it so it doesn't get clipped by the window's bottom edge at minimum size.
    private static let legendHeight: CGFloat = 28
    // Hard floor the window can be dragged down to — the board's own scale (see
    // recomputeScale()) fits content to whatever size the window actually is, so this only
    // needs to keep the toolbar legible and a sliver of the board visible. If the player
    // drags the window down near this floor, cards may clip — an accepted tradeoff.
    static let minWindowSize = NSSize(width: 340, height: 403)
    // The size the window opens at when there's no saved "make current size the default"
    // preference — numerically the same size this app has always opened at for normal
    // play (previously toolbarHeight + boardBaseHeight + legendHeight + 28, at the old
    // zoom=1 baseline).
    static let defaultOpeningSize = NSSize(width: 905, height: 868)
    // Below these measured widths, buttons swap their text label for an icon-only SF
    // Symbol to save space — hand-estimated, not measured from a live render.
    private static let compactToolbarWidthThreshold: CGFloat = 420
    private static let compactActionButtonsWidthThreshold: CGFloat = 520

    public init(viewModel: BlackjackViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            // Board Background — a custom image if one's active, otherwise the app-wide
            // shared felt color on AppCoordinator (not per-game options).
            BackgroundLayerView()
                .ignoresSafeArea()

            if coordinator.showFeltVignette { FeltVignetteView() }

            VStack(spacing: 0) {
                // Stationary toolbar — never scales with zoom
                toolbarView
                    .padding(.horizontal, 16)
                    .padding(.top, 36) // Clear the macOS traffic light window controls
                    .padding(.bottom, 8)

                Divider().overlay(Color.white.opacity(0.2))

                // Scaled board area — GeometryReader measures the true available width
                // directly and the centering offset is computed as plain arithmetic and
                // applied via .offset(x:), rather than relying on frame(alignment:) or
                // Spacer-flanking, both of which proved inconsistent here across several
                // attempts (worse the more the board is scaled down from its 905pt width).
                GeometryReader { outerGeo in
                    VStack(spacing: 12) {
                        if !viewModel.isFreePlay {
                            creditDisplay
                        }

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
                    .frame(width: 905, alignment: .topLeading)
                    .background(GeometryReader { geo in
                        Color.clear
                            .onAppear { measuredBoardHeight = geo.size.height }
                            .onChange(of: geo.size.height) { _, newHeight in measuredBoardHeight = newHeight }
                    })
                    .scaleEffect(viewModel.zoomScale, anchor: .topLeading)
                    .frame(width: 905 * viewModel.zoomScale, height: measuredBoardHeight * viewModel.zoomScale, alignment: .topLeading)
                    .offset(x: max(0, (outerGeo.size.width - 905 * viewModel.zoomScale) / 2))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Result banner overlay
            if showResultBanner && !viewModel.state.lastResultSummary.isEmpty {
                resultBanner
            }

            // Keyboard shortcuts
            keyboardShortcuts
                .opacity(0)
                .frame(width: 0, height: 0)
                .clipped()

            HotkeyLegendView(text: "Space=Deal   H=Hit   S=Stand   D=Double Down   P=Split")
        }
        .frame(minWidth: Self.minWindowSize.width, maxWidth: .infinity,
               minHeight: Self.minWindowSize.height, maxHeight: .infinity)
        .onAppear {
            DispatchQueue.main.async {
                applyInitialWindowSize()
            }
        }
        .background(WindowAccessor(callback: { window in
            self.hostingWindow = window
            self.zoomController = WindowZoomController(window: window)
            coordinator.activeWindow = window
            DispatchQueue.main.async {
                applyInitialWindowSize()
            }
        }, onResize: recomputeScale))
        .onChange(of: viewModel.options.noStressMode) { recomputeScale() }
        .onChange(of: measuredBoardHeight) { recomputeScale() }
        .environment(\.activeCardBackTheme, coordinator.cardBackTheme)
        .environment(\.activeCustomCardColors, coordinator.customCardColors)
        .overlay {
            if isShowingOptions {
                Color.clear
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .overlay(
                        BlackjackOptionsView(viewModel: viewModel, isShowingStats: $isShowingStats, isPresented: $isShowingOptions, coordinator: coordinator, availableWidth: toolbarWidth, availableHeight: windowContentHeight)
                    )
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $isShowingStats) {
            BlackjackStatsView(viewModel: viewModel)
        }
        .confirmationDialog("Start a new game?", isPresented: $isShowingNewGameConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("New Game", role: .destructive) { viewModel.startNewGame() }
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
                withAnimation(.easeIn(duration: 0.3)) { cardsVisible = true }
                let bannerShowTask = DispatchWorkItem { showResultBanner = true }
                resultBannerShowTask = bannerShowTask
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: bannerShowTask)
                let bannerTask = DispatchWorkItem {
                    let hideTask = DispatchWorkItem {
                        withAnimation(.easeOut(duration: 0.4)) { cardsVisible = false; showResultBanner = false }
                        // Cards fully faded — show card backs then schedule idle prompt
                        let promptTask = DispatchWorkItem {
                            showCardBackPlaceholders = true
                            withAnimation(.easeIn(duration: 0.3)) { cardsVisible = true }
                            withAnimation(.easeInOut(duration: 0.6)) { showIdlePrompt = true }
                        }
                        idlePromptTask = promptTask
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: promptTask)
                    }
                    resultCardHideTask = hideTask
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: hideTask)
                }
                resultHideTask = bannerTask
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: bannerTask)
            }
            if newPhase == .betting || newPhase == .playing {
                resultBannerShowTask?.cancel()
                resultBannerShowTask = nil
                resultHideTask?.cancel()
                resultHideTask = nil
                resultCardHideTask?.cancel()
                resultCardHideTask = nil
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
        .onChange(of: viewModel.debugBannerRequest) { _, kind in
            guard let kind else { return }
            viewModel.debugBannerRequest = nil
            resultBannerShowTask?.cancel()
            resultHideTask?.cancel()
            resultCardHideTask?.cancel()
            showResultBanner = false
            cardsVisible = true
            showCardBackPlaceholders = false
            dealerFlipped = true
            viewModel.debugSetupBannerState(kind)
            showResultBanner = true
        }
    }

    // MARK: - Toolbar

    private var toolbarView: some View {
        HStack(spacing: 20) {
            GameSelectionDropdown(coordinator: coordinator)
            toolbarButton("Options", systemImage: "gearshape", disabled: !viewModel.canOpenOptions) {
                isShowingOptions = true
            }
            Spacer()
        }
    }

    private func toolbarButton(_ label: String, systemImage: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        GameToolbarButton(
            label: label, systemImage: systemImage,
            isCompact: toolbarWidth < Self.compactToolbarWidthThreshold,
            disabled: disabled, action: action
        )
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
                    .foregroundColor(viewModel.state.currentBet == viewModel.state.sessionCredits ? .orange : .white)
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
        let dealerOverlapFraction: CGFloat = viewModel.state.dealerCards.count >= 6 ? tightOverlapFraction : lightOverlapFraction
        return VStack(spacing: 8) {
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

            HStack(spacing: -cardW * dealerOverlapFraction) {
                if viewModel.state.dealerCards.isEmpty || showCardBackPlaceholders {
                    ForEach(0..<2, id: \.self) { _ in
                        CardView(card: Card(suit: .spades, rank: 1, faceUp: false))
                            .scaleEffect(cardScale)
                            .frame(width: cardW, height: cardH)
                            .onTapGesture { viewModel.deal() }
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
    // Disabled — cards now overlap (tight overlap on splits), which saves enough room
    // that hands no longer need to shrink.
    private var playerCardScale: CGFloat {
        // let maxCards = viewModel.state.playerHands.map { $0.cards.count }.max() ?? 2
        // let isSplit = viewModel.state.playerHands.count > 1
        // if isSplit {
        //     switch maxCards {
        //     case ..<3: return cardScale
        //     case 3:    return 1.0
        //     case 4:    return 0.78
        //     default:   return 0.65
        //     }
        // } else {
        //     switch maxCards {
        //     case ..<5: return cardScale   // 2–4 cards — full size
        //     case 5:    return 0.85
        //     default:   return 0.70        // 6+
        //     }
        // }
        return cardScale
    }
    private var playerCardW: CGFloat { 128 * playerCardScale }
    private var playerCardH: CGFloat { 181 * playerCardScale }

    private var playerArea: some View {
        let isSplit = viewModel.state.playerHands.count > 1
        let scale  = playerCardScale
        let width  = playerCardW
        let height = playerCardH
        let columns = isSplit
            ? [GridItem(.flexible()), GridItem(.flexible())]
            : [GridItem(.flexible())]

        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("PLAYER")
                    .font(.display(12, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                if !viewModel.state.playerHands.isEmpty && !showCardBackPlaceholders {
                    let label = viewModel.state.playerHands.map { "\($0.value)" }.joined(separator: " / ")
                    Text(label)
                        .font(.display(14, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                }
            }

            if viewModel.state.playerHands.isEmpty || showCardBackPlaceholders {
                HStack(spacing: -cardW * lightOverlapFraction) {
                    ForEach(0..<2, id: \.self) { _ in
                        CardView(card: Card(suit: .spades, rank: 1, faceUp: false))
                            .scaleEffect(cardScale)
                            .frame(width: cardW, height: cardH)
                            .onTapGesture { viewModel.deal() }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: cardH + 40)
            } else {

            LazyVGrid(columns: columns, alignment: .center, spacing: 16) {
                ForEach(Array(viewModel.state.playerHands.enumerated()), id: \.offset) { handIdx, hand in
                    let isActive = handIdx == viewModel.state.activeHandIndex && viewModel.state.phase == .playing
                    let overlapFraction: CGFloat = {
                        if isSplit {
                            return hand.cards.count >= 4 ? tightestOverlapFraction : tightOverlapFraction
                        } else {
                            return hand.cards.count >= 6 ? tightOverlapFraction : lightOverlapFraction
                        }
                    }()
                    let handSpacing = -width * overlapFraction
                    VStack(spacing: 8) {
                        HStack(spacing: handSpacing) {
                            ForEach(Array(hand.cards.enumerated()), id: \.offset) { cardIdx, card in
                                CardView(card: card)
                                    .scaleEffect(scale)
                                    .frame(width: width, height: height)
                                    .opacity(cardsVisible ? 1 : 0)
                                    .animation(.easeIn(duration: 0.15).delay(Double(cardIdx) * 0.08), value: cardsVisible)
                            }
                        }
                        // No .padding() here — keeps the label-to-cards gap identical to
                        // dealerArea's (which has no equivalent padding). The highlight
                        // border's breathing room is added via negative padding on the
                        // overlay itself instead, so it doesn't affect layout/spacing.
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSplit && isActive ? Color.yellow.opacity(0.85) : Color.clear, lineWidth: 2)
                                .padding(-8)
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: playerCardH + 40)
            } // end else (playerHands non-empty)
        }
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
            headline = "Blackjack!"
            subline = net > 0 ? "+\(net) credits" : net < 0 ? "\(net) credits" : "Even"
            isWin = true
        } else if anyWin {
            headline = "You win!"
            subline = net > 0 ? "+\(net) credits" : net < 0 ? "\(net) credits" : "Even"
            isWin = true
        } else if allPush {
            headline = "Push"
            subline = "Bets returned"
            isWin = false
        } else {
            let playerBust = !viewModel.state.playerHands.isEmpty && viewModel.state.playerHands.allSatisfy { $0.isBust }
            headline = playerBust ? "Bust!" : "Not today, partner!"
            subline = net > 0 ? "+\(net) credits" : net < 0 ? "\(net) credits" : "Even"
            isWin = false
        }
        
        let streak = viewModel.statistics.currentStreak
        let streakText: String?
        if streak >= 2 && isWin {
            streakText = streak >= 5 ? "*** \(streak) WIN STREAK ***"
                       : streak >= 3 ? "** \(streak) WIN STREAK **"
                       :               "\(streak) wins in a row!"
        } else {
            streakText = nil
        }
        
        let dealerVal = viewModel.state.dealerValue
        let playerVal = viewModel.state.playerHands.map { $0.value }.max() ?? 0

        return VStack(spacing: 8) {
            Text(headline)
                .font(.system(size: 36, weight: .black))
                .foregroundColor(.yellow)
                .multilineTextAlignment(.center)
                .scaleEffect(isWin && bannerWinFlash ? 1.06 : 1.0)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: bannerWinFlash)
                .onAppear { if isWin { bannerWinFlash = true } }
                .onDisappear { bannerWinFlash = false }

            if !viewModel.isFreePlay {
                Text(subline)
                    .font(.system(.body))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 2) {
                Text("Dealer: \(dealerVal)")
                Text("Player: \(playerVal)")
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.white.opacity(0.7))
            .multilineTextAlignment(.center)

            if let streakText = streakText {
                Text(streakText)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.yellow.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 12)
                    .padding(.vertical, 24)
        .frame(maxWidth: isWin ? 280 : 420)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.black.opacity(0.75))
        .cornerRadius(12)
        .shadow(color: isWin ? Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.5) : .clear, radius: 16)
        .transition(.opacity)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            switch viewModel.state.phase {
            case .betting, .result:
                HStack(spacing: 12) {
                    if !viewModel.isFreePlay {
                        casinoButton("CLEAR BET", systemImage: "xmark", color: Color(white: 0.25)) { viewModel.clearBet() }
                        Divider().frame(height: 36).overlay(Color.white.opacity(0.3))
                    }
                    casinoButton("DEAL  [Space]", systemImage: "play.fill", color: .yellow,
                                 disabled: !viewModel.isFreePlay && viewModel.state.sessionCredits < viewModel.state.currentBet) {
                        viewModel.deal()
                    }
                    if viewModel.canRebuy {
                        Divider().frame(height: 36).overlay(Color.white.opacity(0.3))
                        casinoButton("REBUY", systemImage: "creditcard", color: .red.opacity(0.8)) { viewModel.rebuy() }
                    }
                }

                if !viewModel.isFreePlay {
                    HStack(spacing: 12) {
                        casinoButton("1",  color: .white, textColor: .black) { viewModel.addToBet(1) }
                        casinoButton("5",  color: .red.opacity(0.85)) { viewModel.addToBet(5) }
                        casinoButton("10", color: .blue.opacity(0.75)) { viewModel.addToBet(10) }
                        casinoButton("25", color: .green.opacity(0.75)) { viewModel.addToBet(25) }
                        casinoButton("2X", color: .orange.opacity(0.85)) { viewModel.doubleBet() }
                    }
                } else {
                    phantomChipRow
                }

            case .playing:
                HStack(spacing: 12) {
                    if viewModel.activeHand?.isSplitAce == true {
                        // Split Aces auto-stand after one card — no player action, just a brief pause.
                        casinoButton("HIT  [H]",   systemImage: "plus.circle", color: .green.opacity(0.3), disabled: true) {}
                        casinoButton("STAND  [S]", systemImage: "hand.raised", color: .red.opacity(0.3),   disabled: true) {}
                    } else {
                        casinoButton("HIT  [H]",       systemImage: "plus.circle", color: .green.opacity(0.85))  { viewModel.hit() }
                        casinoButton("STAND  [S]",     systemImage: "hand.raised", color: .red.opacity(0.75))    { viewModel.stand() }
                        if viewModel.canDouble {
                            casinoButton("DOUBLE  [D]", systemImage: "arrow.up.circle", color: .blue.opacity(0.75)) { viewModel.doubleDown() }
                        }
                        if viewModel.canSplit {
                            casinoButton("SPLIT  [P]", systemImage: "square.split.2x1", color: .purple.opacity(0.75)) { viewModel.split() }
                        }
                    }
                }
                // Reserves the same second-row height the betting/result phase's chip row
                // occupies, so switching phases never changes the board's measured height —
                // that would otherwise re-trigger the fit-to-window scale and visibly shift
                // everything above the buttons.
                phantomChipRow

            case .dealerTurn:
                HStack(spacing: 12) {
                    casinoButton("HIT  [H]",       systemImage: "plus.circle", color: .green.opacity(0.3), disabled: true) {}
                    casinoButton("STAND  [S]",     systemImage: "hand.raised", color: .red.opacity(0.3),   disabled: true) {}
                }
                phantomChipRow
            }
        }
    }

    // Invisible stand-in for the betting/result chip row, reserving its exact height in
    // every other phase so the action area's total height — and therefore the board's
    // measured/scaled height — never changes when the phase changes.
    private var phantomChipRow: some View {
        HStack(spacing: 12) {
            casinoButton("1", color: .clear, textColor: .clear) {}
            casinoButton("5", color: .clear, textColor: .clear) {}
            casinoButton("10", color: .clear, textColor: .clear) {}
            casinoButton("25", color: .clear, textColor: .clear) {}
            casinoButton("2X", color: .clear, textColor: .clear) {}
        }
        .opacity(0)
        .allowsHitTesting(false)
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

    private func casinoButton(_ label: String, systemImage: String? = nil, color: Color, textColor: Color = .white,
                               disabled: Bool = false, action: @escaping () -> Void) -> some View {
        let isCompact = systemImage != nil && actionButtonsWidth < Self.compactActionButtonsWidthThreshold
        return Button(action: action) {
            Group {
                if isCompact, let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .black))
                } else {
                    Text(label)
                        .font(.display(14, weight: .black))
                }
            }
            .foregroundColor(disabled ? textColor.opacity(0.4) : textColor)
            .padding(.horizontal, isCompact ? 14 : 18)
            .padding(.vertical, 10)
            .background(disabled ? Color.gray.opacity(0.3) : color)
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(PressButtonStyle())
        .disabled(disabled)
        .focusable(false)
        .accessibilityLabel(label)
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

    // Continuously refits the board's scale to the window's current content size — called
    // on every window resize (via WindowAccessor's onResize) and whenever No Stress Mode
    // changes without the window moving. Both toolbarHeight and legendHeight are excluded
    // from the height side of the fit, since neither scales with the board. Never touches
    // the window frame itself — a pure property write, which is what keeps this loop-safe.
    private func recomputeScale() {
        guard let window = hostingWindow else { return }
        let contentSize = window.contentView?.frame.size ?? window.frame.size
        toolbarWidth = contentSize.width
        windowContentHeight = contentSize.height
        actionButtonsWidth = contentSize.width
        let scaleX = contentSize.width / 905.0
        let scaleY = (contentSize.height - Self.toolbarHeight - Self.legendHeight) / measuredBoardHeight
        viewModel.zoomScale = min(2.0, max(0.3, min(scaleX, scaleY)))
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

    private func formatTime(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - Options View

struct BlackjackOptionsView: View {
    @Bindable var viewModel: BlackjackViewModel
    @Binding var isShowingStats: Bool
    @Binding var isPresented: Bool
    @Bindable var coordinator: AppCoordinator

    @State private var startingCredits: Int
    @State private var isSoundEnabled: Bool
    @State private var noStressMode: Bool
    let availableWidth: CGFloat
    let availableHeight: CGFloat

    init(viewModel: BlackjackViewModel, isShowingStats: Binding<Bool>, isPresented: Binding<Bool>, coordinator: AppCoordinator, availableWidth: CGFloat = 2000, availableHeight: CGFloat = 900) {
        self.viewModel = viewModel
        self._isShowingStats = isShowingStats
        self._isPresented = isPresented
        self.coordinator = coordinator
        self.availableWidth = availableWidth
        self.availableHeight = availableHeight
        _startingCredits = State(initialValue: viewModel.options.startingCredits)
        _isSoundEnabled  = State(initialValue: viewModel.options.isSoundEnabled)
        _noStressMode    = State(initialValue: viewModel.options.noStressMode)
    }

    var body: some View {
        OptionsSheetShell(
            isPresented: $isPresented,
            coordinator: coordinator,
            availableWidth: availableWidth,
            availableHeight: availableHeight,
            maxContentHeight: 560,
            fixedSizeHorizontal: false,
            onViewStats: { isShowingStats = true },
            onOK: {
                var o = viewModel.options
                o.startingCredits = startingCredits
                o.isSoundEnabled  = isSoundEnabled
                o.noStressMode    = noStressMode
                viewModel.options = o
            }
        ) {
            Stepper("Starting Credits: \(startingCredits)", value: $startingCredits, in: 10...10000, step: 10)
                .font(.system(.body))

            Divider()

            Toggle("Sound Effects",     isOn: $isSoundEnabled).font(.system(.body))
            Toggle("No Stress Mode",    isOn: $noStressMode).font(.system(.body))
        }
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
                .font(.system(size: 16, weight: .bold))
                .padding(.top, 16)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                statRow("Hands Played",  "\(viewModel.statistics.handsPlayed)")
                statRow("Hands Won",     "\(viewModel.statistics.handsWon)")
                statRow("Hands Lost",    "\(viewModel.statistics.handsLost)")
                statRow("Pushes",        "\(viewModel.statistics.pushes)")
                statRow("Blackjacks",    "\(viewModel.statistics.blackjacks)")
                statRow("Win Rate",       String(format: "%.1f%%", viewModel.statistics.winRate * 100))
                statRow("Cur. Streak",   "\(viewModel.statistics.currentStreak)")
                statRow("Best Streak",   "\(viewModel.statistics.longestStreak)")
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
                    .font(.system(.body))
                    .alert("Reset Statistics?", isPresented: $showingResetConfirmation) {
                        Button("Reset", role: .destructive) { viewModel.resetStatistics() }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will permanently clear all Blackjack statistics. This cannot be undone.")
                    }
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .font(.system(.body))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(width: 340)
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(.body))
            Spacer()
            Text(value).font(.system(.body)).fontWeight(.bold)
        }
    }
}
