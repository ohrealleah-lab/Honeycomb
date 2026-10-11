import Foundation

// Desktop Video Poker and Blackjack round flow on fixed hands/decks: bets and credits,
// payouts, the dealer's rules, split/double, free play (No Stress), rebuy and the
// out-of-credits toast, streaks, and what survives a relaunch. (Mobile is betting-free by
// design; these suites run on the Mac build where betting exists.)
struct VideoPokerGameplayTests {
    static let defaultsKeys = ["videopoker_options", "videopoker_statistics"]

    static func run() {
        UISound.isHeadlessMode = true
        func isolated(_ test: () -> Void) { withCleanDefaults(defaultsKeys, test) }
        isolated(testDealChargesBetAndShowsFiveCards)
        isolated(testHoldingDrawingAndPayouts)
        isolated(testLosingHandsEndTheStreak)
        isolated(testBetControls)
        isolated(testFreePlayIsLockedForTheHand)
        isolated(testRebuyAndOutOfCreditsToast)
        isolated(testNewGameResetsSessionAndAbandonedHandBreaksStreak)
        isolated(testBannersAndMilestones)
        isolated(testOptionsAndStatsPersistence)
        isolated(testPayTablesPerVariant)
    }

    static func card(_ suit: Card.Suit, _ rank: Int) -> Card { CovCards.card(suit, rank) }

    /// A dealt hand: runs the real deal() (so credits/stats are charged), then swaps in known cards.
    static func dealt(_ vm: VideoPokerViewModel, hand: [Card], deck: [Card]) {
        vm.deal()
        vm.state.hand = hand
        vm.state.deck = deck
    }

    static func drain(_ vm: VideoPokerViewModel) -> Int {
        var n = 0
        while vm.flashBanner != nil { n += 1; vm.advanceBannerQueue(); if n > 50 { break } }
        return n
    }

    static func testDealChargesBetAndShowsFiveCards() {
        let vm = VideoPokerViewModel()
        expect(vm.state.sessionCredits == 100 && vm.state.currentBet == 1 && vm.state.phase == .deal && !vm.isFreePlay,
               "Fresh session: 100 credits, bet 1, waiting to deal")
        vm.state.currentBet = 3
        expect(vm.totalBet == 3, "Single play stakes the bet once")
        vm.deal()
        expect(vm.state.phase == .holding && vm.state.hand.count == 5 && vm.state.deck.count == 47, "Deal: 5 cards, 47 left in the deck")
        expect(vm.state.hand.allSatisfy { $0.faceUp } && vm.state.heldIndices.isEmpty, "Cards face up, nothing held")
        expect(Set((vm.state.hand + vm.state.deck).map { "\($0.suit.rawValue)\($0.rank)" }).count == 52, "A full 52-card deck, no duplicates")
        expect(vm.state.sessionCredits == 97 && vm.statistics.totalWagered == 3 && vm.statistics.handsPlayed == 1 && vm.state.handsDealt == 1,
               "Bet of 3 deducted and counted")
        let hand = vm.state.hand
        vm.deal()
        expect(vm.state.hand == hand && vm.state.sessionCredits == 97, "Dealing again mid-hand does nothing")
        expect(!vm.canOpenOptions, "Options are locked mid-hand")

        // Can't deal without enough credits.
        let broke = VideoPokerViewModel()
        broke.state.sessionCredits = 2
        broke.state.currentBet = 3
        let handsBefore = broke.statistics.handsPlayed
        broke.deal()
        expect(broke.state.phase == .deal && broke.state.sessionCredits == 2 && broke.statistics.handsPlayed == handsBefore, "Not enough credits: no deal")
        expect(broke.canOpenOptions, "Options open between hands")
    }

    static func testHoldingDrawingAndPayouts() {
        let vm = VideoPokerViewModel()
        vm.state.currentBet = 3
        dealt(vm, hand: [card(.hearts, 11), card(.spades, 11), card(.clubs, 2), card(.diamonds, 5), card(.clubs, 9)],
              deck: [card(.clubs, 13), card(.hearts, 3), card(.diamonds, 8), card(.spades, 4)])
        vm.toggleHold(at: 0); vm.toggleHold(at: 1); vm.toggleHold(at: 4)
        expect(vm.state.heldIndices == [0, 1, 4], "Three cards held")
        vm.toggleHold(at: 4)
        expect(vm.state.heldIndices == [0, 1], "Tapping a held card releases it")
        vm.toggleHold(at: 7)
        expect(vm.state.heldIndices == [0, 1], "An out-of-range hold is ignored")
        vm.draw()
        expect(vm.state.hand.map { $0.rank } == [11, 11, 13, 3, 8], "Unheld cards are replaced from the top of the deck, held ones kept")
        expect(vm.state.phase == .result && vm.state.lastHandName == "Jacks or Better", "Pair of jacks: Jacks or Better (\(vm.state.lastHandName))")
        expect(vm.state.lastPayout == 3 && vm.state.sessionCredits == 100, "Pays 1× the 3-coin bet: 97 + 3 = 100")
        expect(vm.statistics.handsWon == 1 && vm.statistics.currentStreak == 1 && vm.statistics.totalPaidOut == 3 && vm.statistics.biggestPayout == 3,
               "Win stats recorded")
        vm.toggleHold(at: 2)
        expect(vm.state.heldIndices == [0, 1], "Holds can't change after the draw")
        vm.draw()
        expect(vm.state.sessionCredits == 100, "Drawing twice pays nothing extra")

        // Two pair at 2 coins pays 2 × 2.
        let tp = VideoPokerViewModel()
        tp.state.currentBet = 2
        dealt(tp, hand: [card(.hearts, 5), card(.spades, 5), card(.clubs, 9), card(.diamonds, 9), card(.clubs, 2)], deck: [card(.hearts, 13)])
        tp.state.heldIndices = [0, 1, 2, 3]
        tp.draw()
        expect(tp.state.lastHandName == "Two Pair" && tp.state.lastPayout == 4, "Two Pair pays 2× at 2 coins (got \(tp.state.lastPayout))")

        // A natural royal at max bet pays the 4000 jackpot and is counted.
        let royal = VideoPokerViewModel()
        royal.state.currentBet = 5
        dealt(royal, hand: [card(.hearts, 1), card(.hearts, 13), card(.hearts, 12), card(.hearts, 11), card(.hearts, 10)], deck: [])
        royal.state.heldIndices = [0, 1, 2, 3, 4]
        royal.draw()
        expect(royal.state.lastHandName == "Royal Flush" && royal.state.lastPayout == 4000 && royal.statistics.royalFlushCount == 1,
               "Royal flush at 5 coins pays 4000 (got \(royal.state.lastPayout))")
        expect(royal.state.sessionCredits == 95 + 4000 && royal.statistics.biggestPayout == 4000, "Credited and recorded as the biggest payout")

        // Drawing before a deal does nothing.
        let idle = VideoPokerViewModel()
        idle.draw()
        expect(idle.state.phase == .deal, "No draw without a deal")
    }

