import SwiftUI
import UIKit

/// Touch-first Blackjack for iPhone/iPad, driven by the shared BlackjackViewModel.
/// Button-driven (no drags): dealer row on top (hole card face-down until dealer's
/// turn), player hand(s) below, action buttons (Hit/Stand/Double/Split) replace the
/// bet controls once a hand is in progress. Supports the split-hands display.
struct BlackjackTouchView: View {
    @Bindable var viewModel: BlackjackViewModel
    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator

    @State private var isMenuOpen = false
    @State private var showingOptions = false
    @State private var showingThemes = false
    @State private var showingStats = false

    // Post-result pacing/reset choreography — ported from mac's BlackjackView
    // (.onChange(of: viewModel.state.phase) + chained DispatchWorkItem/asyncAfter), for
    // the same reason as Video Poker's equivalent block: the shared BlackjackViewModel
    // just sits on state.phase == .result forever on its own, so without this iOS had
    // no pause/reset — the result banner appeared instantly and cards stayed revealed
    // until Deal was tapped again. dealerFlipped mirrors mac's own state var 1:1 for
    // timing parity even though — like on mac — nothing here currently reads it for a
    // visual flip; the hole-card reveal is actually driven by the model's card.faceUp
    // data changing synchronously, which TouchCardView's own flip already animates.
    @State private var showResultBanner = false
    @State private var bannerWinFlash = false
    @State private var cardsVisible = true
    @State private var showCardBackPlaceholders = false
    @State private var dealerFlipped = false
    @State private var showIdlePrompt = false
    @State private var resultHideTask: DispatchWorkItem? = nil
    @State private var resultCardHideTask: DispatchWorkItem? = nil
    @State private var idlePromptTask: DispatchWorkItem? = nil

    private let actionHaptic = UIImpactFeedbackGenerator(style: .medium)

    private var canAffordBet: Bool {
        viewModel.isFreePlay || viewModel.state.sessionCredits >= max(viewModel.state.currentBet, 1)
    }

    // Matches mac's BlackjackView overlap tiers exactly (lightOverlapFraction/
    // tightOverlapFraction/tightestOverlapFraction) — cards overlap by default (a
    // fanned hand) rather than card width shrinking to fit N-across at a fixed gap.
    // The old (geo.width - 32) / 6 sizing assumed a worst-case 6-card hand needed to
    // fit with zero overlap, which capped every card at 90pt regardless of how much
    // room was actually available for the common 2-3 card case.
    private let lightOverlapFraction: CGFloat = 0.3
    private let tightOverlapFraction: CGFloat = 0.55
    private let tightestOverlapFraction: CGFloat = 0.75

    private func handSpacing(cardW: CGFloat, count: Int, isSplit: Bool) -> CGFloat {
        let fraction: CGFloat
        if isSplit {
            fraction = count >= 4 ? tightestOverlapFraction : tightOverlapFraction
        } else {
            fraction = count >= 6 ? tightOverlapFraction : lightOverlapFraction
        }
        return -cardW * fraction
    }

