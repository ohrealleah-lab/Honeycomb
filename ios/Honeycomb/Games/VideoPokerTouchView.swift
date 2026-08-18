import SwiftUI
import UIKit

/// Touch-first Video Poker for iPhone/iPad, driven by the shared VideoPokerViewModel.
/// Button-driven (no drags): tap cards to hold during the holding phase, Deal/Draw
/// button advances the phase machine, bet controls sit below. Triple Play rendering is
/// not built yet — the settings expose Single Play options only for now.
struct VideoPokerTouchView: View {
    @Bindable var viewModel: VideoPokerViewModel
    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator

    @State private var isMenuOpen = false
    @State private var showingOptions = false
    @State private var showingThemes = false
    @State private var showingStats = false

    // Post-result pacing/reset choreography — ported from mac's VideoPokerView
    // (.onChange(of: viewModel.state.phase) + chained DispatchWorkItem/asyncAfter),
    // which the shared VideoPokerViewModel doesn't do on its own: state.phase moves to
    // .result and just sits there. Without this, iOS had no pause/reset at all — the
    // result banner appeared instantly and stale revealed cards just stayed on screen
    // until the player manually tapped Deal again.
    @State private var winFlash = false
    @State private var cardVisible: [Bool] = Array(repeating: false, count: 5)
    @State private var cardRotation: [Double] = Array(repeating: 0, count: 5)
    @State private var showParticles = false
    @State private var showResultBanner = false
    @State private var cardsVisible = true
    @State private var showCardBackPlaceholders = true
    @State private var showIdlePrompt = false
    @State private var resultBannerShowTask: DispatchWorkItem? = nil
    @State private var resultWinFlashTask: DispatchWorkItem? = nil
    @State private var resultAnimationTask: DispatchWorkItem? = nil
    @State private var resultHideTask: DispatchWorkItem? = nil
    @State private var idlePromptTask: DispatchWorkItem? = nil

    private let holdHaptic = UIImpactFeedbackGenerator(style: .light)
    private let dealHaptic = UIImpactFeedbackGenerator(style: .medium)

    private var canAffordBet: Bool {
        viewModel.isFreePlay || viewModel.state.sessionCredits >= viewModel.totalBet
    }

