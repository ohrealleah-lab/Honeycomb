import Foundation
import Observation

@Observable
public final class BlackjackViewModel {
    public var options: BlackjackOptions {
        didSet {
            saveOptions()
            UISound.isEnabled = options.isSoundEnabled
        }
    }

    public var state: BlackjackState
    public var statistics: BlackjackStatistics {
        didSet { saveStatistics() }
    }

    // MARK: - Init

    public init() {
        self.state = BlackjackState()
        self.options = BlackjackOptions()
        self.statistics = BlackjackStatistics()

        if let data = UserDefaults.standard.data(forKey: "blackjack_options"),
           let decoded = try? JSONDecoder().decode(BlackjackOptions.self, from: data) {
            self.options = decoded
        } else {
            self.options = BlackjackOptions()
        }

        if let data = UserDefaults.standard.data(forKey: "blackjack_statistics"),
           let decoded = try? JSONDecoder().decode(BlackjackStatistics.self, from: data) {
            self.statistics = decoded
        }

        state.sessionCredits = options.startingCredits
        state.currentBet = 1

        UISound.isEnabled = self.options.isSoundEnabled
    }

    // MARK: - Persistence

    private func saveOptions() {
        if let data = try? JSONEncoder().encode(options) {
            UserDefaults.standard.set(data, forKey: "blackjack_options")
        }
    }

    private func saveStatistics() {
        if let data = try? JSONEncoder().encode(statistics) {
            UserDefaults.standard.set(data, forKey: "blackjack_statistics")
        }
    }

    // MARK: - Computed properties

    public var isFreePlay: Bool {
        options.noStressMode
    }

    // FIFO queue of banner texts (milestones, loading flavor) — mirrors the Honeycomb
    // port's bannerQueue/enqueueBanner/advanceBannerQueue.
    private var bannerQueue: [String] = []
    public var flashBanner: String? { bannerQueue.first }
    public var flashBannerTrigger: Int = 0

    private func enqueueBanner(_ text: String) {
        bannerQueue.append(text)
        if bannerQueue.count == 1 {
            flashBannerTrigger += 1
        }
    }

    // Fires the "out of credits" toast when sessionCredits is at/under the same <= 10
    // threshold canRebuy uses, and only after an outright round loss (not a win/push —
    // a split round can win one hand while losing another, or a double-down can win
    // back more than it cost, so being low on credits alone doesn't mean the player is
    // actually stuck). Public and called from the view, deliberately NOT from
    // evaluateAllHands() itself — the view times this call to fire once its own win/
    // lose result banner has finished its display+dismiss animation, so the toast reads
    // as landing alongside the Rebuy button rather than stacking on top of the result
    // banner while it's still up. 20% flavor ("Busy as a bee, broke as a beekeeper.") /
    // 80% the plain "Out of Credits!" toast, per the catalog entry's gate.
    public func checkOutOfCredits() {
        guard !isFreePlay, state.sessionCredits <= 10 else { return }
        let roundWon = state.playerHands.contains { $0.result == .win || $0.result == .blackjack }
        let roundLost = state.playerHands.contains { $0.result == .loss || $0.result == .bust }
        guard roundLost && !roundWon else { return }
        switch BannerCatalog.shared.fire(.gameplayPlayerRunsOutOfCreditsVideoPokerBlackjack) {
        case .message(let text): enqueueBanner(text)
        case .fallback, .none: enqueueBanner(L(.outOfCreditsToast, language: BannerCatalog.currentLanguage))
        }
    }

    public func advanceBannerQueue() {
        guard !bannerQueue.isEmpty else { return }
        bannerQueue.removeFirst()
        if !bannerQueue.isEmpty {
            flashBannerTrigger += 1
        }
    }

