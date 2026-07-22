import Foundation

public struct GameState: Codable, Equatable {
    public enum DrawMode: String, Codable {
        case drawOne
        case drawThree
    }
    
    public var stock: Pile
    public var waste: Pile
    public var foundations: [Pile] // Array of 4 foundations
    public var tableau: [Pile]     // Array of 7 columns
    
    public var score: Int
    public var movesCount: Int
    public var timerSeconds: Int
    public var isTimerActive: Bool
    public var drawMode: DrawMode
    public var hasWon: Bool
    public var recyclesCount: Int
    // Tracks how many cards from the current draw batch are still on top of the waste pile.
    // Shrinks as cards are played; reset to the draw count on each new draw.
    public var wasteDisplayCount: Int = 0

    public init(
        stock: Pile = Pile(id: "stock", type: .stock),
        waste: Pile = Pile(id: "waste", type: .waste),
        foundations: [Pile] = [],
        tableau: [Pile] = [],
        score: Int = 0,
        movesCount: Int = 0,
        timerSeconds: Int = 0,
        isTimerActive: Bool = false,
        drawMode: DrawMode = .drawThree,
        hasWon: Bool = false,
        recyclesCount: Int = 0,
        wasteDisplayCount: Int = 0
    ) {
        self.stock = stock
        self.waste = waste
        let foundationSuits: [Card.Suit] = [.spades, .clubs, .diamonds, .hearts]
        self.foundations = foundations.isEmpty ? foundationSuits.map { Pile(id: "foundation_\($0.rawValue)", type: .foundation) } : foundations
        self.tableau = tableau.isEmpty ? (0..<7).map { Pile(id: "tableau_\($0)", type: .tableau) } : tableau
        self.score = score
        self.movesCount = movesCount
        self.timerSeconds = timerSeconds
        self.isTimerActive = isTimerActive
        self.drawMode = drawMode
        self.hasWon = hasWon
        self.recyclesCount = recyclesCount
        self.wasteDisplayCount = wasteDisplayCount
    }
}