    static func testLosingHandsEndTheStreak() {
        let vm = VideoPokerViewModel()
        func play(_ hand: [Card]) {
            dealt(vm, hand: hand, deck: [])
            vm.state.heldIndices = [0, 1, 2, 3, 4]
            vm.draw()
        }
        play([card(.hearts, 11), card(.spades, 11), card(.clubs, 2), card(.diamonds, 5), card(.clubs, 9)])
        play([card(.hearts, 12), card(.spades, 12), card(.clubs, 2), card(.diamonds, 5), card(.clubs, 9)])
        expect(vm.statistics.currentStreak == 2 && vm.statistics.longestStreak == 2, "Two wins in a row")
        play([card(.hearts, 10), card(.spades, 10), card(.clubs, 2), card(.diamonds, 5), card(.clubs, 9)])
        expect(vm.state.lastHandName == "No Win" && vm.state.lastPayout == 0, "A pair of tens doesn't pay")
        expect(vm.statistics.currentStreak == 0 && vm.statistics.longestStreak == 2, "A losing hand ends the streak but keeps the best")
        expect(vm.state.sessionCredits == 100 - 3 + 2, "Credits: three 1-coin bets, two 1-coin wins (got \(vm.state.sessionCredits))")
        expect(vm.statistics.handsPlayed == 3 && vm.statistics.handsWon == 2, "Counts")
        expect(abs(vm.statistics.winRate - 2.0 / 3.0) < 1e-9 && abs(vm.statistics.returnToPlayer - 2.0 / 3.0) < 1e-9, "Win rate and return to player")
        expect(VideoPokerStatistics().winRate == 0 && VideoPokerStatistics().returnToPlayer == 0, "Empty stats are safe")
    }

    static func testBetControls() {
        let vm = VideoPokerViewModel()
        vm.decreaseBet()
        expect(vm.state.currentBet == 1, "Bet never goes below 1")
        for _ in 0..<7 { vm.increaseBet() }
        expect(vm.state.currentBet == 5, "Bet tops out at 5")
        vm.decreaseBet()
        expect(vm.state.currentBet == 4, "Decrease works")

        vm.maxBet()
        expect(vm.state.currentBet == 5 && vm.state.phase == .holding && vm.state.sessionCredits == 95, "Max Bet sets 5 and deals straight away")
        vm.increaseBet()
        expect(vm.state.currentBet == 5, "Bet can't change mid-hand")
        vm.decreaseBet()
        expect(vm.state.currentBet == 5, "...in either direction")
        vm.state.heldIndices = []
        vm.draw()

        let poor = VideoPokerViewModel()
        poor.state.sessionCredits = 3
        poor.maxBet()
        expect(poor.state.currentBet == 3 && poor.state.sessionCredits == 0, "Max Bet is limited by the credits you have")
        let none = VideoPokerViewModel()
        none.state.sessionCredits = 0
        none.maxBet()
        expect(none.state.phase == .deal, "No credits: Max Bet can't deal")
    }

    static func testFreePlayIsLockedForTheHand() {
        // Dealt free (No Stress on), then paid mode switched on: still free for that hand.
        let free = VideoPokerViewModel()
        free.sharedOptions.noStressMode = true
        expect(free.isFreePlay, "No Stress Mode makes Video Poker free play")
        free.state.sessionCredits = 0
        free.deal()
        expect(free.state.phase == .holding && free.state.sessionCredits == 0 && free.statistics.totalWagered == 0, "Free play deals with zero credits and charges nothing")
        free.state.hand = [card(.hearts, 1), card(.hearts, 13), card(.hearts, 12), card(.hearts, 11), card(.hearts, 10)]
        free.sharedOptions.noStressMode = false
        expect(free.isFreePlay, "Mid-hand, the hand stays free even though No Stress is now off")
        free.state.heldIndices = [0, 1, 2, 3, 4]
        free.draw()
        expect(free.state.sessionCredits == 0 && free.statistics.totalPaidOut == 0, "...so the royal flush pays no credits")
        expect(free.statistics.handsWon == 1 && free.statistics.royalFlushCount == 1, "...but still counts as a win")
        expect(!free.isFreePlay, "After the hand, the live setting applies again")

        // Dealt for credits, then No Stress switched on: that hand still pays out.
        let paid = VideoPokerViewModel()
        paid.deal()
        paid.state.hand = [card(.hearts, 11), card(.spades, 11), card(.clubs, 2), card(.diamonds, 5), card(.clubs, 9)]
        paid.sharedOptions.noStressMode = true
        paid.state.heldIndices = [0, 1, 2, 3, 4]
        paid.draw()
        expect(paid.state.sessionCredits == 100, "A hand bought with credits pays credits even if No Stress was switched on mid-hand")
        expect(!paid.canRebuy, "No rebuy in free play")
    }

    static func testRebuyAndOutOfCreditsToast() {
        let vm = VideoPokerViewModel()
        vm.state.sessionCredits = 50
        expect(!vm.canRebuy, "Plenty of credits: no rebuy")
        vm.state.sessionCredits = 10
        expect(vm.canRebuy, "At 10 credits or fewer a rebuy is offered")
        vm.rebuy()
        expect(vm.state.sessionCredits == 110 && vm.statistics.rebuyCount == 1, "Rebuy adds the starting credits")
        vm.rebuy()
        expect(vm.state.sessionCredits == 110 && vm.statistics.rebuyCount == 1, "A double-tap can't rebuy twice")

        vm.state.sessionCredits = 5
        vm.deal()
        expect(!vm.canRebuy, "No rebuy mid-hand")
        vm.state.heldIndices = []
        vm.state.hand = [card(.hearts, 2), card(.spades, 5), card(.diamonds, 9), card(.clubs, 3), card(.hearts, 7)]
        vm.state.deck = [card(.clubs, 8), card(.spades, 13), card(.diamonds, 4), card(.hearts, 6), card(.clubs, 10)]
        vm.draw()
        expect(vm.state.lastPayout == 0 && vm.state.sessionCredits == 4, "Lost the hand: 4 credits left")
        expect(vm.canRebuy, "Rebuy offered once the hand is over")

        // Out-of-credits toast: only after a loss, at ≤ 10 credits, in paid play.
        _ = drain(vm)
        vm.checkOutOfCredits()
        expect(vm.flashBanner != nil, "Low on credits after a losing hand → toast")
        _ = drain(vm)
        vm.state.sessionCredits = 11
        vm.checkOutOfCredits()
        expect(vm.flashBanner == nil, "More than 10 credits → no toast")
        vm.state.sessionCredits = 4
        vm.state.lastPayout = 5
        vm.checkOutOfCredits()
        expect(vm.flashBanner == nil, "A winning hand doesn't trigger the toast even when low")
        vm.state.lastPayout = 0
        vm.sharedOptions.noStressMode = true
        vm.checkOutOfCredits()
        expect(vm.flashBanner == nil, "Free play never shows the toast")
    }