    var body: some View {
        GeometryReader { geo in
            // Matches mac's hand-area sizing philosophy: cards are their own generous
            // size (mac: 77x122 scaled 1.4x ≈ 108x171) rather than shrinking to whatever
            // fits 5-across at a fixed positive gap. The old 120pt width cap was hit on
            // every iPad-sized screen regardless of how much room was actually available,
            // leaving cards small with a lot of dead space below/beside them — raised
            // considerably so cards keep growing on bigger screens. Overlap is now the
            // *default* look (a fanned hand), not just a narrow-screen fallback: an
            // 18%-of-card-width negative gap on every screen, growing more negative only
            // if that's still not enough room to fit all 5.
            let cardW = min(geo.size.width * 0.32, 190)
            let overlapSpacing = -cardW * 0.18
            let overlappedRowWidth = cardW * 5 + overlapSpacing * 4
            let availableRowWidth = geo.size.width - 24
            let handSpacing: CGFloat = overlappedRowWidth > availableRowWidth
                ? (availableRowWidth - cardW * 5) / 4
                : overlapSpacing
            let isLandscape = geo.size.width > geo.size.height

            ZStack {
                IOSBackgroundLayer()

                // ScrollView fallback rather than a computed shrink factor: unlike the
                // tableau games, most of this view's height is fixed-size text (the pay
                // table) that doesn't have a natural "shrink" — landscape's shorter
                // height can still exceed it, so let it scroll instead of clipping the
                // Deal button off the bottom. Portrait already fits without scrolling.
                ScrollView {
                    VStack(spacing: 12) {
                        topBar
                            .padding(.horizontal, 12)
                            .frame(height: 44)

                        // Landscape auto-hides the pay table, same idea as mac's existing
                        // hideBetBoard/noStressMode/Triple-Play conditions — landscape's
                        // shorter height has the least room to spare, so it always wins
                        // regardless of the manual setting.
                        if !isLandscape && !viewModel.options.hideBetBoard && !viewModel.options.noStressMode {
                            payTableView
                                .padding(.horizontal, 16)
                        }

                        Spacer(minLength: 4)

                        // Between the pay table and the cards, not above the pay table —
                        // sits in the same "breathing room" gap as resultBanner rather
                        // than crowding the top bar.
                        if !viewModel.isFreePlay {
                            creditDisplay
                        }

                        resultBanner

                        handRow(cardW: cardW, spacing: handSpacing)
                            .padding(.horizontal, 12)

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
        .sheet(isPresented: $showingStats) { VideoPokerStatsSheet(viewModel: viewModel) }
        .sheet(isPresented: $showingThemes) { ThemesFullScreenView(coordinator: coordinator) }
        .sheet(isPresented: $showingOptions) {
            OptionsFullScreenView(coordinator: coordinator, onShowStats: { showingStats = true }) {
                VideoPokerSettingsSection(viewModel: viewModel,
                                          isMidHand: viewModel.state.phase == .holding)
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
            if newPhase == .result {
                // Cancel any leftover tasks just in case.
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
                resultBannerShowTask?.cancel(); resultBannerShowTask = nil
                resultWinFlashTask?.cancel(); resultWinFlashTask = nil
                resultAnimationTask?.cancel(); resultAnimationTask = nil
                resultHideTask?.cancel(); resultHideTask = nil
                idlePromptTask?.cancel(); idlePromptTask = nil

                withAnimation(.easeInOut(duration: 0.3)) { showIdlePrompt = false }
                showResultBanner = false
                showCardBackPlaceholders = false
                cardsVisible = true
                animateDeal()
            }
            if newPhase == .deal {
                resultBannerShowTask?.cancel(); resultBannerShowTask = nil
                resultWinFlashTask?.cancel(); resultWinFlashTask = nil
                resultAnimationTask?.cancel(); resultAnimationTask = nil
                resultHideTask?.cancel(); resultHideTask = nil
                idlePromptTask?.cancel(); idlePromptTask = nil

                showCardBackPlaceholders = true
                cardsVisible = true
                withAnimation(.easeInOut(duration: 0.6)) { showIdlePrompt = true }
            }
        }
    }

    // Mirrors mac's animateDeal(): each of the 5 cards reveals staggered 0.06s apart,
    // settling from a small starting rotation rather than all popping in at once.
    private func animateDeal() {
        let startAngles: [Double] = [-8, -5, 0, 5, 8]
        cardVisible = Array(repeating: false, count: 5)
        cardRotation = startAngles
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.06) {
                cardVisible[i] = true
                cardRotation[i] = 0
            }
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            menuBarButtons(isMenuOpen: $isMenuOpen, showingOptions: $showingOptions, showingThemes: $showingThemes, coordinator: coordinator)

            Spacer()

            Text(localizedVariantName(viewModel.options.variant, language: coordinator.language))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
        }
    }

    // MARK: Credit display

    // Matches mac's VideoPokerView creditDisplay (CREDITS/BET/HANDS panel) — iOS
    // previously only had a small credit-card capsule tucked into the top bar showing
    // the raw credits number, with no bet or hand-count readout at all and no visual
    // parity with mac's dedicated panel. Sizes are scaled down from mac's literal
    // 10pt labels / 28pt values for the smaller screen, but the structure (three
    // stat columns, yellow credits, dark rounded card) is a direct port.
    private var creditDisplay: some View {
        HStack(spacing: 24) {
            creditStat(coordinator.L(.creditsLabel), "\(viewModel.state.sessionCredits)", .yellow)
            creditStat(coordinator.L(.betLabel), "\(viewModel.state.currentBet)",
                       viewModel.state.currentBet == 5 ? .orange : .white)
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

    // MARK: Pay table

    private var payTableView: some View {
        VStack(spacing: 2) {
            ForEach(Array(viewModel.payTable.enumerated()), id: \.offset) { _, entry in
                let isHit = viewModel.state.phase == .result
                    && viewModel.state.lastPayout > 0
                    && viewModel.state.lastHandName == entry.handName
                HStack {
                    Text(localizedHandName(entry.handName, language: coordinator.language))
                    Spacer()
                    Text("\(entry.payout(bet: max(1, viewModel.state.currentBet)))")
                        .monospacedDigit()
                }
                .font(.caption2.weight(isHit ? .black : .medium))
                .foregroundStyle(isHit ? .yellow : .white.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 1)
                .background(isHit ? Color.yellow.opacity(winFlash ? 0.9 : 0.4) : .clear)
                .animation(isHit ? .easeInOut(duration: 0.3).repeatForever(autoreverses: true) : .default, value: winFlash)
            }
        }
        .padding(.vertical, 6)
        .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Hand

    private func handRow(cardW: CGFloat, spacing: CGFloat) -> some View {
        HStack(alignment: .top, spacing: spacing) {
            // showCardBackPlaceholders also gates this branch — it flips true during
            // the post-result reset tail so the table visibly returns to face-down
            // cards instead of just sitting on the stale revealed hand.
            if viewModel.state.hand.isEmpty || showCardBackPlaceholders {
                ForEach(0..<5, id: \.self) { i in
                    HoneycombSimpleCardBack()
                        .frame(width: cardW, height: cardW * CardDimensions.aspectRatio)
                        .overlay(
                            RoundedRectangle(cornerRadius: cardW * 0.07)
                                .stroke(Color.black.opacity(0.85), lineWidth: 0.75)
                        )
                        // Later HStack children draw on top; when spacing goes negative
                        // (overlap) each card's left edge — where the corner rank/suit
                        // index lives — stays uncovered by its left neighbor, same as a
                        // fanned hand of real cards.
                        .zIndex(Double(i))
                }
            } else {
                ForEach(Array(viewModel.state.hand.enumerated()), id: \.element.id) { i, card in
                    // Mirrors mac's animateDeal() stagger: each card lifts/fades in
                    // 0.06s after the last, settling from a small starting rotation.
                    let isHeld = viewModel.state.heldIndices.contains(i)
                    let lifting = isHeld && viewModel.state.phase == .holding
                    let visible = i < cardVisible.count && cardVisible[i]
                    let wobble = i < cardRotation.count ? cardRotation[i] : 0.0
                    VStack(spacing: 4) {
                        Text(coordinator.L(.heldLabel))
                            .font(.caption2.weight(.black))
                            .foregroundStyle(.yellow)
                            .opacity(isHeld ? 1 : 0)
                        TouchCardView(card: card, width: cardW)
                            .overlay(
                                RoundedRectangle(cornerRadius: cardW * 0.07)
                                    .stroke(Color.yellow, lineWidth: isHeld ? 3 : 0)
                            )
                            .onTapGesture {
                                guard viewModel.state.phase == .holding else { return }
                                viewModel.toggleHold(at: i)
                                holdHaptic.impactOccurred()
                            }
                    }
                    .rotationEffect(.degrees(wobble))
                    .offset(y: lifting ? -18 : (visible ? 0 : 40))
                    .opacity(visible ? 1 : 0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.5).delay(Double(i) * 0.06), value: visible)
                    .animation(.spring(response: 0.2, dampingFraction: 0.4).delay(Double(i) * 0.06), value: wobble)
                    .animation(.easeInOut(duration: 0.15), value: lifting)
                    .zIndex(Double(i))
                }
            }
        }
        .opacity(cardsVisible ? 1 : 0)
        .overlay {
            WinParticleView(active: showParticles)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var resultBanner: some View {
        Group {
            if showResultBanner, viewModel.state.phase == .result, !viewModel.state.lastHandName.isEmpty {
                let localizedName = localizedHandName(viewModel.state.lastHandName, language: coordinator.language)
                Text(viewModel.state.lastPayout > 0
                     ? coordinator.L(.payoutResultFmt, localizedName, viewModel.state.lastPayout)
                     : localizedName)
                    .font(.title3.weight(.black))
                    .foregroundStyle(viewModel.state.lastPayout > 0 ? .yellow : .white.opacity(0.8))
                    .scaleEffect(viewModel.state.lastPayout > 0 && winFlash ? 1.1 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.45), value: winFlash)
            } else if viewModel.state.phase == .holding {
                Text(coordinator.L(.tapHoldDrawHint))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                Text(" ").font(.title3.weight(.black))
            }
        }
        .frame(height: 28)
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 12) {
            if viewModel.state.phase != .holding {
                HStack(spacing: 0) {
                    Button {
                        viewModel.decreaseBet()
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                    Text("\(coordinator.L(.betLabel)) \(viewModel.state.currentBet)")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .frame(minWidth: 60)
                    Button {
                        viewModel.increaseBet()
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                }
                .foregroundStyle(.white)
                .background(.black.opacity(0.35), in: Capsule())

                casinoButton(coordinator.L(.touchBetMaxButton), systemImage: "dollarsign.circle", color: .orange.opacity(0.85)) {
                    viewModel.maxBet()
                }
            }

            Spacer()

            if !canAffordBet && viewModel.state.phase != .holding {
                casinoButton(coordinator.L(.rebuyButton), systemImage: "arrow.clockwise.circle", color: .red.opacity(0.8)) {
                    viewModel.rebuy()
                }
            } else if viewModel.state.phase == .holding {
                casinoButton(coordinator.L(.btnDraw), systemImage: "arrow.triangle.2.circlepath", color: .green.opacity(0.85)) {
                    viewModel.draw()
                    dealHaptic.impactOccurred()
                }
            } else {
                casinoButton(coordinator.L(.dealButton), systemImage: "play.fill", color: .yellow, textColor: .black,
                             disabled: !canAffordBet) {
                    viewModel.deal()
                    dealHaptic.impactOccurred()
                }
            }
        }
    }
}

// MARK: - Settings section shown inside the slide-down menu

struct VideoPokerSettingsSection: View {
    @Bindable var viewModel: VideoPokerViewModel
    let isMidHand: Bool
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(coordinator.L(.settingsHeaderVideopoker))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Group {
                Picker(coordinator.L(.pickerVariantLabel), selection: $viewModel.options.variant) {
                    ForEach(VideoPokerVariant.allCases, id: \.self) { v in
                        Text(localizedVariantName(v, language: coordinator.language)).tag(v)
                    }
                }
                .pickerStyle(.menu)

                // Play Mode (Single/Triple) intentionally left out — Triple Play's
                // three-hand layout isn't built on iOS yet, so exposing the toggle
                // would let the player select a mode this view can't render.

                Stepper(coordinator.L(.startingCreditsFmt, viewModel.options.startingCredits),
                        value: $viewModel.options.startingCredits, in: 100...10000, step: 100)

                Picker(coordinator.L(.pickerDefaultBetLabel), selection: $viewModel.options.betPerHand) {
                    ForEach(1...5, id: \.self) { bet in
                        Text("\(bet)").tag(bet)
                    }
                }
                .pickerStyle(.menu)

                Toggle(coordinator.L(.soundShort), isOn: $viewModel.options.isSoundEnabled)
                Toggle(coordinator.L(.noStressMode), isOn: $viewModel.options.noStressMode)
                    .onChange(of: viewModel.options.noStressMode) { _, _ in viewModel.startNewGame() }
                Toggle(coordinator.L(.hideBetBoard), isOn: $viewModel.options.hideBetBoard)
            }
            .disabledDuringGameplay(isMidHand)

            if isMidHand {
                Text(coordinator.L(.touchSettingsUnlockHandEnds))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Stats sheet

struct VideoPokerStatsSheet: View {
    @Bindable var viewModel: VideoPokerViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        NavigationStack {
            List {
                row(coordinator.L(.handsPlayed), "\(viewModel.statistics.handsPlayed)")
                row(coordinator.L(.handsWon), "\(viewModel.statistics.handsWon)")
                row(coordinator.L(.winRate), String(format: "%.1f%%", viewModel.statistics.winRate * 100))
                row(coordinator.L(.statCurStreakShort), "\(viewModel.statistics.currentStreak)")
                row(coordinator.L(.statBestStreak), "\(viewModel.statistics.longestStreak)")
                row(coordinator.L(.biggestPay), "\(viewModel.statistics.biggestPayout)")
                row(coordinator.L(.totalWagered), "\(viewModel.statistics.totalWagered)")
                row(coordinator.L(.totalPaid), "\(viewModel.statistics.totalPaidOut)")
                row(coordinator.L(.rtpStat), String(format: "%.1f%%", viewModel.statistics.returnToPlayer * 100))
                row(coordinator.L(.royalFlushes), "\(viewModel.statistics.royalFlushCount)")
                row(coordinator.L(.rebuysStat), "\(viewModel.statistics.rebuyCount)")
                row(coordinator.L(.touchHandsDealtStat), "\(viewModel.state.handsDealt)")
                row(coordinator.L(.touchSessionCreditsStat), "\(viewModel.state.sessionCredits)")
            }
            .navigationTitle(coordinator.L(.videoPokerStatistics))
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
