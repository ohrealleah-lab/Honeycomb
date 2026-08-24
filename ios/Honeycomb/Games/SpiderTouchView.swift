import SwiftUI
import UIKit

/// Touch-first Spider board for iPhone/iPad, driven by the shared SpiderViewModel.
/// Same interaction pattern as KlondikeTouchView (the drag feel the user picked):
/// custom DragGesture + pile-frame hit testing. Spider-specific bits: only same-suit
/// descending runs can be picked up (isValidDragSequence), tapping the stock deals a
/// row, and completed runs sweep themselves — foundations are a progress indicator,
/// not a drop target.
struct SpiderTouchView: View {
    @Bindable var viewModel: SpiderViewModel
    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator
    @Environment(\.scenePhase) private var scenePhase

    private static let boardSpace = "spiderBoard"
    private static let columnSpacing: CGFloat = 4

    @State private var pileFrames: [String: CGRect] = [:]
    @State private var draggedCards: [Card] = []
    @State private var dragSourcePile: Pile? = nil
    @State private var dragLocation: CGPoint = .zero
    @State private var dragOffset: CGSize = .zero

    @State private var isMenuOpen = false
    @State private var showingOptions = false
    @State private var showingThemes = false
    @State private var showingStats = false
    @State private var dismissedStuckBanner = false
    @State private var showParticles = false
    @State private var isDealInFlight = false
    @State private var showNoHintsBanner = false
    @State private var noHintsBannerTask: DispatchWorkItem? = nil
    @State private var showEmptyStockWarning = false
    @State private var emptyStockWarningTask: DispatchWorkItem? = nil