    static func testNewGameResetsSessionAndAbandonedHandBreaksStreak() {
        let vm = VideoPokerViewModel()
        var opts = vm.options
        opts.startingCredits = 250
        opts.betPerHand = 2
        vm.options = opts
        vm.startNewGame()
        expect(vm.state.sessionCredits == 250 && vm.state.currentBet == 2 && vm.state.phase == .deal, "New game restores the chosen starting credits and bet")

        var s = vm.statistics; s.currentStreak = 4; s.longestStreak = 4; vm.statistics = s
        vm.startNewGame()
        expect(vm.statistics.currentStreak == 4, "New game between hands keeps the streak")
        vm.deal()
        expect(vm.state.phase == .holding, "Dealt")
        vm.startNewGame()
        expect(vm.statistics.currentStreak == 0 && vm.statistics.longestStreak == 4, "Abandoning a dealt-but-undrawn hand breaks the streak")

        // Hand display reset after a result.
        vm.deal()
        vm.state.heldIndices = [0]
        vm.draw()
        expect(vm.state.phase == .result, "Result showing")
        vm.resetIfRoundOver()
        expect(vm.state.phase == .deal && vm.state.hand.isEmpty && vm.state.lastPayout == 0 && vm.state.lastHandName.isEmpty,
               "Leaving and re-entering clears a finished round")
        vm.resetIfRoundOver()
        expect(vm.state.phase == .deal, "Harmless when there's nothing to reset")
        vm.restartCurrentGame()
        expect(vm.state.sessionCredits == 250, "Restart behaves like New Game")
        expect(!vm.canUndo, "No undo in Video Poker")
        vm.undoLastAction()
        vm.debugSetupBannerState(.win)
        expect(vm.state.lastHandName == "Royal Flush", "Debug hook sets up a win display")
        vm.debugSetupBannerState(.loss)
        expect(vm.state.lastHandName == "No Win", "...and a loss display")
    }

    static func testBannersAndMilestones() {
        let vm = VideoPokerViewModel()
        expect(drain(vm) == 0, "Nothing queued before the first hand")
        vm.deal()
        expect(drain(vm) == 1, "The very first hand shows the welcome banner")
        vm.state.phase = .deal
        vm.deal()
        expect(drain(vm) == 0, "...only once")
        vm.checkLoadingBanner(); _ = drain(vm)
        vm.checkLoadingBanner()
        expect(drain(vm) == 0, "Loading banner once per session")

        // The 10th winning hand shows the milestone, exactly once.
        var s = vm.statistics; s.handsWon = 9; vm.statistics = s
        vm.state.phase = .holding
        vm.state.hand = [card(.hearts, 11), card(.spades, 11), card(.clubs, 2), card(.diamonds, 5), card(.clubs, 9)]
        vm.state.heldIndices = [0, 1, 2, 3, 4]
        vm.draw()
        expect(vm.flashBanner != nil, "10th win → milestone banner")
        let t = vm.flashBannerTrigger
        vm.replayCurrentBanner()
        expect(vm.flashBannerTrigger == t + 1, "Replayed when the board comes back")
        expect(drain(vm) == 1, "One banner")
        vm.state.phase = .holding
        vm.state.hand = [card(.hearts, 11), card(.spades, 11), card(.clubs, 2), card(.diamonds, 5), card(.clubs, 9)]
        vm.state.heldIndices = [0, 1, 2, 3, 4]
        vm.draw()
        expect(drain(vm) == 0, "11th win doesn't repeat it")
        vm.scheduleIdleActionCheck(); vm.cancelIdleActionCheck()
    }

    static func testOptionsAndStatsPersistence() {
        let vm = VideoPokerViewModel()
        var o = vm.options
        o.variant = .bonusPoker; o.startingCredits = 500; o.betPerHand = 4
        vm.options = o
        var s = vm.statistics; s.handsWon = 12; s.biggestPayout = 800; vm.statistics = s
        let again = VideoPokerViewModel()
        expect(again.options.variant == .bonusPoker && again.options.startingCredits == 500 && again.options.betPerHand == 4, "Options survive a relaunch")
        expect(again.state.sessionCredits == 500 && again.state.currentBet == 4, "...and seed the session")
        expect(again.statistics.handsWon == 12 && again.statistics.biggestPayout == 800, "Stats survive a relaunch")
        again.resetStatistics()
        expect(again.statistics.handsWon == 0 && VideoPokerViewModel().statistics.handsWon == 0, "Reset Stats clears and persists")

        // Old saves: missing fields default; Triple Play (hidden) is forced back to Single Play.
        UserDefaults.standard.set(Data("{\"variant\":\"Deuces Wild\",\"playMode\":\"Triple Play\"}".utf8), forKey: "videopoker_options")
        let old = VideoPokerViewModel()
        expect(old.options.variant == .deucesWild && old.options.startingCredits == 100 && old.options.betPerHand == 1, "Missing fields take defaults")
        expect(old.options.playMode == .single, "A saved Triple Play falls back to Single Play while it's hidden")
        UserDefaults.standard.set(Data("not json".utf8), forKey: "videopoker_options")
        UserDefaults.standard.set(Data("{\"handsWon\":3}".utf8), forKey: "videopoker_statistics")
        let broken = VideoPokerViewModel()
        expect(broken.options == VideoPokerOptions() && broken.statistics.handsWon == 3 && broken.statistics.longestStreak == 0,
               "Unreadable options fall back; sparse stats keep what they have")
    }

