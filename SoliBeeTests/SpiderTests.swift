import Foundation

struct SpiderTests {
    static func run() {
        testSpiderInitialization()
        testSpiderValidation()
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
}
