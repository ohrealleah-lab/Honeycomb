import Foundation

struct SpiderTests {
    static func run() {
        testSpiderInitialization()
        testSpiderValidation()
        testSpiderWinState()
    }
    
    static func testSpiderInitialization() {
        let viewModel = SpiderViewModel()
        assert(viewModel.state.tableau.count == 10, "Spider tableau must have 10 columns")
        
        // Initial score is 500
        assert(viewModel.state.score == 500, "Spider starting score must be 500")
        
        // Total cards in initial tableau is 54
        let initialTableauCardCount = viewModel.state.tableau.reduce(0) { $0 + $1.cards.count }
        assert(initialTableauCardCount == 54, "Initial dealt cards must be 54")
        
        // Stock has remaining 50 cards
        assert(viewModel.state.stock.cards.count == 50, "Initial stock must have 50 cards")
    }
    
    static func testSpiderValidation() {
        let viewModel = SpiderViewModel()
        
        // Check single cards are valid sequence
        let singleCard = Card(suit: .spades, rank: 5, faceUp: true)
        assert(viewModel.isValidDragSequence([singleCard]), "Single face-up card should be a valid drag sequence")
        
        // Check matching suit descending order sequence is valid
        let card1 = Card(suit: .spades, rank: 5, faceUp: true)
        let card2 = Card(suit: .spades, rank: 4, faceUp: true)
        assert(viewModel.isValidDragSequence([card1, card2]), "Matching suit descending sequence should be valid")
        
        // Check non-matching suit sequence is invalid for drag
        let card3 = Card(suit: .hearts, rank: 4, faceUp: true)
        assert(!viewModel.isValidDragSequence([card1, card3]), "Non-matching suit sequence should be invalid for drag")
    }

    static func testSpiderWinState() {
        let viewModel = SpiderViewModel()
        assert(!viewModel.state.hasWon, "Fresh game should not be won")

        // Fill all 8 foundations with a complete King-to-Ace run to simulate a win
        // (8 * 13 = 104 cards, matching Spider's full deck).
        viewModel.state.foundations = (0..<8).map { idx in
            Pile(id: "foundation_\(idx)", type: .foundation, cards: (1...13).reversed().map { Card(suit: .spades, rank: $0, faceUp: true) })
        }

        viewModel.checkWinState()
        assert(viewModel.state.hasWon, "Game should be won with all 104 foundation cards filled")
        assert(!viewModel.state.isTimerActive, "Timer should stop on win")
    }
}
