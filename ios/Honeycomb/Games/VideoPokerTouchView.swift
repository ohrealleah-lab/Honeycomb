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
    // Portrait only — the real betTrio row's live-measured height, reused as an
    // invisible placeholder during .holding (see portraitBetTrioSlot) so the controls
    // bar's total height stays constant across every phase instead of collapsing from
    // 2 rows to 1 and back, which shifted the pay table/cards up and down with it.
    @State private var betTrioHeight: CGFloat = 60
    // Height of the fixed bottom controls bar (see body) — reserved as bottom padding
    // on the scrollable content so it never ends up hidden underneath it.
    @State private var controlsHeight: CGFloat = 90

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
            let cardW = min(geo.size.width * 0.32, geo.size.height * 0.32, 190)
            let overlapSpacing = -cardW * 0.18
            let overlappedRowWidth = cardW * 5 + overlapSpacing * 4
            let availableRowWidth = geo.size.width - 24
            let handSpacing: CGFloat = overlappedRowWidth > availableRowWidth
                ? (availableRowWidth - cardW * 5) / 4
                : overlapSpacing
            let isLandscape = geo.size.width > geo.size.height

            // Bottom-aligned, matching Blackjack's ZStack(alignment: .bottom) — controls
            // (below) is a fixed bar pinned outside the ScrollView's flow, not part of
            // its scrolling content, so it never drifts away from the bottom of the
            // screen regardless of how much (or little) the pay table/credit display/
            // cards above it take up — that mismatch was what previously left Deal
            // stranded directly under the cards with a large empty gap below it
            // whenever No Stress Mode (or hideBetBoard) hid the pay table.
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    topBar(isLandscape: isLandscape)
                        .padding(.horizontal, 12)
                        .frame(height: 44)

                    if !isLandscape && !viewModel.isFreePlay {
                        creditDisplay
                            .padding(.top, 8)
                    }

                    // ScrollView fallback rather than a computed shrink factor: unlike
                    // the tableau games, most of this view's height is fixed-size text
                    // (the pay table) that doesn't have a natural "shrink" — landscape's
                    // shorter height can still exceed it, so let it scroll instead of
                    // clipping content. Portrait already fits without scrolling, so
                    // centering here (rather than top-aligning, like Blackjack) reads as
                    // the cards sitting in the middle of the available space instead of
                    // stuck to its top edge.
                    ScrollView {
                        VStack(spacing: 12) {
                            // Landscape auto-hides the pay table, same idea as mac's
                            // existing hideBetBoard/noStressMode/Triple-Play conditions —
                            // landscape's shorter height has the least room to spare, so
                            // it always wins regardless of the manual setting.
                            if !isLandscape && !viewModel.options.hideBetBoard && !viewModel.options.noStressMode {
                                Text(localizedVariantName(viewModel.options.variant, language: coordinator.language))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .lineLimit(1)
                                payTableView
                                    .padding(.horizontal, 16)
                            }

                            holdHint

                            handRow(cardW: cardW, spacing: handSpacing)
                                .padding(.horizontal, 12)
                        }
                        // Reserves room at the bottom for the fixed controls bar
                        // (measured live below) so the cards never end up scrolled
                        // underneath it — +16 beyond the exact measured height as a
                        // visible buffer, since exactly matching it still read as
                        // touching/overlapping (this box's own .center alignment can
                        // shift how the measured gap actually lands).
                        .padding(.bottom, controlsHeight + 16)
                        .frame(minHeight: geo.size.height - 44, alignment: .center)
                    }
                    // This ScrollView is a fallback for content that doesn't fit (a
                    // short landscape height), not a surface meant to invite scrolling —
                    // hiding the indicator wasn't enough on its own, since a plain
                    // ScrollView still lets you drag/rubber-band the content up (with
                    // nothing to snap back to but empty space) even when it already
                    // fits. .basedOnSize disables that drag entirely whenever content
                    // fits within the viewport, and only re-enables real scrolling once
                    // content actually overflows it — exactly the fallback-only
                    // behavior wanted.
                    .scrollBounceBehavior(.basedOnSize)
                    .scrollIndicators(.hidden)
                }

                // Overlay, not part of the ScrollView's flow — centers on the whole
                // screen regardless of scroll position or how tall the content above it
                // is, rather than wherever it happened to sit between the pay table and
                // the cards.
                resultOverlay

                // Listed after resultOverlay so the burst renders in front of the
                // banner, not behind it — matches Windows, where ParticleCanvas sits at
                // a higher ZIndex than the result overlay. Previously lived as a
                // same-frame .overlay on handRow itself, which put it behind
                // resultOverlay (a ZStack sibling added later) and also meant it only
                // burst from the card row's on-screen position rather than centering
                // with the (screen-centered) banner it's paired with.
                WinParticleView(active: showParticles)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)

                // Fixed bottom bar, outside the ScrollView above — same placement as
                // Blackjack's controls: pinned to the bottom of the screen at every
                // hand/pay-table size instead of trailing directly under the cards.
                controls(isLandscape: isLandscape)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    // Less than the top's 12 per request — nudges the buttons down
                    // a little closer to the screen's bottom edge.
                    .padding(.bottom, 4)
                    .frame(maxWidth: .infinity)
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { newHeight in
                        controlsHeight = newHeight
                    }
            }
        }
        .environment(\.activeCardBackTheme, coordinator.cardBackTheme)
        .environment(\.activeCustomCardColors, coordinator.customCardColors)
        .sheet(isPresented: $isMenuOpen) { GameSelectionFullScreenView(coordinator: coordinator) }
        .sheet(isPresented: $showingStats) { VideoPokerStatsSheet(viewModel: viewModel) }
        .sheet(isPresented: $showingThemes) { ThemesFullScreenView(coordinator: coordinator) }
        .sheet(isPresented: $showingOptions) {
            OptionsFullScreenView(
                coordinator: coordinator,
                onShowStats: { showingStats = true },
                onNoStressModeChange: { viewModel.startNewGame() },
                isGlobalSectionDisabled: viewModel.state.phase == .holding,
                globalSectionUnlockNote: coordinator.L(.touchSettingsUnlockHandEnds)
            ) {
                VideoPokerSettingsSection(viewModel: viewModel,
                                          isMidHand: viewModel.state.phase == .holding,
                                          coordinator: coordinator)
            }
        }
        .background(IOSBackgroundLayer(intensity: 0.6))
        .queuedFlashBanner(
            trigger: viewModel.flashBannerTrigger,
            latestMessage: viewModel.flashBanner,
            manuallyDismissBanners: viewModel.options.manuallyDismissBanners,
            onAdvanceQueue: viewModel.advanceBannerQueue
        )
        .onAppear { viewModel.checkLoadingBanner() }
        // Debug-only trigger handler — mirrors mac's VideoPokerView.swift onChange(of:
        // viewModel.debugBannerRequest). viewModel.debugSetupBannerState(kind) is shared
        // code that builds the actual hand/result state; this just resets the transient
        // result-banner UI state around it, same as the phase == .result branch below does.
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
        .onChange(of: viewModel.state.phase) { _, newPhase in
            // Re-arms the idle-nudge timer on every phase change, matching mac
            // (VideoPokerView.swift:235) — previously only armed once via
            // startNewGame(), so it could misfire near game start and then never
            // fire again for genuinely idle stretches later in the same session.
            viewModel.scheduleIdleActionCheck()
            if newPhase == .result {
                // Cancel any leftover tasks just in case.
                resultBannerShowTask?.cancel()
                resultWinFlashTask?.cancel()
                resultAnimationTask?.cancel()
                resultHideTask?.cancel()
                idlePromptTask?.cancel()

                // Matches mac: a 1.0s beat before the banner appears, so the player
                // actually gets to see the final hand before it's covered. Used to show
                // synchronously here instead — that made the banner pop up over the hand
                // with no time to read it, and meant iOS held the banner up a full
                // second longer than mac despite both fading it at the same absolute
                // moment.
                let bannerShowTask = DispatchWorkItem { showResultBanner = true }
                resultBannerShowTask = bannerShowTask
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: bannerShowTask)

                let animationTask = DispatchWorkItem {
                    let hideTask = DispatchWorkItem {
                        withAnimation(.easeOut(duration: 0.4)) { cardsVisible = false; showResultBanner = false }
                        // Checked here, not synchronously when the hand resolves — this is
                        // the moment the win/lose result banner has actually finished its
                        // display+dismiss, so the toast reads as following it (and landing
                        // alongside the Rebuy button) instead of stacking on top of it.
                        viewModel.checkOutOfCredits()
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

    private func topBar(isLandscape: Bool) -> some View {
        HStack(spacing: 10) {
            topBarIconButton(systemImage: "square.grid.2x2", accessibilityLabel: coordinator.L(.menuTabGameSelection)) {
                isMenuOpen = true
            }
            debugMenuButton(items: [("Win", .win), ("Loss", .loss)]) {
                viewModel.debugBannerRequest = $0
            }

            Spacer()

            // Options/Themes right-aligned, per request — previously bunched with Game
            // Selection on the left, which put them directly under creditDisplay's
            // overlay (see below) and read as visually cramped/overlapping.
            topBarIconButton(systemImage: "gearshape", accessibilityLabel: coordinator.L(.options)) {
                showingOptions = true
            }
            topBarIconButton(systemImage: "paintpalette", accessibilityLabel: coordinator.L(.themesPanelTitle)) {
                showingThemes = true
            }
        }
        // Landscape only: overlay on the whole bar, not a third HStack element flanked
        // by Spacers, matching Klondike's identical statusCapsule placement — reclaims
        // the separate row creditDisplay would otherwise occupy in the ScrollView
        // content, giving that space back to the cards (landscape's shorter height has
        // the least room to spare). Top-aligned, not centered — creditDisplay's
        // own height is taller than topBar's fixed 44pt band, and centering it split
        // that overflow evenly above/below, pushing it up into the status bar/notch
        // above the screen's safe area. Top-aligning keeps its top edge flush with
        // topBar's instead, with a little padding on top of that so it doesn't sit
        // flush against the very top; all the overflow lands below, into the board.
        .overlay(alignment: .top) {
            if isLandscape && !viewModel.isFreePlay {
                creditDisplay
                    .padding(.top, 6)
            }
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
                // Bounded, not .repeatForever — a repeatForever animation triggered by
                // winFlash toggling true then false is never explicitly canceled once
                // started (isHit later going false for a subsequent hand doesn't stop an
                // already-running repeat, since winFlash itself isn't changing anymore),
                // so the pay table row kept pulsing indefinitely after the win that
                // triggered it. 10 repeats (~3s at 0.3s/leg) comfortably outlasts the ~1s
                // window winFlash is actually true for, then settles and stays stopped.
                .animation(isHit ? .easeInOut(duration: 0.3).repeatCount(10, autoreverses: true) : .default, value: winFlash)
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
                    // No "HELD" text label — matches mac, which conveys a held card
                    // purely through the lift, not a separate text caption above it.
                    Group {
                        TouchCardView(card: card, width: cardW)
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
    }

    // Small in-flow hint during the holding phase — split out from the old
    // resultBanner (see resultOverlay below), which used to occupy this same spot in
    // the layout for both this hint AND the win/loss banner. The banner is now a
    // screen-centered overlay instead, so this only needs to reserve its own small
    // height, not the banner's.
    private var holdHint: some View {
        Group {
            if viewModel.state.phase == .holding {
                Text(coordinator.L(.tapHoldDrawHint))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                Text(" ").font(.footnote.weight(.semibold))
            }
        }
        .frame(height: 20)
    }

    // Matches mac's resultBanner overlay (VideoPokerView.swift:521-576) in content —
    // mac's headline is unconditionally yellow for both a win *and* a loss (only the
    // wording and the win-only streak/shadow differ), not white-for-loss the way this
    // read before. Diverges from mac in presentation: doubled in size and centered on
    // the whole screen (an overlay outside the ScrollView's flow, see body) rather than
    // inline between the pay table and the cards, matching mac's own actual pop-up
    // placement more closely than the inline spot this used to occupy did.
    private var resultOverlay: some View {
        ZStack {
            if showResultBanner, viewModel.state.phase == .result, !viewModel.state.lastHandName.isEmpty {
                Color.black.opacity(0.45).ignoresSafeArea()
                    .onTapGesture {
                        viewModel.deal()
                        dealHaptic.impactOccurred()
                    }

                if viewModel.state.lastPayout > 0 {
                    let localizedName = localizedHandName(viewModel.state.lastHandName, language: coordinator.language)
                    VStack(spacing: 12) {
                        Text(coordinator.L(.resultHandNameFmt, localizedName))
                            .font(.system(size: 64, weight: .black))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .foregroundStyle(.yellow)
                            .scaleEffect(winFlash ? 1.1 : 1.0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.45), value: winFlash)
                        if !viewModel.isFreePlay {
                            Text(coordinator.L(.resultCreditsWonFmt, viewModel.state.lastPayout))
                                .font(.title)
                                .foregroundStyle(.white)
                        }
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 32)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(28)
                    .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.5), radius: 24)
                    // Scoped to the message box only, not the whole ZStack (which also
                    // contains the full-bleed scrim above) — ignoresSafeArea() only
                    // cancels the system safe area, not an ancestor's explicit .padding(),
                    // so padding the outer ZStack was insetting the scrim itself, leaving
                    // a visible gap of unshaded background down both edges of the screen.
                    .padding(.horizontal, 16)
                    .onTapGesture {
                        viewModel.deal()
                        dealHaptic.impactOccurred()
                    }
                } else {
                    VStack(spacing: 12) {
                        Text(coordinator.L(.notTodayPartner))
                            .font(.system(size: 64, weight: .black))
                            .minimumScaleFactor(0.5)
                            .lineLimit(2)
                            .foregroundStyle(.yellow)
                        if !viewModel.isFreePlay {
                            Text(coordinator.L(.resultCreditsLostFmt, viewModel.state.currentBet))
                                .font(.title)
                                .foregroundStyle(.white)
                        }
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 32)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(28)
                    // See the win branch's identical .padding(.horizontal, 16) above for
                    // why this is scoped to the box, not the outer ZStack.
                    .padding(.horizontal, 16)
                    .onTapGesture {
                        viewModel.deal()
                        dealHaptic.impactOccurred()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Controls

    // Landscape (and iPad) matches mac's actionButtons exactly (VideoPokerView.swift:
    // 763-793): one continuous, natural-width HStack — bet trio, a Divider, then the
    // phase button. Portrait iPhone stacks instead — Deal/Draw/Rebuy on top, the bet
    // trio in its own row below — since all 5 controls plus a divider in one row left
    // no room for each casinoButton's generous padding/28pt font at portrait iPhone
    // widths, forcing labels to wrap ("Ma-x", "De-al") instead of shrinking gracefully.
    @ViewBuilder
    private func controls(isLandscape: Bool) -> some View {
        if isLandscape {
            // compact: true here — an iPhone's ~400pt landscape height doesn't leave
            // room for the full-size (28pt font/28h·20v padding) buttons below a
            // width-driven card row, and they ran off the bottom/edge of the screen
            // without this. Portrait doesn't need it (buttons stack in their own row
            // under the cards with plenty of vertical room to spare).
            HStack(spacing: 12) {
                betTrio(compact: true)
                if !viewModel.isFreePlay && viewModel.state.phase != .holding {
                    Divider().frame(height: 28).overlay(Color.white.opacity(0.3))
                }
                phaseButton(compact: true)
            }
        } else {
            VStack(spacing: 12) {
                portraitBetTrioSlot()
                phaseButton(compact: false)
            }
        }
    }

    // Matches Blackjack's actionRow/chipRowHeight pattern — betTrio disappears
    // entirely during .holding (nothing to bet with once a hand is in progress),
    // which used to collapse this VStack from 2 rows to 1 and back, shifting the
    // vertically-centered pay table/cards up and down with it (see controlsHeight's
    // own comment and the ScrollView's .padding(.bottom, controlsHeight + 16) below).
    // Swapping in a same-height invisible placeholder instead keeps the controls bar's
    // total height — and therefore controlsHeight — constant across every phase.
    @ViewBuilder
    private func portraitBetTrioSlot() -> some View {
        if viewModel.isFreePlay {
            EmptyView()
        } else if viewModel.state.phase == .holding {
            Color.clear.frame(height: betTrioHeight)
        } else {
            betTrio(compact: false)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { newHeight in
                    betTrioHeight = newHeight
                }
        }
    }

    @ViewBuilder
    private func betTrio(compact: Bool) -> some View {
        // Matches mac's actionButtons: No Stress Mode (isFreePlay) hides the bet trio
        // entirely, not just when holding — there's nothing to bet with in free play.
        if !viewModel.isFreePlay && viewModel.state.phase != .holding {
            HStack(spacing: 12) {
                casinoButton(coordinator.L(.btnBetMinus), color: .white.opacity(0.2), compact: compact) {
                    viewModel.decreaseBet()
                }
                casinoButton(coordinator.L(.touchBetMaxButton), color: .orange.opacity(0.85), compact: compact) {
                    viewModel.maxBet()
                }
                casinoButton(coordinator.L(.btnBetPlus), color: .white.opacity(0.2), compact: compact) {
                    viewModel.increaseBet()
                }
            }
        }
    }

    @ViewBuilder
    private func phaseButton(compact: Bool) -> some View {
        if !canAffordBet && viewModel.state.phase != .holding {
            casinoButton(coordinator.L(.rebuyButton), color: .red.opacity(0.8), compact: compact) {
                viewModel.rebuy()
            }
        } else if viewModel.state.phase == .holding {
            casinoButton(coordinator.L(.btnDraw), color: .green.opacity(0.85), compact: compact) {
                viewModel.draw()
                dealHaptic.impactOccurred()
            }
        } else {
            casinoButton(coordinator.L(.dealButton), color: .yellow, textColor: .black,
                         disabled: !canAffordBet, compact: compact) {
                viewModel.deal()
                dealHaptic.impactOccurred()
            }
        }
    }
}

// MARK: - Settings section shown inside the slide-down menu

struct VideoPokerSettingsSection: View {
    @Bindable var viewModel: VideoPokerViewModel
    let isMidHand: Bool
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                // .pickerStyle(.menu) outside a Form/List only renders the selected
                // value + chevron as a button — the Picker's own label text (passed
                // as its first argument) is silently dropped, unlike a Toggle, whose
                // label always shows inline. Wrapping in an explicit label + Spacer
                // row surfaces it instead of relying on the Picker to show it itself.
                HStack {
                    Text(coordinator.L(.pickerVariantLabel))
                    Spacer()
                    Picker(coordinator.L(.pickerVariantLabel), selection: $viewModel.options.variant) {
                        ForEach(VideoPokerVariant.allCases, id: \.self) { v in
                            Text(localizedVariantName(v, language: coordinator.language)).tag(v)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                // Play Mode (Single/Triple) intentionally left out — Triple Play's
                // three-hand layout isn't built on iOS yet, so exposing the toggle
                // would let the player select a mode this view can't render.

                Stepper(coordinator.L(.startingCreditsFmt, viewModel.options.startingCredits),
                        value: $viewModel.options.startingCredits, in: 100...10000, step: 100)

                HStack {
                    Text(coordinator.L(.pickerDefaultBetLabel))
                    Spacer()
                    Picker(coordinator.L(.pickerDefaultBetLabel), selection: $viewModel.options.betPerHand) {
                        ForEach(1...5, id: \.self) { bet in
                            Text("\(bet)").tag(bet)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                // Sound/No Stress Mode/Honey Mode/Manually Dismiss Banners live in
                // OptionsFullScreenView's own Global section now — this card is
                // Video Poker-specific only. (No Hide Hint here — Video Poker has no
                // hint feature.)
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
                        .buttonStyle(.borderedProminent)
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