    static func testPayTablesPerVariant() {
        let vm = VideoPokerViewModel()
        expect(vm.payTable.count == 9 && vm.payTable.first?.handName == "Royal Flush", "Jacks or Better has 9 rows")
        expect(VideoPokerViewModel.payTable(for: .deucesWild).count == 10 && VideoPokerViewModel.payTable(for: .deucesWild).first?.handName == "Natural Royal Flush",
               "Deuces Wild has 10 rows")
        expect(VideoPokerViewModel.payTable(for: .bonusPoker).count == 11, "Bonus Poker has 11 rows")
        // Bonus Poker pays 80× for four aces; Deuces Wild pays 200× for four deuces.
        let bonus = VideoPokerViewModel.scoreHand([card(.hearts, 1), card(.spades, 1), card(.clubs, 1), card(.diamonds, 1), card(.clubs, 9)], variant: .bonusPoker, bet: 2)
        expect(bonus.name == "Four Aces" && bonus.payout == 160, "Four aces in Bonus Poker: 80 × 2 (got \(bonus.name) \(bonus.payout))")
        let deuces = VideoPokerViewModel.scoreHand([card(.hearts, 2), card(.spades, 2), card(.clubs, 2), card(.diamonds, 2), card(.clubs, 9)], variant: .deucesWild, bet: 1)
        expect(deuces.name == "Four Deuces" && deuces.payout == 200, "Four deuces: 200 (got \(deuces.name) \(deuces.payout))")
        let junk = VideoPokerViewModel.scoreHand([card(.hearts, 2)], variant: .jacksOrBetter, bet: 1)
        expect(junk.name == "No Win" && junk.payout == 0, "A hand that isn't five cards scores nothing")
    }
}

struct BlackjackGameplayTests {
    static let defaultsKeys = ["blackjack_options", "blackjack_statistics"]

    static func run() {
        UISound.isHeadlessMode = true
        func isolated(_ test: () -> Void) { withCleanDefaults(defaultsKeys, test) }
        isolated(testDealSetsUpTheRound)
        isolated(testPayoutsForWinLossPush)
        isolated(testDealerRules)
        isolated(testNaturalsPayThreeToOneAndOnlyOnUnsplitHands)
        isolated(testDoubleDown)
        isolated(testSplitRules)
        isolated(testSplitAces)
        isolated(testHitStandAndAutoAdvance)
        isolated(testFreePlayIsLockedForTheHand)
        isolated(testBetsRebuyAndOutOfCreditsToast)
        isolated(testResultTextAndSessionReset)
        isolated(testBannersMilestonesAndPersistence)
    }

    static func card(_ suit: Card.Suit, _ rank: Int, up: Bool = true) -> Card { CovCards.card(suit, rank, up: up) }

    /// A table with a clean slate: view models load whatever the previous one saved, which would
    /// leak stats (and No Stress Mode) from one scenario into the next.
    static func fresh() -> BlackjackViewModel {
        for key in defaultsKeys + sharedGameOptionKeys { UserDefaults.standard.removeObject(forKey: key) }
        return BlackjackViewModel()
    }

    /// A round already in progress (bet deducted, as after deal()): `deck`'s LAST card is dealt next.
    static func round(_ vm: BlackjackViewModel, player: [[Card]], dealer: [Card], deck: [Card] = [], bet: Int = 10, credits: Int = 90) {
        vm.state.phase = .playing
        vm.state.sessionCredits = credits
        vm.state.currentBet = bet
        vm.state.playerHands = player.map { BlackjackHand(cards: $0, bet: bet) }
        vm.state.dealerCards = dealer
        vm.state.deck = deck
        vm.state.activeHandIndex = 0
        vm.state.resultOutcome = .none
    }

    static func drain(_ vm: BlackjackViewModel) -> Int {
        var n = 0
        while vm.flashBanner != nil { n += 1; vm.advanceBannerQueue(); if n > 50 { break } }
        return n
    }

    static func testDealSetsUpTheRound() {
        let vm = BlackjackViewModel()
        expect(vm.state.sessionCredits == 100 && vm.state.currentBet == 1 && vm.state.phase == .betting && !vm.isFreePlay, "Fresh table: 100 credits, bet 1")
        vm.deal()
        expect(vm.state.phase == .playing && vm.state.sessionCredits == 99, "Dealt: bet of 1 deducted")
        expect(vm.state.playerHands.count == 1 && vm.state.playerHands[0].cards.count == 2 && vm.state.dealerCards.count == 2, "Two cards each")
        expect(vm.state.playerHands[0].cards.allSatisfy { $0.faceUp } && vm.state.dealerCards[0].faceUp && !vm.state.dealerCards[1].faceUp,
               "The dealer's hole card is face down")
        expect(vm.state.deck.count == 48, "48 cards left in the shoe")
        expect(vm.statistics.handsPlayed == 1 && vm.statistics.totalWagered == 1 && vm.state.handsDealt == 1, "Hand counted and wagered")
        expect(vm.activeHand?.cards.count == 2, "The active hand is the player's")
        let hand = vm.state.playerHands[0].cards
        vm.deal()
        expect(vm.state.playerHands[0].cards == hand, "Can't deal again mid-round")
        expect(!vm.canOpenOptions, "Options locked mid-round")

        let broke = BlackjackViewModel()
        broke.state.sessionCredits = 5
        broke.state.currentBet = 10
        broke.deal()
        expect(broke.state.phase == .betting && broke.state.sessionCredits == 5, "Not enough credits: no deal")
        expect(broke.canOpenOptions, "Options open at the betting table")
    }

    static func testPayoutsForWinLossPush() {
        // Win: 20 beats 18 → pays 2× the bet.
        var vm = fresh()
        round(vm, player: [[card(.hearts, 10), card(.spades, 10)]], dealer: [card(.clubs, 10), card(.diamonds, 8, up: false)])
        vm.stand()
        expect(vm.state.phase == .result && vm.state.playerHands[0].result == .win, "20 beats 18")
        expect(vm.state.sessionCredits == 110 && vm.state.lastNetResult == 10 && vm.state.resultOutcome == .win, "Win pays 2× (net +10), got \(vm.state.sessionCredits)")
        expect(vm.statistics.handsWon == 1 && vm.statistics.currentStreak == 1 && vm.statistics.totalPaidOut == 20 && vm.statistics.biggestPayout == 20, "Win stats")
        expect(vm.state.isWinRound, "Round flagged as a win")

        // Loss: 18 loses to 20.
        vm = fresh()
        var s = vm.statistics; s.currentStreak = 3; s.longestStreak = 3; vm.statistics = s
        round(vm, player: [[card(.hearts, 10), card(.spades, 8)]], dealer: [card(.clubs, 10), card(.diamonds, 10, up: false)])
        vm.stand()
        expect(vm.state.playerHands[0].result == .loss && vm.state.sessionCredits == 90 && vm.state.lastNetResult == -10 && vm.state.resultOutcome == .loss,
               "Loss keeps the bet gone")
        expect(vm.statistics.handsLost == 1 && vm.statistics.currentStreak == 0 && vm.statistics.longestStreak == 3, "A loss ends the streak")

        // Push: 18 vs 18 returns the bet, leaves the streak alone, and isn't a "biggest payout".
        vm = fresh()
        s = vm.statistics; s.currentStreak = 3; vm.statistics = s
        round(vm, player: [[card(.hearts, 10), card(.spades, 8)]], dealer: [card(.clubs, 10), card(.diamonds, 8, up: false)])
        vm.stand()
        expect(vm.state.playerHands[0].result == .push && vm.state.sessionCredits == 100 && vm.state.resultOutcome == .push && vm.state.lastNetResult == 0,
               "Push returns the bet")
        expect(vm.statistics.pushes == 1 && vm.statistics.currentStreak == 3 && vm.statistics.biggestPayout == 0, "Push doesn't touch the streak or biggest payout")

        // Bust: hitting over 21 loses without the dealer drawing.
        vm = fresh()
        round(vm, player: [[card(.hearts, 10), card(.spades, 6)]], dealer: [card(.clubs, 10), card(.diamonds, 5, up: false)], deck: [card(.diamonds, 13)])
        vm.hit()
        expect(vm.state.phase == .result && vm.state.playerHands[0].result == .bust && vm.state.resultOutcome == .bust, "Bust ends the round")
        expect(vm.state.dealerCards.count == 2 && vm.state.dealerCards.allSatisfy { $0.faceUp }, "The dealer only turns the hole card over when every hand has busted")
        expect(vm.state.sessionCredits == 90 && vm.statistics.handsLost == 1, "Bust loses the bet")

        // A win is a win even from a small total when the dealer busts.
        vm = fresh()
        round(vm, player: [[card(.hearts, 10), card(.spades, 2)]], dealer: [card(.clubs, 10), card(.diamonds, 6, up: false)], deck: [card(.hearts, 13)])
        vm.stand()
        expect(vm.state.playerHands[0].result == .win && vm.state.dealerCards.count == 3 && vm.state.sessionCredits == 110, "Dealer busts on 26: player's 12 wins")
    }

