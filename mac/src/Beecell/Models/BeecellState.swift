import Foundation

public struct BeecellState: Codable, Equatable {
    public var freeCells: [Pile]        // 4 (1-deck) or 8 (2-decks) cells
    public var foundations: [Pile]     // 4 (1-deck) or 8 (2-decks) foundations
    public var tableau: [Pile]         // 8 (1-deck) or 10 (2-decks) columns
    public var score: Int
    public var movesCount: Int
    public var timerSeconds: Int
    public var isTimerActive: Bool
    public var hasWon: Bool
    
    public init(
        freeCells: [Pile],
        foundations: [Pile],
        tableau: [Pile],
        score: Int,
        movesCount: Int,
        timerSeconds: Int,
        isTimerActive: Bool,
        hasWon: Bool
    ) {
        self.freeCells = freeCells
        self.foundations = foundations
        self.tableau = tableau
        self.score = score
        self.movesCount = movesCount
        self.timerSeconds = timerSeconds
        self.isTimerActive = isTimerActive
        self.hasWon = hasWon
    }
}
