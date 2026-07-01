import Foundation

struct VideoPokerAndBlackjackTests {
    static func run() {
        print("🧪 Running VideoPokerAndBlackjackTests...")
        testVideoPokerDeucesWildRoyalFlushDistinction()
        testVideoPokerDeucesWildFiveOfAKindPreference()
        testBlackjackDealerTurnPhaseGuard()
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
}
