import Foundation

public struct SpiderState: Codable, Equatable {
    public var stock: Pile
    public var foundations: [Pile]
    public var tableau: [Pile]
    public var score: Int
    public var movesCount: Int
    public var timerSeconds: Int
    public var isTimerActive: Bool
    public var hasWon: Bool
    
    public init(
        stock: Pile,
        foundations: [Pile],
        tableau: [Pile],
        score: Int,
        movesCount: Int,
        timerSeconds: Int,
        isTimerActive: Bool,
        hasWon: Bool
    ) {
        self.stock = stock
        self.foundations = foundations
        self.tableau = tableau
        self.score = score
        self.movesCount = movesCount
        self.timerSeconds = timerSeconds
        self.isTimerActive = isTimerActive
        self.hasWon = hasWon
    }
}
