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

    private let actionHaptic = UIImpactFeedbackGenerator(style: .medium)

    private var canAffordBet: Bool {
        viewModel.isFreePlay || viewModel.state.sessionCredits >= max(viewModel.state.currentBet, 1)
    }

    var body: some View {
        GeometryReader { geo in
            let cardW = min((geo.size.width - 32) / 6, 90)

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

                        dealerArea(cardW: cardW)

                        resultBanner

                        Spacer(minLength: 4)

                        playerHandsArea(cardW: cardW)

                        Spacer(minLength: 4)

                        controls
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    }
                    .frame(minHeight: geo.size.height)
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
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            menuBarButtons(isMenuOpen: $isMenuOpen, showingOptions: $showingOptions, showingThemes: $showingThemes, coordinator: coordinator)

            Spacer()

            HStack(spacing: 8) {
                Image(systemName: "creditcard")
                Text(viewModel.isFreePlay ? coordinator.L(.freePlayLabel) : "\(viewModel.state.sessionCredits)")
            }
            .font(.subheadline.weight(.bold).monospacedDigit())
            .foregroundStyle(.yellow)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.black.opacity(0.35), in: Capsule())

            Spacer()

            Text(coordinator.L(.touchBlackjackTitle))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    // MARK: Dealer

    private func dealerArea(cardW: CGFloat) -> some View {
        VStack(spacing: 6) {
            Text(dealerLabel)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.7))
            HStack(spacing: 6) {
                if viewModel.state.dealerCards.isEmpty {
                    ForEach(0..<2, id: \.self) { _ in
                        HoneycombSimpleCardBack().frame(width: cardW, height: cardW * CardDimensions.aspectRatio)
                    }
                } else {
                    ForEach(Array(viewModel.state.dealerCards.enumerated()), id: \.offset) { _, card in
                        TouchCardView(card: card, width: cardW)
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
            ForEach(Array(viewModel.state.playerHands.enumerated()), id: \.offset) { i, hand in
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        if viewModel.state.playerHands.count > 1 {
                            Circle()
                                .fill(i == viewModel.state.activeHandIndex && viewModel.state.phase == .playing
                                      ? Color.yellow : Color.white.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                        Text("\(handLabel(hand, index: i))  \(hand.value)\(hand.isBust ? coordinator.L(.touchBustSuffix) : "")")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(hand.isBust ? .red : .white)
                        if let result = hand.result {
                            Text(resultText(result))
                                .font(.caption.weight(.black))
                                .foregroundStyle(resultColor(result))
                        }
                    }
                    HStack(spacing: 6) {
                        ForEach(Array(hand.cards.enumerated()), id: \.offset) { _, card in
                            TouchCardView(card: card, width: cardW)
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

    private func handLabel(_ hand: BlackjackHand, index: Int) -> String {
        viewModel.state.playerHands.count > 1 ? coordinator.L(.touchHandLabelFmt, index + 1) : coordinator.L(.touchYouLabel)
    }

    private func resultText(_ result: BlackjackHandResult) -> String {
        switch result {
        case .win: return coordinator.L(.touchResultWin)
        case .loss: return coordinator.L(.touchResultLoss)
        case .push: return coordinator.L(.touchResultPush)
        case .blackjack: return coordinator.L(.touchResultBlackjack)
        case .bust: return coordinator.L(.touchResultBust)
        }
    }

    private func resultColor(_ result: BlackjackHandResult) -> Color {
        switch result {
        case .win, .blackjack: return .yellow
        case .push: return .white
        case .loss, .bust: return .red.opacity(0.9)
        }
    }

    private var resultBanner: some View {
        Group {
            if viewModel.state.phase == .result, viewModel.state.resultOutcome != .none {
                let (headline, subline) = localizedBlackjackResult(viewModel.state, language: coordinator.language)
                VStack(spacing: 2) {
                    Text(headline)
                        .font(.title3.weight(.black))
                        .foregroundStyle(viewModel.state.isWinRound ? .yellow : .white)

                    if !viewModel.isFreePlay {
                        Text(subline)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            } else {
                VStack(spacing: 2) {
                    Text(" ").font(.title3.weight(.black))
                    if !viewModel.isFreePlay {
                        Text(" ").font(.subheadline)
                    }
                }
            }
        }
        .frame(height: viewModel.isFreePlay ? 28 : 48)
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

    private var bettingControls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 0) {
                    Button {
                        viewModel.clearBet()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    Text("\(coordinator.L(.betLabel)) \(viewModel.state.currentBet)")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .frame(minWidth: 60)
                    Button {
                        viewModel.doubleBet()
                    } label: {
                        Image(systemName: "multiply")
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                }
                .foregroundStyle(.white)
                .background(.black.opacity(0.35), in: Capsule())

                Spacer()

                ForEach([1, 5, 25], id: \.self) { chip in
                    Button {
                        viewModel.addToBet(chip)
                    } label: {
                        Text("+\(chip)")
                            .font(.caption.weight(.bold))
                            .frame(width: 42, height: 30)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                }
            }

            casinoButton(coordinator.L(.dealButton), systemImage: "play.fill", color: .yellow,
                         disabled: !canAffordBet || viewModel.state.currentBet == 0) {
                viewModel.deal()
                actionHaptic.impactOccurred()
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
            Text(coordinator.L(.touchBlackjackBanner))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

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