    var body: some View {
        GeometryReader { geo in
            let cardW = min(geo.size.width * 0.28, 150)
            let isLandscape = geo.size.width > geo.size.height

            ZStack {
                IOSBackgroundLayer()

                // ScrollView fallback rather than a computed shrink factor — a split
                // stacks a second hand below the first, and landscape's shorter height
                // can't always fit dealer + two hands + controls. Scrolling beats
                // clipping the action buttons off the bottom; portrait already fits
                // without scrolling in the common case.
                ScrollView {
                    VStack(spacing: 16) {
                        topBar
                            .padding(.horizontal, 12)
                            .frame(height: 44)

                        if !viewModel.isFreePlay {
                            creditDisplay
                        }

                        if isLandscape {
                            // Landscape's width can't spare the height a vertical
                            // dealer-then-player stack needs, but it has plenty of width
                            // to spare — dealer left, player right instead.
                            HStack(alignment: .top, spacing: 24) {
                                dealerArea(cardW: cardW)
                                    .frame(maxWidth: .infinity)
                                playerHandsArea(cardW: cardW)
                                    .frame(maxWidth: .infinity)
                            }

                            resultBanner
                        } else {
                            dealerArea(cardW: cardW)

                            resultBanner

                            playerHandsArea(cardW: cardW)
                        }

                        controls
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    }
                    // Flexible Spacers used to sit between the cards and controls,
                    // which combined with this enforced min-height stretched them apart
                    // into a large gap at every screen size — top-aligning instead lets
                    // the content hug together at its natural height (buttons directly
                    // under the cards, matching mac) and pushes any leftover space below
                    // the controls instead of between them.
                    .frame(minHeight: geo.size.height, alignment: .top)
                }
            }
        }
        .environment(\.activeCardBackTheme, coordinator.cardBackTheme)
        .environment(\.activeCustomCardColors, coordinator.customCardColors)
        .sheet(isPresented: $isMenuOpen) { GameSelectionFullScreenView(coordinator: coordinator) }
        .sheet(isPresented: $showingStats) { BlackjackStatsSheet(viewModel: viewModel) }
        .sheet(isPresented: $showingThemes) { ThemesFullScreenView(coordinator: coordinator) }
        .sheet(isPresented: $showingOptions) {
            OptionsFullScreenView(coordinator: coordinator, onShowStats: { showingStats = true }) {
                BlackjackSettingsSection(viewModel: viewModel,
                                         canOpenOptions: viewModel.canOpenOptions)
            }
        }
        .queuedFlashBanner(
            trigger: viewModel.flashBannerTrigger,
            latestMessage: viewModel.flashBanner,
            manuallyDismissBanners: viewModel.options.manuallyDismissBanners,
            onAdvanceQueue: viewModel.advanceBannerQueue
        )
        .onAppear { viewModel.checkLoadingBanner() }
        .onChange(of: viewModel.state.phase) { _, newPhase in
            // Re-arms the idle-nudge timer on every phase change, matching mac
            // (BlackjackView.swift:211) — previously only armed once via
            // startNewGame(), so it could misfire near game start and then never
            // fire again for genuinely idle stretches later in the same session.
            viewModel.scheduleIdleActionCheck()
            if newPhase == .result {
                idlePromptTask?.cancel()
                withAnimation(.easeInOut(duration: 0.4)) { showIdlePrompt = false }
                dealerFlipped = true
                withAnimation(.easeIn(duration: 0.3)) { cardsVisible = true }

                // Shows synchronously rather than through a delayed DispatchWorkItem
                // (mac waits 1.0s first) — a plain, directly-verifiable SwiftUI
                // condition instead of depending on an async task actually firing.
                showResultBanner = true

                let bannerTask = DispatchWorkItem {
                    let hideTask = DispatchWorkItem {
                        withAnimation(.easeOut(duration: 0.4)) { cardsVisible = false; showResultBanner = false }
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
                resultHideTask?.cancel(); resultHideTask = nil
                resultCardHideTask?.cancel(); resultCardHideTask = nil
                idlePromptTask?.cancel(); idlePromptTask = nil

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

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            menuBarButtons(isMenuOpen: $isMenuOpen, showingOptions: $showingOptions, showingThemes: $showingThemes, coordinator: coordinator)

            Spacer()

            Text(coordinator.L(.touchBlackjackTitle))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    // MARK: Credit display

    // Matches mac's BlackjackView creditDisplay (CREDITS/BET/HANDS panel) — iOS
    // previously only had a small credit-card capsule tucked into the top bar showing
    // the raw credits number, with no bet or hand-count readout and no visual parity
    // with mac's dedicated panel. Sizes are scaled down from mac's literal 10pt labels
    // / 28pt values for the smaller screen, but the structure is a direct port.
    private var creditDisplay: some View {
        HStack(spacing: 24) {
            creditStat(coordinator.L(.creditsLabel), "\(viewModel.state.sessionCredits)", .yellow)
            creditStat(coordinator.L(.betLabel), "\(viewModel.state.currentBet)",
                       viewModel.state.currentBet == viewModel.state.sessionCredits ? .orange : .white)
            creditStat(coordinator.L(.handsLabel), "\(viewModel.state.handsDealt)", .white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func creditStat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
            Text(value)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(color)
        }
    }

    // MARK: Dealer

    private func dealerArea(cardW: CGFloat) -> some View {
        VStack(spacing: 6) {
            Text(dealerLabel)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.7))
            HStack(spacing: handSpacing(cardW: cardW, count: max(viewModel.state.dealerCards.count, 2), isSplit: false)) {
                if viewModel.state.dealerCards.isEmpty || showCardBackPlaceholders {
                    ForEach(0..<2, id: \.self) { i in
                        HoneycombSimpleCardBack()
                            .frame(width: cardW, height: cardW * CardDimensions.aspectRatio)
                            .overlay(
                                RoundedRectangle(cornerRadius: cardW * 0.07)
                                    .stroke(Color.black.opacity(0.85), lineWidth: 0.75)
                            )
                            .zIndex(Double(i))
                    }
                } else {
                    ForEach(Array(viewModel.state.dealerCards.enumerated()), id: \.offset) { i, card in
                        TouchCardView(card: card, width: cardW)
                            .opacity(cardsVisible ? 1 : 0)
                            .animation(.easeIn(duration: 0.15).delay(Double(i) * 0.08), value: cardsVisible)
                            .zIndex(Double(i))
                    }
                }
            }
        }
    }

    private var dealerLabel: String {
        guard !viewModel.state.dealerCards.isEmpty else { return coordinator.L(.dealerLabel) }
        let value = viewModel.state.phase == .playing ? viewModel.state.dealerVisibleValue : viewModel.state.dealerValue
        return "\(coordinator.L(.dealerLabel))  \(value)"
    }

    // MARK: Player hand(s)

    private func playerHandsArea(cardW: CGFloat) -> some View {
        VStack(spacing: 18) {
            if viewModel.state.playerHands.isEmpty || showCardBackPlaceholders {
                // Pre-deal placeholder — matches dealerArea's own empty-state branch
                // (two face-down HoneycombSimpleCardBack placeholders), which the player
                // side was missing entirely, leaving it blank instead of showing a
                // matching pair of face-down cards before the first deal. Also reused
                // as the post-result reset state via showCardBackPlaceholders.
                VStack(spacing: 6) {
                    Text(coordinator.L(.touchYouLabel))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    HStack(spacing: handSpacing(cardW: cardW, count: 2, isSplit: false)) {
                        ForEach(0..<2, id: \.self) { i in
                            HoneycombSimpleCardBack()
                                .frame(width: cardW, height: cardW * CardDimensions.aspectRatio)
                                .overlay(
                                    RoundedRectangle(cornerRadius: cardW * 0.07)
                                        .stroke(Color.black.opacity(0.85), lineWidth: 0.75)
                                )
                                .zIndex(Double(i))
                        }
                    }
                }
            } else {
                // showCardBackPlaceholders can be true while playerHands still holds
                // the just-finished hand (it only clears on the next deal) — without
                // this else, the placeholder above and this ForEach rendered at the
                // same time during the post-result reset pause, showing the old played
                // cards stacked directly under the fresh face-down placeholders instead
                // of them disappearing.
                ForEach(Array(viewModel.state.playerHands.enumerated()), id: \.offset) { i, hand in
                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            if viewModel.state.playerHands.count > 1 {
                                Circle()
                                    .fill(i == viewModel.state.activeHandIndex && viewModel.state.phase == .playing
                                          ? Color.yellow : Color.white.opacity(0.3))
                                    .frame(width: 8, height: 8)
                            }
                            // No inline per-hand result tag here — matches mac's playerArea
                            // (BlackjackView.swift), which only ever shows the hand value,
                            // never a WIN/LOSS/PUSH label beside it; the result is
                            // communicated once, by the big resultBanner below.
                            Text("\(handLabel(hand, index: i))  \(hand.value)\(hand.isBust ? coordinator.L(.touchBustSuffix) : "")")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(hand.isBust ? .red : .white)
                        }
                        HStack(spacing: handSpacing(cardW: cardW, count: hand.cards.count, isSplit: viewModel.state.playerHands.count > 1)) {
                            ForEach(Array(hand.cards.enumerated()), id: \.offset) { i, card in
                                TouchCardView(card: card, width: cardW)
                                    .opacity(cardsVisible ? 1 : 0)
                                    .animation(.easeIn(duration: 0.15).delay(Double(i) * 0.08), value: cardsVisible)
                                    .zIndex(Double(i))
                            }
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        (i == viewModel.state.activeHandIndex && viewModel.state.phase == .playing && viewModel.state.playerHands.count > 1)
                            ? Color.black.opacity(0.25) : .clear,
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                }
            }
        }
    }

    private func handLabel(_ hand: BlackjackHand, index: Int) -> String {
        viewModel.state.playerHands.count > 1 ? coordinator.L(.touchHandLabelFmt, index + 1) : coordinator.L(.touchYouLabel)
    }

    private var resultBanner: some View {
        Group {
            if showResultBanner, viewModel.state.phase == .result, viewModel.state.resultOutcome != .none {
                let (headline, subline) = localizedBlackjackResult(viewModel.state, language: coordinator.language)
                let isWin = viewModel.state.isWinRound
                VStack(spacing: 2) {
                    // Matches mac (BlackjackView.swift:554-556) — the headline is
                    // unconditionally yellow for every outcome, win or loss; only the
                    // wording and the win-only glow/pulse below differ. Was
                    // conditionally white for a loss, which doesn't match mac at all.
                    Text(headline)
                        .font(.title3.weight(.black))
                        .foregroundStyle(.yellow)

                    if !viewModel.isFreePlay {
                        Text(subline)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                // Matches mac's resultBanner background/shadow (BlackjackView.swift:
                // 585-591) — was missing here, so the banner text floated directly on
                // the felt with nothing to separate it from the cards behind it.
                .background(Color.black.opacity(0.75))
                .cornerRadius(12)
                .shadow(color: isWin ? Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.5) : .clear, radius: 16)
                // Matches mac's bannerWinFlash — a slow repeating pulse for the
                // duration the win banner is visible, not a one-shot flash.
                .scaleEffect(isWin && bannerWinFlash ? 1.06 : 1.0)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: bannerWinFlash)
                .onAppear { if isWin { bannerWinFlash = true } }
                .onDisappear { bannerWinFlash = false }
            } else {
                VStack(spacing: 2) {
                    Text(" ").font(.title3.weight(.black))
                    if !viewModel.isFreePlay {
                        Text(" ").font(.subheadline)
                    }
                }
            }
        }
        // Bumped from 28/48 — the new boxed background/padding above makes the shown
        // banner taller than the old bare-text reservation, which would otherwise
        // compress/clip it against this fixed frame.
        .frame(height: viewModel.isFreePlay ? 60 : 84)
    }

    // MARK: Controls

    private var controls: some View {
        Group {
            switch viewModel.state.phase {
            case .betting:
                bettingControls
            case .playing:
                actionControls
            case .dealerTurn:
                HStack {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                }
            case .result:
                if viewModel.canRebuy {
                    rebuyControl
                } else {
                    bettingControls
                }
            }
        }
    }

    // Matches mac's actionButtons betting/result case (BlackjackView.swift:600-626)
    // exactly: Clear (hidden in free play, mac's own gate) + Deal in one row, then a
    // row of five colored chip buttons (1/5/10/25/2x) — was a dark capsule reset+bet-
    // text+double control plus only 3 plain-bordered chips (missing the 10 chip
    // entirely, no color coding, no relation to the rest of the button system). The
    // bet amount itself isn't duplicated here, same as mac — it's already shown in
    // creditDisplay's BET stat above.
    private var bettingControls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                if !viewModel.isFreePlay {
                    casinoButton(coordinator.L(.btnClearBet), systemImage: "xmark", color: Color(white: 0.25)) {
                        viewModel.clearBet()
                    }
                }
                casinoButton(coordinator.L(.dealButton), systemImage: "play.fill", color: .yellow,
                             disabled: !canAffordBet || viewModel.state.currentBet == 0) {
                    viewModel.deal()
                    actionHaptic.impactOccurred()
                }
            }

            if !viewModel.isFreePlay {
                HStack(spacing: 10) {
                    casinoButton(coordinator.L(.chip1), color: .white, textColor: .black) { viewModel.addToBet(1) }
                    casinoButton(coordinator.L(.chip5), color: .red.opacity(0.85)) { viewModel.addToBet(5) }
                    casinoButton(coordinator.L(.chip10), color: .blue.opacity(0.75)) { viewModel.addToBet(10) }
                    casinoButton(coordinator.L(.chip25), color: .green.opacity(0.75)) { viewModel.addToBet(25) }
                    casinoButton(coordinator.L(.chip2x), color: .orange.opacity(0.85)) { viewModel.doubleBet() }
                }
            }
        }
    }

    private var actionControls: some View {
        HStack(spacing: 10) {
            casinoButton(coordinator.L(.touchActionHit), systemImage: "plus.circle", color: .green.opacity(0.85)) {
                viewModel.hit()
                actionHaptic.impactOccurred()
            }
            casinoButton(coordinator.L(.touchActionStand), systemImage: "hand.raised", color: .red.opacity(0.75)) {
                viewModel.stand()
                actionHaptic.impactOccurred()
            }
            if viewModel.canDouble {
                casinoButton(coordinator.L(.touchActionDouble), systemImage: "multiply.circle", color: .blue.opacity(0.75)) {
                    viewModel.doubleDown()
                    actionHaptic.impactOccurred()
                }
            }
            if viewModel.canSplit {
                casinoButton(coordinator.L(.touchActionSplit), systemImage: "arrow.triangle.branch", color: .purple.opacity(0.75)) {
                    viewModel.split()
                    actionHaptic.impactOccurred()
                }
            }
        }
    }

    private var rebuyControl: some View {
        HStack {
            Spacer()
            casinoButton(coordinator.L(.rebuyButton), systemImage: "arrow.clockwise.circle", color: .red.opacity(0.8)) {
                viewModel.rebuy()
            }
            Spacer()
        }
    }
}

// MARK: - Settings section shown inside the slide-down menu

struct BlackjackSettingsSection: View {
    @Bindable var viewModel: BlackjackViewModel
    let canOpenOptions: Bool
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                Stepper(coordinator.L(.startingCreditsFmt, viewModel.options.startingCredits),
                        value: $viewModel.options.startingCredits, in: 10...10000, step: 10)
                Toggle(coordinator.L(.soundShort), isOn: $viewModel.options.isSoundEnabled)
                // No startNewGame() call here, unlike mac's equivalent — this Toggle is
                // disabled during gameplay (.disabledDuringGameplay below), so it can only
                // ever fire between hands, when there's no in-progress hand to interrupt.
                // isFreePlay reads options.noStressMode live, so the change takes effect
                // on the next deal on its own; calling startNewGame() here only served to
                // unconditionally wipe the win streak on a benign settings change.
                Toggle(coordinator.L(.noStressMode), isOn: $viewModel.options.noStressMode)
                Toggle(coordinator.L(.honeyMode), isOn: $viewModel.options.honeyMode)
                Toggle(coordinator.L(.manuallyDismissBanners), isOn: $viewModel.options.manuallyDismissBanners)
            }
            .disabledDuringGameplay(!canOpenOptions)