    // Fires once, exactly on crossing a threshold — checked against the value BEFORE
    // this round's wins were added, since a split round can win multiple hands at
    // once and jump straight past a threshold (e.g. 9 -> 11), skipping "== 10" entirely.
    private func checkWinMilestones(previousHandsWon: Int) {
        let thresholds: [(Int, BannerID)] = [
            (10, .milestonesPlayerReaches10TotalWins),
            (100, .milestonesPlayerReaches100TotalWins),
            (1000, .milestonesPlayerReaches1000TotalWins),
        ]
        for (threshold, id) in thresholds where previousHandsWon < threshold && statistics.handsWon >= threshold {
            if case .message(let text) = BannerCatalog.shared.fire(id) {
                enqueueBanner(text)
            }
        }
    }

    // Fires once per app session, the first time this game's view actually appears
    // (called from BlackjackView's .onAppear — a "loading" banner belongs to a
    // screen transition, not a gameplay action, so switching to this game for the
    // first time this session fires it; switching back to it later doesn't).
    private var hasFiredLoadingBannerThisSession = false

    public func checkLoadingBanner() {
        guard !hasFiredLoadingBannerThisSession else { return }
        hasFiredLoadingBannerThisSession = true
        if case .message(let text) = BannerCatalog.shared.fire(BannerCatalog.loadingBannerID()) {
            enqueueBanner(text)
        }
    }

    // Ambiance/Idle nudge: fires if a full minute passes with no action. Re-armed via a
    // generation-token so an already-scheduled check from before the last action sees a
    // mismatch and silently no-ops instead of firing late. Mirrors the Honeycomb port's
    // scheduleIdleCheck (shared/Honeycomb/ViewModels/HoneycombViewModel.swift) — called
    // from BlackjackView's .onChange(of: viewModel.state.phase) and from deal().
    private var idleCheckGeneration: Int = 0
    private static let idleToastDelay: TimeInterval = 60

    // Guards the delayed executeDealerTurn() closures (dealer/player blackjack auto-
    // resolve, split-aces auto-resolve) against the ABA problem a bare `state.phase ==
    // .playing` check can't catch on its own: startNewGame()/restartCurrentGame() don't
    // guard on phase, so a hand can be abandoned and a fresh one dealt (back to
    // .playing) within the ~1-1.5s delay — a stale closure would then resolve the wrong
    // hand since the phase alone matches again. Bumped alongside state resets the same
    // way Honeycomb/Klondike bump their own match generation counters.
    private var handGeneration: Int = 0

