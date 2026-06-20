import Foundation

struct GameStateTests {
    static func run() {
        testCardInitialization()
        testCardRankStrings()
        testPileHelpers()
    }
    
    static func testCardInitialization() {
        let card = Card(suit: .hearts, rank: 1, faceUp: false)
        assert(card.suit == .hearts, "Suit should be hearts")
        assert(card.rank == 1, "Rank should be 1")
        assert(!card.faceUp, "Card should be face-down")
        assert(card.isRed, "Card should be red")
        assert(!card.isBlack, "Card should not be black")
        assert(card.rankString == "A", "Rank string should be A")
    }
    
    static func testCardRankStrings() {
        let jack = Card(suit: .spades, rank: 11)
        let queen = Card(suit: .clubs, rank: 12)
        let king = Card(suit: .diamonds, rank: 13)
        let ten = Card(suit: .hearts, rank: 10)
        
        assert(jack.rankString == "J", "Rank string should be J")
        assert(queen.rankString == "Q", "Rank string should be Q")
        assert(king.rankString == "K", "Rank string should be K")
        assert(ten.rankString == "10", "Rank string should be 10")
    }
    
    static func testPileHelpers() {
        let card1 = Card(suit: .hearts, rank: 5)
        let card2 = Card(suit: .clubs, rank: 6)
        
        var pile = Pile(id: "test", type: .tableau, cards: [card1, card2])
        assert(!pile.isEmpty, "Pile should not be empty")
        assert(pile.topCard == card2, "Top card should be card2")
        
        pile.cards.removeAll()
        assert(pile.isEmpty, "Pile should be empty")
        assert(pile.topCard == nil, "Top card should be nil")
    }
}