            if !canOpenOptions {
                Text(coordinator.L(.touchSettingsUnlockBetweenHands))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Stats sheet

struct BlackjackStatsSheet: View {
    @Bindable var viewModel: BlackjackViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        NavigationStack {
            List {
                row(coordinator.L(.handsPlayed), "\(viewModel.statistics.handsPlayed)")
                row(coordinator.L(.handsWon), "\(viewModel.statistics.handsWon)")
                row(coordinator.L(.statHandsLost), "\(viewModel.statistics.handsLost)")
                row(coordinator.L(.statPushes), "\(viewModel.statistics.pushes)")
                row(coordinator.L(.statBlackjacks), "\(viewModel.statistics.blackjacks)")
                row(coordinator.L(.winRate), String(format: "%.1f%%", viewModel.statistics.winRate * 100))
                row(coordinator.L(.statCurStreakShort), "\(viewModel.statistics.currentStreak)")
                row(coordinator.L(.statBestStreak), "\(viewModel.statistics.longestStreak)")
                row(coordinator.L(.totalWagered), "\(viewModel.statistics.totalWagered)")
                row(coordinator.L(.totalPaid), "\(viewModel.statistics.totalPaidOut)")
                row(coordinator.L(.biggestPay), "\(viewModel.statistics.biggestPayout)")
                row(coordinator.L(.rtpStat), String(format: "%.1f%%", viewModel.statistics.returnToPlayer * 100))
                row(coordinator.L(.rebuysStat), "\(viewModel.statistics.rebuyCount)")
                row(coordinator.L(.touchHandsDealtStat), "\(viewModel.state.handsDealt)")
                row(coordinator.L(.touchSessionCreditsStat), "\(viewModel.state.sessionCredits)")
            }
            .navigationTitle(coordinator.L(.blackjackStatistics))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(coordinator.L(.done)) { dismiss() }
                }
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}
