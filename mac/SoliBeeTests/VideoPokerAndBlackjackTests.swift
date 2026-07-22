import Foundation

struct VideoPokerAndBlackjackTests {
    static func run() {
        print("🧪 Running VideoPokerAndBlackjackTests...")
        testVideoPokerDeucesWildRoyalFlushDistinction()
        testVideoPokerDeucesWildFiveOfAKindPreference()
        testVideoPokerTriplePlayChargesTripleBet()
        testVideoPokerTriplePlayIndependentHands()
        testVideoPokerTriplePlayInsufficientCreditsBlocksDeal()
        testVideoPokerFreePlayDoesNotChargeOrPayCredits()
        testBlackjackDealerTurnPhaseGuard()
        testBlackjackSplitTwoSixes()
        testBlackjackChipButtonReplacesDefaultBet()
        testBlackjackCanRebuy()
        testBlackjackPaysThreeToOne()
        testBlackjackFreePlayBypassesCreditChecks()
        print("✅ VideoPokerAndBlackjackTests passed.")
    }

    static func testVideoPokerDeucesWildRoyalFlushDistinction() {
        let viewModel = VideoPokerViewModel()
        viewModel.options.variant = .deucesWild

        // Test Wild Royal Flush
        viewModel.state.phase = .holding
        viewModel.state.hand = [
            Card(suit: .hearts, rank: 10, faceUp: true),
            Card(suit: .hearts, rank: 11, faceUp: true),
            Card(suit: .hearts, rank: 12, faceUp: true),
            Card(suit: .hearts, rank: 13, faceUp: true),
            Card(suit: .clubs, rank: 2, faceUp: true)
        ]
        viewModel.state.heldIndices = [0, 1, 2, 3, 4]
        viewModel.draw()
        assert(viewModel.state.lastHandName == "Wild Royal Flush", "Should match Wild Royal Flush, got \(viewModel.state.lastHandName)")

        // Test Natural Royal Flush
        viewModel.state.phase = .holding
        viewModel.state.hand = [
            Card(suit: .hearts, rank: 10, faceUp: true),
            Card(suit: .hearts, rank: 11, faceUp: true),
            Card(suit: .hearts, rank: 12, faceUp: true),
            Card(suit: .hearts, rank: 13, faceUp: true),
            Card(suit: .hearts, rank: 1, faceUp: true)
        ]
        viewModel.state.heldIndices = [0, 1, 2, 3, 4]
        viewModel.draw()
        assert(viewModel.state.lastHandName == "Natural Royal Flush", "Should match Natural Royal Flush, got \(viewModel.state.lastHandName)")
    }

    static func testVideoPokerDeucesWildFiveOfAKindPreference() {
        let viewModel = VideoPokerViewModel()
        viewModel.options.variant = .deucesWild

        // 4 of rank 5 + 1 deuce (should evaluate to Five of a Kind, not Four of a Kind)
        viewModel.state.phase = .holding
        viewModel.state.hand = [
            Card(suit: .spades, rank: 5, faceUp: true),
            Card(suit: .hearts, rank: 5, faceUp: true),
            Card(suit: .diamonds, rank: 5, faceUp: true),
            Card(suit: .clubs, rank: 5, faceUp: true),
            Card(suit: .clubs, rank: 2, faceUp: true)
        ]
        viewModel.state.heldIndices = [0, 1, 2, 3, 4]
        viewModel.draw()
        assert(viewModel.state.lastHandName == "Five of a Kind", "Should match Five of a Kind, got \(viewModel.state.lastHandName)")
    }

    static func testVideoPokerTriplePlayChargesTripleBet() {
        let viewModel = VideoPokerViewModel()
        viewModel.options.playMode = .triple
        viewModel.state.sessionCredits = 100
        viewModel.state.currentBet = 5
        let handsPlayedBefore = viewModel.statistics.handsPlayed

        viewModel.deal()

        assert(viewModel.state.sessionCredits == 85, "Triple Play deal should charge betPerHand * 3, got credits \(viewModel.state.sessionCredits)")
        assert(viewModel.statistics.handsPlayed == handsPlayedBefore + 3, "Triple Play deal should count as 3 hands played, got \(viewModel.statistics.handsPlayed)")
    }

