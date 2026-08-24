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
    @State private var showParticles = false
    @State private var cardsVisible = true
    @State private var showCardBackPlaceholders = false
    @State private var dealerFlipped = false
    @State private var showIdlePrompt = false
    @State private var resultHideTask: DispatchWorkItem? = nil
    @State private var resultCardHideTask: DispatchWorkItem? = nil
    @State private var idlePromptTask: DispatchWorkItem? = nil

    // Height of bettingControls' chip row (Clear Bet/Deal sits above it) — reserved as
    // an invisible placeholder under every other phase's single-row controls (Hit/
    // Stand, the dealer-turn spinner, Rebuy) so that row always lands at the same
    // height Clear Bet/Deal sits at, instead of sinking to the very bottom of the
    // screen the way a genuinely shorter block naturally would in this fixed-bottom-
    // bar layout. No-op in free play, where bettingControls itself has no chip row.
    @State private var chipRowHeight: CGFloat = 74

    // Portrait only (see body's isLandscape branch) — just the real, visibly-
    // rendered control row's height, excluding actionRow's invisible
    // chipRowHeight-matching placeholder below single-row phases. cardW's
    // available-height budget uses this one: reserving room for the placeholder
    // too shrank cards to leave space under Hit/Stand that nothing is actually
    // drawn into, since the placeholder exists only to anchor the button row's
    // position, not to hold content cards could otherwise render behind.
    @State private var visibleControlsHeight: CGFloat = 0

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

    private func handSpacing(cardW: CGFloat, count: Int, maxHandWidth: CGFloat) -> CGFloat {
        guard count > 1 else { return 0 }
        // The maximum distance between the leading edges of consecutive cards so the whole
        // hand fits perfectly within maxHandWidth.
        let maxSpacingDistance = (maxHandWidth - cardW) / CGFloat(count - 1)
        // The default comfortable fanned out spacing (lightOverlapFraction = 0.3)
        let defaultSpacingDistance = cardW * (1 - lightOverlapFraction)
        // Use the tighter of the two so small hands don't spread too far, but large hands
        // still fit inside maxHandWidth without shrinking the cards themselves.
        let actualSpacingDistance = min(maxSpacingDistance, defaultSpacingDistance)
        // HStack spacing is the gap between the trailing edge of one card and the leading
        // edge of the next. Negative spacing creates overlap.
        return actualSpacingDistance - cardW
    }

    // A split stacks a second (and possibly third) player hand below the first in
    // portrait — the ScrollView fallback keeps that from ever clipping, but it read
    // as broken rather than intentional: dealer + hands should fit above the fixed
    // controls bar without scrolling whenever reasonably possible. Landscape lays hands
    // out side-by-side instead (see body's isLandscape branch) but hands still stack
    // vertically within the player area during a split, so shrinking helps avoid scrolling.
    private func splitScale(handCount: Int) -> CGFloat {
        guard handCount > 1 else { return 1.0 }
        return handCount >= 3 ? 0.7 : 0.8
    }

    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            // Every landscape phase (betting, playing, dealerTurn, result) now shows
            // its controls in the same inline column between playerHandsArea and
            // dealerArea — see inlineLandscapeControls — instead of some phases using
            // that column and others falling back to a fixed bar under the cards. That
            // used to make dealt cards visibly jump size and position right after
            // Deal: the betting screen's cardW was solved around the inline column's
            // reserved width, while the post-deal screen's cardW was solved around a
            // fixed bottom bar's reserved height instead — two different formulas
            // landing on two different sizes for what should read as the same board.
            // Using one column for every phase means one cardW formula for every
            // phase too, so the board no longer shifts under the player when a hand
            // starts.
            // The height term used to be a flat
            // geo.size.height * 0.32 guess, which was generous enough on an iPhone's
            // ~400pt landscape height to still overflow by a small margin — enough that
            // .scrollBounceBehavior(.basedOnSize) correctly (if unhelpfully) kept
            // allowing a drag, since content genuinely didn't fit. This instead adds up
            // every actual vertical consumer in the single-hand landscape layout —
            // topBar, the VStack's own spacing, dealerArea/playerHandsArea's internal
            // label-to-cards spacing and label line height, and the reserved space
            // below for the fixed controls bar — and solves for the card height that
            // makes the rest fit exactly, so there's no overflow left to scroll.
            // Reserves nothing in landscape — there's no fixed bottom bar to clear
            // there, so cards get to grow into the space it would have used, per
            // request ("if card size can be gained back... increase it").
            // Reserves 58pt in landscape so the inline controls can hang below the cards
            // (specifically so Deal hangs below, aligning 2X/Clear with the cards).
            let reservedBottom: CGFloat = isLandscape ? 58 : (visibleControlsHeight + 38)
            let verticalChrome: CGFloat = 44 /* topBar */ + 16 /* outer VStack spacing */
                + 6 /* dealerArea/playerHandsArea's label-to-cards VStack spacing */
                + 20 /* .subheadline label line height */
                + reservedBottom
            let cardHeightFromAvailable = max(0, geo.size.height - verticalChrome)
            // In landscape, playerHandsArea/dealerArea size to their own natural
            // content width (not frame(maxWidth: .infinity), which portrait's fixed-
            // bottom-bar layout uses instead). We reserve space for the center controls.
            let maxHandWidth: CGFloat = isLandscape
                ? (geo.size.width - (Self.bettingGridButtonWidth * 2 + Self.bettingGridSpacing) - 24 - 60) / 2
                : (geo.size.width - 32)
            let cardWidthFromAvailable = maxHandWidth / 1.7
            let effectiveHandCount = (viewModel.state.playerHands.isEmpty || showCardBackPlaceholders)
                ? 1
                : viewModel.state.playerHands.count
            // Same base width cap as Video Poker (min(width * 0.32, 190)) so the two
            // games' cards read as the same size — without this, maxHandWidth's fit-to-
            // width formula lets a lone 2-card hand grow unbounded on wide screens
            // (iPad portrait: (834-32)/1.7 ≈ 472pt cards).
            let cardW = min(geo.size.width * 0.32, cardHeightFromAvailable / CardDimensions.aspectRatio, cardWidthFromAvailable, 190)
                * splitScale(handCount: effectiveHandCount)

            ZStack(alignment: .bottom) {
                // ScrollView fallback rather than a computed shrink factor — a split
                // stacks a second hand below the first, and this can't always fit
                // dealer + two hands + controls in either orientation. controls itself
                // is pinned below as a fixed bottom bar (not part of this scrolling
                // content) so it's never what gets pushed off screen — only the cards
                // scroll.
                ScrollView {
                    VStack(spacing: 16) {
                        topBar(isLandscape: isLandscape)
                            .padding(.horizontal, 12)
                            .frame(height: 44)

                        if !isLandscape && !viewModel.isFreePlay {
                            creditDisplay
                        }

                        if isLandscape {
                            // Landscape's width can't spare the height a vertical
                            // dealer-then-player stack needs, but it has plenty of width
                            // to spare — dealer left, player right instead, with
                            // inlineLandscapeControls (chips while betting, the action
                            // buttons once a hand starts, etc.) sitting in that same gap
                            // for every phase, so the gap's width — and therefore
                            // cardW — never changes between them.
                            HStack(alignment: .top, spacing: 12) {
                                playerHandsArea(cardW: cardW, maxHandWidth: maxHandWidth)
                                inlineLandscapeControls
                                    // Shrink the layout bounds by 58pt at the bottom so the
                                    // Deal button isn't counted in the height. Then the bottom
                                    // alignment below will align the 2X/Clear row perfectly
                                    // with the bottom of the cards!
                                    .padding(.bottom, -58)
                                    .frame(maxHeight: .infinity, alignment: .bottom)
                                dealerArea(cardW: cardW, maxHandWidth: maxHandWidth)
                            }
                        } else {
                            dealerArea(cardW: cardW, maxHandWidth: maxHandWidth)

                            playerHandsArea(cardW: cardW, maxHandWidth: maxHandWidth)
                        }
                    }
                    // Reserves room at the bottom for the fixed controls bar (measured
                    // live below) so the last card/banner content never ends up
                    // scrolled underneath it — beyond the exact measured height as a
                    // visible buffer (matches Video Poker's identical adjustment;
                    // exactly matching it still read as touching/overlapping). 38, not
                    // 16 — landscape's betting screen still had its chip row grazing
                    // the cards above at 16, then again at 28. 0 when
                    // showsInlineBettingGrid — see reservedBottom above.
                    .padding(.bottom, reservedBottom)
                    // Flexible Spacers used to sit between the cards and controls,
                    // which combined with this enforced min-height stretched them apart
                    // into a large gap at every screen size — top-aligning instead lets
                    // the content hug together at its natural height (buttons directly
                    // under the cards, matching mac) and pushes any leftover space below
                    // the controls instead of between them.
                    .frame(minHeight: geo.size.height, alignment: .top)
                }
                // This ScrollView is a fallback for content that doesn't fit (a split's
                // second hand, a short landscape height), not a surface meant to invite
                // scrolling — hiding the indicator wasn't enough on its own, since a
                // plain ScrollView still lets you drag/rubber-band the content up (with
                // nothing to snap back to but empty space) even when it already fits.
                // .basedOnSize disables that drag entirely whenever content fits within
                // the viewport, and only re-enables real scrolling once content
                // actually overflows it — exactly the fallback-only behavior wanted.
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)

                // Overlay, not part of the ScrollView's flow — centers on the whole
                // screen regardless of scroll position or how tall the dealer/player
                // areas are, rather than wherever it happened to sit between them.
                resultOverlay

                // Listed after resultOverlay so the burst renders in front of the
                // banner, not behind it — matches Windows' BlackjackView, where
                // ParticleCanvas sits at a higher ZIndex than the result overlay, and
                // Video Poker's own confetti/banner ordering here on iOS.
                WinParticleView(active: showParticles)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)

                // Fixed bottom bar, outside the ScrollView above — portrait's
                // dealer+hands stacking vertically with no side-by-side room to spare
                // (a split especially) could grow tall enough to push these action
                // buttons below the visible screen, right when they're needed most.
                // Pinning them here means only the cards ever scroll; the buttons that
                // act on them stay in the same place at every hand size. Landscape
                // never uses this — every phase's controls render inline instead (see
                // inlineLandscapeControls), between the two card areas, not down here.
                if !isLandscape {
                    controls(isLandscape: isLandscape)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        // Less than the top's 12 per request (matches Video Poker's
                        // identical adjustment) — nudges the buttons down a little
                        // closer to the screen's bottom edge.
                        .padding(.bottom, 4)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .environment(\.activeCardBackTheme, coordinator.cardBackTheme)
        .environment(\.activeCustomCardColors, coordinator.customCardColors)
        .sheet(isPresented: $isMenuOpen) { GameSelectionFullScreenView(coordinator: coordinator) }
        .sheet(isPresented: $showingStats) { BlackjackStatsSheet(viewModel: viewModel) }
        .sheet(isPresented: $showingThemes) { ThemesFullScreenView(coordinator: coordinator) }
        .sheet(isPresented: $showingOptions) {
            OptionsFullScreenView(
                coordinator: coordinator,
                onShowStats: { showingStats = true },
                isGlobalSectionDisabled: !viewModel.canOpenOptions,
                globalSectionUnlockNote: coordinator.L(.touchSettingsUnlockBetweenHands)
            ) {
                BlackjackSettingsSection(viewModel: viewModel,
                                         canOpenOptions: viewModel.canOpenOptions,
                                         coordinator: coordinator)
            }
        }
        .queuedFlashBanner(
            trigger: viewModel.flashBannerTrigger,
            latestMessage: viewModel.flashBanner,
            manuallyDismissBanners: viewModel.options.manuallyDismissBanners,
            onAdvanceQueue: viewModel.advanceBannerQueue
        )
        // IOSBackgroundLayer calls .ignoresSafeArea() internally. As a plain ZStack
        // sibling (inside the GeometryReader above), that makes the ZStack itself
        // adopt the full-bleed, notch-including size and propose that same expanded
        // size to every other sibling too — including the ScrollView with the actual
        // game content, which is what let cards and the top bar clip under the
        // Dynamic Island in landscape. Attaching it as .background() here, on the
        // whole view, outside the GeometryReader entirely, avoids that: .background()
        // never feeds size back up to the view it's attached to, so the background
        // can still bleed edge-to-edge without dragging the GeometryReader's own
        // reported size out past the safe area with it.
        .background(IOSBackgroundLayer(intensity: 0.6))
        .onAppear { viewModel.checkLoadingBanner() }
        // Debug-only trigger handler — mirrors mac's BlackjackView.swift onChange(of:
        // viewModel.debugBannerRequest), minus resultBannerShowTask (this view doesn't
        // have that task var). viewModel.debugSetupBannerState(kind) is shared code that
        // builds the actual hand/result state; this just resets the transient result-
        // banner/card UI state around it.
        .onChange(of: viewModel.debugBannerRequest) { _, kind in
            guard let kind else { return }
            viewModel.debugBannerRequest = nil
            resultHideTask?.cancel()
            resultCardHideTask?.cancel()
            showResultBanner = false
            cardsVisible = true
            showCardBackPlaceholders = false
            dealerFlipped = true
            viewModel.debugSetupBannerState(kind)
            showResultBanner = true
        }
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
                if viewModel.state.isWinRound {
                    showParticles = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { showParticles = false }
                }

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
                showParticles = false
                showCardBackPlaceholders = false
                withAnimation(.easeIn(duration: 0.2)) { cardsVisible = true }
            }
            if newPhase == .dealerTurn {
                dealerFlipped = true
            }
        }
    }

    // MARK: Top bar

    private func topBar(isLandscape: Bool) -> some View {
        HStack(spacing: 10) {
            menuBarButtons(isMenuOpen: $isMenuOpen, showingOptions: $showingOptions, showingThemes: $showingThemes, coordinator: coordinator)
            debugMenuButton(items: [("Win", .win), ("Loss", .loss)]) {
                viewModel.debugBannerRequest = $0
            }

            Spacer()

            Text(coordinator.L(.touchBlackjackTitle))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
        }
        // Landscape only: overlay on the whole bar, not a third HStack element flanked
        // by Spacers, matching Klondike's identical statusCapsule placement — reclaims
        // the separate row creditDisplay would otherwise occupy below topBar, giving
        // that space back to the cards (landscape's shorter height has the least room
        // to spare). Top-aligned, not centered — creditDisplay's own height is taller
        // than topBar's fixed 44pt band, and centering it split that overflow evenly
        // above/below, pushing it up into the status bar/notch above the screen's safe
        // area. Top-aligning keeps its top edge flush with topBar's instead, with a
        // little padding on top of that so it doesn't sit flush against the very top;
        // all the overflow lands below, into the board.
        // Portrait has height to spare, so creditDisplay instead renders as its own row
        // below topBar (see body) rather than overlapping the menu icons — the overlay
        // was only ever a landscape space-saving trick, not the intended default.
        .overlay(alignment: .top) {
            if isLandscape && !viewModel.isFreePlay {
                creditDisplay
                    .padding(.top, 6)
            }
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

    private func dealerArea(cardW: CGFloat, maxHandWidth: CGFloat) -> some View {
        VStack(spacing: 6) {
            // Matches playerHandsArea's label font exactly (.subheadline, not
            // .caption) — a smaller dealer label made this VStack's label+cards
            // shorter than the player's, so the two card rows (each top-aligned
            // within their own VStack) landed on different horizontal axes despite
            // sharing one HStack row.
            Text(dealerLabel)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white.opacity(0.7))
            HStack(spacing: handSpacing(cardW: cardW, count: max(viewModel.state.dealerCards.count, 2), maxHandWidth: maxHandWidth)) {
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

    private func playerHandsArea(cardW: CGFloat, maxHandWidth: CGFloat) -> some View {
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
                    HStack(spacing: handSpacing(cardW: cardW, count: 2, maxHandWidth: maxHandWidth)) {
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
                            // No inline per-hand result tag or "BUST" suffix here —
                            // matches mac's playerArea (BlackjackView.swift), which
                            // only ever shows the hand value, never a WIN/LOSS/PUSH/
                            // BUST label beside it; the result is communicated once,
                            // by the big resultBanner below.
                            Text("\(handLabel(hand, index: i))  \(hand.value)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                        }
                        HStack(spacing: handSpacing(cardW: cardW, count: hand.cards.count, maxHandWidth: maxHandWidth)) {
                            ForEach(Array(hand.cards.enumerated()), id: \.offset) { i, card in
                                TouchCardView(card: card, width: cardW)
                                    .opacity(cardsVisible ? 1 : 0)
                                    .animation(.easeIn(duration: 0.15).delay(Double(i) * 0.08), value: cardsVisible)
                                    .zIndex(Double(i))
                            }
                        }
                    }
                    // Padding only when it's actually doing something (giving the
                    // split active-hand highlight below room to breathe) — applied
                    // unconditionally before, this widened a single non-split hand by
                    // 10pt a side versus both the placeholder state and dealerArea
                    // (neither of which ever has this padding), so the whole centered
                    // HStack row grew the moment a hand was dealt, pushing the
                    // dealer's side further right even though it hadn't changed size
                    // at all.
                    .padding(.vertical, viewModel.state.playerHands.count > 1 ? 6 : 0)
                    .padding(.horizontal, viewModel.state.playerHands.count > 1 ? 10 : 0)
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

    // Diverges from mac's resultBanner in presentation (mac: BlackjackView.swift:
    // 554-591) — doubled in size and centered on the whole screen (an overlay outside
    // the ScrollView's flow, see body) rather than inline between the dealer and
    // player hands, matching mac's own actual pop-up placement more closely than the
    // inline spot this used to occupy did. Content/behavior otherwise unchanged.
    private var resultOverlay: some View {
        ZStack {
            if showResultBanner, viewModel.state.phase == .result, viewModel.state.resultOutcome != .none {
                Color.black.opacity(0.45).ignoresSafeArea()

                let (headline, subline) = localizedBlackjackResult(viewModel.state, language: coordinator.language)
                let isWin = viewModel.state.isWinRound
                VStack(spacing: 12) {
                    Text(headline)
                        .font(.system(size: 64, weight: .black))
                        .minimumScaleFactor(0.5)
                        .lineLimit(2)
                        .foregroundStyle(.yellow)

                    if !viewModel.isFreePlay {
                        Text(subline)
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.vertical, 36)
                .background(Color.black.opacity(0.75))
                .cornerRadius(24)
                .shadow(color: isWin ? Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.5) : .clear, radius: 32)
                .padding(.horizontal, 16)
                // Matches mac's bannerWinFlash — a slow repeating pulse for the
                // duration the win banner is visible, not a one-shot flash.
                .scaleEffect(isWin && bannerWinFlash ? 1.06 : 1.0)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: bannerWinFlash)
                .onAppear { if isWin { bannerWinFlash = true } }
                .onDisappear { bannerWinFlash = false }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    // MARK: Controls

    // compact: true in landscape — an iPhone's ~400pt landscape height doesn't leave
    // room for the full-size (28pt font/28h·20v padding) buttons below a width-driven
    // card row, and they ran off the bottom/edge of the screen without this. Portrait
    // doesn't need it (buttons sit in their own row under the cards with plenty of
    // vertical room to spare).
    private func controls(isLandscape: Bool) -> some View {
        Group {
            switch viewModel.state.phase {
            case .betting:
                bettingControls(compact: isLandscape)
            case .playing:
                actionRow(actionControls(compact: isLandscape))
            case .dealerTurn:
                actionRow(
                    HStack {
                        Spacer()
                        ProgressView().tint(.white)
                        Spacer()
                    }
                )
            case .result:
                if viewModel.canRebuy {
                    actionRow(rebuyControl(compact: isLandscape))
                } else {
                    bettingControls(compact: isLandscape)
                }
            }
        }
    }

    // Pads a single-row control block with an invisible placeholder matching the chip
    // row's height (see chipRowHeight) so its one real row lands at the same height
    // Clear Bet/Deal sits at in bettingControls, not bottom-anchored lower on its own.
    private func actionRow(_ row: some View) -> some View {
        VStack(spacing: 10) {
            row
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { newHeight in
                    visibleControlsHeight = newHeight
                }
            if !viewModel.isFreePlay {
                Color.clear.frame(height: chipRowHeight)
            }
        }
    }

    // Chips (1/5/10/25/2x) row, then Clear/Deal below it — iOS-only ordering swap
    // from mac's actionButtons (BlackjackView.swift:600-626), which puts Clear/Deal
    // first. The row of five colored chip buttons was a dark capsule reset+bet-text+
    // double control plus only 3 plain-bordered chips (missing the 10 chip entirely,
    // no color coding, no relation to the rest of the button system) before either
    // platform got this design. The bet amount itself isn't duplicated here, same as
    // mac — it's already shown in creditDisplay's BET stat above.
    private func bettingControls(compact: Bool) -> some View {
        // Betting has two rows (5 chips, then Clear/Deal) competing for the same
        // landscape height every other phase's single row doesn't — 10% smaller than
        // the standard compact scale per request, on top of the extra vertical
        // clearance added below (see the ScrollView's .padding(.bottom, ...)).
        let scale: CGFloat = compact ? 0.9 : 1.0
        return VStack(spacing: 10) {
            if !viewModel.isFreePlay {
                HStack(spacing: 10) {
                    casinoButton(coordinator.L(.chip1), color: .white, textColor: .black, compact: true, scale: scale) { viewModel.addToBet(1) }
                    casinoButton(coordinator.L(.chip5), color: .red.opacity(0.85), compact: true, scale: scale) { viewModel.addToBet(5) }
                    casinoButton(coordinator.L(.chip10), color: .blue.opacity(0.75), compact: true, scale: scale) { viewModel.addToBet(10) }
                    casinoButton(coordinator.L(.chip25), color: .green.opacity(0.75), compact: true, scale: scale) { viewModel.addToBet(25) }
                    casinoButton(coordinator.L(.chip2x), color: .orange.opacity(0.85), compact: true, scale: scale) { viewModel.doubleBet() }
                }
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { newHeight in
                    chipRowHeight = newHeight
                }
            }

            HStack(spacing: 10) {
                if !viewModel.isFreePlay {
                    casinoButton(coordinator.L(.btnClearBet), color: Color(white: 0.25), compact: compact, scale: scale) {
                        viewModel.clearBet()
                    }
                }
                casinoButton(coordinator.L(.dealButton), color: .yellow,
                             disabled: !canAffordBet || viewModel.state.currentBet == 0, compact: compact, scale: scale) {
                    viewModel.deal()
                    actionHaptic.impactOccurred()
                }
            }
        }
        // No invisible placeholder here, unlike actionRow — both rows are real
        // content, so this VStack's whole rendered height already is the visible
        // height (see visibleControlsHeight above).
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { newHeight in
            visibleControlsHeight = newHeight
        }
    }

    // Landscape's inline controls column, between playerHandsArea and dealerArea —
    // one shared column every phase renders into (see body's isLandscape branch),
    // so the column's width — and therefore cardW, solved around it — never
    // changes between phases. .frame(maxHeight: .infinity, alignment: .bottom) is
    // applied once at the call site (not per-case here) so every phase's content
    // lands flush with the bottom of the cards the same way.
    @ViewBuilder
    private var inlineLandscapeControls: some View {
        switch viewModel.state.phase {
        case .betting:
            bettingGridLandscape
        case .playing:
            actionColumnLandscape
        case .dealerTurn:
            ProgressView().tint(.white)
                .frame(width: Self.bettingGridButtonWidth * 2 + Self.bettingGridSpacing)
        case .result:
            if viewModel.canRebuy {
                casinoButton(coordinator.L(.rebuyButton), color: .red.opacity(0.8), compact: true,
                             width: Self.bettingGridButtonWidth * 2 + Self.bettingGridSpacing) {
                    viewModel.rebuy()
                }
            } else {
                bettingGridLandscape
            }
        }
    }

    // Matches the requested mockup: a 2-column grid (1/5, 10/25, 2X/Clear) with Deal
    // spanning below, sitting in the gap between playerHandsArea and dealerArea
    // instead of bettingControls' two full-width rows in a fixed bar under the
    // cards. Every chip/Clear cell shares one fixed width (wide enough for "Clear",
    // the longest label) rather than each sizing to its own content — per request,
    // so "1" doesn't read as a narrower button than "Clear". Deal is exactly double
    // that width plus the column gap, so it visually spans both columns and reads
    // as the button that draws the eye. Height stays a minHeight floor, not fixed —
    // that sizing was already right.
    // 68pt is "Clear"'s exact unwrapped width at this font/padding (18pt black
    // condensed + 14pt horizontal padding each side) — measured live via a
    // temporary onGeometryChange readout rather than guessed. +4 for a small
    // safety margin against rounding.
    private static let bettingGridButtonWidth: CGFloat = 72
    private static let bettingGridButtonMinHeight: CGFloat = 34
    private static let bettingGridSpacing: CGFloat = 4

    private var bettingGridLandscape: some View {
        VStack(spacing: Self.bettingGridSpacing) {
            if !viewModel.isFreePlay {
                Grid(horizontalSpacing: Self.bettingGridSpacing, verticalSpacing: Self.bettingGridSpacing) {
                    GridRow {
                        casinoButton(coordinator.L(.chip1), color: .white, textColor: .black, compact: true, width: Self.bettingGridButtonWidth) { viewModel.addToBet(1) }
                        casinoButton(coordinator.L(.chip5), color: .red.opacity(0.85), compact: true, width: Self.bettingGridButtonWidth) { viewModel.addToBet(5) }
                    }
                    GridRow {
                        casinoButton(coordinator.L(.chip10), color: .blue.opacity(0.75), compact: true, width: Self.bettingGridButtonWidth) { viewModel.addToBet(10) }
                        casinoButton(coordinator.L(.chip25), color: .green.opacity(0.75), compact: true, width: Self.bettingGridButtonWidth) { viewModel.addToBet(25) }
                    }
                    GridRow {
                        casinoButton(coordinator.L(.chip2x), color: .orange.opacity(0.85), compact: true, width: Self.bettingGridButtonWidth) { viewModel.doubleBet() }
                        casinoButton(coordinator.L(.btnClearShort), color: Color(white: 0.25), compact: true, width: Self.bettingGridButtonWidth) { viewModel.clearBet() }
                    }
                }
            }
            casinoButton(coordinator.L(.dealButton), color: .yellow,
                         disabled: !canAffordBet || viewModel.state.currentBet == 0, compact: true, width: Self.bettingGridButtonWidth * 2 + Self.bettingGridSpacing) {
                viewModel.deal()
                actionHaptic.impactOccurred()
            }
        }
        // Pinned explicitly, matching actionColumnLandscape's own explicit width —
        // without this, the column relied on the Grid/Deal button's content
        // naturally landing at exactly bettingGridButtonWidth * 2 + bettingGridSpacing,
        // which isn't guaranteed pixel-for-pixel, and any drift there shifted the
        // whole HStack's centered position the moment Deal switched this column out
        // for actionColumnLandscape.
        .frame(width: Self.bettingGridButtonWidth * 2 + Self.bettingGridSpacing)
    }

    // Stacked, not the portrait/original actionControls' HStack row — a Hit/Stand/
    // Double/Split row at full size (or even compact size) is wider than
    // inlineLandscapeControls' column has room for. Each button spans the full
    // column width (bettingGridButtonWidth * 2 + bettingGridSpacing, matching
    // bettingGridLandscape's Deal button) rather than a single grid-cell width —
    // narrower than that wrapped "Stand"/"Double" onto two lines and clipped.
    private var actionColumnLandscape: some View {
        VStack(spacing: Self.bettingGridSpacing) {
            casinoButton(coordinator.L(.touchActionHit), color: .green.opacity(0.85), compact: true,
                         width: Self.bettingGridButtonWidth * 2 + Self.bettingGridSpacing) {
                viewModel.hit()
                actionHaptic.impactOccurred()
            }
            casinoButton(coordinator.L(.touchActionStand), color: .red.opacity(0.75), compact: true,
                         width: Self.bettingGridButtonWidth * 2 + Self.bettingGridSpacing) {
                viewModel.stand()
                actionHaptic.impactOccurred()
            }
            if viewModel.canDouble {
                casinoButton(coordinator.L(.touchActionDouble), color: .blue.opacity(0.75), compact: true,
                             width: Self.bettingGridButtonWidth * 2 + Self.bettingGridSpacing) {
                    viewModel.doubleDown()
                    actionHaptic.impactOccurred()
                }
            }
            if viewModel.canSplit {
                casinoButton(coordinator.L(.touchActionSplit), color: .purple.opacity(0.75), compact: true,
                             width: Self.bettingGridButtonWidth * 2 + Self.bettingGridSpacing) {
                    viewModel.split()
                    actionHaptic.impactOccurred()
                }
            }
        }
        // Redundant with each button's own explicit width above, but pins the
        // VStack's own reported width too — without it, an empty state (Double/
        // Split both hidden) could in principle report a narrower natural width and
        // shrink the whole column, pulling playerHandsArea/dealerArea closer
        // together and shifting the board sideways even though cardW hasn't changed.
        .frame(width: Self.bettingGridButtonWidth * 2 + Self.bettingGridSpacing)
    }

    private func actionControls(compact: Bool) -> some View {
        HStack(spacing: 10) {
            casinoButton(coordinator.L(.touchActionHit), color: .green.opacity(0.85), compact: compact) {
                viewModel.hit()
                actionHaptic.impactOccurred()
            }
            casinoButton(coordinator.L(.touchActionStand), color: .red.opacity(0.75), compact: compact) {
                viewModel.stand()
                actionHaptic.impactOccurred()
            }
            if viewModel.canDouble {
                casinoButton(coordinator.L(.touchActionDouble), color: .blue.opacity(0.75), compact: compact) {
                    viewModel.doubleDown()
                    actionHaptic.impactOccurred()
                }
            }
            if viewModel.canSplit {
                casinoButton(coordinator.L(.touchActionSplit), color: .purple.opacity(0.75), compact: compact) {
                    viewModel.split()
                    actionHaptic.impactOccurred()
                }
            }
        }
    }

    private func rebuyControl(compact: Bool) -> some View {
        HStack {
            Spacer()
            casinoButton(coordinator.L(.rebuyButton), color: .red.opacity(0.8), compact: compact) {
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
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                // Sound/No Stress Mode/Honey Mode/Manually Dismiss Banners live in
                // OptionsFullScreenView's own Global section now — this card is
                // Blackjack-specific only. (No Hide Hint here — Blackjack has no hint
                // feature. No onNoStressModeChange either, unlike the other games —
                // isFreePlay reads options.noStressMode live, so the change takes
                // effect on the next deal on its own; calling startNewGame() there
                // only served to unconditionally wipe the win streak on a benign
                // settings change.)
                Stepper(coordinator.L(.startingCreditsFmt, viewModel.options.startingCredits),
                        value: $viewModel.options.startingCredits, in: 10...10000, step: 10)
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
