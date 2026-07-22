import Foundation

struct GameStateTests {
    static func run() {
        testCardInitialization()
        testCardRankStrings()
        testPileHelpers()
        testCustomCardBackCoding()
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
    
    static func testCustomCardBackCoding() {
        // Test encoding and decoding with offsetX and offsetY present
        let back1 = CustomCardBack(id: UUID(), name: "Test Back", relativePath: "test.png", scale: 1.5, offsetX: 10.0, offsetY: -20.0)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        do {
            let data = try encoder.encode(back1)
            let decoded = try decoder.decode(CustomCardBack.self, from: data)
            assert(decoded.id == back1.id, "ID should match")
            assert(decoded.name == back1.name, "Name should match")
            assert(decoded.relativePath == back1.relativePath, "Path should match")
            assert(decoded.scale == back1.scale, "Scale should match")
            assert(decoded.offsetX == back1.offsetX, "OffsetX should match")
            assert(decoded.offsetY == back1.offsetY, "OffsetY should match")
        } catch {
            assertionFailure("Failed to encode/decode with offsets: \(error)")
        }
        
        // Test backwards compatibility: decode from JSON where offsetX and offsetY are missing
        let jsonWithoutOffsets = """
        {
            "id": "A4C98226-788B-4DC0-891A-0402092147DF",
            "name": "Legacy Back",
            "relativePath": "legacy.png",
            "scale": 1.25
        }
        """.data(using: .utf8)!
        
        do {
            let decodedLegacy = try decoder.decode(CustomCardBack.self, from: jsonWithoutOffsets)
            assert(decodedLegacy.id == UUID(uuidString: "A4C98226-788B-4DC0-891A-0402092147DF"), "ID should match")
            assert(decodedLegacy.name == "Legacy Back", "Name should match")
            assert(decodedLegacy.relativePath == "legacy.png", "Path should match")
            assert(decodedLegacy.scale == 1.25, "Scale should match")
            assert(decodedLegacy.offsetX == 0.0, "OffsetX should default to 0.0")
            assert(decodedLegacy.offsetY == 0.0, "OffsetY should default to 0.0")
        } catch {
            assertionFailure("Failed to decode legacy custom card back without offsets: \(error)")
        }
    }
}