    static func testDealerRules() {
        // Dealer draws on 16 …
        var vm = BlackjackViewModel()
        round(vm, player: [[card(.hearts, 10), card(.spades, 9)]], dealer: [card(.clubs, 10), card(.diamonds, 6, up: false)], deck: [card(.hearts, 2)])
        vm.stand()
        expect(vm.state.dealerCards.count == 3 && BlackjackState.handValue(vm.state.dealerCards) == 18, "Dealer hits 16 and stops at 18")
        expect(vm.state.playerHands[0].result == .win, "Player's 19 beats 18")

        // … and stands on every 17, including soft 17.
        vm = BlackjackViewModel()
        round(vm, player: [[card(.hearts, 10), card(.spades, 8)]], dealer: [card(.clubs, 1), card(.diamonds, 6, up: false)], deck: [card(.hearts, 9)])
        vm.stand()
        expect(vm.state.dealerCards.count == 2, "Dealer stands on soft 17")
        expect(vm.state.playerHands[0].result == .win, "Player's 18 beats the dealer's 17")

        // Dealer natural (resolved right after the deal): beats a non-natural 21, pushes a natural.
        vm = BlackjackViewModel()
        round(vm, player: [[card(.hearts, 10), card(.spades, 9)]], dealer: [card(.clubs, 1), card(.diamonds, 13, up: false)], deck: [card(.hearts, 2)])
        vm.executeDealerTurn()
        expect(vm.state.playerHands[0].result == .loss && vm.state.dealerCards.count == 2, "Dealer blackjack beats 19 and doesn't draw")
        vm = BlackjackViewModel()
        round(vm, player: [[card(.hearts, 1), card(.spades, 13)]], dealer: [card(.clubs, 1), card(.diamonds, 13, up: false)])
        vm.executeDealerTurn()
        expect(vm.state.playerHands[0].result == .push && vm.state.sessionCredits == 100, "Blackjack vs blackjack is a push")
        vm = BlackjackViewModel()
        round(vm, player: [[card(.hearts, 5), card(.spades, 6), card(.clubs, 10)]], dealer: [card(.clubs, 1), card(.diamonds, 13, up: false)])
        vm.executeDealerTurn()
        expect(vm.state.playerHands[0].result == .loss, "A made 21 (not a natural) still loses to a dealer blackjack")

        // Actions against a hidden dealer blackjack are refused.
        vm = BlackjackViewModel()
        round(vm, player: [[card(.hearts, 10), card(.spades, 9)]], dealer: [card(.clubs, 1), card(.diamonds, 13, up: false)], deck: [card(.hearts, 2)])
        vm.hit(); vm.stand()
        expect(vm.state.phase == .playing && vm.state.playerHands[0].cards.count == 2, "Player can't act once the dealer has a natural")

        // Executing out of turn does nothing.
        vm = BlackjackViewModel()
        vm.executeDealerTurn()
        expect(vm.state.phase == .betting, "Dealer turn needs a round in progress")
    }

    static func testNaturalsPayThreeToOneAndOnlyOnUnsplitHands() {
        var vm = fresh()
        round(vm, player: [[card(.hearts, 1), card(.spades, 13)]], dealer: [card(.clubs, 10), card(.diamonds, 4, up: false)], deck: [card(.hearts, 9)])
        vm.hit(); vm.stand(); vm.doubleDown(); vm.split()
        expect(vm.state.phase == .playing && vm.state.playerHands[0].cards.count == 2 && vm.state.sessionCredits == 90, "A natural can't be hit, stood, doubled or split")
        vm.executeDealerTurn()
        expect(vm.state.playerHands[0].result == .blackjack && vm.state.sessionCredits == 90 + 40 && vm.state.resultOutcome == .blackjack, "Natural pays 3:1 (+30 profit)")
        expect(vm.state.dealerCards.count == 2, "The dealer doesn't draw against a natural")
        expect(vm.statistics.blackjacks == 1 && vm.statistics.handsWon == 1 && vm.statistics.currentStreak == 1 && vm.statistics.biggestPayout == 40, "Natural stats")
        expect(vm.state.lastNetResult == 30, "Net +30")

        // 21 on a split hand is just a win, paid 1:1 — a natural only counts on an unsplit hand.
        vm = fresh()
        round(vm, player: [[card(.hearts, 10), card(.spades, 10)]], dealer: [card(.clubs, 10), card(.diamonds, 7, up: false)],
              deck: [card(.hearts, 1), card(.clubs, 8)], credits: 90)
        vm.split()   // hand 1 = 10 + 8 = 18, hand 2 = 10 + A = 21
        expect(vm.state.playerHands.count == 2 && vm.state.playerHands[1].value == 21, "Second hand made 21")
        vm.stand()   // the already-complete 21 is skipped straight to the dealer
        expect(vm.state.phase == .result, "Round finished")
        expect(vm.state.playerHands[1].result == .win && vm.statistics.blackjacks == 0, "A split 21 is a plain win, not a blackjack")
        expect(vm.state.sessionCredits == 80 + 40, "Both hands paid 1:1 (got \(vm.state.sessionCredits))")
    }