    static func testVideoPokerTriplePlayIndependentHands() {
        let viewModel = VideoPokerViewModel()
        viewModel.options.playMode = .triple
        viewModel.state.sessionCredits = 100
        viewModel.state.currentBet = 1
        viewModel.state.phase = .holding
        viewModel.state.hand = [
            Card(suit: .hearts, rank: 5, faceUp: true),
            Card(suit: .spades, rank: 5, faceUp: true),
            Card(suit: .clubs, rank: 9, faceUp: true),
            Card(suit: .diamonds, rank: 2, faceUp: true),
            Card(suit: .hearts, rank: 7, faceUp: true)
        ]
        viewModel.state.heldIndices = [0, 1]
        viewModel.state.deck = (0..<47).map { i in
            Card(suit: Card.Suit.allCases[i % 4], rank: (i % 13) + 1, faceUp: true)
        }

        viewModel.draw()

        assert(viewModel.state.triplePlayHands.count == 3, "Should produce 3 completed hands, got \(viewModel.state.triplePlayHands.count)")
        for hand in viewModel.state.triplePlayHands {
            assert(hand.count == 5, "Each triple-play hand should have 5 cards, got \(hand.count)")
            assert(hand[0].suit == .hearts && hand[0].rank == 5, "Held card at index 0 should be cloned across all hands")
            assert(hand[1].suit == .spades && hand[1].rank == 5, "Held card at index 1 should be cloned across all hands")
        }
        assert(viewModel.state.lastPayout == viewModel.state.triplePlayPayouts.reduce(0, +), "lastPayout should equal the sum of the 3 hand payouts")
    }

    static func testVideoPokerTriplePlayInsufficientCreditsBlocksDeal() {
        let viewModel = VideoPokerViewModel()
        viewModel.options.playMode = .triple
        viewModel.state.phase = .deal
        viewModel.state.currentBet = 5
        viewModel.state.sessionCredits = 10 // covers 1 hand's bet but not the tripled wager of 15

        viewModel.deal()

        assert(viewModel.state.phase == .deal, "Deal should be a no-op when credits are below the tripled wager")
        assert(viewModel.state.sessionCredits == 10, "Credits should be unchanged when deal is blocked")
    }

    static func testVideoPokerFreePlayDoesNotChargeOrPayCredits() {
        let viewModel = VideoPokerViewModel()
        viewModel.options.variant = .jacksOrBetter
        viewModel.options.noStressMode = true
        viewModel.state.sessionCredits = 0
        viewModel.state.currentBet = 5

        viewModel.deal()
        assert(viewModel.state.phase == .holding, "Free play deal should not be blocked by zero credits")
        assert(viewModel.state.sessionCredits == 0, "Free play deal should not deduct credits")

        // Force a guaranteed winning hand (royal flush) before drawing.
        viewModel.state.hand = [
            Card(suit: .hearts, rank: 1, faceUp: true),
            Card(suit: .hearts, rank: 13, faceUp: true),
            Card(suit: .hearts, rank: 12, faceUp: true),
            Card(suit: .hearts, rank: 11, faceUp: true),
            Card(suit: .hearts, rank: 10, faceUp: true)
        ]
        viewModel.state.heldIndices = [0, 1, 2, 3, 4]
        let handsWonBefore = viewModel.statistics.handsWon
        let streakBefore = viewModel.statistics.currentStreak
        let paidOutBefore = viewModel.statistics.totalPaidOut

        viewModel.draw()

        assert(viewModel.state.lastHandName == "Royal Flush", "Hand name should still be computed in free play")
        assert(viewModel.state.sessionCredits == 0, "Free play should never award credits")
        assert(viewModel.statistics.handsWon == handsWonBefore + 1, "Free play should still count the win")
        assert(viewModel.statistics.currentStreak == streakBefore + 1, "Free play should still track win streaks")
        assert(viewModel.statistics.totalPaidOut == paidOutBefore, "Free play should not report credits as paid out")
    }

    static func testBlackjackDealerTurnPhaseGuard() {
        let viewModel = BlackjackViewModel()

        // Phase is betting (e.g. game reset or new game started)
        viewModel.state.phase = .betting
        viewModel.executeDealerTurn()

        // The dealer turn should have returned early, keeping the phase as betting
        assert(viewModel.state.phase == .betting, "Dealer turn must not execute if phase is not playing")
    }

    static func testBlackjackSplitTwoSixes() {
        let viewModel = BlackjackViewModel()
        viewModel.state.sessionCredits = 100
        viewModel.state.currentBet = 10
        viewModel.state.playerHands = [
            BlackjackHand(cards: [
                Card(suit: .hearts, rank: 6, faceUp: true),
                Card(suit: .spades, rank: 6, faceUp: true)
            ], bet: 10)
        ]
        assert(viewModel.canSplit == true, "Two 6s must be splittable if credits are sufficient")
    }