    public func scheduleIdleActionCheck() {
        idleCheckGeneration += 1
        let generation = idleCheckGeneration
        guard !UISound.isHeadlessMode else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.idleToastDelay) { [weak self] in
            guard let self, self.idleCheckGeneration == generation else { return }
            if case .message(let text) = BannerCatalog.shared.fire(.idleActionNoActionTakenForOneMinute) {
                self.enqueueBanner(text)
            }
        }
    }

    // Options can only be opened between hands — changing a setting like No Stress
    // Mode mid-hand would desync isFreePlay's live re-evaluation from what was
    // actually wagered when the hand started.
    public var canOpenOptions: Bool {
        state.phase == .betting || state.phase == .result
    }

    public var canSplit: Bool {
        state.playerHands.count == 1
        && state.playerHands[0].cards.count == 2
        && state.playerHands[0].cards[0].rank == state.playerHands[0].cards[1].rank
        && (isFreePlay || state.sessionCredits >= state.currentBet)
    }

    // True during the delay window deal() schedules between detecting a concealed dealer
    // blackjack (checked by raw rank, before the hole card is revealed) and actually
    // resolving it. state.phase is already .playing by that point — the player's own
    // cards need to render — so hit/stand/doubleDown/split must additionally check this,
    // or a player could act (and wager more) against a hand that's already decided.
    private var isDealerBlackjackPending: Bool {
        guard state.phase == .playing, state.dealerCards.count == 2 else { return false }
        let ranks = state.dealerCards.map { $0.rank }
        return ranks.contains(1) && ranks.contains { $0 >= 10 }
    }

    public var canDouble: Bool {
        guard state.activeHandIndex < state.playerHands.count else { return false }
        let hand = state.playerHands[state.activeHandIndex]
        return hand.cards.count == 2
            && !hand.isSplitAce
            && (9...11).contains(hand.value)
            && (isFreePlay || state.sessionCredits >= hand.bet)
    }

    public var canRebuy: Bool {
        !isFreePlay
            && (state.phase == .betting || state.phase == .result)
            && state.sessionCredits <= 10
    }

    public var activeHand: BlackjackHand? {
        guard state.activeHandIndex < state.playerHands.count else { return nil }
        return state.playerHands[state.activeHandIndex]
    }

    // MARK: - Deck helpers

    private func freshDeck() -> [Card] {
        var deck: [Card] = []
        for suit in Card.Suit.allCases {
            for rank in 1...13 {
                deck.append(Card(suit: suit, rank: rank, faceUp: true))
            }
        }
        deck.shuffle()
        return deck
    }

    private func popCard(faceUp: Bool = true) -> Card? {
        guard !state.deck.isEmpty else { return nil }
        var card = state.deck[state.deck.count - 1]
        state.deck.removeLast()
        card = Card(id: card.id, suit: card.suit, rank: card.rank, faceUp: faceUp)
        return card
    }

    // MARK: - Game flow

    public func deal() {
        guard state.phase == .betting || state.phase == .result else { return }
        guard isFreePlay || state.sessionCredits >= state.currentBet else { return }

        // statistics.handsPlayed only grows via the increment below, so checking it
        // here, before that increment, is this game's equivalent of "is this the very
        // first hand ever."
        if statistics.handsPlayed == 0, case .message(let text) = BannerCatalog.shared.fire(.milestonesFirstLaunchEver) {
            enqueueBanner(text)
        }

        if !isFreePlay {
            state.sessionCredits -= state.currentBet
            statistics.totalWagered += state.currentBet
        }
        // Counted here (and again in split()) rather than at resolution time, so it
        // stays in lockstep with totalWagered even if the hand is abandoned mid-play
        // (e.g. New Game/Restart) before evaluateAllHands() ever runs.
        statistics.handsPlayed += 1
        state.handsDealt += 1

        state.deck = freshDeck()
        playSound(named: "shuffle")

        // Deal: player card, dealer card, player card, dealer hole card (face-down)
        guard let p1 = popCard(faceUp: true),
              let d1 = popCard(faceUp: true),
              let p2 = popCard(faceUp: true),
              let d2 = popCard(faceUp: false) else { return }

        state.playerHands = [BlackjackHand(cards: [p1, p2], bet: state.currentBet)]
        state.dealerCards = [d1, d2]
        state.activeHandIndex = 0
        state.resultOutcome = .none
        state.phase = .playing
        scheduleIdleActionCheck()

        // Dealer blackjack ends the hand immediately — checked here by raw rank
        // (ignoring the hole card's face-down state) rather than waiting for it to be
        // revealed, so the player can never act (Hit/Stand/Double/Split) against a
        // hidden dealer natural. Matches the Windows port's peek timing. Still delayed
        // a beat before resolving (unlike a bare synchronous call) so the player sees
        // their own cards land before the hand auto-completes out from under them.
        let dealerRanks = state.dealerCards.map { $0.rank }
        let dealerHasBlackjack = dealerRanks.count == 2 && dealerRanks.contains(1) && dealerRanks.contains { $0 >= 10 }
        let generation = handGeneration
        if dealerHasBlackjack {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self, self.handGeneration == generation else { return }
                self.executeDealerTurn()
            }
            return
        }

        // Check for player blackjack — delay so the player can see their cards first
        if state.playerHands[0].isBlackjack {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self, self.handGeneration == generation else { return }
                self.executeDealerTurn()
            }
        }
    }

    public func hit() {
        guard state.phase == .playing else { return }
        guard !isDealerBlackjackPending else { return }
        guard state.activeHandIndex < state.playerHands.count else { return }
        guard !(state.playerHands.count == 1 && state.playerHands[0].isBlackjack) else { return }
        guard !state.playerHands[state.activeHandIndex].isSplitAce else { return }
        guard let card = popCard(faceUp: true) else { return }

        playSound(named: "snap")
        state.playerHands[state.activeHandIndex].cards.append(card)

        // Auto-advance on any multi-card 21, not just a bust — matches the Windows port,
        // which doesn't make the player manually Stand once no further Hit could help.
        let hand = state.playerHands[state.activeHandIndex]
        if hand.isBust || hand.value == 21 {
            advanceHand()
        }
    }

    public func stand() {
        guard state.phase == .playing else { return }
        guard !isDealerBlackjackPending else { return }
        guard state.activeHandIndex < state.playerHands.count else { return }
        guard !(state.playerHands.count == 1 && state.playerHands[0].isBlackjack) else { return }
        guard !state.playerHands[state.activeHandIndex].isSplitAce else { return }
        advanceHand()
    }

    public func doubleDown() {
        guard state.phase == .playing else { return }
        guard !isDealerBlackjackPending else { return }
        guard canDouble else { return }
        guard !(state.playerHands.count == 1 && state.playerHands[0].isBlackjack) else { return }
        let hand = state.playerHands[state.activeHandIndex]
        if !isFreePlay {
            state.sessionCredits -= hand.bet
            statistics.totalWagered += hand.bet
        }
        state.playerHands[state.activeHandIndex].bet *= 2
        state.playerHands[state.activeHandIndex].isDoubled = true

        if let card = popCard(faceUp: true) {
            playSound(named: "snap")
            state.playerHands[state.activeHandIndex].cards.append(card)
        }
        advanceHand()
    }

    public func split() {
        guard state.phase == .playing, canSplit else { return }
        guard !isDealerBlackjackPending else { return }
        guard !(state.playerHands.count == 1 && state.playerHands[0].isBlackjack) else { return }
        let originalBet = state.playerHands[0].bet
        if !isFreePlay {
            state.sessionCredits -= originalBet
            statistics.totalWagered += originalBet
        }
        // A split creates a second wagered hand, so it counts as an additional
        // "hand played" alongside the one already counted in deal().
        statistics.handsPlayed += 1

        let card0 = state.playerHands[0].cards[0]
        let card1 = state.playerHands[0].cards[1]
        let isAces = card0.rank == 1

        // Draw a second card for each split hand
        let extra0 = popCard(faceUp: true) ?? card0
        let extra1 = popCard(faceUp: true) ?? card1

        var hand0 = BlackjackHand(cards: [card0, extra0], bet: originalBet)
        var hand1 = BlackjackHand(cards: [card1, extra1], bet: originalBet)
        hand0.isSplitAce = isAces
        hand1.isSplitAce = isAces

        state.playerHands = [hand0, hand1]
        state.activeHandIndex = 0
        playSound(named: "snap")

        // Split Aces: each hand gets exactly the one card just dealt, then must stand.
        // Delay the auto-resolve so the player has a moment to see both hands' cards
        // before the round jumps to the dealer's turn.
        if isAces {
            let generation = handGeneration
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self, self.handGeneration == generation else { return }
                self.executeDealerTurn()
            }
        } else if state.playerHands[state.activeHandIndex].value == 21 {
            // The freshly dealt second card already completes this hand — matches the
            // Windows port, which doesn't wait for a manual Stand once no Hit could help.
            advanceHand()
        }
    }

    public func addToBet(_ amount: Int) {
        guard state.phase == .betting || state.phase == .result else { return }
        if amount != 1 && state.currentBet == 1 {
            state.currentBet = max(1, min(amount, state.sessionCredits))
        } else {
            state.currentBet = max(1, min(state.currentBet + amount, state.sessionCredits))
        }
    }

    public func doubleBet() {
        guard state.phase == .betting || state.phase == .result else { return }
        state.currentBet = max(1, min(state.currentBet * 2, state.sessionCredits))
    }

    public func clearBet() {
        guard state.phase == .betting || state.phase == .result else { return }
        state.currentBet = 1
    }

    public func rebuy() {
        state.sessionCredits += options.startingCredits
        statistics.rebuyCount += 1
    }

    private func advanceHand() {
        let next = state.activeHandIndex + 1
        if next < state.playerHands.count {
            state.activeHandIndex = next
            // A split hand can already be complete the moment it's dealt (e.g. drew to a
            // made 21) without ever going through hit()/doubleDown()'s own auto-advance —
            // recurse past it instead of leaving it sitting active with Hit/Stand enabled.
            if state.playerHands[next].isComplete {
                advanceHand()
            }
        } else {
            executeDealerTurn()
        }
    }

    public func executeDealerTurn() {
        guard state.phase == .playing else { return }
        state.phase = .dealerTurn

        // Reveal hole card
        if state.dealerCards.indices.contains(1) {
            let c = state.dealerCards[1]
            state.dealerCards[1] = Card(id: c.id, suit: c.suit, rank: c.rank, faceUp: true)
        }

        // Dealer hits until 17+
        while BlackjackState.handValue(state.dealerCards) < 17 {
            if let card = popCard(faceUp: true) {
                state.dealerCards.append(card)
                playSound(named: "snap")
            } else { break }
        }

        evaluateAllHands()
        state.phase = .result

        // Keep the bet at its last wagered amount for the next hand if still affordable,
        // otherwise fall back to the 1 credit minimum. Skipped in free play, where
        // sessionCredits never changes and comparing against it would otherwise reset
        // the player's bet after every single hand.
        if !isFreePlay && state.currentBet > state.sessionCredits {
            state.currentBet = 1
        }
    }

    private func evaluateAllHands() {
        let dealerValue = BlackjackState.handValue(state.dealerCards)
        let dealerBJ = state.dealerCards.count == 2 && dealerValue == 21
        var totalPayout = 0
        var totalWagered = 0
        // Captured before the per-hand loop below (which can win multiple split
        // hands in one round) so checkWinMilestones can catch a threshold crossed
        // partway through, not just landed on exactly.
        let previousHandsWon = statistics.handsWon

        for i in 0..<state.playerHands.count {
            let hand = state.playerHands[i]
            totalWagered += hand.bet
            let playerValue = hand.value
            let playerBJ = hand.isBlackjack && state.playerHands.count == 1  // BJ only counts on unsplit hand

            let result: BlackjackHandResult
            var payout = 0

            if playerBJ && dealerBJ {
                // Both have blackjack — push
                result = .push
                payout = hand.bet
                statistics.pushes += 1
            } else if playerBJ {
                // Blackjack pays 3:1 (bet returned + 3x bet profit) — always a whole
                // number for any bet, unlike the old 3:2 payout, which truncated
                // unfairly on odd bets.
                result = .blackjack
                payout = hand.bet * 4
                statistics.blackjacks += 1
                statistics.handsWon += 1
                playSound(named: "victory")
            } else if hand.isBust {
                result = .bust
                statistics.handsLost += 1
            } else if dealerBJ || (!hand.isBust && dealerValue > playerValue && dealerValue <= 21) {
                result = .loss
                statistics.handsLost += 1
            } else if dealerValue > 21 || playerValue > dealerValue {
                result = .win
                payout = hand.bet * 2
                statistics.handsWon += 1
                if totalPayout == 0 { playSound(named: "victory") }
            } else {
                result = .push
                payout = hand.bet  // return original bet
                statistics.pushes += 1
            }

            state.playerHands[i].result = result
            totalPayout += payout
            if !isFreePlay {
                state.sessionCredits += payout
                statistics.totalPaidOut += payout
                // Excludes pushes — a push is a returned stake, not a winning payout, so
                // it shouldn't count toward "Biggest Pay".
                if result != .push {
                    statistics.biggestPayout = max(statistics.biggestPayout, payout)
                }
            }
        }

        state.lastNetResult = totalPayout - totalWagered

        // Only the aggregate outcome is stored — display text (including the per-hand
        // breakdown for a split round) is derived live from this + playerHands/
        // lastNetResult by localizedBlackjackResult(_:language:), so it can't go stale
        // if the language changes while the result banner is still showing.
        let anyBJ = state.playerHands.contains { $0.result == .blackjack }
        let anyWin = state.playerHands.contains { $0.result == .win || $0.result == .blackjack }
        let allPush = !state.playerHands.isEmpty && state.playerHands.allSatisfy { $0.result == .push }
        let playerBust = !state.playerHands.isEmpty && state.playerHands.allSatisfy { $0.isBust }

        if anyBJ {
            state.resultOutcome = .blackjack
        } else if anyWin {
            state.resultOutcome = .win
        } else if allPush {
            state.resultOutcome = .push
        } else if playerBust {
            state.resultOutcome = .bust
        } else {
            state.resultOutcome = .loss
        }

        let roundWon = state.playerHands.contains { $0.result == .win || $0.result == .blackjack }
        let roundLost = state.playerHands.contains { $0.result == .loss || $0.result == .bust }
        if roundWon && !roundLost {
            statistics.currentStreak += 1
            statistics.longestStreak = max(statistics.longestStreak, statistics.currentStreak)
        } else if roundLost {
            statistics.currentStreak = 0
        }
        checkWinMilestones(previousHandsWon: previousHandsWon)
    }


    // MARK: - Sound

    public func playSound(named name: String) {
        UISound.play(named: name, enabled: options.isSoundEnabled, respectHeadlessMode: true)
    }

    // Clears a finished round's cards/result before the game becomes visible again,
    // so switching away while its win/lose banner is still up and back doesn't replay
    // it — AppRouterView recreates the view on every mode switch (`.id()`), so it has
    // no memory of already having shown the banner. Credits/bet are untouched; only
    // deal() (.betting/.result) can reach here, so there's never a hand in progress
    // to lose.
    public func resetIfRoundOver() {
        guard state.phase == .result else { return }
        state.playerHands = []
        state.activeHandIndex = 0
        state.dealerCards = []
        state.resultOutcome = .none
        state.lastNetResult = 0
        state.phase = .betting
    }

    // MARK: - Statistics / AppCoordinator stubs

    public func resetStatistics() {
        statistics = BlackjackStatistics()
    }

    public var debugBannerRequest: DebugBannerKind? = nil

    public func debugSetupBannerState(_ kind: DebugBannerKind) {
        switch kind {
        case .win:
            var hand = BlackjackHand(
                cards: [Card(suit: .hearts, rank: 10, faceUp: true),
                        Card(suit: .spades, rank: 10, faceUp: true)],
                bet: 50)
            hand.result = .win
            state.playerHands = [hand]
            state.dealerCards  = [Card(suit: .diamonds, rank: 9, faceUp: true),
                                  Card(suit: .clubs,    rank: 8, faceUp: true)]
            state.lastNetResult    = 100
            state.resultOutcome = .win
        case .loss:
            var hand = BlackjackHand(
                cards: [Card(suit: .hearts, rank: 8, faceUp: true),
                        Card(suit: .spades, rank: 7, faceUp: true)],
                bet: 50)
            hand.result = .loss
            state.playerHands = [hand]
            state.dealerCards  = [Card(suit: .diamonds, rank: 10, faceUp: true),
                                  Card(suit: .clubs,    rank: 10, faceUp: true)]
            state.lastNetResult    = -50
            state.resultOutcome = .loss
        default: break
        }
    }

    public func startNewGame() {
        handGeneration += 1
        state = BlackjackState()
        state.sessionCredits = options.startingCredits
        state.currentBet = 1
        statistics.currentStreak = 0
    }

    public func restartCurrentGame() {
        handGeneration += 1
        state = BlackjackState()
        state.sessionCredits = options.startingCredits
        state.currentBet = 1
        // streak preserved — restart replays the same session
    }
    public func undoLastAction() {}
    public var canUndo: Bool { false }

    // Board scale — no longer manual; BlackjackView.recomputeScale() continuously derives
    // this from the window's current size. Not persisted, purely a function of window size.
    public var zoomScale: CGFloat = 1.0
}