    static func testDoubleDown() {
        var vm = fresh()
        round(vm, player: [[card(.hearts, 5), card(.spades, 6)]], dealer: [card(.clubs, 10), card(.diamonds, 8, up: false)], deck: [card(.diamonds, 9)])
        expect(vm.canDouble, "11 can double")
        vm.doubleDown()
        expect(vm.state.playerHands[0].isDoubled && vm.state.playerHands[0].bet == 20 && vm.state.playerHands[0].cards.count == 3, "Doubled: bet 20, exactly one more card")
        expect(vm.state.phase == .result, "Doubling stands automatically and plays out the dealer")
        expect(vm.state.sessionCredits == 80 + 40 && vm.state.lastNetResult == 20, "20 beats 18: pays 2 × 20 (net +20), got \(vm.state.sessionCredits)")
        expect(vm.statistics.totalWagered == 10, "The extra stake is counted as wagered (10 here, the deal's 10 was set up by hand)")

        func can(_ cards: [Card], credits: Int = 90) -> Bool {
            let v = BlackjackViewModel()
            round(v, player: [cards], dealer: [card(.clubs, 10), card(.diamonds, 8, up: false)], credits: credits)
            return v.canDouble
        }
        expect(can([card(.hearts, 4), card(.spades, 5)]), "9 can double")
        expect(can([card(.hearts, 4), card(.spades, 6)]), "10 can double")
        expect(!can([card(.hearts, 4), card(.spades, 3)]), "7 can't double")
        expect(!can([card(.hearts, 10), card(.spades, 2)]), "12 can't double")
        expect(!can([card(.hearts, 2), card(.spades, 3), card(.clubs, 4)]), "Three cards can't double")
        expect(!can([card(.hearts, 5), card(.spades, 6)], credits: 5), "Not enough credits to cover the double")
        vm = fresh()
        vm.state.phase = .betting
        vm.doubleDown()
        expect(vm.state.playerHands.isEmpty, "Can't double outside a round")
        expect(vm.activeHand == nil, "No active hand outside a round")
    }

    static func testSplitRules() {
        let vm = fresh()
        round(vm, player: [[card(.hearts, 8), card(.spades, 8)]], dealer: [card(.clubs, 10), card(.diamonds, 7, up: false)],
              deck: [card(.diamonds, 3), card(.clubs, 9)])
        expect(vm.canSplit, "A pair can split")
        vm.split()
        expect(vm.state.playerHands.count == 2 && vm.state.sessionCredits == 80 && vm.statistics.totalWagered == 10 && vm.statistics.handsPlayed == 1,
               "Split costs a second bet and counts as another hand played")
        expect(vm.state.playerHands[0].cards.map { $0.rank } == [8, 9] && vm.state.playerHands[1].cards.map { $0.rank } == [8, 3], "Each hand gets one new card")
        expect(vm.state.activeHandIndex == 0 && !vm.canSplit, "Only one split per round")
        vm.split()
        expect(vm.state.playerHands.count == 2 && vm.state.sessionCredits == 80, "A second split attempt does nothing")

        vm.stand()
        expect(vm.state.activeHandIndex == 1 && vm.state.phase == .playing, "Standing moves to the second hand")
        vm.stand()
        expect(vm.state.phase == .result, "...then the dealer plays")
        expect(vm.state.playerHands[0].result == .push && vm.state.playerHands[1].result == .loss, "17 pushes, 11 loses")
        expect(vm.state.sessionCredits == 90 && vm.state.lastNetResult == -10 && vm.state.resultOutcome == .loss, "Push returns 10, loss forfeits 10")
        expect(vm.statistics.pushes == 1 && vm.statistics.handsLost == 1 && vm.statistics.currentStreak == 0, "Split result stats")

        // Unequal ranks (even two ten-valued cards) can't split; low credits can't either.
        let ten = BlackjackViewModel()
        round(ten, player: [[card(.hearts, 10), card(.spades, 13)]], dealer: [card(.clubs, 10), card(.diamonds, 7, up: false)])
        expect(!ten.canSplit, "10 and K aren't a pair")
        let poor = BlackjackViewModel()
        round(poor, player: [[card(.hearts, 8), card(.spades, 8)]], dealer: [card(.clubs, 10), card(.diamonds, 7, up: false)], credits: 5)
        expect(!poor.canSplit, "Not enough credits to split")
        poor.split()
        expect(poor.state.playerHands.count == 1, "split() respects canSplit")

        // A split hand that is dealt straight to 21 doesn't wait for the player.
        let auto = BlackjackViewModel()
        round(auto, player: [[card(.hearts, 10), card(.spades, 10)]], dealer: [card(.clubs, 10), card(.diamonds, 7, up: false)],
              deck: [card(.clubs, 8), card(.diamonds, 1)])
        auto.split()   // hand 1 = 10 + A = 21, hand 2 = 10 + 8 = 18
        expect(auto.state.activeHandIndex == 1 && auto.state.phase == .playing, "A split hand dealt to 21 is skipped; play moves to hand 2")
        auto.stand()
        expect(auto.state.phase == .result && auto.state.playerHands.allSatisfy { $0.result == .win }, "Both hands beat 17")
    }

    static func testSplitAces() {
        let vm = fresh()
        round(vm, player: [[card(.hearts, 1), card(.spades, 1)]], dealer: [card(.clubs, 10), card(.diamonds, 8, up: false)],
              deck: [card(.diamonds, 13), card(.clubs, 5)])
        vm.split()
        expect(vm.state.playerHands.count == 2 && vm.state.playerHands.allSatisfy { $0.isSplitAce && $0.cards.count == 2 }, "Split aces get exactly one card each")
        expect(vm.state.playerHands.allSatisfy { $0.isComplete }, "...and are complete")
        vm.hit(); vm.stand(); vm.doubleDown()
        expect(vm.state.playerHands.allSatisfy { $0.cards.count == 2 } && vm.state.phase == .playing, "No hit, stand or double on split aces")
        vm.executeDealerTurn()   // what the 1.5 s delayed resolve does
        expect(vm.state.playerHands[0].value == 16 && vm.state.playerHands[0].result == .loss, "A + 5 = 16 loses to 18")
        expect(vm.state.playerHands[1].value == 21 && vm.state.playerHands[1].result == .win, "A + K after a split is 21 but only a plain win")
        expect(vm.state.sessionCredits == 80 + 20 && vm.statistics.blackjacks == 0, "Paid 1:1 (20 back), not 3:1")

        // The round resolves on its own about a second and a half after the split — unless the
        // hand was abandoned in the meantime, in which case the stale timer must do nothing.
        let timed = fresh()
        round(timed, player: [[card(.hearts, 1), card(.spades, 1)]], dealer: [card(.clubs, 10), card(.diamonds, 8, up: false)],
              deck: [card(.diamonds, 13), card(.clubs, 5)])
        timed.split()
        let abandoned = fresh()
        round(abandoned, player: [[card(.hearts, 1), card(.spades, 1)]], dealer: [card(.clubs, 10), card(.diamonds, 8, up: false)],
              deck: [card(.diamonds, 13), card(.clubs, 5)])
        abandoned.split()
        abandoned.restartCurrentGame()
        expect(timed.state.phase == .playing, "Waiting for the delayed resolve")
        pumpRunLoop(timeout: 3) { timed.state.phase == .result }
        expect(timed.state.phase == .result && timed.state.playerHands.allSatisfy { $0.result != nil }, "Split aces resolve by themselves")
        expect(abandoned.state.phase == .betting, "A hand abandoned before the timer fires isn't resolved afterwards")
    }