    private let placementHaptic = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        GeometryReader { geo in
            // Width-fit first (always exactly fills available width, spacing/padding
            // included), then shrink further only if the deepest column would overflow
            // the available height — see KlondikeTouchView for the full rationale.
            let widthCardW = min((geo.size.width - 16 - 9 * Self.columnSpacing) / 10, 90)
            let widthCardH = widthCardW * CardDimensions.aspectRatio
            let neededHeight = 54 + widthCardH + 10 + deepestColumnHeight(cardH: widthCardH) + 20
            let heightShrink = neededHeight > geo.size.height ? geo.size.height / neededHeight : 1.0
            let cardW = widthCardW * heightShrink
            let cardH = cardW * CardDimensions.aspectRatio

            ZStack {
                VStack(spacing: 10) {
                    topBar
                        .padding(.horizontal, 12)
                        .frame(height: 44)

                    topRow(cardW: cardW, cardH: cardH)
                        .padding(.horizontal, 8)

                    tableauRow(cardW: cardW, cardH: cardH)
                        .padding(.horizontal, 8)

                    Spacer(minLength: 0)
                }

                dragOverlay(cardW: cardW, cardH: cardH)

                if viewModel.isAutocompleteAvailable && !viewModel.state.hasWon {
                    autocompleteButton
                }

                if viewModel.state.hasWon {
                    // Unlike Klondike/Beecell, Spider intentionally skips the bouncing-
                    // card cascade and just shows the banner + confetti.
                    winOverlay

                    // On top of the banner (not behind it) — matches the Blackjack/
                    // Video Poker confetti ordering.
                    WinParticleView(active: showParticles)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)
                }

                if viewModel.isStuck && !viewModel.state.hasWon && !dismissedStuckBanner {
                    stuckOverlay
                }

                if showNoHintsBanner {
                    noHintsBanner
                }

                if showEmptyStockWarning {
                    emptyStockWarningBanner
                }
            }
            // Anchors boardSpace — every pileFrames GeometryReader and DragGesture
            // .named(Self.boardSpace) reference below depends on this exact container.
            // Moving this modifier to a different view breaks drop hit-testing silently.
            .coordinateSpace(name: Self.boardSpace)
        }
        .environment(\.feltColor, coordinator.feltColor)
        .environment(\.activeCardBackTheme, coordinator.cardBackTheme)
        .environment(\.activeCustomCardColors, coordinator.customCardColors)
        .sheet(isPresented: $isMenuOpen) { GameSelectionFullScreenView(coordinator: coordinator) }
        .sheet(isPresented: $showingStats) { SpiderStatsSheet(viewModel: viewModel) }
        .sheet(isPresented: $showingThemes) { ThemesFullScreenView(coordinator: coordinator) }
        .sheet(isPresented: $showingOptions) {
            OptionsFullScreenView(coordinator: coordinator, onShowStats: { showingStats = true }) {
                SpiderSettingsSection(viewModel: viewModel, coordinator: coordinator)
            }
        }
        .onAppear {
            viewModel.startTimerIfNeeded()
            viewModel.checkLoadingBanner()
        }
        // Re-arms the idle-nudge timer on every move, matching mac
        // (SpiderView.swift:589-590) — previously only armed once via startNewGame().
        .onChange(of: viewModel.state.movesCount) {
            viewModel.scheduleIdleActionCheck()
        }
        .onChange(of: viewModel.state.hasWon) { _, newVal in
            dismissedStuckBanner = false
            if newVal {
                showParticles = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { showParticles = false }
            }
        }
        // Debug-only trigger handler — mirrors mac's SpiderView.swift onChange(of:
        // viewModel.debugBannerRequest), minus dismissedWinBanner/dismissedAutocompleteBanner
        // resets (this view doesn't have those flags — its win/autocomplete UI shows
        // unconditionally off hasWon/isAutocompleteAvailable, no separate dismiss state).
        .onChange(of: viewModel.debugBannerRequest) { _, kind in
            guard let kind else { return }
            viewModel.debugBannerRequest = nil
            switch kind {
            case .win:
                let suits: [Card.Suit] = [.spades, .clubs, .diamonds, .hearts]
                let count = max(viewModel.state.foundations.count, 4)
                viewModel.state.foundations = (0..<count).map { i in
                    let suit = suits[i % suits.count]
                    let cards = (1...13).map { Card(suit: suit, rank: $0, faceUp: true) }
                    return Pile(id: "foundation_\(i)", type: .foundation, cards: cards)
                }
                viewModel.state.hasWon = true
            case .stuck:
                viewModel.state.hasWon = false
                dismissedStuckBanner = false
                viewModel.isStuck = true
            case .autocomplete:
                viewModel.state.hasWon = false
                viewModel.isAutocompleteAvailable = true
            case .loss, .same, .plus, .suddenDeath:
                break
            }
        }
        // Mirrors the mac view's NSWindow.didResignKeyNotification safety net: SwiftUI's
        // DragGesture has no "cancelled" callback, so a drag interrupted by the app
        // backgrounding (Control Center, an incoming call, the home gesture, etc.) never
        // fires .onEnded — without this, the floating drag overlay would keep rendering
        // forever and the source pile would stay hidden its dragged card.
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase != .active, !draggedCards.isEmpty else { return }
            cancelDrag()
        }
        .queuedFlashBanner(
            trigger: viewModel.flashBannerTrigger,
            latestMessage: viewModel.flashBanner,
            manuallyDismissBanners: viewModel.options.manuallyDismissBanners,
            onAdvanceQueue: viewModel.advanceBannerQueue
        )
        .background(IOSBackgroundLayer())
    }

    // MARK: Top bar

    private var topBar: some View {
        // statusCapsule is an overlay, not a third HStack element flanked by
        // Spacers — the leading (menu) and trailing (New Deal) content aren't the
        // same width, so centering it "between" two Spacers actually centered it in
        // whatever space was left over, not on the bar itself. An overlay centers it
        // on the full bar width regardless of how wide either side is.
        HStack(spacing: 10) {
            menuBarButtons(isMenuOpen: $isMenuOpen, showingOptions: $showingOptions, showingThemes: $showingThemes, coordinator: coordinator)
            debugMenuButton(items: [("Win", .win), ("Loss (Stuck)", .stuck), ("Autocomplete", .autocomplete)]) {
                viewModel.debugBannerRequest = $0
            }

            Spacer()

            Button {
                dismissedStuckBanner = false
                viewModel.startNewGame()
            } label: {
                Label(coordinator.L(.touchNewDealLabel), systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .overlay { statusCapsule }
    }

    private var statusCapsule: some View {
        HStack(spacing: 14) {
            statusStat(coordinator.L(.scoreLabel), viewModel.scoreString, color: .yellow)
            if viewModel.options.isTimed && !viewModel.options.noStressMode {
                statusStat(coordinator.L(.timeLabel), formatTime(viewModel.state.timerSeconds), color: .white.opacity(0.85))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(.black.opacity(0.35), in: Capsule())
    }

    // MARK: Top row: stock (deal), undo/hint, completed-runs indicator

    private var completedRunCount: Int {
        viewModel.state.foundations.filter { !$0.cards.isEmpty }.count
    }

    private func topRow(cardW: CGFloat, cardH: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 12) {
            stockView(cardW: cardW, cardH: cardH)

            Spacer()

            controlCircle(systemImage: "arrow.uturn.backward", label: coordinator.L(.undo)) {
                viewModel.undoLastAction()
            }
            .disabled(!viewModel.canUndo)
            .opacity(viewModel.canUndo ? 1 : 0.35)

            if !viewModel.options.hideHintButton {
                controlCircle(systemImage: "lightbulb", label: coordinator.L(.hint)) {
                    if !viewModel.findHint() {
                        flashNoHintsBanner()
                    }
                }
            }

            Spacer()

            runsIndicator(cardW: cardW, cardH: cardH)
        }
        .frame(height: cardH)
    }

    private func stockView(cardW: CGFloat, cardH: CGFloat) -> some View {
        let dealsLeft = viewModel.state.stock.cards.count / max(viewModel.state.tableau.count, 1)
        return ZStack(alignment: .topLeading) {
            if viewModel.state.stock.isEmpty {
                RoundedRectangle(cornerRadius: cardW * 0.07)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
                    .frame(width: cardW, height: cardH)
            } else {
                // One back per remaining deal, slightly fanned like the mac view.
                ForEach(0..<max(dealsLeft, 1), id: \.self) { i in
                    HoneycombSimpleCardBack()
                        .frame(width: cardW, height: cardH)
                        .overlay(
                            RoundedRectangle(cornerRadius: cardW * 0.07)
                                .stroke(Color.black.opacity(0.85), lineWidth: 0.75)
                        )
                        .offset(x: CGFloat(i) * 6)
                }
            }
        }
        .frame(width: cardW + CGFloat(max(dealsLeft - 1, 0)) * 6, height: cardH, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture { performDeal() }
        .accessibilityLabel(coordinator.L(.touchDealA11y))
    }

    private func runsIndicator(cardW: CGFloat, cardH: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cardW * 0.07)
                .fill(Color.black.opacity(0.18))
            RoundedRectangle(cornerRadius: cardW * 0.07)
                .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
            VStack(spacing: 2) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(completedRunCount > 0 ? .yellow : .white.opacity(0.35))
                Text("\(completedRunCount)/\(viewModel.state.foundations.count)")
                    .font(.system(size: cardW * 0.28, weight: .bold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .frame(width: cardW * 1.4, height: cardH)
        .accessibilityLabel(coordinator.L(.touchCompletedRunsA11y))
    }

    // MARK: Tableau

    private func tableauRow(cardW: CGFloat, cardH: CGFloat) -> some View {
        HStack(alignment: .top, spacing: Self.columnSpacing) {
            ForEach(viewModel.state.tableau) { pile in
                tableauColumn(pile: pile, cardW: cardW, cardH: cardH)
            }
        }
    }

    /// The deepest tableau column's actual stacked height at the given card height —
    /// same per-card offsets tableauColumn renders with, so the fit-to-screen scale
    /// computed from this always matches what's actually drawn.
    private func deepestColumnHeight(cardH: CGFloat) -> CGFloat {
        let upStep = cardH * 0.24
        let downStep = cardH * 0.12
        return viewModel.state.tableau.map { pile -> CGFloat in
            guard !pile.cards.isEmpty else { return cardH }
            var running: CGFloat = 0
            for card in pile.cards.dropLast() {
                running += card.faceUp ? upStep : downStep
            }
            return running + cardH
        }.max() ?? cardH
    }

    private func tableauColumn(pile: Pile, cardW: CGFloat, cardH: CGFloat) -> some View {
        let upStep = cardH * 0.24
        let downStep = cardH * 0.12

        var offsets: [CGFloat] = []
        var running: CGFloat = 0
        for card in pile.cards {
            offsets.append(running)
            running += card.faceUp ? upStep : downStep
        }
        let columnHeight = (pile.cards.isEmpty ? cardH : (offsets.last ?? 0) + cardH)
        let hintIndex = hintTouches(pile.id)
            ? pile.cards.firstIndex(where: { $0.id == viewModel.activeHint?.card.id })
            : nil

        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: cardW * 0.07)
                .fill(Color.black.opacity(0.18))
                .frame(width: cardW, height: cardH)
            ForEach(Array(pile.cards.enumerated()), id: \.element.id) { i, card in
                let stack = Array(pile.cards[i...])
                TouchCardView(card: card, width: cardW)
                    .offset(y: offsets[i])
                    .opacity(draggedCards.contains(where: { $0.id == card.id }) ? 0 : 1)
                    .onTapGesture(count: 2) {
                        viewModel.doubleClickMove(card: card, from: pile)
                    }
                    .gesture(
                        (card.faceUp && viewModel.isValidDragSequence(stack))
                            ? cardDragGesture(pile: pile, stack: stack) : nil
                    )
            }
            // Drawn as its own sibling, positioned with the exact same offsets[]
            // value as the matched card, rather than attached via modifier chaining
            // on the card itself — the per-card modifier version was reported
            // visually landing above the actual hinted card instead of tightly
            // bordering it, which this sidesteps entirely by computing the ring's
            // position independently, from the same source of truth.
            //
            // Always mounted (not `if let hintIndex { ... }`) — TouchHintHighlight's
            // pulse only starts on an isHighlighted false->true *transition* (it's
            // driven by .onChange). A conditionally-inserted view is born with
            // isHighlighted already true, so there's no transition to observe: phase
            // never leaves 0 and the ring's opacity formula ((1-cos(phase*pi*4))/2)
            // stays permanently 0 — invisible. The empty-column ring below never hits
            // this because it's an unconditional sibling that sees the real
            // false->true edge when a hint lands on it.
            Color.clear
                .frame(width: cardW, height: cardH)
                // TouchHintHighlight's pulse modifier conforms to AnimatableModifier —
                // it receives its content as an opaque view and animates only its own
                // `phase` property. Proven via direct instrumentation (computedOffset
                // math lands exactly on the hinted card's position every time) that
                // this is a rendering, not a data, bug: once the pulse animation is
                // running, AnimatableModifier can keep presenting geometry from
                // whenever that animation started rather than picking up a same-frame
                // change to *content* (here, a new .offset() from hintIndex changing).
                // Moving .offset() to apply AFTER (outside) the animated modifier,
                // instead of before/inside it, means it's shifting the whole already-
                // rendered bordered box from the outside every frame — nothing for the
                // animator to cache stale.
                .modifier(TouchHintHighlight(isHighlighted: hintIndex != nil))
                .offset(y: hintIndex.flatMap { offsets.indices.contains($0) ? offsets[$0] : nil } ?? 0)
                .allowsHitTesting(false)
        }
        .frame(width: cardW, height: columnHeight, alignment: .top)
        .modifier(TouchHintHighlight(isHighlighted: pile.cards.isEmpty && hintTouches(pile.id)))
        .background(frameTracker(id: pile.id))
    }

    // MARK: Shared pieces

    private func controlCircle(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.black.opacity(0.35), in: Circle())
        }
        .accessibilityLabel(label)
    }

    private func frameTracker(id: String) -> some View {
        GeometryReader { geo in
            Color.clear
                .onAppear { pileFrames[id] = geo.frame(in: .named(Self.boardSpace)) }
                .onChange(of: geo.frame(in: .named(Self.boardSpace))) { _, newFrame in
                    pileFrames[id] = newFrame
                }
        }
    }

    private func hintTouches(_ pileId: String) -> Bool {
        (viewModel.activeHint?.sourcePileId == pileId) || 
        (viewModel.activeHint?.targetPileId == pileId)
    }

    // MARK: Drag handling (Klondike pattern; tableau-only targets)

    private func cardDragGesture(pile: Pile, stack: [Card]) -> some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .named(Self.boardSpace))
            .onChanged { val in
                if draggedCards.isEmpty {
                    viewModel.clearHint()
                    draggedCards = stack
                    dragSourcePile = pile
                    dragLocation = val.startLocation
                }
                dragOffset = val.translation
            }
            .onEnded { _ in handleDragEnded() }
    }

    @ViewBuilder
    private func dragOverlay(cardW: CGFloat, cardH: CGFloat) -> some View {
        if !draggedCards.isEmpty {
            let upStep = cardH * 0.24
            let stackH = cardH + CGFloat(draggedCards.count - 1) * upStep
            ZStack(alignment: .top) {
                ForEach(Array(draggedCards.enumerated()), id: \.element.id) { i, card in
                    TouchCardView(card: card, width: cardW)
                        .offset(y: CGFloat(i) * upStep)
                }
            }
            .frame(width: cardW, height: stackH, alignment: .top)
            .position(x: dragLocation.x + dragOffset.width,
                      y: dragLocation.y + dragOffset.height + stackH / 2 - cardH * 0.4)
            .shadow(radius: 8, y: 4)
            .allowsHitTesting(false)
            .zIndex(10)
        }
    }

    private func cancelDrag() {
        draggedCards = []
        dragSourcePile = nil
        dragOffset = .zero
    }

    private func handleDragEnded() {
        let releaseLocation = CGPoint(
            x: dragLocation.x + dragOffset.width,
            y: dragLocation.y + dragOffset.height
        )

        func accepts(_ pile: Pile) -> Bool {
            SmartDrop.resolve(cards: draggedCards, isValidMove: { viewModel.isValidMove(cards: $0, to: pile) }) != nil
        }

        struct Candidate {
            let pile: Pile
            let accepts: Bool
            let distanceX: CGFloat
        }
        var candidates: [Candidate] = []
        for tab in viewModel.state.tableau {
            if let frame = pileFrames[tab.id] {
                let margin: CGFloat = 12
                let inX = releaseLocation.x >= frame.minX - margin && releaseLocation.x <= frame.maxX + margin
                let inY = releaseLocation.y >= frame.minY - margin
                if inX && inY {
                    candidates.append(Candidate(
                        pile: tab, accepts: accepts(tab),
                        distanceX: abs(releaseLocation.x - frame.midX)))
                }
            }
        }
        if let best = candidates.sorted(by: { c1, c2 in
            if c1.accepts != c2.accepts { return c1.accepts && !c2.accepts }
            return c1.distanceX < c2.distanceX
        }).first, best.accepts,
           let source = dragSourcePile,
           let resolved = SmartDrop.resolve(cards: draggedCards, isValidMove: { viewModel.isValidMove(cards: $0, to: best.pile) }) {
            viewModel.clearHint()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                viewModel.moveCards(resolved, from: source, to: best.pile)
            }
            placementHaptic.impactOccurred()
        }

        viewModel.clearHint()
        cancelDrag()
    }

    private func performDeal() {
        guard !viewModel.state.stock.isEmpty, !isDealInFlight, !viewModel.state.hasWon else { return }
        viewModel.clearHint()
        if viewModel.hasEmptyTableauColumn {
            flashEmptyStockWarning()
            return
        }
        isDealInFlight = true
        withAnimation(.easeInOut(duration: 0.25)) {
            viewModel.drawFromStock()
        }
        placementHaptic.impactOccurred(intensity: 0.7)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isDealInFlight = false
        }
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    // Matches mac's StatusItemView (label above, value below) rather than an unlabeled
    // capsule of raw numbers — a player glancing at "-$52.00  00:00" has no way to tell
    // which is score/bankroll and which is the timer without already knowing the format.
    private func statusStat(_ label: String, _ value: String, color: Color) -> some View {
        VStack(spacing: 0) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
        }
    }

    // MARK: Overlays

    private var autocompleteButton: some View {
        VStack {
            Spacer()
            Button {
                viewModel.runAutocomplete()
            } label: {
                Label(coordinator.L(.helpShortcutAutocomplete), systemImage: "wand.and.stars")
                    .font(.headline)
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.yellow)
            .foregroundStyle(.black)
            .padding(.bottom, 24)
        }
    }

    private var winOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 16) {
                Text(coordinator.L(.youWin))
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.yellow)
                Text(coordinator.L(.scoreFmt, viewModel.scoreString))
                    .foregroundColor(.white)
                Button {
                    viewModel.startNewGame()
                } label: {
                    Label(coordinator.L(.newGame), systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: 240)
            }
            .padding(28)
            // Matches mac's SpiderView win overlay exactly (solid dark card + yellow-
            // glow shadow) rather than the frosted .ultraThinMaterial look this had
            // before, which let the board show through and didn't match any other banner.
            .background(Color.black.opacity(0.75))
            .cornerRadius(12)
            .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.5), radius: 16)
        }
    }

    private var noHintsBanner: some View {
        VStack {
            Text(coordinator.L(.noHintsAvailable))
                .font(.title3.weight(.black))
                .foregroundStyle(Color.yellow)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.black.opacity(0.75), in: Capsule())
                .transition(.scale.combined(with: .opacity))
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 60)
        .allowsHitTesting(false)
    }

    private func flashNoHintsBanner() {
        noHintsBannerTask?.cancel()
        withAnimation(.easeIn(duration: 0.15)) { showNoHintsBanner = true }
        let task = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.3)) { showNoHintsBanner = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: task)
        noHintsBannerTask = task
    }

    private var emptyStockWarningBanner: some View {
        VStack {
            Text(coordinator.L(.emptyColumnDrawToast))
                .font(.subheadline.weight(.black))
                .foregroundStyle(Color.yellow)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 16))
                .contentShape(Rectangle())
                .onTapGesture { dismissEmptyStockWarning() }
                .transition(.scale.combined(with: .opacity))
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 60)
        .allowsHitTesting(viewModel.options.manuallyDismissBanners)
    }

    private func dismissEmptyStockWarning() {
        emptyStockWarningTask?.cancel()
        emptyStockWarningTask = nil
        withAnimation(.easeOut(duration: 0.3)) { showEmptyStockWarning = false }
    }

    private func flashEmptyStockWarning() {
        emptyStockWarningTask?.cancel()
        withAnimation(.easeIn(duration: 0.15)) { showEmptyStockWarning = true }
        // Same gate as the queued/milestone banner (.queuedFlashBanner's own
        // manuallyDismissBanners handling) — when the option is on, the toast
        // stays up until tapped instead of timing out underneath the player.
        guard !viewModel.options.manuallyDismissBanners else {
            emptyStockWarningTask = nil
            return
        }
        let task = DispatchWorkItem { dismissEmptyStockWarning() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: task)
        emptyStockWarningTask = task
    }

    private var stuckOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 14) {
                Text(coordinator.L(.gameOver))
                    .font(.system(size: 34, weight: .black))
                    .foregroundColor(.yellow)
                Text(coordinator.L(.noMovesRemaining))
                    .foregroundColor(.white)
                Button {
                    dismissedStuckBanner = true
                    viewModel.restartCurrentGame()
                } label: {
                    Label(coordinator.L(.restartGame), systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.white)
                Button {
                    dismissedStuckBanner = false
                    viewModel.startNewGame()
                } label: {
                    Label(coordinator.L(.newGame), systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: 260)
            .padding(24)
            // Matches mac's SpiderView stuck overlay exactly — see winOverlay above.
            .background(Color.black.opacity(0.75))
            .cornerRadius(12)
            .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.5), radius: 16)
            .overlay(alignment: .topTrailing) {
                Button {
                    dismissedStuckBanner = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(8)
            }
        }
    }
}

