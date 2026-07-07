import Foundation

struct VideoPokerAndBlackjackTests {
    static func run() {
        print("🧪 Running VideoPokerAndBlackjackTests...")
        testVideoPokerDeucesWildRoyalFlushDistinction()
        testVideoPokerDeucesWildFiveOfAKindPreference()
        testBlackjackDealerTurnPhaseGuard()
        testBlackjackSplitTwoSixes()
        testBlackjackChipButtonReplacesDefaultBet()
        testBlackjackCanRebuy()
        testBlackjackPaysThreeToOne()
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

        // Betting phase with insufficient credits should offer rebuy
        viewModel.state.phase = .betting
        viewModel.state.sessionCredits = 0
        viewModel.state.currentBet = 1
        assert(viewModel.canRebuy == true, "Rebuy should be offered when credits are below the current bet in betting phase")

        // Result phase with insufficient credits should also offer rebuy
        viewModel.state.phase = .result
        assert(viewModel.canRebuy == true, "Rebuy should be offered when credits are below the current bet in result phase")

        // Sufficient credits: no rebuy needed
        viewModel.state.sessionCredits = 100
        assert(viewModel.canRebuy == false, "Rebuy should not be offered when credits cover the current bet")

        // Insufficient credits but mid-hand: rebuy should not be offered (only in betting/result)
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
}