    static func testHitStandAndAutoAdvance() {
        let vm = BlackjackViewModel()
        vm.hit()
        vm.stand()
        expect(vm.state.phase == .betting, "Hit/stand do nothing outside a round")

        round(vm, player: [[card(.hearts, 5), card(.spades, 6)]], dealer: [card(.clubs, 10), card(.diamonds, 7, up: false)], deck: [card(.diamonds, 10)])
        vm.hit()
        expect(vm.state.phase == .result && vm.state.playerHands[0].value == 21 && vm.state.playerHands[0].result == .win,
               "Hitting to 21 stands automatically (no extra click) and wins")

        // Hit keeps going until the player stops.
        let more = BlackjackViewModel()
        round(more, player: [[card(.hearts, 2), card(.spades, 3)]], dealer: [card(.clubs, 10), card(.diamonds, 7, up: false)],
              deck: [card(.diamonds, 9), card(.clubs, 4)])
        more.hit()
        expect(more.state.phase == .playing && more.state.playerHands[0].value == 9, "Still playing at 9")
        more.hit()
        expect(more.state.phase == .playing && more.state.playerHands[0].value == 18, "Still playing at 18")
        more.stand()
        expect(more.state.phase == .result && more.state.playerHands[0].result == .win, "18 beats 17")

        // An empty shoe can't deal a card.
        let empty = BlackjackViewModel()
        round(empty, player: [[card(.hearts, 2), card(.spades, 3)]], dealer: [card(.clubs, 10), card(.diamonds, 7, up: false)], deck: [])
        empty.hit()
        expect(empty.state.playerHands[0].cards.count == 2, "No cards left: hit does nothing")
    }

    static func testFreePlayIsLockedForTheHand() {
        let vm = BlackjackViewModel()
        vm.sharedOptions.noStressMode = true
        expect(vm.isFreePlay, "No Stress makes Blackjack free play")
        vm.state.sessionCredits = 0
        vm.state.currentBet = 10
        vm.deal()
        expect(vm.state.phase == .playing && vm.state.sessionCredits == 0 && vm.statistics.totalWagered == 0, "Free play deals with zero credits")
        vm.sharedOptions.noStressMode = false
        expect(vm.isFreePlay, "The dealt hand stays free play after No Stress is switched off")
        vm.state.playerHands = [BlackjackHand(cards: [card(.hearts, 10), card(.spades, 10)], bet: 10)]
        vm.state.dealerCards = [card(.clubs, 10), card(.diamonds, 8, up: false)]
        vm.stand()
        expect(vm.state.playerHands[0].result == .win && vm.state.sessionCredits == 0 && vm.statistics.totalPaidOut == 0, "...so a win pays no credits")
        expect(vm.statistics.handsWon == 1, "...but still counts")
        expect(!vm.isFreePlay && vm.canRebuy, "After the hand the live setting applies again: paid play, and with 0 credits a rebuy is offered")
        vm.sharedOptions.noStressMode = true
        expect(!vm.canRebuy, "No rebuy in free play")
    }

    static func testBetsRebuyAndOutOfCreditsToast() {
        let vm = BlackjackViewModel()
        vm.doubleBet()
        expect(vm.state.currentBet == 2, "Double Bet doubles")
        vm.doubleBet(); vm.doubleBet()
        expect(vm.state.currentBet == 8, "...repeatedly")
        vm.state.sessionCredits = 5
        vm.doubleBet()
        expect(vm.state.currentBet == 5, "...but never past your credits")
        vm.clearBet()
        expect(vm.state.currentBet == 1, "Clear Bet returns to 1")
        vm.state.phase = .playing
        vm.doubleBet(); vm.addToBet(5); vm.clearBet()
        expect(vm.state.currentBet == 1, "Bet controls are locked during a round")

        // A lost round that leaves a bet bigger than the credits resets it to 1.
        let lose = BlackjackViewModel()
        round(lose, player: [[card(.hearts, 10), card(.spades, 8)]], dealer: [card(.clubs, 10), card(.diamonds, 10, up: false)], bet: 50, credits: 8)
        lose.stand()
        expect(lose.state.sessionCredits == 8 && lose.state.currentBet == 1, "Bet falls back to 1 when it can't be afforded")

        // Out-of-credits toast: after a lost round at ≤ 10 credits, in paid play only.
        _ = drain(lose)
        lose.checkOutOfCredits()
        expect(lose.flashBanner != nil, "Low on credits after a lost round → toast")
        expect(lose.canRebuy, "...and a rebuy is offered")
        lose.rebuy()
        expect(lose.state.sessionCredits == 108 && lose.statistics.rebuyCount == 1, "Rebuy adds the starting credits")
        lose.rebuy()
        expect(lose.statistics.rebuyCount == 1, "No double rebuy")
        _ = drain(lose)
        lose.checkOutOfCredits()
        expect(lose.flashBanner == nil, "Plenty of credits again → no toast")

        let won = BlackjackViewModel()
        round(won, player: [[card(.hearts, 10), card(.spades, 10)]], dealer: [card(.clubs, 10), card(.diamonds, 8, up: false)], bet: 10, credits: 0)
        won.stand()
        won.state.sessionCredits = 5
        _ = drain(won)
        won.checkOutOfCredits()
        expect(won.flashBanner == nil, "A winning round never shows the toast")

        let split = BlackjackViewModel()
        round(split, player: [[card(.hearts, 8), card(.spades, 8)]], dealer: [card(.clubs, 10), card(.diamonds, 7, up: false)],
              deck: [card(.diamonds, 10), card(.clubs, 10)], bet: 4, credits: 6)
        split.split()   // hand0 8+10 = 18, hand1 8+10 = 18; credits 2
        split.stand(); split.stand()
        expect(split.state.playerHands.allSatisfy { $0.result == .win }, "Two 18s beat 17")
        split.state.sessionCredits = 3
        _ = drain(split)
        split.checkOutOfCredits()
        expect(split.flashBanner == nil, "A round with a win in it isn't 'running out'")
    }