// MARK: - Settings section shown inside the slide-down menu

struct SpiderSettingsSection: View {
    @Bindable var viewModel: SpiderViewModel
    // @Bindable, not @Environment — Sound/No Stress Mode/Honey Mode/Manually Dismiss
    // Banners bind directly to the coordinator (see AppCoordinator's "single source of
    // truth" fields) so a change here live-propagates to every other game via their
    // own didSet, instead of only updating this one game's local options copy.
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(coordinator.L(.touchSuitsPickerLabel), selection: $viewModel.options.suitCount) {
                Text(coordinator.L(.suitCount1)).tag(1)
                Text(coordinator.L(.suitCount2)).tag(2)
                Text(coordinator.L(.suitCount4)).tag(4)
            }
            .pickerStyle(.segmented)

            Toggle(coordinator.L(.soundShort), isOn: $coordinator.isSoundEnabled)
            Toggle(coordinator.L(.noStressMode), isOn: $coordinator.noStressMode)
                .onChange(of: viewModel.options.noStressMode) { _, _ in viewModel.startNewGame() }
            Toggle(coordinator.L(.hideHintButton), isOn: $viewModel.options.hideHintButton)
            Toggle(coordinator.L(.honeyMode), isOn: $coordinator.honeyMode)
            Toggle(coordinator.L(.manuallyDismissBanners), isOn: $coordinator.manuallyDismissBanners)
        }
    }
}

// MARK: - Stats sheet

struct SpiderStatsSheet: View {
    @Bindable var viewModel: SpiderViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        NavigationStack {
            List {
                let stats = viewModel.currentModeStats
                row(coordinator.L(.gamesPlayed), "\(viewModel.gamesPlayed)")
                row(coordinator.L(.gamesWon), "\(viewModel.gamesWon)")
                row(coordinator.L(.highScore), viewModel.highScoreString)
                row(coordinator.L(.winRate), String(format: "%.0f%%", stats.winPercentage))
                row(coordinator.L(.currentStreak), "\(stats.currentStreak)")
                row(coordinator.L(.longestStreak), "\(stats.longestStreak)")
                row(coordinator.L(.statAverageWinTime), formatTime(Int(viewModel.averageWinningTime)))
                row(coordinator.L(.fastestWin), formatTime(viewModel.shortestWinTime))
            }
            .navigationTitle(coordinator.L(.spiderStatisticsFmt, viewModel.options.suitCount, viewModel.options.suitCount == 1 ? coordinator.L(.labelSuitSingular) : coordinator.L(.labelSuitPlural)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(coordinator.L(.done)) { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        if totalSeconds == 0 { return coordinator.L(.noTimePlaceholder) }
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}