    static func testBlackjackChipButtonReplacesDefaultBet() {
        let viewModel = BlackjackViewModel()
        viewModel.state.phase = .betting
        viewModel.state.sessionCredits = 1000

        // Default bet (1): clicking 10 should replace, not add (1 -> 10, not 11)
        viewModel.state.currentBet = 1
        viewModel.addToBet(10)
        assert(viewModel.state.currentBet == 10, "Clicking 10 chip at default bet should set bet to 10, got \(viewModel.state.currentBet)")

        // Clicking 10 again should add normally (10 -> 20)
        viewModel.addToBet(10)
        assert(viewModel.state.currentBet == 20, "Clicking 10 chip again should add to bet, got \(viewModel.state.currentBet)")

        // Default bet (1): clicking the 1 chip should add normally (1 -> 2 -> 3)
        viewModel.state.currentBet = 1
        viewModel.addToBet(1)
        assert(viewModel.state.currentBet == 2, "Clicking 1 chip at default bet should add, got \(viewModel.state.currentBet)")
        viewModel.addToBet(1)
        assert(viewModel.state.currentBet == 3, "Clicking 1 chip again should add, got \(viewModel.state.currentBet)")

        // Default bet (1): clicking 5 or 25 should also replace
        viewModel.state.currentBet = 1
        viewModel.addToBet(5)
        assert(viewModel.state.currentBet == 5, "Clicking 5 chip at default bet should set bet to 5, got \(viewModel.state.currentBet)")

        viewModel.state.currentBet = 1
        viewModel.addToBet(25)
        assert(viewModel.state.currentBet == 25, "Clicking 25 chip at default bet should set bet to 25, got \(viewModel.state.currentBet)")

        // Replacement is clamped to available session credits
        viewModel.state.sessionCredits = 8
        viewModel.state.currentBet = 1
        viewModel.addToBet(10)
        assert(viewModel.state.currentBet == 8, "Chip replacement should clamp to available credits, got \(viewModel.state.currentBet)")
    }

    static func testBlackjackCanRebuy() {
        let viewModel = BlackjackViewModel()

        // canRebuy is a flat "you're running low" gas light (sessionCredits <= 10),
        // deliberately not bet-relative — see the comment above canRebuy in
        // BlackjackViewModel: it's an early warning, not "can't afford this bet."
        viewModel.state.phase = .betting
        viewModel.state.sessionCredits = 0
        viewModel.state.currentBet = 1
        assert(viewModel.canRebuy == true, "Rebuy should be offered when credits are low in betting phase")

        // Result phase, still low on credits: rebuy should also be offered
        viewModel.state.phase = .result
        assert(viewModel.canRebuy == true, "Rebuy should be offered when credits are low in result phase")

        viewModel.state.sessionCredits = 10
        assert(viewModel.canRebuy == true, "Rebuy should still be offered right at the threshold, regardless of the bet")

        viewModel.state.sessionCredits = 11
        assert(viewModel.canRebuy == false, "Rebuy should not be offered just above the threshold")

        // Plenty of credits: no rebuy needed
        viewModel.state.sessionCredits = 100
        assert(viewModel.canRebuy == false, "Rebuy should not be offered with plenty of credits")

        // Low on credits but mid-hand: rebuy should not be offered (only in betting/result)
        viewModel.state.phase = .playing
        viewModel.state.sessionCredits = 0
        assert(viewModel.canRebuy == false, "Rebuy should not be offered during an active hand")

        viewModel.state.phase = .dealerTurn
        assert(viewModel.canRebuy == false, "Rebuy should not be offered during the dealer's turn")
    }

    static func testBlackjackPaysThreeToOne() {
        let viewModel = BlackjackViewModel()

        // Bet already deducted (mirrors state after deal()); dealer has a non-blackjack 17 so no hit occurs.
        viewModel.state.phase = .playing
        viewModel.state.sessionCredits = 100
        viewModel.state.currentBet = 10
        viewModel.state.dealerCards = [
            Card(suit: .clubs, rank: 10, faceUp: true),
            Card(suit: .clubs, rank: 7, faceUp: true)
        ]
        viewModel.state.playerHands = [
            BlackjackHand(cards: [
                Card(suit: .hearts, rank: 1, faceUp: true),
                Card(suit: .spades, rank: 13, faceUp: true)
            ], bet: 10)
        ]

        viewModel.executeDealerTurn()

        assert(viewModel.state.playerHands[0].result == .blackjack, "Hand should resolve as blackjack")
        assert(viewModel.state.sessionCredits == 140, "3:1 blackjack payout on a 10 bet should credit 40 (10 back + 30 profit), got \(viewModel.state.sessionCredits)")
    }

    static func testBlackjackFreePlayBypassesCreditChecks() {
        let viewModel = BlackjackViewModel()
        viewModel.options.noStressMode = true
        viewModel.state.sessionCredits = 0
        viewModel.state.currentBet = 10

        viewModel.deal()
        assert(viewModel.state.phase == .playing || viewModel.state.phase == .result,
               "Free play deal should not be blocked by zero credits")
        assert(viewModel.state.sessionCredits == 0, "Free play deal should not deduct credits")

        viewModel.state.phase = .playing
        viewModel.state.activeHandIndex = 0
        viewModel.state.playerHands = [
            BlackjackHand(cards: [
                Card(suit: .hearts, rank: 5, faceUp: true),
                Card(suit: .spades, rank: 5, faceUp: true)
            ], bet: 10)
        ]
        assert(viewModel.canSplit == true, "canSplit should bypass the credit check in free play")
        assert(viewModel.canDouble == true, "canDouble should bypass the credit check in free play")

        viewModel.split()
        assert(viewModel.state.sessionCredits == 0, "Free play split should not deduct credits")
        assert(viewModel.state.playerHands.count == 2, "Split should still create two hands in free play")
    }
}