    static func testResultTextAndSessionReset() {
        let vm = BlackjackViewModel()
        expect(localizedBlackjackResult(vm.state, language: .english) == ("", ""), "No text before a round finishes")

        // Single-hand outcomes.
        round(vm, player: [[card(.hearts, 10), card(.spades, 10)]], dealer: [card(.clubs, 10), card(.diamonds, 8, up: false)])
        vm.stand()
        let win = localizedBlackjackResult(vm.state, language: .english)
        expect(!win.headline.isEmpty && win.subline.contains("10"), "Win text mentions the net amount: \(win)")
        let winEs = localizedBlackjackResult(vm.state, language: .spanish)
        expect(winEs.headline != win.headline && !winEs.headline.isEmpty, "Spanish headline differs from English")

        var headlines = Set<String>([win.headline])
        let others: [(player: [Card], dealer: [Card])] = [
            ([card(.hearts, 10), card(.spades, 8)], [card(.clubs, 10), card(.diamonds, 10, up: false)]),     // loss
            ([card(.hearts, 10), card(.spades, 8)], [card(.clubs, 10), card(.diamonds, 8, up: false)]),      // push
            ([card(.hearts, 1), card(.spades, 13)], [card(.clubs, 10), card(.diamonds, 7, up: false)]),      // blackjack
        ]
        for pair in others {
            let v = BlackjackViewModel()
            round(v, player: [pair.player], dealer: pair.dealer)
            v.executeDealerTurn()
            headlines.insert(localizedBlackjackResult(v.state, language: .english).headline)
        }
        let bust = BlackjackViewModel()
        round(bust, player: [[card(.hearts, 10), card(.spades, 6)]], dealer: [card(.clubs, 10), card(.diamonds, 5, up: false)], deck: [card(.diamonds, 13)])
        bust.hit()
        headlines.insert(localizedBlackjackResult(bust.state, language: .english).headline)
        expect(headlines.count == 5 && !headlines.contains(""), "Win, loss, push, blackjack and bust each have their own headline: \(headlines)")

        // Split rounds show a per-hand breakdown instead of one net figure.
        let split = BlackjackViewModel()
        round(split, player: [[card(.hearts, 8), card(.spades, 8)]], dealer: [card(.clubs, 10), card(.diamonds, 7, up: false)],
              deck: [card(.diamonds, 3), card(.clubs, 9)])
        split.split(); split.stand(); split.stand()
        let text = localizedBlackjackResult(split.state, language: .english)
        expect(text.subline.contains("1") && text.subline.contains("2") && text.subline.contains("·"), "Split result lists each hand: \(text.subline)")

        // New Game / Restart reset the table; Restart keeps the streak.
        var s = vm.statistics; s.currentStreak = 5; vm.statistics = s
        var opts = vm.options; opts.startingCredits = 300; vm.options = opts
        vm.restartCurrentGame()
        expect(vm.state.sessionCredits == 300 && vm.state.phase == .betting && vm.statistics.currentStreak == 5, "Restart resets the table but keeps the streak")
        vm.startNewGame()
        expect(vm.state.sessionCredits == 300 && vm.statistics.currentStreak == 0, "New Game resets the table and the streak")
        expect(!vm.canUndo, "No undo in Blackjack")
        vm.undoLastAction()

        // A finished round is cleared when the game is re-entered.
        round(vm, player: [[card(.hearts, 10), card(.spades, 10)]], dealer: [card(.clubs, 10), card(.diamonds, 8, up: false)])
        vm.stand()
        expect(vm.state.phase == .result, "Result showing")
        vm.resetIfRoundOver()
        expect(vm.state.phase == .betting && vm.state.playerHands.isEmpty && vm.state.dealerCards.isEmpty && vm.state.resultOutcome == .none && vm.state.lastNetResult == 0,
               "Re-entering clears the finished round")
        expect(vm.state.sessionCredits == 110, "...but keeps credits")
        vm.debugSetupBannerState(.win)
        expect(vm.state.resultOutcome == .win, "Debug win display")
        vm.debugSetupBannerState(.loss)
        expect(vm.state.resultOutcome == .loss, "Debug loss display")
    }

    static func testBannersMilestonesAndPersistence() {
        let vm = BlackjackViewModel()
        expect(drain(vm) == 0, "Nothing queued before the first hand")
        vm.deal()
        expect(drain(vm) == 1, "First hand ever shows the welcome banner")
        vm.checkLoadingBanner(); _ = drain(vm)
        vm.checkLoadingBanner()
        expect(drain(vm) == 0, "Loading banner once per session")

        var s = vm.statistics; s.handsWon = 9; vm.statistics = s
        round(vm, player: [[card(.hearts, 10), card(.spades, 10)]], dealer: [card(.clubs, 10), card(.diamonds, 8, up: false)])
        vm.stand()
        expect(vm.flashBanner != nil, "10th won hand → milestone")
        let t = vm.flashBannerTrigger
        vm.replayCurrentBanner()
        expect(vm.flashBannerTrigger == t + 1, "Replayed on return")
        expect(drain(vm) == 1, "Once")
        round(vm, player: [[card(.hearts, 10), card(.spades, 10)]], dealer: [card(.clubs, 10), card(.diamonds, 8, up: false)])
        vm.stand()
        expect(drain(vm) == 0, "Not repeated on the 11th")
        vm.scheduleIdleActionCheck(); vm.cancelIdleActionCheck()

        // Persistence & old saves
        var opts = vm.options; opts.startingCredits = 750; vm.options = opts
        let again = BlackjackViewModel()
        expect(again.options.startingCredits == 750 && again.state.sessionCredits == 750, "Starting credits survive a relaunch")
        expect(again.statistics.handsWon == 11 && again.statistics.blackjacks == 0, "Stats survive a relaunch")
        expect(abs(again.statistics.winRate - Double(again.statistics.handsWon) / Double(again.statistics.handsPlayed)) < 1e-9, "Win rate")
        again.resetStatistics()
        expect(BlackjackViewModel().statistics.handsWon == 0, "Reset Stats persists")
        expect(BlackjackStatistics().winRate == 0 && BlackjackStatistics().returnToPlayer == 0, "Empty stats are safe")
        UserDefaults.standard.set(Data("{}".utf8), forKey: "blackjack_options")
        UserDefaults.standard.set(Data("{\"handsWon\":2}".utf8), forKey: "blackjack_statistics")
        let old = BlackjackViewModel()
        expect(old.options.startingCredits == 100 && old.statistics.handsWon == 2 && old.statistics.pushes == 0, "Sparse old saves decode with defaults")
    }
}
