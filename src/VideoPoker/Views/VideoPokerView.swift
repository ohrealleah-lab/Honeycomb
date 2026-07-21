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
    @State private var showParticles         = false
    @State private var showResultBanner      = false
    @State private var cardsVisible          = true
    @State private var showCardBackPlaceholders = true
    @State private var showIdlePrompt   = false
    @State private var hostingWindow: NSWindow? = nil
    @State private var zoomController: WindowZoomController? = nil
    @State private var spaceMonitor: Any? = nil
    // Measured width of the top toolbar row — drives the icon-only compact button swap.
    // Starts generous so buttons show full text before the first layout pass measures it.
    @State private var toolbarWidth: CGFloat = 2000
    @State private var windowContentHeight: CGFloat = 900
    // Same idea, for the in-game action button row (Deal/Draw/Hold All/etc.).
    @State private var actionButtonsWidth: CGFloat = 2000
    // Measured natural (unscaled) height of the board content — drives the fit-to-window
    // scale math. Replaces hand-estimated per-mode constants that drifted out of sync with
    // the real content and let the action buttons get clipped by the window's bottom edge.
    // Starts generous (more than any real mode needs) so the first-frame scale is an
    // underestimate rather than an overflow before the first real measurement lands.
    @State private var measuredBoardHeight: CGFloat = 900
    @State private var resultBannerShowTask: DispatchWorkItem? = nil
    @State private var resultWinFlashTask:   DispatchWorkItem? = nil
    @State private var resultAnimationTask:  DispatchWorkItem? = nil
    @State private var resultHideTask:       DispatchWorkItem? = nil
    @State private var idlePromptTask:       DispatchWorkItem? = nil
    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator

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
    static let minWindowSize = NSSize(width: 520, height: 450)
    // The size the window opens at when there's no saved "make current size the default"
    // preference — numerically the same size this app has always opened at for normal
    // single-play mode (previously toolbarHeight + boardBaseHeight + legendHeight + 28, at
    // the old zoom=1 baseline).
    static let defaultOpeningSize = NSSize(width: 905, height: 680)
    // Below this measured toolbar width, buttons swap their text label for an icon-only
    // SF Symbol to save space — hand-estimated, not measured from a live render.
    private static let compactToolbarWidthThreshold: CGFloat = 420
    // Same idea, for the wider in-game action button row.
    private static let compactActionButtonsWidthThreshold: CGFloat = 520
    // Triple Play never shows the pay table, so its cards can be a comfortable, fully
    // legible size (120pt wide — 100pt base bumped 20% — matching CardView's true
    // 128x181 native aspect ratio) rather than a tiny thumbnail.
    private static let tripleCardScale: CGFloat = 120.0 / 128.0
    private static let tripleRowSpacing: CGFloat = 12
    // Extra headroom above each triple-play row's card height so the "lift held card"
    // offset animation has room without being clipped by the row's own bounds.
    private static let tripleRowSlack: CGFloat = 16
    private static let tripleRowHeight: CGFloat = 181 * tripleCardScale + tripleRowSlack

    public init(viewModel: VideoPokerViewModel) {
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
                    VStack(spacing: 0) {
                        if !(viewModel.options.hideBetBoard || viewModel.options.noStressMode) && viewModel.options.playMode != .triple {
                            payTableGrid
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                                .padding(.bottom, 6)

                            Divider().overlay(Color.white.opacity(0.1))
                        }

                        VStack(spacing: 16) {
                            if !viewModel.isFreePlay {
                                creditDisplay
                            }
                            if viewModel.options.playMode != .triple {
                                resultLabel
                            }
                            handArea
                            holdLabels
                            // +24pt (50% more than the surrounding 16pt VStack spacing +
                            // holdLabels' own 16pt height = 48pt total gap between the cards and
                            // the buttons below, before this) — added here rather than before
                            // holdLabels so the hold indicators stay close to the cards they
                            // label once cards are actually dealt.
                            actionButtons
                                .padding(.top, 24)
                        }
                        .padding(.horizontal, 12)
                            .padding(.vertical, 24)
                    }
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

            // Keyboard shortcut buttons (invisible, zero-size)
            keyboardShortcuts
                .opacity(0)
                .frame(width: 0, height: 0)
                .clipped()

            HotkeyLegendView(text: "Space/Enter/D=Deal or Draw   1-5=Toggle Hold   H=Hold All   C=Clear   M=Bet Max")
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
        .onChange(of: viewModel.options.playMode) { recomputeScale() }
        .onChange(of: viewModel.options.noStressMode) { recomputeScale() }
        .onChange(of: viewModel.options.hideBetBoard) { recomputeScale() }
        .onChange(of: measuredBoardHeight) { recomputeScale() }
        .environment(\.activeCardBackTheme, coordinator.cardBackTheme)
        .environment(\.activeCustomCardColors, coordinator.customCardColors)
        .overlay {
            if isShowingOptions {
                Color.clear
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .overlay(
                        VideoPokerOptionsView(viewModel: viewModel, isShowingStats: $isShowingStats, isPresented: $isShowingOptions, coordinator: coordinator, availableWidth: toolbarWidth, availableHeight: windowContentHeight)
                    )
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $isShowingStats) {
            VideoPokerStatsView(viewModel: viewModel)
        }
        .confirmationDialog("Start a new game?", isPresented: $isShowingNewGameConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("New Game", role: .destructive) { viewModel.startNewGame() }
        }
        .onAppear {
            if viewModel.state.phase == .deal {
                withAnimation(.easeInOut(duration: 0.6)) { showIdlePrompt = true }
            }
            
            // Add local key monitor to swallow repeat spacebar events to avoid autoplaying draw
            spaceMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 49 && event.isARepeat {
                    if let firstResponder = NSApp.keyWindow?.firstResponder,
                       firstResponder.isKind(of: NSText.self) || String(describing: type(of: firstResponder)).contains("TextView") {
                        return event
                    }
                    return nil // Swallow spacebar key-repeat
                }
                return event
            }
        }
        .onDisappear {
            if let monitor = spaceMonitor {
                NSEvent.removeMonitor(monitor)
                spaceMonitor = nil
            }
        }
        .onChange(of: viewModel.state.phase) { _, newPhase in
            if newPhase == .result {
                // Cancel any leftover tasks just in case
                resultBannerShowTask?.cancel()
                resultWinFlashTask?.cancel()
                resultAnimationTask?.cancel()
                resultHideTask?.cancel()
                idlePromptTask?.cancel()

                let bannerShowTask = DispatchWorkItem { showResultBanner = true }
                resultBannerShowTask = bannerShowTask
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: bannerShowTask)

                let animationTask = DispatchWorkItem {
                    let hideTask = DispatchWorkItem {
                        withAnimation(.easeOut(duration: 0.4)) { cardsVisible = false; showResultBanner = false }

                        let promptTask = DispatchWorkItem {
                            showCardBackPlaceholders = true
                            withAnimation(.easeInOut(duration: 0.4)) { cardsVisible = true }
                            withAnimation(.easeInOut(duration: 0.6)) { showIdlePrompt = true }
                        }
                        idlePromptTask = promptTask
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: promptTask)
                    }
                    resultHideTask = hideTask
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: hideTask)
                }
                resultAnimationTask = animationTask
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: animationTask)
                
                if viewModel.state.lastPayout > 0 {
                    let winFlashTask = DispatchWorkItem {
                        winFlash = true
                        showParticles = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { winFlash = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { showParticles = false }
                    }
                    resultWinFlashTask = winFlashTask
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: winFlashTask)
                }
            }
            if newPhase == .holding {
                // Cancel result animations immediately
                resultBannerShowTask?.cancel()
                resultBannerShowTask = nil
                resultWinFlashTask?.cancel()
                resultWinFlashTask = nil
                resultAnimationTask?.cancel()
                resultAnimationTask = nil
                resultHideTask?.cancel()
                resultHideTask = nil
                idlePromptTask?.cancel()
                idlePromptTask = nil

                withAnimation(.easeInOut(duration: 0.3)) { showIdlePrompt = false }
                showResultBanner = false
                showCardBackPlaceholders = false
                cardsVisible = true
                animateDeal()
            }
            if newPhase == .deal {
                resultBannerShowTask?.cancel()
                resultBannerShowTask = nil
                resultWinFlashTask?.cancel()
                resultWinFlashTask = nil
                resultAnimationTask?.cancel()
                resultAnimationTask = nil
                resultHideTask?.cancel()
                resultHideTask = nil
                idlePromptTask?.cancel()
                idlePromptTask = nil

                showCardBackPlaceholders = true
                cardsVisible = true
                withAnimation(.easeInOut(duration: 0.6)) { showIdlePrompt = true }
            }
        }
        .onChange(of: viewModel.debugBannerRequest) { _, kind in
            guard let kind else { return }
            viewModel.debugBannerRequest = nil
            resultBannerShowTask?.cancel()
            resultWinFlashTask?.cancel()
            resultAnimationTask?.cancel()
            resultHideTask?.cancel()
            showResultBanner = false
            winFlash = false
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

    // MARK: - Pay Table Grid

    private var payTableGrid: some View {
        let entries = viewModel.payTable
        let half = (entries.count + 1) / 2
        let firstHalf  = Array(entries.prefix(half))
        let secondHalf = Array(entries.dropFirst(half))

        return VStack(spacing: 0) {
            Text(viewModel.options.variant.rawValue.uppercased())
                .font(.system(size: 11, weight: .black))
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
                        .font(.system(size: 9, weight: .bold))
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
                        .font(.system(size: 10, weight: isWinner ? .black : .regular))
                        .foregroundColor(isWinner ? .black : .white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(width: 118, alignment: .leading)
                    ForEach(0..<5, id: \.self) { i in
                        let total = entry.multipliers[i] * (i + 1)
                        Text("\(total)")
                            .font(.system(size: 10, weight: .bold))
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

    private var cardScale: CGFloat {
        viewModel.options.playMode == .triple ? Self.tripleCardScale : 1.4
    }
    // CardView's own intrinsic size is 128x181 (see CardView.swift); single play's
    // existing look uses a 77x122 "logical" base instead (kept as-is to avoid changing
    // its already-correct appearance). Triple play must use CardView's real 128x181
    // base so the scaled card frame actually matches what gets painted — otherwise the
    // card's edges get clipped by the row's .clipped() bounds.
    private var scaledCardW: CGFloat {
        viewModel.options.playMode == .triple ? 128 * cardScale : 77 * cardScale
    }
    private var scaledCardH: CGFloat {
        viewModel.options.playMode == .triple ? 181 * cardScale : 122 * cardScale
    }

    private var handArea: some View {
        Group {
            if viewModel.options.playMode == .triple {
                tripleHandArea
            } else {
                singleHandArea
            }
        }
    }

    private var singleHandArea: some View {
        HStack(spacing: 16) {
            if viewModel.state.hand.isEmpty || showCardBackPlaceholders {
                ForEach(0..<5, id: \.self) { _ in
                    CardView(card: Card(suit: .spades, rank: 1, faceUp: false))
                        .scaleEffect(cardScale)
                        .frame(width: scaledCardW, height: scaledCardH)
                        .onTapGesture { viewModel.deal() }
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
                    let streak = viewModel.statistics.currentStreak
                    let streakText: String? = streak >= 2
                        ? (streak >= 5 ? "*** \(streak) WIN STREAK ***"
                           : streak >= 3 ? "** \(streak) WIN STREAK **"
                           : "\(streak) wins in a row!")
                        : nil
                    VStack(spacing: 8) {
                        Text("\(viewModel.state.lastHandName)!")
                            .font(.system(size: 36, weight: .black))
                            .foregroundColor(.yellow)
                            .scaleEffect(winFlash ? 1.1 : 1.0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.45), value: winFlash)
                        if !viewModel.isFreePlay {
                            Text("+\(viewModel.state.lastPayout) Credits")
                                .font(.system(.body))
                                .foregroundColor(.white)
                        }
                        if let streakText {
                            Text(streakText)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.yellow.opacity(0.9))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                    .fixedSize()
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(12)
                    .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.5), radius: 16)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                } else {
                    VStack(spacing: 8) {
                        Text("Not today, partner!")
                            .font(.system(size: 36, weight: .black))
                            .foregroundColor(.yellow)
                        if !viewModel.isFreePlay {
                            Text("-\(viewModel.state.currentBet) credits")
                                .font(.system(.body))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 24)
                    .frame(maxWidth: 420)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(12)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.state.phase)
    }

    // MARK: - Triple Play Hand Area

    private var tripleHandArea: some View {
        VStack(spacing: 12) {
            if viewModel.state.hand.isEmpty || showCardBackPlaceholders {
                tripleCardBackRow
            } else {
                tripleCardRow(index: 0)
                tripleCardRow(index: 1)
                tripleCardRow(index: 2)
            }
        }
        .opacity(cardsVisible ? 1 : 0)
        .overlay {
            WinParticleView(active: showParticles)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.state.phase)
    }

    private var tripleCardBackRow: some View {
        HStack(spacing: 10) {
            ForEach(0..<5, id: \.self) { _ in
                CardView(card: Card(suit: .spades, rank: 1, faceUp: false))
                    .scaleEffect(cardScale)
                    .frame(width: scaledCardW, height: scaledCardH)
                    .onTapGesture { viewModel.deal() }
            }
        }
        .frame(height: Self.tripleRowHeight, alignment: .bottom)
        .clipped()
    }

    @ViewBuilder
    private func tripleCardRow(index: Int) -> some View {
        let isBaseRow = index == 2
        let isHolding = viewModel.state.phase == .holding

        if !isBaseRow && isHolding {
            // Hands 1 & 2 haven't been dealt yet — show a plain placeholder band
            // instead of a full (and potentially confusing) preview of the base hand.
            tripleBandRow
        } else {
            let cards: [Card] = isBaseRow
                ? viewModel.state.hand
                : (index < viewModel.state.triplePlayHands.count ? viewModel.state.triplePlayHands[index] : viewModel.state.hand)
            let name = index < viewModel.state.triplePlayHandNames.count ? viewModel.state.triplePlayHandNames[index] : ""
            let payout = index < viewModel.state.triplePlayPayouts.count ? viewModel.state.triplePlayPayouts[index] : 0

            HStack(spacing: 10) {
                HStack(spacing: 10) {
                    ForEach(Array(cards.enumerated()), id: \.offset) { idx, card in
                        let isHeld = isBaseRow && viewModel.state.heldIndices.contains(idx)
                        CardView(card: card)
                            .scaleEffect(cardScale)
                            .frame(width: scaledCardW, height: scaledCardH)
                            .offset(y: isHeld && isHolding ? -12 : 0)
                            .animation(.easeInOut(duration: 0.15), value: isHeld)
                            .onTapGesture {
                                if isBaseRow && isHolding {
                                    viewModel.toggleHold(at: idx)
                                }
                            }
                            .shadow(color: .black.opacity(0.3), radius: 3)
                    }
                }
                .frame(height: Self.tripleRowHeight, alignment: .bottom)
                .clipped()
                .transition(.opacity)

                if showResultBanner && !name.isEmpty {
                    tripleBadge(name: name, payout: payout)
                        .transition(.opacity)
                }
            }
        }
    }

    private var tripleBandRow: some View {
        HStack(spacing: 10) {
            ForEach(0..<5, id: \.self) { _ in
                CardView(card: Card(suit: .spades, rank: 1, faceUp: false))
                    .scaleEffect(cardScale)
                    .frame(width: scaledCardW, height: scaledCardH)
            }
        }
        .frame(height: Self.tripleRowHeight, alignment: .bottom)
        .clipped()
        .transition(.opacity)
    }

    private func tripleBadge(name: String, payout: Int) -> some View {
        Text(payout > 0 ? "\(name) +\(payout)" : name)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(payout > 0 ? .black : .white.opacity(0.8))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(payout > 0 ? Color.yellow.opacity(winFlash ? 1.0 : 0.85) : Color.black.opacity(0.4))
            .cornerRadius(6)
            .fixedSize()
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
                Text(viewModel.options.playMode == .triple ? "BET/HAND" : "BET")
                    .font(.display(10))
                    .foregroundColor(.white.opacity(0.6))
                Text("\(viewModel.state.currentBet)")
                    .font(.display(28, weight: .black))
                    .foregroundColor(viewModel.state.currentBet == 5 ? .orange : .white)
            }

            if viewModel.options.playMode == .triple {
                VStack(spacing: 2) {
                    Text("TOTAL BET")
                        .font(.display(10))
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(viewModel.totalBet)")
                        .font(.display(28, weight: .black))
                        .foregroundColor(.white)
                }
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

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            switch viewModel.state.phase {
            case .deal, .result:
                if !viewModel.isFreePlay {
                    casinoButton("-", color: .white.opacity(0.2)) { viewModel.decreaseBet() }
                    casinoButton("BET MAX  [M]", systemImage: "dollarsign.circle", color: .orange.opacity(0.85)) { viewModel.maxBet() }
                    casinoButton("+", color: .white.opacity(0.2)) { viewModel.increaseBet() }

                    Divider().frame(height: 36).overlay(Color.white.opacity(0.3))
                }

                casinoButton("DEAL  [Space]", systemImage: "play.fill", color: .yellow, textColor: .black,
                             disabled: !viewModel.isFreePlay && viewModel.state.sessionCredits < viewModel.totalBet) {
                    viewModel.deal()
                }

            case .holding:
                casinoButton("HOLD ALL  [H]", systemImage: "hand.raised.fill", color: .white.opacity(0.2)) { holdAll() }
                casinoButton("CLEAR  [C]", systemImage: "xmark", color: .white.opacity(0.2)) { clearHolds() }

                Divider().frame(height: 36).overlay(Color.white.opacity(0.3))

                casinoButton("DRAW", systemImage: "arrow.triangle.2.circlepath", color: .green.opacity(0.85)) { viewModel.draw() }
            }

            if !viewModel.isFreePlay && viewModel.state.sessionCredits <= 10 && viewModel.state.phase != .holding {
                casinoButton("REBUY", systemImage: "creditcard", color: .red.opacity(0.8)) { viewModel.rebuy() }
            }
        }
    }

    private func casinoButton(
        _ label: String,
        systemImage: String? = nil,
        color: Color,
        textColor: Color = .white,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
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
            // M — bet max (hidden in free play, where the BET MAX button is also hidden)
            Button("") { if !viewModel.isFreePlay { viewModel.maxBet() } }.keyboardShortcut("m", modifiers: [])
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
            guard viewModel.isFreePlay || viewModel.state.sessionCredits >= viewModel.totalBet else { return }
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

    // Continuously refits the board's scale to the window's current content size — called
    // on every window resize (via WindowAccessor's onResize) and whenever the board's own
    // intrinsic size changes without the window moving (play mode, No Stress Mode, hide
    // bet board). Both toolbarHeight and legendHeight are excluded from the height side of
    // the fit, since neither scales with the board. Never touches the window frame itself
    // — a pure property write, which is what keeps this loop-safe.
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

    private func formatTime(_ s: Int) -> String {
        String(format: "%02d:%02d", s / 60, s % 60)
    }
}

// MARK: - Options View

struct VideoPokerOptionsView: View {
    @Bindable var viewModel: VideoPokerViewModel
    @Binding var isShowingStats: Bool
    @Binding var isPresented: Bool
    @Bindable var coordinator: AppCoordinator

    @State private var variant: VideoPokerVariant
    @State private var playMode: VideoPokerPlayMode
    @State private var startingCredits: Int
    @State private var betPerHand: Int
    @State private var isSoundEnabled: Bool
    @State private var hideHintButton: Bool
    @State private var hideBetBoard: Bool
    @State private var noStressMode: Bool
    let availableWidth: CGFloat
    let availableHeight: CGFloat

    init(viewModel: VideoPokerViewModel, isShowingStats: Binding<Bool>, isPresented: Binding<Bool>, coordinator: AppCoordinator, availableWidth: CGFloat = 2000, availableHeight: CGFloat = 900) {
        self.viewModel = viewModel
        self._isShowingStats = isShowingStats
        self._isPresented = isPresented
        self.coordinator = coordinator
        self.availableWidth = availableWidth
        self.availableHeight = availableHeight
        _variant         = State(initialValue: viewModel.options.variant)
        _playMode        = State(initialValue: viewModel.options.playMode)
        _startingCredits = State(initialValue: viewModel.options.startingCredits)
        _betPerHand      = State(initialValue: viewModel.options.betPerHand)
        _isSoundEnabled  = State(initialValue: viewModel.options.isSoundEnabled)
        _hideHintButton  = State(initialValue: viewModel.options.hideHintButton)
        _hideBetBoard    = State(initialValue: viewModel.options.hideBetBoard)
        _noStressMode    = State(initialValue: viewModel.options.noStressMode)
    }

    var body: some View {
        OptionsSheetShell(
            isPresented: $isPresented,
            coordinator: coordinator,
            availableWidth: availableWidth,
            availableHeight: availableHeight,
            useScrollView: false,
            fixedSizeHorizontal: false,
            onViewStats: { isShowingStats = true },
            onOK: {
                let variantChanged  = variant  != viewModel.options.variant
                let playModeChanged = playMode != viewModel.options.playMode
                var o = viewModel.options
                o.variant         = variant
                o.playMode        = playMode
                o.startingCredits = startingCredits
                o.betPerHand      = betPerHand
                o.isSoundEnabled  = isSoundEnabled
                o.hideHintButton  = hideHintButton
                o.hideBetBoard    = hideBetBoard
                o.noStressMode    = noStressMode
                viewModel.options = o
                if variantChanged || playModeChanged {
                    viewModel.resetHandDisplay()
                }
            }
        ) {
            Picker("Variant:", selection: $variant) {
                ForEach(VideoPokerVariant.allCases, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }
            .font(.system(.body))

            if VideoPokerPlayMode.tripleEnabled {
                Picker("Play Mode:", selection: $playMode) {
                    ForEach(VideoPokerPlayMode.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .font(.system(.body))
            }

            Stepper("Starting Credits: \(startingCredits)", value: $startingCredits, in: 100...10000, step: 100)
                .font(.system(.body))

            Picker("Default Bet:", selection: $betPerHand) {
                ForEach(1...5, id: \.self) { n in Text("\(n) coin\(n == 1 ? "" : "s")").tag(n) }
            }
            .font(.system(.body))

            Divider()

            Toggle("Sound Effects",    isOn: $isSoundEnabled).font(.system(.body))
            Toggle("Hide Bet Board",   isOn: $hideBetBoard).font(.system(.body))
            Toggle("No Stress Mode",   isOn: $noStressMode).font(.system(.body))
        }
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
                .font(.system(size: 16, weight: .bold))
                .padding(.top, 16)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                statRow("Hands Played",  "\(viewModel.statistics.handsPlayed)")
                statRow("Hands Won",     "\(viewModel.statistics.handsWon)")
                statRow("Win Rate",      String(format: "%.1f%%", viewModel.statistics.winRate * 100))
                statRow("Cur. Streak",   "\(viewModel.statistics.currentStreak)")
                statRow("Best Streak",   "\(viewModel.statistics.longestStreak)")
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
