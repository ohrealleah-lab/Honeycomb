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

    private let holdHaptic = UIImpactFeedbackGenerator(style: .light)
    private let dealHaptic = UIImpactFeedbackGenerator(style: .medium)

    private var canAffordBet: Bool {
        viewModel.isFreePlay || viewModel.state.sessionCredits >= viewModel.totalBet
    }

    var body: some View {
        GeometryReader { geo in
            let cardW = min((geo.size.width - 24 - 4 * 8) / 5, 110)
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

                        resultBanner

                        handRow(cardW: cardW)
                            .padding(.horizontal, 12)

                        Spacer(minLength: 4)

                        controls
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    }
                    .frame(minHeight: geo.size.height)
                }

                SlideDownMenu(isOpen: $isMenuOpen, coordinator: coordinator)
            }
        }
        .environment(\.activeCardBackTheme, coordinator.cardBackTheme)
        .environment(\.activeCustomCardColors, coordinator.customCardColors)
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

            Text(localizedVariantName(viewModel.options.variant, language: coordinator.language))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
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
                .background(isHit ? Color.black.opacity(0.4) : .clear)
            }
        }
        .padding(.vertical, 6)
        .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Hand

    private func handRow(cardW: CGFloat) -> some View {
        HStack(spacing: 8) {
            if viewModel.state.hand.isEmpty {
                ForEach(0..<5, id: \.self) { _ in
                    HoneycombSimpleCardBack()
                        .frame(width: cardW, height: cardW * CardDimensions.aspectRatio)
                }
            } else {
                ForEach(Array(viewModel.state.hand.enumerated()), id: \.element.id) { i, card in
                    VStack(spacing: 4) {
                        Text(coordinator.L(.heldLabel))
                            .font(.caption2.weight(.black))
                            .foregroundStyle(.yellow)
                            .opacity(viewModel.state.heldIndices.contains(i) ? 1 : 0)
                        TouchCardView(card: card, width: cardW)
                            .overlay(
                                RoundedRectangle(cornerRadius: cardW * 0.07)
                                    .stroke(Color.yellow,
                                            lineWidth: viewModel.state.heldIndices.contains(i) ? 3 : 0)
                            )
                            .onTapGesture {
                                guard viewModel.state.phase == .holding else { return }
                                viewModel.toggleHold(at: i)
                                holdHaptic.impactOccurred()
                            }
                    }
                }
            }
        }
    }

    private var resultBanner: some View {
        Group {
            if viewModel.state.phase == .result, !viewModel.state.lastHandName.isEmpty {
                let localizedName = localizedHandName(viewModel.state.lastHandName, language: coordinator.language)
                Text(viewModel.state.lastPayout > 0
                     ? coordinator.L(.payoutResultFmt, localizedName, viewModel.state.lastPayout)
                     : localizedName)
                    .font(.title3.weight(.black))
                    .foregroundStyle(viewModel.state.lastPayout > 0 ? .yellow : .white.opacity(0.8))
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
                HStack {
                    Text(coordinator.L(.touchHandsDealtStat))
                    Spacer()
                    Text("\(viewModel.state.handsDealt)").foregroundStyle(.secondary)
                }
                HStack {
                    Text(coordinator.L(.royalFlushes))
                    Spacer()
                    Text("\(viewModel.statistics.royalFlushCount)").foregroundStyle(.secondary)
                }
                HStack {
                    Text(coordinator.L(.touchSessionCreditsStat))
                    Spacer()
                    Text("\(viewModel.state.sessionCredits)").foregroundStyle(.secondary)
                }
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
}
